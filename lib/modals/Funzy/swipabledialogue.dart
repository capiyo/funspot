// modals/Funzy/swipeable_vote_pledge_modal.dart
//
// REDESIGN v4 — Pitch Light design system
// Clean, scrollable, swipeable tabs, team names once at top
// Live match = everything disabled
// Channel validation: All actions require a valid channel
// NO DRAW: Voting, pledging, and betting only support Home or Away
// ----------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import '../../models/fixture_models.dart';
import '../../pages/fan_Funzy_design.dart';
import '../../services/toast_helper.dart';
import '../../services/notification_service.dart';
import '../../services/bet_service.dart' as bet_service;
import '../../services/payment_service.dart';

// ============================================================================
// VOTE STATS - No Draw
// ============================================================================
class VoteStats {
  final int homeCount;
  final int awayCount;

  VoteStats({
    required this.homeCount,
    required this.awayCount,
  });

  int get total => homeCount + awayCount;

  double get homePercentage => total > 0 ? (homeCount / total) * 100 : 0;
  double get awayPercentage => total > 0 ? (awayCount / total) * 100 : 0;
}

// ============================================================================
// SUB-FIXTURE MODELS
// ============================================================================

class SubFixtureMarket {
  final String id;
  final String matchId;
  final String marketType;
  final List<String> options;
  final double? line;
  final String status;
  final DateTime? lockAt;
  final Map<String, int> pledgeCounts;
  final Map<String, int> pledgeTotals;
  final String? result;
  final bool isVisible;

  SubFixtureMarket({
    required this.id,
    required this.matchId,
    required this.marketType,
    required this.options,
    this.line,
    required this.status,
    this.lockAt,
    required this.pledgeCounts,
    required this.pledgeTotals,
    this.result,
    this.isVisible = true,
  });

  factory SubFixtureMarket.fromJson(Map<String, dynamic> json) {
    Map<String, int> _intMap(dynamic raw) {
      if (raw is! Map) return {};
      return raw
          .map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
    }

    return SubFixtureMarket(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      matchId: (json['matchId'] ?? json['match_id'] ?? '').toString(),
      marketType: (json['marketType'] ?? json['market_type'] ?? '').toString(),
      options:
          (json['options'] as List? ?? []).map((e) => e.toString()).toList(),
      line: (json['line'] as num?)?.toDouble(),
      status: (json['status'] ?? 'open').toString(),
      lockAt: json['lockAt'] != null
          ? DateTime.tryParse(json['lockAt'].toString())
          : null,
      pledgeCounts: _intMap(json['pledgeCounts']),
      pledgeTotals: _intMap(json['pledgeTotals']),
      result: json['result']?.toString(),
      isVisible: json['isVisible'] ?? true,
    );
  }

  bool get isOpen => status == 'open';
  bool get isSettled => status == 'settled' || status == 'settled';
  bool get isLocked => status == 'locked';

  int get totalPledges => pledgeCounts.values.fold(0, (a, b) => a + b);

  String title(String homeTeam, String awayTeam) {
    switch (marketType) {
      case 'first_goal':
        return 'First Goal';
      case 'first_card':
        return 'First Card';
      case 'first_corner':
        return 'First Corner';
      case 'over_under_2_5':
        return 'Total Goals O/U ${line?.toStringAsFixed(1) ?? "2.5"}';
      default:
        return marketType.replaceAll('_', ' ').toUpperCase();
    }
  }

  IconData get icon {
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
}

// ============================================================================
// SHARED OUTCOME MODEL - NO DRAW
// ============================================================================

class _Outcome {
  final String key;
  final String label;
  final Color color;

  const _Outcome({
    required this.key,
    required this.label,
    required this.color,
  });

  // ALL outcomes - NO DRAW
  static List<_Outcome> matchWinner() => [
        _Outcome(key: 'home', label: 'Home', color: FanColors.primary),
        _Outcome(key: 'away', label: 'Away', color: FanColors.away),
      ];

  static List<_Outcome> twoWay() => [
        _Outcome(key: 'home', label: 'Home', color: FanColors.primary),
        _Outcome(key: 'away', label: 'Away', color: FanColors.away),
      ];

  static List<_Outcome> teamOrNone() => [
        _Outcome(key: 'home', label: 'Home', color: FanColors.primary),
        _Outcome(key: 'away', label: 'Away', color: FanColors.away),
        _Outcome(key: 'none', label: 'None', color: FanColors.textTertiary),
      ];

  static List<_Outcome> overUnder(double line) => [
        _Outcome(
            key: 'over',
            label: 'Over ${line.toStringAsFixed(1)}',
            color: FanColors.primary),
        _Outcome(
            key: 'under',
            label: 'Under ${line.toStringAsFixed(1)}',
            color: FanColors.away),
      ];
}

// ============================================================================
// SHARED UI PIECES - PITCH LIGHT STYLE
// ============================================================================

class _Avatar extends StatelessWidget {
  final String name;
  final Color color;
  final double size;

  const _Avatar({required this.name, required this.color, this.size = 28});

  @override
  Widget build(BuildContext context) {
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
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 8, color: color),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutcomeCard extends StatelessWidget {
  final _Outcome outcome;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isLocked;
  final bool compact;
  final int? count;

  const _OutcomeCard({
    required this.outcome,
    required this.isSelected,
    required this.onTap,
    this.isLocked = false,
    this.compact = false,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final color = outcome.color;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: isLocked ? null : onTap,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: compact ? 6 : 9),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.1) : FanColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? color : FanColors.border.withOpacity(0.3),
                  width: isSelected ? 1.2 : 0.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    outcome.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 9 : 11,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? color : FanColors.textPrimary,
                    ),
                  ),
                  if (count != null)
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: compact ? 8 : 10,
                        fontWeight: FontWeight.w700,
                        color: color.withOpacity(0.75),
                      ),
                    ),
                  if (isLocked && isSelected)
                     Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_circle,
                          size: 10, color: FanColors.primary),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutcomeRow extends StatelessWidget {
  final List<_Outcome> outcomes;
  final String? selected;
  final bool locked;
  final ValueChanged<String>? onSelect;
  final bool compact;
  final Map<String, int>? counts;

  const _OutcomeRow({
    required this.outcomes,
    required this.selected,
    this.locked = false,
    required this.onSelect,
    this.compact = false,
    this.counts,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < outcomes.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 6));
      final outcome = outcomes[i];
      children.add(_OutcomeCard(
        outcome: outcome,
        isSelected: selected == outcome.key,
        isLocked: locked,
        compact: compact,
        count: counts?[outcome.key],
        onTap: onSelect == null ? null : () => onSelect!(outcome.key),
      ));
    }
    return Row(children: children);
  }
}

class _PersonTile extends StatelessWidget {
  final String name;
  final bool isMe;
  final Color accent;
  final String subtitle;
  final List<Widget> badges;
  final Widget trailing;
  final bool highlight;

  const _PersonTile({
    required this.name,
    required this.isMe,
    required this.accent,
    required this.subtitle,
    this.badges = const [],
    required this.trailing,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? FanColors.primaryDim : FanColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? FanColors.borderActive
              : FanColors.border.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          _Avatar(name: name, color: accent, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isMe ? 'You' : name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 10,
                          color:
                              isMe ? FanColors.primary : FanColors.textPrimary,
                        ),
                      ),
                    ),
                    for (final b in badges) ...[const SizedBox(width: 3), b],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 8.5,
                    color: FanColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool loading;
  final VoidCallback? onTap;
  final bool small;

  const _PillButton({
    required this.label,
    this.icon,
    required this.color,
    this.loading = false,
    required this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null || loading;
    return Opacity(
      opacity: disabled && !loading ? 0.5 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: small ? 8 : 12, vertical: small ? 4 : 7),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: loading
              ? SizedBox(
                  width: small ? 12 : 16,
                  height: small ? 12 : 16,
                  child: const CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: small ? 11 : 14, color: Colors.white),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: small ? 8 : 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _BalanceBar extends StatelessWidget {
  final bool loading;
  final double balance;
  final bool processing;
  final VoidCallback onTopUp;
  final VoidCallback onWithdraw;

  const _BalanceBar({
    required this.loading,
    required this.balance,
    required this.processing,
    required this.onTopUp,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FanColors.primaryDim,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FanColors.borderActive, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_rounded,
              size: 16, color: FanColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              loading
                  ? 'Loading balance…'
                  : 'KES ${balance.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: loading ? FanColors.textTertiary : FanColors.textPrimary,
              ),
            ),
          ),
          _PillButton(
              label: 'Add',
              icon: Icons.add,
              color: FanColors.primary,
              small: true,
              loading: processing,
              onTap: onTopUp),
          const SizedBox(width: 4),
          _PillButton(
              label: 'Withdraw',
              icon: Icons.arrow_downward,
              color: FanColors.away,
              small: true,
              loading: processing,
              onTap: onWithdraw),
        ],
      ),
    );
  }
}

