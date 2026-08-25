import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'firebase_options.dart';
import 'services/local_notification_service.dart';
import 'dart:async';
import 'dart:convert';
import 'services/web_notification_service.dart';
import "screens/app_shell.dart";
import '../pages/fixture_page.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import "./models/chat_message.dart";
import 'package:http/http.dart' as http;
import 'models/comments_model.dart';
import 'screens/home_page.dart';
import 'services/notification_service.dart';
import '../services/permission_status_stub.dart'
    if (dart.library.html) 'permission_status_web.dart';

import 'services/auth_service.dart';
import 'services/memory_manager.dart';
import 'models/fixture_models.dart';
import 'models/aftermatch_models.dart';
import 'modals/login_modal.dart';
import './pages/fan_Funzy_design.dart';
import 'models/user_channel.dart';

// ============================================================================
// GLOBAL KEYS
// ============================================================================

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

late AuthService authService;
bool _isLoginModalOpen = false;
Timer? _appCacheRefreshTimer;

// ============================================================================
// APPCACHE - Enhanced with memory management
// ============================================================================

class AppCache {
  // ==========================================================================
  // VOTE STREAM
  // ==========================================================================
  static final _votesController = StreamController<void>.broadcast();
  static Stream<void> get votesStream => _votesController.stream;

  static final Map<String, int> _commentCounts = {};
  static final Map<String, String> _commentPostMap = {};

  // ==========================================================================
  // HISTORY COMMENTS CACHE - FIXED
  // ==========================================================================
  static final Map<String, List<Map<String, dynamic>>> _historyComments = {};
  static bool _historyCommentsLoaded = false;
  static final Map<String, DateTime> _historyCommentFetchTime = {};

  // ==========================================================================
  // LIVE COMMENTARY CACHE
  // ==========================================================================
  static final Map<String, Map<String, dynamic>> _liveCommentaryCache = {};

  static Map<String, dynamic>? getLiveCommentary(String fixtureId) =>
      _liveCommentaryCache[fixtureId];

  static void setLiveCommentary(String fixtureId, Map<String, dynamic> entry) {
    _liveCommentaryCache[fixtureId] = entry;
  }

  static void clearLiveCommentary(String fixtureId) {
    _liveCommentaryCache.remove(fixtureId);
  }

  // ==========================================================================
// SESSION HYDRATION - tracks which fixtures have had ONE network catch-up
// this app process. Never cleared while the app is alive, so re-entering
// ChatScreen mid-session is pure AppCache + WebSocket, no refetch. Only a
// real app kill/relaunch resets these (new process = fresh static state).
// ==========================================================================
  static final Set<String> _hydratedMessageKeys = {};
  static final Set<String> _hydratedCommentaryKeys = {};

  static bool isMessagesHydrated(String channelId, String? fixtureId) {
    final key =
        fixtureId != null ? '${channelId}_$fixtureId' : '${channelId}_overall';
    return _hydratedMessageKeys.contains(key);
  }

  static void markMessagesHydrated(String channelId, String? fixtureId) {
    final key =
        fixtureId != null ? '${channelId}_$fixtureId' : '${channelId}_overall';
    _hydratedMessageKeys.add(key);
  }

  static bool isCommentaryHydrated(String fixtureId) =>
      _hydratedCommentaryKeys.contains(fixtureId);

  static void markCommentaryHydrated(String fixtureId) =>
      _hydratedCommentaryKeys.add(fixtureId);

  // ==========================================================================
  // HISTORY COMMENTS - GETTERS
  // ==========================================================================
  static List<Map<String, dynamic>>? getCachedHistoryComments(
      String fixtureId) {
    if (!_historyComments.containsKey(fixtureId)) {
      _lazyLoadHistoryCommentsFromDisk();
      return null;
    }
    return _historyComments[fixtureId];
  }

  static DateTime? getHistoryCommentFetchTime(String fixtureId) {
    return _historyCommentFetchTime[fixtureId];
  }

  // ==========================================================================
  // HISTORY COMMENTS - CACHE METHODS
  // ==========================================================================
  static void cacheHistoryComments(
      String fixtureId, List<Map<String, dynamic>> comments) {
    _historyComments[fixtureId] = comments;
    _historyCommentFetchTime[fixtureId] = DateTime.now();
    _saveHistoryCommentsToDisk();

    // Also store in the main message cache for cross-screen consistency
    final key = 'history_$fixtureId';
    _cachedMessages[key] = comments
        .map((c) => {
              'id': c['id'] ??
                  'comment_${DateTime.now().millisecondsSinceEpoch}_${c['timestamp'] ?? DateTime.now().millisecondsSinceEpoch}',
              'userId': c['userId'] ?? '__commentary__',
              'username': c['username'] ?? 'Live Commentary',
              'text': c['text'] ?? '',
              'selection': c['selection'],
              'timestamp': c['timestamp'] ?? DateTime.now().toIso8601String(),
              'status': 1,
              'isSeen': false,
              'isCommentary': true,
              'commentaryType': c['type'] ?? 'update',
              'minute': c['minute'] ?? 0,
            })
        .toList();
    _saveMessagesToDisk();

    if (kDebugMode) {
      developer.log(
          '💾 Cached ${comments.length} comments for history fixture $fixtureId',
          name: 'AppCache');
    }
  }

  static void addHistoryComment(
      String fixtureId, Map<String, dynamic> comment) {
    final existing = _historyComments[fixtureId] ?? [];
    // Avoid duplicates by checking text + timestamp
    final exists = existing.any((c) =>
        c['text'] == comment['text'] && c['timestamp'] == comment['timestamp']);
    if (exists) return;

    final updated = [comment, ...existing]; // newest first
    _historyComments[fixtureId] = updated;
    _historyCommentFetchTime[fixtureId] = DateTime.now();
    _saveHistoryCommentsToDisk();

    // Also update cached messages
    final key = 'history_$fixtureId';
    final msgEntry = {
      'id': comment['id'] ?? 'comment_${DateTime.now().millisecondsSinceEpoch}',
      'userId': comment['userId'] ?? '__commentary__',
      'username': comment['username'] ?? 'Live Commentary',
      'text': comment['text'] ?? '',
      'selection': comment['selection'],
      'timestamp': comment['timestamp'] ?? DateTime.now().toIso8601String(),
      'status': 1,
      'isSeen': false,
      'isCommentary': true,
      'commentaryType': comment['type'] ?? 'update',
      'minute': comment['minute'] ?? 0,
    };
    _cachedMessages[key] = [msgEntry, ...(_cachedMessages[key] ?? [])];
    _saveMessagesToDisk();
  }

