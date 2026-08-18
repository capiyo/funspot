// modals/Funzy/swipeable_aftermatch_review_modal.dart
//
// AFTERMATCH REVIEW — Pitch Light design system
// Shows match results with win/loss indicators for:
// - Votes (who voted correctly)
// - Pledges (who won/lost money)
// - Bets (who won the bet)
// - Sub-Fixtures (each market result)
// ----------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import '../../models/fixture_models.dart';
import '../../models/aftermatch_models.dart';
import '../../pages/fan_Funzy_design.dart';
import '../../services/toast_helper.dart';
import '../../main.dart'; // AppCache

// ============================================================================
// AFTERMATCH REVIEW MODAL
// ============================================================================

class SwipeableAftermatchReviewModal extends StatefulWidget {
  final Fixture fixture;
  final String userId;
  final String username;
  final String? authToken;
  final String channelId;
  final bool isLoggedIn;
  final bool showPledgesTab;      // ADD
  final bool showBetsTab;         // ADD
  final bool showSubFixturesTab;  

  const SwipeableAftermatchReviewModal({
    super.key,
    required this.fixture,
    required this.userId,
    required this.username,
    this.authToken,
    required this.channelId,
    required this.isLoggedIn,
    this.showPledgesTab = true,      // ADD
    this.showBetsTab = true,         // ADD
    this.showSubFixturesTab = true, 
  });

  @override
  State<SwipeableAftermatchReviewModal> createState() =>
      _SwipeableAftermatchReviewModalState();
}

