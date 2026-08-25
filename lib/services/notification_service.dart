import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'permission_status_stub.dart'
    if (dart.library.html) 'permission_status_web.dart';

class NotificationService {
  static const String API_BASE_URL = 'https://clash-api-m5mr.onrender.com/api';

  // ─── Foreground notification stream ────────────────────────────────────────
  static final StreamController<Map<String, dynamic>> _streamController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream specifically for badge updates
  static final StreamController<Map<String, dynamic>> _badgeStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream for join request updates (for admin dashboard)
  static final StreamController<Map<String, dynamic>>
      _joinRequestStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Subscribe to this in home_page.dart to receive foreground messages.
  static Stream<Map<String, dynamic>> get notificationStream =>
      _streamController.stream;

  /// Subscribe to this for badge updates only
  static Stream<Map<String, dynamic>> get badgeStream =>
      _badgeStreamController.stream;

  /// Subscribe to this for join request updates
  static Stream<Map<String, dynamic>> get joinRequestStream =>
      _joinRequestStreamController.stream;

  // Cache keys for unread notifications
  static const String _unreadNotificationsKey = 'unread_notifications';
  static const String _unreadCountKey = 'unread_notification_count';
  static const String _unreadCommentCountKey = 'unread_comment_count';

  // NEW: Cache key for pending join requests
  static const String _pendingJoinRequestsKey = 'pending_join_requests';

  /// Called by main.dart when a foreground FCM message arrives.
  static void pushToStream(Map<String, dynamic> payload) {
    if (!_streamController.isClosed) {
      debugPrint('[NotificationService] 📨 Pushing to stream: $payload');
      _streamController.add(payload);

      // Also handle badge update for this notification
      _handleBadgeUpdate(payload);
    }
  }

