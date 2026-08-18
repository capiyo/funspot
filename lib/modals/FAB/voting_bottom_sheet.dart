import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import '../../pages/fan_Funzy_design.dart';

// ========== TOAST HELPER ==========
class ToastHelper {
  static void showSuccess(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: FanColors.primary,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  static void showError(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  static void showInfo(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: FanColors.draw,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  static void showWarning(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.orange,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }
}

// ========== VOTING BOTTOM SHEET ==========
class VotingBottomSheet extends StatefulWidget {
  final String fixtureId;
  final String homeTeam;
  final String awayTeam;
  final double homeOdds;
  final double drawOdds;
  final double awayOdds;
  final String userId;
  final String username;
  final String? authToken;
  final VoidCallback onVoteSuccess;

  const VotingBottomSheet({
    super.key,
    required this.fixtureId,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeOdds,
    required this.drawOdds,
    required this.awayOdds,
    required this.userId,
    required this.username,
    this.authToken,
    required this.onVoteSuccess,
  });

  @override
  State<VotingBottomSheet> createState() => _VotingBottomSheetState();
}

class _VotingBottomSheetState extends State<VotingBottomSheet> {
  String? _selectedOption;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FanColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(FanRadius.xl),
          topRight: Radius.circular(FanRadius.xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: FanColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(FanSpacing.base),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: FanColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.how_to_vote,
                    size: 20,
                    color: FanColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cast Your Vote',
                    style: FanTypography.headline.copyWith(fontSize: 18),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: FanColors.surfaceElevated,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: FanColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Fixture name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FanSpacing.base),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FanColors.background,
                borderRadius: BorderRadius.circular(FanRadius.md),
                border: Border.all(
                  color: FanColors.border.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '${widget.homeTeam} vs ${widget.awayTeam}',
                style: FanTypography.title.copyWith(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          const SizedBox(height: FanSpacing.base),

          // Voting options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FanSpacing.base),
            child: Row(
              children: [
                _buildVoteOption(
                  label: 'HOME',
                  team: widget.homeTeam,
                  odds: widget.homeOdds,
                  selection: 'home_team',
                  color: FanColors.primary,
                ),
                const SizedBox(width: 8),
                _buildVoteOption(
                  label: 'DRAW',
                  team: 'Draw',
                  odds: widget.drawOdds,
                  selection: 'draw',
                  color: FanColors.draw,
                ),
                const SizedBox(width: 8),
                _buildVoteOption(
                  label: 'AWAY',
                  team: widget.awayTeam,
                  odds: widget.awayOdds,
                  selection: 'away_team',
                  color: FanColors.away,
                ),
              ],
            ),
          ),

          const SizedBox(height: FanSpacing.base),

          // Warning message
          Container(
            margin: const EdgeInsets.symmetric(horizontal: FanSpacing.base),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.amber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'You cannot change your vote after submission',
                    style: TextStyle(fontSize: 11, color: Colors.amber),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: FanSpacing.base),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(FanSpacing.base),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: FanColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: FanColors.border, width: 1),
                      ),
                      child: Center(
                        child: Text(
                          'CANCEL',
                          style: FanTypography.tag.copyWith(
                            color: FanColors.textSecondary,
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
                    onTap: _selectedOption != null && !_isLoading
                        ? () => _submitVote()
                        : null,
                    child: Opacity(
                      opacity: _selectedOption == null ? 0.5 : 1.0,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [FanColors.primary, FanColors.primaryMuted],
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'CONFIRM',
                                  style: FanTypography.tag.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildVoteOption({
    required String label,
    required String team,
    required double odds,
    required String selection,
    required Color color,
  }) {
    final isSelected = _selectedOption == selection;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedOption = selection),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(FanRadius.md),
            border: Border.all(
              color:
                  isSelected ? color : FanColors.border.withValues(alpha: 0.5),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: FanTypography.tag.copyWith(
                  color: isSelected ? color : FanColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                team,
                style: FanTypography.caption.copyWith(
                  fontSize: 11,
                  color: isSelected ? color : FanColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                odds.toStringAsFixed(2),
                style: FanTypography.body.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : FanColors.textPrimary,
                ),
              ),
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(Icons.check_circle, size: 14, color: color),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitVote() async {
    if (_selectedOption == null) return;

    setState(() => _isLoading = true);

    try {
      final voteData = {
        'voterId': widget.userId,
        'username': widget.username,
        'fixtureId': widget.fixtureId,
        'homeTeam': widget.homeTeam,
        'awayTeam': widget.awayTeam,
        'draw': 'draw',
        'selection': _selectedOption,
      };

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      if (widget.authToken != null && widget.authToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${widget.authToken}';
      }

      final response = await http
          .post(
            Uri.parse('https://clash-api-m5mr.onrender.com/api/votes/vote'),
            headers: headers,
            body: json.encode(voteData),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        ToastHelper.showSuccess('Vote submitted successfully!');

        // Archive the vote activity
        await _archiveVoteActivity();

        if (mounted) {
          Navigator.pop(context);
          widget.onVoteSuccess();
        }
      } else if (response.statusCode == 409) {
        ToastHelper.showWarning('You have already voted for this fixture');
        if (mounted) Navigator.pop(context);
      } else if (response.statusCode == 401) {
        ToastHelper.showError('Authentication failed. Please log in again.');
      } else {
        ToastHelper.showError('Failed to submit vote. Please try again.');
      }
    } catch (e) {
      ToastHelper.showError('Network error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Archive the vote activity
  Future<void> _archiveVoteActivity() async {
    try {
      final request = {
        'user_id': widget.userId,
        'username': widget.username,
        'fixture_id': widget.fixtureId,
        'home_team': widget.homeTeam,
        'away_team': widget.awayTeam,
        'activity_type': 'vote',
        'selection': _selectedOption,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      await http
          .post(
            Uri.parse(
                'https://clash-api-m5mr.onrender.com/api/archive/activity'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(request),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('✅ Vote activity archived for fixture ${widget.fixtureId}');
    } catch (e) {
      debugPrint('❌ Error archiving vote activity: $e');
    }
  }
}