class _SwipeableAftermatchReviewModalState
    extends State<SwipeableAftermatchReviewModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  // Data state
  AftermatchData? _aftermatchData;
  bool _isLoading = true;
  String? _error;

  // Voters
  List<AftermatchVoter> _voters = [];
  List<AftermatchVoter> _filteredVoters = [];
  String _selectedFilter = 'all';

  // Pledges
  List<AftermatchPledge> _pledges = [];

  // Bets
  List<AftermatchBet> _bets = [];
  int _currentBetIndex = 0;
  final PageController _betPageController = PageController();

  // Sub-fixtures
  List<Map<String, dynamic>> _subFixtures = [];
  final Map<String, bool> _expandedSubFixtures = {};
  final Map<String, String> _subFixtureFilters = {};

  String? _homeScore;
  String? _awayScore;
  String? _winner;

  // ==========================================================================
  // GETTERS
  // ==========================================================================

   // Votes, Pledges, Bets, Sub-Fixtures
 List<String> get _tabLabels {
    final labels = <String>['Votes'];
    if (widget.showPledgesTab) labels.add('Pledges');
    if (widget.showBetsTab) labels.add('Bets');
    if (widget.showSubFixturesTab) labels.add('Sub-Fixtures');
    return labels;
  }

  int get _tabCount => _tabLabels.length;

  String get _matchTitle =>
      '${widget.fixture.homeTeam} vs ${widget.fixture.awayTeam}';

  // ==========================================================================
  // INIT
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: _tabCount, vsync: this, initialIndex: 0);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _selectedTab = _tabController.index);
      }
    });

    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _betPageController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // DATA LOADING
  // ==========================================================================

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Check if we have cached aftermatch data
      final cachedData = AppCache.getAftermatchData(widget.fixture.matchId!);

      if (cachedData != null) {
        _aftermatchData = cachedData;
        _processData(cachedData);
        setState(() => _isLoading = false);

        // Refresh in background if data is stale (> 5 min)
        if (DateTime.now().difference(cachedData.lastUpdated).inMinutes > 5) {
          _fetchFreshData();
        }
        return;
      }

      // 2. No cache - fetch from API
      await _fetchFreshData();
    } catch (e) {
      setState(() {
        _error = 'Failed to load match review: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchFreshData() async {
    try {
      final data = await AppCache.fetchAftermatchData(
        widget.fixture.matchId!,
        channelId: widget.channelId,
        authToken: widget.authToken,
      );

      if (data != null && mounted) {
        _aftermatchData = data;
        _processData(data);
        setState(() => _isLoading = false);
      } else {
        setState(() {
          _error = 'No aftermatch data available';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching data: $e';
        _isLoading = false;
      });
    }
  }

  void _processData(AftermatchData data) {
    // Fixture only has scores as int? — convert to String for display
    _homeScore = widget.fixture.homeScore?.toString() ?? data.homeScore;
    _awayScore = widget.fixture.awayScore?.toString() ?? data.awayScore;

    // Don't use widget.fixture.winner (it's team-name/'Draw', not 'home'/'away'/'draw')
    // Derive the 'home'/'away'/'draw' selection code straight from the scores or backend data
    if (data.winner != null) {
      _winner = data.winner;
    } else if (widget.fixture.hasScores) {
      final hs = widget.fixture.homeScore!;
      final as_ = widget.fixture.awayScore!;
      _winner = hs > as_ ? 'home' : (as_ > hs ? 'away' : 'draw');
    } else {
      _winner = null;
    }

    // Process voters with result
    _voters = data.voters.map((v) {
      final voter = AftermatchVoter.fromJson(v);
      // Calculate if voter won based on match result
      if (_winner != null && voter.selection.isNotEmpty) {
        voter.result = _winner == voter.selection ? 'won' : 'lost';
      }
      return voter;
    }).toList();
    _filteredVoters = List.from(_voters);

    // Process pledges with result
    _pledges = data.pledges.map((p) {
      final pledge = AftermatchPledge.fromJson(p);
      // Set result based on selection vs match winner
      if (_winner != null && pledge.selection.isNotEmpty) {
        pledge.result = _winner == pledge.selection ? 'won' : 'lost';
      }
      return pledge;
    }).toList();

    // Process bets
    _bets = data.bets.map((b) => AftermatchBet.fromJson(b)).toList();

    // Process sub-fixtures
    _subFixtures = data.subFixtures;
    for (var market in _subFixtures) {
      final id = market['id']?.toString() ?? market['_id']?.toString() ?? '';
      _expandedSubFixtures[id] = false;
      _subFixtureFilters[id] = 'all';
    }
  }
  // ==========================================================================
  // SHARE
  // ==========================================================================

  void _shareResults() {
  final resultText = _winner != null
      ? '🏆 Result: ${_homeScore ?? '?'} - ${_awayScore ?? '?'}'
      : '⏳ Match Pending';

  final voteStats = _getVoteStats();
  final totalVotes = _voters.length;
  final correctVotes = _voters.where((v) => v.isWinner).length;

  final buffer = StringBuffer()
    ..writeln('⚔️ Match Review: $_matchTitle')
    ..writeln()
    ..writeln(resultText)
    ..writeln()
    ..writeln('📊 Votes: $totalVotes total')
    ..writeln('✅ Correct: $correctVotes')
    ..writeln('❌ Incorrect: ${totalVotes - correctVotes}')
    ..writeln('🏠 Home: ${voteStats['home']} votes')
    ..writeln('🤝 Draw: ${voteStats['draw']} votes')
    ..writeln('✈️ Away: ${voteStats['away']} votes');

  if (widget.showPledgesTab) {
    buffer..writeln()..writeln('💰 Pledges: ${_pledges.length}');
  }
  if (widget.showBetsTab) {
    buffer..writeln()..writeln('🏅 Bets: ${_bets.length}');
  }

  buffer..writeln()..write('📱 Funzy - Vote, Pledge & Bet!');

  Share.share(buffer.toString(), subject: 'Funzy Match Review - $_matchTitle');
}
  Map<String, int> _getVoteStats() {
    int home = 0, away = 0, draw = 0;
    for (var v in _voters) {
      if (v.selection == 'home' || v.selection == 'home_team')
        home++;
      else if (v.selection == 'away' || v.selection == 'away_team')
        away++;
      else if (v.selection == 'draw') draw++;
    }
    return {'home': home, 'away': away, 'draw': draw};
  }

  // ==========================================================================
  // UI BUILDERS
  // ==========================================================================

  Widget _buildHandleBar() => Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        width: 32,
        height: 3,
        decoration: BoxDecoration(
          color: FanColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  FanColors.primary.withOpacity(0.2),
                  FanColors.primary.withOpacity(0.06)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.emoji_events_rounded,
                size: 16, color: FanColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Match Review',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: FanColors.textPrimary,
                  ),
                ),
                Text(
                  _matchTitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: FanColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(5),
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
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: FanColors.surfaceSunken,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FanColors.border, width: 0.5),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicator: BoxDecoration(
          color: FanColors.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: FanShadows.subtle,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: FanColors.textPrimary,
        unselectedLabelColor: FanColors.textTertiary,
        labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
        tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
      ),
    );
  }

  // ==========================================================================
  // RESULT BANNER
  // ==========================================================================

  Widget _buildResultBanner() {
    final isSettled = _winner != null;
    final color = isSettled
        ? (_winner == 'home'
            ? FanColors.primary
            : _winner == 'away'
                ? FanColors.away
                : FanColors.draw)
        : FanColors.textTertiary;

    String label;
    if (_winner == null) {
      label = '⏳ Match Pending';
    } else if (_winner == 'home') {
      label = '🏠 ${widget.fixture.homeTeam} Won!';
    } else if (_winner == 'away') {
      label = '✈️ ${widget.fixture.awayTeam} Won!';
    } else {
      label = '🤝 Draw!';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _winner != null ? Icons.emoji_events_rounded : Icons.timer_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${_homeScore ?? '?'} - ${_awayScore ?? '?'}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // VOTES TAB
  // ==========================================================================

  Widget _buildVotesTab() {
    final stats = _getVoteStats();
    final total = _voters.length;
    final correct = _voters.where((v) => v.isWinner).length;
    final accuracy =
        total > 0 ? (correct / total * 100).toStringAsFixed(0) : '0';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
          child: Row(
            children: [
              _buildStatChip('Total', total, FanColors.textPrimary),
              const SizedBox(width: 6),
              _buildStatChip('✅ Won', correct, FanColors.primary),
              const SizedBox(width: 6),
              _buildStatChip(
                  '🎯 $accuracy%', total > 0 ? null : 0, FanColors.draw),
              const Spacer(),
              Text(
                'Filter:',
                style: TextStyle(fontSize: 8, color: FanColors.textTertiary),
              ),
              const SizedBox(width: 4),
              _buildFilterChip('All', 'all',
                  stats['home']! + stats['away']! + stats['draw']!),
              _buildFilterChip('🏠', 'home', stats['home']!),
              _buildFilterChip('🤝', 'draw', stats['draw']!),
              _buildFilterChip('✈️', 'away', stats['away']!),
            ],
          ),
        ),
        Expanded(child: _buildVotersList()),
      ],
    );
  }

  Widget _buildStatChip(String label, int? count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 2),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filter, int count) {
    final isSelected = _selectedFilter == filter;
    final color = isSelected ? FanColors.primary : FanColors.textTertiary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
          _applyVoterFilter();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        margin: const EdgeInsets.only(left: 2),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? color : FanColors.border.withOpacity(0.3),
            width: 0.5,
          ),
        ),
        child: Text(
          '$label $count',
          style: TextStyle(
            fontSize: 7,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? color : FanColors.textTertiary,
          ),
        ),
      ),
    );
  }

  void _applyVoterFilter() {
    if (_selectedFilter == 'all') {
      _filteredVoters = List.from(_voters);
      return;
    }
    _filteredVoters =
        _voters.where((v) => v.selection == _selectedFilter).toList();
  }

  Widget _buildVotersList() {
    if (_voters.isEmpty) {
      return _emptyState(
        icon: Icons.how_to_vote_outlined,
        label: 'No votes recorded',
        sublabel: 'Be the first to vote on this match',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      itemCount: _filteredVoters.length,
      itemBuilder: (context, index) {
        final voter = _filteredVoters[index];
        final isMe = voter.userId == widget.userId;

        return _buildVoterTile(voter, isMe);
      },
    );
  }

  Widget _buildVoterTile(AftermatchVoter voter, bool isMe) {
    final selectionColor = _getSelectionColor(voter.selection);
    final selectionDisplay = _getDisplayName(voter.selection);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isMe ? FanColors.primaryDim : FanColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isMe ? FanColors.borderActive : FanColors.border.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          _Avatar(
            name: isMe ? 'You' : voter.userName,
            color: voter.isWinner ? FanColors.primary : selectionColor,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isMe ? 'You' : voter.userName,
                      style: TextStyle(
                        fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 10,
                        color: isMe ? FanColors.primary : FanColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (voter.isComrade && !isMe)
                      _Badge(
                        label: 'comrade',
                        color: FanColors.primary,
                      ),
                    if (voter.isWinner)
                      _Badge(
                        label: '✅ Won',
                        color: FanColors.primary,
                        icon: Icons.check_circle,
                      )
                    else if (voter.isLoser)
                      _Badge(
                        label: '❌ Lost',
                        color: FanColors.away,
                        icon: Icons.close,
                      ),
                  ],
                ),
                Text(
                  'Voted $selectionDisplay',
                  style: TextStyle(
                    fontSize: 8.5,
                    color: selectionColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: voter.resultColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              voter.resultLabel,
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w600,
                color: voter.resultColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PLEDGES TAB
  // ==========================================================================

  Widget _buildPledgesTab() {
    final totalPledged = _pledges.fold<double>(0, (sum, p) => sum + p.amount);
    final totalWon = _pledges
        .where((p) => p.isWinner)
        .fold<double>(0, (sum, p) => sum + (p.payout ?? p.amount * 2));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
          child: Row(
            children: [
              _buildStatChip(
                  '💰 Total', totalPledged.toInt(), FanColors.primary),
              const SizedBox(width: 6),
              _buildStatChip('✅ Won', _pledges.where((p) => p.isWinner).length,
                  FanColors.primary),
              const SizedBox(width: 6),
              _buildStatChip('💸 Payout', totalWon.toInt(), FanColors.draw),
              const Spacer(),
              Text(
                '${_pledges.length} pledges',
                style: TextStyle(fontSize: 8, color: FanColors.textTertiary),
              ),
            ],
          ),
        ),
        Expanded(child: _buildPledgesList()),
      ],
    );
  }

  Widget _buildPledgesList() {
    if (_pledges.isEmpty) {
      return _emptyState(
        icon: Icons.attach_money,
        label: 'No pledges',
        sublabel: 'No one pledged on this match',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      itemCount: _pledges.length,
      itemBuilder: (context, index) {
        final pledge = _pledges[index];
        final isMe = pledge.userId == widget.userId;

        return _buildPledgeTile(pledge, isMe);
      },
    );
  }

  Widget _buildPledgeTile(AftermatchPledge pledge, bool isMe) {
    final selectionColor = _getSelectionColor(pledge.selection);
    final selectionDisplay = _getDisplayName(pledge.selection);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isMe ? FanColors.primaryDim : FanColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isMe ? FanColors.borderActive : FanColors.border.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          _Avatar(
            name: isMe ? 'You' : pledge.userName,
            color: pledge.isWinner ? FanColors.primary : selectionColor,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isMe ? 'You' : pledge.userName,
                      style: TextStyle(
                        fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 10,
                        color: isMe ? FanColors.primary : FanColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (pledge.isWinner)
                      _Badge(
                        label: '✅ Won',
                        color: FanColors.primary,
                        icon: Icons.check_circle,
                      )
                    else if (pledge.isLoser)
                      _Badge(
                        label: '❌ Lost',
                        color: FanColors.away,
                        icon: Icons.close,
                      ),
                    if (pledge.isOpen)
                      _Badge(
                        label: 'Open',
                        color: FanColors.draw,
                      ),
                  ],
                ),
                Text(
                  'Picked $selectionDisplay · KES ${pledge.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 8.5,
                    color: FanColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: pledge.resultColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  pledge.resultLabel,
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w600,
                    color: pledge.resultColor,
                  ),
                ),
              ),
              if (pledge.payout != null)
                Text(
                  '💸 KES ${pledge.payout!.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 7,
                    color: FanColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BETS TAB
  // ==========================================================================

  Widget _buildBetsTab() {
    if (_bets.isEmpty) {
      return _emptyState(
        icon: Icons.sports_score,
        label: 'No bets',
        sublabel: 'No one placed a bet on this match',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              _buildStatChip('🏅 Total', _bets.length, FanColors.primary),
              const SizedBox(width: 6),
              _buildStatChip('✅ Settled',
                  _bets.where((b) => b.isSettled).length, FanColors.primary),
              const Spacer(),
              Text(
                '${_bets.length} bets',
                style: TextStyle(fontSize: 8, color: FanColors.textTertiary),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _betPageController,
            onPageChanged: (index) => setState(() => _currentBetIndex = index),
            itemCount: _bets.length,
            itemBuilder: (context, index) => _buildBetCard(_bets[index]),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _bets.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentBetIndex == index ? 16 : 6,
                height: 4,
                decoration: BoxDecoration(
                  color: _currentBetIndex == index
                      ? FanColors.primary
                      : FanColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBetCard(AftermatchBet bet) {
    final isStarter = bet.starterId == widget.userId;
    final isFinisher = bet.finisherId == widget.userId;
    final isSettled = bet.isSettled;

    String getPickLabel(String? selection) {
      if (selection == null) return '?';
      return _getDisplayName(selection);
    }

    final starterColor = bet.result == 'starter_won'
        ? FanColors.primary
        : FanColors.textTertiary;
    final finisherColor = bet.result == 'finisher_won'
        ? FanColors.primary
        : FanColors.textTertiary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FanColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: FanColors.border.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: FanColors.primaryDim,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSettled ? Icons.emoji_events : Icons.sports_score,
                      size: 12,
                      color: isSettled
                          ? FanColors.primary
                          : FanColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Bet #${bet.id.substring(0, 8)}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: FanColors.textPrimary,
                    ),
                  ),
                ],
              ),
              _Badge(
                label: isSettled ? 'Settled' : 'Active',
                color: isSettled ? FanColors.primary : FanColors.draw,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _betSideBox(
                  label: isStarter ? 'YOU' : bet.starterName.toUpperCase(),
                  highlight: isStarter || bet.result == 'starter_won',
                  color: starterColor,
                  pick: getPickLabel(bet.starterSelection),
                  amount: bet.starterAmount,
                  isWinner: bet.result == 'starter_won',
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    Text('VS',
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: FanColors.textTertiary)),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                          color: FanColors.primaryDim,
                          borderRadius: BorderRadius.circular(4)),
                      child: Text('KES ${bet.totalPot.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              color: FanColors.primary)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _betSideBox(
                  label: isFinisher
                      ? 'YOU'
                      : (bet.finisherName?.toUpperCase() ?? '?'),
                  highlight: isFinisher || bet.result == 'finisher_won',
                  color: finisherColor,
                  pick: getPickLabel(bet.finisherSelection),
                  amount: bet.finisherAmount,
                  isWinner: bet.result == 'finisher_won',
                ),
              ),
            ],
          ),
          if (isSettled && bet.result != null) ...[
             Divider(color: FanColors.border, height: 4),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    bet.result == 'starter_won' || bet.result == 'finisher_won'
                        ? Icons.emoji_events_rounded
                        : Icons.sports_score_rounded,
                    size: 10,
                    color: bet.resultColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    bet.resultLabel,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: bet.resultColor,
                    ),
                  ),
                  if (bet.winnerPayout != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      '· 💰 KES ${bet.winnerPayout!.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 7,
                        color: FanColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _betSideBox({
    required String label,
    required bool highlight,
    required Color color,
    required String pick,
    double? amount,
    bool isWinner = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isWinner
            ? FanColors.primary.withOpacity(0.06)
            : FanColors.surfaceSunken,
        borderRadius: BorderRadius.circular(4),
        border: isWinner
            ? Border.all(color: FanColors.primary.withOpacity(0.3), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 6,
                  fontWeight: highlight ? FontWeight.w800 : FontWeight.w500,
                  color: highlight ? color : FanColors.textTertiary,
                ),
              ),
              if (isWinner) ...[
                const SizedBox(width: 2),
                Icon(Icons.check_circle, size: 8, color: FanColors.primary),
              ],
            ],
          ),
          const SizedBox(height: 1),
          Text(
            pick,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: isWinner ? FanColors.primary : color,
            ),
          ),
          Text(
            'KES ${amount?.toStringAsFixed(2) ?? '0.00'}',
            style: TextStyle(
              fontSize: 7,
              color: isWinner ? FanColors.primary : FanColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SUB-FIXTURES TAB
  // ==========================================================================

  Widget _buildSubFixturesTab() {
    if (_subFixtures.isEmpty) {
      return _emptyState(
        icon: Icons.casino_rounded,
        label: 'No sub-fixtures',
        sublabel: 'This match has no sub-fixture markets',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      itemCount: _subFixtures.length,
      itemBuilder: (context, index) =>
          _buildSubFixtureCard(_subFixtures[index]),
    );
  }

  Widget _buildSubFixtureCard(Map<String, dynamic> market) {
    final id = market['id']?.toString() ?? market['_id']?.toString() ?? '';
    final marketType = market['marketType']?.toString() ??
        market['market_type']?.toString() ??
        '';
    final options = List<String>.from(market['options'] ?? []);
    final line = (market['line'] as num?)?.toDouble();
    final result = market['result']?.toString();
    final isSettled = result != null;
    final isExpanded = _expandedSubFixtures[id] ?? false;

    // Build outcomes with result
    final outcomes = _getSubFixtureOutcomes(marketType, options, line);
    final title = _getSubFixtureTitle(marketType, line);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FanColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: FanColors.border.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _expandedSubFixtures[id] = !isExpanded;
              });
            },
            child: Row(
              children: [
                Icon(
                  _getSubFixtureIcon(marketType),
                  size: 14,
                  color: isSettled ? FanColors.primary : FanColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: FanColors.textPrimary,
                    ),
                  ),
                ),
                if (isSettled)
                  _Badge(
                    label: '✅ Settled',
                    color: FanColors.primary,
                    icon: Icons.check_circle,
                  )
                else
                  _Badge(
                    label: '⏳ Pending',
                    color: FanColors.draw,
                  ),
                const SizedBox(width: 4),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: FanColors.textTertiary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Outcome chips with result
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: outcomes.map((outcome) {
              final isWinner = result == outcome['key'];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isWinner
                      ? FanColors.primary.withOpacity(0.12)
                      : FanColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isWinner
                        ? FanColors.primary
                        : FanColors.border.withOpacity(0.2),
                    width: isWinner ? 1.5 : 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      outcome['label'] as String,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight:
                            isWinner ? FontWeight.w700 : FontWeight.w400,
                        color: isWinner
                            ? FanColors.primary
                            : FanColors.textSecondary,
                      ),
                    ),
                    if (isWinner) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.check_circle,
                          size: 10, color: FanColors.primary),
                    ],
                    if (result != null &&
                        result == outcome['key'] &&
                        !isWinner) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.close, size: 10, color: FanColors.away),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),

          // Expanded pledges list
          if (isExpanded) ...[
            const SizedBox(height: 8),
             Divider(color: FanColors.border, height: 0.5),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Pledges',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: FanColors.textTertiary,
                  ),
                ),
                const Spacer(),
                // Filter chips for this market
                ..._getSubFixtureFilters(market).map((filter) =>
                    _buildSubFixtureFilterChip(id, filter['label'] as String,
                        filter['key'] as String, filter['count'] as int)),
              ],
            ),
            const SizedBox(height: 4),
            _buildSubFixturePledgesList(id, market),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getSubFixtureOutcomes(
      String marketType, List<String> options, double? line) {
    if (marketType == 'over_under_2_5') {
      return [
        {'key': 'over', 'label': 'Over ${line?.toStringAsFixed(1) ?? '2.5'}'},
        {'key': 'under', 'label': 'Under ${line?.toStringAsFixed(1) ?? '2.5'}'},
      ];
    }
    return options.map((opt) {
      String label = opt;
      if (opt == 'home')
        label = widget.fixture.homeTeam;
      else if (opt == 'away')
        label = widget.fixture.awayTeam;
      else if (opt == 'none') label = 'None';
      return {'key': opt, 'label': label};
    }).toList();
  }

  String _getSubFixtureTitle(String marketType, double? line) {
    switch (marketType) {
      case 'first_goal':
        return 'First Goal';
      case 'first_card':
        return 'First Card';
      case 'first_corner':
        return 'First Corner';
      case 'over_under_2_5':
        return 'Total Goals O/U ${line?.toStringAsFixed(1) ?? '2.5'}';
      default:
        return marketType.replaceAll('_', ' ').toUpperCase();
    }
  }

  IconData _getSubFixtureIcon(String marketType) {
    switch (marketType) {
      case 'first_goal':
        return Icons.sports_soccer;
      case 'first_card':
        return Icons.square_rounded;
      case 'first_corner':
        return Icons.flag_rounded;
      case 'over_under_2_5':
        return Icons.stacked_line_chart_rounded;
      default:
        return Icons.casino_rounded;
    }
  }

  List<Map<String, dynamic>> _getSubFixtureFilters(
      Map<String, dynamic> market) {
    final id = market['id']?.toString() ?? market['_id']?.toString() ?? '';
    final result = market['result']?.toString();
    final outcomes = _getSubFixtureOutcomes(
      market['marketType']?.toString() ?? '',
      List<String>.from(market['options'] ?? []),
      (market['line'] as num?)?.toDouble(),
    );

    final filters = [
      {'label': 'All', 'key': 'all', 'count': 0}
    ];

    // Count pledges for each outcome
    final pledges = market['pledges'] as List? ?? [];
    for (var outcome in outcomes) {
      final key = outcome['key'] as String;
      final count = pledges.where((p) => p['selection'] == key).length;
      filters.add({
        'label': outcome['label'] as String,
        'key': key,
        'count': count,
      });
    }

    return filters;
  }

  Widget _buildSubFixtureFilterChip(
      String marketId, String label, String filter, int count) {
    final isSelected = (_subFixtureFilters[marketId] ?? 'all') == filter;
    final color = isSelected ? FanColors.primary : FanColors.textTertiary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _subFixtureFilters[marketId] = filter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        margin: const EdgeInsets.only(left: 2),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? color : FanColors.border.withOpacity(0.3),
            width: 0.5,
          ),
        ),
        child: Text(
          '$label $count',
          style: TextStyle(
            fontSize: 6,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? color : FanColors.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _buildSubFixturePledgesList(
      String marketId, Map<String, dynamic> market) {
    final filter = _subFixtureFilters[marketId] ?? 'all';
    final pledges = (market['pledges'] as List? ?? [])
        .map((p) => Map<String, dynamic>.from(p))
        .toList();

    final filteredPledges = filter == 'all'
        ? pledges
        : pledges.where((p) => p['selection'] == filter).toList();

    if (filteredPledges.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            'No pledges for this selection',
            style: TextStyle(
              fontSize: 8,
              color: FanColors.textTertiary,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredPledges.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final pledge = filteredPledges[index];
        final isMe = pledge['userId'] == widget.userId;
        final selection = pledge['selection']?.toString() ?? '';
        final amount = (pledge['amount'] as num?)?.toDouble() ?? 0;
        final userName = pledge['userName']?.toString() ??
            pledge['user_name']?.toString() ??
            'Unknown';
        final isWinner = market['result']?.toString() == selection;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: isMe ? FanColors.primaryDim : FanColors.surfaceSunken,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              _Avatar(
                name: isMe ? 'You' : userName,
                color: isWinner ? FanColors.primary : FanColors.textTertiary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isMe ? 'You' : userName,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: isMe ? FontWeight.w600 : FontWeight.w400,
                    color: isMe ? FanColors.primary : FanColors.textPrimary,
                  ),
                ),
              ),
              if (isWinner)
                _Badge(
                  label: '✅',
                  color: FanColors.primary,
                ),
              Text(
                'KES ${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: FanColors.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  Color _getSelectionColor(String selection) {
    if (selection == 'home' || selection == 'home_team')
      return FanColors.primary;
    if (selection == 'away' || selection == 'away_team') return FanColors.away;
    if (selection == 'draw') return FanColors.draw;
    return FanColors.textTertiary;
  }

  String _getDisplayName(String selection) {
    if (selection == 'home' || selection == 'home_team') return 'Home';
    if (selection == 'away' || selection == 'away_team') return 'Away';
    if (selection == 'draw') return 'Draw';
    if (selection == 'over') return 'Over';
    if (selection == 'under') return 'Under';
    if (selection == 'none') return 'None';
    return selection;
  }

  Widget _emptyState({
    required IconData icon,
    required String label,
    String? sublabel,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 32,
            color: FanColors.textTertiary.withOpacity(0.3),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: FanColors.textTertiary,
            ),
          ),
          if (sublabel != null) ...[
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 9,
                color: FanColors.textTertiary.withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // SHARED UI PIECES
  // ==========================================================================

  Widget _Avatar({
    required String name,
    required Color color,
    double size = 28,
  }) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.25), width: 0.5),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _Badge({
    required String label,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      margin: const EdgeInsets.only(left: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 7, color: color),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 6,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // LOADING & ERROR STATES
  // ==========================================================================

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: FanColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading match review...',
            style: TextStyle(
              fontSize: 11,
              color: FanColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: FanColors.away.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to load match review',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: FanColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _error ?? 'Unknown error occurred',
            style: TextStyle(
              fontSize: 10,
              color: FanColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _loadData,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: FanColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BOTTOM BUTTON
  // ==========================================================================

  Widget _buildBottomButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: SafeArea(
        child: GestureDetector(
          onTap: _shareResults,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: FanColors.surfaceSunken,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: FanColors.border, width: 0.5),
            ),
            child:  Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.ios_share_rounded,
                    size: 13,
                    color: FanColors.textSecondary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Share Results',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: FanColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // MAIN BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    if (_isLoading) {
      return Container(
        width: screenWidth,
        height: screenHeight * 0.78,
        decoration: BoxDecoration(
          color: FanColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: _buildLoadingState(),
      );
    }

    if (_error != null) {
      return Container(
        width: screenWidth,
        height: screenHeight * 0.78,
        decoration: BoxDecoration(
          color: FanColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: _buildErrorState(),
      );
    }

    final List<Widget> tabChildren = [
      _buildVotesTab(),
      if (widget.showPledgesTab) _buildPledgesTab(),
      if (widget.showBetsTab) _buildBetsTab(),
      if (widget.showSubFixturesTab) _buildSubFixturesTab(),
    ];

    return Container(
      width: screenWidth,
      height: screenHeight * 0.78,
      decoration: BoxDecoration(
        color: FanColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, -3),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandleBar(),
          _buildHeader(),
          _buildResultBanner(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(),
              children: tabChildren,
            ),
          ),
          _buildBottomButton(),
        ],
      ),
    );
  }
}
