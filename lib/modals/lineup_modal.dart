import 'dart:math';
import 'package:flutter/material.dart';
import '../models/fixture_models.dart';

class LineupModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final Fixture fixture;

  const LineupModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.fixture,
  });

  @override
  State<LineupModal> createState() => _LineupModalState();
}

class _LineupModalState extends State<LineupModal>
    with SingleTickerProviderStateMixin {
  String _selectedFormation = '4-3-3';
  bool _showSubsPanel = false;

  late AnimationController _subsAnimController;
  late Animation<double> _subsAnimation;

  final List<String> _formations = [
    '4-3-3',
    '4-4-2',
    '4-2-3-1',
    '3-5-2',
    '3-4-3',
  ];

  // ---------- Starting XI ----------

  final List<Map<String, dynamic>> _homeStartingXI = [
    {'name': 'De Gea', 'position': 'GK', 'number': 1},
    {'name': 'Wan-Bissaka', 'position': 'RB', 'number': 29},
    {'name': 'Varane', 'position': 'CB', 'number': 19},
    {'name': 'Martinez', 'position': 'CB', 'number': 6},
    {'name': 'Shaw', 'position': 'LB', 'number': 23},
    {'name': 'Casemiro', 'position': 'CDM', 'number': 18},
    {'name': 'Eriksen', 'position': 'CM', 'number': 14},
    {'name': 'Bruno', 'position': 'CAM', 'number': 8},
    {'name': 'Antony', 'position': 'RW', 'number': 21},
    {'name': 'Rashford', 'position': 'LW', 'number': 10},
    {'name': 'Hojlund', 'position': 'ST', 'number': 11},
  ];

  final List<Map<String, dynamic>> _awayStartingXI = [
    {'name': 'Sanchez', 'position': 'GK', 'number': 1},
    {'name': 'James', 'position': 'RB', 'number': 24},
    {'name': 'Silva', 'position': 'CB', 'number': 6},
    {'name': 'Colwill', 'position': 'CB', 'number': 26},
    {'name': 'Chilwell', 'position': 'LB', 'number': 21},
    {'name': 'Caicedo', 'position': 'CDM', 'number': 25},
    {'name': 'Enzo', 'position': 'CM', 'number': 8},
    {'name': 'Gallagher', 'position': 'CM', 'number': 23},
    {'name': 'Sterling', 'position': 'RW', 'number': 17},
    {'name': 'Palmer', 'position': 'CAM', 'number': 20},
    {'name': 'Jackson', 'position': 'ST', 'number': 15},
  ];

  // ---------- Substitutes ----------

  final List<Map<String, dynamic>> _homeSubs = [
    {'name': 'Onana', 'position': 'GK', 'number': 24},
    {'name': 'Lindelof', 'position': 'CB', 'number': 2},
    {'name': 'Dalot', 'position': 'RB', 'number': 20},
    {'name': 'McTominay', 'position': 'CM', 'number': 39},
    {'name': 'Pellistri', 'position': 'RW', 'number': 28},
    {'name': 'Martial', 'position': 'ST', 'number': 9},
    {'name': 'Sancho', 'position': 'LW', 'number': 25},
  ];

  final List<Map<String, dynamic>> _awaySubs = [
    {'name': 'Petrovic', 'position': 'GK', 'number': 13},
    {'name': 'Disasi', 'position': 'CB', 'number': 2},
    {'name': 'Cucurella', 'position': 'LB', 'number': 3},
    {'name': 'Kovacic', 'position': 'CM', 'number': 8},
    {'name': 'Madueke', 'position': 'RW', 'number': 11},
    {'name': 'Broja', 'position': 'ST', 'number': 18},
    {'name': 'Mudryk', 'position': 'LW', 'number': 10},
  ];

  // ---------- Lifecycle ----------

  @override
  void initState() {
    super.initState();
    _subsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _subsAnimation = CurvedAnimation(
      parent: _subsAnimController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _subsAnimController.dispose();
    super.dispose();
  }

  void _toggleSubs() {
    setState(() => _showSubsPanel = !_showSubsPanel);
    if (_showSubsPanel) {
      _subsAnimController.forward();
    } else {
      _subsAnimController.reverse();
    }
  }

  // ---------- Helpers ----------

  String _getTeamAbbreviation(String teamName) {
    final n = teamName.toLowerCase();
    if (n.contains('united')) return 'MUN';
    if (n.contains('city')) return 'MCI';
    if (n.contains('chelsea')) return 'CHE';
    if (n.contains('liverpool')) return 'LIV';
    if (n.contains('arsenal')) return 'ARS';
    if (n.contains('tottenham')) return 'TOT';
    return teamName.substring(0, min(3, teamName.length)).toUpperCase();
  }

  Color _getTeamColor(String teamName) {
    final n = teamName.toLowerCase();
    if (n.contains('united')) return Colors.red;
    if (n.contains('city')) return const Color(0xFF6CABDD);
    if (n.contains('chelsea')) return const Color(0xFF034694);
    if (n.contains('liverpool')) return const Color(0xFFC8102E);
    if (n.contains('arsenal')) return const Color(0xFFEF0107);
    if (n.contains('tottenham')) return Colors.white;
    return Colors.grey.shade400;
  }

  String _shortName(String name) {
    final parts = name.split(' ');
    final last = parts.last;
    return last.length > 7 ? last.substring(0, 7) : last;
  }

  // ---------- Formation positions ----------
  // xf = fraction of container width (0.0 – 1.0)
  // y  = absolute px from top (field height = 290)
  // Away team mirrors Y: yFinal = 258 - yHome

  List<Map<String, double>> _getPlayerPositions(
    String formation,
    bool isHomeTeam,
    double containerWidth,
  ) {
    final List<Map<String, double>> raw = [];

    switch (formation) {
      case '4-3-3':
        raw.addAll([
          {'xf': 0.50, 'y': 16}, // GK
          {'xf': 0.82, 'y': 76}, // RB
          {'xf': 0.61, 'y': 76}, // CB
          {'xf': 0.39, 'y': 76}, // CB
          {'xf': 0.18, 'y': 76}, // LB
          {'xf': 0.65, 'y': 148}, // CM-R
          {'xf': 0.50, 'y': 138}, // CM-C
          {'xf': 0.35, 'y': 148}, // CM-L
          {'xf': 0.82, 'y': 218}, // RW
          {'xf': 0.50, 'y': 218}, // ST
          {'xf': 0.18, 'y': 218}, // LW
        ]);
        break;

      case '4-4-2':
        raw.addAll([
          {'xf': 0.50, 'y': 16},
          {'xf': 0.82, 'y': 76},
          {'xf': 0.61, 'y': 76},
          {'xf': 0.39, 'y': 76},
          {'xf': 0.18, 'y': 76},
          {'xf': 0.79, 'y': 150},
          {'xf': 0.59, 'y': 146},
          {'xf': 0.41, 'y': 146},
          {'xf': 0.21, 'y': 150},
          {'xf': 0.63, 'y': 218},
          {'xf': 0.37, 'y': 218},
        ]);
        break;

      case '4-2-3-1':
        raw.addAll([
          {'xf': 0.50, 'y': 16},
          {'xf': 0.82, 'y': 76},
          {'xf': 0.61, 'y': 76},
          {'xf': 0.39, 'y': 76},
          {'xf': 0.18, 'y': 76},
          {'xf': 0.62, 'y': 136},
          {'xf': 0.38, 'y': 136},
          {'xf': 0.79, 'y': 188},
          {'xf': 0.50, 'y': 184},
          {'xf': 0.21, 'y': 188},
          {'xf': 0.50, 'y': 236},
        ]);
        break;

      case '3-5-2':
        raw.addAll([
          {'xf': 0.50, 'y': 16},
          {'xf': 0.71, 'y': 76},
          {'xf': 0.50, 'y': 72},
          {'xf': 0.29, 'y': 76},
          {'xf': 0.85, 'y': 148},
          {'xf': 0.66, 'y': 144},
          {'xf': 0.50, 'y': 141},
          {'xf': 0.34, 'y': 144},
          {'xf': 0.15, 'y': 148},
          {'xf': 0.63, 'y': 218},
          {'xf': 0.37, 'y': 218},
        ]);
        break;

      case '3-4-3':
        raw.addAll([
          {'xf': 0.50, 'y': 16},
          {'xf': 0.71, 'y': 76},
          {'xf': 0.50, 'y': 72},
          {'xf': 0.29, 'y': 76},
          {'xf': 0.79, 'y': 148},
          {'xf': 0.59, 'y': 144},
          {'xf': 0.41, 'y': 144},
          {'xf': 0.21, 'y': 148},
          {'xf': 0.82, 'y': 218},
          {'xf': 0.50, 'y': 218},
          {'xf': 0.18, 'y': 218},
        ]);
        break;

      default:
        break;
    }

    return raw.map((p) {
      final double yFinal = isHomeTeam ? p['y']! : (258.0 - p['y']!);
      return {
        'x': containerWidth * p['xf']! - 25.0,
        'y': yFinal,
      };
    }).toList();
  }

  // ============================================================
  //  BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    final homeColor = _getTeamColor(widget.fixture.homeTeam);
    final awayColor = _getTeamColor(widget.fixture.awayTeam);
    final homeAbbr = _getTeamAbbreviation(widget.fixture.homeTeam);
    final awayAbbr = _getTeamAbbreviation(widget.fixture.awayTeam);

    return Material(
      color: Colors.transparent,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Center(
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ),

            // ── Header ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade800, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Team Lineups',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.fixture.homeTeam} vs ${widget.fixture.awayTeam}',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // ── SUBS BUTTON ──────────────────────────────────────
                  GestureDetector(
                    onTap: _toggleSubs,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _showSubsPanel
                            ? const Color(0xFF10B981)
                            : Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _showSubsPanel
                              ? const Color(0xFF10B981)
                              : Colors.grey.shade600,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showSubsPanel
                                ? Icons.close
                                : Icons.swap_horiz_rounded,
                            color: _showSubsPanel
                                ? Colors.white
                                : Colors.grey.shade300,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Subs',
                            style: TextStyle(
                              color: _showSubsPanel
                                  ? Colors.white
                                  : Colors.grey.shade300,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Close button
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade700),
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.grey.shade400,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Subs animated drawer ─────────────────────────────────────
            SizeTransition(
              sizeFactor: _subsAnimation,
              axisAlignment: -1,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section label
                    Row(
                      children: [
                        Container(
                          width: 3,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Text(
                          'SUBSTITUTES',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Two columns: home | away
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildSubsColumn(
                            teamName: widget.fixture.homeTeam,
                            teamColor: homeColor,
                            teamAbbr: homeAbbr,
                            subs: _homeSubs,
                          ),
                        ),
                        Container(
                          width: 0.5,
                          height: 200,
                          color: Colors.grey.shade800,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        Expanded(
                          child: _buildSubsColumn(
                            teamName: widget.fixture.awayTeam,
                            teamColor: awayColor,
                            teamAbbr: awayAbbr,
                            subs: _awaySubs,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Formation selector ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade800),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text(
                      'Formation:',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ..._formations.map((f) {
                      final selected = _selectedFormation == f;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFormation = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF10B981)
                                : Colors.grey.shade900,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF10B981)
                                  : Colors.grey.shade700,
                            ),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : Colors.grey.shade400,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // ── Main scrollable content ──────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildTeamSection(
                      teamName: widget.fixture.homeTeam,
                      teamColor: homeColor,
                      teamAbbr: homeAbbr,
                      players: _homeStartingXI,
                      isHomeTeam: true,
                    ),
                    const SizedBox(height: 20),
                    _buildVsDivider(homeColor, awayColor),
                    const SizedBox(height: 20),
                    _buildTeamSection(
                      teamName: widget.fixture.awayTeam,
                      teamColor: awayColor,
                      teamAbbr: awayAbbr,
                      players: _awayStartingXI,
                      isHomeTeam: false,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  //  WIDGETS
  // ============================================================

  Widget _buildVsDivider(Color homeColor, Color awayColor) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                homeColor.withValues(alpha: 0.6),
                Colors.green.withValues(alpha: 0.3),
              ]),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.green.withValues(alpha: 0.5),
            ),
          ),
          child: const Text(
            'VS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.green.withValues(alpha: 0.3),
                awayColor.withValues(alpha: 0.6),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  // ── Team section ────────────────────────────────────────────────────────────

  Widget _buildTeamSection({
    required String teamName,
    required Color teamColor,
    required String teamAbbr,
    required List<Map<String, dynamic>> players,
    required bool isHomeTeam,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Team header
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: teamColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: teamColor, width: 2),
              ),
              child: Center(
                child: Text(
                  teamAbbr,
                  style: TextStyle(
                    color: teamColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                teamName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                _selectedFormation,
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Field
        LayoutBuilder(
          builder: (context, constraints) {
            final fw = constraints.maxWidth;
            final positions =
                _getPlayerPositions(_selectedFormation, isHomeTeam, fw);
            return Container(
              height: 290,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.35),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: List.generate(
                    10,
                    (i) => i.isEven
                        ? const Color(0xFF1A3D1A)
                        : const Color(0xFF1E441E),
                  ),
                  stops: List.generate(10, (i) => i / 9),
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Field lines
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CustomPaint(
                        painter: _FieldMarkingsPainter(),
                      ),
                    ),
                  ),
                  // Player dots
                  ...positions.asMap().entries.map((e) {
                    if (e.key >= players.length) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
                      left: e.value['x'],
                      top: e.value['y'],
                      child: _buildPlayerDot(players[e.key], teamColor),
                    );
                  }),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // Starting XI list
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade900.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade800),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STARTING XI',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              ...players.map((p) => _buildPlayerListItem(p, teamColor)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Player dot ──────────────────────────────────────────────────────────────

  Widget _buildPlayerDot(Map<String, dynamic> player, Color teamColor) {
    return SizedBox(
      width: 50,
      height: 62,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: teamColor.withValues(alpha: 0.88),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: teamColor.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${player['number']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              _shortName(player['name'] as String),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Player list item ────────────────────────────────────────────────────────

  Widget _buildPlayerListItem(Map<String, dynamic> player, Color teamColor) {
    final rng = Random();
    final rating = '${rng.nextInt(4) + 6}.${rng.nextInt(9)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.grey.shade800.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Jersey number
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: teamColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: teamColor),
            ),
            child: Center(
              child: Text(
                '${player['number']}',
                style: TextStyle(
                  color: teamColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Name + position
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player['name'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  player['position'] as String,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          // Rating badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              rating,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Subs column (inside drawer) ─────────────────────────────────────────────

  Widget _buildSubsColumn({
    required String teamName,
    required Color teamColor,
    required String teamAbbr,
    required List<Map<String, dynamic>> subs,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Team label
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: teamColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: teamColor, width: 1.2),
              ),
              child: Center(
                child: Text(
                  teamAbbr,
                  style: TextStyle(
                    color: teamColor,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                teamName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Sub rows
        ...subs.map(
          (p) => Container(
            margin: const EdgeInsets.only(bottom: 5),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.grey.shade800.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: teamColor.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: teamColor, width: 0.8),
                  ),
                  child: Center(
                    child: Text(
                      '${p['number']}',
                      style: TextStyle(
                        color: teamColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    p['name'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  p['position'] as String,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
//  FIELD MARKINGS PAINTER
// ============================================================

class _FieldMarkingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final w = size.width;
    final h = size.height;

    // Outer border
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 4, w - 8, h - 8),
        const Radius.circular(8),
      ),
      paint,
    );

    // Half-way line
    canvas.drawLine(Offset(4, h / 2), Offset(w - 4, h / 2), paint);

    // Centre circle
    canvas.drawCircle(Offset(w / 2, h / 2), 28, paint);

    // Centre dot
    canvas.drawCircle(
      Offset(w / 2, h / 2),
      3,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill,
    );

    // Top penalty box
    final penW = w * 0.55;
    final penH = h * 0.18;
    canvas.drawRect(
      Rect.fromLTWH((w - penW) / 2, 4, penW, penH),
      paint,
    );

    // Bottom penalty box
    canvas.drawRect(
      Rect.fromLTWH((w - penW) / 2, h - 4 - penH, penW, penH),
      paint,
    );

    // Top goal box
    final gW = w * 0.28;
    final gH = h * 0.07;
    canvas.drawRect(
      Rect.fromLTWH((w - gW) / 2, 4, gW, gH),
      paint,
    );

    // Bottom goal box
    canvas.drawRect(
      Rect.fromLTWH((w - gW) / 2, h - 4 - gH, gW, gH),
      paint,
    );

    // Penalty spots
    final spotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w / 2, h * 0.14), 2.5, spotPaint);
    canvas.drawCircle(Offset(w / 2, h * 0.86), 2.5, spotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