  static Future<void> _saveHistoryCommentsToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'history_comments_cache', json.encode(_historyComments));
      await prefs.setString(
          'history_comments_timestamps',
          json.encode(_historyCommentFetchTime
              .map((k, v) => MapEntry(k, v.toIso8601String()))));
    } catch (e) {
      developer.log('⚠️ Failed to save history comments: $e', name: 'AppCache');
    }
  }

  static void _lazyLoadHistoryCommentsFromDisk() {
    if (_historyCommentsLoaded) return;
    _historyCommentsLoaded = true;

    unawaited(Future<void>(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final data = prefs.getString('history_comments_cache');
        if (data != null) {
          final Map<String, dynamic> decoded = jsonDecode(data);
          for (var entry in decoded.entries) {
            _historyComments[entry.key] =
                List<Map<String, dynamic>>.from(entry.value);
          }
          if (kDebugMode) {
            developer.log(
                '📦 Lazy loaded ${_historyComments.length} history comment sets',
                name: 'AppCache');
          }
        }

        // Load timestamps
        final tsData = prefs.getString('history_comments_timestamps');
        if (tsData != null) {
          final Map<String, dynamic> decoded = jsonDecode(tsData);
          for (var entry in decoded.entries) {
            _historyCommentFetchTime[entry.key] = DateTime.parse(entry.value);
          }
        }
      } catch (e) {
        developer.log('⚠️ Lazy load history comments error: $e',
            name: 'AppCache');
      }
    }));
  }

  // ==========================================================================
  // REFRESH HISTORY GAMES WITH COMMENTS - FIXED
  // ==========================================================================
 static Future<void> refreshHistoryGamesWithComments(
    {String? authToken}) async {
  try {
    if (kDebugMode) {
      developer.log('🔄 Refreshing history games with comment preload...',
          name: 'AppCache');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
    };
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    final response = await http
        .get(
          Uri.parse(
            'https://clash-api-m5mr.onrender.com/api/games/history?limit=100'
            '&_=${DateTime.now().millisecondsSinceEpoch}',
          ),
          headers: headers,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> gamesData = data['data'] ?? [];

      historyGames = gamesData
          .map((g) => HistoryGame.fromJson(g as Map<String, dynamic>))
          .toList();

      await _saveHistoryGamesToDisk(historyGames);
      _historyController.add(historyGames);

      // Preload comments for the first 5 games
      final gamesToCache = historyGames.take(5).toList();
      for (var game in gamesToCache) {
        if (!_historyComments.containsKey(game.id)) {
          unawaited(_fetchAndCacheHistoryComments(game.id, authToken));
        }
      }

      if (kDebugMode) {
        developer.log(
            '✅ Refreshed ${historyGames.length} history games, preloading comments for ${gamesToCache.length}',
            name: 'AppCache');
      }
    } else {
      if (kDebugMode) {
        developer.log(
            '⚠️ Failed to refresh history games: ${response.statusCode}',
            name: 'AppCache');
      }
      final cached = await _loadHistoryGamesFromDisk();
      if (cached != null) {
        historyGames = cached;
        _historyController.add(historyGames);
      }
    }
  } catch (e) {
    developer.log('❌ Failed to refresh history games: $e', name: 'AppCache');
    final cached = await _loadHistoryGamesFromDisk();
    if (cached != null) {
      historyGames = cached;
      _historyController.add(historyGames);
    }
  }
}
  static Future<void> _fetchAndCacheHistoryComments(
      String fixtureId, String? authToken) async {
    try {
      final headers = {'Content-Type': 'application/json'};
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http
          .get(
            Uri.parse(
                'https://clash-api-m5mr.onrender.com/api/games/history/$fixtureId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final historyGame = data['data'];
        if (historyGame != null) {
          final commentaryList = historyGame['commentary'] ?? [];
          final comments = commentaryList
              .whereType<Map>()
              .map((e) => {
                    'text': e['text'] ?? '',
                    'type': e['type'] ?? 'update',
                    'timestamp': e['createdAt']?.toString() ??
                        DateTime.now().toIso8601String(),
                    'minute': e['minute'] ?? 0,
                    'id': e['_id']?.toString() ??
                        'comment_${DateTime.now().millisecondsSinceEpoch}_$fixtureId',
                    'username': 'Live Commentary',
                  })
              .toList();

          if (comments.isNotEmpty) {
            cacheHistoryComments(fixtureId, comments);
            if (kDebugMode) {
              developer.log(
                  '📥 Preloaded ${comments.length} comments for history game $fixtureId',
                  name: 'AppCache');
            }
          }
        }
      }
    } catch (e) {
      // Silently fail - will be fetched on demand
      if (kDebugMode) {
        developer.log('⚠️ Background preload failed for $fixtureId: $e',
            name: 'AppCache');
      }
    }
  }

  // ==========================================================================
  // HISTORY GAMES
  // ==========================================================================
  static List<HistoryGame> historyGames = [];
  static final _historyController =
      StreamController<List<HistoryGame>>.broadcast();
  static Stream<List<HistoryGame>> get historyStream =>
      _historyController.stream;

  static void notifyVotesChanged() {
    _votesController.add(null);
    if (kDebugMode) {
      developer.log('🔔 AppCache: Vote changed notification sent',
          name: 'AppCache');
    }
  }

  // ==========================================================================
  // USER VOTES
  // ==========================================================================
  static Map<String, String> userVotes = {};

  static void setUserVote(String fixtureId, String selection) {
    userVotes[fixtureId] = selection;
    saveUserVotes();
    notifyVotesChanged();
    if (kDebugMode) {
      developer.log('✅ AppCache: Vote set for $fixtureId -> $selection',
          name: 'AppCache');
    }
  }

  static String? getUserVote(String fixtureId) {
    return userVotes[fixtureId];
  }

  // ==========================================================================
  // POST COMMENTS CACHE
  // ==========================================================================
  static final Map<String, List<Comment>> _postComments = {};
  static final Map<String, DateTime> _lastCommentLoad = {};

  static List<Comment>? getCachedComments(String postId) {
    if (!_postComments.containsKey(postId)) {
      _lazyLoadPostCommentsFromDisk();
      return null;
    }
    return _postComments[postId];
  }

  static DateTime? getLastCommentLoad(String postId) =>
      _lastCommentLoad[postId];

  static void cacheComments(String postId, List<Comment> comments) {
    _postComments[postId] = comments;
    _lastCommentLoad[postId] = DateTime.now();
    _savePostCommentsToDisk();
    if (kDebugMode) {
      developer.log('💾 Cached ${comments.length} comments for post $postId',
          name: 'AppCache');
    }
  }

  static void addCommentToCache(String postId, Comment comment) {
    final existing = List<Comment>.from(_postComments[postId] ?? []);
    existing.insert(0, comment);
    _postComments[postId] = existing;
    _lastCommentLoad[postId] = DateTime.now();
    _savePostCommentsToDisk();
  }

  static void addReplyToCache(
    String postId,
    Comment reply,
    String parentCommentId,
  ) {
    final existing = _postComments[postId];
    if (existing == null) return;

    final parentIndex = existing.indexWhere((c) => c.id == parentCommentId);
    if (parentIndex == -1) return;

    final parent = existing[parentIndex];
    final replies = List<Comment>.from(parent.replies ?? [])..insert(0, reply);

    existing[parentIndex] = parent.copyWith(
      replies: replies,
      replyCount: parent.replyCount + 1,
    );
    _postComments[postId] = existing;
    _savePostCommentsToDisk();
  }

  // ==========================================================================
  // SAVE TO DISK - PERSISTENT STORAGE
  // ==========================================================================
  static Future<void> saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save fixtures
      final fixturesJson = fixtures.map((f) => f.toJson()).toList();
      await prefs.setString('fixtures_cache', jsonEncode(fixturesJson));
      await prefs.setInt(
          'fixtures_timestamp', DateTime.now().millisecondsSinceEpoch ~/ 1000);

      // Save user votes
      await prefs.setString('cached_user_votes', jsonEncode(userVotes));

      // Save channels
      final channelsJson = channels.map((c) => c.toJson()).toList();
      await prefs.setString('cached_channels', jsonEncode(channelsJson));

      // Save profile
      if (profile != null) {
        await prefs.setString('cached_profile', jsonEncode(profile));
      }

      // Save channel fixtures
      final channelFixturesJson = <String, dynamic>{};
      for (var entry in channelFixtures.entries) {
        channelFixturesJson[entry.key] = {
          'fixtureId': entry.value.fixtureId,
          'channelId': entry.value.channelId,
          'matchName': entry.value.matchName,
          'kickoffTime': entry.value.kickoffTime.toIso8601String(),
          'status': entry.value.status,
          'homeVotes': entry.value.homeVotes,
          'awayVotes': entry.value.awayVotes,
          'drawVotes': entry.value.drawVotes,
          'lastMessage': entry.value.lastMessage,
          'lastMessageAt': entry.value.lastMessageAt?.toIso8601String(),
          'lastSender': entry.value.lastSender,
          'userVote': entry.value.userVote,
          'commentCount': entry.value.commentCount,
          'unreadCounts': entry.value.unreadCounts,
        };
      }
      await prefs.setString(
          'channel_fixtures_cache', jsonEncode(channelFixturesJson));

      // Save vote counts
      await prefs.setString('vote_counts_cache', jsonEncode(_voteCounts));

      // Save comment counts
      await prefs.setString('comment_counts_cache', jsonEncode(_commentCounts));

      // Save like counts
      await prefs.setString('like_counts_cache', jsonEncode(_likeCounts));

      // Save pledge counts
      await prefs.setString('pledge_counts_cache', jsonEncode(_pledgeCounts));

      // Save bet counts
      await prefs.setString('bet_counts_cache', jsonEncode(_betCounts));

      // Save unread counts
      await prefs.setString('unread_counts_cache', jsonEncode(_unreadCounts));

      // Save latest comments
      final latestCommentsJson = <String, dynamic>{};
      for (var entry in _latestComments.entries) {
        latestCommentsJson[entry.key] = {
          'comment': entry.value,
          'author': _latestCommentAuthors[entry.key],
          'timestamp': _latestCommentTimestamps[entry.key]?.toIso8601String(),
        };
      }
      await prefs.setString(
          'latest_comments_cache', jsonEncode(latestCommentsJson));

      // Save messages
      await prefs.setString('cached_messages', jsonEncode(_cachedMessages));

      // Save comrades
      await prefs.setString('cached_comrades', jsonEncode(comrades));

      // Save user comrades
      await prefs.setStringList('cached_user_comrades', userComrades.toList());

      // Save comrade voters
      final comradeVotersJson = <String, List<Map<String, dynamic>>>{};
      for (var entry in comradeVoters.entries) {
        comradeVotersJson[entry.key] =
            entry.value.map((c) => c.toJson()).toList();
      }
      await prefs.setString(
          'cached_comrade_voters', jsonEncode(comradeVotersJson));

      // Save per-channel vote counts
      await prefs.setString(
          'per_channel_vote_counts', jsonEncode(perChannelVoteCounts));

      // Save history games
      final historyGamesJson = historyGames.map((g) => g.toJson()).toList();
      await prefs.setString(
          'history_games_cache', jsonEncode(historyGamesJson));

      // Save aftermatch data
      final aftermatchJson = <String, dynamic>{};
      for (var entry in _aftermatchData.entries) {
        aftermatchJson[entry.key] = entry.value.toJson();
      }
      await prefs.setString(
          'aftermatch_data_cache', jsonEncode(aftermatchJson));

      // Save live events
      await prefs.setString('live_events_cache', jsonEncode(_liveEvents));

      // Save voters list
      await prefs.setString('voters_cache', jsonEncode(_votersList));

      // Save history comments
      await _saveHistoryCommentsToDisk();

      debugPrint('💾 AppCache: All data saved to disk successfully');
    } catch (e) {
      debugPrint('❌ AppCache: Error saving to disk: $e');
    }
  }

  // ==========================================================================
  // LOAD FIXTURES FROM CACHE
  // ==========================================================================
  static Future<List<Fixture>?> loadFixturesFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fixturesJson = prefs.getString('fixtures_cache');

      if (fixturesJson == null) {
        debugPrint('📭 No fixtures cache found');
        return null;
      }

      final List<dynamic> data = jsonDecode(fixturesJson);
      final List<Fixture> loadedFixtures =
          data.map((f) => Fixture.fromJson(f as Map<String, dynamic>)).toList();

      debugPrint('📦 Loaded ${loadedFixtures.length} fixtures from disk cache');
      return loadedFixtures;
    } catch (e) {
      debugPrint('⚠️ Error loading fixtures from cache: $e');
      return null;
    }
  }

  // ==========================================================================
  // LOAD ALL DATA FROM DISK
  // ==========================================================================
  static Future<void> loadAllFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load fixtures
      final fixturesJson = prefs.getString('fixtures_cache');
      if (fixturesJson != null) {
        final List<dynamic> data = jsonDecode(fixturesJson);
        fixtures = data
            .map((f) => Fixture.fromJson(f as Map<String, dynamic>))
            .toList();
        debugPrint('📦 Loaded ${fixtures.length} fixtures from disk');
      }

      // Load user votes
      final votesJson = prefs.getString('cached_user_votes');
      if (votesJson != null) {
        userVotes = Map<String, String>.from(jsonDecode(votesJson));
        debugPrint('📦 Loaded ${userVotes.length} user votes from disk');
      }

      // Load channels
      final channelsJson = prefs.getString('cached_channels');
      if (channelsJson != null) {
        final List<dynamic> data = jsonDecode(channelsJson);
        channels = data
            .map((c) => UserChannel.fromJson(c as Map<String, dynamic>))
            .toList();
        debugPrint('📦 Loaded ${channels.length} channels from disk');
      }

      // Load profile
      final profileJson = prefs.getString('cached_profile');
      if (profileJson != null) {
        profile = jsonDecode(profileJson);
        debugPrint('📦 Loaded profile from disk');
      }

      // Load channel fixtures
      final channelFixturesJson = prefs.getString('channel_fixtures_cache');
      if (channelFixturesJson != null) {
        final Map<String, dynamic> data = jsonDecode(channelFixturesJson);
        for (var entry in data.entries) {
          final Map<String, dynamic> value = entry.value;
          channelFixtures[entry.key] = ChannelFixtureData(
            fixtureId: value['fixtureId'] ?? '',
            channelId: value['channelId'] ?? '',
            matchName: value['matchName'] ?? '',
            kickoffTime: DateTime.parse(
                value['kickoffTime'] ?? DateTime.now().toIso8601String()),
            status: value['status'] ?? 'upcoming',
            homeVotes: value['homeVotes'] ?? 0,
            awayVotes: value['awayVotes'] ?? 0,
            drawVotes: value['drawVotes'] ?? 0,
            lastMessage: value['lastMessage'],
            lastMessageAt: value['lastMessageAt'] != null
                ? DateTime.parse(value['lastMessageAt'])
                : null,
            lastSender: value['lastSender'],
            userVote: value['userVote'],
            commentCount: value['commentCount'] ?? 0,
            unreadCounts: Map<String, int>.from(value['unreadCounts'] ?? {}),
          );
        }
        debugPrint(
            '📦 Loaded ${channelFixtures.length} channel fixtures from disk');
      }

      // Load vote counts
      final voteCountsJson = prefs.getString('vote_counts_cache');
      if (voteCountsJson != null) {
        final Map<String, dynamic> data = jsonDecode(voteCountsJson);
        for (var entry in data.entries) {
          _voteCounts[entry.key] = entry.value as int;
        }
      }

      // Load comment counts
      final commentCountsJson = prefs.getString('comment_counts_cache');
      if (commentCountsJson != null) {
        final Map<String, dynamic> data = jsonDecode(commentCountsJson);
        for (var entry in data.entries) {
          _commentCounts[entry.key] = entry.value as int;
        }
      }

      // Load like counts
      final likeCountsJson = prefs.getString('like_counts_cache');
      if (likeCountsJson != null) {
        final Map<String, dynamic> data = jsonDecode(likeCountsJson);
        for (var entry in data.entries) {
          _likeCounts[entry.key] = entry.value as int;
        }
      }

      // Load pledge counts
      final pledgeCountsJson = prefs.getString('pledge_counts_cache');
      if (pledgeCountsJson != null) {
        final Map<String, dynamic> data = jsonDecode(pledgeCountsJson);
        for (var entry in data.entries) {
          _pledgeCounts[entry.key] = entry.value as int;
        }
      }

      // Load bet counts
      final betCountsJson = prefs.getString('bet_counts_cache');
      if (betCountsJson != null) {
        final Map<String, dynamic> data = jsonDecode(betCountsJson);
        for (var entry in data.entries) {
          _betCounts[entry.key] = entry.value as int;
        }
      }

      // Load unread counts
      final unreadCountsJson = prefs.getString('unread_counts_cache');
      if (unreadCountsJson != null) {
        final Map<String, dynamic> data = jsonDecode(unreadCountsJson);
        for (var entry in data.entries) {
          _unreadCounts[entry.key] = entry.value as int;
        }
      }

      // Load latest comments
      final latestCommentsJson = prefs.getString('latest_comments_cache');
      if (latestCommentsJson != null) {
        final Map<String, dynamic> data = jsonDecode(latestCommentsJson);
        for (var entry in data.entries) {
          final Map<String, dynamic> value = entry.value;
          _latestComments[entry.key] = value['comment'] as String?;
          _latestCommentAuthors[entry.key] = value['author'] as String?;
          if (value['timestamp'] != null) {
            _latestCommentTimestamps[entry.key] =
                DateTime.tryParse(value['timestamp']);
          }
        }
      }

      // Load messages
      final messagesJson = prefs.getString('cached_messages');
      if (messagesJson != null) {
        final Map<String, dynamic> data = jsonDecode(messagesJson);
        for (var entry in data.entries) {
          _cachedMessages[entry.key] =
              List<Map<String, dynamic>>.from(entry.value);
        }
      }

      // Load comrades
      final comradesJson = prefs.getString('cached_comrades');
      if (comradesJson != null) {
        comrades = List<Map<String, dynamic>>.from(jsonDecode(comradesJson));
      }

      // Load user comrades
      final userComradesList = prefs.getStringList('cached_user_comrades');
      if (userComradesList != null) {
        userComrades = Set<String>.from(userComradesList);
      }

      // Load comrade voters
      final comradeVotersJson = prefs.getString('cached_comrade_voters');
      if (comradeVotersJson != null) {
        final Map<String, dynamic> data = jsonDecode(comradeVotersJson);
        for (var entry in data.entries) {
          final List<dynamic> list = entry.value;
          comradeVoters[entry.key] = list
              .map(
                  (v) => ComradeWithProfile.fromJson(v as Map<String, dynamic>))
              .toList();
        }
      }

      // Load per-channel vote counts
      final perChannelVotesJson = prefs.getString('per_channel_vote_counts');
      if (perChannelVotesJson != null) {
        final Map<String, dynamic> data = jsonDecode(perChannelVotesJson);
        for (var entry in data.entries) {
          perChannelVoteCounts[entry.key] = Map<String, int>.from(entry.value);
        }
      }

      // Load history games
      final historyGamesJson = prefs.getString('history_games_cache');
      if (historyGamesJson != null) {
        final List<dynamic> data = jsonDecode(historyGamesJson);
        historyGames = data
            .map((g) => HistoryGame.fromJson(g as Map<String, dynamic>))
            .toList();
      }

      // Load aftermatch data
      final aftermatchJson = prefs.getString('aftermatch_data_cache');
      if (aftermatchJson != null) {
        final Map<String, dynamic> data = jsonDecode(aftermatchJson);
        for (var entry in data.entries) {
          _aftermatchData[entry.key] =
              AftermatchData.fromJson(entry.value as Map<String, dynamic>);
        }
      }

      // Load live events
      final liveEventsJson = prefs.getString('live_events_cache');
      if (liveEventsJson != null) {
        final Map<String, dynamic> data = jsonDecode(liveEventsJson);
        for (var entry in data.entries) {
          _liveEvents[entry.key] = List<Map<String, dynamic>>.from(entry.value);
        }
      }

      // Load voters list
      final votersJson = prefs.getString('voters_cache');
      if (votersJson != null) {
        final Map<String, dynamic> data = jsonDecode(votersJson);
        for (var entry in data.entries) {
          _votersList[entry.key] = List<Map<String, dynamic>>.from(entry.value);
        }
      }

      // Load history comments
      _lazyLoadHistoryCommentsFromDisk();

      isLoaded = true;
      debugPrint('✅ AppCache: All data loaded from disk successfully');
    } catch (e) {
      debugPrint('❌ AppCache: Error loading from disk: $e');
    }
  }

  // ==========================================================================
  // SAVE FIXTURES
  // ==========================================================================
  static Future<void> saveFixtures(List<Fixture> newFixtures) async {
    try {
      fixtures = newFixtures;

      final prefs = await SharedPreferences.getInstance();
      final fixturesJson = fixtures.map((f) => f.toJson()).toList();
      await prefs.setString('fixtures_cache', jsonEncode(fixturesJson));
      await prefs.setInt(
          'fixtures_timestamp', DateTime.now().millisecondsSinceEpoch ~/ 1000);

      // Notify listeners
      _fixturesController.add(fixtures);

      debugPrint('💾 Saved ${fixtures.length} fixtures to disk');
    } catch (e) {
      debugPrint('❌ Error saving fixtures: $e');
    }
  }

  static Future<void> _savePostCommentsToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = <String, dynamic>{};
      for (var entry in _postComments.entries) {
        serialized[entry.key] = entry.value.map((c) => c.toJson()).toList();
      }
      await prefs.setString('post_comments_cache', json.encode(serialized));
    } catch (e) {
      developer.log('⚠️ Failed to save post comments: $e', name: 'AppCache');
    }
  }

  static void _lazyLoadPostCommentsFromDisk() {
    unawaited(Future<void>(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final data = prefs.getString('post_comments_cache');
        if (data != null) {
          final Map<String, dynamic> decoded = jsonDecode(data);
          for (var entry in decoded.entries) {
            final List<dynamic> list = entry.value;
            _postComments[entry.key] = list
                .map((c) => Comment.fromJson(c as Map<String, dynamic>))
                .toList();
          }
          if (kDebugMode) {
            developer.log(
                '📦 Lazy loaded post comments for ${_postComments.length} posts',
                name: 'AppCache');
          }
        }
      } catch (e) {
        developer.log('⚠️ Lazy load post comments error: $e', name: 'AppCache');
      }
    }));
  }

  // ==========================================================================
  // SAVE/Load USER VOTES
  // ==========================================================================
  static Future<void> saveUserVotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_votes', jsonEncode(userVotes));
      if (kDebugMode) {
        developer.log('💾 AppCache: Saved ${userVotes.length} user votes',
            name: 'AppCache');
      }
    } catch (e) {
      developer.log('❌ AppCache: Error saving user votes: $e',
          name: 'AppCache');
    }
  }

  static Future<void> loadUserVotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('cached_user_votes');
      if (data != null) {
        final Map<String, dynamic> decoded = jsonDecode(data);
        userVotes = Map<String, String>.from(decoded);
        if (kDebugMode) {
          developer.log('📦 AppCache: Loaded ${userVotes.length} user votes',
              name: 'AppCache');
        }
      }
    } catch (e) {
      developer.log('❌ AppCache: Error loading user votes: $e',
          name: 'AppCache');
    }
  }

  // ==========================================================================
  // STATIC DATA
  // ==========================================================================
  static List<Map<String, dynamic>> comrades = [];
  static List<UserChannel> channels = [];
  static List<Fixture> fixtures = [];
  static Map<String, ChannelFixtureData> channelFixtures = {};
  static Map<String, Map<String, int>> perChannelVoteCounts = {};
  static Set<String> userComrades = {};
  static Map<String, List<ComradeWithProfile>> comradeVoters = {};
  static Set<String> addedComradeIds = {};
  static Map<String, dynamic>? profile;

  // ==========================================================================
  // STREAM NOTIFIER
  // ==========================================================================
  static final _fixturesController =
      StreamController<List<Fixture>>.broadcast();
  static Stream<List<Fixture>> get fixturesStream => _fixturesController.stream;

  // ==========================================================================
  // TIMESTAMP TRACKING
  // ==========================================================================
  static final Map<String, DateTime> _lastVoteUpdate = {};
  static final Map<String, DateTime> _lastCommentUpdate = {};
  static final Map<String, DateTime> _lastLikeUpdate = {};
  static final Map<String, DateTime> _lastLatestCommentUpdate = {};
  static final Map<String, DateTime> _lastPledgeUpdate = {};
  static final Map<String, DateTime> _lastBetUpdate = {};
  static final Map<String, DateTime> _lastUnreadUpdate = {};

  static DateTime? getLastVoteUpdate(String fixtureId) =>
      _lastVoteUpdate[fixtureId];
  static DateTime? getLastCommentUpdate(String fixtureId) =>
      _lastCommentUpdate[fixtureId];
  static DateTime? getLastLikeUpdate(String fixtureId) =>
      _lastLikeUpdate[fixtureId];
  static DateTime? getLastLatestCommentUpdate(String fixtureId) =>
      _lastLatestCommentUpdate[fixtureId];
  static DateTime? getLastPledgeUpdate(String fixtureId) =>
      _lastPledgeUpdate[fixtureId];
  static DateTime? getLastBetUpdate(String fixtureId) =>
      _lastBetUpdate[fixtureId];

  // ==========================================================================
  // VOTE COUNTS
  // ==========================================================================
  static final Map<String, int> _voteCounts = {};
  static int? getVoteCount(String fixtureId) => _voteCounts[fixtureId];

  // ==========================================================================
  // COMMENT COUNTS
  // ==========================================================================
  static int? getCommentCount(String fixtureId) => _commentCounts[fixtureId];

  // ==========================================================================
  // LIKE COUNTS
  // ==========================================================================
  static final Map<String, int> _likeCounts = {};
  static int? getLikeCount(String fixtureId) => _likeCounts[fixtureId];

  // ==========================================================================
  // PLEDGE COUNTS
  // ==========================================================================
  static final Map<String, int> _pledgeCounts = {};
  static int? getPledgeCount(String fixtureId) => _pledgeCounts[fixtureId];

  // ==========================================================================
  // BET COUNTS
  // ==========================================================================
  static final Map<String, int> _betCounts = {};
  static int? getBetCount(String fixtureId) => _betCounts[fixtureId];

  // ==========================================================================
  // USER LIKES
  // ==========================================================================
  static final Map<String, bool> _userLikes = {};
  static bool? getUserLike(String fixtureId) => _userLikes[fixtureId];

  // ==========================================================================
  // UNREAD COUNTS
  // ==========================================================================
  static final Map<String, int> _unreadCounts = {};
  static int? getUnreadCount(String fixtureId) => _unreadCounts[fixtureId];

  // ==========================================================================
  // LATEST COMMENTS
  // ==========================================================================
  static final Map<String, String?> _latestComments = {};
  static final Map<String, String?> _latestCommentAuthors = {};
  static final Map<String, DateTime?> _latestCommentTimestamps = {};

  static String? getLatestComment(String fixtureId) =>
      _latestComments[fixtureId];
  static String? getLatestCommentAuthor(String fixtureId) =>
      _latestCommentAuthors[fixtureId];
  static DateTime? getLatestCommentTimestamp(String fixtureId) =>
      _latestCommentTimestamps[fixtureId];

  // ==========================================================================
  // LIVE EVENTS
  // ==========================================================================
  static final Map<String, List<Map<String, dynamic>>> _liveEvents = {};
  static List<Map<String, dynamic>>? getLiveEvents(String fixtureId) =>
      _liveEvents[fixtureId];

  // ==========================================================================
  // VOTERS LIST
  // ==========================================================================
  static final Map<String, List<Map<String, dynamic>>> _votersList = {};
  static List<Map<String, dynamic>>? getVotersList(String fixtureId) =>
      _votersList[fixtureId];

  // ==========================================================================
  // MESSAGE CACHE
  // ==========================================================================
  static final Map<String, List<Map<String, dynamic>>> _cachedMessages = {};
  static Map<String, List<Map<String, dynamic>>> get cachedMessages =>
      _cachedMessages;
