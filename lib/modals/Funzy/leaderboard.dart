import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/fixture_models.dart';
import '../../services/notification_service.dart';
import "../../pages/fan_Funzy_design.dart";
import '../../utils/add_helper.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

// ============================================================================
// LOCAL STORAGE KEYS
// ============================================================================
class StorageKeys {
  static const String votersPrefix = 'cached_voters_';
  static const String timestampPrefix = 'voters_timestamp_';
  static const String comradesCacheKey = 'comrades_cache_';
  static const String comradesTimestampKey = 'comrades_timestamp_';
  static const Duration cacheDuration = Duration(minutes: 5);
}

// ============================================================================
// CAROUSEL ITEM TYPE
// ============================================================================
enum CarouselItemType { comrade, ad }

class CarouselItem {
  final CarouselItemType type;
  final ComradeWithStats? comrade;
  final String? adUnitId;

  CarouselItem.comrade({required this.comrade})
      : type = CarouselItemType.comrade,
        adUnitId = null;

  CarouselItem.ad({required this.adUnitId})
      : type = CarouselItemType.ad,
        comrade = null;
}

// ============================================================================
// VOTER MODEL
// ============================================================================
class Voter {
  final String userId;
  final String username;
  final String selection;
  final bool isComrade;
  final DateTime votedAt;

  Voter({
    required this.userId,
    required this.username,
    required this.selection,
    this.isComrade = false,
    required this.votedAt,
  });

  factory Voter.fromJson(Map<String, dynamic> json) {
    return Voter(
      userId: json['userId']?.toString() ?? '',
      username: json['userName']?.toString() ?? 'Anonymous',
      selection: json['selection']?.toString() ?? '',
      isComrade: json['isComrade'] ?? false,
      votedAt: json['votedAt'] != null
          ? DateTime.tryParse(json['votedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': username,
      'selection': selection,
      'isComrade': isComrade,
      'votedAt': votedAt.toIso8601String(),
    };
  }
}

// ============================================================================
// VOTE STATS
// ============================================================================
class VoteStats {
  final int homeCount;
  final int awayCount;
  final int drawCount;
  final int total;

  VoteStats({
    required this.homeCount,
    required this.awayCount,
    required this.drawCount,
  }) : total = homeCount + awayCount + drawCount;

  double get homePercentage => total > 0 ? (homeCount / total) * 100 : 0;
  double get awayPercentage => total > 0 ? (awayCount / total) * 100 : 0;
  double get drawPercentage => total > 0 ? (drawCount / total) * 100 : 0;
}

// ============================================================================
// COMRADE MODEL WITH STATS
// ============================================================================
class ComradeWithStats {
  final String id;
  final String username;
  final String nickname;
  final String clubFan;
  final String countryFan;
  final bool isComrade;
  final DateTime? joinedDate;
  final int totalPoints;
  final double accuracyPercentage;
  final int correctVotes;
  final int totalVotes;
  final int currentStreak;
  final int bestStreak;
  final bool isOnline;
  final int rank;
  final String? avatarUrl;
  final int messageCount;
  

  ComradeWithStats({
    required this.id,
    required this.username,
    required this.nickname,
    required this.clubFan,
    required this.countryFan,
    this.isComrade = true,
    this.joinedDate,
    required this.totalPoints,
    required this.accuracyPercentage,
    required this.correctVotes,
    required this.totalVotes,
    required this.currentStreak,
    required this.bestStreak,
    this.isOnline = false,
    required this.rank,
    this.avatarUrl,
    this.messageCount = 0,
  });

  factory ComradeWithStats.fromChannelMember(
      Map<String, dynamic> json, Set<String> comradesList) {
    final userId = json['user_id']?.toString() ?? '';
    final totalVotes = (json['total_votes'] as int?) ?? 0;
    final correctVotes = (json['correct_votes'] as int?) ?? 0;
    final accuracy = (json['accuracy'] as num?)?.toDouble() ?? 0.0;
    final totalPoints = (json['season_points'] as int?) ?? 0;
    final rank = (json['rank'] as int?) ?? 0;

    return ComradeWithStats(
      id: userId,
      username: json['username']?.toString() ?? 'Anonymous',
      nickname: json['username']?.toString() ?? 'Anonymous',
      clubFan: '',
      countryFan: '',
      isComrade: comradesList.contains(userId),
      joinedDate: null,
      totalPoints: totalPoints,
      accuracyPercentage: accuracy,
      correctVotes: correctVotes,
      totalVotes: totalVotes,
      currentStreak: 0,
      bestStreak: 0,
      isOnline: false,
      rank: rank,
      messageCount: (json['message_count'] as int?) ?? 0,
    );
  }
}

// ============================================================================
// AD MANAGER
// ============================================================================
class CarouselAdManager {
  static final CarouselAdManager _instance = CarouselAdManager._internal();
  factory CarouselAdManager() => _instance;
  CarouselAdManager._internal();

  final Map<String, bool> _preloadedAds = {};

  void preloadAd(String adUnitId) {
    if (_preloadedAds.containsKey(adUnitId)) return;
    _preloadedAds[adUnitId] = true;
  }

  bool isAdReady(String adUnitId) => _preloadedAds.containsKey(adUnitId);

  String getAdUnitId(int index) {
    final ids = AdHelper.carouselAdUnitIds;
    return ids.isEmpty ? '' : ids[index % ids.length];
  }
}

// ============================================================================
// MAIN COMBINED MODAL - PITCH LIGHT STYLE
// ============================================================================
class ComradeModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final String? currentUserId;
  final String? currentUserName;
  final String? authToken;
  final String? channelId;
  final String? channelName;
  final Fixture? fixture;
  final Set<String> comradesList;
  final Map<String, Map<String, String>> comradesVoteMap;
  final bool hasUserVoted;
  final String? userVoteSelection;

  const ComradeModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    this.currentUserId,
    this.currentUserName,
    this.authToken,
    this.channelId,
    this.channelName,
    this.fixture,
    this.comradesList = const {},
    this.comradesVoteMap = const {},
    this.hasUserVoted = false,
    this.userVoteSelection,
  });

  @override
  State<ComradeModal> createState() => _ComradeModalState();
}