class _StakeInput extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool loading;
  final VoidCallback? onSubmit;

  const _StakeInput({
    required this.controller,
    required this.enabled,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 12, color: FanColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Amount (KES)',
              labelStyle:
                  TextStyle(color: FanColors.textTertiary, fontSize: 10),
              filled: true,
              fillColor: FanColors.surfaceSunken,
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
                borderSide:  BorderSide(color: FanColors.primary),
              ),
              prefixIcon:
                  Icon(Icons.attach_money, color: FanColors.primary, size: 16),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 6),
        _PillButton(
          label: '',
          icon: Icons.send_rounded,
          color: FanColors.primary,
          loading: loading,
          onTap: enabled ? onSubmit : null,
          small: true,
        ),
      ],
    );
  }
}

// ============================================================================
// MAIN MODAL
// ============================================================================
class SwipeableVotePledgeModal extends StatefulWidget {
  final Fixture fixture;
  final String userId;
  final String username;
  final String? authToken;
  final bool isLoggedIn;
  final bool hasUserVoted;
  final String? userVoteSelection;
  final Set<String> comradesList;
  final bool showPledgesTab;
  final bool showSubFixturesTab;
  final bool showBetsTab;
  final String channelId;
  final Future<bool> Function(String) onVote;
  final Future<bool> Function(String, double) onPledge;
  final VoidCallback? onShowJoinGroups;

  const SwipeableVotePledgeModal({
    super.key,
    required this.fixture,
    required this.userId,
    required this.username,
    this.authToken,
    required this.isLoggedIn,
    required this.hasUserVoted,
    this.userVoteSelection,
    required this.comradesList,
    this.showPledgesTab = true,
    this.showSubFixturesTab = true,
    this.showBetsTab = false,
    required this.channelId,
    required this.onVote,
    required this.onPledge,
    this.onShowJoinGroups,
  });

  @override
  State<SwipeableVotePledgeModal> createState() =>
      _SwipeableVotePledgeModalState();
}

