// ============================================================
// HISTORY PAGE - Aftermatch Only with Voter List + Comments
// Redesigned: slim, minimal, backgroundless-text UI
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../utils/add_helper.dart';

import '../../modals/Funzy/chat_screen.dart';
import '../modals/Funzy/swipabledialogue.dart';
import '../../models/fixture_models.dart' as fixture_models;
import 'fan_Funzy_design.dart';
import '../models/user_channel.dart';
import '../../main.dart';
import '../modals/Funzy/match_details.dart';
import '../modals/Funzy/aftermatch_modal.dart';
import '../../services/web_soecket.dart';
import "../screens/home_page.dart";

// ============================================================
// USE VOTER FROM FIXTURE_MODELS DIRECTLY
// ============================================================

// Voter is already defined in fixture_models.dart
// We access it as fixture_models.Voter

// ============================================================
// FIXTURE COMMENT - Defined locally (not in fixture_models)
// ============================================================

class FixtureComment {
  final String id;
  final String userId;
  final String username;
  final String fixtureId;
  final String comment;
  final String? selection;
  final DateTime timestamp;

  FixtureComment({
    required this.id,
    required this.userId,
    required this.username,
    required this.fixtureId,
    required this.comment,
    this.selection,
    required this.timestamp,
  });

  factory FixtureComment.fromJson(Map<String, dynamic> json) {
    String id = '';
    if (json['_id'] != null) {
      if (json['_id'] is Map) {
        id = json['_id']['\$oid'] ?? json['_id']['oid'] ?? '';
      } else if (json['_id'] is String) {
        id = json['_id'];
      }
    }

    DateTime timestamp;
    try {
      timestamp = DateTime.parse(
        json['timestamp'] ??
            json['createdAt'] ??
            json['sent_at']?['\$date'] ??
            DateTime.now().toIso8601String(),
      );
    } catch (e) {
      timestamp = DateTime.now();
    }

    return FixtureComment(
      id: id,
      userId: json['userId']?.toString() ??
          json['user_id']?.toString() ??
          json['sender_id']?.toString() ??
          '',
      username: json['username']?.toString() ??
          json['user_name']?.toString() ??
          json['sender_name']?.toString() ??
          'Anonymous',
      fixtureId:
          json['fixtureId']?.toString() ?? json['fixture_id']?.toString() ?? '',
      comment: json['comment']?.toString() ?? json['text']?.toString() ?? '',
      selection: json['selection']?.toString(),
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'fixtureId': fixtureId,
      'comment': comment,
      'selection': selection,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

// ============================================================
// DATE HELPER
// ============================================================

class HistoryDateHelper {
  static String formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return DateFormat('MMM d').format(date);
  }

  static String formatFullDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM d, HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }
}

// ============================================================
// HISTORY ITEM MODEL
// ============================================================

class HistoryItem {
  final String fixtureId;
  final String channelId;
  final String channelName;
  final String homeTeam;
  final String awayTeam;
  final String matchName;
  DateTime lastActivity;
  String lastMessage;
  String? lastSender;
  final int unreadCount;
  final bool hasVoted;
  int commentCount;
  final DateTime? matchTime;
  final String league;
  int homeScore;
  int awayScore;
  String status;
  final String? winner;
  List<fixture_models.Voter> voters;
  List<FixtureComment> comments;

  HistoryItem({
    required this.fixtureId,
    required this.channelId,
    required this.channelName,
    required this.homeTeam,
    required this.awayTeam,
    required this.matchName,
    required this.lastActivity,
    required this.lastMessage,
    this.lastSender,
    this.unreadCount = 0,
    this.hasVoted = false,
    this.commentCount = 0,
    this.matchTime,
    this.league = '',
    this.homeScore = 0,
    this.awayScore = 0,
    this.status = 'completed',
    this.winner,
    this.voters = const [],
    this.comments = const [],
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      fixtureId: json['fixture_id']?.toString() ?? '',
      channelId: json['channel_id']?.toString() ?? '',
      channelName: json['channel_name']?.toString() ?? '',
      homeTeam: json['home_team']?.toString() ?? '',
      awayTeam: json['away_team']?.toString() ?? '',
      matchName: json['match_name']?.toString() ?? '',
      lastActivity: DateTime.parse(
          json['last_activity'] ?? DateTime.now().toIso8601String()),
      lastMessage: json['last_message']?.toString() ?? '',
      lastSender: json['last_sender']?.toString(),
      unreadCount: json['unread_count'] as int? ?? 0,
      hasVoted: json['has_voted'] as bool? ?? false,
      commentCount: json['comment_count'] as int? ?? 0,
      matchTime: json['match_time'] != null
          ? DateTime.parse(json['match_time'])
          : null,
      league: json['league']?.toString() ?? '',
      homeScore: json['home_score'] as int? ?? 0,
      awayScore: json['away_score'] as int? ?? 0,
      status: json['status']?.toString() ?? 'completed',
      winner: json['winner']?.toString(),
      voters: (json['voters'] as List? ?? [])
          .map((v) => fixture_models.Voter.fromJson(v))
          .toList(),
      comments: (json['comments'] as List? ?? [])
          .map((c) => FixtureComment.fromJson(c))
          .toList(),
    );
  }

  factory HistoryItem.fromFixture(fixture_models.Fixture fixture) {
    final channelId =
        AppCache.channelFixtures[fixture.matchId]?.channelId ?? '';
    final channelName = AppCache.channelFixtures[fixture.matchId]?.matchName ??
        '${fixture.homeTeam} vs ${fixture.awayTeam}';
    final lastMessage =
        AppCache.getLatestComment(fixture.matchId) ?? 'No messages yet';
    final lastSender = AppCache.getLatestCommentAuthor(fixture.matchId);
    final commentCount =
        AppCache.channelFixtures[fixture.matchId]?.commentCount ?? 0;
    final userVote = AppCache.userVotes[fixture.matchId];

    return HistoryItem(
      fixtureId: fixture.matchId,
      channelId: channelId,
      channelName: channelName,
      homeTeam: fixture.homeTeam,
      awayTeam: fixture.awayTeam,
      matchName: '${fixture.homeTeam} vs ${fixture.awayTeam}',
      lastActivity: fixture.dateIso.isNotEmpty
          ? DateTime.tryParse(fixture.dateIso) ?? DateTime.now()
          : DateTime.now(),
      lastMessage: lastMessage,
      lastSender: lastSender,
      unreadCount: 0,
      hasVoted: userVote != null,
      commentCount: commentCount,
      matchTime: fixture.dateIso.isNotEmpty
          ? DateTime.tryParse(fixture.dateIso)
          : null,
      league: fixture.league,
      homeScore: fixture.homeScore ?? 0,
      awayScore: fixture.awayScore ?? 0,
      status: fixture.status,
      winner: fixture.result,
      voters: [],
      comments: [],
    );
  }

  bool get isCompleted => status == 'completed' || status == 'finished';
}

// ============================================================
// VOTER DOT — compact overlapping avatar, ring color = pick
// ============================================================

class _VoterDot extends StatelessWidget {
  final fixture_models.Voter voter;
  final bool isUser;
  final String homeTeam;
  final String awayTeam;

  const _VoterDot({
    required this.voter,
    required this.isUser,
    required this.homeTeam,
    required this.awayTeam,
  });