class _ComradeModalState extends State<ComradeModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Voters data
  List<Voter> _voters = [];
  List<Voter> _filteredVoters = [];
  bool _isLoadingVoters = true;
  String _selectedFilter = 'all';
  final ScrollController _voterScroll = ScrollController();

  // Leaderboard data
  List<ComradeWithStats> _comrades = [];
  List<ComradeWithStats> _displayComrades = [];
  bool _isLoadingLeaderboard = true;
  bool _hasLoadedCache = false;

  // Carousel
  List<CarouselItem> _carouselItems = [];
  PageController? _carouselController;
  int _currentCarouselIndex = 0;
  Timer? _carouselTimer;
  bool _isCarouselRunning = false;
  final CarouselAdManager _adManager = CarouselAdManager();

  // Shared
  late SharedPreferences _prefs;
  StreamSubscription<Map<String, dynamic>>? _badgeSubscription;

  static const String _api = 'https://clash-api-m5mr.onrender.com/api';
  static const Duration _timeout = Duration(seconds: 15);

  // ==========================================================================
  // INIT
  // ==========================================================================
  @override
  void initState() {
    super.initState();
    _initPrefs();
    _tabController = TabController(length: _getTabCount(), vsync: this);
    _carouselController = PageController();
    _listenToFCMUpdates();
    if (widget.isOpen) {
      _loadVotersData();
      _loadLeaderboardData();
    }
  }

  int _getTabCount() {
    return widget.fixture != null ? 2 : 1;
  }

  @override
  void didUpdateWidget(covariant ComradeModal old) {
    super.didUpdateWidget(old);
    if (widget.isOpen && !old.isOpen) {
      _loadVotersData();
      _loadLeaderboardData();
    }
    if (widget.fixture != old.fixture && widget.isOpen) {
      _loadVotersData();
    }
    if (widget.comradesList != old.comradesList && widget.isOpen) {
      _loadLeaderboardData();
      _loadVotersData();
    }
    if (_getTabCount() != _tabController.length) {
      _tabController.dispose();
      _tabController = TabController(length: _getTabCount(), vsync: this);
    }
  }

  @override
  void dispose() {
    _stopCarouselAutoScroll();
    _badgeSubscription?.cancel();
    _carouselTimer?.cancel();
    _carouselController?.dispose();
    _voterScroll.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  void _listenToFCMUpdates() {
    _badgeSubscription = NotificationService.badgeStream.listen((event) {
      if (!widget.isOpen || !mounted) return;
      final eventFixtureId = event['fixture_id'] as String?;
      final isForThisFixture =
          widget.fixture != null && eventFixtureId == widget.fixture!.matchId;
      final notificationType = event['notification_type'] as String?;
      final isVoteOrComment = notificationType == 'vote_supporter' ||
          notificationType == 'vote_rival' ||
          notificationType == 'fixture_comment';
      if (isForThisFixture && isVoteOrComment && mounted) {
        _refreshVotersData();
      }
    });
  }

  // ==========================================================================
  // CAROUSEL METHODS
  // ==========================================================================
  void _buildCarousel() {
    if (_comrades.isEmpty) return;

    final items = <CarouselItem>[];
    int adSlotIndex = 0;

    for (int i = 0; i < _comrades.length; i++) {
      items.add(CarouselItem.comrade(comrade: _comrades[i]));

      if ((i + 1) % 3 == 0 && i < _comrades.length - 1) {
        final adUnitId = _adManager.getAdUnitId(adSlotIndex++);
        if (adUnitId.isNotEmpty) {
          _adManager.preloadAd(adUnitId);
          items.add(CarouselItem.ad(adUnitId: adUnitId));
        }
      }
    }

    setState(() {
      _carouselItems = items;
    });

    if (items.length > 1 && !_isCarouselRunning) {
      _startCarouselAutoScroll();
    }
  }

  void _startCarouselAutoScroll() {
    if (_isCarouselRunning || _carouselItems.length <= 1) return;
    _isCarouselRunning = true;
    _carouselTimer?.cancel();

    _carouselTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (!mounted || !_isCarouselRunning) {
        timer.cancel();
        _isCarouselRunning = false;
        return;
      }

      final controller = _carouselController;
      if (controller == null || !controller.hasClients) {
        timer.cancel();
        _isCarouselRunning = false;
        return;
      }

      final nextIndex = (_currentCarouselIndex + 1) % _carouselItems.length;
      controller.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _stopCarouselAutoScroll() {
    _isCarouselRunning = false;
    _carouselTimer?.cancel();
    _carouselTimer = null;
  }

  Widget _buildCarouselWidget() {
    if (_carouselItems.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 68,
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      child: PageView.builder(
        controller: _carouselController,
        onPageChanged: (index) {
          setState(() => _currentCarouselIndex = index);
        },
        itemCount: _carouselItems.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _buildCarouselItem(_carouselItems[index]),
        ),
      ),
    );
  }

  Widget _buildExitChannelButton() {
    // Check if user is a member of this channel
    final isMember = widget.channelId != null &&
        AppCache.channels.any((c) => c.channelId == widget.channelId);

    if (!isMember || widget.channelId == null) {
      return const SizedBox.shrink();
    }

    // Check if user is an admin (admins can't leave via this button)
    final isAdmin = AppCache.channels
        .any((c) => c.channelId == widget.channelId && c.isAdmin == true);

    if (isAdmin) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: FanColors.surfaceSunken,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: FanColors.border.withOpacity(0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.admin_panel_settings,
                color: FanColors.textTertiary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Admins cannot leave',
                style: TextStyle(
                  color: FanColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: _showLeaveChannelConfirmation,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                FanColors.away.withOpacity(0.1),
                FanColors.away.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: FanColors.away.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.exit_to_app,
                color: FanColors.away,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '⚠️ Exit Channel (-30 points)',
                style: TextStyle(
                  color: FanColors.away,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: FanColors.away.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '30pt',
                  style: TextStyle(
                    color: FanColors.away,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

   void _showLeaveChannelConfirmation() {
    if (widget.channelId == null || widget.currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot leave channel: Missing information'),
          backgroundColor: FanColors.away,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _LeaveChannelDialog(
        channelName: widget.channelName ?? 'this channel',
        channelId: widget.channelId!,
        userId: widget.currentUserId!,
        authToken: widget.authToken,
        onLeaveSuccess: () {
          // Close the modal and refresh UI
          widget.onClose();
          // Refresh channels list
          _refreshChannelsAfterLeave();
        },
      ),
    );
  }
   Future<void> _refreshChannelsAfterLeave() async {
    try {
      final authService = AuthService();
      if (authService.userId != null && authService.authToken != null) {
        await AppCache.refreshChannels(
          authService.userId!,
          authService.authToken,
        );
        // Also update the fixtures page if it's listening
        AppCache.notifyFixturesChanged();
      }
    } catch (e) {
      debugPrint('⚠️ Error refreshing channels after leave: $e');
    }
  }

  Widget _buildCarouselItem(CarouselItem item) {
    if (item.type == CarouselItemType.comrade && item.comrade != null) {
      return _buildComradeCarouselCard(item.comrade!);
    } else if (item.type == CarouselItemType.ad) {
      return _buildAdCarouselCard(item.adUnitId ?? '');
    }
    return const SizedBox.shrink();
  }

  Widget _buildComradeCarouselCard(ComradeWithStats comrade) {
    final isCurrentUser = comrade.id == widget.currentUserId;
    final isComrade = widget.comradesList.contains(comrade.id);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FanColors.surface,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: FanColors.border.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: FanColors.primaryDim,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                comrade.nickname[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: FanColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comrade.nickname,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: FanColors.textPrimary,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: FanColors.primaryDim,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'YOU',
                          style: TextStyle(
                              fontSize: 6,
                              fontWeight: FontWeight.bold,
                              color: FanColors.primary),
                        ),
                      ),
                    ] else if (isComrade) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: FanColors.secondaryDim,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'COM',
                          style: TextStyle(
                              fontSize: 6,
                              fontWeight: FontWeight.bold,
                              color: FanColors.primary),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.sports_soccer,
                        size: 8, color: FanColors.textTertiary),
                    const SizedBox(width: 2),
                    Text(
                      comrade.clubFan.isNotEmpty ? comrade.clubFan : 'No club',
                      style:
                          TextStyle(fontSize: 7, color: FanColors.textTertiary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${comrade.totalPoints} pts',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: FanColors.primary,
                ),
              ),
              if (comrade.currentStreak > 0)
                Row(
                  children: [
                    Icon(Icons.local_fire_department,
                        size: 8, color: FanColors.draw),
                    const SizedBox(width: 1),
                    Text(
                      '${comrade.currentStreak}',
                      style: TextStyle(fontSize: 7, color: FanColors.draw),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdCarouselCard(String adUnitId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FanColors.surface,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: FanColors.border.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: FanColors.primaryDim,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('⚡', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Funzy+',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: FanColors.textPrimary,
                  ),
                ),
                Text(
                  'Remove ads • Rewards',
                  style: TextStyle(fontSize: 7, color: FanColors.textTertiary),
                ),
              ],
            ),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: FanColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(Icons.arrow_forward_rounded,
                  size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // VOTERS SECTION
  // ==========================================================================
  Future<void> _loadVotersData() async {
    if (widget.fixture == null) return;

    final cachedVoters = await _loadVotersFromCache();
    if (cachedVoters != null && cachedVoters.isNotEmpty) {
      setState(() {
        _voters = cachedVoters;
        _applyVoterFilter();
        _isLoadingVoters = false;
      });
    } else {
      setState(() => _isLoadingVoters = true);
    }
    await _fetchVotersFromServer();
  }

  Future<List<Voter>?> _loadVotersFromCache() async {
    if (widget.fixture == null) return null;
    try {
      final fixtureId = widget.fixture!.matchId;
      final cachedVotersJson =
          _prefs.getString('${StorageKeys.votersPrefix}$fixtureId');
      final cachedTimestamp =
          _prefs.getInt('${StorageKeys.timestampPrefix}$fixtureId');

      if (cachedVotersJson == null) return null;
      if (cachedTimestamp != null) {
        final cacheAge =
            DateTime.now().millisecondsSinceEpoch - cachedTimestamp;
        if (cacheAge > StorageKeys.cacheDuration.inMilliseconds) return null;
      }

      final List<dynamic> decoded = json.decode(cachedVotersJson);
      final voters = decoded
          .map((item) => Voter.fromJson(item as Map<String, dynamic>))
          .toList();
      final filteredVoters = voters
          .where((v) =>
              widget.comradesList.contains(v.userId) ||
              v.userId == widget.currentUserId)
          .toList();

      return filteredVoters;
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveVotersToCache(List<Voter> voters) async {
    if (widget.fixture == null) return;
    try {
      final fixtureId = widget.fixture!.matchId;
      final votersJson = voters.map((v) => v.toJson()).toList();
      await _prefs.setString(
          '${StorageKeys.votersPrefix}$fixtureId', json.encode(votersJson));
      await _prefs.setInt('${StorageKeys.timestampPrefix}$fixtureId',
          DateTime.now().millisecondsSinceEpoch);
    } catch (e) {}
  }

  Future<void> _fetchVotersFromServer() async {
    if (widget.fixture == null) return;

    final fixtureId = widget.fixture!.matchId;

    final cachedVoters = AppCache.getCachedComradeVotersData(fixtureId);
    if (cachedVoters != null && cachedVoters.isNotEmpty && mounted) {
      final voters = cachedVoters.map((v) => Voter.fromJson(v)).toList();
      final filteredVoters = voters
          .where((v) =>
              widget.comradesList.contains(v.userId) ||
              v.userId == widget.currentUserId)
          .toList();
      setState(() {
        _voters = filteredVoters;
        _applyVoterFilter();
        _isLoadingVoters = false;
      });
    }

    try {
      final response = await http
          .get(
            Uri.parse('$_api/games/fixture/${widget.fixture!.matchId}/voters'),
            headers: _headers(),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['voters'] is List) {
          final votersList = data['voters'] as List;
          final List<Voter> voters = [];

          for (var voter in votersList) {
            final uid = voter['userId']?.toString() ?? '';
            final uname = voter['userName']?.toString() ?? 'Anonymous';
            final sel = voter['selection']?.toString() ?? '';

            if (uid.isNotEmpty && sel.isNotEmpty) {
              if (widget.comradesList.contains(uid) ||
                  uid == widget.currentUserId) {
                voters.add(Voter(
                  userId: uid,
                  username: uname,
                  selection: sel,
                  isComrade: widget.comradesList.contains(uid),
                  votedAt: DateTime.now(),
                ));
              }
            }
          }

          voters.sort((a, b) {
            if (a.userId == widget.currentUserId) return -1;
            if (b.userId == widget.currentUserId) return 1;
            return a.username.compareTo(b.username);
          });

          setState(() {
            _voters = voters;
            _applyVoterFilter();
            _isLoadingVoters = false;
          });

          final votersForCache = voters.map((v) => v.toJson()).toList();
          AppCache.cacheComradeVotersData(fixtureId, votersForCache);
        }
      }
    } catch (e) {
      if (mounted && _voters.isEmpty) setState(() => _isLoadingVoters = false);
    }
  }

  Future<void> _refreshVotersData() async {
    await _fetchVotersFromServer();
  }

  void _applyVoterFilter() {
    final List<Voter> filtered;
    switch (_selectedFilter) {
      case 'home':
        filtered = _voters.where((v) => v.selection == 'home_team').toList();
        break;
      case 'away':
        filtered = _voters.where((v) => v.selection == 'away_team').toList();
        break;
      case 'draw':
        filtered = _voters.where((v) => v.selection == 'draw').toList();
        break;
      default:
        filtered = List.from(_voters);
    }
    _filteredVoters = filtered;
  }

  VoteStats get _voteStats {
    int home = 0, away = 0, draw = 0;
    for (var v in _voters) {
      switch (v.selection) {
        case 'home_team':
          home++;
          break;
        case 'away_team':
          away++;
          break;
        case 'draw':
          draw++;
          break;
      }
    }
    return VoteStats(homeCount: home, awayCount: away, drawCount: draw);
  }

  // ==========================================================================
  // LEADERBOARD SECTION
  // ==========================================================================
  Future<void> _loadLeaderboardData() async {
    final userId = widget.currentUserId ?? '';

    final cachedLeaderboard = AppCache.getCachedComradeLeaderboard(userId);
    if (cachedLeaderboard != null && cachedLeaderboard.isNotEmpty) {
      final comrades = <ComradeWithStats>[];
      for (int i = 0; i < cachedLeaderboard.length; i++) {
        comrades.add(ComradeWithStats.fromChannelMember(
            cachedLeaderboard[i], widget.comradesList));
      }
      setState(() {
        _comrades = comrades;
        _displayComrades = comrades;
        _isLoadingLeaderboard = false;
        _hasLoadedCache = true;
      });
      _buildCarousel();
    } else {
      setState(() => _isLoadingLeaderboard = true);
    }

    await _fetchLeaderboardFromServer();
  }

  Future<void> _fetchLeaderboardFromServer() async {
    if (widget.authToken == null ||
        widget.currentUserId == null ||
        widget.channelId == null) {
      return;
    }

    try {
      final url = Uri.parse('$_api/channels/${widget.channelId}/leaderboard');
      final response = await http
          .get(
            url,
            headers: _headers(),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 && mounted && response.body.isNotEmpty) {
        final dynamic data = json.decode(response.body);

        if (data['success'] == true && data['leaderboard'] is List) {
          final leaderboardData = data['leaderboard'] as List;
          List<ComradeWithStats> comrades = [];

          for (var item in leaderboardData) {
            comrades.add(
                ComradeWithStats.fromChannelMember(item, widget.comradesList));
          }

          comrades.sort((a, b) => a.rank.compareTo(b.rank));

          setState(() {
            _comrades = comrades;
            _displayComrades = comrades;
            _isLoadingLeaderboard = false;
          });
          _buildCarousel();

          AppCache.cacheComradeLeaderboard(widget.currentUserId!,
              leaderboardData.cast<Map<String, dynamic>>());
        } else {
          setState(() => _isLoadingLeaderboard = false);
        }
      } else {
        setState(() => _isLoadingLeaderboard = false);
      }
    } catch (e) {
      debugPrint('❌ Error fetching leaderboard: $e');
      if (!_hasLoadedCache) setState(() => _isLoadingLeaderboard = false);
    }
  }

  void _showUserActivity(ComradeWithStats comrade) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ActivityHistorySheet(
        userId: comrade.id,
        userName: comrade.username,
        displayName: comrade.nickname,
        clubFan: comrade.clubFan,
        authToken: widget.authToken,
      ),
    );
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================
  Map<String, String> _headers() {
    final h = {'Content-Type': 'application/json'};
    if (widget.authToken != null && widget.authToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer ${widget.authToken}';
    }
    return h;
  }

  String _initials(String name) =>
      name.isNotEmpty ? name[0].toUpperCase() : 'U';
  String _displayVote(String sel) {
    if (widget.fixture == null) return sel;
    if (sel == 'home_team') return widget.fixture!.homeTeam;
    if (sel == 'away_team') return widget.fixture!.awayTeam;
    if (sel == 'draw') return 'Draw';
    return sel;
  }

  Color _getVoteColor(String sel) {
    switch (sel) {
      case 'home_team':
        return FanColors.primary;
      case 'away_team':
        return FanColors.away;
      case 'draw':
        return FanColors.draw;
      default:
        return FanColors.textTertiary;
    }
  }

  Color _getVoteBg(String sel) => _getVoteColor(sel).withOpacity(0.08);
  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return FanColors.primary;
    if (accuracy >= 70) return FanColors.draw;
    return FanColors.textTertiary;
  }

  // ==========================================================================
  // BUILD - PITCH LIGHT STYLE
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();
    final mq = MediaQuery.of(context);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: mq.size.height * 0.80,
            decoration: BoxDecoration(
              color: FanColors.background,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHandle(),
                _buildHeader(),
                _buildCarouselWidget(),
                if (_getTabCount() > 1) _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLeaderboardContent(),
                      if (widget.fixture != null) _buildVotersContent(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHandle() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: FanColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FanColors.primaryDim,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(Icons.emoji_events, color: FanColors.primary, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.channelName != null && widget.channelName!.isNotEmpty
                      ? widget.channelName!.toUpperCase()
                      : 'LEADERBOARD',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: FanColors.textPrimary,
                  ),
                ),
                Text(
                  '${_comrades.length} comrades',
                  style: TextStyle(
                    fontSize: 9,
                    color: FanColors.textTertiary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            GestureDetector(
              onTap: widget.onClose,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: FanColors.surfaceSunken,
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.close, size: 14, color: FanColors.textSecondary),
              ),
            ),
          ],
        ),
      );

  Widget _buildTabBar() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: FanColors.surfaceSunken,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: FanColors.border, width: 0.5),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: FanColors.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: FanShadows.subtle,
          ),
          labelColor: FanColors.textPrimary,
          unselectedLabelColor: FanColors.textTertiary,
          labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
          tabs: const [
            Tab(text: 'LEADERBOARD'),
            Tab(text: 'VOTES'),
          ],
        ),
      );

  // ==========================================================================
  // LEADERBOARD CONTENT - Slimmer
  // ==========================================================================
  Widget _buildLeaderboardContent() {
    final champion =
        _displayComrades.isNotEmpty ? _displayComrades.first : null;
    final members = _displayComrades.length > 1
        ? _displayComrades.sublist(1)
        : <ComradeWithStats>[];

    return _isLoadingLeaderboard && !_hasLoadedCache
        ? _buildLoadingState()
        : RefreshIndicator(
            onRefresh: _fetchLeaderboardFromServer,
            color: FanColors.primary,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                // ✅ EXIT BUTTON AT THE TOP
                _buildExitChannelButton(),
                const SizedBox(height: 8),
                if (champion != null) _buildChampionCard(champion),
                const SizedBox(height: 4),
                ...members.map((c) => _buildMemberCard(c)),
                if (members.isEmpty && champion == null)
                  _buildEmptyState('No comrades found'),
              ],
            ),
          );
  }

  Widget _buildChampionCard(ComradeWithStats comrade) {
    final isGold = comrade.rank == 1;
    final isSilver = comrade.rank == 2;
    final isBronze = comrade.rank == 3;

    Color rankColor;
    if (isGold) {
      rankColor = const Color(0xFFFFD700);
    } else if (isSilver)
      rankColor = Colors.grey.shade400;
    else if (isBronze)
      rankColor = const Color(0xFFCD7F32);
    else
      rankColor = FanColors.primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            rankColor.withOpacity(0.12),
            rankColor.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rankColor.withOpacity(0.15), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: rankColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: rankColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events, size: 12, color: rankColor),
                    const SizedBox(width: 3),
                    Text(
                      isGold
                          ? 'CHAMPION'
                          : (isSilver ? 'RUNNER UP' : '3RD PLACE'),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: rankColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: rankColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${comrade.rank}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: rankColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: rankColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: rankColor.withOpacity(0.2), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    comrade.nickname[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: rankColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comrade.nickname,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: FanColors.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '@${comrade.username}',
                          style: TextStyle(
                            fontSize: 9,
                            color: FanColors.textTertiary,
                          ),
                        ),
                        if (comrade.isOnline) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: FanColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (comrade.clubFan.isNotEmpty)
                      Text(
                        comrade.clubFan,
                        style: TextStyle(
                          fontSize: 8,
                          color: FanColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildChampionStat(
                  '${comrade.accuracyPercentage.toStringAsFixed(1)}%',
                  'ACCURACY',
                  '📊'),
              _buildChampionStat('${comrade.totalPoints}', 'POINTS', '🎯'),
              _buildChampionStat('${comrade.currentStreak}', 'STREAK', '🔥'),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showUserActivity(comrade),
              style: ElevatedButton.styleFrom(
                backgroundColor: rankColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(vertical: 6),
              ),
              child: Text(
                'VIEW ACTIVITY',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChampionStat(String value, String label, String emoji) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: FanColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 7, color: FanColors.textTertiary),
        ),
      ],
    );
  }

  Widget _buildMemberCard(ComradeWithStats comrade) {
    final isGold = comrade.rank == 1;
    final isSilver = comrade.rank == 2;
    final isBronze = comrade.rank == 3;

    Color rankColor;
    if (isGold) {
      rankColor = const Color(0xFFFFD700);
    } else if (isSilver)
      rankColor = Colors.grey.shade400;
    else if (isBronze)
      rankColor = const Color(0xFFCD7F32);
    else
      rankColor = FanColors.textTertiary;

    return GestureDetector(
      onTap: () => _showUserActivity(comrade),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: FanColors.surface,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: FanColors.border.withOpacity(0.3), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              alignment: Alignment.center,
              child: Text(
                '#${comrade.rank}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: rankColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: FanColors.primaryDim,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  comrade.nickname[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: FanColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        comrade.nickname,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: FanColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: FanColors.primaryDim,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'COM',
                          style: TextStyle(
                            fontSize: 5,
                            fontWeight: FontWeight.bold,
                            color: FanColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (comrade.clubFan.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.sports_soccer,
                            size: 8, color: FanColors.textTertiary),
                        const SizedBox(width: 2),
                        Text(
                          comrade.clubFan,
                          style: TextStyle(
                              fontSize: 7, color: FanColors.textTertiary),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 8,
                      color: _getAccuracyColor(comrade.accuracyPercentage),
                    ),
                    const SizedBox(width: 1),
                    Text(
                      '${comrade.accuracyPercentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: _getAccuracyColor(comrade.accuracyPercentage),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${comrade.totalPoints} pts',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: FanColors.primary,
                  ),
                ),
                if (comrade.currentStreak > 0) ...[
                  Row(
                    children: [
                      Icon(Icons.local_fire_department,
                          size: 8, color: FanColors.draw),
                      const SizedBox(width: 1),
                      Text(
                        '${comrade.currentStreak}',
                        style: TextStyle(fontSize: 7, color: FanColors.draw),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // VOTERS CONTENT - Slimmer
  // ==========================================================================
  Widget _buildVotersContent() {
    if (widget.fixture == null) return const SizedBox.shrink();

    return Column(
      children: [
        _buildVoteSummary(),
        _buildFilterChips(),
        Expanded(
          child: _isLoadingVoters && _voters.isEmpty
              ? _buildLoadingState()
              : RefreshIndicator(
                  onRefresh: _refreshVotersData,
                  color: FanColors.primary,
                  child: _buildVotersList(),
                ),
        ),
      ],
    );
  }

  Widget _buildVoteSummary() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: FanColors.surfaceSunken,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: FanColors.border, width: 0.5),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildVoteStat(widget.fixture!.homeTeam, _voteStats.homeCount,
                    _voteStats.homePercentage, FanColors.primary),
                const SizedBox(width: 8),
                _buildVoteStat('Draw', _voteStats.drawCount,
                    _voteStats.drawPercentage, FanColors.draw),
                const SizedBox(width: 8),
                _buildVoteStat(widget.fixture!.awayTeam, _voteStats.awayCount,
                    _voteStats.awayPercentage, FanColors.away),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 3,
                child: Row(
                  children: _voteStats.total == 0
                      ? [Expanded(child: Container(color: FanColors.border))]
                      : [
                          if (_voteStats.homeCount > 0)
                            Flexible(
                                flex: _voteStats.homePercentage
                                    .round()
                                    .clamp(1, 100),
                                child: Container(color: FanColors.primary)),
                          if (_voteStats.drawCount > 0)
                            Flexible(
                                flex: _voteStats.drawPercentage
                                    .round()
                                    .clamp(1, 100),
                                child: Container(color: FanColors.draw)),
                          if (_voteStats.awayCount > 0)
                            Flexible(
                                flex: _voteStats.awayPercentage
                                    .round()
                                    .clamp(1, 100),
                                child: Container(color: FanColors.away)),
                        ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildVoteStat(
          String label, int count, double percentage, Color color) =>
      Expanded(
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                  fontSize: 8, fontWeight: FontWeight.w500, color: color),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${percentage.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 7, color: color.withOpacity(0.7)),
            ),
          ],
        ),
      );

  Widget _buildFilterChips() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          children: [
            _buildFilterChip('All', 'all', _voteStats.total),
            const SizedBox(width: 4),
            _buildFilterChip(
                widget.fixture!.homeTeam, 'home', _voteStats.homeCount,
                color: FanColors.primary),
            const SizedBox(width: 4),
            _buildFilterChip('Draw', 'draw', _voteStats.drawCount,
                color: FanColors.draw),
            const SizedBox(width: 4),
            _buildFilterChip(
                widget.fixture!.awayTeam, 'away', _voteStats.awayCount,
                color: FanColors.away),
          ],
        ),
      );

  Widget _buildFilterChip(String label, String filter, int count,
      {Color? color}) {
    final isSelected = _selectedFilter == filter;
    final chipColor = color ?? FanColors.primary;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedFilter = filter;
        _applyVoterFilter();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : chipColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? null
              : Border.all(color: chipColor.withOpacity(0.15), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : chipColor,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 2),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white.withOpacity(0.8) : chipColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVotersList() {
    if (_filteredVoters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.how_to_vote_outlined,
                size: 32, color: FanColors.textTertiary.withOpacity(0.4)),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'all'
                  ? 'No votes yet'
                  : 'No votes for this selection',
              style: TextStyle(fontSize: 11, color: FanColors.textTertiary),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _voterScroll,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      itemCount: _filteredVoters.length,
      itemBuilder: (context, index) => _buildVoterCard(_filteredVoters[index]),
    );
  }

  Widget _buildVoterCard(Voter voter) {
    final isMe = voter.userId == widget.currentUserId;
    final voteColor = _getVoteColor(voter.selection);
    final voteBg = _getVoteBg(voter.selection);
    final voteDisplay = _displayVote(voter.selection);

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: voteBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _initials(voter.username),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: voteColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isMe ? 'You' : voter.username,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                        color: isMe ? FanColors.primary : FanColors.textPrimary,
                      ),
                    ),
                    if (voter.isComrade && !isMe) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: FanColors.primaryDim,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'comrade',
                          style: TextStyle(
                              fontSize: 6,
                              color: FanColors.primary,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Voted for $voteDisplay',
                  style: TextStyle(fontSize: 8, color: FanColors.textTertiary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: voteBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              voteDisplay,
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w500, color: voteColor),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // COMMON WIDGETS
  // ==========================================================================
  Widget _buildLoadingState() =>  Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: FanColors.primary),
            ),
            SizedBox(height: 8),
            Text('Loading...',
                style: TextStyle(fontSize: 10, color: FanColors.textTertiary)),
          ],
        ),
      );

  Widget _buildEmptyState(String message) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline,
                size: 36, color: FanColors.textTertiary.withOpacity(0.4)),
            const SizedBox(height: 8),
            Text(message,
                style: TextStyle(fontSize: 10, color: FanColors.textTertiary)),
          ],
        ),
      );
}

