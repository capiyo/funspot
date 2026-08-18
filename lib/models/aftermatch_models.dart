// models/aftermatch_models.dart

import 'package:flutter/material.dart';
import '../../pages/fan_Funzy_design.dart';

// ============================================================================
// AFTERMATCH VOTER
// ============================================================================

class AftermatchVoter {
  final String userId;
  final String userName;
  final String selection;
  final DateTime votedAt;
  final bool isComrade;
  String? result;

  AftermatchVoter({
    required this.userId,
    required this.userName,
    required this.selection,
    required this.votedAt,
    this.isComrade = false,
    this.result,
  });

  factory AftermatchVoter.fromJson(Map<String, dynamic> json) {
    return AftermatchVoter(
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      userName: json['userName']?.toString() ??
          json['user_name']?.toString() ??
          'Unknown',
      selection: json['selection']?.toString() ?? '',
      votedAt: DateTime.tryParse(json['votedAt']?.toString() ??
              json['voted_at']?.toString() ??
              '') ??
          DateTime.now(),
      isComrade: json['isComrade'] ?? json['is_comrade'] ?? false,
      result: json['result']?.toString(),
    );
  }

  bool get isWinner => result == 'won';
  bool get isLoser => result == 'lost';

  Color get resultColor {
    if (result == 'won') return FanColors.primary;
    if (result == 'lost') return FanColors.away;
    return FanColors.textTertiary;
  }

  String get resultLabel {
    if (result == 'won') return '✅ Won';
    if (result == 'lost') return '❌ Lost';
    return '⏳ Pending';
  }
}

// ============================================================================
// AFTERMATCH PLEDGE
// ============================================================================

class AftermatchPledge {
  final String betId;
  final String userId;
  final String userName;
  final String selection;
  final double amount;
  final String status;
  String? result;
  final double? payout;
  final DateTime? settledAt;

  AftermatchPledge({
    required this.betId,
    required this.userId,
    required this.userName,
    required this.selection,
    required this.amount,
    required this.status,
    this.result,
    this.payout,
    this.settledAt,
  });

  factory AftermatchPledge.fromJson(Map<String, dynamic> json) {
    return AftermatchPledge(
      betId: json['betId']?.toString() ?? json['bet_id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      userName: json['userName']?.toString() ??
          json['user_name']?.toString() ??
          'Unknown',
      selection: json['selection']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'open',
      result: json['result']?.toString(),
      payout: (json['payout'] as num?)?.toDouble(),
      settledAt: DateTime.tryParse(json['settledAt']?.toString() ??
          json['settled_at']?.toString() ??
          ''),
    );
  }

  bool get isWinner => result == 'won';
  bool get isLoser => result == 'lost';
  bool get isOpen => status == 'open';

  Color get resultColor {
    if (result == 'won') return FanColors.primary;
    if (result == 'lost') return FanColors.away;
    return FanColors.textTertiary;
  }

  String get resultLabel {
    if (result == 'won') return '✅ Won';
    if (result == 'lost') return '❌ Lost';
    return '⏳ Pending';
  }
}

// ============================================================================
// AFTERMATCH BET
// ============================================================================

class AftermatchBet {
  final String id;
  final String starterId;
  final String starterName;
  final String? starterSelection;
  final double starterAmount;
  final String? finisherId;
  final String? finisherName;
  final String? finisherSelection;
  final double? finisherAmount;
  final double totalPot;
  final String status;
  final String? result;
  final double? winnerPayout;
  final DateTime createdAt;

  AftermatchBet({
    required this.id,
    required this.starterId,
    required this.starterName,
    this.starterSelection,
    required this.starterAmount,
    this.finisherId,
    this.finisherName,
    this.finisherSelection,
    this.finisherAmount,
    required this.totalPot,
    required this.status,
    this.result,
    this.winnerPayout,
    required this.createdAt,
  });

  factory AftermatchBet.fromJson(Map<String, dynamic> json) {
    return AftermatchBet(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      starterId:
          json['starterId']?.toString() ?? json['starter_id']?.toString() ?? '',
      starterName: json['starterName']?.toString() ??
          json['starter_name']?.toString() ??
          'Unknown',
      starterSelection: json['starterSelection']?.toString() ??
          json['starter_selection']?.toString(),
      starterAmount: (json['starterAmount'] as num?)?.toDouble() ??
          (json['starter_amount'] as num?)?.toDouble() ??
          0.0,
      finisherId:
          json['finisherId']?.toString() ?? json['finisher_id']?.toString(),
      finisherName:
          json['finisherName']?.toString() ?? json['finisher_name']?.toString(),
      finisherSelection: json['finisherSelection']?.toString() ??
          json['finisher_selection']?.toString(),
      finisherAmount: (json['finisherAmount'] as num?)?.toDouble() ??
          (json['finisher_amount'] as num?)?.toDouble(),
      totalPot: (json['totalPot'] as num?)?.toDouble() ??
          (json['total_pot'] as num?)?.toDouble() ??
          0.0,
      status: json['status']?.toString() ?? 'active',
      result: json['result']?.toString(),
      winnerPayout: (json['winnerPayout'] as num?)?.toDouble() ??
          (json['winner_payout'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ??
              json['created_at']?.toString() ??
              '') ??
          DateTime.now(),
    );
  }

  bool get isSettled => status == 'settled';
  bool get isActive => status == 'active';

  Color get resultColor {
    if (result == 'starter_won' || result == 'finisher_won')
      return FanColors.primary;
    if (result == 'draw') return FanColors.draw;
    return FanColors.textTertiary;
  }

  String get resultLabel {
    if (result == 'starter_won') return '✅ ${starterName} Won';
    if (result == 'finisher_won') return '✅ ${finisherName ?? 'Unknown'} Won';
    if (result == 'draw') return '⚖️ Draw';
    return '⏳ Pending';
  }
}

// ============================================================================
// AFTERMATCH DATA
// ============================================================================

class AftermatchData {
  final String fixtureId;
  final List<Map<String, dynamic>> voters;
  final List<Map<String, dynamic>> pledges;
  final List<Map<String, dynamic>> bets;
  final List<Map<String, dynamic>> subFixtures;
  final DateTime lastUpdated;
  final String? homeScore;
  final String? awayScore;
  final String? winner;

  AftermatchData({
    required this.fixtureId,
    required this.voters,
    required this.pledges,
    required this.bets,
    required this.subFixtures,
    required this.lastUpdated,
    this.homeScore,
    this.awayScore,
    this.winner,
  });

  factory AftermatchData.fromJson(Map<String, dynamic> json) {
    return AftermatchData(
      fixtureId: json['fixtureId']?.toString() ?? '',
      voters: List<Map<String, dynamic>>.from(json['voters'] ?? []),
      pledges: List<Map<String, dynamic>>.from(json['pledges'] ?? []),
      bets: List<Map<String, dynamic>>.from(json['bets'] ?? []),
      subFixtures: List<Map<String, dynamic>>.from(json['subFixtures'] ?? []),
      lastUpdated: DateTime.tryParse(json['lastUpdated']?.toString() ?? '') ??
          DateTime.now(),
      homeScore: json['homeScore']?.toString(),
      awayScore: json['awayScore']?.toString(),
      winner: json['winner']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'fixtureId': fixtureId,
        'voters': voters,
        'pledges': pledges,
        'bets': bets,
        'subFixtures': subFixtures,
        'lastUpdated': lastUpdated.toIso8601String(),
        'homeScore': homeScore,
        'awayScore': awayScore,
        'winner': winner,
      };
}