  @override
  Widget build(BuildContext context) {
    final selectionDisplay = voter.selection == 'home_team'
        ? homeTeam
        : voter.selection == 'away_team'
            ? awayTeam
            : voter.selection == 'draw'
                ? 'Draw'
                : (voter.selection ?? '');
    final color = voter.selection == 'home_team'
        ? FanColors.primary
        : voter.selection == 'away_team'
            ? FanColors.away
            : FanColors.draw;
    final isWinner = voter.isCorrect == true;

    return Tooltip(
      message:
          '${voter.userName} voted for $selectionDisplay${isWinner ? ' • Won' : ''}',
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: FanColors.surface,
          border: Border.all(
            color: isWinner ? FanColors.primary : color.withOpacity(0.5),
            width: isWinner ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            isUser
                ? 'Y'
                : (voter.userName.isNotEmpty
                    ? voter.userName[0].toUpperCase()
                    : '?'),
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: isWinner ? FanColors.primary : color,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SLIM COMMENT INPUT — backgroundless, underline style
// ============================================================

class _SpeechBubbleInput extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final String hintText;
  final VoidCallback? onSend;
  final Function(String)? onSubmitted;

  const _SpeechBubbleInput({
    required this.controller,
    required this.enabled,
    required this.hintText,
    this.onSend,
    this.onSubmitted,
  });

  @override
  State<_SpeechBubbleInput> createState() => _SpeechBubbleInputState();
}

class _SpeechBubbleInputState extends State<_SpeechBubbleInput> {
  bool _hasText = false;
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_updateHasText);
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  void _updateHasText() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (_hasText != hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateHasText);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color lineColor = widget.enabled
        ? (_focused
            ? FanColors.primary.withValues(alpha: 0.5)
            : FanColors.border.withValues(alpha: 0.25))
        : FanColors.border.withValues(alpha: 0.12);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: lineColor, width: 1)),
      ),
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: widget.enabled
                    ? FanColors.textPrimary
                    : FanColors.textTertiary.withValues(alpha: 0.6),
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: FanColors.textTertiary.withValues(alpha: 0.6),
                  fontStyle:
                      widget.enabled ? FontStyle.normal : FontStyle.italic,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              maxLines: null,
              onChanged: (_) => setState(() {}),
              onSubmitted: (value) {
                final trimmed = value.trim();
                if (widget.enabled && trimmed.isNotEmpty) {
                  widget.onSubmitted?.call(trimmed);
                  widget.controller.clear();
                }
              },
            ),
          ),
          if (widget.enabled && _hasText)
            GestureDetector(
              onTap: widget.onSend,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 1),
                child: Icon(
                  Icons.arrow_upward_rounded,
                  size: 16,
                  color: FanColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// TOAST HELPER - Using existing ToastHelper from main
// ============================================================

// The ToastHelper is already imported from main.dart
// Using ToastHelper.showSuccess, ToastHelper.showError, etc.

// ============================================================
// HISTORY PAGE STATE
// ============================================================

class HistoryPage extends StatefulWidget {
  final String userId;
  final String username;
  final String? authToken;
  final bool isLoggedIn;
  final List<UserChannel> userChannels;
  final ScrollController? scrollController;

  const HistoryPage({
    super.key,
    required this.userId,
    required this.username,
    this.authToken,
    this.isLoggedIn = false,
    this.userChannels = const [],
    this.scrollController,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  List<HistoryItem> _historyItems = [];
  List<fixture_models.Fixture> _liveGames = [];
  bool _loading = true;
  bool _loadingLiveGames = false;
  String _error = '';
  String _activeTab = 'history';

  Timer? _refreshTimer;
  StreamSubscription? _appCacheSubscription;

  static const String API_BASE_URL = 'https://clash-api-m5mr.onrender.com/api';
  static const Duration REQUEST_TIMEOUT = Duration(seconds: 15);

  final Map<String, List<fixture_models.Voter>> _votersCache = {};
  final Map<String, bool> _votersLoading = {};
  final Map<String, String> _winnerCache = {};

  // Comment controllers
  final Map<String, TextEditingController> _commentControllers = {};
  final Map<String, bool> _loadingComment = {};
  final Map<String, List<FixtureComment>> _fixtureComments = {};
  final Map<String, int> _commentCounts = {};
  final Map<String, bool> _isPosting = {};

  // WebSocket
  bool _wsConnected = false;
  bool _wsStatusListenerAttached = false;

  // Random for mock comments
  final Random _random = Random();

  // Sample data for mock comments
  final List<String> _sampleUsernames = [
    '⚽ GoalMachine',
    '🔥 FireStriker',
    '🛡️ DefenseWall',
    '🎯 Sniper',
    '💪 PowerShot',
    '✨ MagicFeet',
    '🏃 SpeedDemon',
    '🧠 TacticalGenius',
    '🌟 StarPlayer',
    '🎭 FalseNine',
    '⚡ LightningBolt',
    '🎨 Playmaker',
    '🔒 CleanSheet',
    '🎪 CircusSave',
    '🏆 ChampionMind',
    '📊 AnalystPro',
  ];

  final List<String> _sampleComments = [
    "What a match this was! 🔥",
    "Home team dominated today 💪",
    "Away team showed great spirit 📈",
    "Can't believe that result! ⏰",
    "This rivalry never disappoints ⚔️",
    "Both teams gave it their all 🎯",
    "The atmosphere was electric ⚡",
    "Key players made the difference 👀",
    "So many goals! 🥅",
    "Defensive battle 🛡️",
    "Midfield controlled the game 🧠",
    "History was made today 📚",
    "Underdogs surprised everyone 🐕",
    "Star player was incredible 🙌",
    "Perfect football weather ☀️",
    "A must-watch match 🏆",
  ];

  @override
  void initState() {
    super.initState();
    FanTheme.controller.addListener(_onThemeChanged);
    _loadHistory();
    _loadLiveGamesFromCache();

    _appCacheSubscription = AppCache.fixturesStream.listen((fixtures) {
      if (mounted) {
        debugPrint('🔄 AppCache updated - refreshing live games');
        _loadLiveGamesFromCache();
        _loadHistory(forceRefresh: true);
      }
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        debugPrint('⏰ Periodic refresh - updating data');
        _loadLiveGamesFromCache();
        _loadHistory(forceRefresh: true);
      }
    });

    WidgetsBinding.instance.addObserver(this);

    // Connect WebSocket if logged in
    if (widget.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _connectWebSocket();
      });
    }
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 App resumed - refreshing data');
      _loadLiveGamesFromCache();

      // ✅ Only force a network refetch if history data is actually stale —
      // was previously unconditional, causing the same reload flash pattern.
      final now = DateTime.now();
      final isStale = _lastHistoryFetchTime == null ||
          now.difference(_lastHistoryFetchTime!) > const Duration(minutes: 2);
      _loadHistory(forceRefresh: isStale);

      if (widget.isLoggedIn && !_wsConnected) {
        _connectWebSocket();
      }
    }
  }

  // ============================================================
  // WEB SOCKET CONNECTION
  // ============================================================

  void _connectWebSocket() {
    if (!widget.isLoggedIn) {
      debugPrint('🔌 Skipping WebSocket - not logged in');
      return;
    }

    final ws = WebSocketService();

    if (!_wsStatusListenerAttached) {
      _wsStatusListenerAttached = true;
      ws.connectionStatus.listen((connected) {
        if (connected) {
          debugPrint('✅ HistoryPage WebSocket connected');
          _wsConnected = true;
          _joinAllFixtureRooms();
        } else {
          debugPrint('⚠️ HistoryPage WebSocket disconnected');
          _wsConnected = false;
          if (!_loading && mounted) {
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted && !_wsConnected) {
                _connectWebSocket();
              }
            });
          }
        }
      });
    }

    // ✅ FIX: Pass the required arguments
    if (!ws.isConnected) {
      final channelId = widget.userChannels.isNotEmpty
          ? widget.userChannels.first.channelId
          : null;

      ws.connect(
        widget.userId,
        widget.authToken ?? '',
        channelId ?? '',
        widget.username,
      );
    } else {
      _wsConnected = true;
      _joinAllFixtureRooms();
    }

    _setupWebSocketListeners();
  }

  void _joinAllFixtureRooms() {
    final ws = WebSocketService();
    if (!ws.isConnected) return;

    for (var fixture in _liveGames) {
      final item = _historyItems.firstWhere(
        (h) => h.fixtureId == fixture.matchId,
        orElse: () => HistoryItem.fromFixture(fixture),
      );
      final channelId = _resolveChannelIdFor(item);
      if (channelId == null) continue;
      ws.joinChannelFixtureRoom(channelId, fixtureId: fixture.matchId);
    }

    for (var item in _historyItems) {
      if (item.status == 'live' || item.status == 'half_time') {
        final channelId = _resolveChannelIdFor(item);
        if (channelId == null) continue;
        ws.joinChannelFixtureRoom(channelId, fixtureId: item.fixtureId);
      }
    }
  }

  // ============================================================
  // WEB SOCKET LISTENERS
  // ============================================================
  bool _wsListenersSetup = false;

  void _setupWebSocketListeners() {
    if (_wsListenersSetup) return;
    _wsListenersSetup = true;
    final ws = WebSocketService();

    // Listen for new comments

    // Listen for match status updates
    ws.on('match.status', (payload) {
      final fixtureId = payload['fixture_id']?.toString();
      final status = payload['status']?.toString();
      final homeScore = payload['home_score'] as int?;
      final awayScore = payload['away_score'] as int?;
      final timeElapsed = (payload['timeElapsed'] as num?)?.toDouble();

      if (fixtureId == null || status == null) return;

      debugPrint('📺 Match status update via WebSocket: $fixtureId -> $status');

      _safeSetState(() {
        // Update live games
        final index = _liveGames.indexWhere((f) => f.matchId == fixtureId);
        if (index != -1) {
          final old = _liveGames[index];
          _liveGames[index] = fixture_models.Fixture(
            id: old.id,
            matchId: old.matchId,
            homeTeam: old.homeTeam,
            awayTeam: old.awayTeam,
            league: old.league,
            homeWin: old.homeWin,
            awayWin: old.awayWin,
            draw: old.draw,
            date: old.date,
            time: old.time,
            homeScore: homeScore ?? old.homeScore,
            awayScore: awayScore ?? old.awayScore,
            status: status,
            isLive: status == 'live' || status == 'half_time',
            availableForVoting: false,
            source: old.source,
            scrapedAt: old.scrapedAt,
            dateIso: old.dateIso,
            subFixtures: old.subFixtures,
            timeElapsed: timeElapsed ?? old.timeElapsed,
          );
        }

        // Update history item if it's in history
        final hIndex =
            _historyItems.indexWhere((h) => h.fixtureId == fixtureId);
        if (hIndex != -1) {
          _historyItems[hIndex].status = status;
          _historyItems[hIndex].homeScore =
              homeScore ?? _historyItems[hIndex].homeScore;
          _historyItems[hIndex].awayScore =
              awayScore ?? _historyItems[hIndex].awayScore;
        }
      });

      // If match is completed, refresh history
      if (status == 'completed' || status == 'finished') {
        _loadHistory(forceRefresh: true);
      }
    });

    // Listen for goal events
    ws.on('goal', (payload) {
      final fixtureId = payload['fixture_id']?.toString();
      final homeScore = payload['home_score'] as int? ?? 0;
      final awayScore = payload['away_score'] as int? ?? 0;
      final minute = payload['minute'] as int? ?? 0;
      final scorer = payload['scorer']?.toString() ?? 'Unknown';
      final minuteDisplay = payload['minute_display']?.toString() ?? "$minute'";
      final timeElapsed =
          (payload['timeElapsed'] as num?)?.toDouble() ?? minute.toDouble();

      if (fixtureId == null) return;

      debugPrint(
          '⚽ Goal via WebSocket: $fixtureId - $scorer at $minuteDisplay');

      _safeSetState(() {
        // Update live games
        final index = _liveGames.indexWhere((f) => f.matchId == fixtureId);
        if (index != -1) {
          final old = _liveGames[index];
          _liveGames[index] = fixture_models.Fixture(
            id: old.id,
            matchId: old.matchId,
            homeTeam: old.homeTeam,
            awayTeam: old.awayTeam,
            league: old.league,
            homeWin: old.homeWin,
            awayWin: old.awayWin,
            draw: old.draw,
            date: old.date,
            time: old.time,
            homeScore: homeScore,
            awayScore: awayScore,
            status: old.status,
            isLive: old.isLive,
            availableForVoting: false,
            source: old.source,
            scrapedAt: old.scrapedAt,
            dateIso: old.dateIso,
            subFixtures: old.subFixtures,
            timeElapsed: timeElapsed,
          );
        }

        // Update history item
        final hIndex =
            _historyItems.indexWhere((h) => h.fixtureId == fixtureId);
        if (hIndex != -1) {
          _historyItems[hIndex].homeScore = homeScore;
          _historyItems[hIndex].awayScore = awayScore;
        }
      });

      // Show toast for goal
      if (mounted) {
        ToastHelper.showSuccess("⚽ GOAL! $scorer scores at $minuteDisplay");
      }
    });

    // Listen for card events
    ws.on('card', (payload) {
      final fixtureId = payload['fixture_id']?.toString();
      final cardType = payload['card_type']?.toString();
      final player = payload['player']?.toString();
      final minute = payload['minute'] as int? ?? 0;
      final minuteDisplay = payload['minute_display']?.toString() ?? "$minute'";

      if (fixtureId == null || player == null) return;

      debugPrint('🟨 Card via WebSocket: $fixtureId - $cardType for $player');

      if (mounted) {
        final emoji = cardType == 'yellow' ? '🟨' : '🟥';
        ToastHelper.showSuccess(
            "$emoji $cardType card for $player at $minuteDisplay");
      }
    });

    // Listen for error events
    ws.on('error', (payload) {
      final error = payload['message']?.toString() ?? 'Unknown error';
      debugPrint('❌ WebSocket error: $error');
    });
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  // ============================================================
  // LOAD HISTORY
  // ============================================================

  DateTime? _lastHistoryFetchTime;

  Future<void> _loadHistory({bool forceRefresh = false}) async {
    if (!mounted) return;

    setState(() => _loading = true);

    try {
      final historyGames = AppCache.historyGames;

      if (historyGames.isNotEmpty) {
        final historyItems = historyGames.map((historyGame) {
          final fixture = historyGame.toFixture();
          return HistoryItem.fromFixture(fixture);
        }).toList();

        setState(() {
          _historyItems = historyItems;
          _loading = false;
          _error = '';
        });

        debugPrint(
            '📊 Loaded ${historyItems.length} history games from AppCache');

        _loadVotersForHistoryItems(historyItems);
        _loadCommentsForHistoryItems(historyItems);
      } else {
        final allFixtures = AppCache.fixtures;
        final now = DateTime.now();
        final historyItems = allFixtures
            .where((f) {
              if (f.dateIso.isEmpty) return false;
              try {
                final fixtureDate = DateTime.parse(f.dateIso);
                return fixtureDate.isBefore(now);
              } catch (_) {
                return false;
              }
            })
            .map((fixture) => HistoryItem.fromFixture(fixture))
            .toList();

        setState(() {
          _historyItems = historyItems;
          _loading = false;
          _error = '';
        });

        debugPrint(
            '📊 Loaded ${historyItems.length} history games from fixtures');

        _loadVotersForHistoryItems(historyItems);
        _loadCommentsForHistoryItems(historyItems);
      }

      if (forceRefresh &&
          widget.authToken != null &&
          widget.authToken!.isNotEmpty) {
        await AppCache.refreshHistoryGames(authToken: widget.authToken);
        final updatedHistoryGames = AppCache.historyGames;
        if (updatedHistoryGames.isNotEmpty) {
          final updatedItems = updatedHistoryGames
              .map((hg) => HistoryItem.fromFixture(hg.toFixture()))
              .toList();
          setState(() {
            _historyItems = updatedItems;
          });
          debugPrint(
              '📊 Refreshed ${updatedItems.length} history games from API');

          _loadVotersForHistoryItems(updatedItems);
          _loadCommentsForHistoryItems(updatedItems);
        }
        _lastHistoryFetchTime = DateTime.now(); // ✅ mark fresh
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = "Couldn't load games";
      });
      debugPrint('❌ Error loading history: $e');
    }
  }

  void _loadLiveGamesFromCache() {
    if (!mounted) return;

    setState(() {
      _loadingLiveGames = false;
      final allFixtures = AppCache.fixtures;
      _liveGames = allFixtures
          .where((f) =>
              f.isLive == true || f.status == 'live' || f.status == 'half_time')
          .toList()
        ..sort((a, b) => (a.timeElapsed ?? 0).compareTo(b.timeElapsed ?? 0));

      debugPrint('🎮 Loaded ${_liveGames.length} live games from AppCache');
    });

    // Join WebSocket rooms for live games
    if (_wsConnected) {
      _joinAllFixtureRooms();
    }
  }


  List<Widget> _buildHistoryItemsWithAds() {
    final List<Widget> widgets = [];
    final items = _historyItems;

    // Only show ads if user is logged in
    final bool showAds = widget.isLoggedIn;

    // Get ad unit IDs from AdHelper
    final List<String> adUnitIds = AdHelper.adSenseInFeedSlotIds;
    final bool hasAds = adUnitIds.isNotEmpty && adUnitIds[0].isNotEmpty;

    // Ad frequency - insert an ad after every 3 history items
    const int adFrequency = 2;
    int adIndex = 0;
    int adSlotsUsed = 0;
    const int maxAdSlots = 40; // Maximum ads to show

    for (int i = 0; i < items.length; i++) {
      // Add the history item
      widgets.add(_buildHistoryCard(items[i]));

      // Check if we should insert an ad after this item
      final bool shouldInsertAd = showAds &&
          hasAds &&
          (i + 1) % adFrequency == 0 &&
          adSlotsUsed < maxAdSlots &&
          i < items.length - 1; // Don't add ad after the last item

      if (shouldInsertAd) {
        final String adUnitId = adUnitIds[adIndex % adUnitIds.length];
        widgets.add(_buildAdCard(adUnitId));
        adIndex++;
        adSlotsUsed++;
      }
    }

    return widgets;
  }