  /// Handle badge update when notification arrives
  static Future<void> _handleBadgeUpdate(Map<String, dynamic> payload) async {
    try {
      final rawData = payload['data'] as Map<String, dynamic>? ?? payload;

      Map<String, dynamic> data = rawData;
      final nested = rawData['data'];
      if (nested is String && nested.isNotEmpty) {
        try {
          final decoded = json.decode(nested);
          if (decoded is Map<String, dynamic>) {
            data = {...rawData, ...decoded};
          }
        } catch (e) {
          debugPrint(
              '[NotificationService] ⚠️ Failed to decode nested data string: $e');
        }
      }

      final notificationType =
          data['notificationType'] as String? ?? data['type'] as String?;
      final fixtureId = data['fixture_id'] as String?;

      if (notificationType == null) {
        debugPrint('[NotificationService] ⚠️ Missing notificationType');
        return;
      }

      // ─── HANDLE JOIN REQUEST NOTIFICATIONS ────────────────────────────────
      if (notificationType == 'join_request') {
        final channelId = data['channel_id'] as String?;
        final channelName = data['channel_name'] as String?;
        final userId = data['user_id'] as String?;
        final username = data['username'] as String?;
        final requestId = data['request_id'] as String?;

        debugPrint(
          '[NotificationService] 📥 Join request from $username for channel $channelName',
        );

        await _savePendingJoinRequest(
          channelId: channelId ?? '',
          channelName: channelName ?? 'Unknown Channel',
          userId: userId ?? '',
          username: username ?? 'Unknown User',
          requestId: requestId ?? '',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );

        if (!_joinRequestStreamController.isClosed) {
          _joinRequestStreamController.add({
            'type': 'join_request',
            'channel_id': channelId,
            'channel_name': channelName,
            'user_id': userId,
            'username': username,
            'request_id': requestId,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }

        final newNotificationCount = await _incrementUnreadCount();
        if (!_badgeStreamController.isClosed) {
          _badgeStreamController.add({
            'type': 'notification_badge_update',
            'join_request': true,
            'total_unread_notifications': newNotificationCount,
          });
        }

        debugPrint(
          '[NotificationService] 🔴 Join request notification processed for channel $channelName',
        );
        return;
      }

      // ─── HANDLE JOIN APPROVED NOTIFICATIONS ──────────────────────────────
      if (notificationType == 'join_approved') {
        final channelId = data['channel_id'] as String?;
        final channelName = data['channel_name'] as String?;
        final action = data['action'] as String?;

        debugPrint(
          '[NotificationService] ✅ Join approved for channel $channelName',
        );

        if (channelId != null) {
          await _removePendingJoinRequest(channelId);
        }

        if (!_badgeStreamController.isClosed) {
          _badgeStreamController.add({
            'type': 'join_approved',
            'channel_id': channelId,
            'channel_name': channelName,
            'action': action,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }

        if (!_streamController.isClosed) {
          _streamController.add({
            'type': 'join_approved',
            'title': '✅ Request Approved!',
            'body': 'You have been added to "$channelName" 🎉',
            'data': data,
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
        return;
      }

      // ─── HANDLE JOIN REJECTED NOTIFICATIONS ──────────────────────────────
      if (notificationType == 'join_rejected') {
        final channelId = data['channel_id'] as String?;
        final channelName = data['channel_name'] as String?;

        debugPrint(
          '[NotificationService] ❌ Join rejected for channel $channelName',
        );

        if (channelId != null) {
          await _removePendingJoinRequest(channelId);
        }

        if (!_badgeStreamController.isClosed) {
          _badgeStreamController.add({
            'type': 'join_rejected',
            'channel_id': channelId,
            'channel_name': channelName,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }

        if (!_streamController.isClosed) {
          _streamController.add({
            'type': 'join_rejected',
            'title': '❌ Request Declined',
            'body': 'Your request to join "$channelName" was declined',
            'data': data,
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
        return;
      }

      // ─── HANDLE VOTE / PLEDGE / BET NOTIFICATIONS (Rust dot-separated types) ──
      if (notificationType == 'vote.cast' ||
          notificationType == 'pledge.create' ||
          notificationType == 'bet.matched' ||
          notificationType == 'bet.settled') {
        if (fixtureId == null) {
          debugPrint(
            '[NotificationService] ⚠️ Missing fixture_id for $notificationType',
          );
          return;
        }

        await _saveUnreadNotification(fixtureId, notificationType, data);

        final newCommentCount = await _incrementUnreadCommentCount();

        if (!_badgeStreamController.isClosed) {
          _badgeStreamController.add({
            'type': 'comment_badge_update',
            'fixture_id': fixtureId,
            'has_unread': true,
            'total_unread_comments': newCommentCount,
            'notification_type': notificationType,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }

        debugPrint(
          '[NotificationService] 🔴 Badge updated for $notificationType on fixture $fixtureId, total: $newCommentCount',
        );
        return;
      }

      // ─── EXISTING HANDLERS FOR VOTE/COMMENT NOTIFICATIONS ────────────────
      final isVoteNotification = notificationType == 'vote_supporter' ||
          notificationType == 'vote_rival';
      final isCommentNotification = notificationType == 'fixture_comment' ||
          notificationType == 'fixture_comment_push';

      if (isVoteNotification || isCommentNotification) {
        if (fixtureId == null) {
          debugPrint(
            '[NotificationService] ⚠️ Missing fixture_id for vote/comment notification',
          );
          return;
        }

        await _saveUnreadNotification(fixtureId, notificationType, data);

        final newCommentCount = await _incrementUnreadCommentCount();

        if (!_badgeStreamController.isClosed) {
          _badgeStreamController.add({
            'type': 'comment_badge_update',
            'fixture_id': fixtureId,
            'has_unread': true,
            'total_unread_comments': newCommentCount,
            'notification_type': notificationType,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }

        debugPrint(
          '[NotificationService] 🔴 Comment badge updated for fixture $fixtureId, total comments: $newCommentCount',
        );
      }

      if (notificationType == 'comrade_added') {
        final newNotificationCount = await _incrementUnreadCount();

        if (!_badgeStreamController.isClosed) {
          _badgeStreamController.add({
            'type': 'notification_badge_update',
            'comrade_added': true,
            'total_unread_notifications': newNotificationCount,
          });
        }

        debugPrint(
          '[NotificationService] 🔴 Notification badge updated, total: $newNotificationCount',
        );
      }

      if (notificationType == 'like' || notificationType == 'post_comment') {
        final newNotificationCount = await _incrementUnreadCount();

        if (!_badgeStreamController.isClosed) {
          _badgeStreamController.add({
            'type': 'notification_badge_update',
            'notification_type': notificationType,
            'total_unread_notifications': newNotificationCount,
          });
        }

        debugPrint(
          '[NotificationService] 🔴 Notification badge updated, total: $newNotificationCount',
        );
      }
    } catch (e) {
      debugPrint('[NotificationService] ❌ Badge update error: $e');
    }
  }

  /// Returns 'granted' | 'denied' | 'default' on web, 'unsupported' elsewhere.
  static String getPermissionStatus() {
    if (!kIsWeb) return 'unsupported';
    try {
      return getWebPermissionStatus();
    } catch (e) {
      return 'unsupported';
    }
  }

  // ========================================================================
  // JOIN REQUEST PENDING STORAGE METHODS
  // ========================================================================

  static Future<void> _savePendingJoinRequest({
    required String channelId,
    required String channelName,
    required String userId,
    required String username,
    required String requestId,
    required int timestamp,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingJson = prefs.getString(_pendingJoinRequestsKey);
      List<dynamic> pendingRequests = [];

      if (pendingJson != null) {
        pendingRequests = json.decode(pendingJson);
      }

      final exists = pendingRequests.any(
        (req) => req['channel_id'] == channelId && req['user_id'] == userId,
      );

      if (!exists) {
        pendingRequests.add({
          'channel_id': channelId,
          'channel_name': channelName,
          'user_id': userId,
          'username': username,
          'request_id': requestId,
          'timestamp': timestamp,
          'status': 'pending',
        });

        await prefs.setString(
          _pendingJoinRequestsKey,
          json.encode(pendingRequests),
        );

        debugPrint(
          '[NotificationService] 💾 Saved pending join request for $username -> $channelName',
        );
      }
    } catch (e) {
      debugPrint('[NotificationService] ❌ Save pending request error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingJoinRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingJson = prefs.getString(_pendingJoinRequestsKey);
      if (pendingJson == null) return [];

      final pendingRequests = json.decode(pendingJson);
      return List<Map<String, dynamic>>.from(pendingRequests);
    } catch (e) {
      debugPrint('[NotificationService] ❌ Get pending requests error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingRequestsForChannel(
    String channelId,
  ) async {
    try {
      final allRequests = await getPendingJoinRequests();
      return allRequests
          .where((req) => req['channel_id'] == channelId)
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> _removePendingJoinRequest(String channelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingJson = prefs.getString(_pendingJoinRequestsKey);
      if (pendingJson == null) return;

      List<dynamic> pendingRequests = json.decode(pendingJson);
      pendingRequests.removeWhere(
        (req) => req['channel_id'] == channelId,
      );

      await prefs.setString(
        _pendingJoinRequestsKey,
        json.encode(pendingRequests),
      );

      debugPrint(
        '[NotificationService] 🗑️ Removed pending request for channel $channelId',
      );
    } catch (e) {
      debugPrint('[NotificationService] ❌ Remove pending request error: $e');
    }
  }

  static Future<void> removePendingRequestById(String requestId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingJson = prefs.getString(_pendingJoinRequestsKey);
      if (pendingJson == null) return;

      List<dynamic> pendingRequests = json.decode(pendingJson);
      pendingRequests.removeWhere(
        (req) => req['request_id'] == requestId,
      );

      await prefs.setString(
        _pendingJoinRequestsKey,
        json.encode(pendingRequests),
      );

      debugPrint(
        '[NotificationService] 🗑️ Removed pending request $requestId',
      );
    } catch (e) {
      debugPrint('[NotificationService] ❌ Remove pending request error: $e');
    }
  }

  static Future<bool> hasPendingRequest({
    required String channelId,
    required String userId,
  }) async {
    try {
      final requests = await getPendingJoinRequests();
      return requests.any(
        (req) => req['channel_id'] == channelId && req['user_id'] == userId,
      );
    } catch (e) {
      return false;
    }
  }

  static Future<void> clearAllPendingRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingJoinRequestsKey);
      debugPrint('[NotificationService] 🗑️ Cleared all pending requests');
    } catch (e) {
      debugPrint('[NotificationService] ❌ Clear pending requests error: $e');
    }
  }

  // ========================================================================
  // EXISTING METHODS (unchanged)
  // ========================================================================

  static Future<void> _saveUnreadNotification(
    String fixtureId,
    String notificationType,
    Map<String, dynamic> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unreadJson = prefs.getString(_unreadNotificationsKey);
      Map<String, dynamic> unreadMap = {};

      if (unreadJson != null) {
        unreadMap = json.decode(unreadJson);
      }

      if (!unreadMap.containsKey(fixtureId)) {
        unreadMap[fixtureId] = {
          'has_unread': true,
          'types': <String>[],
          'last_notification_time': DateTime.now().millisecondsSinceEpoch,
          'notification_data': [],
        };
      }

      final fixtureData = unreadMap[fixtureId] as Map<String, dynamic>;
      final types = List<String>.from(fixtureData['types'] ?? []);

      if (!types.contains(notificationType)) {
        types.add(notificationType);
        fixtureData['types'] = types;
      }

      fixtureData['last_notification_time'] =
          DateTime.now().millisecondsSinceEpoch;

      List<dynamic> notifications = List.from(
        fixtureData['notification_data'] ?? [],
      );
      notifications.insert(0, {
        'type': notificationType,
        'title': data['title'] ?? '',
        'body': data['body'] ?? '',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': data,
      });

      if (notifications.length > 10) {
        notifications = notifications.take(10).toList();
      }
      fixtureData['notification_data'] = notifications;

      await prefs.setString(_unreadNotificationsKey, json.encode(unreadMap));
    } catch (e) {
      debugPrint('[NotificationService] ❌ Save unread error: $e');
    }
  }

  static Future<bool> hasUnreadForFixture(String fixtureId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unreadJson = prefs.getString(_unreadNotificationsKey);
      if (unreadJson == null) return false;

      final unreadMap = json.decode(unreadJson);
      return unreadMap[fixtureId]?['has_unread'] == true;
    } catch (e) {
      return false;
    }
  }

  static Future<int> getUnreadCountForFixture(String fixtureId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unreadJson = prefs.getString(_unreadNotificationsKey);
      if (unreadJson == null) return 0;

      final unreadMap = json.decode(unreadJson);
      final fixtureData = unreadMap[fixtureId] as Map<String, dynamic>?;
      if (fixtureData == null) return 0;

      final notificationData = fixtureData['notification_data'] as List? ?? [];
      return notificationData.length;
    } catch (e) {
      return 0;
    }
  }

  static Future<Map<String, Map<String, dynamic>>> getAllUnreadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unreadJson = prefs.getString(_unreadNotificationsKey);

      if (unreadJson == null) {
        return {};
      }

      final unreadMap = json.decode(unreadJson);
      final result = <String, Map<String, dynamic>>{};

      for (var entry in unreadMap.entries) {
        final fixtureId = entry.key.toString();
        final data = entry.value as Map<String, dynamic>;

        if (data['has_unread'] == true) {
          final notificationData = data['notification_data'] as List? ?? [];
          final unreadCount = notificationData.length;

          result[fixtureId] = {
            'count': unreadCount,
            'has_unread': true,
            'types': data['types'] ?? [],
            'last_notification_time': data['last_notification_time'],
            'latest_notification':
                notificationData.isNotEmpty ? notificationData[0] : null,
          };
        }
      }

      debugPrint(
        '[NotificationService] 📊 Loaded unread data for ${result.length} fixtures',
      );
      return result;
    } catch (e) {
      debugPrint('[NotificationService] ❌ getAllUnreadData error: $e');
      return {};
    }
  }

  static Future<List<String>> getAllUnreadFixtures() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unreadJson = prefs.getString(_unreadNotificationsKey);
      if (unreadJson == null) return [];

      final unreadMap = json.decode(unreadJson);
      final List<String> result = [];

      unreadMap.forEach((fixtureId, data) {
        if (data['has_unread'] == true) {
          result.add(fixtureId.toString());
        }
      });

      return result;
    } catch (e) {
      debugPrint('[NotificationService] ❌ Get unread fixtures error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> getAllUnreadFixturesWithDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unreadJson = prefs.getString(_unreadNotificationsKey);
      if (unreadJson == null) return {};

      final unreadMap = json.decode(unreadJson);
      final result = <String, dynamic>{};

      unreadMap.forEach((fixtureId, data) {
        if (data['has_unread'] == true) {
          result[fixtureId] = {
            'has_unread': true,
            'types': data['types'] ?? [],
            'last_notification_time': data['last_notification_time'],
            'latest_notification': data['notification_data']?.isNotEmpty == true
                ? data['notification_data'][0]
                : null,
            'notification_count':
                (data['notification_data'] as List?)?.length ?? 0,
          };
        }
      });

      return result;
    } catch (e) {
      debugPrint(
        '[NotificationService] ❌ Get unread fixtures details error: $e',
      );
      return {};
    }
  }

  static Future<void> markFixtureAsRead(String fixtureId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unreadJson = prefs.getString(_unreadNotificationsKey);

      if (unreadJson != null) {
        final unreadMap = json.decode(unreadJson);
        if (unreadMap.containsKey(fixtureId)) {
          final count =
              (unreadMap[fixtureId]['notification_data'] as List?)?.length ?? 0;

          unreadMap[fixtureId]['has_unread'] = false;
          unreadMap[fixtureId]['types'] = [];

          await prefs.setString(
            _unreadNotificationsKey,
            json.encode(unreadMap),
          );

          for (int i = 0; i < count; i++) {
            await _decrementUnreadCommentCount();
          }

          if (!_badgeStreamController.isClosed) {
            _badgeStreamController.add({
              'type': 'comment_badge_cleared',
              'fixture_id': fixtureId,
              'total_unread_comments': await _getUnreadCommentCount(),
            });
          }

          debugPrint(
            '[NotificationService] ✅ Marked fixture $fixtureId as read (cleared $count comment notifications)',
          );
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] ❌ Mark read error: $e');
    }
  }

  static Future<void> markAllCommentsAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_unreadNotificationsKey);
      await prefs.setInt(_unreadCommentCountKey, 0);

      if (!_badgeStreamController.isClosed) {
        _badgeStreamController.add({
          'type': 'comment_badge_cleared_all',
          'total_unread_comments': 0,
        });
      }

      debugPrint(
        '[NotificationService] ✅ Marked all comment notifications as read',
      );
    } catch (e) {
      debugPrint('[NotificationService] ❌ Mark all comments read error: $e');
    }
  }

  static Future<void> markAllNotificationsAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_unreadCountKey, 0);

      if (!_badgeStreamController.isClosed) {
        _badgeStreamController.add({
          'type': 'notification_badge_cleared_all',
          'total_unread_notifications': 0,
        });
      }

      debugPrint('[NotificationService] ✅ Marked all notifications as read');
    } catch (e) {
      debugPrint(
        '[NotificationService] ❌ Mark all notifications read error: $e',
      );
    }
  }

  static Future<int> _getUnreadCommentCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_unreadCommentCountKey) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<int> getTotalUnreadCommentCount() async {
    return await _getUnreadCommentCount();
  }

  static Future<int> _getUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_unreadCountKey) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<int> getTotalUnreadNotificationCount() async {
    return await _getUnreadCount();
  }

  static Future<int> _incrementUnreadCommentCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_unreadCommentCountKey) ?? 0;
      final newCount = current + 1;
      await prefs.setInt(_unreadCommentCountKey, newCount);
      return newCount;
    } catch (e) {
      return 0;
    }
  }

  static Future<int> _decrementUnreadCommentCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_unreadCommentCountKey) ?? 0;
      final newCount = current > 0 ? current - 1 : 0;
      await prefs.setInt(_unreadCommentCountKey, newCount);
      return newCount;
    } catch (e) {
      return 0;
    }
  }

  static Future<int> _incrementUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_unreadCountKey) ?? 0;
      final newCount = current + 1;
      await prefs.setInt(_unreadCountKey, newCount);
      return newCount;
    } catch (e) {
      return 0;
    }
  }

  static Future<int> _decrementUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_unreadCountKey) ?? 0;
      final newCount = current > 0 ? current - 1 : 0;
      await prefs.setInt(_unreadCountKey, newCount);
      return newCount;
    } catch (e) {
      return 0;
    }
  }

  static Future<void> markFixtureAsUnread(
    String fixtureId,
    String notificationType,
    Map<String, dynamic> data,
  ) async {
    await _saveUnreadNotification(fixtureId, notificationType, data);
    await _incrementUnreadCommentCount();
  }

  static Future<void> clearUnreadForFixture(String fixtureId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unreadJson = prefs.getString(_unreadNotificationsKey);

      if (unreadJson != null) {
        final unreadMap = json.decode(unreadJson);
        if (unreadMap.containsKey(fixtureId)) {
          final count =
              (unreadMap[fixtureId]['notification_data'] as List?)?.length ?? 0;

          unreadMap.remove(fixtureId);
          await prefs.setString(
            _unreadNotificationsKey,
            json.encode(unreadMap),
          );

          for (int i = 0; i < count; i++) {
            await _decrementUnreadCommentCount();
          }

          debugPrint(
            '[NotificationService] ✅ Cleared all unread for fixture $fixtureId',
          );
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] ❌ Clear unread error: $e');
    }
  }

  // ─── Token registration ────────────────────────────────────────────────────
  static Future<bool> registerToken({
    required String userId,
    required String fcmToken,
    required String platform,
    String? authToken,
  }) async {
    try {
      debugPrint('[NotificationService] 📤 Registering token for user $userId');
      debugPrint(
        '[NotificationService] 📱 Platform: $platform — '
        'token: ${fcmToken.length > 20 ? fcmToken.substring(0, 20) : fcmToken}…',
      );

      final requestBody = {
        'user_id': userId,
        'fcm_token': fcmToken,
        'platform': platform,
      };

      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/notifications/register-token'),
            headers: {
              'Content-Type': 'application/json',
              if (authToken != null && authToken.isNotEmpty)
                'Authorization': 'Bearer $authToken',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint(
        '[NotificationService] 📥 Register token response: '
        '${response.statusCode} — ${response.body}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final success = data['success'] == true;
        debugPrint(
          success
              ? '[NotificationService] ✅ Token registered'
              : '[NotificationService] ❌ Token registration returned success=false',
        );
        return success;
      }

      debugPrint(
        '[NotificationService] ❌ Token registration failed: ${response.statusCode}',
      );
      return false;
    } catch (e) {
      debugPrint('[NotificationService] ❌ registerToken error: $e');
      return false;
    }
  }

  // ─── Send notification ─────────────────────────────────────────────────────
  static Future<bool> sendNotification({
    required String userId,
    required String notificationType,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      debugPrint(
        '[NotificationService] 📤 Sending "$notificationType" to $userId',
      );

      final requestBody = {
        'user_id': userId,
        'notification_type': notificationType,
        'title': title,
        'body': body,
        'data': data,
      };

      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/notifications/send'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 5));

      debugPrint(
        '[NotificationService] 📥 Send response: '
        '${response.statusCode} — ${response.body}',
      );

      final success = response.statusCode == 200;
      debugPrint(
        success
            ? '[NotificationService] ✅ Notification delivered to $userId'
            : '[NotificationService] ❌ Notification FAILED for $userId '
                '(status ${response.statusCode})',
      );
      return success;
    } catch (e) {
      debugPrint('[NotificationService] ❌ sendNotification error: $e');
      return false;
    }
  }

  // ─── Mark as read (server sync) ──────────────────────────────────────────
  static Future<void> markAsRead({
    required String userId,
    List<String>? notificationIds,
  }) async {
    try {
      final requestBody = <String, dynamic>{'user_id': userId};
      if (notificationIds != null) {
        requestBody['notification_ids'] = notificationIds;
      }

      await http
          .post(
            Uri.parse('$API_BASE_URL/notifications/mark-read'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[NotificationService] ❌ markAsRead error: $e');
    }
  }

  // ─── Comrade notifications ─────────────────────────────────────────────────
  static void handleComradeNotification(Map<String, dynamic> data) {
    final type = data['type'] ?? '';

    if (type == 'comrade_added') {
      final username = data['username'] ?? 'Someone';
      debugPrint('📱 New comrade added: $username added you!');

      _streamController.add({
        'type': 'comrade_added',
        'title': 'New Comrade! 🎉',
        'body': '$username added you as a comrade',
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _incrementUnreadCount().then((newCount) {
        _badgeStreamController.add({
          'type': 'notification_badge_update',
          'comrade_added': true,
          'total_unread_notifications': newCount,
        });
      });
    }
  }

  static Future<bool> notifyComradeAdded({
    required String userId,
    required String comradeUsername,
    required String authToken,
  }) async {
    return await sendNotification(
      userId: userId,
      notificationType: 'comrade_added',
      title: 'New Comrade! 🎉',
      body: '$comradeUsername added you as a comrade',
      data: {
        'type': 'comrade_added',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // ─── Preferences ───────────────────────────────────────────────────────────
  static Future<Map<String, bool>> getNotificationPreferences(
    String userId,
  ) async {
    const defaults = {
      'vote_alerts': true,
      'like_alerts': true,
      'comment_alerts': true,
    };

    try {
      final response = await http
          .get(Uri.parse('$API_BASE_URL/notifications/preferences/$userId'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'vote_alerts': data['vote_alerts'] ?? true,
          'like_alerts': data['like_alerts'] ?? true,
          'comment_alerts': data['comment_alerts'] ?? true,
        };
      }
    } catch (e) {
      debugPrint('[NotificationService] ❌ getPreferences error: $e');
    }

    return defaults;
  }

  static Future<bool> updateNotificationPreferences({
    required String userId,
    required bool voteAlerts,
    required bool likeAlerts,
    required bool commentAlerts,
    String? authToken,
  }) async {
    try {
      final requestBody = {
        'user_id': userId,
        'vote_alerts': voteAlerts,
        'like_alerts': likeAlerts,
        'comment_alerts': commentAlerts,
      };

      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/notifications/preferences'),
            headers: {
              'Content-Type': 'application/json',
              if (authToken != null) 'Authorization': 'Bearer $authToken',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[NotificationService] ❌ updatePreferences error: $e');
      return false;
    }
  }

  // ─── Load initial badge counts on app start ────────────────────────────────
  static Future<Map<String, int>> loadInitialBadgeCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final commentCount = prefs.getInt(_unreadCommentCountKey) ?? 0;
      final notificationCount = prefs.getInt(_unreadCountKey) ?? 0;

      debugPrint(
        '[NotificationService] 📊 Initial counts - Comments: $commentCount, Notifications: $notificationCount',
      );

      return {
        'unread_comments': commentCount,
        'unread_notifications': notificationCount,
      };
    } catch (e) {
      debugPrint('[NotificationService] ❌ loadInitialBadgeCounts error: $e');
      return {'unread_comments': 0, 'unread_notifications': 0};
    }
  }

  static Future<int> getTotalUnreadCount() async {
    return await _getUnreadCount();
  }

  // ─── Cleanup ───────────────────────────────────────────────────────────────
  static void dispose() {
    if (!_streamController.isClosed) {
      _streamController.close();
    }
    if (!_badgeStreamController.isClosed) {
      _badgeStreamController.close();
    }
    if (!_joinRequestStreamController.isClosed) {
      _joinRequestStreamController.close();
    }
  }
}
