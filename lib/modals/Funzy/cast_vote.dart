// modals/Funzy/vote_casting_modal.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/fixture_models.dart';
import '../../pages/fan_Funzy_design.dart';
//import '../../pages/social_th.dart';
import '../../services/toast_helper.dart';
import '../../pages/fan_Funzy_design.dart';

class VoteCastingModal extends StatefulWidget {
  final Fixture fixture;
  final String userId;
  final String username;
  final String? authToken;
  final bool isLoggedIn;
  final bool hasUserVoted;
  final String? userVoteSelection;
  final Function(String) onVote;

  const VoteCastingModal({
    super.key,
    required this.fixture,
    required this.userId,
    required this.username,
    this.authToken,
    required this.isLoggedIn,
    required this.hasUserVoted,
    this.userVoteSelection,
    required this.onVote,
  });

  @override
  State<VoteCastingModal> createState() => _VoteCastingModalState();
}

class _VoteCastingModalState extends State<VoteCastingModal> {
  String? _selectedVoteOption;
  bool _isVoting = false;

  @override
  Widget build(BuildContext context) {
    if (widget.hasUserVoted) {
      return _buildAlreadyVotedView();
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: FanColors.background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandleBar(),
            _buildHeader(),
             Divider(height: 1, color: FanColors.border),
            _buildVoteOptions(),
            const SizedBox(height: 16),
            _buildBottomButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHandleBar() {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: FanColors.border.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A3E),
              shape: BoxShape.circle,
            ),
            child:  Center(
              child: Icon(
                Icons.how_to_vote,
                size: 22,
                color: FanColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cast Your Vote',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${widget.fixture.homeTeam} vs ${widget.fixture.awayTeam}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: FanColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoteOptions() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FanColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: FanColors.primary.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                 Icon(Icons.info_outline,
                    size: 16, color: FanColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pick the team you think will win this match',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildVoteOption(
            title: widget.fixture.homeTeam,
            odds: widget.fixture.homeWin,
            selection: 'home_team',
            isSelected: _selectedVoteOption == 'home_team',
            color: FanColors.surface,
            onTap: () {
              setState(() => _selectedVoteOption = 'home_team');
            },
          ),
          const SizedBox(height: 12),
          _buildVoteOption(
            title: 'Draw',
            odds: widget.fixture.draw,
            selection: 'draw',
            isSelected: _selectedVoteOption == 'draw',
            color: const Color(0xFF8B5CF6),
            onTap: () {
              setState(() => _selectedVoteOption = 'draw');
            },
          ),
          const SizedBox(height: 12),
          _buildVoteOption(
            title: widget.fixture.awayTeam,
            odds: widget.fixture.awayWin,
            selection: 'away_team',
            isSelected: _selectedVoteOption == 'away_team',
            color: const Color(0xFF2563EB),
            onTap: () {
              setState(() => _selectedVoteOption = 'away_team');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVoteOption({
    required String title,
    required double odds,
    required String selection,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : FanColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : FanColors.border.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (isSelected)
                  Icon(Icons.check_circle, color: color, size: 20),
                if (isSelected) const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? color : Colors.white,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? color : FanColors.background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                odds.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : FanColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    final canConfirm = _selectedVoteOption != null && !widget.hasUserVoted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: canConfirm && !_isVoting ? _handleVote : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: canConfirm && !_isVoting
                ? FanColors.primary
                : FanColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: _isVoting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Confirm Vote',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: canConfirm && !_isVoting
                          ? Colors.white
                          : FanColors.textSecondary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlreadyVotedView() {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: FanColors.background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandleBar(),
              const SizedBox(height: 16),
               Icon(
                Icons.check_circle,
                color: FanColors.primary,
                size: 48,
              ),
              const SizedBox(height: 12),
              const Text(
                'You already voted',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Selection: ${_getVoteDisplayText(widget.userVoteSelection)}',
                style: TextStyle(
                  fontSize: 13,
                  color: FanColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: FanColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: FanColors.border.withValues(alpha: 0.3),
                    ),
                  ),
                  child:  Center(
                    child: Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: FanColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleVote() async {
    if (_selectedVoteOption == null || widget.hasUserVoted) return;

    setState(() => _isVoting = true);

    try {
      await widget.onVote(_selectedVoteOption!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ Error voting: $e');
      ToastHelper.showError('Failed to cast vote');
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  String _getVoteDisplayText(String? selection) {
    if (selection == 'home_team') return widget.fixture.homeTeam;
    if (selection == 'away_team') return widget.fixture.awayTeam;
    if (selection == 'draw') return 'Draw';
    return selection ?? 'Unknown';
  }
}