// ============================================================================
// ACTIVITY HISTORY SHEET
// ============================================================================
class _ActivityHistorySheet extends StatefulWidget {
  final String userId;
  final String userName;
  final String displayName;
  final String clubFan;
  final String? authToken;

  const _ActivityHistorySheet({
    required this.userId,
    required this.userName,
    required this.displayName,
    required this.clubFan,
    this.authToken,
  });

  @override
  State<_ActivityHistorySheet> createState() => _ActivityHistorySheetState();
}

class _ActivityHistorySheetState extends State<_ActivityHistorySheet> {
  List<ArchiveActivity> _activities = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  static const String _baseUrl = 'https://clash-api-m5mr.onrender.com/api';

  @override
  void initState() {
    super.initState();
    _fetchActivities();
  }

  Future<void> _fetchActivities() async {
    setState(() => _isLoading = true);
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (widget.authToken != null && widget.authToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${widget.authToken}';
      }
      final response = await http
          .get(Uri.parse('$_baseUrl/archive/user/${widget.userId}'),
              headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && mounted && response.body.isNotEmpty) {
        final List<dynamic> data = json.decode(response.body);
        final activities = data.map((item) => _activityFromJson(item)).toList();
        activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        setState(() {
          _activities = activities;
          _isLoading = false;
        });
      } else {
        setState(() {
          _activities = _generateMockActivities();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _activities = _generateMockActivities();
        _isLoading = false;
      });
    }
  }

