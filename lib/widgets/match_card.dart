// FILE: lib/widgets/match_card.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fixture_models.dart';

class MatchCard extends StatefulWidget {
  final Fixture fixture;
  final UserData? userData;
  final Function(UserData) onUserDataUpdate;

  const MatchCard({
    super.key,
    required this.fixture,
    required this.userData,
    required this.onUserDataUpdate,
  });

  @override
  State<MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<MatchCard> {
  String selectedBet = '';
  final betAmountController = TextEditingController();
  bool isLiked = false;
  int likeCount = 20;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    likeCount = 20 + (DateTime.now().millisecond % 30);
  }

  String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diffHours = date.difference(now).inHours;

      if (diffHours <= 2 && diffHours >= -2) {
        return 'LIVE';
      }

      if (date.isAfter(now)) {
        return 'In ${diffHours}h';
      }

      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'TBD';
    }
  }

  bool get isLive => formatDate(widget.fixture.date) == 'LIVE';

  Future<void> handleBetPlacement() async {
    if (selectedBet.isEmpty || betAmountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select outcome and enter stake'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final betAmount = double.tryParse(betAmountController.text) ?? 0;

    if (betAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid bet amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.userData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete your profile first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.userData!.balance < betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient balance. You need Ksh $betAmount but have Ksh ${widget.userData!.balance}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isProcessing = true);

    try {
      String selection;
      switch (selectedBet) {
        case 'homeTeam':
          selection = 'home_team';
          break;
        case 'awayTeam':
          selection = 'away_team';
          break;
        case 'draw':
          selection = 'draw';
          break;
        default:
          selection = 'draw';
      }

      final pledgeData = PledgeData(
        username: widget.userData!.username,
        phone: widget.userData!.phone,
        selection: selection,
        amount: betAmount,
        fan: 'user',
        homeTeam: widget.fixture.homeTeam,
        awayTeam: widget.fixture.awayTeam,
        starterId: widget.userData!.userId,
      );

      final betResponse = await http.post(
        Uri.parse('https://clash-api-m5mr.onrender.com/api/pledges'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(pledgeData.toJson()),
      );

      if (betResponse.statusCode != 200) {
        throw Exception('Failed to place bet');
      }

      final newBalance = widget.userData!.balance - betAmount;

      final updateResponse = await http.post(
        Uri.parse(
          'https://clash-api-m5mr.onrender.com/api/profile/update-balance',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userData!.userId,
          'balance': newBalance,
        }),
      );

      if (updateResponse.statusCode == 200) {
        final updatedUser = jsonDecode(updateResponse.body);
        final newUserData = UserData(
          userId: widget.userData!.userId,
          username: widget.userData!.username,
          phone: widget.userData!.phone,
          balance: updatedUser['balance'] ?? newBalance,
          nickname: widget.userData!.nickname,
          clubFan: widget.userData!.clubFan,
          countryFan: widget.userData!.countryFan,
          numberOfBets: widget.userData!.numberOfBets,
        );

        widget.onUserDataUpdate(newUserData);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userProfile', jsonEncode(newUserData.toJson()));

        if (mounted) {
          final selectedTeam = selectedBet == 'homeTeam'
              ? widget.fixture.homeTeam
              : selectedBet == 'awayTeam'
              ? widget.fixture.awayTeam
              : 'Draw';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎯 Bet Placed! Ksh $betAmount on $selectedTeam'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );

          setState(() {
            betAmountController.clear();
            selectedBet = '';
          });
        }
      }
    } catch (e) {
      print('Error placing bet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to place bet'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade900.withValues(alpha: 0.3),
            Colors.black.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      widget.fixture.league,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF10B981),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (isLive) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                formatDate(widget.fixture.date),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Teams
          Row(
            children: [
              // Home Team
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.grey.shade900, Colors.black],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          widget.fixture.homeTeam.substring(0, 2).toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.fixture.homeTeam,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // VS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade800),
                  ),
                  child: Center(
                    child: Text(
                      'VS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade300,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
              // Away Team
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.grey.shade900, Colors.black],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          widget.fixture.awayTeam.substring(0, 2).toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.fixture.awayTeam,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Odds Buttons
          Row(
            children: [
              Expanded(
                child: _buildOddsButton(
                  '1',
                  widget.fixture.homeWin,
                  'homeTeam',
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildOddsButton('X', widget.fixture.draw, 'draw'),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildOddsButton(
                  '2',
                  widget.fixture.awayWin,
                  'awayTeam',
                ),
              ),
            ],
          ),
          // Bet Input
          if (selectedBet.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextField(
              controller: betAmountController,
              keyboardType: TextInputType.number,
              enabled: !isProcessing,
              decoration: InputDecoration(
                hintText: 'Stake amount...',
                prefixIcon: const Icon(Icons.attach_money, size: 16),
                filled: true,
                fillColor: Colors.grey.shade900.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade800),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade800),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF10B981)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            // Quick Stakes
            Row(
              children: [
                _buildQuickStake('100'),
                const SizedBox(width: 4),
                _buildQuickStake('500'),
                const SizedBox(width: 4),
                _buildQuickStake('1000'),
                const SizedBox(width: 4),
                _buildQuickStake('5000'),
              ],
            ),
            const SizedBox(height: 6),
            // Place Bet Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isProcessing || betAmountController.text.isEmpty
                    ? null
                    : handleBetPlacement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  disabledBackgroundColor: Colors.grey.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                        'Bet Ksh ${betAmountController.text.isEmpty ? '...' : betAmountController.text}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            // Balance Info
            if (widget.userData != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bal: Ksh ${widget.userData!.balance.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  ),
                  if (betAmountController.text.isNotEmpty)
                    Text(
                      'Left: Ksh ${(widget.userData!.balance - (double.tryParse(betAmountController.text) ?? 0)).toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            (double.tryParse(betAmountController.text) ?? 0) >
                                widget.userData!.balance
                            ? Colors.red
                            : const Color(0xFF10B981),
                      ),
                    ),
                ],
              ),
            ],
          ],
          // Actions
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.grey.shade800.withValues(alpha: 0.3),
                ),
              ),
            ),
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    size: 16,
                    color: isLiked ? Colors.pink : Colors.grey.shade400,
                  ),
                  onPressed: () {
                    setState(() {
                      isLiked = !isLiked;
                      likeCount += isLiked ? 1 : -1;
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                Text(
                  '$likeCount',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.share,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.bookmark_border,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOddsButton(String label, String odds, String betType) {
    final isSelected = selectedBet == betType;
    return GestureDetector(
      onTap: () => setState(() => selectedBet = betType),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981)
              : Colors.grey.shade900.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : Colors.grey.shade700,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: isSelected ? Colors.white : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              odds,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF10B981),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStake(String amount) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          betAmountController.text = amount;
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade900.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade800),
          ),
          child: Text(
            amount.length > 3 ? '${amount.substring(0, 1)}K' : amount,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    betAmountController.dispose();
    super.dispose();
  }
}