// ==========================================================================
  // MESSAGE DISK-LOAD COORDINATION
  // ==========================================================================
  // Guards against _loadDeferredData() (background, unawaited from load())
  // and getCachedMessagesAsync() (called from ChatScreen on navigation)
  // both reading 'cached_messages' from SharedPreferences at the same time.
  // Whichever one starts first "wins" and the other just awaits its result.
  static Completer<void>? _messagesDiskLoadCompleter;
  // ==========================================================================
  // ADMIN DASHBOARD CACHES
  // ==========================================================================
  static final Map<String, Map<String, dynamic>> _cachedChannelStats = {};
  static final Map<String, List<Map<String, dynamic>>> _cachedChannelMembers =
      {};
  static Map<String, Map<String, dynamic>> get cachedChannelStats =>
      _cachedChannelStats;
  static Map<String, List<Map<String, dynamic>>> get cachedChannelMembers =>
      _cachedChannelMembers;

  // ==========================================================================
  // LINEUP CACHES
  // ==========================================================================
  static final Map<String, Map<String, dynamic>> _cachedLineups = {};
  static Map<String, Map<String, dynamic>> get cachedLineups => _cachedLineups;

  // ==========================================================================
  // COMRADE MODAL CACHES
  // ==========================================================================
  static final Map<String, List<Map<String, dynamic>>>
      _cachedComradeLeaderboard = {};
  static final Map<String, List<Map<String, dynamic>>>
      _cachedComradeVotersData = {};
  static Map<String, List<Map<String, dynamic>>> get cachedComradeLeaderboard =>
      _cachedComradeLeaderboard;
  static Map<String, List<Map<String, dynamic>>> get cachedComradeVotersData =>
      _cachedComradeVotersData;

  // ==========================================================================
  // AFTERMATCH REVIEW CACHES
  // ==========================================================================
  static final Map<String, AftermatchData> _aftermatchData = {};

  static AftermatchData? getAftermatchData(String fixtureId) {
    return _aftermatchData[fixtureId];
  }

  static void cacheAftermatchData(String fixtureId, AftermatchData data) {
    _aftermatchData[fixtureId] = data;
    _saveAftermatchDataToDisk();
    if (kDebugMode) {
      developer.log('📦 Cached aftermatch data for fixture: $fixtureId',
          name: 'AppCache');
    }
  }

  static Future<void> _saveAftermatchDataToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = <String, dynamic>{};
      for (var entry in _aftermatchData.entries) {
        serialized[entry.key] = entry.value.toJson();
      }
      await prefs.setString('aftermatch_data_cache', json.encode(serialized));
    } catch (e) {
      developer.log('⚠️ Failed to save aftermatch data: $e', name: 'AppCache');
    }
  }

  static Future<void> _loadAftermatchDataFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('aftermatch_data_cache');
      if (data == null) return;

      final Map<String, dynamic> decoded = json.decode(data);
      for (var entry in decoded.entries) {
        _aftermatchData[entry.key] =
            AftermatchData.fromJson(entry.value as Map<String, dynamic>);
      }
      if (kDebugMode) {
        developer.log(
            '📦 Loaded ${_aftermatchData.length} aftermatch data sets',
            name: 'AppCache');
      }
    } catch (e) {
      developer.log('⚠️ Failed to load aftermatch data: $e', name: 'AppCache');
    }
  }

  // ==========================================================================
  // AFTERMATCH DATA FETCHING
  // ==========================================================================
  static Future<AftermatchData?> fetchAftermatchData(
    String fixtureId, {
    String? channelId,
    String? authToken,
  }) async {
    try {
      if (kDebugMode) {
        developer.log('🔄 Fetching aftermatch data for: $fixtureId',
            name: 'AppCache');
      }

      final headers = {'Content-Type': 'application/json'};
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final results = await Future.wait([
        _fetchVoters(fixtureId, headers),
        _fetchPledges(fixtureId, channelId, headers),
        _fetchBets(fixtureId, channelId, headers),
        _fetchSubFixtures(fixtureId, headers),
      ]);

      final voters = results[0] as List<Map<String, dynamic>>;
      final pledges = results[1] as List<Map<String, dynamic>>;
      final bets = results[2] as List<Map<String, dynamic>>;
      final subFixtures = results[3] as List<Map<String, dynamic>>;

      final data = AftermatchData(
        fixtureId: fixtureId,
        voters: voters,
        pledges: pledges,
        bets: bets,
        subFixtures: subFixtures,
        lastUpdated: DateTime.now(),
      );

      cacheAftermatchData(fixtureId, data);
      return data;
    } catch (e) {
      developer.log('❌ Error fetching aftermatch data: $e', name: 'AppCache');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchVoters(
    String fixtureId,
    Map<String, String> headers,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse(
                'https://clash-api-m5mr.onrender.com/api/actions/vote/fixture/$fixtureId/voters'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['voters'] as List? ?? []).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      developer.log('⚠️ Error fetching voters: $e', name: 'AppCache');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchPledges(
    String fixtureId,
    String? channelId,
    Map<String, String> headers,
  ) async {
    if (channelId == null) return [];
    try {
      final response = await http
          .get(
            Uri.parse(
                'https://clash-api-m5mr.onrender.com/api/actions/channel/$channelId/$fixtureId/pledges'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['pledges'] as List? ?? []).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      developer.log('⚠️ Error fetching pledges: $e', name: 'AppCache');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchBets(
    String fixtureId,
    String? channelId,
    Map<String, String> headers,
  ) async {
    if (channelId == null) return [];
    try {
      final response = await http
          .get(
            Uri.parse(
                'https://clash-api-m5mr.onrender.com/api/actions/channel/$channelId/$fixtureId/bettors'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['bettors'] as List? ?? []).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      developer.log('⚠️ Error fetching bets: $e', name: 'AppCache');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchSubFixtures(
    String fixtureId,
    Map<String, String> headers,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse(
                'https://clash-api-m5mr.onrender.com/api/sub_fixtures/markets/$fixtureId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['markets'] as List? ?? []).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      developer.log('⚠️ Error fetching sub-fixtures: $e', name: 'AppCache');
      return [];
    }
  }

  static bool isLoaded = false;
  static bool _criticalLoaded = false;

  // ==========================================================================
  // SINGLE UPDATE METHOD
  // ==========================================================================
  static void applyUpdate({
    required String fixtureId,
    required String updateType,
    required int value,
    Map<String, dynamic>? extraData,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();

    final lastUpdate = _getLastUpdate(fixtureId, updateType);
    if (lastUpdate != null && now.isBefore(lastUpdate)) {
      if (kDebugMode) {
        developer.log('⏭️ Stale update ignored: $fixtureId $updateType',
            name: 'AppCache');
      }
      return;
    }

    if (kDebugMode) {
      developer.log('📥 AppCache update: $fixtureId $updateType = $value',
          name: 'AppCache');
    }

    switch (updateType) {
      case 'vote':
        _lastVoteUpdate[fixtureId] = now;
        _voteCounts[fixtureId] = value;
        final channelId = extraData?['channelId'] as String? ?? 'default';
        perChannelVoteCounts[fixtureId] ??= {};
        perChannelVoteCounts[fixtureId]![channelId] = value;

        if (extraData?['userVote'] != null) {
          userVotes[fixtureId] = extraData!['userVote'] as String;
          saveUserVotes();
          notifyVotesChanged();
        }

        if (channelFixtures.containsKey(fixtureId)) {
          final existing = channelFixtures[fixtureId]!;
          channelFixtures[fixtureId] = ChannelFixtureData(
            fixtureId: existing.fixtureId,
            channelId: existing.channelId,
            matchName: existing.matchName,
            kickoffTime: existing.kickoffTime,
            status: existing.status,
            homeVotes: extraData?['homeVotes'] ?? existing.homeVotes,
            awayVotes: extraData?['awayVotes'] ?? existing.awayVotes,
            drawVotes: extraData?['drawVotes'] ?? existing.drawVotes,
            lastMessage: existing.lastMessage,
            lastMessageAt: existing.lastMessageAt,
            lastSender: existing.lastSender,
            userVote: extraData?['userVote'] ?? existing.userVote,
            commentCount: existing.commentCount,
            unreadCounts: existing.unreadCounts,
          );
        }
        break;

      case 'comment':
        _lastCommentUpdate[fixtureId] = now;
        _commentCounts[fixtureId] = value;

        if (channelFixtures.containsKey(fixtureId)) {
          final existing = channelFixtures[fixtureId]!;
          channelFixtures[fixtureId] = ChannelFixtureData(
            fixtureId: existing.fixtureId,
            channelId: existing.channelId,
            matchName: existing.matchName,
            kickoffTime: existing.kickoffTime,
            status: existing.status,
            homeVotes: existing.homeVotes,
            awayVotes: existing.awayVotes,
            drawVotes: existing.drawVotes,
            lastMessage: existing.lastMessage,
            lastMessageAt: existing.lastMessageAt,
            lastSender: existing.lastSender,
            userVote: existing.userVote,
            commentCount: value,
            unreadCounts: existing.unreadCounts,
          );
        }
        break;

      case 'like':
        _lastLikeUpdate[fixtureId] = now;
        _likeCounts[fixtureId] = value;
        if (extraData != null) {
          _userLikes[fixtureId] = extraData['liked'] as bool? ?? false;
        }
        break;

      case 'pledge':
        _lastPledgeUpdate[fixtureId] = now;
        _pledgeCounts[fixtureId] = value;
        break;

      case 'bet':
        _lastBetUpdate[fixtureId] = now;
        _betCounts[fixtureId] = value;
        break;

      case 'unread':
        _lastUnreadUpdate[fixtureId] = now;
        _unreadCounts[fixtureId] = value;
        break;

      case 'latest_comment':
        _lastLatestCommentUpdate[fixtureId] = now;
        _latestComments[fixtureId] = extraData?['comment'] as String?;
        _latestCommentAuthors[fixtureId] = extraData?['username'] as String?;
        _latestCommentTimestamps[fixtureId] = now;
        break;

      case 'live_event':
        final event = extraData?['event'] as Map<String, dynamic>?;
        if (event != null) {
          final events = _liveEvents[fixtureId] ?? [];
          events.insert(0, event);
          if (events.length > 20) events.removeLast();
          _liveEvents[fixtureId] = events;
        }
        break;

      case 'voters':
        final votersList = extraData?['voters'] as List<Map<String, dynamic>>?;
        if (votersList != null) {
          _votersList[fixtureId] = votersList;
        }
        break;
    }

    _saveToDisk(fixtureId, updateType, value, extraData);
    _fixturesController.add(fixtures);
  }

  static DateTime? _getLastUpdate(String fixtureId, String type) {
    switch (type) {
      case 'vote':
        return _lastVoteUpdate[fixtureId];
      case 'comment':
        return _lastCommentUpdate[fixtureId];
      case 'like':
        return _lastLikeUpdate[fixtureId];
      case 'latest_comment':
        return _lastLatestCommentUpdate[fixtureId];
      case 'pledge':
        return _lastPledgeUpdate[fixtureId];
      case 'bet':
        return _lastBetUpdate[fixtureId];
      case 'unread':
        return _lastUnreadUpdate[fixtureId];
      default:
        return null;
    }
  }

  // ==========================================================================
  // NOTIFY FIXTURES CHANGED
  // ==========================================================================
  static void notifyFixturesChanged() {
    _fixturesController.add(fixtures);
    if (kDebugMode) {
      developer.log('📢 AppCache notified listeners of fixture update',
          name: 'AppCache');
    }
  }

  // ==========================================================================
  // BACKGROUND SAVE TO DISK
  // ==========================================================================
  static Future<void> _saveToDisk(
    String fixtureId,
    String type,
    int value,
    Map<String, dynamic>? extraData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      switch (type) {
        case 'vote':
          final voteData = prefs.getString('per_channel_vote_counts') ?? '{}';
          final Map<String, dynamic> data = json.decode(voteData);
          final channelId = extraData?['channelId'] as String? ?? 'default';
          data[fixtureId] ??= {};
          data[fixtureId][channelId] = value;
          await prefs.setString('per_channel_vote_counts', json.encode(data));

          final fastData = prefs.getString('vote_counts_cache') ?? '{}';
          final Map<String, dynamic> fastMap = json.decode(fastData);
          fastMap[fixtureId] = value;
          await prefs.setString('vote_counts_cache', json.encode(fastMap));

          if (extraData?['userVote'] != null) {
            userVotes[fixtureId] = extraData!['userVote'] as String;
            await saveUserVotes();
          }
          break;

        case 'comment':
          final commentData = prefs.getString('comment_counts_cache') ?? '{}';
          final Map<String, dynamic> data = json.decode(commentData);
          data[fixtureId] = value;
          await prefs.setString('comment_counts_cache', json.encode(data));
          break;

        case 'like':
          final likeData = prefs.getString('like_counts_cache') ?? '{}';
          final Map<String, dynamic> data = json.decode(likeData);
          data[fixtureId] = value;
          await prefs.setString('like_counts_cache', json.encode(data));
          break;

        case 'pledge':
          final pledgeData = prefs.getString('pledge_counts_cache') ?? '{}';
          final Map<String, dynamic> data = json.decode(pledgeData);
          data[fixtureId] = value;
          await prefs.setString('pledge_counts_cache', json.encode(data));
          break;

        case 'bet':
          final betData = prefs.getString('bet_counts_cache') ?? '{}';
          final Map<String, dynamic> data = json.decode(betData);
          data[fixtureId] = value;
          await prefs.setString('bet_counts_cache', json.encode(data));
          break;

        case 'unread':
          final unreadData = prefs.getString('unread_counts_cache') ?? '{}';
          final Map<String, dynamic> data = json.decode(unreadData);
          data[fixtureId] = value;
          await prefs.setString('unread_counts_cache', json.encode(data));
          break;

        case 'latest_comment':
          final latestData = prefs.getString('latest_comments_cache') ?? '{}';
          final Map<String, dynamic> data = json.decode(latestData);
          data[fixtureId] = {
            'comment': extraData?['comment'],
            'author': extraData?['username'],
            'timestamp': DateTime.now().toIso8601String(),
          };
          await prefs.setString('latest_comments_cache', json.encode(data));
          break;

        case 'live_event':
          final liveData = prefs.getString('live_events_cache') ?? '{}';
          final Map<String, dynamic> data = json.decode(liveData);
          final events = data[fixtureId] as List? ?? [];
          final event = extraData?['event'] as Map<String, dynamic>?;
          if (event != null) {
            events.insert(0, event);
            if (events.length > 20) events.removeLast();
            data[fixtureId] = events;
            await prefs.setString('live_events_cache', json.encode(data));
          }
          break;

        case 'voters':
          final votersData = prefs.getString('voters_cache') ?? '{}';
          final Map<String, dynamic> data = json.decode(votersData);
          final votersList =
              extraData?['voters'] as List<Map<String, dynamic>>?;
          if (votersList != null) {
            data[fixtureId] = votersList;
            await prefs.setString('voters_cache', json.encode(data));
          }
          break;
      }
    } catch (e) {
      developer.log('⚠️ Failed to save update to disk: $e', name: 'AppCache');
    }
  }

  // ==========================================================================
  // SAVE METHODS
  // ==========================================================================
  static Future<void> saveVoteCount(String fixtureId, int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fastData = prefs.getString('vote_counts_cache') ?? '{}';
      final Map<String, dynamic> fastMap = json.decode(fastData);
      fastMap[fixtureId] = count;
      await prefs.setString('vote_counts_cache', json.encode(fastMap));
      _voteCounts[fixtureId] = count;
      if (kDebugMode) {
        developer.log('💾 Saved vote count $count for fixture $fixtureId',
            name: 'AppCache');
      }
    } catch (e) {
      developer.log('⚠️ Failed to save vote count: $e', name: 'AppCache');
    }
  }

  static Future<void> saveCommentCount(String fixtureId, int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final commentData = prefs.getString('comment_counts_cache') ?? '{}';
      final Map<String, dynamic> data = json.decode(commentData);
      data[fixtureId] = count;
      await prefs.setString('comment_counts_cache', json.encode(data));
      _commentCounts[fixtureId] = count;
      if (kDebugMode) {
        developer.log('💾 Saved comment count $count for fixture $fixtureId',
            name: 'AppCache');
      }
    } catch (e) {
      developer.log('⚠️ Failed to save comment count: $e', name: 'AppCache');
    }
  }

  static Future<void> saveLatestComment(
    String fixtureId,
    String comment,
    String author, {
    String? replyToText,
    bool isReply = false,
    bool isCommentaryReply = false,
    String? commentaryType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final latestData = prefs.getString('latest_comments_cache') ?? '{}';
      final Map<String, dynamic> data = json.decode(latestData);

      final Map<String, dynamic> commentData = {
        'comment': comment,
        'author': author,
        'timestamp': DateTime.now().toIso8601String(),
        'isReply': isReply,
        'isCommentaryReply': isCommentaryReply,
      };

      if (replyToText != null) {
        commentData['replyTo'] = replyToText;
      }

      if (commentaryType != null) {
        commentData['commentaryType'] = commentaryType;
      }

      data[fixtureId] = commentData;
      await prefs.setString('latest_comments_cache', json.encode(data));

      _latestComments[fixtureId] = comment;
      _latestCommentAuthors[fixtureId] = author;
      _latestCommentTimestamps[fixtureId] = DateTime.now();
      _latestCommentReplyTo[fixtureId] = replyToText;
      _latestCommentIsReply[fixtureId] = isReply;
      _latestCommentIsCommentaryReply[fixtureId] = isCommentaryReply;

      if (kDebugMode) {
        if (isReply) {
          developer.log(
              '💾 Saved reply comment for fixture $fixtureId: "$comment" replying to "$replyToText"',
              name: 'AppCache');
        } else if (isCommentaryReply) {
          developer.log(
              '🎙️ Saved commentary reply for fixture $fixtureId: "$comment"',
              name: 'AppCache');
        } else {
          developer.log('💾 Saved latest comment for fixture $fixtureId',
              name: 'AppCache');
        }
      }
    } catch (e) {
      developer.log('⚠️ Failed to save latest comment: $e', name: 'AppCache');
    }
  }

  static final Map<String, String?> _latestCommentReplyTo = {};
  static final Map<String, bool> _latestCommentIsReply = {};
  static final Map<String, bool> _latestCommentIsCommentaryReply = {};

  static String? getLatestCommentReplyTo(String fixtureId) {
    return _latestCommentReplyTo[fixtureId];
  }

  static bool getLatestCommentIsReply(String fixtureId) {
    return _latestCommentIsReply[fixtureId] ?? false;
  }

  static bool getLatestCommentIsCommentaryReply(String fixtureId) {
    return _latestCommentIsCommentaryReply[fixtureId] ?? false;
  }

  static Future<void> saveLikeCount(String fixtureId, int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final likeData = prefs.getString('like_counts_cache') ?? '{}';
      final Map<String, dynamic> data = json.decode(likeData);
      data[fixtureId] = count;
      await prefs.setString('like_counts_cache', json.encode(data));
      _likeCounts[fixtureId] = count;
      if (kDebugMode) {
        developer.log('💾 Saved like count $count for fixture $fixtureId',
            name: 'AppCache');
      }
    } catch (e) {
      developer.log('⚠️ Failed to save like count: $e', name: 'AppCache');
    }
  }

  static Future<void> saveUnreadCount(String fixtureId, int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unreadData = prefs.getString('unread_counts_cache') ?? '{}';
      final Map<String, dynamic> data = json.decode(unreadData);
      data[fixtureId] = count;
      await prefs.setString('unread_counts_cache', json.encode(data));
      _unreadCounts[fixtureId] = count;
      if (kDebugMode) {
        developer.log('💾 Saved unread count $count for fixture $fixtureId',
            name: 'AppCache');
      }
    } catch (e) {
      developer.log('⚠️ Failed to save unread count: $e', name: 'AppCache');
    }
  }

  // ==========================================================================
  // CHAT MESSAGE FETCHING
  // ==========================================================================
  static Future<List<Map<String, dynamic>>> fetchChatMessages(
    String channelId,
    String? fixtureId, {
    String? authToken,
    int limit = 100,
  }) async {
    try {
      final headers = {'Content-Type': 'application/json'};
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      String url;
      if (fixtureId != null) {
        url =
            'https://clash-api-m5mr.onrender.com/api/channels/$channelId/messages'
            '?fixture_id=$fixtureId'
            '&limit=$limit';
      } else {
        url =
            'https://clash-api-m5mr.onrender.com/api/channels/$channelId/messages'
            '?limit=$limit';
      }

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> messagesData = data['messages'] ?? [];

        final List<Map<String, dynamic>> messages =
            messagesData.map((item) => _convertMessageToMap(item)).toList();

        final key = fixtureId != null
            ? '${channelId}_$fixtureId'
            : '${channelId}_overall';
        _cachedMessages[key] = messages;
        await _saveMessagesToDisk();

        if (kDebugMode) {
          developer.log('📥 Fetched ${messages.length} chat messages for $key',
              name: 'AppCache');
        }
        return messages;
      }

      if (kDebugMode) {
        developer.log(
            '⚠️ Failed to fetch chat messages: ${response.statusCode}',
            name: 'AppCache');
      }
      return [];
    } catch (e) {
      developer.log('❌ Error fetching chat messages: $e', name: 'AppCache');
      return [];
    }
  }

  static Map<String, dynamic> _convertMessageToMap(dynamic item) {
    String id = item['message_id'] ?? '';
    if (id.isEmpty) {
      final idObj = item['_id'];
      if (idObj is Map && idObj['\$oid'] != null) {
        id = idObj['\$oid'];
      } else if (idObj is String) {
        id = idObj;
      }
    }

    DateTime timestamp;
    final sentAt = item['sent_at'];
    if (sentAt is Map) {
      final dateObj = sentAt['\$date'];
      if (dateObj is Map && dateObj['\$numberLong'] != null) {
        final milliseconds = int.parse(dateObj['\$numberLong'].toString());
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

    Map<String, dynamic>? replyTo;
    if (item['reply_to'] != null && item['reply_to'] is Map) {
      final replyData = item['reply_to'] as Map;
      replyTo = {
        'messageId': replyData['messageId'] ?? '',
        'text': replyData['text'] ?? '',
        'username': replyData['username'] ?? '',
        'selection': replyData['selection'],
        'isMe': replyData['isMe'] ?? false,
      };
    }

    final bool isCommentary = item['is_commentary'] == true ||
        (item['username']?.toString().contains('Commentary') ?? false) ||
        (item['sender_name']?.toString().contains('Commentary') ?? false);

    return {
      'id': id,
      'userId': item['sender_id'] ?? (isCommentary ? '__commentary__' : ''),
      'username': item['sender_name'] ??
          (isCommentary ? 'Live Commentary' : 'Anonymous'),
      'text': item['text'] ?? '',
      'selection': item['selection'],
      'timestamp': timestamp.toIso8601String(),
      'status': 1,
      'isSeen': false,
      'isCommentary': isCommentary,
      'commentaryType': item['commentary_type'],
      'replyTo': replyTo,
      'imageUrl': item['image_url'],
      'videoUrl': item['video_url'],
      'videoThumbnailUrl': item['video_thumbnail_url'],
      'isImage': item['is_image'] ?? false,
      'isVideo': item['is_video'] ?? false,
    };
  }

  // ==========================================================================
  // GET ACTIVE FIXTURE AND CHANNEL
  // ==========================================================================
  static String? getActiveFixtureId() {
    if (fixtures.isEmpty) return null;

    for (var f in fixtures) {
      if (f.isLive == true || f.status == 'live') {
        return f.matchId ?? f.id;
      }
    }

    for (var f in fixtures) {
      if (f.status == 'upcoming' || f.status == 'soon') {
        return f.matchId ?? f.id;
      }
    }

    return fixtures.first.matchId ?? fixtures.first.id;
  }

  static String? getActiveChannelId() {
    if (channels.isNotEmpty) {
      return channels.first.channelId;
    }
    return null;
  }

  // ==========================================================================
  // REFRESH ALL
  // ==========================================================================
  static Future<void> refreshAll() async {
    if (kDebugMode) {
      developer.log('🔄 AppCache: Refreshing all data from API...',
          name: 'AppCache');
    }

    final authService = AuthService();
    final isLoggedIn = authService.isLoggedIn;
    final userId = authService.userId;
    final authToken = authService.authToken;

    await Future.wait([
      refreshFixturesWithTime(),
      refreshComrades(authToken),
      refreshHistoryGames(authToken: authToken),
      if (isLoggedIn && userId != null) ...[
        _refreshProfile(userId, authToken),
        refreshChannels(userId, authToken),
        _refreshUserVotes(userId, authToken),
      ],
    ]);

    final activeFixtureId = getActiveFixtureId();
    final channelId = getActiveChannelId();
    if (activeFixtureId != null && channelId != null) {
      unawaited(fetchChatMessages(
        channelId,
        activeFixtureId,
        authToken: authToken,
        limit: 50,
      ));
    }

    if (kDebugMode) {
      developer.log('✅ AppCache: Refresh complete', name: 'AppCache');
    }
  }
    // ==========================================================================
  // REFRESH FIXTURES WITH TIME - DIFFED (only notifies on real change)
  // ==========================================================================
  static Future<void> refreshFixturesWithTime() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://clash-api-m5mr.onrender.com/api/games'
          '?_=${DateTime.now().millisecondsSinceEpoch}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> fixturesData =
            data['data'] ?? data['fixtures'] ?? [];
        final newFixtures =
            fixturesData.map((f) => Fixture.fromJson(f)).toList();

        // ✅ Compare against what's currently held before touching anything.
        // A JSON-based compare avoids requiring Fixture to implement ==/hashCode
        // itself — if two payloads serialize identically, nothing changed.
        final bool changed = !_fixtureListsEqual(fixtures, newFixtures);

        if (!changed) {
          if (kDebugMode) {
            developer.log('⏭️ Fixtures refresh: no changes, skipping repaint',
                name: 'AppCache');
          }
          return;
        }

        fixtures = newFixtures;

        for (var f in fixtures) {
          if (f.isLive && f.timeElapsed != null) {
            if (kDebugMode) {
              developer.log(
                  '🔴 Live match ${f.matchId}: timeElapsed = ${f.timeElapsed}',
                  name: 'AppCache');
            }
          }
        }

        await saveFixtures(fixtures);
        _fixturesController.add(fixtures);
        if (kDebugMode) {
          developer.log(
              '✅ AppCache: Refreshed ${fixtures.length} fixtures (changed)',
              name: 'AppCache');
        }
      }
    } catch (e) {
      developer.log('❌ AppCache: Failed to refresh fixtures: $e',
          name: 'AppCache');
    }
  }

  // Structural compare via toJson() — cheap, no need to touch the Fixture
  // model. Order-sensitive on purpose: if the API reorders fixtures, that's
  // a real change worth repainting for.
  static bool _fixtureListsEqual(List<Fixture> a, List<Fixture> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (json.encode(a[i].toJson()) != json.encode(b[i].toJson())) {
        return false;
      }
    }
    return true;
  }

  // ==========================================================================
  // REFRESH CHANNELS - DIFFED
  // ==========================================================================
  static Future<void> refreshChannels(String userId, String? authToken) async {
  try {
    final headers = {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
    };
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    final response = await http
        .get(
          Uri.parse(
            'https://clash-api-m5mr.onrender.com/api/channels/user/$userId'
            '?_=${DateTime.now().millisecondsSinceEpoch}',
          ),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> channelsData = data['channels'] ?? [];
      final newChannels = channelsData
          .map((c) => UserChannel.fromJson(c as Map<String, dynamic>))
          .toList();

      final bool changed = channels.length != newChannels.length ||
          !_listsEqualByJson(
            channels.map((c) => c.toJson()).toList(),
            newChannels.map((c) => c.toJson()).toList(),
          );

      if (!changed) {
        if (kDebugMode) {
          developer.log('⏭️ Channels refresh: no changes, skipping repaint',
              name: 'AppCache');
        }
        return;
      }

      channels = newChannels;
      await saveChannels(channels);
      _fixturesController.add(fixtures); // existing behavior preserved
      if (kDebugMode) {
        developer.log(
            '✅ AppCache: Refreshed ${channels.length} channels (changed)',
            name: 'AppCache');
      }
    }
  } catch (e) {
    developer.log('❌ AppCache: Failed to refresh channels: $e',
        name: 'AppCache');
  }
}

  // ==========================================================================
  // REFRESH COMRADES - DIFFED
  // ==========================================================================
  static Future<void> refreshComrades(String? authToken) async {
  try {
    final headers = {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
    };
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    final response = await http
        .get(
          Uri.parse(
            'https://clash-api-m5mr.onrender.com/api/profile/profiles'
            '?_=${DateTime.now().millisecondsSinceEpoch}',
          ),
          headers: headers,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      final List<Map<String, dynamic>> profiles =
          data.cast<Map<String, dynamic>>();

      final authService = AuthService();
      final userId = authService.userId;

      List<Map<String, dynamic>> availableUsers;
      if (userId != null && userId.isNotEmpty) {
        availableUsers = profiles
            .where((profile) => profile['user_id']?.toString() != userId)
            .toList();
      } else {
        availableUsers = List.from(profiles);
      }

      final newComrades = availableUsers
          .map((item) => {
                'id': item['user_id']?.toString() ?? '',
                'nickname': item['nickname']?.toString() ??
                    item['username']?.toString() ??
                    'Fan',
                'club': item['club_fan']?.toString() ?? 'Football Fan',
                'country': item['country_fan']?.toString() ?? 'World',
                'username': item['username']?.toString() ?? 'user',
              })
          .toList();

      final bool changed = !_listsEqualByJson(comrades, newComrades);

      if (!changed) {
        if (kDebugMode) {
          developer.log('⏭️ Comrades refresh: no changes, skipping repaint',
              name: 'AppCache');
        }
        return;
      }

      comrades = newComrades;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_comrades', jsonEncode(comrades));
      if (kDebugMode) {
        developer.log(
            '✅ AppCache: Refreshed ${comrades.length} comrades (changed)',
            name: 'AppCache');
      }
    }
  } catch (e) {
    developer.log('❌ AppCache: Failed to refresh comrades: $e',
        name: 'AppCache');
  }
}
  // Generic structural compare for List<Map<String, dynamic>> payloads.
  static bool _listsEqualByJson(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (json.encode(a[i]) != json.encode(b[i])) return false;
    }
    return true;
  }

 

  static Future<void> _refreshProfile(String userId, String? authToken) async {
    try {
      final headers = {'Content-Type': 'application/json'};
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http
          .get(
            Uri.parse(
                'https://clash-api-m5mr.onrender.com/api/profile/profile/$userId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final Map<String, dynamic> userMap = decoded is List
            ? Map<String, dynamic>.from(decoded.first as Map)
            : Map<String, dynamic>.from(decoded);

        final enrichedProfile = {
          ...userMap,
          'nickname': userMap['nickname'] ?? userMap['username'] ?? 'Fan',
          'club_fan': userMap['club_fan'] ?? 'No Club',
          'country_fan': userMap['country_fan'] ?? 'World',
          'points': userMap['points'] ?? userMap['season_points'] ?? 0,
        };
        await saveProfile(enrichedProfile);
        if (kDebugMode) {
          developer.log('✅ AppCache: Refreshed profile for $userId',
              name: 'AppCache');
        }
      }
    } catch (e) {
      developer.log('❌ AppCache: Failed to refresh profile: $e',
          name: 'AppCache');
    }
  }

  

  static Future<void> _refreshUserVotes(
      String userId, String? authToken) async {
    try {
      final headers = {'Content-Type': 'application/json'};
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http
          .get(
            Uri.parse(
                'https://clash-api-m5mr.onrender.com/api/channels/votes/user/$userId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final Map<String, String> votes = {};

        if (data['votes'] is List) {
          for (var vote in data['votes']) {
            final fixtureId = vote['fixture_id']?.toString() ?? '';
            final selection = vote['selection']?.toString() ?? '';
            if (fixtureId.isNotEmpty && selection.isNotEmpty) {
              votes[fixtureId] = selection;
            }
          }
        }

        userVotes = votes;
        await saveUserVotes();
        if (kDebugMode) {
          developer.log('✅ AppCache: Refreshed ${votes.length} user votes',
              name: 'AppCache');
        }
      }
    } catch (e) {
      developer.log('❌ AppCache: Failed to refresh user votes: $e',
          name: 'AppCache');
    }
  }

  // ==========================================================================
  // INSTANT FIXTURES LOAD
  // ==========================================================================
  static const int _instantFixturesCount = 10;

  static Future<void> loadFixturesInstantly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fixturesJson = prefs.getString('fixtures_cache');

      if (fixturesJson != null) {
        final List<dynamic> data = jsonDecode(fixturesJson);

        // ✅ Only build Fixture objects for the first N entries synchronously —
        // this is the part that blocks first paint, so keep it tiny. The
        // jsonDecode() above is unavoidable (need the array to slice it), but
        // Fixture.fromJson() per-item parsing/validation is the actual cost
        // when the cache has hundreds of fixtures with nested subFixtures.
        final int instantCount = data.length < _instantFixturesCount
            ? data.length
            : _instantFixturesCount;

        fixtures = data
            .take(instantCount)
            .map((f) => Fixture.fromJson(f as Map<String, dynamic>))
            .toList();

        if (kDebugMode) {
          developer.log(
              '⚡ Instant: ${fixtures.length}/${data.length} fixtures loaded pre-frame',
              name: 'AppCache');
        }

        // ✅ Finish parsing the remainder AFTER first frame, off the
        // synchronous cold-start path. This still runs fast (same process,
        // no I/O) but no longer delays runApp()/first paint.
        if (data.length > instantCount) {
          _fixturesController.add(fixtures); // notify with partial list first

          scheduleMicrotask(() {
            try {
              final remaining = data
                  .skip(instantCount)
                  .map((f) => Fixture.fromJson(f as Map<String, dynamic>))
                  .toList();

              fixtures = [...fixtures, ...remaining];
              _fixturesController.add(fixtures);

              if (kDebugMode) {
                developer.log(
                    '⚡ Deferred: remaining ${remaining.length} fixtures parsed',
                    name: 'AppCache');
              }
            } catch (e) {
              developer.log('❌ Deferred fixture parse error: $e',
                  name: 'AppCache');
            }
          });
        }
      } else {
        try {
         
          if (kDebugMode) {
            developer.log(
                '🌱 Instant: seeded ${fixtures.length} fixtures from bundle (first launch)',
                name: 'AppCache');
          }
        } catch (seedError) {
          if (kDebugMode) {
            developer.log(
                '⚠️ No fixtures seed asset found, starting empty: $seedError',
                name: 'AppCache');
          }
        }
      }

      _fixturesController.add(fixtures);
    } catch (e) {
      developer.log('❌ Instant fixtures load error: $e', name: 'AppCache');
    }
  }

  // ==========================================================================
  // LOAD - FAST, NON-BLOCKING WITH PARALLELIZED READS
  // ==========================================================================
  static Future<void> load() async {
    if (isLoaded) return;
    isLoaded = true;

    await _loadCriticalData();

    unawaited(_loadDeferredData());
    unawaited(_loadAftermatchDataFromDisk());
    _lazyLoadHistoryCommentsFromDisk(); // ✅ ADDED — same class of bug as
    // _cachedMessages: history comments were only ever pulled from disk
    // reactively via getCachedHistoryComments(), which is too late for
    // first paint on a cold start. This kicks the disk read off eagerly
    // at load-time instead of waiting for something to ask for it.

    if (kDebugMode) {
      developer.log('⚡ AppCache: Critical data ready, UI can paint',
          name: 'AppCache');
    }
  }

  static Future<void> _loadCriticalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final results = await Future.wait([
        Future.value(prefs.getString('cached_channels')),
        Future.value(prefs.getString('cached_profile')),
        Future.value(prefs.getString('cached_user_votes')),
      ]);

      final channelsJson = results[0] as String?;
      final profileJson = results[1] as String?;
      final votesJson = results[2] as String?;

      if (channelsJson != null) {
        final List<dynamic> data = jsonDecode(channelsJson);
        channels = data
            .map((c) => UserChannel.fromJson(c as Map<String, dynamic>))
            .toList();
        if (kDebugMode) {
          developer.log('⚡ Critical: ${channels.length} channels loaded',
              name: 'AppCache');
        }
      }

      if (profileJson != null) {
        final Map<String, dynamic> raw = jsonDecode(profileJson);
        profile = {
          ...raw,
          'nickname': raw['nickname'] ?? raw['username'] ?? 'Fan',
          'club_fan': raw['club_fan'] ?? 'No Club',
          'country_fan': raw['country_fan'] ?? 'World',
          'points': raw['points'] ?? raw['season_points'] ?? 0,
        };
        if (kDebugMode) {
          developer.log('⚡ Critical: profile loaded', name: 'AppCache');
        }
      }

      if (votesJson != null) {
        final Map<String, dynamic> data = jsonDecode(votesJson);
        userVotes = Map<String, String>.from(data);
        if (kDebugMode) {
          developer.log('⚡ Critical: ${userVotes.length} votes loaded',
              name: 'AppCache');
        }
      }

      _criticalLoaded = true;
    } catch (e) {
      developer.log('❌ Critical load error: $e', name: 'AppCache');
    }
  }

  static Future<void> _loadDeferredData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final deferredKeys = [
        'history_games_cache',
        'cached_comrades',
        'cached_user_comrades',
        'cached_comrade_voters',
        'per_channel_vote_counts',
        'vote_counts_cache',
        'comment_counts_cache',
        'like_counts_cache',
        'pledge_counts_cache',
        'bet_counts_cache',
        'unread_counts_cache',
        'latest_comments_cache',
        'channel_fixtures_cache',
        'cached_messages', // ✅ ADDED — was silently skipped before
      ];

      final values = await Future.wait(
          deferredKeys.map((k) => Future.value(prefs.getString(k))));
      final map = Map<String, String?>.fromIterables(deferredKeys, values);

      if (map['history_games_cache'] != null) {
        final List<dynamic> data = jsonDecode(map['history_games_cache']!);
        historyGames = data
            .map((g) => HistoryGame.fromJson(g as Map<String, dynamic>))
            .toList();
        _historyController.add(historyGames);
        if (kDebugMode) {
          developer.log(
              '⏳ Deferred: ${historyGames.length} history games loaded',
              name: 'AppCache');
        }
      }

      if (map['cached_comrades'] != null) {
        final List<dynamic> data = jsonDecode(map['cached_comrades']!);
        comrades = data.cast<Map<String, dynamic>>();
        if (kDebugMode) {
          developer.log('⏳ Deferred: ${comrades.length} comrades loaded',
              name: 'AppCache');
        }
      }

      final userComradesList = prefs.getStringList('cached_user_comrades');
      if (userComradesList != null) {
        userComrades = Set<String>.from(userComradesList);
        if (kDebugMode) {
          developer.log('⏳ Deferred: ${userComrades.length} user comrades',
              name: 'AppCache');
        }
      }

      if (map['cached_comrade_voters'] != null) {
        final Map<String, dynamic> data =
            jsonDecode(map['cached_comrade_voters']!);
        for (var entry in data.entries) {
          final List<dynamic> votersList = entry.value;
          comradeVoters[entry.key] = votersList
              .map(
                  (v) => ComradeWithProfile.fromJson(v as Map<String, dynamic>))
              .toList();
        }
        if (kDebugMode) {
          developer.log('⏳ Deferred: ${comradeVoters.length} comrade voters',
              name: 'AppCache');
        }
      }

      if (map['per_channel_vote_counts'] != null) {
        final Map<String, dynamic> data =
            jsonDecode(map['per_channel_vote_counts']!);
        for (var entry in data.entries) {
          perChannelVoteCounts[entry.key] =
              Map<String, int>.from(entry.value as Map);
        }
      }

      if (map['vote_counts_cache'] != null) {
        final Map<String, dynamic> data = jsonDecode(map['vote_counts_cache']!);
        for (var entry in data.entries) {
          _voteCounts[entry.key] = entry.value as int;
        }
      }

      if (map['comment_counts_cache'] != null) {
        final Map<String, dynamic> data =
            jsonDecode(map['comment_counts_cache']!);
        for (var entry in data.entries) {
          _commentCounts[entry.key] = entry.value as int;
        }
      }

      if (map['like_counts_cache'] != null) {
        final Map<String, dynamic> data = jsonDecode(map['like_counts_cache']!);
        for (var entry in data.entries) {
          _likeCounts[entry.key] = entry.value as int;
        }
      }

      if (map['pledge_counts_cache'] != null) {
        final Map<String, dynamic> data =
            jsonDecode(map['pledge_counts_cache']!);
        for (var entry in data.entries) {
          _pledgeCounts[entry.key] = entry.value as int;
        }
      }

      if (map['bet_counts_cache'] != null) {
        final Map<String, dynamic> data = jsonDecode(map['bet_counts_cache']!);
        for (var entry in data.entries) {
          _betCounts[entry.key] = entry.value as int;
        }
      }

      if (map['unread_counts_cache'] != null) {
        final Map<String, dynamic> data =
            jsonDecode(map['unread_counts_cache']!);
        for (var entry in data.entries) {
          _unreadCounts[entry.key] = entry.value as int;
        }
      }

      if (map['latest_comments_cache'] != null) {
        final Map<String, dynamic> data =
            jsonDecode(map['latest_comments_cache']!);
        for (var entry in data.entries) {
          final item = entry.value as Map<String, dynamic>;
          _latestComments[entry.key] = item['comment'] as String?;
          _latestCommentAuthors[entry.key] = item['author'] as String?;
          if (item['timestamp'] != null) {
            _latestCommentTimestamps[entry.key] =
                DateTime.tryParse(item['timestamp']);
          }
        }
        if (kDebugMode) {
          developer.log('⏳ Deferred: ${_latestComments.length} latest comments',
              name: 'AppCache');
        }
      }

      if (map['channel_fixtures_cache'] != null) {
        final Map<String, dynamic> data =
            jsonDecode(map['channel_fixtures_cache']!);
        for (var entry in data.entries) {
          channelFixtures[entry.key] =
              ChannelFixtureData.fromJson(entry.value as Map<String, dynamic>);
        }
        if (kDebugMode) {
          developer.log(
              '⏳ Deferred: ${channelFixtures.length} channel fixtures',
              name: 'AppCache');
        }
      }

      // ✅ NEW BLOCK — this was the missing piece. Without this,
      // _cachedMessages stayed empty after a cold start until something
      // called getCachedMessages() and triggered the fire-and-forget
      // _lazyLoadMessagesFromDisk(), which was too late for first paint.
      // Coordinates with getCachedMessagesAsync() via the shared completer
      // so a ChatScreen navigation racing this background load doesn't
      // trigger two separate SharedPreferences reads of the same key.
      if (map['cached_messages'] != null &&
          _messagesDiskLoadCompleter == null &&
          !_cachedMessages.isNotEmpty) {
        _messagesDiskLoadCompleter = Completer<void>();
        try {
          final Map<String, dynamic> data = jsonDecode(map['cached_messages']!);
          for (var entry in data.entries) {
            _cachedMessages.putIfAbsent(
              entry.key,
              () => List<Map<String, dynamic>>.from(entry.value),
            );
          }
          if (kDebugMode) {
            developer.log(
                '⏳ Deferred: ${_cachedMessages.length} message threads loaded',
                name: 'AppCache');
          }
        } finally {
          _messagesDiskLoadCompleter!.complete();
          _messagesDiskLoadCompleter = null;
        }
      }

      if (kDebugMode) {
        developer.log('✅ AppCache deferred load complete', name: 'AppCache');
      }
    } catch (e) {
      developer.log('❌ Deferred load error: $e', name: 'AppCache');
    }
  }