  ArchiveActivity _activityFromJson(Map<String, dynamic> json) {
    DateTime timestamp;
    try {
      timestamp = DateTime.parse(json['timestamp']).toLocal();
    } catch (e) {
      timestamp = DateTime.now();
    }
    final activityType = ActivityType.values.firstWhere(
        (e) => e.toString().split('.').last == json['activity_type'],
        orElse: () => ActivityType.vote);
    return ArchiveActivity(
      id: json['_id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      fixtureId: json['fixture_id']?.toString() ?? '',
      homeTeam: json['home_team']?.toString() ?? 'Liverpool',
      awayTeam: json['away_team']?.toString() ?? 'Manchester City',
      activityType: activityType,
      selection: json['selection']?.toString(),
      selectedTeam: json['selection'] == 'home_team'
          ? (json['home_team'] ?? 'Home')
          : (json['selection'] == 'away_team'
              ? (json['away_team'] ?? 'Away')
              : 'Draw'),
      comment: json['comment']?.toString(),
      isLiked: json['is_liked'],
      timestamp: timestamp,
    );
  }

  List<ArchiveActivity> _generateMockActivities() {
    final matches = [
      ('Liverpool', 'Arsenal'),
      ('Barcelona', 'Real Madrid'),
      ('Man United', 'Chelsea'),
    ];
    final List<ArchiveActivity> acts = [];
    for (int i = 0; i < 5; i++) {
      final match = matches[i % matches.length];
      acts.add(ArchiveActivity(
        id: i.toString(),
        fixtureId: 'fixture_$i',
        homeTeam: match.$1,
        awayTeam: match.$2,
        activityType: ActivityType.vote,
        selectedTeam: match.$1,
        timestamp: DateTime.now().subtract(Duration(days: i)),
      ));
    }
    return acts;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: FanColors.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: FanColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _buildHeader(),
          _buildFilterTabs(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: FanColors.primaryDim,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.displayName[0].toUpperCase(),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: FanColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.displayName,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: FanColors.textPrimary)),
                  Text('@${widget.userName}',
                      style: TextStyle(
                          fontSize: 9, color: FanColors.textTertiary)),
                  if (widget.clubFan.isNotEmpty)
                    Text(widget.clubFan,
                        style: TextStyle(
                            fontSize: 9, color: FanColors.textTertiary)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: FanColors.surfaceSunken,
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.close, size: 14, color: FanColors.textSecondary),
              ),
            ),
          ],
        ),
      );

  Widget _buildFilterTabs() {
    final filters = ['All', 'Votes', 'Comments', 'Likes'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                filter,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color:
                      isSelected ? FanColors.primary : FanColors.textTertiary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }


  // Add this method to the ComradeModal widget

 

 
 





  Widget _buildContent() {
    if (_isLoading) {
      return  Center(
          child: SizedBox(
        width: 20,
        height: 20,
        child:
            CircularProgressIndicator(strokeWidth: 2, color: FanColors.primary),
      ));
    }

    List<ArchiveActivity> filtered = List.from(_activities);
    if (_selectedFilter != 'All') {
      final type = ActivityType.values.firstWhere(
          (e) => e.toString().split('.').last == _selectedFilter.toLowerCase());
      filtered = filtered.where((a) => a.activityType == type).toList();
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 36, color: FanColors.textTertiary.withOpacity(0.4)),
            const SizedBox(height: 8),
            Text('No activities yet',
                style: TextStyle(fontSize: 11, color: FanColors.textTertiary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (_, i) => _buildActivityCard(filtered[i]),
    );
  }

  Widget _buildActivityCard(ArchiveActivity activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: FanColors.surface,
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: FanColors.border.withOpacity(0.2), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(activity.getActivityIcon(),
                  size: 12, color: activity.getActivityColor()),
              const SizedBox(width: 6),
              Text(
                activity.activityType.toString().split('.').last.toUpperCase(),
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: activity.getActivityColor()),
              ),
              const SizedBox(width: 6),
              Text('•',
                  style: TextStyle(fontSize: 8, color: FanColors.textTertiary)),
              const SizedBox(width: 6),
              Text(activity.getTimeAgo(),
                  style: TextStyle(fontSize: 8, color: FanColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(activity.homeTeam,
                      style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.right),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('vs',
                      style: TextStyle(
                          fontSize: 9, color: FanColors.textTertiary)),
                ),
                Expanded(
                  child: Text(activity.awayTeam,
                      style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.left),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _buildActivityContent(activity),
        ],
      ),
    );
  }

  Widget _buildActivityContent(ArchiveActivity activity) {
    switch (activity.activityType) {
      case ActivityType.vote:
        return Row(
          children: [
            Container(
                width: 2,
                height: 12,
                decoration: BoxDecoration(
                    color: FanColors.primary,
                    borderRadius: BorderRadius.circular(1))),
            const SizedBox(width: 6),
            Icon(Icons.how_to_vote, size: 10, color: FanColors.primary),
            const SizedBox(width: 6),
            Text(activity.selectedTeam,
                style: TextStyle(fontSize: 10, color: FanColors.primary)),
          ],
        );
      case ActivityType.comment:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                width: 2,
                height: 12,
                decoration: BoxDecoration(
                    color: FanColors.draw,
                    borderRadius: BorderRadius.circular(1))),
            const SizedBox(width: 6),
            Icon(Icons.format_quote, size: 10, color: FanColors.draw),
            const SizedBox(width: 6),
            Expanded(
                child: Text(activity.comment ?? 'No comment',
                    style: TextStyle(fontSize: 10))),
          ],
        );
      case ActivityType.like:
        return Row(
          children: [
            Container(
                width: 2,
                height: 12,
                decoration: BoxDecoration(
                    color: FanColors.textTertiary,
                    borderRadius: BorderRadius.circular(1))),
            const SizedBox(width: 6),
            Icon(Icons.favorite_border,
                size: 10, color: FanColors.textTertiary),
            const SizedBox(width: 6),
            Text('Showed support',
                style: TextStyle(fontSize: 10, color: FanColors.textTertiary)),
          ],
        );
    }
  }
}

