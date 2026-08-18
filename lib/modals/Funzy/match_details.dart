import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../pages/fan_Funzy_design.dart';
import '../../models/fixture_models.dart';
import '../../main.dart';

// ═══════════════════════════════════════════════════════════════
//  ENUM DECLARATIONS (MUST BE AT TOP LEVEL)
// ═══════════════════════════════════════════════════════════════

/// Position ranks for sorting players by position
enum PositionRank {
  goalkeeper,
  defender,
  midfielder,
  forward,
}

// ═══════════════════════════════════════════════════════════════
//  MatchDetailsModal
// ═══════════════════════════════════════════════════════════════

class MatchDetailsModal extends StatefulWidget {
  final Fixture fixture;
  final String userId;
  final String username;
  final String? authToken;

  const MatchDetailsModal({
    super.key,
    required this.fixture,
    required this.userId,
    required this.username,
    this.authToken,
  });

  @override
  State<MatchDetailsModal> createState() => _MatchDetailsModalState();
}

class _MatchDetailsModalState extends State<MatchDetailsModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  MatchStatistics? _statistics;
  LineupsData? _lineups;

  bool _loadingStats = true;
  bool _loadingLineups = true;

  String _statsError = '';
  String _lineupsError = '';

  bool _hasStats = false;

  // Subs panel state
  bool _showBench = false;
  late AnimationController _benchAnimController;
  late Animation<double> _benchAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);

    _benchAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _benchAnimation = CurvedAnimation(
      parent: _benchAnimController,
      curve: Curves.easeInOut,
    );

    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _benchAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    await Future.wait([_fetchLineups(), _fetchStatistics()]);
    if (_hasStats && mounted) {
      _tabController.dispose();
      _tabController = TabController(length: 2, vsync: this);
      setState(() {});
    }
  }

  Map<String, String> get _headers => widget.authToken != null
      ? {'Authorization': 'Bearer ${widget.authToken}'}
      : {};

  // ============================================================
  // FETCH LINEUPS
  // ============================================================

  Future<void> _fetchLineups() async {
    final fixtureId = widget.fixture.matchId;

    final cachedLineup = AppCache.getCachedLineup(fixtureId);
    if (cachedLineup != null && mounted) {
      debugPrint('⚡ INSTANT: Lineups from AppCache (RAM)');
      setState(() {
        _lineups = LineupsData.fromJson(cachedLineup);
        _loadingLineups = false;
      });
      return;
    }

    try {
      final res = await http.get(
        Uri.parse(
          'https://clash-api-m5mr.onrender.com/api/games/${widget.fixture.matchId}/lineups',
        ),
        headers: _headers,
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true && data['data'] != null) {
          if (mounted) {
            final lineupsData = LineupsData.fromJson(data['data']);
            setState(() {
              _lineups = lineupsData;
              _loadingLineups = false;
            });
            AppCache.cacheLineup(fixtureId, data['data']);
          }
          return;
        }
      }

      final fallbackRes = await http.get(
        Uri.parse(
          'https://clash-api-m5mr.onrender.com/api/games/${widget.fixture.matchId}/lineups/simplified',
        ),
        headers: _headers,
      );

      if (fallbackRes.statusCode == 200) {
        final data = json.decode(fallbackRes.body);
        if (data['success'] == true && data['data'] != null && mounted) {
          setState(() {
            _lineups = LineupsData.fromJson(data['data']);
            _loadingLineups = false;
          });
          return;
        }
      }

      if (mounted) {
        setState(() {
          _lineupsError = 'No lineup available';
          _loadingLineups = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching lineups: $e');
      if (mounted) {
        setState(() {
          _lineupsError = 'No network error';
          _loadingLineups = false;
        });
      }
    }
  }

  // ============================================================
  // FETCH STATISTICS
  // ============================================================

  Future<void> _fetchStatistics() async {
    try {
      final res = await http.get(
        Uri.parse(
          'https://clash-api-m5mr.onrender.com/api/games/${widget.fixture.matchId}/statistics/latest',
        ),
        headers: _headers,
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final hasStats = _hasValidStatistics(data);
        if (hasStats && mounted) {
          setState(() {
            _statistics = MatchStatistics.fromJson(data);
            _hasStats = true;
            _loadingStats = false;
          });
          return;
        }
      }

      final fullRes = await http.get(
        Uri.parse(
          'https://clash-api-m5mr.onrender.com/api/games/${widget.fixture.matchId}/statistics',
        ),
        headers: _headers,
      );

      if (fullRes.statusCode == 200) {
        final data = json.decode(fullRes.body);
        if (data['success'] == true) {
          final stats = data['data'] ?? data;
          final hasStats = _hasValidStatistics(stats);
          if (hasStats && mounted) {
            setState(() {
              _statistics = MatchStatistics.fromJson(stats);
              _hasStats = true;
              _loadingStats = false;
            });
            return;
          }
        }
      }

      if (mounted) {
        setState(() {
          _hasStats = false;
          _statistics = null;
          _statsError = 'Statistics available after match starts';
          _loadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching statistics: $e');
      if (mounted) {
        setState(() {
          _hasStats = false;
          _statistics = null;
          _statsError = 'Statistics coming soon';
          _loadingStats = false;
        });
      }
    }
  }

  bool _hasValidStatistics(Map<String, dynamic> data) {
    final stats = data['data'] ?? data;

    if (stats['statistics'] is List) {
      final snapshots = stats['statistics'] as List;
      if (snapshots.isNotEmpty) {
        final latest = snapshots.last;
        final s = latest['statistics'] ?? latest;
        final home = s['home'] ?? {};
        final away = s['away'] ?? {};
        return (home['possession'] ?? 0) > 0 ||
            (away['possession'] ?? 0) > 0 ||
            (home['shots'] ?? 0) > 0 ||
            (away['shots'] ?? 0) > 0;
      }
      return false;
    }

    return (stats['ball_possession_home'] ?? 0) > 0 ||
        (stats['ball_possession_away'] ?? 0) > 0 ||
        (stats['total_shots_home'] ?? 0) > 0 ||
        (stats['total_shots_away'] ?? 0) > 0;
  }

  void _toggleBench() {
    setState(() => _showBench = !_showBench);
    if (_showBench) {
      _benchAnimController.forward();
    } else {
      _benchAnimController.reverse();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: FanColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          if (_hasStats) _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLineupsTab(),
                if (_hasStats) _buildStatsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Handle ───────────────────────────────────────────────────

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: FanColors.borderActive,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────

  Widget _buildHeader() {
    final home = widget.fixture.homeScore ?? 0;
    final away = widget.fixture.awayScore ?? 0;
    final isLive = widget.fixture.status == 'live';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.fixture.homeTeam,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: FanColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isLive) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: FanColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$home - $away',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: FanColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.fixture.awayTeam,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: FanColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.fixture.date.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(widget.fixture.date),
                    style: TextStyle(
                      fontSize: 10,
                      color: FanColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String dateTime) {
    try {
      final date = DateTime.parse(dateTime);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  // ── Tab bar ──────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: TabBar(
        controller: _tabController,
        indicatorColor: FanColors.primary,
        indicatorWeight: 2,
        dividerColor: Colors.transparent,
        labelColor: FanColors.primary,
        unselectedLabelColor: FanColors.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [Tab(text: 'LINEUPS'), Tab(text: 'STATS')],
      ),
    );
  }

  // ============================================================
  // LINEUPS TAB
  // ============================================================

  Widget _buildLineupsTab() {
    if (_loadingLineups) {
      return Center(
        child: CircularProgressIndicator(color: FanColors.primary),
      );
    }
    if (_lineupsError.isNotEmpty) {
      return _buildEmptyState(Icons.error_outline, _lineupsError);
    }
    if (_lineups == null) {
      return _buildEmptyState(
        Icons.sports_soccer,
        'No lineup available',
      );
    }

    final hasBench =
        _lineups!.homeBench.isNotEmpty || _lineups!.awayBench.isNotEmpty;

    return Column(
      children: [
        // Formation header row with Bench button
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Row(
            children: [
              _FormationPill(
                teamName: widget.fixture.homeTeam,
                formation: _lineups!.homeFormation,
                color: FanColors.primary,
              ),
              const Spacer(),
              if (hasBench)
                GestureDetector(
                  onTap: _toggleBench,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _showBench ? FanColors.primary : FanColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _showBench
                            ? FanColors.primary
                            : FanColors.borderActive,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showBench ? Icons.close : Icons.swap_horiz_rounded,
                          color: _showBench
                              ? Colors.white
                              : FanColors.textSecondary,
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Bench',
                          style: TextStyle(
                            color: _showBench
                                ? Colors.white
                                : FanColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              _FormationPill(
                teamName: widget.fixture.awayTeam,
                formation: _lineups!.awayFormation,
                color: FanColors.away,
                alignRight: true,
              ),
            ],
          ),
        ),

        // Bench animated drawer
        SizeTransition(
          sizeFactor: _benchAnimation,
          axisAlignment: -1,
          child: Container(
            decoration: BoxDecoration(
              color: FanColors.background,
              border: Border(
                bottom: BorderSide(
                  color: FanColors.primary.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 13,
                      decoration: BoxDecoration(
                        color: FanColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'BENCH',
                      style: TextStyle(
                        color: FanColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _BenchColumn(
                        players: _lineups!.homeBench,
                        color: FanColors.primary,
                      ),
                    ),
                    Container(
                      width: 0.5,
                      height: 160,
                      color: FanColors.borderActive,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    Expanded(
                      child: _BenchColumn(
                        players: _lineups!.awayBench,
                        color: FanColors.away,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Pitch
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
            child: _PitchView(
              homeTeam: widget.fixture.homeTeam,
              awayTeam: widget.fixture.awayTeam,
              homeFormation: _lineups!.homeFormation,
              awayFormation: _lineups!.awayFormation,
              homePlayers: _lineups!.homeStartingXI,
              awayPlayers: _lineups!.awayStartingXI,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATS TAB
  // ============================================================

  Widget _buildStatsTab() {
    if (!_hasStats || _statistics == null) {
      return const SizedBox.shrink();
    }

    if (_loadingStats) {
      return Center(
        child: CircularProgressIndicator(color: FanColors.primary),
      );
    }

    final statsItems = [
      _StatItem(
        label: 'Possession',
        home: _statistics!.ballPossessionHome,
        away: _statistics!.ballPossessionAway,
        suffix: '%',
      ),
      _StatItem(
        label: 'Total Shots',
        home: _statistics!.totalShotsHome,
        away: _statistics!.totalShotsAway,
      ),
      _StatItem(
        label: 'Shots on Target',
        home: _statistics!.shotsOnTargetHome,
        away: _statistics!.shotsOnTargetAway,
      ),
      _StatItem(
        label: 'Pass Accuracy',
        home: _statistics!.passAccuracyHome,
        away: _statistics!.passAccuracyAway,
        suffix: '%',
      ),
      _StatItem(
        label: 'Corners',
        home: _statistics!.cornersHome,
        away: _statistics!.cornersAway,
      ),
      _StatItem(
        label: 'Fouls',
        home: _statistics!.foulsHome,
        away: _statistics!.foulsAway,
      ),
      _StatItem(
        label: 'Yellow Cards',
        home: _statistics!.yellowCardsHome,
        away: _statistics!.yellowCardsAway,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.fixture.homeTeam,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: FanColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.fixture.awayTeam,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: FanColors.away,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          ...statsItems.map((s) => _buildStatRow(s)),
        ],
      ),
    );
  }

  Widget _buildStatRow(_StatItem stat) {
    final total = stat.home + stat.away;
    final homePercent = total > 0 ? stat.home / total : 0.5;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  '${stat.home}${stat.suffix}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: stat.home > stat.away
                        ? FanColors.primary
                        : FanColors.textSecondary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                child: Text(
                  stat.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: FanColors.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '${stat.away}${stat.suffix}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: stat.away > stat.home
                        ? FanColors.away
                        : FanColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 4,
              child: Row(
                children: [
                  Flexible(
                    flex: (homePercent * 100).toInt(),
                    child: Container(color: FanColors.primary),
                  ),
                  Flexible(
                    flex: ((1 - homePercent) * 100).toInt(),
                    child: Container(color: FanColors.away),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 48, color: FanColors.textTertiary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: FanColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  FORMATION PILL
// ═══════════════════════════════════════════════════════════════

class _FormationPill extends StatelessWidget {
  final String teamName;
  final String formation;
  final Color color;
  final bool alignRight;

  const _FormationPill({
    required this.teamName,
    required this.formation,
    required this.color,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          teamName,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            formation,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  BENCH COLUMN
// ═══════════════════════════════════════════════════════════════

class _BenchColumn extends StatelessWidget {
  final List<SimplifiedPlayer> players;
  final Color color;

  const _BenchColumn({required this.players, required this.color});

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return Center(
        child: Text(
          'No data',
          style: TextStyle(color: FanColors.textTertiary, fontSize: 11),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: players.take(9).map((p) => _buildPlayerRow(p)).toList(),
    );
  }

  Widget _buildPlayerRow(SimplifiedPlayer p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '${p.number}',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _shortName(p.name),
              style: TextStyle(
                fontSize: 11,
                color: FanColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            p.position.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              color: FanColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (p.captain) ...[
            const SizedBox(width: 4),
            Text(
              'C',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _shortName(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return name;
    return '${parts.first[0]}. ${parts.last}';
  }
}

// ═══════════════════════════════════════════════════════════════
//  PITCH VIEW — REDESIGNED WITH A CLEAR HOME / AWAY SPLIT
// ═══════════════════════════════════════════════════════════════
//
//  Instead of letting both teams share one continuous pitch (which
//  could crowd or overlap near the halfway line), the pitch is now
//  split into two strictly separated zones:
//    - a HOME zone (bottom half)
//    - an AWAY zone (top half)
//  divided by a neutral "no-player" gap band around the halfway
//  line. Each team's rows are laid out only within their own zone,
//  so the two lineups never visually mix.
// ═══════════════════════════════════════════════════════════════

class _PitchView extends StatefulWidget {
  final String homeTeam;
  final String awayTeam;
  final String homeFormation;
  final String awayFormation;
  final List<SimplifiedPlayer> homePlayers;
  final List<SimplifiedPlayer> awayPlayers;

  const _PitchView({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeFormation,
    required this.awayFormation,
    required this.homePlayers,
    required this.awayPlayers,
  });

  @override
  State<_PitchView> createState() => _PitchViewState();
}

class _PitchViewState extends State<_PitchView> {
  bool _showHomeOverflow = false;
  bool _showAwayOverflow = false;

  // Fraction of the pitch height reserved as a neutral gap that
  // straddles the halfway line. No player is ever placed inside it,
  // which is what visually separates the two lineups.
  static const double _neutralGapFraction = 0.09;

  // ─────────────────────────────────────────────────────────────
  //  PROFESSIONAL PLAYER POSITIONING ENGINE
  // ─────────────────────────────────────────────────────────────

  PositionRank _getPositionRank(String pos) {
    final p = pos.toLowerCase().trim();

    // Goalkeeper
    if (p.contains('goalkeeper') || p == 'gk' || p == 'g') {
      return PositionRank.goalkeeper;
    }

    // Defender
    if (p.contains('back') ||
        p.contains('defend') ||
        p.contains('def') ||
        p == 'd' ||
        p == 'cb' ||
        p == 'lb' ||
        p == 'rb' ||
        p == 'lwb' ||
        p == 'rwb' ||
        p == 'cwb' ||
        p == 'sw' ||
        p == 'dc' ||
        p == 'dl' ||
        p == 'dr') {
      return PositionRank.defender;
    }

    // Forward
    if (p.contains('forward') ||
        p.contains('striker') ||
        p.contains('winger') ||
        p.contains('attack') ||
        p == 'f' ||
        p == 'cf' ||
        p == 'st' ||
        p == 'lw' ||
        p == 'rw' ||
        p == 'ss' ||
        p == 'fw' ||
        p == 'lf' ||
        p == 'rf') {
      return PositionRank.forward;
    }

    // Midfielder (default for anything else)
    return PositionRank.midfielder;
  }

  /// Parse formation string (e.g., "4-3-3" → [4, 3, 3])
  List<int> _parseFormation(String formation) {
    try {
      return formation
          .split('-')
          .map((s) => int.tryParse(s.trim()) ?? 0)
          .where((n) => n > 0)
          .toList();
    } catch (_) {
      return [4, 4, 2]; // Default formation
    }
  }

  /// Smart grouping by formation with position-aware distribution
  List<List<SimplifiedPlayer>> _groupByFormation(
    List<SimplifiedPlayer> players,
    String formation,
  ) {
    final formationRows = _parseFormation(formation);

    // Separate players by position rank
    final gks = <SimplifiedPlayer>[];
    final defs = <SimplifiedPlayer>[];
    final mids = <SimplifiedPlayer>[];
    final fwds = <SimplifiedPlayer>[];

    for (final player in players) {
      switch (_getPositionRank(player.position)) {
        case PositionRank.goalkeeper:
          gks.add(player);
          break;
        case PositionRank.defender:
          defs.add(player);
          break;
        case PositionRank.midfielder:
          mids.add(player);
          break;
        case PositionRank.forward:
          fwds.add(player);
          break;
      }
    }

    // Sort each group by position specificity
    void sortByPosition(List<SimplifiedPlayer> list) {
      list.sort((a, b) {
        final rankA = _getPositionRank(a.position);
        final rankB = _getPositionRank(b.position);
        if (rankA != rankB) return rankA.index - rankB.index;
        return a.number.compareTo(b.number);
      });
    }

    sortByPosition(gks);
    sortByPosition(defs);
    sortByPosition(mids);
    sortByPosition(fwds);

    final result = <List<SimplifiedPlayer>>[];

    // Add GK row
    result.add(gks.take(1).toList());

    // Distribute outfield players across rows based on formation
    final outfield = [...defs, ...mids, ...fwds];
    int outfieldIndex = 0;

    for (final rowCount in formationRows) {
      final row = <SimplifiedPlayer>[];
      for (int i = 0; i < rowCount && outfieldIndex < outfield.length; i++) {
        row.add(outfield[outfieldIndex++]);
      }
      result.add(row);
    }

    // If we have extra players, distribute them to the last row
    while (outfieldIndex < outfield.length) {
      if (result.isNotEmpty) {
        result.last.add(outfield[outfieldIndex++]);
      } else {
        break;
      }
    }

    return result;
  }

  /// Professional row curve depth based on player count and tactical role
  double _rowCurveDepth(int count, int rowIndex, int totalRows) {
    // If only 1 player in a row, no curve
    if (count <= 1) return 0.0;

    // Determine row type based on position in formation
    final isDefenseRow = rowIndex == 1;
    final isMidfieldRow = rowIndex >= 2 && rowIndex < totalRows - 1;
    final isForwardRow = rowIndex == totalRows - 1;

    // Different curve depths for different rows
    switch (count) {
      case 2:
        if (isDefenseRow) return 0.020; // CB pair slight bow
        if (isMidfieldRow) return 0.025; // Double pivot subtle V
        return 0.015; // Strike partnership

      case 3:
        if (isDefenseRow) return 0.035; // Back three
        if (isMidfieldRow) return 0.070; // Strong V for midfield 3
        if (isForwardRow) return 0.050; // Front three
        return 0.060;

      case 4:
        if (isDefenseRow) return 0.025; // Classic back four
        if (isMidfieldRow) return 0.045; // Diamond midfield
        return 0.035;

      case 5:
        if (isMidfieldRow) return 0.060; // Strong V for midfield 5
        return 0.045;

      default:
        return 0.040;
    }
  }

  /// Get tactical width for a row based on row type and count
  double _getRowWidth(int count, int rowIndex, int totalRows) {
    if (count <= 1) return 0.0;

    final isDefenseRow = rowIndex == 1;
    final isMidfieldRow = rowIndex >= 2 && rowIndex < totalRows - 1;
    final isForwardRow = rowIndex == totalRows - 1;

    // Wider rows for attack, narrower for defense
    double baseWidth;
    if (isDefenseRow) {
      baseWidth = 0.55; // Compact back line
    } else if (isMidfieldRow) {
      baseWidth = 0.62; // Wider midfield
    } else if (isForwardRow) {
      baseWidth = 0.58; // Attack width
    } else {
      baseWidth = 0.55;
    }

    // Adjust based on player count
    final countFactor = (count / 4.0).clamp(0.7, 1.3);
    return (baseWidth * countFactor).clamp(0.25, 0.75);
  }

  /// Calculate professional player positions on the pitch, strictly
  /// confined to the team's own half so the two lineups stay visually
  /// separated by the neutral gap band.
  List<Offset> _calculatePositions(
    List<SimplifiedPlayer> players,
    String formation, {
    required bool isHome,
    required double width,
    required double height,
  }) {
    if (players.isEmpty) return [];

    final groups = _groupByFormation(players, formation);
    final List<Offset> positions = [];

    // Edge margins (goal-line end of the pitch)
    final double edgeMargin = height * 0.06;
    // Half of the neutral gap band, measured from the halfway line
    final double halfGap = height * (_neutralGapFraction / 2);
    final double halfwayY = height / 2;

    // Each team gets everything between its own goal-line margin and
    // the near edge of the neutral gap band.
    final double gkY = isHome ? height - edgeMargin : edgeMargin;
    final double forwardY = isHome ? halfwayY + halfGap : halfwayY - halfGap;

    for (int rowIndex = 0; rowIndex < groups.length; rowIndex++) {
      final row = groups[rowIndex];
      if (row.isEmpty) continue;

      // Calculate Y position for this row with more natural spacing
      final double totalRows = groups.length > 1 ? groups.length - 1 : 1;
      final double t = totalRows > 0 ? rowIndex / totalRows : 0.5;
      final double yPos = gkY + t * (forwardY - gkY);

      // Calculate curve depth for this row
      final double curveDepth = _rowCurveDepth(
        row.length,
        rowIndex,
        groups.length,
      );

      // Calculate row width
      final double rowWidth = _getRowWidth(row.length, rowIndex, groups.length);
      final double rowStart = 0.50 - rowWidth / 2;

      // Sort players within row for natural positioning
      final sortedRow = List<SimplifiedPlayer>.from(row);
      sortedRow.sort((a, b) {
        final rankA = _getPositionRank(a.position);
        final rankB = _getPositionRank(b.position);
        if (rankA != rankB) return rankA.index.compareTo(rankB.index);
        return a.number.compareTo(b.number);
      });

      final int playerCount = sortedRow.length;
      final double center = playerCount > 1 ? (playerCount - 1) / 2 : 0;

      for (int i = 0; i < playerCount; i++) {
        // X position with natural spacing
        final double xPos = playerCount == 1
            ? 0.50
            : rowStart + (rowWidth * i / (playerCount - 1));

        // Y position with V-shape curve
        double d = 0.0;
        if (playerCount > 1 && center > 0) {
          d = (i - center) / center;
        }

        // Curve shape: V-shape where center is deeper, edges are advanced
        final double advance = curveDepth * (d * d - 0.35);
        final double yPosCurved = isHome ? yPos - advance : yPos + advance;

        // Clamp strictly within the team's own half so it can never
        // cross into the neutral gap or the opposing half.
        final double clampMin =
            isHome ? halfwayY + halfGap * 0.4 : edgeMargin * 0.5;
        final double clampMax =
            isHome ? height - edgeMargin * 0.5 : halfwayY - halfGap * 0.4;

        positions.add(Offset(
          xPos * width,
          yPosCurved.clamp(clampMin, clampMax),
        ));
      }
    }

    return positions;
  }

  // ─────────────────────────────────────────────────────────────
  //  UI BUILDERS
  // ─────────────────────────────────────────────────────────────

  Widget _buildOverflowButton({
    required String label,
    required int count,
    required Color color,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    final shortLabel = label.length > 12 ? '${label.substring(0, 11)}…' : label;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:
              expanded ? color.withValues(alpha: 0.15) : FanColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: expanded ? color : FanColors.borderActive,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color.withValues(alpha: expanded ? 0.9 : 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: expanded ? Colors.white : color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              shortLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: expanded ? color : FanColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 14,
              color: expanded ? color : FanColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverflowPanel({
    required List<SimplifiedPlayer> homePlayers,
    required List<SimplifiedPlayer> awayPlayers,
  }) {
    final showHome = _showHomeOverflow && homePlayers.isNotEmpty;
    final showAway = _showAwayOverflow && awayPlayers.isNotEmpty;

    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
      child: (showHome || showAway)
          ? Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              decoration: BoxDecoration(
                color: FanColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: FanColors.borderActive,
                  width: 0.8,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 12,
                        decoration: BoxDecoration(
                          color: FanColors.textTertiary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'EXTRA PLAYERS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: FanColors.textTertiary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showHome)
                        Expanded(
                          child: _BenchColumn(
                            players: homePlayers,
                            color: FanColors.primary,
                          ),
                        ),
                      if (showHome && showAway)
                        Container(
                          width: 0.5,
                          height: (homePlayers.length > awayPlayers.length
                                  ? homePlayers.length
                                  : awayPlayers.length) *
                              32.0,
                          color: FanColors.borderActive,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      if (showAway)
                        Expanded(
                          child: _BenchColumn(
                            players: awayPlayers,
                            color: FanColors.away,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cappedHome = widget.homePlayers.take(11).toList();
    final cappedAway = widget.awayPlayers.take(11).toList();
    final homeOverflow = widget.homePlayers.skip(11).toList();
    final awayOverflow = widget.awayPlayers.skip(11).toList();

    final hasOverflow = homeOverflow.isNotEmpty || awayOverflow.isNotEmpty;

    return Column(
      children: [
        if (hasOverflow)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                if (homeOverflow.isNotEmpty)
                  _buildOverflowButton(
                    label: widget.homeTeam,
                    count: homeOverflow.length,
                    color: FanColors.primary,
                    expanded: _showHomeOverflow,
                    onTap: () => setState(
                      () => _showHomeOverflow = !_showHomeOverflow,
                    ),
                  ),
                if (homeOverflow.isNotEmpty && awayOverflow.isNotEmpty)
                  const Spacer(),
                if (awayOverflow.isNotEmpty)
                  _buildOverflowButton(
                    label: widget.awayTeam,
                    count: awayOverflow.length,
                    color: FanColors.away,
                    expanded: _showAwayOverflow,
                    onTap: () => setState(
                      () => _showAwayOverflow = !_showAwayOverflow,
                    ),
                  ),
              ],
            ),
          ),
        if (hasOverflow)
          _buildOverflowPanel(
            homePlayers: homeOverflow,
            awayPlayers: awayOverflow,
          ),
        AspectRatio(
          aspectRatio: 0.68,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CustomPaint(
              painter: _PitchPainter(
                homeColor: FanColors.primary,
                awayColor: FanColors.away,
                neutralGapFraction: _neutralGapFraction,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;

                  // Calculate positions using the professional system
                  final homePositions = _calculatePositions(
                    cappedHome,
                    widget.homeFormation,
                    isHome: true,
                    width: width,
                    height: height,
                  );

                  final awayPositions = _calculatePositions(
                    cappedAway,
                    widget.awayFormation,
                    isHome: false,
                    width: width,
                    height: height,
                  );

                  return Stack(
                    children: [
                      // Team labels, sitting inside each team's own zone
                      Positioned(
                        bottom: height * 0.03,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: _PitchLabel(
                            label: widget.homeTeam,
                            color: FanColors.primary,
                          ),
                        ),
                      ),
                      Positioned(
                        top: height * 0.03,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: _PitchLabel(
                            label: widget.awayTeam,
                            color: FanColors.away,
                          ),
                        ),
                      ),
                      // Home players (bottom zone)
                      for (int i = 0;
                          i < cappedHome.length && i < homePositions.length;
                          i++)
                        _PlayerDot(
                          player: cappedHome[i],
                          position: homePositions[i],
                          color: FanColors.primary,
                          isHome: true,
                        ),
                      // Away players (top zone)
                      for (int i = 0;
                          i < cappedAway.length && i < awayPositions.length;
                          i++)
                        _PlayerDot(
                          player: cappedAway[i],
                          position: awayPositions[i],
                          color: FanColors.away,
                          isHome: false,
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PITCH LABEL
// ─────────────────────────────────────────────────────────────

class _PitchLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _PitchLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.4,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PITCH PAINTER — REDONE
//  - subtle team-colour wash at each end so each half reads as
//    "belonging" to its team
//  - a shaded neutral band + a bold two-tone halfway line marks
//    the separation between the two lineups
// ═══════════════════════════════════════════════════════════════

class _PitchPainter extends CustomPainter {
  final Color homeColor;
  final Color awayColor;
  final double neutralGapFraction;

  _PitchPainter({
    required this.homeColor,
    required this.awayColor,
    this.neutralGapFraction = 0.09,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Base grass stripes
    const stripeCount = 12;
    for (int i = 0; i < stripeCount; i++) {
      final stripePaint = Paint()
        ..color = i.isEven ? const Color(0xFF0D5E1A) : const Color(0xFF0A5218);
      final stripeH = h / stripeCount;
      canvas.drawRect(
        Rect.fromLTWH(0, i * stripeH, w, stripeH),
        stripePaint,
      );
    }

    // Team-colour wash at each goal end, fading toward the centre —
    // reinforces which half belongs to which team.
    final awayWash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [awayColor.withValues(alpha: 0.16), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.5));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.5), awayWash);

    final homeWash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.center,
        colors: [homeColor.withValues(alpha: 0.16), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, h * 0.5, w, h * 0.5));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.5, w, h * 0.5), homeWash);

    // Neutral separation band around the halfway line
    final gapH = h * neutralGapFraction;
    final gapPaint = Paint()..color = Colors.black.withValues(alpha: 0.18);
    canvas.drawRect(
      Rect.fromLTWH(0, h / 2 - gapH / 2, w, gapH),
      gapPaint,
    );

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    // Pitch outline
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6, 6, w - 12, h - 12),
        const Radius.circular(4),
      ),
      linePaint,
    );

    // Two-tone halfway line: away colour on top, home colour on bottom
    final halfLineAway = Paint()
      ..color = awayColor.withValues(alpha: 0.9)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    final halfLineHome = Paint()
      ..color = homeColor.withValues(alpha: 0.9)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(6, h / 2), Offset(w / 2, h / 2), halfLineAway);
    canvas.drawLine(Offset(w / 2, h / 2), Offset(w - 6, h / 2), halfLineHome);

    // Center circle
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.13, linePaint);
    canvas.drawCircle(
      Offset(w / 2, h / 2),
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );

    // Penalty areas
    final penW = w * 0.55;
    final penH = h * 0.16;
    canvas.drawRect(
      Rect.fromLTWH((w - penW) / 2, 6, penW, penH),
      linePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH((w - penW) / 2, h - 6 - penH, penW, penH),
      linePaint,
    );

    // Goal areas
    final gW = w * 0.30;
    final gH = h * 0.06;
    canvas.drawRect(
      Rect.fromLTWH((w - gW) / 2, 6, gW, gH),
      linePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH((w - gW) / 2, h - 6 - gH, gW, gH),
      linePaint,
    );

    // Penalty spots
    final spotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w / 2, h * 0.13), 2.5, spotPaint);
    canvas.drawCircle(Offset(w / 2, h * 0.87), 2.5, spotPaint);

    // Corner arcs
    final cornerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    const cr = 10.0;
    canvas.drawArc(
      Rect.fromLTWH(6, 6, cr * 2, cr * 2),
      0,
      1.57,
      false,
      cornerPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(w - 6 - cr * 2, 6, cr * 2, cr * 2),
      1.57,
      1.57,
      false,
      cornerPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(6, h - 6 - cr * 2, cr * 2, cr * 2),
      -1.57,
      -1.57,
      false,
      cornerPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(w - 6 - cr * 2, h - 6 - cr * 2, cr * 2, cr * 2),
      0,
      -1.57,
      false,
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PitchPainter oldDelegate) =>
      oldDelegate.homeColor != homeColor ||
      oldDelegate.awayColor != awayColor ||
      oldDelegate.neutralGapFraction != neutralGapFraction;
}

// ═══════════════════════════════════════════════════════════════
//  PLAYER DOT
// ═══════════════════════════════════════════════════════════════

class _PlayerDot extends StatelessWidget {
  final SimplifiedPlayer player;
  final Offset position;
  final Color color;
  final bool isHome;

  const _PlayerDot({
    required this.player,
    required this.position,
    required this.color,
    this.isHome = true,
  });

  // Approximate height of the [gap + name chip] block below/above the dot.
  // Used to keep the dot's visual center pinned to `position` regardless
  // of which side the label is drawn on.
  static const double _labelBlockHeight = 21.0;

  @override
  Widget build(BuildContext context) {
    const dotSize = 34.0;

    final dotWidget = Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.8),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '${player.number}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );

    final labelWidget = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 5,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _shortName(player.name),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (player.captain) ...[
            const SizedBox(width: 2),
            Text(
              'C',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );

    // Home attacks toward smaller y (toward the halfway line), so its
    // label must extend downward (toward its own goal / larger y) to
    // stay clear of the away half. Away attacks toward larger y, so its
    // label must extend upward instead — otherwise a front-row away
    // player's label spills across the halfway line into the home half,
    // which is what reads as the two lineups being "mixed".
    final children = isHome
        ? [dotWidget, const SizedBox(height: 3), labelWidget]
        : [labelWidget, const SizedBox(height: 3), dotWidget];

    // Shift the box up by the label block's height for away players so
    // the dot itself (not the label) stays centered on `position`.
    final topOffset = isHome
        ? position.dy - dotSize / 2
        : position.dy - dotSize / 2 - _labelBlockHeight;

    return Positioned(
      left: position.dx - dotSize / 2,
      top: topOffset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  String _shortName(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return name.length > 12 ? '${name.substring(0, 11)}…' : name;
    }
    return '${parts.first[0]}. ${parts.last}';
  }
}

// ═══════════════════════════════════════════════════════════════
//  DATA MODELS
// ═══════════════════════════════════════════════════════════════

class _StatItem {
  final String label;
  final int home;
  final int away;
  final String suffix;

  const _StatItem({
    required this.label,
    required this.home,
    required this.away,
    this.suffix = '',
  });
}

class MatchStatistics {
  final int ballPossessionHome;
  final int ballPossessionAway;
  final int totalShotsHome;
  final int totalShotsAway;
  final int shotsOnTargetHome;
  final int shotsOnTargetAway;
  final int cornersHome;
  final int cornersAway;
  final int foulsHome;
  final int foulsAway;
  final int offsidesHome;
  final int offsidesAway;
  final int yellowCardsHome;
  final int yellowCardsAway;
  final int passAccuracyHome;
  final int passAccuracyAway;

  const MatchStatistics({
    required this.ballPossessionHome,
    required this.ballPossessionAway,
    required this.totalShotsHome,
    required this.totalShotsAway,
    required this.shotsOnTargetHome,
    required this.shotsOnTargetAway,
    required this.cornersHome,
    required this.cornersAway,
    required this.foulsHome,
    required this.foulsAway,
    required this.offsidesHome,
    required this.offsidesAway,
    required this.yellowCardsHome,
    required this.yellowCardsAway,
    required this.passAccuracyHome,
    required this.passAccuracyAway,
  });

  factory MatchStatistics.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    Map<String, dynamic> stats;

    if (data['statistics'] is List && (data['statistics'] as List).isNotEmpty) {
      final snapshots = data['statistics'] as List;
      final latest = snapshots.last;
      stats = latest['statistics'] ?? latest;
    } else if (data['statistics'] is Map) {
      stats = data['statistics'];
    } else {
      stats = data;
    }

    final home = stats['home'] ?? {};
    final away = stats['away'] ?? {};

    int getInt(Map<String, dynamic> obj, String field1, [String? field2]) {
      return obj[field1] as int? ??
          (field2 != null ? obj[field2] as int? : null) ??
          0;
    }

    int getPercent(Map<String, dynamic> obj, String field1, [String? field2]) {
      final val = obj[field1] ?? obj[field2 ?? ''];
      if (val is double) return (val * 100).round();
      if (val is int) return val;
      return 0;
    }

    return MatchStatistics(
      ballPossessionHome: getPercent(home, 'possession', 'ball_possession'),
      ballPossessionAway: getPercent(away, 'possession', 'ball_possession'),
      totalShotsHome: getInt(home, 'shots', 'total_shots'),
      totalShotsAway: getInt(away, 'shots', 'total_shots'),
      shotsOnTargetHome: getInt(home, 'shotsOnTarget', 'shots_on_target'),
      shotsOnTargetAway: getInt(away, 'shotsOnTarget', 'shots_on_target'),
      cornersHome: getInt(home, 'corners'),
      cornersAway: getInt(away, 'corners'),
      foulsHome: getInt(home, 'fouls'),
      foulsAway: getInt(away, 'fouls'),
      offsidesHome: getInt(home, 'offsides'),
      offsidesAway: getInt(away, 'offsides'),
      yellowCardsHome: getInt(home, 'yellowCards', 'yellow_cards'),
      yellowCardsAway: getInt(away, 'yellowCards', 'yellow_cards'),
      passAccuracyHome: getPercent(home, 'passAccuracy', 'pass_accuracy'),
      passAccuracyAway: getPercent(away, 'passAccuracy', 'pass_accuracy'),
    );
  }
}

class LineupsData {
  final String homeFormation;
  final String awayFormation;
  final String homeCoach;
  final String awayCoach;
  final List<SimplifiedPlayer> homeStartingXI;
  final List<SimplifiedPlayer> homeBench;
  final List<SimplifiedPlayer> awayStartingXI;
  final List<SimplifiedPlayer> awayBench;

  const LineupsData({
    required this.homeFormation,
    required this.awayFormation,
    required this.homeCoach,
    required this.awayCoach,
    required this.homeStartingXI,
    required this.homeBench,
    required this.awayStartingXI,
    required this.awayBench,
  });

  factory LineupsData.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;

    List<SimplifiedPlayer> parseList(dynamic raw) {
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((p) => SimplifiedPlayer.fromJson(Map<String, dynamic>.from(p)))
          .toList();
    }

    return LineupsData(
      homeFormation: data['home_formation']?.toString() ?? '4-3-3',
      awayFormation: data['away_formation']?.toString() ?? '4-3-3',
      homeCoach: data['home_coach']?.toString() ?? 'TBD',
      awayCoach: data['away_coach']?.toString() ?? 'TBD',
      homeStartingXI: parseList(data['home_starting_xi']),
      homeBench: parseList(data['home_bench']),
      awayStartingXI: parseList(data['away_starting_xi']),
      awayBench: parseList(data['away_bench']),
    );
  }
}

class SimplifiedPlayer {
  final String name;
  final int number;
  final String position;
  final bool captain;

  const SimplifiedPlayer({
    required this.name,
    required this.number,
    required this.position,
    required this.captain,
  });

  factory SimplifiedPlayer.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ??
        json['displayName']?.toString() ??
        json['fullName']?.toString() ??
        'Player ${json['competitorId'] ?? json['id'] ?? ''}';

    final rawNumber = json['number'] ??
        json['jerseyNumber'] ??
        json['jersey_number'] ??
        json['shirtNumber'] ??
        json['shirt_number'] ??
        json['squadNumber'] ??
        json['squad_number'] ??
        json['shirtNo'] ??
        json['jerseyNo'] ??
        json['competitorId'] ??
        0;
    final number =
        rawNumber is int ? rawNumber : int.tryParse(rawNumber.toString()) ?? 0;

    final posField = json['position'];
    final position = posField is Map
        ? (posField['shortName']?.toString() ??
            posField['name']?.toString() ??
            '')
        : (posField?.toString() ?? '');

    final captain = json['captain'] == true;

    return SimplifiedPlayer(
      name: name,
      number: number,
      position: position,
      captain: captain,
    );
  }
}