// ==========================================================================
  // APPEND SINGLE MESSAGE TO CACHE - FOR SENDERS/RECEIVERS OUTSIDE CHATSCREEN
  // ==========================================================================
  // FixturesPage and HistoryPage can send AND receive chat messages for a
  // fixture without ChatScreen ever being open. Previously those messages
  // only lived in each page's own local state (_fixtureComments) and never
  // touched _cachedMessages — the exact map ChatScreen reads from on open.
  // Combined with ChatScreen's one-shot-per-session hydration guard (it
  // only ever hits the network once per fixture per app run), a comment
  // posted from FixturesPage was invisible to ChatScreen until the app
  // process was killed and restarted. This keeps _cachedMessages current
  // no matter which screen sent or received the message.
  static void appendCachedMessage(
    String channelId,
    String fixtureId,
    Map<String, dynamic> message,
  ) {
    final key = '${channelId}_$fixtureId';
    final list = _cachedMessages[key] ?? [];

    final id = message['id']?.toString();
    final tempId = message['tempId']?.toString();
    final alreadyExists = list.any((m) =>
        (id != null && m['id']?.toString() == id) ||
        (tempId != null && m['tempId']?.toString() == tempId));
    if (alreadyExists) return;

    _cachedMessages[key] = [...list, message];
    _saveMessagesToDisk();

    if (kDebugMode) {
      developer.log(
          '➕ Appended message to cache for $key (now ${_cachedMessages[key]!.length})',
          name: 'AppCache');
    }
  }

  // ==========================================================================
  // ASYNC MESSAGE CACHE READ - GUARANTEES DISK IS LOADED BEFORE RETURNING
  // ==========================================================================
  // getCachedMessages() is synchronous and, on a cold process where
  // _cachedMessages is still empty, kicks off _lazyLoadMessagesFromDisk()
  // in the background and returns null immediately — the caller has no way
  // to wait for that disk read. This async version actually awaits the
  // SharedPreferences read the first time it's needed, so a fresh
  // ChatScreen._loadMessages() call gets real cached data instead of null
  // on the very first frame after a cold start.
  static Future<List<Map<String, dynamic>>?> getCachedMessagesAsync(
    String channelId,
    String? fixtureId,
  ) async {
    final key =
        fixtureId != null ? '${channelId}_$fixtureId' : '${channelId}_overall';

    if (_cachedMessages.containsKey(key)) {
      return _cachedMessages[key];
    }

    // If a disk load is already in flight (started by _loadDeferredData()
    // in the background, or by an earlier call to this method), wait for
    // that one instead of starting a second concurrent read.
    if (_messagesDiskLoadCompleter != null) {
      await _messagesDiskLoadCompleter!.future;
      return _cachedMessages[key];
    }

    _messagesDiskLoadCompleter = Completer<void>();
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('cached_messages');
      if (data != null) {
        final Map<String, dynamic> decoded = jsonDecode(data);
        for (var entry in decoded.entries) {
          // Don't clobber anything newer that landed in memory while this
          // read was in flight (e.g. a message arriving over WebSocket).
          _cachedMessages.putIfAbsent(
            entry.key,
            () => List<Map<String, dynamic>>.from(entry.value),
          );
        }
        if (kDebugMode) {
          developer.log(
              '📦 getCachedMessagesAsync: hydrated ${_cachedMessages.length} message threads from disk',
              name: 'AppCache');
        }
      }
    } catch (e) {
      developer.log('⚠️ getCachedMessagesAsync error: $e', name: 'AppCache');
    } finally {
      _messagesDiskLoadCompleter!.complete();
      _messagesDiskLoadCompleter = null;
    }

    return _cachedMessages[key];
  }

  // ==========================================================================
  // LAZY LOADERS
  // ==========================================================================
  static Map<String, dynamic>? getCachedLineup(String fixtureId) {
    if (!_cachedLineups.containsKey(fixtureId)) {
      _lazyLoadLineupsFromDisk();
      return null;
    }
    return _cachedLineups[fixtureId];
  }

  static void _lazyLoadLineupsFromDisk() {
    unawaited(Future<void>(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final data = prefs.getString('cached_lineups');
        if (data != null) {
          final Map<String, dynamic> decoded = jsonDecode(data);
          for (var entry in decoded.entries) {
            _cachedLineups[entry.key] = Map<String, dynamic>.from(entry.value);
          }
          if (kDebugMode) {
            developer.log('📦 Lazy loaded ${_cachedLineups.length} lineups',
                name: 'AppCache');
          }
        }
      } catch (e) {
        developer.log('⚠️ Lazy load lineups error: $e', name: 'AppCache');
      }
    }));
  }

  static List<Map<String, dynamic>>? getCachedChannelMembers(String channelId) {
    if (!_cachedChannelMembers.containsKey(channelId)) {
      _lazyLoadChannelMembersFromDisk();
      return null;
    }
    return _cachedChannelMembers[channelId];
  }

  static void _lazyLoadChannelMembersFromDisk() {
    unawaited(Future<void>(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final data = prefs.getString('cached_channel_members');
        if (data != null) {
          final Map<String, dynamic> decoded = jsonDecode(data);
          for (var entry in decoded.entries) {
            _cachedChannelMembers[entry.key] =
                List<Map<String, dynamic>>.from(entry.value);
          }
          if (kDebugMode) {
            developer.log(
                '📦 Lazy loaded ${_cachedChannelMembers.length} channel members',
                name: 'AppCache');
          }
        }
      } catch (e) {
        developer.log('⚠️ Lazy load channel members error: $e',
            name: 'AppCache');
      }
    }));
  }

  static Map<String, dynamic>? getCachedChannelStats(String channelId) {
    if (!_cachedChannelStats.containsKey(channelId)) {
      _lazyLoadChannelStatsFromDisk();
      return null;
    }
    return _cachedChannelStats[channelId];
  }

  static void _lazyLoadChannelStatsFromDisk() {
    unawaited(Future<void>(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final data = prefs.getString('cached_channel_stats');
        if (data != null) {
          final Map<String, dynamic> decoded = jsonDecode(data);
          for (var entry in decoded.entries) {
            _cachedChannelStats[entry.key] =
                Map<String, dynamic>.from(entry.value);
          }
          if (kDebugMode) {
            developer.log(
                '📦 Lazy loaded ${_cachedChannelStats.length} channel stats',
                name: 'AppCache');
          }
        }
      } catch (e) {
        developer.log('⚠️ Lazy load channel stats error: $e', name: 'AppCache');
      }
    }));
  }

  static List<Map<String, dynamic>>? getCachedComradeLeaderboard(
      String userId) {
    if (!_cachedComradeLeaderboard.containsKey(userId)) {
      _lazyLoadComradeLeaderboardFromDisk();
      return null;
    }
    return _cachedComradeLeaderboard[userId];
  }

  static void _lazyLoadComradeLeaderboardFromDisk() {
    unawaited(Future<void>(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final data = prefs.getString('cached_comrade_leaderboard');
        if (data != null) {
          final Map<String, dynamic> decoded = jsonDecode(data);
          for (var entry in decoded.entries) {
            _cachedComradeLeaderboard[entry.key] =
                List<Map<String, dynamic>>.from(entry.value);
          }
          if (kDebugMode) {
            developer.log(
                '📦 Lazy loaded ${_cachedComradeLeaderboard.length} leaderboards',
                name: 'AppCache');
          }
        }
      } catch (e) {
        developer.log('⚠️ Lazy load leaderboard error: $e', name: 'AppCache');
      }
    }));
  }

  static List<Map<String, dynamic>>? getCachedComradeVotersData(
      String fixtureId) {
    if (!_cachedComradeVotersData.containsKey(fixtureId)) {
      _lazyLoadComradeVotersDataFromDisk();
      return null;
    }
    return _cachedComradeVotersData[fixtureId];
  }

  static void _lazyLoadComradeVotersDataFromDisk() {
    unawaited(Future<void>(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final data = prefs.getString('cached_comrade_voters_data');
        if (data != null) {
          final Map<String, dynamic> decoded = jsonDecode(data);
          for (var entry in decoded.entries) {
            _cachedComradeVotersData[entry.key] =
                List<Map<String, dynamic>>.from(entry.value);
          }
          if (kDebugMode) {
            developer.log(
                '📦 Lazy loaded ${_cachedComradeVotersData.length} comrade voters',
                name: 'AppCache');
          }
        }
      } catch (e) {
        developer.log('⚠️ Lazy load comrade voters error: $e',
            name: 'AppCache');
      }
    }));
  }

  static List<Map<String, dynamic>>? getLiveEventsCached(String fixtureId) {
    if (!_liveEvents.containsKey(fixtureId)) {
      _lazyLoadLiveEventsFromDisk();
      return null;
    }
    return _liveEvents[fixtureId];
  }

  static void _lazyLoadLiveEventsFromDisk() {
    unawaited(Future<void>(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final data = prefs.getString('live_events_cache');
        if (data != null) {
          final Map<String, dynamic> decoded = jsonDecode(data);
          for (var entry in decoded.entries) {
            _liveEvents[entry.key] =
                List<Map<String, dynamic>>.from(entry.value);
          }
          if (kDebugMode) {
            developer.log('📦 Lazy loaded ${_liveEvents.length} live events',
                name: 'AppCache');
          }
        }
      } catch (e) {
        developer.log('⚠️ Lazy load live events error: $e', name: 'AppCache');
      }
    }));
  }

  static List<Map<String, dynamic>>? getVotersListCached(String fixtureId) {
    if (!_votersList.containsKey(fixtureId)) {
      _lazyLoadVotersFromDisk();
      return null;
    }
    return _votersList[fixtureId];
  }

  static void _lazyLoadVotersFromDisk() {
    unawaited(Future<void>(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final data = prefs.getString('voters_cache');
        if (data != null) {
          final Map<String, dynamic> decoded = jsonDecode(data);
          for (var entry in decoded.entries) {
            _votersList[entry.key] =
                List<Map<String, dynamic>>.from(entry.value);
          }
          if (kDebugMode) {
            developer.log('📦 Lazy loaded ${_votersList.length} voters lists',
                name: 'AppCache');
          }
        }
      } catch (e) {
        developer.log('⚠️ Lazy load voters error: $e', name: 'AppCache');
      }
    }));
  }

  static List<Map<String, dynamic>>? getCachedMessages(
    String channelId,
    String? fixtureId,
  ) {
    final key =
        fixtureId != null ? '${channelId}_$fixtureId' : '${channelId}_overall';

    if (!_cachedMessages.containsKey(key)) {
      _lazyLoadMessagesFromDisk();
      return null;
    }
    return _cachedMessages[key];
  }

  static void _lazyLoadMessagesFromDisk() {
    unawaited(Future<void>(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final data = prefs.getString('cached_messages');
        if (data != null) {
          final Map<String, dynamic> decoded = jsonDecode(data);
          for (var entry in decoded.entries) {
            _cachedMessages[entry.key] =
                List<Map<String, dynamic>>.from(entry.value);
          }
          if (kDebugMode) {
            developer.log(
                '📦 Lazy loaded ${_cachedMessages.length} message groups',
                name: 'AppCache');
          }
        }
      } catch (e) {
        developer.log('⚠️ Lazy load messages error: $e', name: 'AppCache');
      }
    }));
  }

  // ==========================================================================
  // REFRESH HISTORY GAMES - Legacy method kept for compatibility
  // ==========================================================================
  static Future<void> refreshHistoryGames({String? authToken}) async {
  try {
    if (kDebugMode) {
      developer.log('🔄 Refreshing history games from API...',
          name: 'AppCache');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
    };
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    final response = await http
        .get(
          Uri.parse(
            'https://clash-api-m5mr.onrender.com/api/games/history?limit=100'
            '&_=${DateTime.now().millisecondsSinceEpoch}',
          ),
          headers: headers,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> gamesData = data['data'] ?? [];

      historyGames = gamesData
          .map((g) => HistoryGame.fromJson(g as Map<String, dynamic>))
          .toList();

      await _saveHistoryGamesToDisk(historyGames);
      _historyController.add(historyGames);
      if (kDebugMode) {
        developer.log('✅ Refreshed ${historyGames.length} history games',
            name: 'AppCache');
      }
    } else {
      if (kDebugMode) {
        developer.log(
            '⚠️ Failed to refresh history games: ${response.statusCode}',
            name: 'AppCache');
      }
      final cached = await _loadHistoryGamesFromDisk();
      if (cached != null) {
        historyGames = cached;
        _historyController.add(historyGames);
      }
    }
  } catch (e) {
    developer.log('❌ Failed to refresh history games: $e', name: 'AppCache');
    final cached = await _loadHistoryGamesFromDisk();
    if (cached != null) {
      historyGames = cached;
      _historyController.add(historyGames);
    }
  }
}

  static Future<void> _saveHistoryGamesToDisk(List<HistoryGame> games) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = games.map((g) => g.toJson()).toList();
      await prefs.setString('history_games_cache', jsonEncode(jsonList));
      await prefs.setInt('history_games_timestamp',
          DateTime.now().millisecondsSinceEpoch ~/ 1000);
    } catch (e) {
      developer.log('⚠️ Failed to save history games: $e', name: 'AppCache');
    }
  }

  static Future<List<HistoryGame>?> _loadHistoryGamesFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('history_games_cache');
      if (jsonStr == null) return null;
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList
          .map((g) => HistoryGame.fromJson(g as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return null;
    }
  }

  // ==========================================================================
  // MESSAGE CACHE METHODS
  // ==========================================================================
  static void cacheMessages(
    String channelId,
    String? fixtureId,
    List<Map<String, dynamic>> messages,
  ) {
    final key =
        fixtureId != null ? '${channelId}_$fixtureId' : '${channelId}_overall';

    final processedMessages = messages.map((msg) {
      if (msg['replyTo'] != null && msg['replyTo'] is! Map) {
        final replyData = msg['replyTo'];
        return {
          ...msg,
          'replyTo': {
            'messageId': replyData.messageId ?? '',
            'text': replyData.text ?? '',
            'username': replyData.username ?? '',
            'selection': replyData.selection,
            'isMe': replyData.isMe ?? false,
          }
        };
      }
      return msg;
    }).toList();

    _cachedMessages[key] = processedMessages;
    _saveMessagesToDisk();
    if (kDebugMode) {
      developer.log('💾 Cached ${processedMessages.length} messages for $key',
          name: 'AppCache');
    }
  }

  static Future<void> saveChatMessages(
    String channelId,
    String? fixtureId,
    List<ChatMessage> messages,
  ) async {
    final key =
        fixtureId != null ? '${channelId}_$fixtureId' : '${channelId}_overall';

    final messagesMap = messages
        .map((msg) => {
              'id': msg.id,
              'tempId': msg.tempId,
              'isPending': msg.isPending,
              'userId': msg.userId,
              'username': msg.username,
              'text': msg.text,
              'selection': msg.selection,
              'timestamp': msg.timestamp.toIso8601String(),
              'status': msg.status.index,
              'isSeen': msg.isSeen,
              'isCommentary': msg.isCommentary,
              'commentaryType': msg.commentaryType,
              'replyTo': msg.replyTo != null
                  ? {
                      'messageId': msg.replyTo!.messageId,
                      'text': msg.replyTo!.text,
                      'username': msg.replyTo!.username,
                      'selection': msg.replyTo!.selection,
                      'isMe': msg.replyTo!.isMe,
                      'imageUrl': msg.replyTo!.imageUrl,
                      'videoUrl': msg.replyTo!.videoUrl,
                      'isImage': msg.replyTo!.isImage ?? false,
                      'isVideo': msg.replyTo!.isVideo ?? false,
                    }
                  : null,
              'imageUrl': msg.imageUrl,
              'videoUrl': msg.videoUrl,
              'videoThumbnailUrl': msg.videoThumbnailUrl,
              'isImage': msg.isImage,
              'isVideo': msg.isVideo,
            })
        .toList();

    _cachedMessages[key] = messagesMap;
    await _saveMessagesToDisk();
  }

  static Future<void> _saveMessagesToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = Map<String, dynamic>.from(_cachedMessages);
      await prefs.setString('cached_messages', json.encode(serialized));
    } catch (e) {
      developer.log('⚠️ Failed to save messages to disk: $e', name: 'AppCache');
    }
  }

  static List<Map<String, dynamic>>? getMessages(
    String channelId,
    String? fixtureId,
  ) {
    final key =
        fixtureId != null ? '${channelId}_$fixtureId' : '${channelId}_overall';
    return _cachedMessages[key];
  }

  static List<ChatMessage>? getCachedChatMessages(
    String channelId,
    String? fixtureId,
  ) {
    final cached = getCachedMessages(channelId, fixtureId);
    if (cached == null || cached.isEmpty) return null;

    try {
      return cached.map((msgMap) {
        ReplyData? replyTo;
        if (msgMap['replyTo'] != null && msgMap['replyTo'] is Map) {
          final replyData = msgMap['replyTo'] as Map<String, dynamic>;
          replyTo = ReplyData(
            messageId: replyData['messageId'] ?? '',
            text: replyData['text'] ?? '',
            username: replyData['username'] ?? '',
            selection: replyData['selection'],
            isMe: replyData['isMe'] ?? false,
            imageUrl: replyData['imageUrl'],
            videoUrl: replyData['videoUrl'],
            isImage: replyData['isImage'] ?? false,
            isVideo: replyData['isVideo'] ?? false,
          );
        }

        return ChatMessage(
          id: msgMap['id'] ?? '',
          tempId: msgMap['tempId'],
          isPending: msgMap['isPending'] ?? false,
          userId: msgMap['userId'] ?? '',
          username: msgMap['username'] ?? '',
          text: msgMap['text'] ?? '',
          selection: msgMap['selection'],
          timestamp: DateTime.parse(
              msgMap['timestamp'] ?? DateTime.now().toIso8601String()),
          status: MessageStatus.values[msgMap['status'] ?? 1],
          isSeen: msgMap['isSeen'] ?? false,
          isCommentary: msgMap['isCommentary'] ?? false,
          commentaryType: msgMap['commentaryType'],
          replyTo: replyTo,
          imageUrl: msgMap['imageUrl'],
          videoUrl: msgMap['videoUrl'],
          videoThumbnailUrl: msgMap['videoThumbnailUrl'],
          isImage: msgMap['isImage'] ?? false,
          isVideo: msgMap['isVideo'] ?? false,
        );
      }).toList();
    } catch (e) {
      developer.log('⚠️ Failed to convert cached messages: $e',
          name: 'AppCache');
      return null;
    }
  }

  // ==========================================================================
  // ADMIN DASHBOARD CACHE METHODS
  // ==========================================================================
  static void cacheChannelStats(String channelId, Map<String, dynamic> stats) {
    _cachedChannelStats[channelId] = stats;
    _saveChannelStatsToDisk();
  }

  static Future<void> _saveChannelStatsToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'cached_channel_stats',
      json.encode(_cachedChannelStats),
    );
  }

  static void cacheChannelMembers(
    String channelId,
    List<Map<String, dynamic>> members,
  ) {
    _cachedChannelMembers[channelId] = members;
    _saveChannelMembersToDisk();
  }

  static Future<void> _saveChannelMembersToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'cached_channel_members',
      json.encode(_cachedChannelMembers),
    );
  }

  // ==========================================================================
  // LINEUP CACHE METHODS
  // ==========================================================================
  static void cacheLineup(String fixtureId, Map<String, dynamic> lineupData) {
    _cachedLineups[fixtureId] = lineupData;
    _saveLineupsToDisk();
  }

  static Future<void> _saveLineupsToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_lineups', json.encode(_cachedLineups));
  }

  // ==========================================================================
  // COMRADE MODAL CACHE METHODS
  // ==========================================================================
  static void cacheComradeLeaderboard(
    String userId,
    List<Map<String, dynamic>> comrades,
  ) {
    _cachedComradeLeaderboard[userId] = comrades;
    _saveComradeLeaderboardToDisk();
  }

  static Future<void> _saveComradeLeaderboardToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'cached_comrade_leaderboard',
      json.encode(_cachedComradeLeaderboard),
    );
  }

  static void cacheComradeVotersData(
    String fixtureId,
    List<Map<String, dynamic>> voters,
  ) {
    _cachedComradeVotersData[fixtureId] = voters;
    _saveComradeVotersDataToDisk();
  }

  static Future<void> _saveComradeVotersDataToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'cached_comrade_voters_data',
      json.encode(_cachedComradeVotersData),
    );
  }

  // ==========================================================================
  // SAVE METHODS
  // ==========================================================================
  static Future<void> saveChannelFixtures(
    Map<String, ChannelFixtureData> data,
  ) async {
    channelFixtures = data;
    final prefs = await SharedPreferences.getInstance();
    final serialized = <String, dynamic>{};
    for (var entry in data.entries) {
      serialized[entry.key] = {
        'fixtureId': entry.value.fixtureId,
        'channelId': entry.value.channelId,
        'matchName': entry.value.matchName,
        'kickoffTime': entry.value.kickoffTime.toIso8601String(),
        'status': entry.value.status,
        'homeVotes': entry.value.homeVotes,
        'awayVotes': entry.value.awayVotes,
        'drawVotes': entry.value.drawVotes,
        'lastMessage': entry.value.lastMessage,
        'lastMessageAt': entry.value.lastMessageAt?.toIso8601String(),
        'lastSender': entry.value.lastSender,
        'userVote': entry.value.userVote,
        'commentCount': entry.value.commentCount,
        'unreadCounts': entry.value.unreadCounts,
      };
    }
    await prefs.setString('channel_fixtures_cache', json.encode(serialized));
  }

  static Future<void> saveProfile(Map<String, dynamic> newProfile) async {
    final enrichedProfile = {
      ...newProfile,
      'nickname': newProfile['nickname'] ?? newProfile['username'] ?? 'Fan',
      'club_fan': newProfile['club_fan'] ?? 'No Club',
      'country_fan': newProfile['country_fan'] ?? 'World',
      'points': newProfile['points'] ?? newProfile['season_points'] ?? 0,
    };
    profile = enrichedProfile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_profile', json.encode(enrichedProfile));
  }

  static Future<void> saveChannels(List<UserChannel> newChannels) async {
    channels = newChannels;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'cached_channels',
      json.encode(channels.map((c) => c.toJson()).toList()),
    );
  }

  static Future<void> saveUserComrades(Set<String> comrades) async {
    userComrades = comrades;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('cached_user_comrades', comrades.toList());
  }

  static Future<void> saveComradeVoters(
    Map<String, List<ComradeWithProfile>> voters,
  ) async {
    comradeVoters = voters;
    final prefs = await SharedPreferences.getInstance();
    final serialized = <String, List<Map<String, dynamic>>>{};
    for (var entry in voters.entries) {
      serialized[entry.key] = entry.value.map((c) => c.toJson()).toList();
    }
    await prefs.setString('cached_comrade_voters', json.encode(serialized));
  }

  // ==========================================================================
  // MEMORY MANAGEMENT - TRIM METHODS
  // ==========================================================================
  static void reduceMemoryFootprint() {
    // Keep only active fixture data
    final activeFixtureId = getActiveFixtureId();
    if (activeFixtureId != null) {
      final keysToKeep = {activeFixtureId};

      // Trim channel fixtures
      channelFixtures.removeWhere((key, _) => !keysToKeep.contains(key));

      // Trim vote counts
      _voteCounts.removeWhere((key, _) => !keysToKeep.contains(key));

      // Trim comment counts
      _commentCounts.removeWhere((key, _) => !keysToKeep.contains(key));

      // Trim latest comments
      _latestComments.removeWhere((key, _) => !keysToKeep.contains(key));
      _latestCommentAuthors.removeWhere((key, _) => !keysToKeep.contains(key));
      _latestCommentTimestamps
          .removeWhere((key, _) => !keysToKeep.contains(key));

      // Trim per-channel vote counts
      perChannelVoteCounts.removeWhere((key, _) => !keysToKeep.contains(key));
    }

    // Trim message cache to 10 messages per fixture
    for (var key in _cachedMessages.keys.toList()) {
      final messages = _cachedMessages[key];
      if (messages != null && messages.length > 10) {
        _cachedMessages[key] = messages.take(10).toList();
      }
    }

    // Clear non-essential caches
    _liveEvents.clear();
    _votersList.clear();
    comradeVoters.clear();
    _postComments.clear();
    _cachedComradeLeaderboard.clear();
    _cachedComradeVotersData.clear();
    _cachedLineups.clear();

    // Save trimmed data to disk
    _saveAllToDisk();

    if (kDebugMode) {
      developer.log('🧹 AppCache memory footprint reduced', name: 'AppCache');
    }
  }

  static Future<void> _saveAllToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save trimmed data
      await prefs.setString('cached_messages', json.encode(_cachedMessages));
      await prefs.setString(
          'channel_fixtures_cache', json.encode(channelFixtures));
      await prefs.setString('vote_counts_cache', json.encode(_voteCounts));
      await prefs.setString(
          'comment_counts_cache', json.encode(_commentCounts));

      if (kDebugMode) {
        developer.log('💾 AppCache saved to disk after trim', name: 'AppCache');
      }
    } catch (e) {
      developer.log('⚠️ Error saving to disk: $e', name: 'AppCache');
    }
  }

  // ==========================================================================
  // CLEAR ALL CACHE - UPDATED WITH HISTORY COMMENTS
  // ==========================================================================
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Remove all cache keys
      await prefs.remove('cached_comrades');
      await prefs.remove('post_comments_cache');
      await prefs.remove('cached_channels');
      await prefs.remove('cached_profile');
      await prefs.remove('fixtures_cache');
      await prefs.remove('cached_user_votes');
      await prefs.remove('channel_fixtures_cache');
      await prefs.remove('cached_user_comrades');
      await prefs.remove('cached_comrade_voters');
      await prefs.remove('cached_messages');
      await prefs.remove('cached_channel_stats');
      await prefs.remove('cached_channel_members');
      await prefs.remove('cached_lineups');
      await prefs.remove('cached_comrade_leaderboard');
      await prefs.remove('cached_comrade_voters_data');
      await prefs.remove('per_channel_vote_counts');
      await prefs.remove('comment_counts_cache');
      await prefs.remove('like_counts_cache');
      await prefs.remove('pledge_counts_cache');
      await prefs.remove('bet_counts_cache');
      await prefs.remove('latest_comments_cache');
      await prefs.remove('unread_counts_cache');
      await prefs.remove('live_events_cache');
      await prefs.remove('voters_cache');
      await prefs.remove('vote_counts_cache');
      await prefs.remove('history_games_cache');
      await prefs.remove('history_games_timestamp');
      await prefs.remove('aftermatch_data_cache');

      // Clear history comments
      await prefs.remove('history_comments_cache');
      await prefs.remove('history_comments_timestamps');

      // Clear all in-memory data
      comrades.clear();
      channels.clear();
      profile = null;
      fixtures.clear();
      userVotes.clear();
      channelFixtures.clear();
      userComrades.clear();
      comradeVoters.clear();
      _cachedMessages.clear();
      _cachedChannelStats.clear();
      _cachedChannelMembers.clear();
      _cachedLineups.clear();
      _cachedComradeLeaderboard.clear();
      _cachedComradeVotersData.clear();
      perChannelVoteCounts.clear();
      _commentCounts.clear();
      _likeCounts.clear();
      _pledgeCounts.clear();
      _betCounts.clear();
      _userLikes.clear();
      _latestComments.clear();
      _latestCommentAuthors.clear();
      _latestCommentTimestamps.clear();
      _unreadCounts.clear();
      _liveEvents.clear();
      _votersList.clear();
      _voteCounts.clear();
      _lastVoteUpdate.clear();
      _lastCommentUpdate.clear();
      _lastLikeUpdate.clear();
      _lastLatestCommentUpdate.clear();
      _lastPledgeUpdate.clear();
      _lastBetUpdate.clear();
      _lastUnreadUpdate.clear();
      _aftermatchData.clear();

      // Clear history comments
      _historyComments.clear();
      _historyCommentsLoaded = false;
      _historyCommentFetchTime.clear();

      isLoaded = false;
      _criticalLoaded = false;
      _postComments.clear();
      _lastCommentLoad.clear();

      if (kDebugMode) {
        developer.log('🗑️ AppCache cleared completely', name: 'AppCache');
      }
    } catch (e) {
      developer.log('⚠️ Error clearing AppCache: $e', name: 'AppCache');
    }
  }
}