// ============================================================================
// ENUMS
// ============================================================================
enum ActivityType { vote, comment, like }
// ============================================================================
// LEAVE CHANNEL DIALOG
// ============================================================================

class _LeaveChannelDialog extends StatefulWidget {
  final String channelName;
  final String channelId;
  final String userId;
  final String? authToken;
  final VoidCallback onLeaveSuccess;

  const _LeaveChannelDialog({
    required this.channelName,
    required this.channelId,
    required this.userId,
    required this.authToken,
    required this.onLeaveSuccess,
  });

  @override
  State<_LeaveChannelDialog> createState() => _LeaveChannelDialogState();
}

class _LeaveChannelDialogState extends State<_LeaveChannelDialog> {
  final TextEditingController _confirmController = TextEditingController();
  bool _isLeaving = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _leaveChannel() async {
    // Validate that the user typed the channel name correctly
    if (_confirmController.text.trim() != widget.channelName.trim()) {
      setState(() {
        _errorMessage =
            'Channel name does not match. Please type the exact name.';
      });
      return;
    }

    setState(() {
      _isLeaving = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse(
            'https://clash-api-m5mr.onrender.com/api/channels/members/leave'),
        headers: {
          'Content-Type': 'application/json',
          if (widget.authToken != null && widget.authToken!.isNotEmpty)
            'Authorization': 'Bearer ${widget.authToken}',
        },
        body: json.encode({
          'channel_id': widget.channelId,
          'user_id': widget.userId,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // ✅ Update cache immediately - remove user from channel
        _updateCacheAfterLeave();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message'] ?? '✅ You left the channel (30 points deducted)',
            ),
            backgroundColor: FanColors.primary,
            duration: const Duration(seconds: 3),
          ),
        );

        // Close dialog and trigger callback
        Navigator.pop(context);
        widget.onLeaveSuccess();
      } else {
        final data = json.decode(response.body);
        setState(() {
          _errorMessage = data['message'] ?? 'Failed to leave channel';
          _isLeaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLeaving = false;
        });
      }
    }
  }

  void _updateCacheAfterLeave() {
    // Remove the user from the channel in memory
    try {
      // Remove channel from user's channels list
      AppCache.channels
          .removeWhere((channel) => channel.channelId == widget.channelId);

      // Remove channel fixtures for this channel
      final keysToRemove = AppCache.channelFixtures.keys
          .where((key) => key.contains(widget.channelId))
          .toList();
      for (var key in keysToRemove) {
        AppCache.channelFixtures.remove(key);
      }

      // Clear cached messages for this channel
      final messageKeysToRemove = AppCache.cachedMessages.keys
          .where((key) => key.startsWith(widget.channelId))
          .toList();
      for (var key in messageKeysToRemove) {
        AppCache.cachedMessages.remove(key);
      }

      // Remove per-channel vote counts
      AppCache.perChannelVoteCounts
          .removeWhere((key, _) => key.contains(widget.channelId));

      // Notify listeners
      AppCache.notifyFixturesChanged();

      if (kDebugMode) {
        debugPrint(
            '🗑️ Cache updated after leaving channel: ${widget.channelId}');
      }
    } catch (e) {
      debugPrint('⚠️ Error updating cache after leave: $e');
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⚠️ Warning Icon
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: FanColors.away.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: FanColors.away,
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Center(
            child: Text(
              'Leave Channel?',
              style: FanTypography.headline.copyWith(
                fontSize: 18,
                color: FanColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ⚠️ Warning about 30 point deduction
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FanColors.away.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: FanColors.away.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: FanColors.away,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚠️ 30 POINTS WILL BE DEDUCTED',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: FanColors.away,
                        ),
                      ),
                      Text(
                        'Leaving this channel will deduct 30 points from your total. This is to prevent channel hopping.',
                        style: TextStyle(
                          fontSize: 10,
                          color: FanColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Channel name confirmation
          Text(
            'Type "${widget.channelName}" to confirm:',
            style: TextStyle(
              fontSize: 12,
              color: FanColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmController,
            style: TextStyle(color: FanColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Type channel name here',
              hintStyle: TextStyle(color: FanColors.textTertiary, fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: FanColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: FanColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: FanColors.primary),
              ),
              errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
              errorStyle: TextStyle(fontSize: 10, color: FanColors.away),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (_) {
              if (_errorMessage.isNotEmpty) {
                setState(() => _errorMessage = '');
              }
            },
          ),
          const SizedBox(height: 16),

          // Buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _isLeaving ? null : () => Navigator.pop(context),
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
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _isLeaving ? null : _leaveChannel,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          FanColors.away,
                          FanColors.away.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: FanRadius.pillAll,
                    ),
                    child: _isLeaving
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
                              'Leave Channel',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
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

class ArchiveActivity {
  final String id;
  final String fixtureId;
  final String homeTeam;
  final String awayTeam;
  final ActivityType activityType;
  final String? selection;
  final String selectedTeam;
  final String? comment;
  final bool? isLiked;
  final DateTime timestamp;

  ArchiveActivity({
    required this.id,
    required this.fixtureId,
    required this.homeTeam,
    required this.awayTeam,
    required this.activityType,
    this.selection,
    required this.selectedTeam,
    this.comment,
    this.isLiked,
    required this.timestamp,
  });

  String getTimeAgo() {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('MMM d').format(timestamp);
  }

  IconData getActivityIcon() {
    switch (activityType) {
      case ActivityType.vote:
        return Icons.how_to_vote;
      case ActivityType.comment:
        return Icons.comment;
      case ActivityType.like:
        return Icons.favorite_border;
    }
  }

  Color getActivityColor() {
    switch (activityType) {
      case ActivityType.vote:
        return FanColors.primary;
      case ActivityType.comment:
        return FanColors.draw;
      case ActivityType.like:
        return FanColors.textTertiary;
    }
  }
}
