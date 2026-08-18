import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import '../../models/fixture_models.dart';
import '../../services/notification_service.dart';
import "../../pages/fan_Funzy_design.dart";

// ============================================================================
// VOTES ONLY MODAL - VOTE ONLY (No Pledges, No Bets)
// ============================================================================
class VotesOnlyModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final Fixture fixture;
  final String userId;
  final String username;
  final String? authToken;
  final bool isLoggedIn;
  final bool hasUserVoted;
  final String? userVoteSelection;
  final Set<String> comradesList;
  final Map<String, Map<String, String>> comradesVoteMap;

  const VotesOnlyModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.fixture,
    required this.userId,
    required this.username,
    this.authToken,
    required this.isLoggedIn,
    required this.hasUserVoted,
    this.userVoteSelection,
    required this.comradesList,
    this.comradesVoteMap = const {},
  });

  @override
  State<VotesOnlyModal> createState() => _VotesOnlyModalState();
}

class _VotesOnlyModalState extends State<VotesOnlyModal>
    with SingleTickerProviderStateMixin {
  // ==========================================================================
  // STATE
  // ==========================================================================

  List<Voter> _voters = [];
  List<Voter> _filteredVoters = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  bool _isDisposed = false;

  final ScrollController _voterScroll = ScrollController();
  StreamSubscription<Map<String, dynamic>>? _badgeSubscription;

  static const String _api = 'https://clash-api-m5mr.onrender.com/api';
  static const Duration _timeout = Duration(seconds: 15);

  // ==========================================================================
  // INIT
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    _listenToFCMUpdates();
    if (widget.isOpen) {
      _loadVoters();
    }
  }

  @override
  void didUpdateWidget(covariant VotesOnlyModal old) {
    super.didUpdateWidget(old);
    if (widget.isOpen && !old.isOpen) {
      _loadVoters();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _badgeSubscription?.cancel();
    _voterScroll.dispose();
    super.dispose();
  }

  // ==========================================================================
  // DATA LOADING
  // ==========================================================================

  Future<void> _loadVoters() async {
    setState(() => _isLoading = true);

    try {
      final response = await http
          .get(
            Uri.parse('$_api/games/fixture/${widget.fixture.matchId}/voters'),
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
              if (widget.comradesList.contains(uid) || uid == widget.userId) {
                voters.add(
                  Voter(
                    userId: uid,
                    username: uname,
                    selection: sel,
                    isComrade: widget.comradesList.contains(uid),
                    votedAt: DateTime.now(),
                  ),
                );
              }
            }
          }

          voters.sort((a, b) {
            if (a.userId == widget.userId) return -1;
            if (b.userId == widget.userId) return 1;
            return a.username.compareTo(b.username);
          });

          setState(() {
            _voters = voters;
            _applyFilter();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading voters: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================================================
  // SHARE
  // ==========================================================================

  void _shareChannel() {
    final matchName =
        '${widget.fixture.homeTeam} vs ${widget.fixture.awayTeam}';
    final message = '⚔️ Join the voting on Funzy!\n\n'
        '📊 Vote on: $matchName\n'
        '🏆 ${widget.fixture.league}\n\n'
        'Download the app and vote now!';

    Share.share(message, subject: 'Funzy - $matchName');
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

  void _applyFilter() {
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

  String _initials(String name) =>
      name.isNotEmpty ? name[0].toUpperCase() : 'U';

  String _displayVote(String sel) {
    if (sel == 'home_team') return widget.fixture.homeTeam;
    if (sel == 'away_team') return widget.fixture.awayTeam;
    if (sel == 'draw') return 'Draw';
    return sel;
  }

  Color _getVoteColor(String sel) {
    switch (sel) {
      case 'home_team':
        return FanColors.primary;
      case 'away_team':
        return const Color(0xFF2563EB);
      case 'draw':
        return const Color(0xFF7F77DD);
      default:
        return FanColors.textSecondary;
    }
  }

  Color _getVoteBg(String sel) {
    return _getVoteColor(sel).withValues(alpha: 0.1);
  }

  void _listenToFCMUpdates() {
    _badgeSubscription = NotificationService.badgeStream.listen((event) {
      if (!widget.isOpen || !mounted) return;
      final eventFixtureId = event['fixture_id'] as String?;
      if (eventFixtureId == widget.fixture.matchId) {
        _loadVoters();
      }
    });
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    final mq = MediaQuery.of(context);

    return Stack(
      children: [
        // Backdrop
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),
        ),

        // Sheet
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: mq.size.height * 0.80,
            decoration: BoxDecoration(
              color: FanColors.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(FanRadius.lg),
              ),
            ),
            child: Column(
              children: [
                _buildHandle(),
                _buildHeader(),
                _buildVoteSummary(),
                _buildFilterChips(),
                Expanded(
                  child: _buildVotersList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // BUILD - HANDLE
  // ==========================================================================

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

  // ==========================================================================
  // BUILD - HEADER
  // ==========================================================================

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FanColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  Icon(Icons.how_to_vote, size: 20, color: FanColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Votes',
                    style: FanTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.fixture.homeTeam} vs ${widget.fixture.awayTeam}',
                    style: FanTypography.tag.copyWith(
                      color: FanColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Share button
            GestureDetector(
              onTap: _shareChannel,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: FanColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: FanColors.border.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.share, size: 14, color: FanColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'SHARE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: FanColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  // ==========================================================================
  // BUILD - VOTE SUMMARY
  // ==========================================================================

  Widget _buildVoteSummary() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: FanColors.surface,
          borderRadius: BorderRadius.circular(FanRadius.md),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildVoteStat(
                  label: widget.fixture.homeTeam,
                  count: _voteStats.homeCount,
                  percentage: _voteStats.homePercentage,
                  color: FanColors.primary,
                ),
                const SizedBox(width: 8),
                _buildVoteStat(
                  label: 'Draw',
                  count: _voteStats.drawCount,
                  percentage: _voteStats.drawPercentage,
                  color: const Color(0xFF7F77DD),
                ),
                const SizedBox(width: 8),
                _buildVoteStat(
                  label: widget.fixture.awayTeam,
                  count: _voteStats.awayCount,
                  percentage: _voteStats.awayPercentage,
                  color: const Color(0xFF2563EB),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
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
                              child: Container(color: FanColors.primary),
                            ),
                          if (_voteStats.drawCount > 0)
                            Flexible(
                              flex: _voteStats.drawPercentage
                                  .round()
                                  .clamp(1, 100),
                              child: Container(color: const Color(0xFF7F77DD)),
                            ),
                          if (_voteStats.awayCount > 0)
                            Flexible(
                              flex: _voteStats.awayPercentage
                                  .round()
                                  .clamp(1, 100),
                              child: Container(color: const Color(0xFF2563EB)),
                            ),
                        ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildVoteStat({
    required String label,
    required int count,
    required double percentage,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: FanTypography.body.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: FanTypography.tag.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${percentage.toStringAsFixed(0)}%',
              style:
                  TextStyle(fontSize: 8, color: color.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD - FILTER CHIPS
  // ==========================================================================

  Widget _buildFilterChips() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            _buildFilterChip('All', 'all', _voteStats.total),
            const SizedBox(width: 4),
            _buildFilterChip(
              widget.fixture.homeTeam,
              'home',
              _voteStats.homeCount,
              color: FanColors.primary,
            ),
            const SizedBox(width: 4),
            _buildFilterChip(
              'Draw',
              'draw',
              _voteStats.drawCount,
              color: const Color(0xFF7F77DD),
            ),
            const SizedBox(width: 4),
            _buildFilterChip(
              widget.fixture.awayTeam,
              'away',
              _voteStats.awayCount,
              color: const Color(0xFF2563EB),
            ),
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
        _applyFilter();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : chipColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: FanTypography.tag.copyWith(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : chipColor,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 3),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.8)
                      : chipColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD - VOTERS LIST
  // ==========================================================================

  Widget _buildVotersList() {
    if (_isLoading && _voters.isEmpty) {
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
            Text('Loading votes...',
                style: TextStyle(fontSize: 11, color: FanColors.textSecondary)),
          ],
        ),
      );
    }

    if (_filteredVoters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.how_to_vote_outlined, size: 40, color: FanColors.border),
            const SizedBox(height: 12),
            Text(
              _selectedFilter == 'all'
                  ? 'No votes yet'
                  : 'No votes for this selection',
              style: FanTypography.body
                  .copyWith(color: FanColors.textSecondary, fontSize: 13),
            ),
            if (_selectedFilter != 'all')
              GestureDetector(
                onTap: () => setState(() {
                  _selectedFilter = 'all';
                  _applyFilter();
                }),
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: FanColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Show all votes',
                    style: FanTypography.tag.copyWith(
                      color: FanColors.primary,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _voterScroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: _filteredVoters.length,
      itemBuilder: (context, index) {
        final voter = _filteredVoters[index];
        final isMe = voter.userId == widget.userId;
        return _buildVoterCard(voter, isMe);
      },
    );
  }

  Widget _buildVoterCard(Voter voter, bool isMe) {
    final voteColor = _getVoteColor(voter.selection);
    final voteBg = _getVoteBg(voter.selection);
    final voteDisplay = _displayVote(voter.selection);

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: voteBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _initials(voter.username),
                      style: FanTypography.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: voteColor,
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
                            isMe ? 'You' : voter.username,
                            style: FanTypography.body.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              color: isMe
                                  ? FanColors.primary
                                  : FanColors.textPrimary,
                            ),
                          ),
                          if (voter.isComrade && !isMe) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: FanColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'comrade',
                                style: TextStyle(
                                    fontSize: 7,
                                    color: FanColors.primary,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Voted for $voteDisplay',
                        style: TextStyle(
                            fontSize: 9, color: FanColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: voteBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    voteDisplay,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: voteColor),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Divider(
              color: FanColors.border.withValues(alpha: 0.2),
              height: 0.5,
              thickness: 0.5,
            ),
          ),
        ],
      ),
    );
  }
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