// ============================================================================
// JOIN CHANNEL DIALOG
// ============================================================================
class _JoinChannelDialog extends StatefulWidget {
  final String inviteCode;
  final String channelName;
  final int memberCount;

  const _JoinChannelDialog({
    required this.inviteCode,
    required this.channelName,
    required this.memberCount,
  });

  @override
  State<_JoinChannelDialog> createState() => _JoinChannelDialogState();
}

class _JoinChannelDialogState extends State<_JoinChannelDialog> {
  bool _isJoining = false;

  Future<void> _join() async {
    final authService = AuthService();
    if (!authService.isLoggedIn) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please login first to join a channel'),
          backgroundColor: FanColors.draw,
        ),
      );
      return;
    }

    setState(() => _isJoining = true);

    try {
      final response = await http.post(
        Uri.parse(
            'https://clash-api-m5mr.onrender.com/api/channels/join-by-code'),
        headers: {
          'Content-Type': 'application/json',
          if (authService.authToken != null)
            'Authorization': 'Bearer ${authService.authToken}',
        },
        body: json.encode({
          'invite_code': widget.inviteCode,
          'user_id': authService.userId,
          'username': authService.username,
        }),
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final name = data['channel_name'] ?? widget.channelName;

        if (authService.userId != null) {
          await AppCache.refreshChannels(
              authService.userId!, authService.authToken);
        }

        ScaffoldMessenger.of(messengerKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text('✅ You joined "$name" 🎉'),
            backgroundColor: FanColors.primary,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(messengerKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to join channel'),
            backgroundColor: FanColors.away,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(messengerKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: FanColors.away,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: FanColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: FanRadius.lgAll,
        side: BorderSide(color: FanColors.border),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: FanColors.primaryDim,
              shape: BoxShape.circle,
            ),
            child:
                const Center(child: Text('⚔️', style: TextStyle(fontSize: 28))),
          ),
          const SizedBox(height: 16),
          Text(
            'Join Channel',
            style: FanTypography.headline.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            widget.channelName,
            style: FanTypography.title.copyWith(
              color: FanColors.primary,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.memberCount} members',
            style: FanTypography.caption.copyWith(
              color: FanColors.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _isJoining ? null : () => Navigator.pop(context),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      border: Border.all(color: FanColors.border),
                      borderRadius: FanRadius.pillAll,
                    ),
                    child: Center(
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: FanColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _isJoining ? null : _join,
                  child: Container(
                    height: 44,
                    decoration: FanDecorations.primaryButton,
                    child: _isJoining
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              'Join',
                              style: TextStyle(
                                color: FanColors.textInverse,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FCM BACKGROUND HANDLER
// ============================================================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log(
    '🔔 Background message: ${message.messageId}',
    name: 'FCM-Background',
  );
  final type =
      message.data['type'] ?? message.data['notificationType'] ?? 'general';
  if (type == 'comrade_added') {
    final prefs = await SharedPreferences.getInstance();
    final pendingNotifications =
        prefs.getStringList('pending_notifications') ?? [];
    pendingNotifications.add(message.data.toString());
    await prefs.setStringList('pending_notifications', pendingNotifications);
  }
}

// ============================================================================
// EMULATOR DETECTION
// ============================================================================
bool get isEmulator {
  if (kIsWeb) return false;
  if (Platform.isAndroid) {
    return Platform.environment['ANDROID_EMULATOR'] != null ||
        Platform.environment['ro.kernel.qemu'] != null ||
        Platform.environment['ro.hardware']?.contains('ranchu') == true ||
        Platform.environment['ro.product.device']?.contains('generic') ==
            true ||
        Platform.environment['ro.product.model']?.contains('sdk') == true;
  }
  if (Platform.isIOS) {
    return Platform.environment['SIMULATOR_DEVICE_NAME'] != null;
  }
  return false;
}

// ============================================================================
// APPCACHE AUTO-REFRESH TIMER
// ============================================================================
void startAppCacheRefresh() {
  _appCacheRefreshTimer?.cancel();
  _appCacheRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
    developer.log('🔄 AppCache auto-refresh triggered', name: 'Funzypp');
    AppCache.refreshAll();
  });
  developer.log('✅ AppCache auto-refresh timer started (5 minute interval)',
      name: 'Funzypp');
}

void stopAppCacheRefresh() {
  _appCacheRefreshTimer?.cancel();
  _appCacheRefreshTimer = null;
  developer.log('⏸️ AppCache auto-refresh timer paused (app backgrounded)',
      name: 'Funzypp');
}

// ============================================================================
// DEEP LINKS
// ============================================================================
Future<void> initializeDeepLinks() async {
  final appLinks = AppLinks();

  try {
    final initialUri = await appLinks.getInitialLink();
    if (initialUri != null) {
      _handleDeepLink(initialUri);
    }

    appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  } catch (e) {
    developer.log('❌ Deep link error: $e', name: 'Funzypp');
  }
}

void _handleDeepLink(Uri uri) {
  if (uri.scheme == 'Funzy' && uri.host == 'join') {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return;
    final inviteCode = segments.first.toUpperCase();

    developer.log('🔗 Deep link: invite code $inviteCode', name: 'Funzypp');

    Future.delayed(const Duration(milliseconds: 500), () {
      _showJoinChannelDialog(inviteCode);
    });
  }
}

Future<void> _showJoinChannelDialog(String inviteCode) async {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  Map<String, dynamic>? channelData;
  try {
    final response = await http.get(
      Uri.parse(
          'https://clash-api-m5mr.onrender.com/api/channels/invite/$inviteCode'),
    );
    if (response.statusCode == 200) {
      channelData = json.decode(response.body);
    }
  } catch (e) {
    developer.log('❌ Failed to fetch channel: $e', name: 'Funzypp');
  }

  if (!context.mounted) return;

  final channelName = channelData?['channel_name'] ?? 'Unknown Channel';
  final memberCount = channelData?['member_count'] ?? 0;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _JoinChannelDialog(
      inviteCode: inviteCode,
      channelName: channelName,
      memberCount: memberCount,
    ),
  );
}

// ============================================================================
// FCM SETUP
// ============================================================================



Future<void> initializeFCMWeb() async {
  debugPrint('FCM DEBUG: initializeFCMWeb() entered');
  try {
    developer.log('🔔 Initializing FCM (web)…', name: 'Funzypp');

    await WebNotificationService.requestPermission();
    debugPrint('FCM DEBUG: WebNotificationService.requestPermission() done');

    final settings = await FirebaseMessaging.instance.requestPermission();
    debugPrint('FCM DEBUG: requestPermission() -> ${settings.authorizationStatus}');

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('FCM DEBUG: permission NOT authorized, aborting');
      developer.log('⚠️ FCM permission denied (web)', name: 'Funzypp');
      return;
    }

    debugPrint('FCM DEBUG: about to call getToken()');
    // Web requires the VAPID key to get a token.
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: 'BIvcsdfnoQ07A2PAEiXvHfjLPOfyga-fiPB-JLJfdr7NbXxwWJMr6fNT-71RzUVP-WZcL76W_sN137Fs9wMhi90',
    );
    debugPrint('FCM DEBUG: getToken() returned -> ${token == null ? "NULL" : "token acquired (len=${token.length})"}');

    if (token != null) {
      developer.log('📱 Web FCM Token acquired', name: 'Funzypp');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);

      debugPrint('FCM DEBUG: isLoggedIn=${authService.isLoggedIn}, userId=${authService.userId}');

      if (authService.isLoggedIn && authService.userId != null) {
        debugPrint('FCM DEBUG: calling NotificationService.registerToken()');
        await NotificationService.registerToken(
          userId: authService.userId!,
          fcmToken: token,
          platform: 'web',
          authToken: authService.authToken,
        );
        debugPrint('FCM DEBUG: registerToken() call completed');
      } else {
        debugPrint('FCM DEBUG: skipped registerToken() — not logged in yet');
      }
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('FCM DEBUG: onTokenRefresh fired');
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('fcm_token', newToken);
      });
      if (authService.isLoggedIn && authService.userId != null) {
        NotificationService.registerToken(
          userId: authService.userId!,
          fcmToken: newToken,
          platform: 'web',
          authToken: authService.authToken,
        );
      }
    });

    // Foreground messages — tab is open and focused.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM DEBUG: onMessage (foreground) fired');
      developer.log('🔔 Foreground FCM message (web)', name: 'Funzypp');
      final payload = _buildPayload(message);

      WebNotificationService.show(message);

      if (payload['type'] == 'comrade_added') {
        final username = message.data['username'] ?? 'Someone';
        if (messengerKey.currentContext != null) {
          ScaffoldMessenger.of(messengerKey.currentContext!).showSnackBar(
            SnackBar(
              content: Text('🎉 $username added you as a comrade!'),
              backgroundColor: FanColors.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      NotificationService.pushToStream(payload);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM DEBUG: onMessageOpenedApp fired');
      _handleNotificationClick(message.data);
    });

    debugPrint('FCM DEBUG: initializeFCMWeb() completed successfully');
  } catch (e, st) {
    debugPrint('FCM DEBUG: initializeFCMWeb() THREW -> $e');
    debugPrint('FCM DEBUG: stack trace -> $st');
    developer.log('❌ FCM web initialization error: $e', name: 'Funzypp');
  }
}

