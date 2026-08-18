import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../pages/fan_Funzy_design.dart';
import "../../screens/home_page.dart";
import "../../models/user_channel.dart";

// ============================================================================
// LEADERBOARD MODEL
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
  });

  factory ComradeWithStats.fromComradeJson(
      Map<String, dynamic> json, int rank) {
    final totalVotes =
        json['total_votes'] ?? 15 + (json['comrade_id']?.hashCode ?? 0) % 50;
    final correctVotes = json['correct_votes'] ?? (totalVotes * 0.6).round();
    final accuracy = (correctVotes / totalVotes) * 100;
    final points = json['points'] ?? correctVotes * 10;

    return ComradeWithStats(
      id: json['comrade_id']?.toString() ?? '',
      username: json['comrade_username']?.toString() ?? 'user',
      nickname: json['comrade_nickname']?.toString() ?? 'Fan',
      clubFan: json['comrade_club']?.toString() ?? 'Football Fan',
      countryFan: json['comrade_country']?.toString() ?? 'World',
      isComrade: true,
      joinedDate: json['added_at'] != null
          ? DateTime.tryParse(json['added_at'].toString())
          : null,
      totalPoints: points,
      accuracyPercentage: accuracy,
      correctVotes: correctVotes,
      totalVotes: totalVotes,
      currentStreak: json['current_streak'] ?? 0,
      bestStreak: json['best_streak'] ?? 0,
      isOnline: json['is_online'] ?? false,
      rank: rank,
    );
  }
}

// ============================================================================
// ADMIN DASHBOARD MODAL WITH INTEGRATED LEADERBOARD
// ============================================================================

class AdminDashboardModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final String userId;
  final String username;
  final String? authToken;
  final List<UserChannel> userChannels;

  const AdminDashboardModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.userId,
    required this.username,
    this.authToken,
    required this.userChannels,
  });

  @override
  State<AdminDashboardModal> createState() => _AdminDashboardModalState();
}

class _AdminDashboardModalState extends State<AdminDashboardModal> {
  final PageController _channelPageController = PageController();
  int _currentChannelIndex = 0;

  bool _isLoading = true;
  bool _isWithdrawing = false;

  // Mock data for groups
  final Map<String, Map<String, dynamic>> _groupStats = {
    'Liosx': {
      'messages': 1247,
      'likes': 892,
      'votes': 456,
      'members': 34,
      'engagement': [65, 72, 68, 81, 79, 85, 78],
      'trend': '+12%',
      'trendUp': true,
      'balance': 1250.00,
    },
    'Arsenal FC': {
      'messages': 2341,
      'likes': 1567,
      'votes': 823,
      'members': 67,
      'engagement': [78, 82, 85, 79, 84, 88, 91],
      'trend': '+18%',
      'trendUp': true,
      'balance': 3420.50,
    },
    'Real Madrid': {
      'messages': 1892,
      'likes': 1103,
      'votes': 634,
      'members': 52,
      'engagement': [72, 75, 70, 78, 82, 86, 84],
      'trend': '+9%',
      'trendUp': true,
      'balance': 890.75,
    },
  };

  // Leaderboard data
  List<ComradeWithStats> _comrades = [];
  List<ComradeWithStats> _filteredComrades = [];
  bool _isLoadingLeaderboard = true;
  late SharedPreferences _prefs;