class _SwipeableVotePledgeModalState extends State<SwipeableVotePledgeModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  // Vote state
  String? _selectedVoteOption;
  bool _isVoting = false;

  // Sub-fixtures expanded state
  final Map<String, bool> _expandedSubFixtureMarkets = {};
  final Map<String, List<bet_service.SubFixturePledge>> _subFixturePledges = {};
  final Map<String, bool> _subFixturePledgesLoading = {};
  final Map<String, String?> _subFixturePledgesError = {};
  final Map<String, bool> _subFixturePledgesLoaded = {};
  final Map<String, String> _subFixturePledgeFilters = {};

  // Voters state
  List<Voter> _voters = [];
  List<Voter> _filteredVoters = [];
  bool _isLoadingVoters = true;
  String _selectedFilter = 'all';
  final ScrollController _voterScroll = ScrollController();

  // Pledge state (main fixture)
  String? _selectedPledgeOption;
  final TextEditingController _pledgeAmountController = TextEditingController();
  double _userBalance = 0.0;
  bool _isLoadingBalance = true;
  bool _isPledging = false;
  List<Bettor> _pledges = [];
  bool _isLoadingPledges = true;

  // Sub-fixtures state
  List<SubFixtureMarket> _subFixtures = [];
  bool _isLoadingSubFixtures = true;
  String? _subFixturesError;
  final Map<String, String> _subFixtureSelections = {};
  final Map<String, TextEditingController> _subFixtureAmountControllers = {};
  final Set<String> _pledgingSubFixtureIds = {};

  // Bets state
  List<Bet> _bets = [];
  bool _isLoadingBets = true;
  int _currentBetIndex = 0;
  final PageController _betPageController = PageController();

  // STK Push state
  bool _isProcessingPayment = false;

  // Match-pledge state
  String? _selectedMatchOption;
  bool _isMatching = false;

  StreamSubscription<Map<String, dynamic>>? _badgeSubscription;
  Timer? _pollingTimer;

  static const String _api = 'https://clash-api-m5mr.onrender.com/api';
  static const Duration _timeout = Duration(seconds: 15);

  // ==========================================================================
  // GETTERS - SIMPLE BOOLEANS
  // ==========================================================================

  bool get _isLive => widget.fixture.isLive == true;

  bool get _showPledges => widget.showPledgesTab && !_isLive;
  bool get _showSubFixtures => widget.showSubFixturesTab && !_isLive;
  bool get _showBets => widget.showBetsTab && !_isLive;

  int get _tabCount {
    int count = 1; // Votes always visible
    if (_showPledges) count++;
    if (_showSubFixtures) count++;
    if (_showBets) count++;
    return count;
  }

  List<String> get _tabLabels {
    final labels = <String>['Votes'];
    if (_showPledges) labels.add('Pledges');
    if (_showSubFixtures) labels.add('Sub-Fixtures');
    if (_showBets) labels.add('Bets');
    return labels;
  }

  VoteStats get _voteStats {
    int home = 0, away = 0;
    for (var v in _voters) {
      switch (v.selection) {
        case 'home':
        case 'home_team':
          home++;
          break;
        case 'away':
        case 'away_team':
          away++;
          break;
      }
    }
    return VoteStats(homeCount: home, awayCount: away);
  }

  bool get _hasUserPledged => _pledges.any((p) => p.userId == widget.userId);

  List<_Outcome> get _matchWinnerOutcomes => _Outcome.matchWinner();

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
    _selectedTab = 0;

    _fetchUserBalance();
    _loadVoters();
    _loadPledges();
    if (_showSubFixtures) _loadSubFixtures();
    if (_showBets) _loadBets();

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _selectedTab = _tabController.index);
      }
    });

    _listenToFCMUpdates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pledgeAmountController.dispose();
    _betPageController.dispose();
    _voterScroll.dispose();
    for (final c in _subFixtureAmountControllers.values) {
      c.dispose();
    }
    _badgeSubscription?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _listenToFCMUpdates() {
    _badgeSubscription = NotificationService.badgeStream.listen((event) {
      if (!mounted) return;
      final eventFixtureId = event['fixture_id'] as String?;
      if (eventFixtureId == widget.fixture.matchId) {
        _loadVoters();
        _loadPledges();
        if (_showSubFixtures) _loadSubFixtures();
        if (_showBets) _loadBets();
      }
    });
  }

  // ==========================================================================
  // DATA LOADING
  // ==========================================================================

  Map<String, String> _headers() {
    final h = {'Content-Type': 'application/json'};
    if (widget.authToken != null && widget.authToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer ${widget.authToken}';
    }
    return h;
  }

  Future<void> _loadVoters() async {
    setState(() => _isLoadingVoters = true);
    try {
      final url = '$_api/actions/vote/fixture/${widget.fixture.matchId}/voters';
      print('🔍 Fetching voters from: $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: _headers(),
          )
          .timeout(_timeout);

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        print('📊 Decoded data: $data');

        setState(() {
          _voters = (data['voters'] as List? ?? [])
              .map((v) => Voter.fromJson(v))
              .toList();
          _filteredVoters = List.from(_voters);
          _isLoadingVoters = false;
        });
      } else {
        print('❌ Failed to load voters: ${response.statusCode}');
        setState(() => _isLoadingVoters = false);
      }
    } catch (e) {
      print('❌ Error loading voters: $e');
      if (mounted) setState(() => _isLoadingVoters = false);
    }
  }

  Future<void> _loadSubFixturePledges(String marketId) async {
    if (_subFixturePledgesLoaded[marketId] == true) return;
    if (_subFixturePledgesLoading[marketId] == true) return;

    setState(() {
      _subFixturePledgesLoading[marketId] = true;
      _subFixturePledgesError[marketId] = null;
    });

    try {
      final pledges = await bet_service.SubFixtureService.getMarketBets(
        marketId: marketId,
        matchId: widget.fixture.matchId,
        authToken: widget.authToken,
      );

      setState(() {
        _subFixturePledges[marketId] = pledges;
        _subFixturePledgesLoaded[marketId] = true;
        _subFixturePledgesLoading[marketId] = false;
      });
    } catch (e) {
      setState(() {
        _subFixturePledgesLoading[marketId] = false;
        _subFixturePledgesError[marketId] = e.toString();
      });
    }
  }

  void _toggleSubFixtureExpanded(String marketId) {
    setState(() {
      final isExpanded = _expandedSubFixtureMarkets[marketId] ?? false;
      _expandedSubFixtureMarkets[marketId] = !isExpanded;

      if (!isExpanded) {
        _loadSubFixturePledges(marketId);
      }
    });
  }

  String _getSelectionDisplayForSubFixture(
      String selection, SubFixtureMarket market) {
    if (market.marketType == 'over_under_2_5') {
      return selection == 'over'
          ? 'Over ${market.line?.toStringAsFixed(1) ?? "2.5"}'
          : 'Under ${market.line?.toStringAsFixed(1) ?? "2.5"}';
    }

    switch (selection) {
      case 'home':
        return widget.fixture.homeTeam;
      case 'away':
        return widget.fixture.awayTeam;
      case 'none':
        return 'None';
      default:
        return selection;
    }
  }

  Future<void> _loadPledges() async {
    setState(() => _isLoadingPledges = true);
    try {
      final response = await http
          .get(
            Uri.parse(
                '$_api/actions/channel/${widget.channelId}/${widget.fixture.matchId}/pledges'),
            headers: _headers(),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          _pledges = (data['pledges'] as List? ?? [])
              .map((p) => Bettor.fromOpenBet(p))
              .toList();
          _isLoadingPledges = false;
        });

        final userPledge = _pledges.firstWhere(
          (p) => p.userId == widget.userId,
          orElse: () => null as Bettor,
        );
        if (userPledge != null) {
          setState(() {
            _selectedPledgeOption = userPledge.selection;
            _pledgeAmountController.text = userPledge.amount.toString();
          });
        }
      } else {
        setState(() => _isLoadingPledges = false);
      }
    } catch (e) {
      debugPrint('❌ Error loading pledges: $e');
      if (mounted) setState(() => _isLoadingPledges = false);
    }
  }

  Future<void> _loadSubFixtures() async {
    setState(() {
      _isLoadingSubFixtures = true;
      _subFixturesError = null;
    });
    try {
      final response = await http
          .get(
            Uri.parse('$_api/sub_fixtures/markets/${widget.fixture.matchId}'),
            headers: _headers(),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final markets = (data['markets'] as List? ?? [])
            .map((m) => SubFixtureMarket.fromJson(m as Map<String, dynamic>))
            .where((market) => market.isVisible)
            .toList();
        setState(() {
          _subFixtures = markets;
          _isLoadingSubFixtures = false;
        });
        for (final m in markets) {
          _subFixtureAmountControllers.putIfAbsent(
              m.id, () => TextEditingController());
        }
      } else if (response.statusCode == 404) {
        setState(() {
          _subFixtures = [];
          _isLoadingSubFixtures = false;
        });
      } else {
        setState(() {
          _isLoadingSubFixtures = false;
          _subFixturesError = 'Could not load sub-fixtures';
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading sub-fixtures: $e');
      if (mounted) {
        setState(() {
          _isLoadingSubFixtures = false;
          _subFixturesError = 'Could not load sub-fixtures';
        });
      }
    }
  }

  Future<void> _loadBets() async {
    setState(() => _isLoadingBets = true);
    try {
      final response = await http
          .get(
            Uri.parse(
                '$_api/actions/channel/${widget.channelId}/${widget.fixture.matchId}/bettors'),
            headers: _headers(),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          _bets = (data['bettors'] as List? ?? [])
              .map((b) => Bet.fromJson(b))
              .toList();
          _isLoadingBets = false;
        });
      } else {
        setState(() => _isLoadingBets = false);
      }
    } catch (e) {
      debugPrint('❌ Error loading bets: $e');
      if (mounted) setState(() => _isLoadingBets = false);
    }
  }

  Future<void> _fetchUserBalance({bool forceRefresh = false}) async {
    if (!widget.isLoggedIn) {
      setState(() => _isLoadingBalance = false);
      return;
    }

    setState(() => _isLoadingBalance = true);
    try {
      final balance = await PaymentService.getUserBalance(
        userId: widget.userId,
        authToken: widget.authToken,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _userBalance = balance;
        });
        debugPrint('✅ Balance refreshed: $_userBalance');
      }
    } catch (e) {
      debugPrint('❌ Error fetching balance: $e');
    } finally {
      if (mounted) setState(() => _isLoadingBalance = false);
    }
  }

  Future<String> _getUserPhoneNumber() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_api/auth/user/id/${widget.userId}'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['user']['phone']?.toString() ?? '';
        }
      }
      return '';
    } catch (e) {
      debugPrint('❌ Error fetching phone: $e');
      return '';
    }
  }

  // ==========================================================================
  // PLEDGE HANDLING
  // ==========================================================================

  void _handlePledge() async {
    // ✅ CHANNEL VALIDATION: Check if user is in a channel
    if (widget.channelId.isEmpty) {
      ToastHelper.showWarning('Please join a group to pledge');
      Navigator.pop(context);
      widget.onShowJoinGroups?.call();
      return;
    }

    if (_isLive) {
      ToastHelper.showWarning('Betting is disabled during live matches');
      return;
    }

    if (_selectedPledgeOption == null) {
      ToastHelper.showWarning('Please select a pick first');
      return;
    }

    final amount = double.tryParse(_pledgeAmountController.text);
    if (amount == null || amount <= 0) {
      ToastHelper.showWarning('Please enter a valid amount');
      return;
    }

    if (_userBalance < amount) {
      final shortfall = amount - _userBalance;
      ToastHelper.showInfo(
          'Insufficient balance. You need KES ${shortfall.toStringAsFixed(2)} more.');
      _showTopUpDialog(
        onComplete: () async {
          await _fetchUserBalance(forceRefresh: true);
          if (_userBalance >= amount) {
            await _executePledge(_selectedPledgeOption!, amount);
          } else {
            ToastHelper.showError('Balance still insufficient after top up');
          }
        },
      );
      return;
    }

    await _executePledge(_selectedPledgeOption!, amount);
  }

  Future<void> _executePledge(String selection, double amount) async {
    setState(() => _isPledging = true);
    try {
      final success = await widget.onPledge(selection, amount);

      if (success) {
        ToastHelper.showSuccess('Pledge created! 🎉');
        await _fetchUserBalance(forceRefresh: true);
        await _loadPledges();
        if (mounted) Navigator.pop(context);
      } else {
        ToastHelper.showError('Failed to create pledge');
      }
    } catch (e) {
      debugPrint('❌ Pledge error: $e');
      ToastHelper.showError('Network error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isPledging = false);
    }
  }

  // ==========================================================================
  // SUB-FIXTURE PLEDGE HANDLING
  // ==========================================================================

  Future<void> _handleSubFixturePledge(SubFixtureMarket market) async {
    // ✅ CHANNEL VALIDATION: Check if user is in a channel
    if (widget.channelId.isEmpty) {
      ToastHelper.showWarning('Please join a group to pledge');
      Navigator.pop(context);
      widget.onShowJoinGroups?.call();
      return;
    }

    if (_isLive) {
      ToastHelper.showWarning('Betting is disabled during live matches');
      return;
    }

    final selection = _subFixtureSelections[market.id];
    if (selection == null) {
      ToastHelper.showWarning('Please select a pick first');
      return;
    }

    final controller = _subFixtureAmountControllers[market.id];
    final amount = double.tryParse(controller?.text ?? '');
    if (amount == null || amount <= 0) {
      ToastHelper.showWarning('Please enter a valid amount');
      return;
    }

    if (_userBalance < amount) {
      final shortfall = amount - _userBalance;
      ToastHelper.showInfo(
          'Insufficient balance. You need KES ${shortfall.toStringAsFixed(2)} more.');
      _showTopUpDialog(
        onComplete: () async {
          await _fetchUserBalance(forceRefresh: true);
          if (_userBalance >= amount) {
            await _executeSubFixturePledge(market, selection, amount);
          } else {
            ToastHelper.showError('Balance still insufficient after top up');
          }
        },
      );
      return;
    }

    await _executeSubFixturePledge(market, selection, amount);
  }

  Future<void> _executeSubFixturePledge(
      SubFixtureMarket market, String selection, double amount) async {
    if (_pledgingSubFixtureIds.contains(market.id)) {
      return;
    }

    setState(() => _pledgingSubFixtureIds.add(market.id));
    try {
      final response = await http
          .post(
            Uri.parse('$_api/sub_fixtures/sub-fixture/bet'),
            headers: _headers(),
            body: json.encode({
              'match_id': widget.fixture.matchId,
              'market_id': market.id,
              'starter_id': widget.userId,
              'starter_name': widget.username,
              'selection': selection,
              'amount': amount,
            }),
          )
          .timeout(_timeout);

      final data = json.decode(response.body);

      if (data['success'] == true) {
        ToastHelper.showSuccess('Pledge placed! 🎉');
        await _fetchUserBalance(forceRefresh: true);
        await _loadSubFixtures();
        setState(() {
          _subFixtureSelections[market.id] = "";
          _subFixtureAmountControllers[market.id]?.clear();
        });
      } else {
        ToastHelper.showError(data['message'] ?? 'Failed to place pledge');
        if (data['message']?.toString().toLowerCase().contains('balance') ==
            true) {
          await _fetchUserBalance(forceRefresh: true);
        }
      }
    } catch (e) {
      debugPrint('❌ Sub-fixture pledge error: $e');
      ToastHelper.showError('Network error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _pledgingSubFixtureIds.remove(market.id));
      }
    }
  }

  // ==========================================================================
  // STK PUSH PAYMENT - Using PaymentService
  // ==========================================================================

  Future<bool> _initiateSTKPush(
    double amount, {
    String? phoneNumber,
    String? purpose,
  }) async {
    if (_isProcessingPayment) return false;
    setState(() => _isProcessingPayment = true);

    try {
      String phone = phoneNumber ?? '';
      if (phone.isEmpty) phone = await _getUserPhoneNumber();

      if (phone.isEmpty) {
        ToastHelper.showError('Phone number required.');
        setState(() => _isProcessingPayment = false);
        return false;
      }

      final result = await PaymentService.initiateSTKPush(
        userId: widget.userId,
        username: widget.username,
        amount: amount,
        phoneNumber: phone,
        authToken: widget.authToken,
        purpose: purpose ?? 'Top up balance',
        fixtureId: widget.fixture.matchId,
        voteId: widget.userId,
      );

      setState(() => _isProcessingPayment = false);

      if (result.isSuccess) {
        if (result.newBalance != null) {
          setState(() {
            _userBalance = result.newBalance!;
          });
          await TransactionLocalStorage.cacheBalance(result.newBalance!);
        }
        return true;
      } else {
        String errorMessage = result.error ?? 'Payment failed';
        if (errorMessage.contains('still processing')) {
          errorMessage =
              'Payment is still processing. Please check your M-Pesa.';
        }
        ToastHelper.showError(errorMessage);
        return false;
      }
    } catch (e) {
      debugPrint('❌ STK Push error: $e');
      setState(() => _isProcessingPayment = false);
      ToastHelper.showError('Failed to initiate payment');
      return false;
    }
  }

  Future<bool> _processWithdrawal({
    required double amount,
    required String phone,
  }) async {
    setState(() => _isProcessingPayment = true);
    try {
      final result = await PaymentService.initiateB2CPayment(
        userId: widget.userId,
        username: widget.username,
        channelId: widget.channelId,
        amount: amount,
        phoneNumber: phone,
        authToken: widget.authToken,
        remarks: 'User withdrawal',
        occasion: 'Withdrawal',
      );

      setState(() => _isProcessingPayment = false);

      if (result.isSuccess) {
        if (result.newBalance != null) {
          setState(() {
            _userBalance = result.newBalance!;
          });
        }
        ToastHelper.showSuccess(result.message ?? 'Withdrawal successful!');
        return true;
      } else {
        ToastHelper.showError(result.error ?? 'Withdrawal failed');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Withdrawal error: $e');
      ToastHelper.showError('Failed to process withdrawal');
      setState(() => _isProcessingPayment = false);
      return false;
    }
  }

  // ==========================================================================
  // DIALOGS
  // ==========================================================================

  void _showTopUpDialog({VoidCallback? onComplete}) =>
      _showFundsDialog(isWithdraw: false, onComplete: onComplete);

  void _showWithdrawDialog() => _showFundsDialog(isWithdraw: true);

  void _showFundsDialog({required bool isWithdraw, VoidCallback? onComplete}) {
    final amountController = TextEditingController();
    final phoneController = TextEditingController();
    final kind = isWithdraw ? 'withdraw' : 'topup';
    bool useSavedPhone = true;
    String? savedPhone;
    bool isLoading = true;

    _fetchSavedPhone(kind).then((phone) {
      savedPhone = phone;
      if (phone != null && phone.isNotEmpty) {
        phoneController.text = phone;
      }
      isLoading = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          bool isProcessing = false;
          String statusMessage = '';

          if (isLoading) {
            Future.delayed(const Duration(milliseconds: 60), () {
              if (context.mounted) setStateDialog(() {});
            });
          }

          final accent = isWithdraw ? FanColors.away : FanColors.primary;

          return AlertDialog(
            backgroundColor: FanColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side:  BorderSide(color: FanColors.border),
            ),
            title: Row(
              children: [
                Icon(
                  isWithdraw ? Icons.account_balance : Icons.add_circle,
                  color: accent,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  isWithdraw ? 'Withdraw Funds' : 'Top Up Balance',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: FanColors.textPrimary,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: FanColors.surfaceSunken,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: FanColors.border, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          size: 14,
                          color: FanColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Balance: KES ${_userBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: FanColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AbsorbPointer(
                    absorbing: isProcessing,
                    child: Opacity(
                      opacity: isProcessing ? 0.5 : 1.0,
                      child: Column(
                        children: [
                          TextField(
                            controller: amountController,
                            autofocus: !isWithdraw,
                            decoration: const InputDecoration(
                              labelText: 'Amount (KES)',
                              hintText: 'Enter amount',
                              prefixIcon: Icon(Icons.monetization_on),
                            ),
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                                fontSize: 12, color: FanColors.textPrimary),
                          ),
                          const SizedBox(height: 10),
                          if (isWithdraw)
                            TextField(
                              controller: phoneController,
                              enabled: false,
                              decoration: InputDecoration(
                                labelText: 'Registered Phone Number',
                                hintText: 'Loading...',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: Icon(
                                  Icons.check_circle,
                                  color: FanColors.primary,
                                  size: 16,
                                ),
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: FanColors.textSecondary,
                              ),
                            )
                          else
                            TextField(
                              controller: phoneController,
                              enabled: !isProcessing,
                              decoration: InputDecoration(
                                labelText: 'M-Pesa Phone Number',
                                hintText: 'e.g., 0712345678',
                                prefixIcon: const Icon(Icons.phone_android),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.edit, size: 16),
                                  onPressed: () => phoneController.clear(),
                                ),
                              ),
                              keyboardType: TextInputType.phone,
                              style: TextStyle(
                                fontSize: 12,
                                color: FanColors.textPrimary,
                              ),
                            ),
                          const SizedBox(height: 6),
                          if (!isWithdraw)
                            Row(
                              children: [
                                Checkbox(
                                  value: useSavedPhone,
                                  activeColor: FanColors.primary,
                                  onChanged: isProcessing
                                      ? null
                                      : (val) {
                                          setStateDialog(() {
                                            useSavedPhone = val ?? true;
                                            if (useSavedPhone &&
                                                savedPhone != null) {
                                              phoneController.text =
                                                  savedPhone!;
                                            } else {
                                              phoneController.clear();
                                            }
                                          });
                                        },
                                ),
                                Expanded(
                                  child: Text(
                                    'Save this number for future top-ups',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: FanColors.textTertiary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isWithdraw
                                      ? Icons.warning_amber_rounded
                                      : Icons.info_outline,
                                  size: 12,
                                  color: accent,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    isWithdraw
                                        ? 'Withdrawals must use your registered phone number'
                                        : 'Enter any M-Pesa number. You will receive a prompt to enter your PIN.',
                                    style:
                                        TextStyle(fontSize: 9, color: accent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (statusMessage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusMessage.contains('✅')
                            ? FanColors.primaryDim
                            : FanColors.awayDim,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          if (statusMessage.contains('✅'))
                            Icon(Icons.check_circle,
                                size: 14, color: FanColors.primary)
                          else if (statusMessage.contains('❌'))
                            Icon(Icons.error_outline,
                                size: 14, color: FanColors.away)
                          else
                             SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: FanColors.primary,
                              ),
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              statusMessage,
                              style: TextStyle(
                                fontSize: 11,
                                color: statusMessage.contains('✅')
                                    ? FanColors.primary
                                    : FanColors.away,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    isProcessing ? null : () => Navigator.pop(context, false),
                child: Text(
                  isProcessing ? 'Processing...' : 'Cancel',
                  style: TextStyle(
                    color: isProcessing
                        ? FanColors.textTertiary
                        : FanColors.textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: isProcessing
                    ? null
                    : () async {
                        final amountText = amountController.text.trim();
                        final phone = phoneController.text.trim();

                        if (amountText.isEmpty ||
                            double.tryParse(amountText) == null ||
                            double.parse(amountText) <= 0) {
                          ToastHelper.showWarning(
                              'Please enter a valid amount');
                          return;
                        }

                        if (isWithdraw &&
                            (phone.isEmpty || !_isValidPhoneNumber(phone))) {
                          ToastHelper.showWarning(
                              'Please enter a valid phone number');
                          return;
                        }

                        final amount = double.parse(amountText);

                        if (isWithdraw && amount > _userBalance) {
                          ToastHelper.showWarning('Insufficient balance');
                          return;
                        }

                        setStateDialog(() {
                          isProcessing = true;
                          statusMessage =
                              '⏳ Processing... Please check your phone';
                        });

                        try {
                          bool success;

                          if (isWithdraw) {
                            success = await _processWithdrawal(
                              amount: amount,
                              phone: phone,
                            );
                          } else {
                            success = await _initiateSTKPush(
                              amount,
                              phoneNumber: phone,
                              purpose: 'Top up balance',
                            );
                          }

                          if (success) {
                            setStateDialog(() {
                              statusMessage = '✅ Payment successful!';
                            });

                            await Future.delayed(const Duration(seconds: 1));
                            Navigator.pop(context, true);
                            await _fetchUserBalance(forceRefresh: true);
                            ToastHelper.showSuccess(
                                'Balance updated successfully!');
                            onComplete?.call();

                            if (!isWithdraw && useSavedPhone) {
                              await _savePhone(kind, phone);
                            }
                          } else {
                            setStateDialog(() {
                              statusMessage =
                                  '❌ Payment failed. Please try again.';
                              isProcessing = false;
                            });
                          }
                        } catch (e) {
                          setStateDialog(() {
                            statusMessage = '❌ Error: ${e.toString()}';
                            isProcessing = false;
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  minimumSize: const Size(80, 32),
                ),
                child: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isWithdraw ? 'Withdraw' : 'Pay via M-Pesa',
                        style: const TextStyle(fontSize: 11),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showProcessingDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: FanColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FanRadius.lg),
        ),
        title: const Text('Processing Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             CircularProgressIndicator(color: FanColors.primary),
            const SizedBox(height: 12),
            Text(
              'Please check your phone and enter your PIN',
              style: FanTypography.body.copyWith(
                color: FanColors.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This may take up to 3 minutes',
              style: FanTypography.caption.copyWith(
                color: FanColors.textTertiary,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Do not close this dialog while processing',
              style: FanTypography.caption.copyWith(
                color: FanColors.away,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _fetchSavedPhone(String kind) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_api/auth/user/${widget.userId}/$kind-phone'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) return data['phone']?.toString();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching $kind phone: $e');
      return null;
    }
  }

  Future<bool> _savePhone(String kind, String phone) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_api/auth/user/${widget.userId}/$kind-phone'),
            headers: _headers(),
            body: json.encode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error saving $kind phone: $e');
      return false;
    }
  }

  bool _isValidPhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final regex = RegExp(r'^(0|254)?[7-9][0-9]{8}$');
    return regex.hasMatch(cleaned);
  }

  // ==========================================================================
  // VOTE HANDLING
  // ==========================================================================

  void _handleVote() async {
    // ✅ CHANNEL VALIDATION: Check if user is in a channel
    if (widget.channelId.isEmpty) {
      ToastHelper.showWarning('Please join a group to vote');
      Navigator.pop(context);
      widget.onShowJoinGroups?.call();
      return;
    }

    if (_isLive) {
      ToastHelper.showWarning('Voting is disabled during live matches');
      return;
    }

    if (_selectedVoteOption == null || widget.hasUserVoted) return;

    setState(() => _isVoting = true);
    try {
      final success = await widget.onVote(_selectedVoteOption!);
      if (success) {
        ToastHelper.showSuccess('Vote submitted!');
        if (mounted) Navigator.pop(context);
      } else {
        ToastHelper.showError('Vote failed. Please try again.');
      }
    } catch (e) {
      ToastHelper.showError('Vote failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  // ==========================================================================
  // MATCH BET - NO DRAW SUPPORT
  // ==========================================================================

  Future<void> _matchPledge(Bettor pledge) async {
    // ✅ CHANNEL VALIDATION: Check if user is in a channel
    if (widget.channelId.isEmpty) {
      ToastHelper.showWarning('Please join a group to match pledges');
      Navigator.pop(context);
      widget.onShowJoinGroups?.call();
      return;
    }

    if (_isLive) {
      ToastHelper.showWarning('Betting is disabled during live matches');
      return;
    }

    if (_isMatching) return;

    await _fetchUserBalance(forceRefresh: true);

    if (_userBalance < pledge.amount) {
      final shortfall = pledge.amount - _userBalance;

      final shouldTopUp = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: FanColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: FanColors.draw, size: 20),
              const SizedBox(width: 6),
              Text(
                'Insufficient Balance',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: FanColors.textPrimary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FanColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: FanColors.border, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'You need KES ${pledge.amount.toStringAsFixed(2)} to match this pledge',
                        style: TextStyle(
                            fontSize: 12, color: FanColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Your balance: KES ${_userBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 11, color: FanColors.textTertiary)),
                    const SizedBox(height: 2),
                    Text('Shortfall: KES ${shortfall.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 11,
                            color: FanColors.draw,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: FanColors.primaryDim,
                    borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 12, color: FanColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          'Top up the shortfall amount (KES ${shortfall.toStringAsFixed(2)}) to continue',
                          style: TextStyle(
                              fontSize: 9, color: FanColors.textSecondary)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel',
                    style: TextStyle(color: FanColors.textSecondary))),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: FanColors.primary,
                minimumSize: const Size(80, 32),
              ),
              child: const Text('Top Up & Match'),
            ),
          ],
        ),
      );

      if (shouldTopUp != true) return;

      final topUpSuccess =
          await _initiateSTKPush(shortfall, purpose: 'Top up to match pledge');
      if (!topUpSuccess) {
        ToastHelper.showError('Top-up failed. Please try again.');
        return;
      }

      await _fetchUserBalance(forceRefresh: true);
      if (_userBalance < pledge.amount) {
        ToastHelper.showError('Balance still insufficient after top-up');
        return;
      }
    }

    _showMatchConfirmation(pledge);
  }

  // Simplified match confirmation - NO DRAW
  void _showMatchConfirmation(Bettor pledge) {
    final String oppositeSelection;
    final String oppositeTitle;
    final Color oppositeColor;

    if (pledge.selection == 'home' || pledge.selection == 'home_team') {
      oppositeSelection = 'away';
      oppositeTitle = 'Away';
      oppositeColor = FanColors.away;
    } else {
      // Default to home for any other selection (including draw)
      oppositeSelection = 'home';
      oppositeTitle = 'Home';
      oppositeColor = FanColors.primary;
    }

    _selectedMatchOption = oppositeSelection;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: FanColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        title: Row(
          children: [
            Icon(Icons.sports_score, color: FanColors.primary, size: 16),
            const SizedBox(width: 6),
            Text('Match Pledge',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: FanColors.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _matchPledgeSummaryCard(pledge),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: oppositeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: oppositeColor, width: 1.2),
              ),
              child: Center(
                child: Text(oppositeTitle,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: oppositeColor)),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                  color: FanColors.awayDim,
                  borderRadius: BorderRadius.circular(4)),
              child: Row(
                children: [
                  Icon(Icons.block, size: 10, color: FanColors.away),
                  const SizedBox(width: 3),
                  Text('Cannot pick ${pledge.selectionDisplay}',
                      style: TextStyle(fontSize: 8, color: FanColors.away)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(color: FanColors.textSecondary))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _executeMatch(pledge, oppositeSelection);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FanColors.primary,
              minimumSize: const Size(60, 28),
            ),
            child: const Text('Match'),
          ),
        ],
      ),
    );
  }

  Widget _matchPledgeSummaryCard(Bettor pledge) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: FanColors.surfaceSunken,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: FanColors.border, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pledge.userName,
                    style:
                        TextStyle(fontSize: 10, color: FanColors.textPrimary)),
                Text('Picked ${pledge.selectionDisplay}',
                    style: TextStyle(fontSize: 8, color: FanColors.primary)),
              ],
            ),
            Text('KES ${pledge.amount.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: FanColors.primary)),
          ],
        ),
      );

  Future<void> _executeMatch(Bettor pledge, String selection) async {
    setState(() => _isMatching = true);
    try {
      ToastHelper.showInfo('🔄 Matching pledge...');

      final response = await http
          .post(
            Uri.parse('$_api/actions/bet/fill'),
            headers: _headers(),
            body: json.encode({
              'bet_id': pledge.betId,
              'finisher_id': widget.userId,
              'finisher_name': widget.username,
              'finisher_selection': selection,
              'amount': pledge.amount,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (data['success'] == true) {
        ToastHelper.showSuccess('✅ Bet matched successfully! 🎉');
        await _loadPledges();
        await _loadBets();
        await _fetchUserBalance(forceRefresh: true);

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        ToastHelper.showError(data['message'] ?? 'Failed to match bet');
      }
    } catch (e) {
      ToastHelper.showError('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isMatching = false);
    }
  }

  // ==========================================================================
  // SHARE
  // ==========================================================================

  void _shareChannel() {
    final matchName = _matchTitle;
    final message = '⚔️ Join the voting on Funzy!\n\n'
        '📊 Vote on: $matchName\n'
        '🏆 ${widget.fixture.league}\n\n'
        'Download the app and vote now!';

    Share.share(message, subject: 'Funzy - $matchName');
  }

  // ==========================================================================
  // HELPERS - NO DRAW
  // ==========================================================================

  void _applyFilter() {
    final List<Voter> filtered;
    switch (_selectedFilter) {
      case 'home':
        filtered = _voters
            .where((v) => v.selection == 'home_team' || v.selection == 'home')
            .toList();
        break;
      case 'away':
        filtered = _voters
            .where((v) => v.selection == 'away_team' || v.selection == 'away')
            .toList();
        break;
      default:
        filtered = List.from(_voters);
    }
    _filteredVoters = filtered;
  }

  String _displayVote(String sel) {
    if (sel == 'home_team' || sel == 'home') return 'Home';
    if (sel == 'away_team' || sel == 'away') return 'Away';
    return sel;
  }

  Color _getVoteColor(String sel) {
    switch (sel) {
      case 'home_team':
      case 'home':
        return FanColors.primary;
      case 'away_team':
      case 'away':
        return FanColors.away;
      default:
        return FanColors.textTertiary;
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ==========================================================================
  // MATCH TEAM NAMES HEADER
  // ==========================================================================

  Widget _buildMatchHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: FanColors.surface,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: FanColors.border.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: FanColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.fixture.homeTeam,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: FanColors.primary,
              ),
            ),
          ),
           Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'VS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: FanColors.textTertiary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: FanColors.away.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.fixture.awayTeam,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: FanColors.away,
              ),
            ),
          ),
          if (_isLive) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: FanColors.away.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration:  BoxDecoration(
                      color: FanColors.away,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                      color: FanColors.away,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // HEADER / TAB BAR
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
    final tabLabels = _tabLabels;
    final currentLabel =
        _selectedTab < tabLabels.length ? tabLabels[_selectedTab] : 'Votes';
    final icon = currentLabel == 'Votes'
        ? Icons.how_to_vote_rounded
        : currentLabel == 'Pledges'
            ? Icons.attach_money_rounded
            : currentLabel == 'Sub-Fixtures'
                ? Icons.casino_rounded
                : Icons.sports_score_rounded;

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
            child: Icon(icon, size: 16, color: FanColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: FanColors.textPrimary,
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
    if (_tabCount <= 1) return const SizedBox.shrink();

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
        isScrollable: _tabCount > 3,
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
  // LIVE OVERLAY - DISABLED STATE
  // ==========================================================================

  Widget _buildLiveOverlay(Widget child) {
    if (!_isLive) return child;

    return Stack(
      children: [
        child,
        Container(
          color: Colors.black.withOpacity(0.5),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FanColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child:  Icon(
                    Icons.sports_soccer,
                    size: 32,
                    color: FanColors.away,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '⛔ Match is Live',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Voting & betting are disabled',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: FanColors.away,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
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

  // ==========================================================================
  // VOTES TAB - NO DRAW
  // ==========================================================================

  Widget _buildVotesFragment() {
    final isVoted = widget.hasUserVoted;
    final effectiveSelection =
        isVoted ? widget.userVoteSelection : _selectedVoteOption;

    final counts = {
      'home': _voteStats.homeCount,
      'away': _voteStats.awayCount,
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
          child: Column(
            children: [
              _OutcomeRow(
                outcomes: _matchWinnerOutcomes,
                selected: effectiveSelection,
                locked: isVoted || _isLive,
                counts: counts,
                onSelect: (isVoted || _isLive)
                    ? null
                    : (v) => setState(() => _selectedVoteOption = v),
              ),
              if (_selectedVoteOption != null && !isVoted && !_isLive)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: _PillButton(
                      label: 'Confirm Vote',
                      color: FanColors.primary,
                      loading: _isVoting,
                      onTap: _handleVote,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _buildFilterChips(),
        Expanded(child: _buildVotersList()),
      ],
    );
  }

  Widget _buildVoteStat(
      String label, int count, double percentage, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text(count.toString(),
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 7, fontWeight: FontWeight.w600, color: color)),
            Text('${percentage.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 6, color: color.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          children: [
            _buildFilterChip('All', 'all', _voteStats.total, FanColors.primary),
            const SizedBox(width: 3),
            _buildFilterChip(
                'Home', 'home', _voteStats.homeCount, FanColors.primary),
            const SizedBox(width: 3),
            _buildFilterChip(
                'Away', 'away', _voteStats.awayCount, FanColors.away),
          ],
        ),
      );

  Widget _buildFilterChip(String label, String filter, int count, Color color) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedFilter = filter;
        _applyFilter();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? null
              : Border.all(color: color.withOpacity(0.15), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 8,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  color: isSelected ? Colors.white : color),
            ),
            if (count > 0) ...[
              const SizedBox(width: 2),
              Text('$count',
                  style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                      color:
                          isSelected ? Colors.white.withOpacity(0.85) : color)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVotersList() {
    if (_isLoadingVoters && _voters.isEmpty) {
      return _emptyState(spinner: true, label: 'Loading votes…');
    }

    if (_filteredVoters.isEmpty) {
      return _emptyState(
        icon: Icons.how_to_vote_outlined,
        label: _selectedFilter == 'all'
            ? 'No votes yet'
            : 'No votes for this selection',
        actionLabel: _selectedFilter != 'all' ? 'Show all votes' : null,
        onAction: _selectedFilter != 'all'
            ? () => setState(() {
                  _selectedFilter = 'all';
                  _applyFilter();
                })
            : null,
      );
    }

    return ListView.builder(
      controller: _voterScroll,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      itemCount: _filteredVoters.length,
      itemBuilder: (context, index) {
        final voter = _filteredVoters[index];
        final isMe = voter.userId == widget.userId;
        final voteColor = _getVoteColor(voter.selection);
        final voteDisplay = _displayVote(voter.selection);

        return _PersonTile(
          name: voter.userName,
          isMe: isMe,
          accent: voteColor,
          subtitle: 'Voted for $voteDisplay',
          badges: [
            if (voter.isComrade && !isMe)
               _Badge(label: 'comrade', color: FanColors.primary)
          ],
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: voteColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Text(voteDisplay,
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: voteColor)),
          ),
        );
      },
    );
  }

  // ==========================================================================
  // SHARED EMPTY-STATE
  // ==========================================================================

  Widget _emptyState({
    bool spinner = false,
    IconData icon = Icons.info_outline,
    required String label,
    String? sublabel,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (spinner)
             SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: FanColors.primary, strokeWidth: 2))
          else
            Icon(icon,
                size: 32, color: FanColors.textTertiary.withOpacity(0.4)),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(fontSize: 11, color: FanColors.textTertiary)),
          if (sublabel != null) ...[
            const SizedBox(height: 2),
            Text(sublabel,
                style: TextStyle(
                    fontSize: 9,
                    color: FanColors.textTertiary.withOpacity(0.6))),
          ],
          if (actionLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: onAction,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: FanColors.primaryDim,
                      borderRadius: BorderRadius.circular(14)),
                  child: Text(actionLabel,
                      style: TextStyle(
                          color: FanColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 9)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PLEDGES TAB - NO DRAW
  // ==========================================================================

  Widget _buildPledgesFragment() {
    if (!_showPledges) return const SizedBox.shrink();

    final hasUserPledged = _hasUserPledged;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BalanceBar(
            loading: _isLoadingBalance,
            balance: _userBalance,
            processing: _isProcessingPayment,
            onTopUp: _showTopUpDialog,
            onWithdraw: _showWithdrawDialog,
          ),
          const SizedBox(height: 10),
          Text(
            hasUserPledged
                ? '💰 You can pledge multiple times on different picks'
                : 'Select your pick and enter amount to pledge',
            style: TextStyle(fontSize: 9, color: FanColors.textTertiary),
          ),
          const SizedBox(height: 10),
          _OutcomeRow(
            outcomes: _matchWinnerOutcomes,
            selected: _selectedPledgeOption,
            locked: _isLive,
            onSelect: _isLive
                ? null
                : (v) => setState(() => _selectedPledgeOption = v),
          ),
          const SizedBox(height: 10),
          _StakeInput(
            controller: _pledgeAmountController,
            enabled: _selectedPledgeOption != null && !_isLive,
            loading: _isPledging,
            onSubmit: _handlePledge,
          ),
          const SizedBox(height: 10),
           Divider(color: FanColors.border, height: 0.5),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Pledges (${_pledges.length})',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: FanColors.textPrimary)),
              const Spacer(),
              if (_isLoadingPledges)
                 SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: FanColors.primary)),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(child: _buildPledgeList()),
        ],
      ),
    );
  }

  Widget _buildPledgeList() {
    if (_isLoadingPledges) {
      return  Center(
        child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: FanColors.primary)),
      );
    }

    if (_pledges.isEmpty) {
      return _emptyState(
          icon: Icons.attach_money,
          label: 'No pledges yet',
          sublabel: 'Be the first to pledge on this match');
    }

    final isLive = _isLive;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _pledges.length,
      itemBuilder: (context, index) {
        final pledge = _pledges[index];
        final isMe = pledge.userId == widget.userId;
        final voteColor = _getVoteColor(pledge.selection);
        final voteDisplay = _displayVote(pledge.selection);
        final canMatch = !isMe && pledge.isOpen && !isLive;

        return _PersonTile(
          name: pledge.userName,
          isMe: isMe,
          accent: voteColor,
          highlight: isMe,
          subtitle: 'Pledged for $voteDisplay',
          badges: [
            if (isMe)  _Badge(label: 'you', color: FanColors.primary),
          ],
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canMatch) ...[
                _PillButton(
                    label: 'MATCH',
                    color: FanColors.primary,
                    small: true,
                    onTap: () => _matchPledge(pledge)),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: FanColors.primaryDim,
                    borderRadius: BorderRadius.circular(8)),
                child: Text('KES ${pledge.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: FanColors.primary)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================================
  // SUB-FIXTURES TAB
  // ==========================================================================

  Widget _buildSubFixturesFragment() {
    if (!_showSubFixtures) return const SizedBox.shrink();

    final visibleMarkets = _subFixtures.where((m) => m.isVisible).toList();
    if (visibleMarkets.isEmpty && !_isLoadingSubFixtures) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: _BalanceBar(
            loading: _isLoadingBalance,
            balance: _userBalance,
            processing: _isProcessingPayment,
            onTopUp: _showTopUpDialog,
            onWithdraw: _showWithdrawDialog,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(child: _buildSubFixturesList()),
      ],
    );
  }

  Widget _buildSubFixturesList() {
    if (_isLoadingSubFixtures && _subFixtures.isEmpty) {
      return _emptyState(spinner: true, label: 'Loading sub-fixtures…');
    }

    if (_subFixturesError != null && _subFixtures.isEmpty) {
      return _emptyState(
        icon: Icons.error_outline,
        label: _subFixturesError!,
        actionLabel: 'Retry',
        onAction: _loadSubFixtures,
      );
    }

    final visibleMarkets = _subFixtures.where((m) => m.isVisible).toList();

    if (visibleMarkets.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: visibleMarkets.length,
      itemBuilder: (context, index) =>
          _buildSubFixtureCard(visibleMarkets[index]),
    );
  }

  Widget _buildSubFixtureCard(SubFixtureMarket market) {
    final isLineMarket = market.marketType == 'over_under_2_5';
    final outcomes = isLineMarket
        ? _Outcome.overUnder(market.line ?? 2.5)
        : [
            _Outcome(
                key: 'home',
                label: widget.fixture.homeTeam,
                color: FanColors.primary),
            _Outcome(
                key: 'away',
                label: widget.fixture.awayTeam,
                color: FanColors.away),
            _Outcome(key: 'none', label: 'None', color: FanColors.textTertiary),
          ];

    final selected = _subFixtureSelections[market.id];
    final controller = _subFixtureAmountControllers.putIfAbsent(
        market.id, () => TextEditingController());
    final isPledging = _pledgingSubFixtureIds.contains(market.id);
    final locked = _isLive || !market.isOpen || market.isSettled;

    final isExpanded = _expandedSubFixtureMarkets[market.id] ?? false;
    final pledges = _subFixturePledges[market.id] ?? [];
    final isLoadingPledges = _subFixturePledgesLoading[market.id] ?? false;
    final pledgesError = _subFixturePledgesError[market.id];
    final filter = _subFixturePledgeFilters[market.id] ?? 'all';
    final filteredPledges = filter == 'all'
        ? pledges
        : pledges.where((p) => p.selection == filter).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FanColors.surface,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: FanColors.border.withOpacity(0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Clickable to expand
          GestureDetector(
            onTap: () => _toggleSubFixtureExpanded(market.id),
            child: Row(
              children: [
                Icon(market.icon, size: 14, color: FanColors.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    market.title(
                        widget.fixture.homeTeam, widget.fixture.awayTeam),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: FanColors.textPrimary,
                    ),
                  ),
                ),
                _Badge(
                  label: market.status.toUpperCase(),
                  color: market.isSettled
                      ? FanColors.secondary
                      : market.isOpen
                          ? FanColors.primary
                          : FanColors.draw,
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

          const SizedBox(height: 8),

          // Outcome row
          _OutcomeRow(
            outcomes: outcomes,
            selected: market.isSettled ? market.result : selected,
            locked: locked,
            onSelect: locked
                ? null
                : (v) => setState(() => _subFixtureSelections[market.id] = v),
            compact: true,
          ),

          if (market.totalPledges > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.people_outline,
                    size: 10, color: FanColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  '${market.totalPledges} pledge${market.totalPledges == 1 ? '' : 's'}'
                  '${market.isSettled && market.result != null ? ' · won by ${outcomes.firstWhere((o) => o.key == market.result, orElse: () => outcomes.first).label}' : ''}',
                  style: TextStyle(fontSize: 8, color: FanColors.textTertiary),
                ),
              ],
            ),
          ],

          // Betting input
          if (market.isOpen && !market.isSettled && !_isLive) ...[
            const SizedBox(height: 8),
            _StakeInput(
              controller: controller,
              enabled: selected != null,
              loading: isPledging,
              onSubmit: () => _handleSubFixturePledge(market),
            ),
          ],

          // Expandable pledges list
          if (isExpanded) ...[
            const SizedBox(height: 8),
             Divider(color: FanColors.border, height: 0.5),
            const SizedBox(height: 6),

            // Filter chips - only show if pledges exist
            if (pledges.isNotEmpty) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSubFixtureFilterChip(
                        market.id, 'All', 'all', pledges.length),
                    const SizedBox(width: 4),
                    _buildSubFixtureFilterChip(
                        market.id,
                        widget.fixture.homeTeam,
                        'home',
                        pledges.where((p) => p.selection == 'home').length),
                    const SizedBox(width: 4),
                    _buildSubFixtureFilterChip(
                        market.id,
                        widget.fixture.awayTeam,
                        'away',
                        pledges.where((p) => p.selection == 'away').length),
                    if (market.marketType == 'over_under_2_5') ...[
                      const SizedBox(width: 4),
                      _buildSubFixtureFilterChip(market.id, 'Over', 'over',
                          pledges.where((p) => p.selection == 'over').length),
                      const SizedBox(width: 4),
                      _buildSubFixtureFilterChip(market.id, 'Under', 'under',
                          pledges.where((p) => p.selection == 'under').length),
                    ],
                    if (market.marketType != 'over_under_2_5') ...[
                      const SizedBox(width: 4),
                      _buildSubFixtureFilterChip(market.id, 'None', 'none',
                          pledges.where((p) => p.selection == 'none').length),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],

            // Pledges header with count
            Row(
              children: [
                Text(
                  'Pledges (${filteredPledges.length})',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: FanColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (isLoadingPledges)
                   SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: FanColors.primary,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 4),

            // Pledges list or empty state
            if (isLoadingPledges)
               Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: FanColors.primary,
                    ),
                  ),
                ),
              )
            else if (pledgesError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        'Failed to load pledges',
                        style: TextStyle(
                          fontSize: 9,
                          color: FanColors.away,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _loadSubFixturePledges(market.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: FanColors.primaryDim,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Retry',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: FanColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (filteredPledges.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.attach_money_outlined,
                        size: 24,
                        color: FanColors.textTertiary.withOpacity(0.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        filter == 'all'
                            ? 'No pledges yet'
                            : 'No pledges for this selection',
                        style: TextStyle(
                          fontSize: 9,
                          color: FanColors.textTertiary,
                        ),
                      ),
                      Text(
                        filter == 'all'
                            ? 'Be the first to pledge on this market'
                            : 'Try a different filter',
                        style: TextStyle(
                          fontSize: 7,
                          color: FanColors.textTertiary.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredPledges.length,
                separatorBuilder: (_, __) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  final pledge = filteredPledges[index];
                  final isMe = pledge.userId == widget.userId;
                  final selectionDisplay = _getSelectionDisplayForSubFixture(
                    pledge.selection,
                    market,
                  );
                  final selectionColor = pledge.selectionColor;

                  return _PersonTile(
                    name: pledge.userName,
                    isMe: isMe,
                    accent: selectionColor,
                    subtitle: 'Pledged ${pledge.amount.toStringAsFixed(2)} KES',
                    badges: [
                      if (isMe)
                         _Badge(label: 'you', color: FanColors.primary),
                      if (pledge.status == 'settled')
                        _Badge(
                          label: 'won',
                          color: FanColors.primary,
                          icon: Icons.check_circle,
                        ),
                    ],
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: selectionColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            selectionDisplay,
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w600,
                              color: selectionColor,
                            ),
                          ),
                          Text(
                            'KES ${pledge.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 6,
                              color: FanColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _refreshSubFixtures() async {
    setState(() {
      _subFixturePledgesLoaded.clear();
      _subFixturePledges.clear();
      _subFixturePledgesError.clear();
    });
    await _loadSubFixtures();
  }

  void _applySubFixturePledgeFilter(String marketId, String filter) {
    setState(() {
      _subFixturePledgeFilters[marketId] = filter;
    });
  }

  Widget _buildSubFixtureFilterChip(
      String marketId, String label, String filter, int count) {
    final isSelected = (_subFixturePledgeFilters[marketId] ?? 'all') == filter;
    final color = isSelected ? FanColors.primary : FanColors.textTertiary;

    return GestureDetector(
      onTap: () => _applySubFixturePledgeFilter(marketId, filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
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

  // ==========================================================================
  // BETS FRAGMENT - NO DRAW
  // ==========================================================================

  Widget _buildBetsFragment() {
    if (!_showBets) return const SizedBox.shrink();

    if (_isLive) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: FanColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FanColors.border.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                   Icon(
                    Icons.sports_score,
                    size: 40,
                    color: FanColors.away,
                  ),
                  const SizedBox(height: 12),
                   Text(
                    '⛔ Betting is disabled during live matches',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: FanColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Come back after the match ends',
                    style: TextStyle(
                      fontSize: 11,
                      color: FanColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoadingBets)
      return _emptyState(spinner: true, label: 'Loading bets…');

    if (_bets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            _emptyState(
                icon: Icons.sports_score,
                label: 'No active bets',
                sublabel: 'Accept a pledge to start betting'),
          ],
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 2),
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
        Expanded(
          child: PageView.builder(
            controller: _betPageController,
            onPageChanged: (index) => setState(() => _currentBetIndex = index),
            itemCount: _bets.length,
            itemBuilder: (context, index) => _buildBetCard(_bets[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildBetCard(Bet bet) {
    final isStarter = bet.starterId == widget.userId;
    final isFinisher = bet.finisherId == widget.userId;

    String getPickLabel(String? selection) {
      if (selection == null) return '?';
      if (selection == 'home') return 'Home';
      if (selection == 'away') return 'Away';
      return selection;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FanColors.surface,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: FanColors.border.withOpacity(0.3), width: 0.5),
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
                        color: FanColors.primaryDim, shape: BoxShape.circle),
                    child:  Icon(Icons.sports_score,
                        size: 12, color: FanColors.primary),
                  ),
                  const SizedBox(width: 4),
                  Text('Bet #${bet.id!.substring(0, 8)}',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: FanColors.textPrimary)),
                ],
              ),
              _Badge(
                label: bet.status.toUpperCase(),
                color: bet.isActive
                    ? FanColors.primary
                    : (bet.isSettled ? FanColors.secondary : FanColors.away),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _betSideBox(
                  label: isStarter ? 'YOU' : bet.starterName.toUpperCase(),
                  highlight: isStarter,
                  color: FanColors.primary,
                  pick: getPickLabel(bet.starterSelection),
                  amount: bet.starterAmount,
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
                  highlight: isFinisher,
                  color: FanColors.secondary,
                  pick: getPickLabel(bet.finisherSelection),
                  amount: bet.finisherAmount,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Divider(color: FanColors.border.withOpacity(0.3), height: 0.5),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer, size: 8, color: FanColors.textTertiary),
              const SizedBox(width: 2),
              Text(bet.isSettled ? 'Settled' : 'Waiting for match result',
                  style: TextStyle(fontSize: 7, color: FanColors.textTertiary)),
              const SizedBox(width: 4),
              Container(
                  width: 2,
                  height: 2,
                  decoration: BoxDecoration(
                      color: FanColors.textTertiary, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('Created ${_timeAgo(bet.createdAt)}',
                  style: TextStyle(fontSize: 6, color: FanColors.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _betSideBox(
      {required String label,
      required bool highlight,
      required Color color,
      required String pick,
      double? amount}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: FanColors.surfaceSunken,
          borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 6,
                  fontWeight: highlight ? FontWeight.w800 : FontWeight.w500,
                  color: highlight ? color : FanColors.textTertiary)),
          const SizedBox(height: 1),
          Text(pick,
              style: TextStyle(
                  fontSize: 8, fontWeight: FontWeight.w700, color: color)),
          Text('KES ${amount?.toStringAsFixed(2) ?? '0.00'}',
              style: TextStyle(fontSize: 7, color: FanColors.textTertiary)),
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
          onTap: _shareChannel,
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
                  Icon(Icons.ios_share_rounded,
                      size: 13, color: FanColors.textSecondary),
                  SizedBox(width: 4),
                  Text('Share Match',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: FanColors.textSecondary)),
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

    // ✅ CHANNEL VALIDATION: Show message if no channel
    if (widget.channelId.isEmpty) {
      return Container(
        width: screenWidth,
        height: screenHeight * 0.78,
        decoration: BoxDecoration(
          color: FanColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildHandleBar(),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: FanColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FanColors.border.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                   Icon(
                    Icons.group_off_rounded,
                    size: 56,
                    color: FanColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                   Text(
                    'Join a Group First',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: FanColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                   Text(
                    'You need to join a group to vote, pledge, and interact with this match',
                    style: TextStyle(
                      fontSize: 13,
                      color: FanColors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onShowJoinGroups?.call();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: FanColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Join a Group',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final List<Widget> tabChildren = [_buildVotesFragment()];
    if (_showPledges) tabChildren.add(_buildPledgesFragment());
    if (_showSubFixtures) tabChildren.add(_buildSubFixturesFragment());
    if (_showBets) tabChildren.add(_buildBetsFragment());

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
              offset: const Offset(0, -3))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandleBar(),
          _buildHeader(),
          _buildMatchHeader(),
          _buildTabBar(),
          if (_tabCount > 1)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: tabChildren,
              ),
            )
          else
            Expanded(child: _buildVotesFragment()),
          _buildBottomButton(),
        ],
      ),
    );
  }
}