Future<void> initializeFCM() async {
  debugPrint('FCM DEBUG: initializeFCM() entered (native)');
  try {
    developer.log('🔔 Initializing FCM…', name: 'Funzypp');
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await LocalNotificationService.initialize(
      onTap: (payload) {
        if (payload == null || payload.isEmpty) return;
        _handleNotificationClick({'type': payload});
      },
    );
    debugPrint('FCM DEBUG: LocalNotificationService.initialize() done');

    final settings = await FirebaseMessaging.instance.requestPermission();
    debugPrint('FCM DEBUG: requestPermission() -> ${settings.authorizationStatus}');

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('FCM DEBUG: permission NOT authorized, aborting');
      developer.log('⚠️ FCM permission denied', name: 'Funzypp');
      return;
    }

    developer.log('✅ FCM permissions granted', name: 'Funzypp');

    debugPrint('FCM DEBUG: about to call getToken()');
    final token = await FirebaseMessaging.instance.getToken();
    debugPrint('FCM DEBUG: getToken() returned -> ${token == null ? "NULL" : "token acquired (len=${token.length})"}');

    if (token != null) {
      developer.log(
        '📱 FCM Token: ${token.substring(0, token.length > 20 ? 20 : token.length)}…',
        name: 'Funzypp',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);

      debugPrint('FCM DEBUG: isLoggedIn=${authService.isLoggedIn}, userId=${authService.userId}');

      if (authService.isLoggedIn && authService.userId != null) {
        final platform = Platform.isIOS ? 'ios' : 'android';
        debugPrint('FCM DEBUG: calling registerToken() platform=$platform');
        await NotificationService.registerToken(
          userId: authService.userId!,
          fcmToken: token,
          platform: platform,
          authToken: authService.authToken,
        );
        debugPrint('FCM DEBUG: registerToken() call completed');
      } else {
        debugPrint('FCM DEBUG: skipped registerToken() — not logged in yet');
      }
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('FCM DEBUG: onTokenRefresh fired');
      developer.log('🔄 FCM Token refreshed', name: 'Funzypp');
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('fcm_token', newToken);
      });

      if (authService.isLoggedIn && authService.userId != null) {
        final platform = Platform.isIOS ? 'ios' : 'android';
        NotificationService.registerToken(
          userId: authService.userId!,
          fcmToken: newToken,
          platform: platform,
          authToken: authService.authToken,
        );
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM DEBUG: onMessage (foreground) fired');
      developer.log('🔔 Foreground FCM message', name: 'Funzypp');
      final payload = _buildPayload(message);

      LocalNotificationService.show(message);

      if (payload['type'] == 'comrade_added') {
        final username = message.data['username'] ?? 'Someone';
        if (messengerKey.currentContext != null) {
          ScaffoldMessenger.of(messengerKey.currentContext!).showSnackBar(
            SnackBar(
              content: Text('🎉 $username added you as a comrade!'),
              backgroundColor: FanColors.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'View',
                textColor: FanColors.textInverse,
                onPressed: () =>
                    navigatorKey.currentState?.pushNamed('/profile'),
              ),
            ),
          );
        }
      }
      NotificationService.pushToStream(payload);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM DEBUG: onMessageOpenedApp fired');
      developer.log('🔔 App resumed from notification tap', name: 'Funzypp');
      _handleNotificationClick(message.data);
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FCM DEBUG: launched from terminated state via notification');
      developer.log(
        '🔔 App launched from terminated state via notification',
        name: 'Funzypp',
      );
      Future.delayed(
        const Duration(milliseconds: 500),
        () => _handleNotificationClick(initialMessage.data),
      );
    }

    debugPrint('FCM DEBUG: initializeFCM() completed successfully');
  } catch (e, st) {
    debugPrint('FCM DEBUG: initializeFCM() THREW -> $e');
    debugPrint('FCM DEBUG: stack trace -> $st');
    developer.log('❌ FCM initialization error: $e', name: 'Funzypp');
  }
}













