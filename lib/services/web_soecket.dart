import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

// ✅ Import the shared ReplyData and ChatMessage from chat_message.dart
import '../models/chat_message.dart';

// ============================================================================
// WEB SOCKET SERVICE — MULTI-ROOM
// ============================================================================
//
// One physical socket, many rooms. The server (websocket.rs) now tracks a
// per-connection HashSet<String> of joined rooms instead of a single
// current_room. This client mirrors that: joinRoom() is additive (never
// evicts another room), leaveRoom() removes exactly one, and on reconnect
// we rejoin everything that was joined before — because the server has no
// memory of a dropped connection's rooms.
//
// The old pinRoom()/unpinRoom() concept existed only to protect an actively
// -viewed room from being stolen by a single-room model. With true
// multi-room join, that problem doesn't exist anymore — FixturesPage can
// hold N fixture rooms and ChatScreen can hold its own room at the same
// time, on the same connection. pinRoom/unpinRoom are kept as thin
// deprecated no-ops so existing call sites don't break, but they no longer
// do anything meaningful.
// ============================================================================

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _currentUserId;
  String? _currentAuthToken;
  String? _currentChannelId; // channel used for the initial connect() call
  String? _currentFixtureId; // fixture used for the initial connect() call
  String? _currentUsername;

  // ✅ MULTI-ROOM: every room this connection currently belongs to.
  // Populated by joinRoom()/joinChannelFixtureRoom(), drained by
  // leaveRoom()/leaveChannelFixtureRoom(). On reconnect we replay this
  // whole set against the fresh connection.
  final Set<String> _joinedRooms = {};

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _initialReconnectDelay = Duration(seconds: 2);
  static const Duration _connectionTimeout = Duration(seconds: 10);

  final List<Map<String, dynamic>> _messageQueue = [];
  final Map<String, List<void Function(Map<String, dynamic>)>> _listeners = {};

  Timer? _heartbeatTimer;
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _heartbeatTimeout = Duration(seconds: 35);

  Timer? _connectionTimeoutTimer;
  Timer? _heartbeatTimeoutTimer;

  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  // ==========================================================================
  // DEPRECATED ROOM PINNING — kept as no-ops for backward compatibility.
  // Multi-room join makes stealing impossible, so pinning has nothing to do.
  // ==========================================================================

  @Deprecated('No longer needed — rooms are additive now. Safe to remove calls.')
  void pinRoom(String roomId) {
    debugPrint('📌 pinRoom($roomId) is a no-op now — rooms are additive.');
  }

  @Deprecated('No longer needed — rooms are additive now. Safe to remove calls.')
  void unpinRoom(String roomId) {
    debugPrint('📌 unpinRoom($roomId) is a no-op now — rooms are additive.');
  }

  // ==========================================================================
  // ROOM HELPERS
  // ==========================================================================

  String _roomIdFor(String channelId, String? fixtureId) {
    return (fixtureId != null && fixtureId.isNotEmpty)
        ? '${channelId}_$fixtureId'
        : '${channelId}_overall';
  }

  /// The set of rooms this connection currently belongs to (read-only view).
  Set<String> get joinedRooms => Set.unmodifiable(_joinedRooms);

  bool isInRoom(String roomId) => _joinedRooms.contains(roomId);

  // ==========================================================================
  // JOIN / LEAVE — additive, multi-room
  // ==========================================================================

  /// Joins a room by its bare id (e.g. a fixture's matchId, which the
  /// server composes into `{channel}_{fixtureId}` — but for FixturesPage's
  /// use case we send the room id as-is via the `roomId` payload key, which
  /// the server's room.join handler accepts directly).
  ///
  /// This NEVER evicts another room — call this once per live fixture and
  /// they'll all keep receiving broadcasts on this one connection.
  void joinRoom(String roomId) {
    if (_joinedRooms.contains(roomId)) return;
    _joinedRooms.add(roomId);

    if (!_isConnected) {
      // Queued rooms are rejoined automatically once the socket connects
      // (see _handleConnectionSuccess -> _rejoinAllRooms).
      debugPrint('⏳ Queued room join (not connected yet): $roomId');
      return;
    }

    send('room.join', {'roomId': roomId});
    debugPrint('🔀 Joined room: $roomId');
  }

  /// Leaves a single room without touching any others this connection
  /// currently belongs to.
  void leaveRoom(String roomId) {
    if (!_joinedRooms.remove(roomId)) return;

    if (_isConnected) {
      send('room.leave', {'roomId': roomId});
    }
    debugPrint('🚪 Left room: $roomId');
  }

  /// Convenience wrapper for the channel_id/fixture_id shape (matches
  /// ChatScreen's usage and the server's alternate room.join payload).
  void joinChannelFixtureRoom(String channelId, {String? fixtureId}) {
    joinRoom(_roomIdFor(channelId, fixtureId));
  }

  void leaveChannelFixtureRoom(String channelId, {String? fixtureId}) {
    leaveRoom(_roomIdFor(channelId, fixtureId));
  }

  /// Re-sends room.join for every room in _joinedRooms. Called after a
  /// successful (re)connect, since the server has zero memory of rooms
  /// from a dropped connection — this is what makes reconnection actually
  /// restore FixturesPage's live-commentary rooms and a currently-open
  /// ChatScreen's room without the user doing anything.
  void _rejoinAllRooms() {
    if (_joinedRooms.isEmpty) return;
    debugPrint('🔁 Rejoining ${_joinedRooms.length} room(s) after connect');
    for (final roomId in _joinedRooms) {
      send('room.join', {'roomId': roomId});
    }
  }

  // ==========================================================================
  // CONNECTION
  // ==========================================================================

  /// Establishes the socket if not already connected. The channelId/fixtureId
  /// here only seed the initial query-string room (kept for server-side
  /// compatibility with the `connected` welcome payload) — the room is also
  /// added to `_joinedRooms` so it survives reconnects and coexists with any
  /// other rooms joined via joinRoom().
  Future<void> connect(
    String userId,
    String authToken,
    String channelId,
    String username, {
    String? fixtureId,
  }) async {
    final initialRoomId = _roomIdFor(channelId, fixtureId);

    if (_isConnected) {
      // Already connected — just add this room to the set additively.
      joinRoom(initialRoomId);
      return;
    }

    if (_isConnecting) return;

    _currentUserId = userId;
    _currentAuthToken = authToken;
    _currentChannelId = channelId;
    _currentFixtureId = fixtureId;
    _currentUsername = username;
    _isConnecting = true;

    // Track the initial room too, so reconnects restore it.
    _joinedRooms.add(initialRoomId);

    final wsUrl = 'wss://clash-api-m5mr.onrender.com/ws/channel'
        '?user_id=$userId'
        '&username=$username'
        '&channel_id=$channelId'
        '&fixture_id=${fixtureId ?? ''}';

    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = Timer(_connectionTimeout, () {
      if (_isConnecting && !_isConnected) {
        debugPrint(
            '⏱️ WS connection timed out after ${_connectionTimeout.inSeconds}s — retrying');
        _handleConnectionFailure('Connection timed out');
      }
    });

    try {
      _channel = IOWebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );
    } catch (e) {
      _handleConnectionFailure('Connection error: $e');
    }
  }

  void _handleConnectionFailure(String reason) {
    debugPrint('❌ WS connection failure: $reason');

    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimeoutTimer?.cancel();

    _isConnecting = false;
    _isConnected = false;

    _channel?.sink.close();
    _channel = null;

    _connectionStatusController.add(false);
    _scheduleReconnect();
  }

  void _handleConnectionSuccess() {
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = null;

    if (_isConnecting || !_isConnected) {
      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _connectionStatusController.add(true);

      _flushMessageQueue();
      _rejoinAllRooms(); // ✅ restore every room membership after (re)connect
      _startHeartbeat();
    }
  }

  /// Fully tears down the connection AND forgets all room memberships.
  /// Use this only when the whole app is done with sockets (logout, app
  /// dispose) — not for leaving one screen, since that would drop every
  /// other screen's rooms too. Use leaveRoom()/leaveChannelFixtureRoom()
  /// for that instead.
  void disconnect() {
    _connectionTimeoutTimer?.cancel();
    _heartbeatTimer?.cancel();
    _heartbeatTimeoutTimer?.cancel();
    _reconnectTimer?.cancel();

    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    _joinedRooms.clear();
    _connectionStatusController.add(false);
  }

  void _handleDisconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimeoutTimer?.cancel();
    _connectionTimeoutTimer?.cancel();

    if (_isConnecting) {
      // Socket closed before the server's "connected" ack ever arrived —
      // this used to be silently swallowed because _isConnected was still
      // false, leaving the client permanently stuck "connecting" forever.
      _handleConnectionFailure('Socket closed during handshake');
      return;
    }

    if (_isConnected) {
      _isConnected = false;
      // ✅ Deliberately do NOT clear _joinedRooms here — we want to
      // remember them so _rejoinAllRooms() can restore them once the
      // reconnect succeeds.
      _connectionStatusController.add(false);
      _scheduleReconnect();
    }
  }

  void _handleError(Object error) {
    debugPrint('⚠️ WS stream error: $error');
    if (_isConnecting) {
      _handleConnectionFailure('Stream error during handshake: $error');
    } else if (_isConnected) {
      _handleDisconnect();
    }
  }

  void _scheduleReconnect() {
    // Keep retrying indefinitely with a capped backoff instead of giving up
    // after N attempts — during a live match, giving up permanently just
    // because the network blipped 10 times is worse than a slow retry loop.
    final delay = _reconnectAttempts < _maxReconnectAttempts
        ? _initialReconnectDelay * (_reconnectAttempts + 1)
        : const Duration(seconds: 30);

    _reconnectAttempts++;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_currentUserId != null &&
          _currentAuthToken != null &&
          _currentChannelId != null &&
          _currentUsername != null) {
        connect(
          _currentUserId!,
          _currentAuthToken!,
          _currentChannelId!,
          _currentUsername!,
          fixtureId: _currentFixtureId,
        );
      }
    });
  }

  // ==========================================================================
  // HEARTBEAT
  // ==========================================================================

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_isConnected) {
        send('ping', {});

        _heartbeatTimeoutTimer?.cancel();
        _heartbeatTimeoutTimer = Timer(_heartbeatTimeout, () {
          if (_isConnected) {
            _handleDisconnect();
          }
        });
      }
    });
  }

  void _cancelHeartbeatTimeout() {
    _heartbeatTimeoutTimer?.cancel();
    _heartbeatTimeoutTimer = null;
  }

  // ==========================================================================
  // MESSAGE HANDLING
  // ==========================================================================

  void _handleMessage(dynamic message) {
    try {
      final data = json.decode(message as String);
      final eventType = data['type'] as String? ?? 'unknown';
      final payload = data['payload'] as Map<String, dynamic>? ?? {};

      // 🔍 TEMP DEBUG — remove once you've confirmed commentary/chat is
      // flowing correctly across all joined rooms.
      debugPrint('📩 WS RAW: type=$eventType joinedRooms=$_joinedRooms');

      if (eventType == 'connected') {
        _cancelHeartbeatTimeout();
        _handleConnectionSuccess();
        return;
      }

      if (eventType == 'pong') {
        _cancelHeartbeatTimeout();
        return;
      }

      // room.joined / room.left acks — nothing required client-side beyond
      // logging, since _joinedRooms is already updated optimistically by
      // joinRoom()/leaveRoom() at call time.
      if (eventType == 'room.joined' || eventType == 'room.left') {
        debugPrint('📩 $eventType ack: ${payload['room_id']}');
        return;
      }

      if (_listeners.containsKey(eventType)) {
        for (var listener in _listeners[eventType]!) {
          listener(payload);
        }
      }

      if (_listeners.containsKey('*')) {
        for (var listener in _listeners['*']!) {
          listener({'type': eventType, ...payload});
        }
      }
    } catch (e) {
      debugPrint('❌ WS _handleMessage parse error: $e');
    }
  }

  // ==========================================================================
  // SEND MESSAGE
  // ==========================================================================

  void send(String type, Map<String, dynamic> payload) {
    final message = json.encode({
      'type': type,
      'payload': payload,
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add(message);
      } catch (e) {
        _handleDisconnect();
      }
    } else {
      _messageQueue.add({'type': type, 'payload': payload});
    }
  }

  void _flushMessageQueue() {
    if (!_isConnected) return;

    final queued = List<Map<String, dynamic>>.from(_messageQueue);
    _messageQueue.clear();

    for (var message in queued) {
      send(message['type'], message['payload']);
    }
  }

  // ==========================================================================
  // EVENT SUBSCRIPTION
  // ==========================================================================

  void on(String eventType, void Function(Map<String, dynamic>) callback) {
    _listeners.putIfAbsent(eventType, () => []).add(callback);
  }

  void off(String eventType, void Function(Map<String, dynamic>) callback) {
    _listeners[eventType]?.remove(callback);
  }

  void offAll(String eventType) {
    _listeners.remove(eventType);
  }

  void clearAllListeners() {
    _listeners.clear();
  }

  // ==========================================================================
  // DEDICATED MINUTE METHODS
  // ==========================================================================

  /// Request the current minute for a fixture
  void requestCurrentMinute({
    required String fixtureId,
    String? channelId,
  }) {
    if (!_isConnected) {
      debugPrint('⚠️ Cannot request minute: WebSocket not connected');
      _messageQueue.add({
        'type': 'get.minute',
        'payload': {
          'fixtureId': fixtureId,
          if (channelId != null) 'channelId': channelId,
        },
      });
      return;
    }

    final payload = {
      'fixtureId': fixtureId,
    };

    if (channelId != null) {
      payload['channelId'] = channelId;
    }

    send('get.minute', payload);
    debugPrint('📤 Requested current minute for fixture: $fixtureId');
  }

  /// Subscribe to minute updates for a fixture — now just joins that
  /// fixture's room additively, alongside whatever else is already joined.
  void subscribeToMinuteUpdates({
    required String fixtureId,
    required String channelId,
  }) {
    joinChannelFixtureRoom(channelId, fixtureId: fixtureId);
    debugPrint('📡 Subscribed to minute updates for: $fixtureId');
  }

  /// Unsubscribe from minute updates — leaves just that fixture's room.
  void unsubscribeFromMinuteUpdates({
    required String fixtureId,
    required String channelId,
  }) {
    leaveChannelFixtureRoom(channelId, fixtureId: fixtureId);
    debugPrint('📡 Unsubscribed from minute updates for: $fixtureId');
  }

  /// Send a manual minute update (for testing or admin)
  void sendMinuteUpdate({
    required String fixtureId,
    required String channelId,
    required double minute,
    required String status,
    required String minuteDisplay,
  }) {
    if (!_isConnected) {
      debugPrint('⚠️ Cannot send minute update: WebSocket not connected');
      return;
    }

    final payload = {
      'fixture_id': fixtureId,
      'channel_id': channelId,
      'minute': minute,
      'minute_display': minuteDisplay,
      'status': status,
    };

    send('minute.update', payload);
    debugPrint('📤 Sent minute update: $fixtureId → $minuteDisplay');
  }

  // ==========================================================================
  // CHAT METHODS
  // ==========================================================================
  // Add this method to WebSocketService (services/web_soecket.dart)

  /// Sends a chat message, reconnecting once and waiting briefly if the
  /// socket is currently disconnected, instead of failing instantly.
  /// Returns true only if the message was actually handed to a connected
  /// socket — callers own any optimistic-UI revert on false.
  Future<bool> sendChatMessageReliable({
    required String message,
    required String selection,
    required String username,
    required String messageId,
    required String channelId,
    required String fixtureId,
    required String tempId,
    Map<String, dynamic>? replyTo,
    String? imageUrl,
    String? videoUrl,
    String? videoThumbnailUrl,
    bool isImage = false,
    bool isVideo = false,
    Future<void> Function()? onReconnectAttempt,
  }) async {
    if (isConnected) {
      sendChatMessage(
        message: message,
        selection: selection,
        username: username,
        messageId: messageId,
        replyTo: replyTo,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        videoThumbnailUrl: videoThumbnailUrl,
        isImage: isImage,
        isVideo: isVideo,
        channelId: channelId,
        fixtureId: fixtureId,
        tempId: tempId,
      );
      debugPrint('📤 Message sent via WebSocket (channel: $channelId)');
      return true;
    }

    debugPrint('⚠️ WebSocket not connected — attempting reconnect before send');
    if (onReconnectAttempt != null) {
      await onReconnectAttempt();
    }

    const maxWait = Duration(seconds: 4);
    const pollInterval = Duration(milliseconds: 200);
    var waited = Duration.zero;

    while (waited < maxWait) {
      await Future.delayed(pollInterval);
      waited += pollInterval;
      if (isConnected) {
        sendChatMessage(
          message: message,
          selection: selection,
          username: username,
          messageId: messageId,
          replyTo: replyTo,
          imageUrl: imageUrl,
          videoUrl: videoUrl,
          videoThumbnailUrl: videoThumbnailUrl,
          isImage: isImage,
          isVideo: isVideo,
          channelId: channelId,
          fixtureId: fixtureId,
          tempId: tempId,
        );
        debugPrint('📤 Message sent via WebSocket after reconnect ($waited)');
        return true;
      }
    }

    debugPrint('❌ WebSocket still not connected after ${maxWait.inSeconds}s');
    return false;
  }

  void sendChatMessage({
    required String message,
    required String selection,
    required String username,
    required String messageId,
    Map<String, dynamic>? replyTo,
    String? imageUrl,
    String? videoUrl,
    String? videoThumbnailUrl,
    bool isImage = false,
    bool isVideo = false,
    required String channelId,
    String? fixtureId,
    String? tempId,
  }) {
    final payload = {
      'message': message,
      'selection': selection,
      'username': username,
      'userId': _currentUserId,
      'messageId': messageId,
      'replyTo': replyTo,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'videoThumbnailUrl': videoThumbnailUrl,
      'isImage': isImage,
      'isVideo': isVideo,
      'channelId': channelId,
      'fixtureId': fixtureId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (tempId != null && tempId.isNotEmpty) {
      payload['tempId'] = tempId;
    }

    if (!_isConnected) {
      debugPrint('⚠️ Cannot send chat message: WebSocket not connected');
      _messageQueue.add({
        'type': 'chat.message',
        'payload': payload,
      });
      return;
    }

    send('chat.message', payload);
  }

  void sendTyping({
    required String channelId,
    String? fixtureId,
    required bool isTyping,
    required String username,
  }) {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      return;
    }

    final payload = <String, dynamic>{
      'isTyping': isTyping,
      'username': username,
      'channelId': channelId,
      'userId': _currentUserId!,
    };

    if (fixtureId != null && fixtureId.isNotEmpty) {
      payload['fixtureId'] = fixtureId;
    }

    send('typing', payload);
  }

  void sendPing() {
    send('ping', {});
  }

  // ==========================================================================
  // GETTERS
  // ==========================================================================

  bool get isConnected => _isConnected;
  String? get currentUserId => _currentUserId;
  String? get currentChannelId => _currentChannelId;
  String? get currentFixtureId => _currentFixtureId;

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  void dispose() {
    _connectionTimeoutTimer?.cancel();
    _heartbeatTimer?.cancel();
    _heartbeatTimeoutTimer?.cancel();
    _reconnectTimer?.cancel();
    disconnect();
    _connectionStatusController.close();
    _listeners.clear();
  }
}