  static const String _api = 'https://clash-api-m5mr.onrender.com/api';
  static const Duration _timeout = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _initPrefs();
    _loadData();
    _loadLeaderboardData();
  }

  @override
  void dispose() {
    _channelPageController.dispose();
    super.dispose();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _isLoading = false);
  }

  // ==========================================================================
  // LEADERBOARD METHODS
  // ==========================================================================

  Future<void> _loadLeaderboardData() async {
    setState(() => _isLoadingLeaderboard = true);

    if (widget.authToken == null || widget.userId.isEmpty) {
      _useMockComrades();
      return;
    }

    try {
      final url = Uri.parse('$_api/comrades/comrades/${widget.userId}');
      final response = await http
          .get(
            url,
            headers: _headers(),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 && mounted && response.body.isNotEmpty) {
        final dynamic data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          List<ComradeWithStats> comrades = [];
          for (int i = 0; i < data.length; i++) {
            comrades.add(ComradeWithStats.fromComradeJson(data[i], i + 1));
          }
          comrades.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
          for (int i = 0; i < comrades.length; i++) {
            final c = comrades[i];
            comrades[i] = ComradeWithStats(
              id: c.id,
              username: c.username,
              nickname: c.nickname,
              clubFan: c.clubFan,
              countryFan: c.countryFan,
              isComrade: true,
              joinedDate: c.joinedDate,
              totalPoints: c.totalPoints,
              accuracyPercentage: c.accuracyPercentage,
              correctVotes: c.correctVotes,
              totalVotes: c.totalVotes,
              currentStreak: c.currentStreak,
              bestStreak: c.bestStreak,
              isOnline: c.isOnline,
              rank: i + 1,
            );
          }
          setState(() {
            _comrades = comrades;
            _filteredComrades = comrades;
            _isLoadingLeaderboard = false;
          });
        } else {
          _useMockComrades();
        }
      } else {
        _useMockComrades();
      }
    } catch (e) {
      debugPrint('❌ Fetch comrades error: $e');
      _useMockComrades();
    }
  }

  void _useMockComrades() {
    final List<ComradeWithStats> mockComrades = [];
    final mockNames = [
      'KingKopite',
      'BlaugranaLegend',
      'MadridistaCR7',
      'RedDevil7',
      'Gunner4Life'
    ];
    final mockNicknames = [
      'The Scouser',
      'Catalan Giant',
      'White Knight',
      'Manchester Prince',
      'Cannon King'
    ];

    for (int i = 0; i < mockNames.length; i++) {
      mockComrades.add(ComradeWithStats(
        id: 'mock_$i',
        username: mockNames[i],
        nickname: mockNicknames[i],
        clubFan: 'Football Fan',
        countryFan: 'World',
        isComrade: true,
        totalPoints: 100 - i * 15,
        accuracyPercentage: 80 - i * 5,
        correctVotes: 20 - i * 2,
        totalVotes: 25 - i * 2,
        currentStreak: 5 - i,
        bestStreak: 10 - i,
        isOnline: i % 2 == 0,
        rank: i + 1,
      ));
    }
    setState(() {
      _comrades = mockComrades;
      _filteredComrades = mockComrades;
      _isLoadingLeaderboard = false;
    });
  }

  Map<String, String> _headers() {
    final h = {'Content-Type': 'application/json'};
    if (widget.authToken != null && widget.authToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer ${widget.authToken}';
    }
    return h;
  }

  // ==========================================================================
  // WITHDRAW CASH BUTTON HANDLER
  // ==========================================================================
  Future<void> _withdrawCash() async {
    final channelName = widget.userChannels[_currentChannelIndex].name;
    final stats = _groupStats[channelName] ?? _groupStats.values.first;
    final balance = stats['balance'] as double? ?? 0.0;

    if (balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text('Insufficient balance for withdrawal'),
          backgroundColor: FanColors.away,
        ),
      );
      return;
    }

    setState(() => _isWithdrawing = true);
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() => _isWithdrawing = false);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: FanColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FanRadius.lg),
            side:  BorderSide(color: FanColors.border),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: FanColors.secondary, size: 28),
              const SizedBox(width: 12),
              const Text('Withdrawal Requested'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Amount: \$${balance.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'From: $channelName',
                style: FanTypography.caption,
              ),
              const SizedBox(height: 12),
              const Text(
                'Your withdrawal request has been submitted. Funds will be processed within 3-5 business days.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close',
                  style: TextStyle(color: FanColors.textSecondary)),
            ),
          ],
        ),
      );
    }
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    final currentChannel = widget.userChannels[_currentChannelIndex];
    final stats = _groupStats[currentChannel.name] ?? _groupStats.values.first;
    final balance = stats['balance'] as double? ?? 0.0;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: FanColors.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(FanRadius.lg),
              ),
            ),
            child: Column(
              children: [
                _buildHandle(),
                _buildHeader(balance),
                _buildSwipeableChannelSelector(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildStatsGrid(stats),
                        const SizedBox(height: 16),
                        _buildLeaderboardHeader(),
                        _buildLeaderboardList(),
                        const SizedBox(height: 20),
                      ],
                    ),
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: FanColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );

  Widget _buildHeader(double balance) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FanColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.dashboard, size: 20, color: FanColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin Dashboard',
                    style: FanTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Group analytics & leaderboard',
                    style: FanTypography.caption.copyWith(
                      color: FanColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // WITHDRAW BUTTON - Pure, no background
            GestureDetector(
              onTap: _isWithdrawing ? null : _withdrawCash,
              child: Row(
                children: [
                  if (_isWithdrawing)
                     SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: FanColors.secondary,
                      ),
                    )
                  else
                    Icon(
                      Icons.account_balance_wallet,
                      size: 18,
                      color: balance > 0
                          ? FanColors.secondary
                          : FanColors.textTertiary,
                    ),
                  const SizedBox(width: 4),
                  Text(
                    _isWithdrawing ? '' : '\$${balance.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: balance > 0
                          ? FanColors.secondary
                          : FanColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: widget.onClose,
              child:
                  Icon(Icons.close, size: 20, color: FanColors.textSecondary),
            ),
          ],
        ),
      );

  // Swipeable channel selector - spread equally
  Widget _buildSwipeableChannelSelector() {
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: PageView.builder(
            controller: _channelPageController,
            onPageChanged: (index) {
              setState(() {
                _currentChannelIndex = index;
              });
              _loadLeaderboardData(); // Refresh leaderboard for new channel
            },
            itemCount: widget.userChannels.length,
            itemBuilder: (context, index) {
              final channel = widget.userChannels[index];
              return Center(
                child: Text(
                  channel.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: FanColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              );
            },
          ),
        ),
        // Page indicators
        if (widget.userChannels.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.userChannels.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentChannelIndex == index
                        ? FanColors.primary
                        : FanColors.border,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Stats Grid at top
  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 8,
        childAspectRatio: 1.0,
        children: [
          _buildStatTile('${stats['messages']}', 'Messages',
              Icons.chat_bubble_outline, FanColors.primary),
          _buildStatTile('${stats['likes']}', 'Likes', Icons.favorite_border,
              FanColors.away),
          _buildStatTile('${stats['votes']}', 'Votes',
              Icons.how_to_vote_outlined, FanColors.draw),
          _buildStatTile('${stats['members']}', 'Members', Icons.people_outline,
              FanColors.textPrimary),
        ],
      ),
    );
  }

  Widget _buildStatTile(
      String value, String label, IconData icon, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: FanColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: FanColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLeaderboardHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Icon(Icons.emoji_events, size: 16, color: FanColors.secondary),
          const SizedBox(width: 8),
          Text(
            'LEADERBOARD',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: FanColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            '${_filteredComrades.length} comrades',
            style: TextStyle(
              fontSize: 11,
              color: FanColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList() {
    if (_isLoadingLeaderboard && _comrades.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_filteredComrades.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.people_outline,
                  size: 40, color: FanColors.textTertiary),
              const SizedBox(height: 8),
              Text(
                'No comrades found',
                style: TextStyle(fontSize: 12, color: FanColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredComrades.length,
      itemBuilder: (context, index) =>
          _buildLeaderboardRow(_filteredComrades[index]),
    );
  }

  Widget _buildLeaderboardRow(ComradeWithStats comrade) {
    final isTop3 = comrade.rank <= 3;
    Color rankColor;
    IconData? rankIcon;

    if (comrade.rank == 1) {
      rankColor = const Color(0xFFFFD700);
      rankIcon = Icons.emoji_events;
    } else if (comrade.rank == 2) {
      rankColor = Colors.grey.shade400;
      rankIcon = Icons.emoji_events;
    } else if (comrade.rank == 3) {
      rankColor = const Color(0xFFCD7F32);
      rankIcon = Icons.emoji_events;
    } else {
      rankColor = FanColors.textTertiary;
      rankIcon = null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Rank
          Container(
            width: 32,
            alignment: Alignment.center,
            child: rankIcon != null
                ? Icon(rankIcon, size: 18, color: rankColor)
                : Text(
                    '#${comrade.rank}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: rankColor,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  FanColors.primary.withValues(alpha: 0.2),
                  Colors.transparent
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                comrade.nickname[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: FanColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name and info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comrade.nickname,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FanColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '@${comrade.username}',
                  style: TextStyle(
                    fontSize: 10,
                    color: FanColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Points and streak
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${comrade.totalPoints} pts',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: FanColors.primary,
                ),
              ),
              if (comrade.currentStreak > 0)
                Row(
                  children: [
                    Icon(Icons.local_fire_department,
                        size: 10, color: Colors.orange),
                    const SizedBox(width: 2),
                    Text(
                      '${comrade.currentStreak}',
                      style: TextStyle(fontSize: 10, color: Colors.orange),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
