// modals/FAB/history_modal.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../pages/fan_Funzy_design.dart';
import 'dart:async';

// ========== HISTORY MODAL ==========
class HistoryModal extends StatefulWidget {
  final String apiBaseUrl;
  final VoidCallback onClose;

  const HistoryModal({
    super.key,
    required this.apiBaseUrl,
    required this.onClose,
  });

  @override
  State<HistoryModal> createState() => _HistoryModalState();
}

class _HistoryModalState extends State<HistoryModal>
    with WidgetsBindingObserver {
  List<HistoryActivity> _activities = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _userId;
  String? _username;

  // Cache keys
  static const String _cacheKey = 'history_cache';
  static const String _timestampKey = 'history_timestamp';
  static const Duration _cacheDuration = Duration(minutes: 30);
  static const Duration _backgroundFetchInterval = Duration(minutes: 15);

  // Stats
  int _totalVotes = 0;
  int _totalLikes = 0;
  int _totalComments = 0;

  // Background fetch timer
  Timer? _backgroundTimer;

  // App lifecycle state
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print('📜 HistoryModal initState called');
    _initializeData();
    _startBackgroundFetch();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      _checkForUpdates();
      _startBackgroundFetch();
    } else if (state == AppLifecycleState.paused) {
      _stopBackgroundFetch();
    }
  }

  void _startBackgroundFetch() {
    _backgroundTimer?.cancel();
    _backgroundTimer = Timer.periodic(_backgroundFetchInterval, (_) {
      if (mounted && _appLifecycleState == AppLifecycleState.resumed) {
        _checkForUpdates();
      }
    });
  }

  void _stopBackgroundFetch() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
  }

  Future<void> _checkForUpdates() async {
    if (_userId == null || _activities.isEmpty) return;

    try {
      final url = Uri.parse(
        '${widget.apiBaseUrl}/archive/user/$_userId/timestamp',
      );
      final response = await http.head(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final serverTimestamp =
            int.tryParse(response.headers['last-modified'] ?? '0') ?? 0;
        final lastSync = await _getLastSyncTime();

        if (serverTimestamp > lastSync) {
          await _fetchHistory(forceRefresh: true);
        }
      }
    } catch (e) {
      print('⚠️ Background update check failed: $e');
    }
  }

  Future<int> _getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_timestampKey) ?? 0;
  }

  Future<void> _initializeData() async {
    print('🔄 Starting history initialization');
    await _loadUserData();
    await _loadCachedData();
    await _fetchHistory();
  }

  Future<void> _loadUserData() async {
    print('👤 Loading user data from SharedPreferences...');
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');

    if (userString != null) {
      try {
        final userData = jsonDecode(userString);
        _userId = userData['id'] ?? userData['userId'] ?? userData['_id'] ?? '';
        _username = userData['username'] ?? userData['name'] ?? 'User';
        print('✅ User data loaded: $_username');
      } catch (e) {
        print('❌ Error parsing user data: $e');
      }
    }
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey);

      if (cachedData != null) {
        final List<dynamic> decoded = json.decode(cachedData);
        final activities =
            decoded.map((item) => HistoryActivity.fromJson(item)).toList();

        setState(() {
          _activities = activities;
          _updateStats(activities);
        });

        print('✅ Loaded ${activities.length} activities from cache');
      }
    } catch (e) {
      print('❌ Error loading cache: $e');
    }
  }

  Future<void> _saveToCache(List<HistoryActivity> activities) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = activities.map((a) => a.toJson()).toList();
      await prefs.setString(_cacheKey, json.encode(jsonList));
      await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
      print('✅ Saved ${activities.length} activities to cache');
    } catch (e) {
      print('❌ Error saving to cache: $e');
    }
  }

  void _updateStats(List<HistoryActivity> activities) {
    int voteCount = 0, likeCount = 0, commentCount = 0;

    for (var activity in activities) {
      switch (activity.activity_type) {
        case ActivityType.vote:
          voteCount++;
          break;
        case ActivityType.like:
          likeCount++;
          break;
        case ActivityType.comment:
          commentCount++;
          break;
      }
    }

    setState(() {
      _totalVotes = voteCount;
      _totalLikes = likeCount;
      _totalComments = commentCount;
    });
  }

  Future<void> _fetchHistory({bool forceRefresh = false}) async {
    print('\n📡 Fetching history...');

    if (_userId == null) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final url = Uri.parse('${widget.apiBaseUrl}/archive/user/$_userId');
      print('🌐 URL: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': forceRefresh ? 'no-cache' : 'max-age=300',
        },
      );

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          setState(() {
            _activities = [];
            _isLoading = false;
            _updateStats([]);
          });
          return;
        }

        try {
          final List<dynamic> data = json.decode(response.body);
          final List<HistoryActivity> activities = [];

          for (var item in data) {
            try {
              final activity = HistoryActivity.fromJson(item);
              activities.add(activity);
            } catch (e) {
              print('❌ Error parsing activity: $e');
            }
          }

          activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          setState(() {
            _activities = activities;
            _updateStats(activities);
            _isLoading = false;
            _hasError = false;
          });

          await _saveToCache(activities);
          print('✅ Loaded ${activities.length} activities');
        } catch (e) {
          print('❌ JSON parsing error: $e');
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      print('❌ Network error: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _showActivityDetails(HistoryActivity activity) async {
    // Fetch voters for this fixture
    final voters = await _fetchVotersForFixture(activity.fixture_id);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ActivityDetailsModal(
        activity: activity,
        voters: voters,
        currentUserId: _userId ?? '',
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  Future<FixtureVoters> _fetchVotersForFixture(String fixtureId) async {
    try {
      final response = await http.get(
        Uri.parse('${widget.apiBaseUrl}/votes/fixture/$fixtureId/voters'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return FixtureVoters.fromJson(data);
      }
    } catch (e) {
      print('❌ Error fetching voters: $e');
    }

    return FixtureVoters(supporters: [], rivals: []);
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopBackgroundFetch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: FanColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border.all(color: FanColors.border),
      ),
      child: Column(
        children: [
          // ── Handle ──
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: FanColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: FanColors.primaryDim,
                        borderRadius: FanRadius.lgAll,
                      ),
                      child: Icon(
                        Icons.history,
                        color: FanColors.primary,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'History',
                          style: FanTypography.headline.copyWith(fontSize: 16),
                        ),
                        if (_username != null)
                          Text(
                            _username!,
                            style: FanTypography.caption.copyWith(
                              color: FanColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildIconBtn(
                      icon: Icons.refresh,
                      color: FanColors.primary,
                      onTap: () => _fetchHistory(forceRefresh: true),
                    ),
                    const SizedBox(width: 2),
                    _buildIconBtn(
                      icon: Icons.close,
                      color: FanColors.textPrimary,
                      onTap: widget.onClose,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Stats ──
          if (!_isLoading && !_hasError && _activities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  _buildStatItem(
                    icon: Icons.how_to_vote,
                    count: _totalVotes,
                    label: 'Votes',
                    iconBg: FanColors.primaryDim,
                    iconColor: FanColors.primary,
                  ),
                  const SizedBox(width: 8),
                  _buildStatItem(
                    icon: Icons.favorite,
                    count: _totalLikes,
                    label: 'Likes',
                    iconBg: FanColors.reactionLike.withValues(alpha: 0.1),
                    iconColor: FanColors.reactionLike,
                  ),
                  const SizedBox(width: 8),
                  _buildStatItem(
                    icon: Icons.comment,
                    count: _totalComments,
                    label: 'Comments',
                    iconBg: FanColors.reactionShare.withValues(alpha: 0.1),
                    iconColor: FanColors.reactionShare,
                  ),
                ],
              ),
            ),

          // ── Updated ──
          if (!_isLoading && !_hasError && _activities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.sync,
                    size: 10,
                    color: FanColors.textTertiary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Updated just now',
                    style: FanTypography.tag.copyWith(
                      color: FanColors.textTertiary.withValues(alpha: 0.5),
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),

          Divider(
            color: FanColors.border.withValues(alpha: 0.4),
            height: 1,
            thickness: 0.5,
            indent: 0,
            endIndent: 0,
          ),

          // ── Content ──
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  // Helper: compact icon button
  Widget _buildIconBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  // Updated _buildStatItem signature — pass iconBg + iconColor
  Widget _buildStatItem({
    required IconData icon,
    required int count,
    required String label,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: FanColors.surfaceSunken,
          borderRadius: FanRadius.lgAll,
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: FanRadius.smAll,
              ),
              child: Icon(icon, size: 13, color: iconColor),
            ),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: FanTypography.headline.copyWith(fontSize: 14),
                ),
                Text(
                  label.toUpperCase(),
                  style: FanTypography.tag.copyWith(
                    fontSize: 9.5,
                    color: FanColors.textSecondary,
                    letterSpacing: 0.04,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: FanColors.primary,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading your history...',
              style: FanTypography.body.copyWith(
                color: FanColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError && _activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: FanColors.surfaceSunken,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.error_outline,
                    color: FanColors.primary,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Failed to load history',
                style: FanTypography.headline.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _userId == null
                    ? 'Please login to see your history'
                    : 'Check your connection and try again',
                textAlign: TextAlign.center,
                style: FanTypography.body.copyWith(
                  color: FanColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => _fetchHistory(forceRefresh: true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: FanDecorations.primaryButton,
                  child: Text(
                    'Retry',
                    style: FanTypography.button.copyWith(
                      color: FanColors.textInverse,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: FanColors.surfaceSunken,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.history,
                    color: FanColors.primary.withValues(alpha: 0.5),
                    size: 50,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No history yet',
                style: FanTypography.headline.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Start voting, liking, and commenting on fixtures to build your history',
                  textAlign: TextAlign.center,
                  style: FanTypography.body.copyWith(
                    color: FanColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchHistory(forceRefresh: true),
      color: FanColors.primary,
      backgroundColor: FanColors.surface,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _activities.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _showActivityDetails(_activities[index]),
            child: _buildActivityCard(_activities[index]),
          );
        },
      ),
    );
  }

  Widget _buildActivityCard(HistoryActivity activity) {
    final timeAgo = _formatTimeAgo(activity.timestamp);
    final activityColor = _getActivityColor(activity.activity_type);
    final activityIcon = _getActivityIcon(activity.activity_type);
    final activityTitle = _getActivityTitle(activity);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: FanDecorations.card(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and time
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: activityColor.withValues(alpha: 0.1),
                    borderRadius: FanRadius.lgAll,
                  ),
                  child: Icon(activityIcon, color: activityColor, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activityTitle,
                        style: FanTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: activityColor,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: FanTypography.tag.copyWith(
                          color: FanColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Match chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: FanColors.surfaceSunken,
                    borderRadius: FanRadius.pillAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        activity.home_team.length >= 2
                            ? activity.home_team.substring(0, 2).toUpperCase()
                            : activity.home_team.toUpperCase(),
                        style: FanTypography.tag.copyWith(
                          color: FanColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.sports_kabaddi,
                          size: 8,
                          color: FanColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      Text(
                        activity.away_team.length >= 2
                            ? activity.away_team.substring(0, 2).toUpperCase()
                            : activity.away_team.toUpperCase(),
                        style: FanTypography.tag.copyWith(
                          color: FanColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Teams
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      activity.home_team,
                      style: FanTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: FanColors.primaryDim,
                      borderRadius: FanRadius.pillAll,
                    ),
                    child: Text(
                      'VS',
                      style: FanTypography.tag.copyWith(
                        color: FanColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      activity.away_team,
                      style: FanTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.left,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Activity preview (short version)
            _buildActivityPreview(activity),

            // Tap indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.tap_and_play,
                  size: 12,
                  color: FanColors.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  'Tap for details',
                  style: FanTypography.tag.copyWith(
                    color: FanColors.primary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityPreview(HistoryActivity activity) {
    switch (activity.activity_type) {
      case ActivityType.vote:
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: FanColors.surfaceSunken,
            borderRadius: FanRadius.lgAll,
          ),
          child: Row(
            children: [
              Icon(
                Icons.how_to_vote,
                size: 14,
                color: _getVoteColor(activity.selection),
              ),
              const SizedBox(width: 6),
              Text(
                'Predicted: ${_getVoteText(activity.selection)}',
                style: TextStyle(
                  color: _getVoteColor(activity.selection),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

      case ActivityType.like:
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: FanColors.surfaceSunken,
            borderRadius: FanRadius.lgAll,
          ),
          child: Row(
            children: [
              Icon(
                activity.is_liked == true
                    ? Icons.favorite
                    : Icons.favorite_border,
                size: 14,
                color: activity.is_liked == true
                    ? FanColors.reactionLike
                    : FanColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                activity.is_liked == true
                    ? 'Liked this match'
                    : 'Unliked this match',
                style: TextStyle(
                  color: activity.is_liked == true
                      ? FanColors.reactionLike
                      : FanColors.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

      case ActivityType.comment:
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: FanColors.surfaceSunken,
            borderRadius: FanRadius.lgAll,
          ),
          child: Row(
            children: [
              Icon(
                Icons.comment,
                size: 14,
                color: FanColors.reactionShare,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  activity.comment ?? 'No comment',
                  style: TextStyle(
                    color: FanColors.reactionShare,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
    }
  }

  // Helper Methods
  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.vote:
        return FanColors.primary;
      case ActivityType.like:
        return FanColors.reactionLike;
      case ActivityType.comment:
        return FanColors.reactionShare;
    }
  }

  Color _getVoteColor(String? selection) {
    switch (selection) {
      case 'home_team':
        return FanColors.primary;
      case 'away_team':
        return FanColors.reactionShare;
      case 'draw':
        return FanColors.draw;
      default:
        return FanColors.textTertiary;
    }
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.vote:
        return Icons.how_to_vote;
      case ActivityType.like:
        return Icons.favorite;
      case ActivityType.comment:
        return Icons.comment;
    }
  }

  String _getActivityTitle(HistoryActivity activity) {
    switch (activity.activity_type) {
      case ActivityType.vote:
        return 'Vote Prediction';
      case ActivityType.like:
        return activity.is_liked == true ? 'Liked Fixture' : 'Unliked Fixture';
      case ActivityType.comment:
        return 'Commented on Fixture';
    }
  }

  String _getVoteText(String? selection) {
    switch (selection) {
      case 'home_team':
        return 'Home Win';
      case 'away_team':
        return 'Away Win';
      case 'draw':
        return 'Draw';
      default:
        return 'Unknown';
    }
  }
}

// ========== FIXTURE VOTERS MODEL ==========
class FixtureVoters {
  final List<Voter> supporters;
  final List<Voter> rivals;

  FixtureVoters({required this.supporters, required this.rivals});

  factory FixtureVoters.fromJson(Map<String, dynamic> json) {
    List<Voter> supporters = [];
    List<Voter> rivals = [];

    if (json['supporters'] != null) {
      supporters =
          (json['supporters'] as List).map((v) => Voter.fromJson(v)).toList();
    }

    if (json['rivals'] != null) {
      rivals = (json['rivals'] as List).map((v) => Voter.fromJson(v)).toList();
    }

    return FixtureVoters(supporters: supporters, rivals: rivals);
  }
}

// ========== VOTER MODEL ==========
class Voter {
  final String userId;
  final String username;
  final String selection;
  final DateTime votedAt;

  Voter({
    required this.userId,
    required this.username,
    required this.selection,
    required this.votedAt,
  });

  factory Voter.fromJson(Map<String, dynamic> json) {
    return Voter(
      userId: json['userId']?.toString() ?? json['voterId']?.toString() ?? '',
      username: json['username']?.toString() ?? 'Anonymous',
      selection: json['selection']?.toString() ?? '',
      votedAt: DateTime.parse(
        json['votedAt'] ??
            json['timestamp'] ??
            DateTime.now().toIso8601String(),
      ),
    );
  }
}

// ========== ACTIVITY DETAILS MODAL ==========
class ActivityDetailsModal extends StatelessWidget {
  final HistoryActivity activity;
  final FixtureVoters voters;
  final String currentUserId;
  final VoidCallback onClose;

  const ActivityDetailsModal({
    super.key,
    required this.activity,
    required this.voters,
    required this.currentUserId,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: FanColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border.all(color: FanColors.border),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: FanColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Activity Details',
                  style: FanTypography.headline.copyWith(fontSize: 18),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: FanColors.textPrimary,
                    size: 20,
                  ),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Match info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: FanDecorations.card(),
                    child: Column(
                      children: [
                        // League (if available)
                        Text(
                          'PREMIER LEAGUE', // Placeholder - you might want to fetch actual league
                          style: FanTypography.caption.copyWith(
                            color: FanColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Teams
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: FanColors.primary.withValues(
                                          alpha: 0.3,
                                        ),
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        activity.home_team.length >= 2
                                            ? activity.home_team
                                                .substring(0, 2)
                                                .toUpperCase()
                                            : activity.home_team.toUpperCase(),
                                        style: FanTypography.body.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: FanColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    activity.home_team,
                                    style: FanTypography.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Icon(
                                Icons.sports_kabaddi,
                                color: FanColors.primary.withValues(
                                  alpha: 0.5,
                                ),
                                size: 24,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: FanColors.primary.withValues(
                                          alpha: 0.3,
                                        ),
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        activity.away_team.length >= 2
                                            ? activity.away_team
                                                .substring(0, 2)
                                                .toUpperCase()
                                            : activity.away_team.toUpperCase(),
                                        style: FanTypography.body.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: FanColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    activity.away_team,
                                    style: FanTypography.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Activity details
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: FanDecorations.card(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Activity Information',
                          style: FanTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          icon: _getActivityIcon(activity.activity_type),
                          label: 'Type',
                          value: _getActivityTypeString(activity.activity_type),
                          color: _getActivityColor(activity.activity_type),
                        ),
                        Divider(height: 24, color: FanColors.border),
                        _buildDetailRow(
                          icon: Icons.person,
                          label: 'User',
                          value: activity.username,
                          color: FanColors.primary,
                        ),
                        Divider(height: 24, color: FanColors.border),
                        _buildDetailRow(
                          icon: Icons.access_time,
                          label: 'Time',
                          value: DateFormat(
                            'MMM d, yyyy • h:mm a',
                          ).format(activity.timestamp),
                          color: FanColors.textSecondary,
                        ),
                        if (activity.activity_type == ActivityType.vote) ...[
                          Divider(height: 24, color: FanColors.border),
                          _buildDetailRow(
                            icon: Icons.how_to_vote,
                            label: 'Prediction',
                            value: _getVoteText(activity.selection),
                            color: _getVoteColor(activity.selection),
                          ),
                        ],
                        if (activity.activity_type == ActivityType.like) ...[
                          Divider(height: 24, color: FanColors.border),
                          _buildDetailRow(
                            icon: activity.is_liked == true
                                ? Icons.favorite
                                : Icons.favorite_border,
                            label: 'Action',
                            value:
                                activity.is_liked == true ? 'Liked' : 'Unliked',
                            color: activity.is_liked == true
                                ? FanColors.reactionLike
                                : FanColors.textTertiary,
                          ),
                        ],
                        if (activity.activity_type == ActivityType.comment &&
                            activity.comment != null) ...[
                          Divider(height: 24, color: FanColors.border),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.comment,
                                      size: 16,
                                      color: FanColors.reactionShare,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Comment',
                                      style: FanTypography.caption.copyWith(
                                        color: FanColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: FanColors.surfaceSunken,
                                    borderRadius: FanRadius.lgAll,
                                  ),
                                  child: Text(
                                    activity.comment!,
                                    style: FanTypography.body,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Supporters Section (only for vote activities)
                  if (activity.activity_type == ActivityType.vote) ...[
                    // Supporters
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: FanDecorations.card(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: FanColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: FanRadius.smAll,
                                ),
                                child: Icon(
                                  Icons.people,
                                  color: FanColors.primary,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Supporters (${voters.supporters.length})',
                                style: FanTypography.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: FanColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (voters.supporters.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.people_outline,
                                      size: 32,
                                      color: FanColors.textTertiary
                                          .withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No supporters yet',
                                      style: FanTypography.caption.copyWith(
                                        color: FanColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 200,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: voters.supporters.length,
                                itemBuilder: (context, index) {
                                  final supporter = voters.supporters[index];
                                  final isCurrentUser =
                                      supporter.userId == currentUserId;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: FanColors.surfaceSunken,
                                      borderRadius: FanRadius.lgAll,
                                      border: Border.all(
                                        color: isCurrentUser
                                            ? FanColors.primary.withValues(
                                                alpha: 0.5,
                                              )
                                            : Colors.transparent,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Avatar placeholder
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: FanColors.primary.withValues(
                                              alpha: 0.1,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              supporter.username.isNotEmpty
                                                  ? supporter.username[0]
                                                      .toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                color: FanColors.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                supporter.username,
                                                style:
                                                    FanTypography.body.copyWith(
                                                  fontWeight: isCurrentUser
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                              if (isCurrentUser)
                                                Text(
                                                  'You',
                                                  style: FanTypography.tag
                                                      .copyWith(
                                                    color: FanColors.primary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getVoteColor(
                                              supporter.selection,
                                            ).withValues(alpha: 0.1),
                                            borderRadius: FanRadius.pillAll,
                                          ),
                                          child: Text(
                                            _getVoteText(supporter.selection),
                                            style: TextStyle(
                                              color: _getVoteColor(
                                                supporter.selection,
                                              ),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Rivals Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: FanDecorations.card(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: FanColors.away.withValues(alpha: 0.1),
                                  borderRadius: FanRadius.smAll,
                                ),
                                child: Icon(
                                  Icons.groups,
                                  color: FanColors.away,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Rivals (${voters.rivals.length})',
                                style: FanTypography.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: FanColors.away,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (voters.rivals.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.group_outlined,
                                      size: 32,
                                      color: FanColors.textTertiary
                                          .withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No rivals yet',
                                      style: FanTypography.caption.copyWith(
                                        color: FanColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 200,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: voters.rivals.length,
                                itemBuilder: (context, index) {
                                  final rival = voters.rivals[index];

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: FanColors.surfaceSunken,
                                      borderRadius: FanRadius.lgAll,
                                    ),
                                    child: Row(
                                      children: [
                                        // Avatar placeholder
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: FanColors.away.withValues(
                                              alpha: 0.1,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              rival.username.isNotEmpty
                                                  ? rival.username[0]
                                                      .toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                color: FanColors.away,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            rival.username,
                                            style: FanTypography.body,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getVoteColor(
                                              rival.selection,
                                            ).withValues(alpha: 0.1),
                                            borderRadius: FanRadius.pillAll,
                                          ),
                                          child: Text(
                                            _getVoteText(rival.selection),
                                            style: TextStyle(
                                              color: _getVoteColor(
                                                rival.selection,
                                              ),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: FanRadius.smAll,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: FanTypography.tag.copyWith(
                  color: FanColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: FanTypography.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper Methods (defined inside ActivityDetailsModal)
  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.vote:
        return FanColors.primary;
      case ActivityType.like:
        return FanColors.reactionLike;
      case ActivityType.comment:
        return FanColors.reactionShare;
    }
  }

  Color _getVoteColor(String? selection) {
    switch (selection) {
      case 'home_team':
        return FanColors.primary;
      case 'away_team':
        return FanColors.reactionShare;
      case 'draw':
        return FanColors.draw;
      default:
        return FanColors.textTertiary;
    }
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.vote:
        return Icons.how_to_vote;
      case ActivityType.like:
        return Icons.favorite;
      case ActivityType.comment:
        return Icons.comment;
    }
  }

  String _getActivityTypeString(ActivityType type) {
    switch (type) {
      case ActivityType.vote:
        return 'Vote';
      case ActivityType.like:
        return 'Like';
      case ActivityType.comment:
        return 'Comment';
    }
  }

  String _getVoteText(String? selection) {
    switch (selection) {
      case 'home_team':
        return 'Home Win';
      case 'away_team':
        return 'Away Win';
      case 'draw':
        return 'Draw';
      default:
        return 'Unknown';
    }
  }
}

// ========== ACTIVITY TYPE ENUM ==========
enum ActivityType {
  vote,
  like,
  comment;

  @override
  String toString() => name;

  static ActivityType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'vote':
        return ActivityType.vote;
      case 'like':
        return ActivityType.like;
      case 'comment':
        return ActivityType.comment;
      default:
        return ActivityType.vote;
    }
  }
}

// ========== HISTORY ACTIVITY MODEL ==========
class HistoryActivity {
  final String? id;
  final String user_id;
  final String username;
  final String fixture_id;
  final String home_team;
  final String away_team;
  final ActivityType activity_type;
  final String? selection;
  final bool? is_liked;
  final String? comment;
  final DateTime timestamp;
  final DateTime created_at;

  HistoryActivity({
    this.id,
    required this.user_id,
    required this.username,
    required this.fixture_id,
    required this.home_team,
    required this.away_team,
    required this.activity_type,
    this.selection,
    this.is_liked,
    this.comment,
    required this.timestamp,
    required this.created_at,
  });

  factory HistoryActivity.fromJson(Map<String, dynamic> json) {
    // Handle MongoDB _id field
    String? id;
    if (json['_id'] != null) {
      if (json['_id'] is Map<String, dynamic>) {
        id = json['_id']['\$oid'] ?? json['_id']['oid'];
      } else if (json['_id'] is String) {
        id = json['_id'];
      }
    }

    // Parse timestamp
    DateTime timestamp;
    try {
      final timestampStr = json['timestamp'];
      if (timestampStr is String) {
        timestamp = DateTime.parse(timestampStr).toLocal();
      } else {
        timestamp = DateTime.now();
      }
    } catch (e) {
      timestamp = DateTime.now();
    }

    // Parse created_at
    DateTime createdAt;
    try {
      final createdStr = json['created_at'];
      if (createdStr is String) {
        createdAt = DateTime.parse(createdStr).toLocal();
      } else {
        createdAt = DateTime.now();
      }
    } catch (e) {
      createdAt = DateTime.now();
    }

    return HistoryActivity(
      id: id,
      user_id: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? 'Unknown',
      fixture_id: json['fixture_id']?.toString() ?? '',
      home_team: json['home_team']?.toString() ?? '',
      away_team: json['away_team']?.toString() ?? '',
      activity_type: ActivityType.fromString(
        json['activity_type']?.toString() ?? 'vote',
      ),
      selection: json['selection']?.toString(),
      is_liked: json['is_liked'] is bool ? json['is_liked'] as bool? : null,
      comment: json['comment']?.toString(),
      timestamp: timestamp,
      created_at: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': user_id,
      'username': username,
      'fixture_id': fixture_id,
      'home_team': home_team,
      'away_team': away_team,
      'activity_type': activity_type.toString(),
      'selection': selection,
      'is_liked': is_liked,
      'comment': comment,
      'timestamp': timestamp.toIso8601String(),
      'created_at': created_at.toIso8601String(),
    };
  }
}