Map<String, dynamic> _buildPayload(RemoteMessage message) {
  final type =
      message.data['type'] ?? message.data['notificationType'] ?? 'general';
  return {
    'type': type,
    'title': message.notification?.title ??
        message.data['title'] ??
        'New Notification',
    'body': message.notification?.body ?? message.data['body'] ?? '',
    'data': message.data,
    'notificationId': message.messageId ?? '',
    'timestamp': DateTime.now().toIso8601String(),
  };
}

void _handleNotificationClick(Map<String, dynamic> data) {
  final type = data['type'] as String? ?? '';
  if (type == 'comrade_added') {
    navigatorKey.currentState?.pushNamed('/profile');
  } else if (type.contains('vote') ||
      type.contains('sub_fixture') ||
      data.containsKey('fixture_id')) {
    navigatorKey.currentState?.pushNamed('/fixtures');
  } else if (type == 'comment' ||
      type == 'like' ||
      data.containsKey('post_id')) {
    navigatorKey.currentState?.pushNamed('/feed');
  }
}

// ============================================================================
// HEAVY DATA LOAD
// ============================================================================
void _loadHeavyDataInBackground() {
  Future.microtask(() async {
    await AppCache.load();
    await AppCache.refreshComrades(authService.authToken);
    await AppCache.refreshHistoryGamesWithComments(
        authToken: authService.authToken);
  });
}