// ============================================================
// AD CARD - Compact history-style ad placeholder
// ============================================================

  Widget _buildAdCard(String adUnitId) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: FanColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FanColors.border.withOpacity(0.08),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: FanColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '📢',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sponsored',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: FanColors.textTertiary,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'Support Funzy+',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: FanColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: FanColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Learn More',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FETCH VOTERS FOR A FIXTURE
  // ============================================================

    Future<List<fixture_models.Voter>> _fetchVotersForFixture(String fixtureId,
      String? winner, String homeTeam, String awayTeam) async {
    final normalizedWinner = winner ?? '';

    if (_votersCache.containsKey(fixtureId)) {
      final cachedWinner = _winnerCache[fixtureId] ?? '';
      if (cachedWinner == normalizedWinner) {
        debugPrint('✅ Using cached voters for fixture: $fixtureId');
        return _votersCache[fixtureId]!;
      } else {
        debugPrint(
            '♻️ Winner changed for $fixtureId ("$cachedWinner" -> "$normalizedWinner"), refetching voters');
        _votersCache.remove(fixtureId);
      }
    }

    if (_votersLoading[fixtureId] == true) {
      debugPrint('⏳ Voters already loading for fixture: $fixtureId');
      return [];
    }

    setState(() {
      _votersLoading[fixtureId] = true;
    });

    try {
      // ✅ FIX: cache-bust — this app-level cache (_votersCache) is fine,
      // but the underlying HTTP GET used the same URL every call, so on
      // web the browser could satisfy repeat requests from its own cache
      // instead of hitting the backend, meaning a voter who was removed
      // (or a winner correction) server-side wouldn't show up here either.
      final url =
          Uri.parse('$API_BASE_URL/actions/vote/fixture/$fixtureId/voters'
              '?_=${DateTime.now().millisecondsSinceEpoch}');

      debugPrint('🔍 Fetching voters from: $url');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.authToken}',
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      ).timeout(REQUEST_TIMEOUT);

      debugPrint('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final List<fixture_models.Voter> voters =
            (data['voters'] as List? ?? [])
                .map((v) => fixture_models.Voter.fromJson(v))
                .toList();

        final votersWithResult = voters.map((voter) {
          bool? isWinner;

          if (winner != null && winner.isNotEmpty) {
            String voterSelection = voter.selection.trim().toLowerCase();
            String normalizedWinnerValue = winner.trim().toLowerCase();

            if (voterSelection == 'home_team') voterSelection = 'home';
            if (voterSelection == 'away_team') voterSelection = 'away';

            if (normalizedWinnerValue == homeTeam.trim().toLowerCase()) {
              normalizedWinnerValue = 'home';
            } else if (normalizedWinnerValue == awayTeam.trim().toLowerCase()) {
              normalizedWinnerValue = 'away';
            }

            isWinner = voterSelection == normalizedWinnerValue;
          }

          return fixture_models.Voter(
            userId: voter.userId,
            userName: voter.userName,
            selection: voter.selection,
            votedAt: voter.votedAt,
            isComrade: voter.isComrade,
            isCorrect: voter.isCorrect,
            pointsAwarded: voter.pointsAwarded,
          );
        }).toList();

        debugPrint(
            '✅ Loaded ${votersWithResult.length} voters for fixture: $fixtureId');

        _votersCache[fixtureId] = votersWithResult;
        _winnerCache[fixtureId] = normalizedWinner;

        if (mounted) {
          setState(() {
            _votersLoading[fixtureId] = false;
          });
        }

        return votersWithResult;
      } else {
        debugPrint('❌ Failed to load voters: ${response.statusCode}');

        if (mounted) {
          setState(() {
            _votersLoading[fixtureId] = false;
          });
        }

        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching voters for $fixtureId: $e');

      if (mounted) {
        setState(() {
          _votersLoading[fixtureId] = false;
        });
      }

      return [];
    }
  }

  // ============================================================
  // LOAD VOTERS FOR MULTIPLE HISTORY ITEMS
  // ============================================================

  Future<void> _loadVotersForHistoryItems(List<HistoryItem> items) async {
    if (widget.authToken == null || widget.authToken!.isEmpty) {
      debugPrint('⚠️ No auth token - skipping voter loading');
      return;
    }

    if (items.isEmpty) {
      debugPrint('⚠️ No history items to load voters for');
      return;
    }

    debugPrint('🔄 Loading voters for ${items.length} history items...');

    for (final item in items) {
      final normalizedWinner = item.winner ?? '';
      final cachedWinner = _winnerCache[item.fixtureId];

      if (_votersCache.containsKey(item.fixtureId) &&
          cachedWinner == normalizedWinner) {
        if (mounted) {
          setState(() {
            final index =
                _historyItems.indexWhere((h) => h.fixtureId == item.fixtureId);
            if (index != -1) {
              _historyItems[index].voters = _votersCache[item.fixtureId]!;
            }
          });
        }
        continue;
      }

      if (_votersLoading[item.fixtureId] == true) {
        continue;
      }

      final voters = await _fetchVotersForFixture(
          item.fixtureId, item.winner, item.homeTeam, item.awayTeam);

      if (voters.isNotEmpty && mounted) {
        setState(() {
          final index =
              _historyItems.indexWhere((h) => h.fixtureId == item.fixtureId);

          if (index != -1) {
            _historyItems[index].voters = voters;
            debugPrint(
                '✅ Updated history item ${item.fixtureId} with ${voters.length} voters');
          }
        });
      }
    }
  }

  // ============================================================
  // LOAD COMMENTS FOR HISTORY ITEMS
  // ============================================================

   Future<void> _loadCommentsForHistoryItems(List<HistoryItem> items) async {
    if (items.isEmpty) return;

    debugPrint('💬 Loading comments for ${items.length} history items...');

    for (final item in items) {
      // ✅ Resolve the same way posting/opening do — item.channelId alone
      // may be empty, stale, or not one of the user's current channels.
      final channelId = _resolveChannelIdFor(item);
      if (channelId == null) continue;

      try {
        final response = await http.get(
          // ✅ FIX: cache-bust with a timestamp query param + explicit
          // no-cache headers. Same root cause as the posts.dart bug —
          // on Flutter Web this URL was identical on every call, so the
          // browser's HTTP cache could keep serving a stale message
          // list (including messages/comments that were later deleted
          // server-side) instead of ever hitting the network again.
          Uri.parse(
              '$API_BASE_URL/channels/$channelId/messages?fixture_id=${item.fixtureId}&limit=100'
              '&_=${DateTime.now().millisecondsSinceEpoch}'),
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            if (widget.authToken != null && widget.authToken!.isNotEmpty)
              'Authorization': 'Bearer ${widget.authToken}',
          },
        ).timeout(REQUEST_TIMEOUT);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final messagesList = data['messages'] ?? [];

          final List<FixtureComment> comments = [];
          for (var msg in messagesList) {
            String id = msg['message_id'] ?? '';
            if (id.isEmpty) {
              final idObj = msg['_id'];
              if (idObj is Map && idObj['\$oid'] != null) {
                id = idObj['\$oid'];
              }
            }

            DateTime timestamp;
            final sentAt = msg['sent_at'];
            if (sentAt is Map) {
              final dateObj = sentAt['\$date'];
              if (dateObj is Map && dateObj['\$numberLong'] != null) {
                final milliseconds =
                    int.parse(dateObj['\$numberLong'].toString());
                timestamp = DateTime.fromMillisecondsSinceEpoch(milliseconds);
              } else if (dateObj is String) {
                timestamp = DateTime.parse(dateObj);
              } else {
                timestamp = DateTime.now();
              }
            } else if (sentAt is String) {
              timestamp = DateTime.parse(sentAt);
            } else {
              timestamp = DateTime.now();
            }

            comments.add(FixtureComment(
              id: id,
              userId: msg['sender_id']?.toString() ?? '',
              username: msg['sender_name']?.toString() ?? 'Anonymous',
              fixtureId: item.fixtureId,
              comment: msg['text']?.toString() ?? '',
              selection: msg['selection']?.toString(),
              timestamp: timestamp,
            ));
          }

          comments.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (mounted) {
            setState(() {
              final index = _historyItems
                  .indexWhere((h) => h.fixtureId == item.fixtureId);
              if (index != -1) {
                _historyItems[index].comments = comments;
                _historyItems[index].commentCount = comments.length;
                _fixtureComments[item.fixtureId] = comments;
                _commentCounts[item.fixtureId] = comments.length;
              }
            });
          }

          debugPrint(
              '✅ Loaded ${comments.length} comments for ${item.fixtureId}');
        }
      } catch (e) {
        debugPrint('⚠️ Error loading comments for ${item.fixtureId}: $e');
      }
    }

    // Generate mock comments for items with no real comments
    _generateMockCommentsForHistoryItems(items);
  }

  // ============================================================
  // GENERATE MOCK COMMENTS (like FixturesPage)
  // ============================================================

  void _generateMockCommentsForHistoryItems(List<HistoryItem> items) {
    for (final item in items) {
      final fixtureId = item.fixtureId;

      // Skip if already has real comments
      if (_fixtureComments.containsKey(fixtureId) &&
          _fixtureComments[fixtureId]!.isNotEmpty) {
        continue;
      }

      // Generate 1-3 mock comments
      final int mockCount = 1 + _random.nextInt(3);
      final List<FixtureComment> mockComments = [];

      for (int i = 0; i < mockCount; i++) {
        final randomUsername =
            _sampleUsernames[_random.nextInt(_sampleUsernames.length)];
        final randomComment =
            _sampleComments[_random.nextInt(_sampleComments.length)];
        final randomUserId = 'mock_${_random.nextInt(10000)}';

        // Random selection for mock comment
        final selections = ['home_team', 'away_team', 'draw'];
        final randomSelection = selections[_random.nextInt(selections.length)];

        // Random timestamp within last 24 hours
        final timestamp = DateTime.now().subtract(
          Duration(minutes: _random.nextInt(1440)),
        );

        mockComments.add(
          FixtureComment(
            id: 'mock_${DateTime.now().millisecondsSinceEpoch}_$i',
            userId: randomUserId,
            username: randomUsername,
            fixtureId: fixtureId,
            comment: randomComment,
            selection: randomSelection,
            timestamp: timestamp,
          ),
        );
      }

      // Sort by timestamp (newest first)
      mockComments.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Store mock comments
      _fixtureComments[fixtureId] = mockComments;
      _commentCounts[fixtureId] = mockComments.length;

      // Update history item
      if (mounted) {
        setState(() {
          final index =
              _historyItems.indexWhere((h) => h.fixtureId == fixtureId);
          if (index != -1) {
            _historyItems[index].comments = mockComments;
            _historyItems[index].commentCount = mockComments.length;
            _historyItems[index].lastMessage = mockComments.first.comment;
            _historyItems[index].lastSender = mockComments.first.username;
          }
        });
      }

      debugPrint(
          '🎲 Generated ${mockComments.length} mock comments for fixture $fixtureId');
    }
  }

  // ============================================================
  // CREATE COMMENT
  // ============================================================

  Future<void> _createComment(HistoryItem item, String commentText) async {
    final fixtureId = item.fixtureId;

    if (!widget.isLoggedIn) {
      ToastHelper.showWarning('Log in to comment');
      return;
    }

    // ✅ resolve the SAME way _openChat does
    final channelId = _resolveChannelIdFor(item);
    if (channelId == null) {
      ToastHelper.showWarning('No channel available');
      return;
    }

    final trimmedComment = commentText.trim();
    if (trimmedComment.isEmpty) {
      ToastHelper.showWarning('Comment cannot be empty');
      return;
    }
    if (_isPosting[fixtureId] == true) {
      ToastHelper.showWarning('Already posting...');
      return;
    }

    // ✅ make sure channel<->fixture link exists before posting,
    // same as FixturesPage does
    await _ensureChannelFixture(channelId, fixtureId);

    final userVoteSelection = AppCache.userVotes[fixtureId];
    _isPosting[fixtureId] = true;
    final tempId =
        'temp_${DateTime.now().millisecondsSinceEpoch}_${widget.userId}';
    final timestamp = DateTime.now();

    final optimisticComment = FixtureComment(
      id: tempId,
      userId: widget.userId,
      username: widget.username,
      fixtureId: fixtureId,
      comment: trimmedComment,
      selection: userVoteSelection,
      timestamp: timestamp,
    );

    setState(() {
      _fixtureComments.putIfAbsent(fixtureId, () => []);
      _fixtureComments[fixtureId]!.insert(0, optimisticComment);
      _commentCounts[fixtureId] = (_commentCounts[fixtureId] ?? 0) + 1;

      final index = _historyItems.indexWhere((h) => h.fixtureId == fixtureId);
      if (index != -1) {
        _historyItems[index].comments = _fixtureComments[fixtureId]!;
        _historyItems[index].commentCount = _commentCounts[fixtureId]!;
        _historyItems[index].lastMessage = trimmedComment;
        _historyItems[index].lastSender = widget.username;
        _historyItems[index].lastActivity = DateTime.now();
      }
    });

    _commentControllers[fixtureId]?.clear();

    // ✅ Same fix — HistoryPage sends comments too and must keep
    // AppCache's message cache current for ChatScreen.
    AppCache.appendCachedMessage(channelId, fixtureId, {
      'id': tempId,
      'tempId': tempId,
      'userId': widget.userId,
      'username': widget.username,
      'text': trimmedComment,
      'selection': userVoteSelection,
      'timestamp': timestamp.toIso8601String(),
      'status': 1,
      'isSeen': false,
      'isCommentary': false,
      'commentaryType': null,
    });

    final sent = await WebSocketService().sendChatMessageReliable(
      message: trimmedComment,
      selection: userVoteSelection ?? '',
      username: widget.username,
      messageId: tempId,
      channelId: channelId, // ✅ resolved id, not item.channelId
      fixtureId: fixtureId,
      tempId: tempId,
      onReconnectAttempt: () async {
        if (widget.isLoggedIn) _connectWebSocket();
      },
    );

    if (!sent) {
      setState(() {
        _fixtureComments[fixtureId]!.removeWhere((c) => c.id == tempId);
        _commentCounts[fixtureId] = (_commentCounts[fixtureId] ?? 1) - 1;
        final index = _historyItems.indexWhere((h) => h.fixtureId == fixtureId);
        if (index != -1) {
          _historyItems[index].comments = _fixtureComments[fixtureId]!;
          _historyItems[index].commentCount = _commentCounts[fixtureId]!;
        }
      });
      ToastHelper.showError('Not connected to chat server');
      _isPosting[fixtureId] = false;
      return;
    }

    _isPosting[fixtureId] = false;
  }

  // ============================================================
  // CHECK VOTES BUTTON VISIBILITY
  // ============================================================

   Future<bool> _checkVotesButtonVisibility() async {
    try {
      final response = await http.get(
        // ✅ FIX: same cache-busting treatment for consistency — this
        // toggle is low-frequency-changing but there's no reason to let
        // the browser serve a possibly month-old cached value either.
        Uri.parse('$API_BASE_URL/visibility/votes_button_show'
            '?_=${DateTime.now().millisecondsSinceEpoch}'),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          if (widget.authToken != null && widget.authToken!.isNotEmpty)
            'Authorization': 'Bearer ${widget.authToken}',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['value'] ?? true;
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error checking visibility: $e');
      return true;
    }
  }
  // ============================================================
  // OPEN AFTERMATCH REVIEW MODAL
  // ============================================================

  void _openAftermatchReview(HistoryItem item) async {
    final bool showFullModal = await _checkVotesButtonVisibility();

    final fixture = fixture_models.Fixture(
      id: item.fixtureId,
      matchId: item.fixtureId,
      homeTeam: item.homeTeam,
      awayTeam: item.awayTeam,
      league: item.league.isNotEmpty ? item.league : item.channelName,
      homeWin: 0.0,
      awayWin: 0.0,
      draw: 0.0,
      date: '',
      time: '',
      homeScore: item.homeScore,
      awayScore: item.awayScore,
      status: item.status,
      isLive: false,
      availableForVoting: false,
      source: 'history',
      scrapedAt: DateTime.now(),
      dateIso: item.matchTime?.toIso8601String() ?? '',
      result: item.winner,
      votes: 0,
      voters: const [],
      pledges: 0,
      pledgers: const [],
      bets: 0,
      bettors: const [],
      subFixtures: const [],
      timeElapsed: null,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SwipeableAftermatchReviewModal(
        fixture: fixture,
        userId: widget.userId,
        username: widget.username,
        authToken: widget.authToken,
        channelId: item.channelId,
        isLoggedIn: widget.isLoggedIn,
        showPledgesTab: showFullModal,
        showBetsTab: showFullModal,
        showSubFixturesTab: showFullModal,
      ),
    );
  }

  // ============================================================
  // OPEN CHAT
  // ============================================================

  Future<void> _openChat(HistoryItem item) async {
    if (!widget.isLoggedIn) {
      ToastHelper.showWarning('Log in to open this chat');
      return;
    }

    fixture_models.Fixture? fixture;
    for (final f in AppCache.fixtures) {
      if (f.matchId == item.fixtureId) {
        fixture = f;
        break;
      }
    }

    fixture ??= fixture_models.Fixture(
      id: item.fixtureId,
      matchId: item.fixtureId,
      homeTeam: item.homeTeam,
      awayTeam: item.awayTeam,
      league: item.league.isNotEmpty ? item.league : item.channelName,
      homeWin: 0.0,
      awayWin: 0.0,
      draw: 0.0,
      date: '',
      time: '',
      homeScore: item.homeScore,
      awayScore: item.awayScore,
      status: item.status,
      isLive: false,
      availableForVoting: false,
      source: 'history',
      scrapedAt: DateTime.now(),
      dateIso: item.matchTime?.toIso8601String() ?? '',
      result: item.winner,
      votes: 0,
      voters: const [],
      pledges: 0,
      pledgers: const [],
      bets: 0,
      bettors: const [],
      subFixtures: const [],
      timeElapsed: null,
    );

    final userVoteSelection = AppCache.userVotes[item.fixtureId];

    if (widget.userChannels.isEmpty) {
      ToastHelper.showWarning('Join a channel first to chat');
      return;
    }

    final String? channelId = _resolveChannelIdFor(item);
    if (channelId == null) {
      ToastHelper.showWarning('Join a channel first to chat');
      return;
    }

    final channelName = widget.userChannels
        .firstWhere(
          (c) => c.channelId == channelId,
          orElse: () => widget.userChannels.first,
        )
        .name;

    final chatScreen = ChatScreen(
      channelId: channelId,
      fixtureId: item.fixtureId,
      fixture: fixture,
      userId: widget.userId,
      username: widget.username,
      authToken: widget.authToken,
      isLoggedIn: widget.isLoggedIn,
      comradesList: widget.userChannels.isNotEmpty ? {} : const {},
      userVoteSelection: userVoteSelection,
    );

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth >= 900;

    final result = isWideScreen
        ? await showDialog(
            context: context,
            barrierDismissible: true,
            barrierColor: Colors.black.withOpacity(0.5),
            builder: (dialogContext) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 80,
                vertical: 40,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 480,
                  height: MediaQuery.of(context).size.height * 0.85,
                  constraints: const BoxConstraints(maxHeight: 900),
                  color: FanColors.background,
                  child: chatScreen,
                ),
              ),
            ),
          )
        : await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => chatScreen),
          );

    if (result == true) {
      _loadHistory(forceRefresh: true);
    }
  }
  // ============================================================
  // BUILD UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final showLiveTab = _liveGames.isNotEmpty;
    final showHistoryTab = _historyItems.isNotEmpty;
    final showTabs = showLiveTab && showHistoryTab;

    return Scaffold(
      backgroundColor: FanColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadHistory(forceRefresh: true);
          _loadLiveGamesFromCache();
        },
        color: FanColors.primary,
        backgroundColor: FanColors.background,
        child: Column(
          children: [
            if (showTabs) _buildHeader(),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: FanColors.border.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildTabButton(
              'History', _historyItems.length, _activeTab == 'history'),
          const SizedBox(width: 26),
          _buildTabButton('Live', _liveGames.length, _activeTab == 'live'),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int count, bool isActive) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _activeTab = label == 'Live' ? 'live' : 'history';
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.1,
                  color:
                      isActive ? FanColors.textPrimary : FanColors.textTertiary,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isActive
                        ? FanColors.primary
                        : FanColors.textTertiary.withOpacity(0.6),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            height: 2,
            width: isActive ? 20 : 0,
            decoration: BoxDecoration(
              color: FanColors.primary,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final showLiveTab = _liveGames.isNotEmpty;
    final showHistoryTab = _historyItems.isNotEmpty;

    if (!showLiveTab && !showHistoryTab) {
      return _buildEmptyState();
    }

    if (!showHistoryTab && showLiveTab) {
      if (_loadingLiveGames) return _buildLoadingState();
      return _buildLiveGamesList();
    }

    if (showHistoryTab && !showLiveTab) {
      if (_loading) return _buildLoadingState();
      return _buildHistoryList();
    }

    if (_activeTab == 'live') {
      if (_loadingLiveGames) return _buildLoadingState();
      return _buildLiveGamesList();
    }

    if (_loading) return _buildLoadingState();
    if (_error.isNotEmpty) return _buildErrorState();
    return _buildHistoryList();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 1.75,
              color: FanColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Loading…',
            style: TextStyle(color: FanColors.textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off,
                size: 34, color: FanColors.away.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              _error,
              style: TextStyle(color: FanColors.textSecondary, fontSize: 13.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _loadHistory(forceRefresh: true),
              child: Text(
                'Retry',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: FanColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history,
                size: 34, color: FanColors.textSecondary.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(
              'Nothing here yet',
              style: TextStyle(
                color: FanColors.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isLoggedIn
                  ? 'Chats you join will show up here'
                  : 'Log in to see your past chats',
              style: TextStyle(color: FanColors.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            if (!widget.isLoggedIn)
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text(
                  'Log In',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: FanColors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HISTORY LIST
  // ============================================================

 Widget _buildHistoryList() {
  final itemsWithAds = _buildHistoryItemsWithAds();
  
  return ListView(
    controller: widget.scrollController,
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    children: itemsWithAds,
  );
}

  Widget _buildLiveGamesList() {
    return ListView.separated(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      itemCount: _liveGames.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildLiveCard(_liveGames[index]),
    );
  }

  // ============================================================
  // HISTORY CARD — slim, backgroundless-text design
  // ============================================================

  Widget _buildHistoryCard(HistoryItem item) {
    final unread = item.unreadCount > 0;
    final timeAgo = HistoryDateHelper.formatTimeAgo(item.lastActivity);
    final matchup = (item.homeTeam.isNotEmpty && item.awayTeam.isNotEmpty)
        ? '${item.homeTeam} vs ${item.awayTeam}'
        : item.matchName;

    final homeScore = item.homeScore;
    final awayScore = item.awayScore;
    final hasScores = homeScore > 0 || awayScore > 0;

    final isLoadingVoters = _votersLoading[item.fixtureId] == true;

    // Comments
    final comments = _fixtureComments[item.fixtureId] ?? item.comments;
    final commentCount = _commentCounts[item.fixtureId] ?? item.commentCount;
    final latestComment = comments.isNotEmpty ? comments.first : null;

    // User vote result
    final userVote = AppCache.userVotes[item.fixtureId];
    final userVoter = item.voters.firstWhere(
      (v) => v.userId == widget.userId,
      orElse: () => fixture_models.Voter(
        userId: widget.userId,
        userName: widget.username,
        selection: userVote ?? '',
        votedAt: DateTime.now(),
        isCorrect: false,
        pointsAwarded: 0,
        isComrade: false,
      ),
    );
    final userWon = userVoter.isCorrect == true;
    final userLost = userVoter.isCorrect == false;

    // Comment controller
    _commentControllers.putIfAbsent(
        item.fixtureId, () => TextEditingController());
    final commentController = _commentControllers[item.fixtureId]!;
    final isPosting = _isPosting[item.fixtureId] == true;
    final isLoggedIn = widget.isLoggedIn;

    return GestureDetector(
      onTap: () => _openChat(item),
      child: Container(
        decoration: BoxDecoration(
          color: FanColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: FanColors.border.withOpacity(0.08),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.network(
                      _getLeagueIcon(item.league),
                      width: 16,
                      height: 16,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => SizedBox(
                        width: 16,
                        height: 16,
                        child: Center(
                          child: Text(
                            item.league.isNotEmpty
                                ? item.league[0].toUpperCase()
                                : '⚽',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: FanColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      matchup,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                        color: unread
                            ? FanColors.textPrimary
                            : FanColors.textSecondary,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeAgo,
                    style: TextStyle(
                      fontSize: 10,
                      color: FanColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              // Score — plain typographic score line, no boxes
              if (hasScores) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.homeTeam,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: homeScore > awayScore
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: homeScore > awayScore
                              ? FanColors.textPrimary
                              : FanColors.textSecondary,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '$homeScore : $awayScore',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: FanColors.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.awayTeam,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: awayScore > homeScore
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: awayScore > homeScore
                              ? FanColors.textPrimary
                              : FanColors.textSecondary,
                        ),
                        textAlign: TextAlign.left,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // User vote result
              if (widget.isLoggedIn && userVote != null) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      userWon ? Icons.check_circle : Icons.cancel,
                      size: 11,
                      color: userWon ? FanColors.primary : FanColors.away,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      userWon ? 'You voted correctly' : 'You lost this one',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: userWon ? FanColors.primary : FanColors.away,
                      ),
                    ),
                  ],
                ),
              ],

              // Voters — compact overlapping avatars, no chip backgrounds
              if (widget.isLoggedIn) ...[
                const SizedBox(height: 8),
                if (isLoadingVoters)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 11,
                        height: 11,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: FanColors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Loading votes…',
                        style: TextStyle(
                            fontSize: 10, color: FanColors.textTertiary),
                      ),
                    ],
                  )
                else if (item.voters.isEmpty)
                  Text(
                    'No votes yet',
                    style:
                        TextStyle(fontSize: 10, color: FanColors.textTertiary),
                  )
                else
                  Row(
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20 +
                            (min(item.voters.length, 6) - 1).clamp(0, 5) * 13.0,
                        child: Stack(
                          children: [
                            for (int i = 0; i < min(item.voters.length, 6); i++)
                              Padding(
                                padding: EdgeInsets.only(left: i * 13.0),
                                child: _VoterDot(
                                  voter: item.voters[i],
                                  isUser:
                                      item.voters[i].userId == widget.userId,
                                  homeTeam: item.homeTeam,
                                  awayTeam: item.awayTeam,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (item.voters.length > 6) ...[
                        const SizedBox(width: 6),
                        Text(
                          '+${item.voters.length - 6}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: FanColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
              ],

              // Latest comment — plain, hairline divider instead of a box
              if (latestComment != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: FanColors.border.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${latestComment.username}  ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: FanColors.textSecondary,
                          ),
                        ),
                        TextSpan(
                          text: latestComment.comment,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: FanColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Comment input — slim underline, absorbed taps
              const SizedBox(height: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {}, // absorb — do not let this reach the card
                child: _SpeechBubbleInput(
                  controller: commentController,
                  enabled: isLoggedIn && !isPosting,
                  hintText:
                      isLoggedIn ? 'Write a comment…' : 'Log in to comment',
                  onSend: () {
                    final text = commentController.text.trim();
                    if (text.isNotEmpty && !isPosting) {
                      _createComment(item, text);
                      commentController.clear();
                    }
                  },
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty && !isPosting) {
                      _createComment(item, value.trim());
                      commentController.clear();
                    }
                  },
                ),
              ),
              if (isPosting) ...[
                const SizedBox(height: 6),
                Center(
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: FanColors.primary,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Footer — plain text actions, no pill backgrounds
              Row(
                children: [
                  if (commentCount > 0) ...[
                    Icon(Icons.chat_bubble_outline,
                        size: 11, color: FanColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      '$commentCount',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: FanColors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _openAftermatchReview(item),
                    child: Text(
                      'Results',
                      style: TextStyle(
                        fontSize: 11,
                        color: FanColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => _openChat(item),
                    child: Text(
                      'Chat',
                      style: TextStyle(
                        fontSize: 11,
                        color: FanColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Add to _HistoryPageState, mirrors FixturesPage's _resolveChannelIdFor
  String? _resolveChannelIdFor(HistoryItem item) {
    String? channelId = item.channelId;
    final hasChannel = channelId.isNotEmpty &&
        widget.userChannels.any((c) => c.channelId == channelId);
    if (!hasChannel) {
      channelId = widget.userChannels.isNotEmpty
          ? widget.userChannels.first.channelId
          : null;
    }
    return (channelId != null && channelId.isNotEmpty) ? channelId : null;
  }

// Mirrors FixturesPage's _ensureChannelFixture
  final Set<String> _ensuredChannelFixtures = {};

  Future<void> _ensureChannelFixture(String channelId, String fixtureId) async {
    final dedupeKey = '${channelId}_$fixtureId';
    if (_ensuredChannelFixtures.contains(dedupeKey)) return;
    try {
      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/channels/fixture/chat'),
            headers: {
              'Content-Type': 'application/json',
              if (widget.authToken != null && widget.authToken!.isNotEmpty)
                'Authorization': 'Bearer ${widget.authToken}',
            },
            body:
                json.encode({'channel_id': channelId, 'fixture_id': fixtureId}),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 || response.statusCode == 201) {
        _ensuredChannelFixtures.add(dedupeKey);
      }
    } catch (e) {
      debugPrint('⚠️ ensureChannelFixture failed: $e');
    }
  }

  // ============================================================
  // LIVE CARD — slim, backgroundless-text design
  // ============================================================

  Widget _buildLiveCard(fixture_models.Fixture fixture) {
    final isHalfTime = fixture.status == 'half_time' ||
        (fixture.timeElapsed ?? 0) >= 44 && (fixture.timeElapsed ?? 0) <= 46;
    final minutes = fixture.timeElapsed ?? 0;
    final homeScore = fixture.homeScore ?? 0;
    final awayScore = fixture.awayScore ?? 0;
    final commentCount =
        AppCache.channelFixtures[fixture.matchId]?.commentCount ?? 0;
    final latestComment = AppCache.getLatestComment(fixture.matchId);
    final latestSender = AppCache.getLatestCommentAuthor(fixture.matchId);
    final hasLiveComment = latestComment != null && latestComment.isNotEmpty;

    return GestureDetector(
      onTap: () => _openLiveGameChat(fixture),
      child: Container(
        decoration: BoxDecoration(
          color: FanColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: FanColors.live.withOpacity(0.25),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: FanColors.live,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isHalfTime ? 'HALF-TIME' : 'LIVE',
                    style: TextStyle(
                      color: isHalfTime ? FanColors.draw : FanColors.live,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isHalfTime
                        ? "45'"
                        : minutes > 0
                            ? "${minutes.floor()}'"
                            : "0'",
                    style: TextStyle(
                      fontSize: 10,
                      color: FanColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      fixture.league,
                      style: TextStyle(
                        fontSize: 10,
                        color: FanColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fixture.homeTeam,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: FanColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fixture.awayTeam,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: FanColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$homeScore',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: FanColors.scoreHome,
                          height: 1.3,
                        ),
                      ),
                      Text(
                        '$awayScore',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: FanColors.scoreAway,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (hasLiveComment) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: FanColors.border.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${latestSender ?? 'Anonymous'}  ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: FanColors.textSecondary,
                          ),
                        ),
                        TextSpan(
                          text: latestComment!,
                          style: TextStyle(
                            fontSize: 11,
                            color: FanColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 13, color: FanColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Join live chat',
                    style: TextStyle(
                      color: FanColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (commentCount > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$commentCount',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: FanColors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _openAftermatchReview(
                      HistoryItem.fromFixture(fixture),
                    ),
                    child: Text(
                      'Details',
                      style: TextStyle(
                        fontSize: 11,
                        color: FanColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // OPEN LIVE GAME CHAT
  // ============================================================

  Future<void> _openLiveGameChat(fixture_models.Fixture fixture) async {
    if (!widget.isLoggedIn) {
      ToastHelper.showWarning('Log in to join the chat');
      return;
    }

    if (widget.userChannels.isEmpty) {
      ToastHelper.showWarning('No channels available');
      return;
    }

    final UserChannel channel = widget.userChannels.first;
    final userVoteSelection = AppCache.userVotes[fixture.matchId];

    final chatScreen = ChatScreen(
      channelId: channel.channelId,
      fixtureId: fixture.matchId,
      fixture: fixture,
      userId: widget.userId,
      username: widget.username,
      authToken: widget.authToken,
      isLoggedIn: widget.isLoggedIn,
      comradesList: const {},
      userVoteSelection: userVoteSelection,
    );

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth >= 900;

    final result = isWideScreen
        ? await showDialog(
            context: context,
            barrierDismissible: true,
            barrierColor: Colors.black.withOpacity(0.5),
            builder: (dialogContext) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 80,
                vertical: 40,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 480,
                  height: MediaQuery.of(context).size.height * 0.85,
                  constraints: const BoxConstraints(maxHeight: 900),
                  color: FanColors.background,
                  child: chatScreen,
                ),
              ),
            ),
          )
        : await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => chatScreen),
          );

    if (result == true) {
      _loadLiveGamesFromCache();
    }
  }
  // ============================================================
  // HELPER: Get League Icon
  // ============================================================

  String _getLeagueIcon(String leagueName) {
    final leagueLower = leagueName.toLowerCase();
    if (leagueLower.contains('premier') || leagueLower.contains('epl'))
      return 'https://cdn-icons-png.flaticon.com/512/3095/3095207.png';
    if (leagueLower.contains('laliga') || leagueLower.contains('spain'))
      return 'https://cdn-icons-png.flaticon.com/512/3095/3095212.png';
    if (leagueLower.contains('serie a') || leagueLower.contains('italy'))
      return 'https://cdn-icons-png.flaticon.com/512/3095/3095216.png';
    if (leagueLower.contains('bundesliga') || leagueLower.contains('german'))
      return 'https://cdn-icons-png.flaticon.com/512/3095/3095221.png';
    if (leagueLower.contains('ligue 1') || leagueLower.contains('france'))
      return 'https://cdn-icons-png.flaticon.com/512/3095/3095225.png';
    if (leagueLower.contains('champions league') || leagueLower.contains('ucl'))
      return 'https://cdn-icons-png.flaticon.com/512/3095/3095230.png';
    if (leagueLower.contains('world cup') || leagueLower.contains('wc'))
      return 'https://cdn-icons-png.flaticon.com/512/3095/3095234.png';
    if (leagueLower.contains('europa'))
      return 'https://cdn-icons-png.flaticon.com/512/3095/3095239.png';
    return 'https://cdn-icons-png.flaticon.com/512/3095/3095243.png';
  }

  @override
  void dispose() {
    FanTheme.controller.removeListener(_onThemeChanged);
    _refreshTimer?.cancel();
    _appCacheSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);

    // ✅ Leave only the rooms this page joined — never disconnect the
    // shared socket, since ChatScreen/FixturesPage may be using it too.
    final ws = WebSocketService();
    for (var fixture in _liveGames) {
      final item = _historyItems.firstWhere(
        (h) => h.fixtureId == fixture.matchId,
        orElse: () => HistoryItem.fromFixture(fixture),
      );
      final channelId = _resolveChannelIdFor(item);
      if (channelId != null) {
        ws.leaveChannelFixtureRoom(channelId, fixtureId: fixture.matchId);
      }
    }
    for (var item in _historyItems) {
      if (item.status == 'live' || item.status == 'half_time') {
        final channelId = _resolveChannelIdFor(item);
        if (channelId != null) {
          ws.leaveChannelFixtureRoom(channelId, fixtureId: item.fixtureId);
        }
      }
    }

    for (var controller in _commentControllers.values) {
      controller.dispose();
    }
    _commentControllers.clear();

    super.dispose();
  }
}