// ============================================================================
// MAIN ENTRY POINT - FAST STARTUP
// ============================================================================
Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // ✅ Tell the native splash to stay up past first frame — this is what
  // eliminates the blank/white flash between native splash and Flutter UI.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  final sw = Stopwatch()..start();

  // ✅ AWAITED — was `unawaited(...)`. Nothing that touches Firebase
  // (FirebaseMessaging.instance, FirebaseAuth, etc.) is safe to call
  // until this has actually completed. Racing it caused an intermittent
  // JS/Dart interop TypeError inside requestPermission() on web.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  authService = AuthService();
  // ✅ Was unawaited — awaited now so isLoggedIn/userId are reliably known
  // before HomePage.initState() and initializeFCM() both check them. This
  // is a fast SharedPreferences read, not a network call, so it doesn't
  // meaningfully delay startup.
  await authService.initialize();

  await AppCache.loadFixturesInstantly();
  await AppCache.loadUserVotes();

  MemoryManager().startMonitoring();

  runApp(const Funzypp());

  developer.log('⏱ runApp called at ${sw.elapsedMilliseconds}ms',
      name: 'Funzypp');

  // ✅ Remove the native splash only once the first real frame (with
  // fixtures + votes already populated) has actually been painted.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FlutterNativeSplash.remove();
  });

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadHeavyDataInBackground();
  });

  Future.delayed(const Duration(seconds: 3), () => AppCache.refreshAll());

  // ✅ Platform-specific push init: web uses VAPID + service worker +
  // browser Notification API; mobile uses FCM's native background handler
  // + flutter_local_notifications for foreground display.
  unawaited(() async {
    try {
      await initializeDeepLinks();
    } catch (e) {
      developer.log('❌ Deep link init error: $e', name: 'Funzypp');
    }

    try {
      if (kIsWeb) {
        await initializeFCMWeb();
      } else {
        await initializeFCM();
      }
    } catch (e) {
      developer.log('❌ FCM init error: $e', name: 'Funzypp');
    }
  }());

  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
    developer.log('🔥 Flutter Error: ${details.exception}',
        name: 'Funzypp', error: details.exception);
  };
}

Future<bool> _hasNotificationPermission() async {
  if (kIsWeb) {
    return WebNotificationService.getPermissionStatus() == 'granted';
  }
  final settings = await FirebaseMessaging.instance.getNotificationSettings();
  return settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;
}

Future<bool> _requestNotificationPermission() async {
  if (kIsWeb) {
    await WebNotificationService.requestPermission();
    return WebNotificationService.getPermissionStatus() == 'granted';
  }
  final settings = await FirebaseMessaging.instance.requestPermission();
  return settings.authorizationStatus == AuthorizationStatus.authorized;
}

// ============================================================================
// MAIN APP WIDGET
// ============================================================================
class Funzypp extends StatefulWidget {
  const Funzypp({super.key});

  @override
  State<Funzypp> createState() => _FunzyppState();
}

class _FunzyppState extends State<Funzypp> with WidgetsBindingObserver {
  late AuthService _authService;
  bool _isLoggedIn = false;
  String? _userId;
  String? _username;

  bool _isBackground = false;
  bool _isLoading = false;

  Timer? _backgroundTeardownTimer;
  static const Duration _teardownDelay = Duration(seconds: 1800);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _authService = AuthService();
    _authService.addListener(_onAuthStateChanged);
    _isLoggedIn = _authService.isLoggedIn;
    _userId = _authService.userId;
    _username = _authService.username;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingNotifications();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appCacheRefreshTimer?.cancel();
    _backgroundTeardownTimer?.cancel();
    _authService.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _backgroundTeardownTimer?.cancel();
        _backgroundTeardownTimer = null;

        if (_isBackground) {
          _isBackground = false;
          MemoryManager().onForeground();
          startAppCacheRefresh();
        }
        break;
        case AppLifecycleState.resumed:
        _backgroundTeardownTimer?.cancel();
        _backgroundTeardownTimer = null;

        if (_isBackground) {
          _isBackground = false;
          MemoryManager().onForeground();
          startAppCacheRefresh();
        }

        // ✅ NEW — reconcile with the server on every resume, so counts
        // recover even if a push was missed entirely while backgrounded.
        if (_isLoggedIn && _userId != null) {
          final adminChannelIds = AppCache.channels
              .where((c) => c.isAdmin)
              .map((c) => c.channelId)
              .toList();
          NotificationService.reconcileFromServer(
            userId: _userId!,
            authToken: _authService.authToken,
            adminChannelIds: adminChannelIds,
          );
        }
        break;

      case AppLifecycleState.paused:
        _backgroundTeardownTimer?.cancel();
        _backgroundTeardownTimer = Timer(_teardownDelay, () {
          _isBackground = true;
          MemoryManager().onBackground();
          stopAppCacheRefresh();
        });
        break;

      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _checkPendingNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('pending_notifications') ?? [];
      if (pending.isNotEmpty) {
        developer.log(
          '📱 Found ${pending.length} pending notifications',
          name: 'Funzypp',
        );
        await prefs.remove('pending_notifications');
      }
    } catch (e) {
      developer.log('⚠️ Error checking pending notifications: $e',
          name: 'Funzypp');
    }
  }

  void _onAuthStateChanged() {
    if (mounted) {
      setState(() {
        _isLoggedIn = _authService.isLoggedIn;
        _userId = _authService.userId;
        _username = _authService.username;
      });
      developer.log(
          '🔄 Auth state changed: loggedIn=$_isLoggedIn, userId=$_userId',
          name: 'Funzypp');

      if (!_isLoggedIn && !_isLoginModalOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showLoginModalAsOverlay();
        });
      }
    }
  }

 void _showLoginModalAsOverlay() async {
    if (_isLoginModalOpen || !mounted) return;

    final hasPermission = await _hasNotificationPermission();
    if (!hasPermission) {
      _showNotificationGateDialog();
      return; // login modal never opens until this resolves
    }

    _openLoginModal();
  }

  void _openLoginModal() {
    _isLoginModalOpen = true;
    final context = navigatorKey.currentContext;
    if (context == null) {
      _isLoginModalOpen = false;
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => LoginModal(
        messengerKey: messengerKey,
        onLoginSuccess: (userId, username) {
          setState(() {
            _isLoggedIn = _authService.isLoggedIn;
            _userId = _authService.userId;
            _username = _authService.username;
          });
          _isLoginModalOpen = false;
          developer.log('✅ Login successful: $username ($userId)',
              name: 'Funzypp');
        },
      ),
    ).then((_) {
      _isLoginModalOpen = false;
    });
  }

  void _showNotificationGateDialog() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    bool isBlocked =
        kIsWeb && WebNotificationService.getPermissionStatus() == 'denied';
    bool requesting = false;

    showDialog(
      context: context,
      barrierDismissible: false, // can't tap outside to skip it
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setD) => PopScope(
          canPop: false, // can't back-button out of it either
          child: AlertDialog(
            backgroundColor: FanColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: FanRadius.lgAll,
              side: BorderSide(color: FanColors.border),
            ),
            title: Row(
              children: [
                Icon(Icons.notifications_active, color: FanColors.primary),
                const SizedBox(width: 10),
                Text('Notifications Required', style: FanTypography.headline),
              ],
            ),
            content: Text(
              isBlocked
                  ? 'You blocked notifications for this site. Open your '
                      'browser\'s site settings, allow notifications, then tap '
                      'Retry below.'
                  : 'Funspot needs notification permission before you can '
                      'log in, so you never miss votes, comments, or comrade '
                      'activity.',
              style: FanTypography.body,
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FanColors.primary,
                  foregroundColor: FanColors.textInverse,
                  shape:
                      RoundedRectangleBorder(borderRadius: FanRadius.pillAll),
                ),
                onPressed: requesting
                    ? null
                    : () async {
                        setD(() => requesting = true);

                        final granted = isBlocked
                            ? await _hasNotificationPermission() // re-check after they fixed it in settings
                            : await _requestNotificationPermission();

                        if (granted) {
                          if (dialogContext.mounted)
                            Navigator.pop(dialogContext);
                          _openLoginModal();
                        } else {
                          setD(() {
                            requesting = false;
                            isBlocked = kIsWeb &&
                                WebNotificationService.getPermissionStatus() ==
                                    'denied';
                          });
                        }
                      },
                child: Text(isBlocked ? 'Retry' : 'Allow Notifications'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FanTheme.controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'Funspot',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: messengerKey,
          theme: fanFunzyTheme(),
          home: _buildHome(),
          routes: {
            '/feed': (context) => const HomePage(initialTab: 0),
            '/fixtures': (context) => const HomePage(initialTab: 1),
            '/profile': (context) => const HomePage(initialTab: 0),
          },
        );
      },
    );
  }

 Widget _buildHome() {
    return AppShell(userId: _authService.userId);
  }
}
