// models/fixture_models.dart
// Complete rewrite with proper history game support and timeElapsed

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import "../pages/fan_Funzy_design.dart";

// ============================================================================
// SUB-FIXTURE MODELS
// ============================================================================

enum SubFixtureType { firstYellowCard, firstGoal, firstCorner, firstOffside }

enum SubFixtureFormat { teamVsTeam, threeWay }

// ============================================================================
// SUB-FIXTURE PLEDGE MODEL - Matches Rust SubFixtureBet
// ============================================================
class SubFixturePledge {
  final String id;
  final String userId;
  final String userName;
  final String marketId;
  final String matchId;
  final String selection;
  final double amount;
  final String status; // 'open', 'matched', 'settled', 'refunded'
  final DateTime createdAt;
  final DateTime? settledAt;
  final String? result;
  final String? finisherId;
  final String? finisherName;
  final String? finisherSelection;
  final double? finisherAmount;
  final double totalPot;

  SubFixturePledge({
    required this.id,
    required this.userId,
    required this.userName,
    required this.marketId,
    required this.matchId,
    required this.selection,
    required this.amount,
    this.status = 'open',
    required this.createdAt,
    this.settledAt,
    this.result,
    this.finisherId,
    this.finisherName,
    this.finisherSelection,
    this.finisherAmount,
    this.totalPot = 0.0,
  });

  factory SubFixturePledge.fromBetJson(Map<String, dynamic> json) {
    final starterId =
        (json['starter_id'] ?? json['starterId'] ?? '').toString();
    final starterName =
        (json['starter_name'] ?? json['starterName'] ?? 'Unknown').toString();
    final starterSelection =
        (json['starter_selection'] ?? json['starterSelection'] ?? '')
            .toString();
    final starterAmount =
        (json['starter_amount'] ?? json['starterAmount'] ?? 0.0).toDouble();
    final finisherId =
        (json['finisher_id'] ?? json['finisherId'] ?? '').toString();
    final finisherName =
        (json['finisher_name'] ?? json['finisherName'] ?? '').toString();
    final finisherSelection =
        (json['finisher_selection'] ?? json['finisherSelection'] ?? '')
            .toString();
    final finisherAmount =
        (json['finisher_amount'] ?? json['finisherAmount'] ?? 0.0).toDouble();
    final totalPot = (json['total_pot'] ??
            json['totalPot'] ??
            starterAmount + finisherAmount)
        .toDouble();
    final status = (json['status'] ?? 'open').toString();

    return SubFixturePledge(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      userId: starterId,
      userName: starterName,
      marketId: (json['market_id'] ?? json['marketId'] ?? '').toString(),
      matchId: (json['match_id'] ?? json['matchId'] ?? '').toString(),
      selection: starterSelection,
      amount: starterAmount,
      status: status,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ??
              json['createdAt']?.toString() ??
              '') ??
          DateTime.now(),
      settledAt: json['settled_at'] != null
          ? DateTime.tryParse(json['settled_at'].toString())
          : (json['settledAt'] != null
              ? DateTime.tryParse(json['settledAt'].toString())
              : null),
      result: json['result']?.toString(),
      finisherId: finisherId.isNotEmpty ? finisherId : null,
      finisherName: finisherName.isNotEmpty ? finisherName : null,
      finisherSelection:
          finisherSelection.isNotEmpty ? finisherSelection : null,
      finisherAmount: finisherAmount > 0 ? finisherAmount : null,
      totalPot: totalPot,
    );
  }

  factory SubFixturePledge.fromJson(Map<String, dynamic> json) {
    return SubFixturePledge(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      userName: (json['userName'] ?? json['username'] ?? 'Unknown').toString(),
      marketId: (json['marketId'] ?? json['market_id'] ?? '').toString(),
      matchId: (json['matchId'] ?? json['match_id'] ?? '').toString(),
      selection: (json['selection'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: (json['status'] ?? 'open').toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ??
              json['created_at']?.toString() ??
              '') ??
          DateTime.now(),
      settledAt: json['settledAt'] != null
          ? DateTime.tryParse(json['settledAt'].toString())
          : (json['settled_at'] != null
              ? DateTime.tryParse(json['settled_at'].toString())
              : null),
      result: json['result']?.toString(),
      finisherId:
          json['finisherId']?.toString() ?? json['finisher_id']?.toString(),
      finisherName:
          json['finisherName']?.toString() ?? json['finisher_name']?.toString(),
      finisherSelection: json['finisherSelection']?.toString() ??
          json['finisher_selection']?.toString(),
      finisherAmount: (json['finisherAmount'] as num?)?.toDouble() ??
          json['finisher_amount']?.toDouble(),
      totalPot: (json['totalPot'] as num?)?.toDouble() ??
          json['total_pot']?.toDouble() ??
          0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'userId': userId,
        'userName': userName,
        'marketId': marketId,
        'matchId': matchId,
        'selection': selection,
        'amount': amount,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'settledAt': settledAt?.toIso8601String(),
        'result': result,
        'finisherId': finisherId,
        'finisherName': finisherName,
        'finisherSelection': finisherSelection,
        'finisherAmount': finisherAmount,
        'totalPot': totalPot,
      };

  bool get isOpen => status == 'open';
  bool get isMatched => status == 'matched';
  bool get isSettled => status == 'settled';
  bool get isRefunded => status == 'refunded';

  String get selectionDisplay {
    switch (selection) {
      case 'home':
        return 'Home';
      case 'away':
        return 'Away';
      case 'none':
        return 'None';
      case 'over':
        return 'Over';
      case 'under':
        return 'Under';
      default:
        return selection;
    }
  }

  Color get selectionColor {
    switch (selection) {
      case 'home':
        return FanColors.primary;
      case 'away':
        return FanColors.away;
      case 'none':
        return FanColors.textTertiary;
      case 'over':
        return FanColors.primary;
      case 'under':
        return FanColors.away;
      default:
        return FanColors.textTertiary;
    }
  }
}

// ============================================================
// SUB-FIXTURE SERVICE - Matches Rust Routes
// ============================================================
class SubFixtureService {
  static const String _api = 'https://clash-api-m5mr.onrender.com/api';
  static const Duration _timeout = Duration(seconds: 15);

  static Future<List<SubFixturePledge>> getOpenBets(
      {required String matchId, String? authToken}) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };
      final response = await http
          .get(
            Uri.parse('$_api/sub-fixture/bets/open/$matchId'),
            headers: headers,
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final bets = data['bets'] as List? ?? [];
        return bets
            .map((bet) =>
                SubFixturePledge.fromBetJson(bet as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching open sub-fixture bets: $e');
      return [];
    }
  }

  static Future<List<SubFixturePledge>> getMarketBets(
      {required String matchId,
      required String marketId,
      String? authToken}) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };
      final response = await http
          .get(
            Uri.parse('$_api/sub-fixture/bets/market/$matchId/$marketId'),
            headers: headers,
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final bets = data['bets'] as List? ?? [];
        return bets
            .map((bet) =>
                SubFixturePledge.fromBetJson(bet as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching market sub-fixture bets: $e');
      return [];
    }
  }

  static Future<List<SubFixturePledge>> getUserBets(
      {required String userId, String? authToken}) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };
      final response = await http
          .get(
            Uri.parse('$_api/sub-fixture/bets/user/$userId'),
            headers: headers,
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final bets = data['bets'] as List? ?? [];
        return bets
            .map((bet) =>
                SubFixturePledge.fromBetJson(bet as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching user sub-fixture bets: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> getMarketDetails(
      {required String matchId,
      required String marketId,
      String? authToken}) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };
      final response = await http
          .get(
            Uri.parse('$_api/sub_fixtures/markets/$matchId/$marketId'),
            headers: headers,
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {};
    } catch (e) {
      debugPrint('❌ Error fetching market details: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> placeBet({
    required String matchId,
    required String marketId,
    required String userId,
    required String userName,
    required String selection,
    required double amount,
    String? authToken,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };
      final response = await http
          .post(
            Uri.parse('$_api/sub-fixture/bet'),
            headers: headers,
            body: json.encode({
              'match_id': matchId,
              'market_id': marketId,
              'starter_id': userId,
              'starter_name': userName,
              'selection': selection,
              'amount': amount,
            }),
          )
          .timeout(_timeout);
      return json.decode(response.body);
    } catch (e) {
      debugPrint('❌ Error placing sub-fixture bet: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> fillBet({
    required String betId,
    required String matchId,
    required String marketId,
    required String finisherId,
    required String finisherName,
    required String selection,
    required double amount,
    String? authToken,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };
      final response = await http
          .post(
            Uri.parse('$_api/sub-fixture/bet/$betId/fill'),
            headers: headers,
            body: json.encode({
              'match_id': matchId,
              'market_id': marketId,
              'finisher_id': finisherId,
              'finisher_name': finisherName,
              'selection': selection,
              'amount': amount,
            }),
          )
          .timeout(_timeout);
      return json.decode(response.body);
    } catch (e) {
      debugPrint('❌ Error filling sub-fixture bet: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}

// ============================================================================
// BET MODEL
// ============================================================================

class Bet {
  final String id;
  final String fixtureId;
  final String starterId;
  final String starterName;
  final String starterSelection;
  final double starterAmount;
  final String? finisherId;
  final String? finisherName;
  final String? finisherSelection;
  final double? finisherAmount;
  final String channelId;
  final String status;
  final String? winnerId;
  final String? starterResult;
  final String? finisherResult;
  final DateTime createdAt;
  final DateTime? matchedAt;
  final DateTime? settledAt;

  Bet({
    required this.id,
    required this.fixtureId,
    required this.starterId,
    required this.starterName,
    required this.starterSelection,
    required this.starterAmount,
    this.finisherId,
    this.finisherName,
    this.finisherSelection,
    this.finisherAmount,
    required this.channelId,
    required this.status,
    this.winnerId,
    this.starterResult,
    this.finisherResult,
    required this.createdAt,
    this.matchedAt,
    this.settledAt,
  });

  static DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    try {
      if (dateValue is Map && dateValue['\$date'] != null) {
        final dateObj = dateValue['\$date'];
        if (dateObj is Map && dateObj['\$numberLong'] != null) {
          final timestamp = int.tryParse(dateObj['\$numberLong'].toString());
          if (timestamp != null) {
            return DateTime.fromMillisecondsSinceEpoch(timestamp);
          }
        }
        if (dateObj is String) {
          return DateTime.parse(dateObj);
        }
      }
      if (dateValue is String) {
        return DateTime.parse(dateValue);
      }
      return DateTime.now();
    } catch (e) {
      debugPrint('⚠️ Date parse error: $e for value: $dateValue');
      return DateTime.now();
    }
  }

  factory Bet.fromJson(Map<String, dynamic> json) {
    return Bet(
      id: json['_id']?['\$oid']?.toString() ?? json['id']?.toString() ?? '',
      fixtureId: json['fixture_id']?.toString() ?? '',
      starterId: json['starter_id']?.toString() ?? '',
      starterName: json['starter_name']?.toString() ?? '',
      starterSelection: json['starter_selection']?.toString() ?? '',
      starterAmount: (json['starter_amount'] ?? 0.0).toDouble(),
      finisherId: json['finisher_id']?.toString(),
      finisherName: json['finisher_name']?.toString(),
      finisherSelection: json['finisher_selection']?.toString(),
      finisherAmount: (json['finisher_amount'] as num?)?.toDouble(),
      channelId: json['channel_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      winnerId: json['winner_id']?.toString(),
      starterResult: json['starter_result']?.toString(),
      finisherResult: json['finisher_result']?.toString(),
      createdAt: _parseDate(json['created_at']),
      matchedAt:
          json['matched_at'] != null ? _parseDate(json['matched_at']) : null,
      settledAt:
          json['settled_at'] != null ? _parseDate(json['settled_at']) : null,
    );
  }

  bool get isOpen => status == 'open';
  bool get isMatched => status == 'matched';
  bool get isSettled => status == 'settled';
  bool get isActive => status == 'open' || status == 'matched';
  double get totalPot => starterAmount + (finisherAmount ?? 0.0);
}

// ============================================================================
// BETTOR MODEL
// ============================================================================

class Bettor {
  final String userId;
  final String userName;
  final String selection;
  final double amount;
  final String? opponentId;
  final String? opponentName;
  final String? opponentSelection;
  final double? opponentAmount;
  final double? totalPot;
  final String betId;
  final String? status;
  final bool? winner;
  final double? payout;
  final DateTime matchedAt;
  final DateTime? resolvedAt;
  final DateTime? createdAt;

  Bettor({
    required this.userId,
    required this.userName,
    required this.selection,
    required this.amount,
    this.opponentId,
    this.opponentName,
    this.opponentSelection,
    this.opponentAmount,
    this.totalPot,
    required this.betId,
    this.status,
    this.winner,
    this.payout,
    required this.matchedAt,
    this.resolvedAt,
    this.createdAt,
  });

  static DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    try {
      if (dateValue is Map && dateValue['\$date'] != null) {
        final dateObj = dateValue['\$date'];
        if (dateObj is Map && dateObj['\$numberLong'] != null) {
          final timestamp = int.tryParse(dateObj['\$numberLong'].toString());
          if (timestamp != null) {
            return DateTime.fromMillisecondsSinceEpoch(timestamp);
          }
        }
        if (dateObj is String) {
          return DateTime.parse(dateObj);
        }
      }
      if (dateValue is String) {
        return DateTime.parse(dateValue);
      }
      return DateTime.now();
    } catch (e) {
      debugPrint('⚠️ Date parse error: $e for value: $dateValue');
      return DateTime.now();
    }
  }

  static String _mapSelection(String selection) {
    switch (selection) {
      case 'home':
        return 'home_team';
      case 'away':
        return 'away_team';
      case 'draw':
        return 'draw';
      default:
        return selection;
    }
  }

  factory Bettor.fromOpenBet(Map<String, dynamic> json) {
    String betId = '';
    final idValue = json['_id'];
    if (idValue is String) {
      betId = idValue;
    } else if (idValue is Map && idValue['\$oid'] != null) {
      betId = idValue['\$oid'].toString();
    } else if (json['id'] != null) {
      betId = json['id'].toString();
    }

    return Bettor(
      userId: json['starter_id']?.toString() ?? '',
      userName: json['starter_name']?.toString() ?? 'Anonymous',
      selection: _mapSelection(json['starter_selection']?.toString() ?? ''),
      amount: (json['starter_amount'] as num?)?.toDouble() ?? 0.0,
      opponentId: null,
      opponentName: null,
      opponentSelection: null,
      opponentAmount: null,
      totalPot: null,
      betId: betId,
      status: 'open',
      winner: null,
      payout: null,
      matchedAt: _parseDate(json['created_at']),
      resolvedAt: null,
      createdAt: _parseDate(json['created_at']),
    );
  }

  factory Bettor.fromMatchedBet(Map<String, dynamic> json, String userId) {
    final isStarter = json['starter_id']?.toString() == userId;
    final starterAmount = (json['starter_amount'] as num?)?.toDouble() ?? 0.0;
    final finisherAmount = (json['finisher_amount'] as num?)?.toDouble() ?? 0.0;
    final totalPot = starterAmount + finisherAmount;

    String betId = '';
    final idValue = json['_id'];
    if (idValue is String) {
      betId = idValue;
    } else if (idValue is Map && idValue['\$oid'] != null) {
      betId = idValue['\$oid'].toString();
    } else if (json['id'] != null) {
      betId = json['id'].toString();
    }

    return Bettor(
      userId: isStarter
          ? json['starter_id']?.toString() ?? ''
          : json['finisher_id']?.toString() ?? '',
      userName: isStarter
          ? json['starter_name']?.toString() ?? 'Anonymous'
          : json['finisher_name']?.toString() ?? 'Anonymous',
      selection: isStarter
          ? _mapSelection(json['starter_selection']?.toString() ?? '')
          : _mapSelection(json['finisher_selection']?.toString() ?? ''),
      amount: isStarter ? starterAmount : finisherAmount,
      opponentId: isStarter
          ? json['finisher_id']?.toString()
          : json['starter_id']?.toString(),
      opponentName: isStarter
          ? json['finisher_name']?.toString()
          : json['starter_name']?.toString(),
      opponentSelection: isStarter
          ? _mapSelection(json['finisher_selection']?.toString() ?? '')
          : _mapSelection(json['starter_selection']?.toString() ?? ''),
      opponentAmount: isStarter ? finisherAmount : starterAmount,
      totalPot: totalPot,
      betId: betId,
      status: json['status']?.toString() ?? 'open',
      winner: json['winner_id']?.toString() == json['starter_id']?.toString(),
      payout: null,
      matchedAt: _parseDate(json['matched_at']),
      resolvedAt:
          json['settled_at'] != null ? _parseDate(json['settled_at']) : null,
      createdAt: _parseDate(json['created_at']),
    );
  }

  factory Bettor.fromJson(Map<String, dynamic> json) {
    final isOpenBet =
        json['finisher_id'] == null || json['finisher_id']?.toString() == '';
    if (isOpenBet) {
      return Bettor.fromOpenBet(json);
    } else {
      final userId =
          json['userId']?.toString() ?? json['starter_id']?.toString() ?? '';
      return Bettor.fromMatchedBet(json, userId);
    }
  }

  factory Bettor.createPledge({
    required String userId,
    required String userName,
    required String selection,
    required double amount,
  }) {
    return Bettor(
      userId: userId,
      userName: userName,
      selection: selection,
      amount: amount,
      opponentId: null,
      opponentName: null,
      opponentSelection: null,
      opponentAmount: null,
      totalPot: null,
      betId: '',
      status: 'open',
      winner: null,
      payout: null,
      matchedAt: DateTime.now(),
      resolvedAt: null,
      createdAt: DateTime.now(),
    );
  }

  bool get isOpen => status == 'open' || status == null;
  bool get isMatched => status == 'matched';
  bool get isSettled => status == 'settled';
  bool get isActive => status == 'open' || status == 'matched';
  bool get isWon => winner == true;
  bool get isLost => winner == false;
  bool get isResolved => resolvedAt != null;
  bool get isPledge => opponentId == null && status == 'open';

  String get statusDisplay {
    if (isOpen) return '💰 Open';
    if (isWon) return '🏆 Won';
    if (isLost) return '💔 Lost';
    return '⚡ Active';
  }

  Color get statusColor {
    if (isOpen) return Colors.amber;
    if (isWon) return Colors.green;
    if (isLost) return Colors.red;
    return Colors.orange;
  }

  String get selectionDisplay {
    if (selection == 'home_team') return '🏠 Home';
    if (selection == 'away_team') return '✈️ Away';
    if (selection == 'draw') return '🤝 Draw';
    return selection;
  }

  String get opponentSelectionDisplay {
    if (opponentSelection == 'home_team') return '🏠 Home';
    if (opponentSelection == 'away_team') return '✈️ Away';
    if (opponentSelection == 'draw') return '🤝 Draw';
    return opponentSelection ?? 'Unknown';
  }

  double get potentialWinnings => totalPot ?? amount;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'selection': selection,
      'amount': amount,
      'opponentId': opponentId,
      'opponentName': opponentName,
      'opponentSelection': opponentSelection,
      'opponentAmount': opponentAmount,
      'totalPot': totalPot,
      'betId': betId,
      'status': status,
      'winner': winner,
      'payout': payout,
      'matchedAt': matchedAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

// ============================================================================
// VOTER MODEL
// ============================================================================

class Voter {
  final String userId;
  final String userName;
  final String selection;
  final bool? isCorrect;
  final int? pointsAwarded;
  final bool isComrade;
  final DateTime votedAt;

  Voter({
    required this.userId,
    required this.userName,
    required this.selection,
    this.isCorrect,
    this.pointsAwarded,
    this.isComrade = false,
    required this.votedAt,
  });

  factory Voter.fromJson(Map<String, dynamic> json) {
    return Voter(
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      userName: json['user_name']?.toString() ??
          json['userName']?.toString() ??
          'Anonymous',
      selection: json['selection']?.toString() ?? '',
      isCorrect: json['is_correct'] as bool? ?? json['isCorrect'] as bool?,
      pointsAwarded:
          json['points_awarded'] as int? ?? json['pointsAwarded'] as int?,
      isComrade:
          json['is_comrade'] as bool? ?? json['isComrade'] as bool? ?? false,
      votedAt: _parseDate(json['voted_at'] ?? json['votedAt']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    try {
      if (value is String) return DateTime.parse(value);
      if (value is Map) {
        final dateObj = value['\$date'];
        if (dateObj is Map && dateObj['\$numberLong'] != null) {
          final timestamp = int.tryParse(dateObj['\$numberLong'].toString());
          if (timestamp != null)
            return DateTime.fromMillisecondsSinceEpoch(timestamp);
        }
      }
      return DateTime.now();
    } catch (_) {
      return DateTime.now();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'selection': selection,
      'isCorrect': isCorrect,
      'pointsAwarded': pointsAwarded,
      'isComrade': isComrade,
      'votedAt': votedAt.toIso8601String(),
    };
  }

  String get selectionDisplay {
    if (selection == 'home_team') return '🏠 Home';
    if (selection == 'away_team') return '✈️ Away';
    if (selection == 'draw') return '🤝 Draw';
    return selection;
  }
}

// ============================================================================
// SUB-FIXTURE MODEL
// ============================================================================

class SubFixture {
  final String id;
  final String parentFixtureId;
  final SubFixtureType type;
  final SubFixtureFormat format;
  final String question;
  final String optionA;
  final String optionB;
  final String? optionC;
  final double oddsA;
  final double oddsB;
  final double? oddsC;
  final bool isActive;
  final int displayOrder;
  final IconData icon;

  SubFixture({
    required this.id,
    required this.parentFixtureId,
    required this.type,
    required this.format,
    required this.question,
    required this.optionA,
    required this.optionB,
    this.optionC,
    required this.oddsA,
    required this.oddsB,
    this.oddsC,
    required this.isActive,
    required this.displayOrder,
    required this.icon,
  });

  factory SubFixture.fromJson(Map<String, dynamic> json) {
    final typeValue = json['type'] ?? json['fixture_type'] ?? 'first_yellow';
    final type = _parseSubFixtureType(typeValue);

    return SubFixture(
      id: json['sub_fixture_id'] ?? json['id'] ?? '',
      parentFixtureId:
          json['parent_fixture_id'] ?? json['parentFixtureId'] ?? '',
      type: type,
      format: _parseSubFixtureFormat(json['format']),
      question: json['question'] ?? '',
      optionA: json['option_a'] ?? json['optionA'] ?? '',
      optionB: json['option_b'] ?? json['optionB'] ?? '',
      optionC: json['option_c'] ?? json['optionC'],
      oddsA: _parseDouble(json['odds_a'] ?? json['oddsA'] ?? 0.0),
      oddsB: _parseDouble(json['odds_b'] ?? json['oddsB'] ?? 0.0),
      oddsC: _parseNullableDouble(json['odds_c'] ?? json['oddsC']),
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      displayOrder: json['display_order'] ?? json['displayOrder'] ?? 0,
      icon: _getIconForType(type),
    );
  }

  static SubFixtureType _parseSubFixtureType(String? type) {
    switch (type) {
      case 'first_yellow':
      case 'first_yellow_card':
        return SubFixtureType.firstYellowCard;
      case 'first_goal':
        return SubFixtureType.firstGoal;
      case 'first_corner':
        return SubFixtureType.firstCorner;
      case 'first_offside':
        return SubFixtureType.firstOffside;
      default:
        return SubFixtureType.firstYellowCard;
    }
  }

  String getBackendType() {
    switch (type) {
      case SubFixtureType.firstYellowCard:
        return 'first_yellow_card';
      case SubFixtureType.firstGoal:
        return 'first_goal';
      case SubFixtureType.firstCorner:
        return 'first_corner';
      case SubFixtureType.firstOffside:
        return 'first_offside';
    }
  }

  static SubFixtureFormat _parseSubFixtureFormat(String? format) {
    switch (format) {
      case 'team_vs_team':
        return SubFixtureFormat.teamVsTeam;
      case 'three_way':
        return SubFixtureFormat.threeWay;
      default:
        return SubFixtureFormat.teamVsTeam;
    }
  }

  static IconData _getIconForType(SubFixtureType type) {
    switch (type) {
      case SubFixtureType.firstYellowCard:
        return Icons.warning_amber_rounded;
      case SubFixtureType.firstGoal:
        return Icons.sports_soccer;
      case SubFixtureType.firstCorner:
        return Icons.flag;
      case SubFixtureType.firstOffside:
        return Icons.outlined_flag;
    }
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'sub_fixture_id': id,
      'parent_fixture_id': parentFixtureId,
      'fixture_type': getBackendType(),
      'question': question,
      'option_a': optionA,
      'option_b': optionB,
      'option_c': optionC,
      'odds_a': oddsA,
      'odds_b': oddsB,
      'odds_c': oddsC,
      'is_active': isActive,
      'display_order': displayOrder,
    };
  }
}

// ============================================================================
// MAIN FIXTURE MODEL - UPDATED WITH timeElapsed
// ============================================================================

class Fixture {
  final String id;
  final String matchId;
  final String homeTeam;
  final String awayTeam;
  final String league;
  final double homeWin;
  final double awayWin;
  final double draw;
  final String date;
  final String time;
  final int? homeScore;
  final int? awayScore;
  final String status;
  final bool isLive;
  final bool availableForVoting;
  final String source;
  final DateTime scrapedAt;
  final String dateIso;
  final String? result;
  final int votes;
  final List<Voter> voters;
  final int pledges;
  final List<Bettor> pledgers;
  final int bets;
  final List<Bettor> bettors;
  List<SubFixture> subFixtures;

  // ✅ ONLY timeElapsed - single source of truth for match time
  final double? timeElapsed;

  Fixture({
    required this.id,
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
    required this.league,
    required this.homeWin,
    required this.awayWin,
    required this.draw,
    required this.date,
    required this.time,
    this.homeScore,
    this.awayScore,
    required this.status,
    required this.isLive,
    required this.availableForVoting,
    required this.source,
    required this.scrapedAt,
    required this.dateIso,
    this.result,
    this.votes = 0,
    this.voters = const [],
    this.pledges = 0,
    this.pledgers = const [],
    this.bets = 0,
    this.bettors = const [],
    this.subFixtures = const [],
    this.timeElapsed,
  });

  static DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    try {
      if (dateValue is Map && dateValue['\$date'] != null) {
        final dateObj = dateValue['\$date'];
        if (dateObj is Map && dateObj['\$numberLong'] != null) {
          final timestamp = int.tryParse(dateObj['\$numberLong'].toString());
          if (timestamp != null) {
            return DateTime.fromMillisecondsSinceEpoch(timestamp);
          }
        }
        if (dateObj is String) {
          return DateTime.parse(dateObj);
        }
      }
      if (dateValue is String) {
        return DateTime.parse(dateValue);
      }
      return DateTime.now();
    } catch (e) {
      debugPrint('⚠️ Date parse error: $e for value: $dateValue');
      return DateTime.now();
    }
  }

  factory Fixture.fromJson(Map<String, dynamic> json) {
    String id;
    if (json['_id'] is String) {
      id = json['_id'];
    } else if (json['_id'] is Map) {
      id = json['_id']['\$oid']?.toString() ??
          json['_id']['oid']?.toString() ??
          '';
    } else {
      id = json['_id']?.toString() ?? '';
    }

    DateTime scrapedAt = _parseDate(json['scrapedAt'] ?? json['scraped_at']);

    List<Voter> voters = [];
    if (json['voters'] is List) {
      try {
        voters = (json['voters'] as List)
            .map((e) => Voter.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    List<Bettor> pledgers = [];
    if (json['pledgers'] is List) {
      try {
        pledgers = (json['pledgers'] as List)
            .map((e) => Bettor.fromOpenBet(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    List<Bettor> bettors = [];
    if (json['bettors'] is List) {
      try {
        bettors = (json['bettors'] as List)
            .map((e) => Bettor.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    List<SubFixture> subFixtures = [];
    if (json['subFixtures'] is List) {
      try {
        subFixtures = (json['subFixtures'] as List)
            .map((e) => SubFixture.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    // ✅ Parse timeElapsed from JSON (supports both camelCase and snake_case)
    double? timeElapsed;
    if (json['timeElapsed'] != null) {
      timeElapsed = (json['timeElapsed'] as num?)?.toDouble();
    } else if (json['time_elapsed'] != null) {
      timeElapsed = (json['time_elapsed'] as num?)?.toDouble();
    }

    return Fixture(
      id: id,
      matchId:
          json['matchId']?.toString() ?? json['match_id']?.toString() ?? '',
      homeTeam:
          json['homeTeam']?.toString() ?? json['home_team']?.toString() ?? '',
      awayTeam:
          json['awayTeam']?.toString() ?? json['away_team']?.toString() ?? '',
      league: json['league']?.toString() ?? '',
      homeWin: _parseDouble(json['homeWin'] ?? json['home_win']),
      awayWin: _parseDouble(json['awayWin'] ?? json['away_win']),
      draw: _parseDouble(json['draw']),
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      homeScore: _parseNullableInt(json['homeScore'] ?? json['home_score']),
      awayScore: _parseNullableInt(json['awayScore'] ?? json['away_score']),
      status: json['status']?.toString() ?? 'upcoming',
      isLive: json['isLive'] as bool? ?? json['is_live'] as bool? ?? false,
      availableForVoting: json['availableForVoting'] as bool? ??
          json['available_for_voting'] as bool? ??
          true,
      source: json['source']?.toString() ?? '',
      scrapedAt: scrapedAt,
      dateIso:
          json['dateIso']?.toString() ?? json['date_iso']?.toString() ?? '',
      result: json['result']?.toString(),
      votes: json['votes'] as int? ?? 0,
      voters: voters,
      pledges: json['pledges'] as int? ?? 0,
      pledgers: pledgers,
      bets: json['bets'] as int? ?? 0,
      bettors: bettors,
      subFixtures: subFixtures,
      timeElapsed: timeElapsed,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'match_id': matchId,
      'home_team': homeTeam,
      'away_team': awayTeam,
      'league': league,
      'home_win': homeWin,
      'away_win': awayWin,
      'draw': draw,
      'date': date,
      'time': time,
      'home_score': homeScore,
      'away_score': awayScore,
      'status': status,
      'is_live': isLive,
      'available_for_voting': availableForVoting,
      'source': source,
      'scraped_at': scrapedAt.toIso8601String(),
      'date_iso': dateIso,
      'result': result,
      'votes': votes,
      'voters': voters.map((v) => v.toJson()).toList(),
      'pledges': pledges,
      'pledgers': pledgers.map((p) => p.toJson()).toList(),
      'bets': bets,
      'bettors': bettors.map((b) => b.toJson()).toList(),
      'subFixtures': subFixtures.map((sf) => sf.toJson()).toList(),
      'timeElapsed': timeElapsed,
    };
  }

  bool get isUpcoming => status == 'upcoming';
  bool get isSoon => status == 'soon';
  bool get isCompleted => status == 'completed';
  bool get hasScores => homeScore != null && awayScore != null;

  String get scoreDisplay => hasScores ? '$homeScore - $awayScore' : '';
  String get formattedDateTime => '$date $time'.trim();
  String get displayDate => dateIso.isNotEmpty ? dateIso : '$date $time';

  double get totalPledgedAmount =>
      pledgers.fold(0.0, (sum, p) => sum + p.amount);
  double get totalBetAmount => bettors.fold(0.0, (sum, b) => sum + b.amount);
  double get totalBetPot =>
      bettors.fold(0.0, (sum, b) => sum + (b.totalPot ?? 0.0));

  List<Bettor> getPledgersBySelection(String selection) =>
      pledgers.where((p) => p.selection == selection).toList();
  List<Bettor> getBettorsBySelection(String selection) =>
      bettors.where((b) => b.selection == selection).toList();

  bool isUserPledger(String userId) => pledgers.any((p) => p.userId == userId);
  bool isUserBettor(String userId) => bettors.any((b) => b.userId == userId);

  Bettor? getUserBet(String userId) {
    try {
      return bettors.firstWhere((b) => b.userId == userId);
    } catch (_) {
      return null;
    }
  }

  Bettor? getUserPledge(String userId) {
    try {
      return pledgers.firstWhere((p) => p.userId == userId);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // 🔥 TIME DISPLAY METHODS - Using timeElapsed only
  // ============================================================

  /// Get formatted minute display from timeElapsed
  String getFormattedMinuteDisplay() {
    if (timeElapsed == null) return '';

    final minutes = timeElapsed!.floor();
    final seconds = ((timeElapsed! % 1) * 60).round();

    if (status == 'half_time' || minutes == 45) {
      return 'Half Time';
    }
    if (minutes >= 90 && minutes < 120) {
      final etMinutes = minutes - 90;
      if (etMinutes == 0) {
        return 'Full Time';
      }
      return 'ET ${etMinutes}\'';
    }
    if (minutes >= 120) {
      return 'Penalties';
    }

    // Show with seconds if available
    if (seconds > 0) {
      return "${minutes}'${seconds.toString().padLeft(2, '0')}";
    }
    return "${minutes}'";
  }

  /// Get color for minute display
  Color getMinuteDisplayColor() {
    final display = getFormattedMinuteDisplay();
    if (display == 'Half Time') return Colors.orange;
    if (display == 'Full Time') return Colors.red;
    if (display.startsWith('ET')) return Colors.purple.shade300;
    if (display == 'Penalties') return Colors.red;
    if (timeElapsed != null && timeElapsed! > 0) return Colors.white70;
    return Colors.grey.withAlpha(100);
  }

  /// Get minutes as integer (floor of timeElapsed)
  int get minutesPlayed => timeElapsed?.floor() ?? 0;

  /// Check if match is at half time
  bool get isHalfTime =>
      status == 'half_time' ||
      (timeElapsed != null && timeElapsed!.floor() == 45);

  /// Check if match is in extra time
  bool get isExtraTime =>
      timeElapsed != null && timeElapsed! >= 90 && timeElapsed! < 120;

  /// Check if match is in penalties
  bool get isPenalties => timeElapsed != null && timeElapsed! >= 120;

  /// Check if match is full time
  bool get isFullTime =>
      status == 'completed' || (timeElapsed != null && timeElapsed! >= 90);
}

// ============================================================================
// EXTENSION METHODS
// ============================================================================

extension GameExtension on Fixture {
  String get winner {
    if (hasScores) {
      if (homeScore! > awayScore!) return homeTeam;
      if (awayScore! > homeScore!) return awayTeam;
      return 'Draw';
    }
    return 'Unknown';
  }

  Color get winnerColor {
    if (hasScores) {
      if (homeScore! > awayScore!) return const Color(0xFF10B981);
      if (awayScore! > homeScore!) return const Color(0xFF3B82F6);
      return const Color(0xFF8B5CF6);
    }
    return Colors.grey;
  }

  int get totalPledgeParticipants => pledgers.length + bettors.length;
  double get totalMoneyInvolved => totalPledgedAmount + totalBetPot;
}

// ============================================================================
// ACTIVE FIXTURE (for UI)
// ============================================================================

class ActiveFixture {
  final String fixtureId;
  final String homeTeam;
  final String awayTeam;
  final String league;
  final String date;
  final int commentCount;
  final int voteCount;
  final String? latestComment;
  final String? latestCommenter;
  bool hasUserJoined;

  ActiveFixture({
    required this.fixtureId,
    required this.homeTeam,
    required this.awayTeam,
    required this.league,
    required this.date,
    this.commentCount = 0,
    this.voteCount = 0,
    this.latestComment,
    this.latestCommenter,
    this.hasUserJoined = false,
  });
}

// ============================================================================
// HISTORY GAME MODEL - UPDATED WITH timeElapsed
// ============================================================================

class HistoryGame {
  final String id;
  final String matchId;
  final String? threesixtyfiveGameId;
  final String homeTeam;
  final String awayTeam;
  final String league;
  final double? homeWin;
  final double? awayWin;
  final double? draw;
  final String date;
  final String time;
  final String dateIso;
  final DateTime kickoffUtc;
  final int? homeScore;
  final int? awayScore;
  final String status;
  final bool isLive;
  final bool availableForVoting;
  final double? timeElapsed; // ✅ ONLY timeElapsed
  final String? result;
  final String? source;
  final DateTime? scrapedAt;
  final DateTime? lastScrapedAt;
  final DateTime? lastPolledAt;
  final List<dynamic> commentary;
  final DateTime? lastCommentaryAt;
  final dynamic lineups;
  final bool? lineupsFetched;
  final DateTime? lineupsFetchedAt;
  final List<dynamic> statistics;
  final int? lastStatisticsMinute;
  final List<String> forwardedEventSignatures;
  final DateTime completedAt;
  final bool movedToHistory;
  final DateTime createdAt;

  HistoryGame({
    required this.id,
    required this.matchId,
    this.threesixtyfiveGameId,
    required this.homeTeam,
    required this.awayTeam,
    required this.league,
    this.homeWin,
    this.awayWin,
    this.draw,
    required this.date,
    required this.time,
    required this.dateIso,
    required this.kickoffUtc,
    this.homeScore,
    this.awayScore,
    required this.status,
    required this.isLive,
    required this.availableForVoting,
    this.timeElapsed,
    this.result,
    this.source,
    this.scrapedAt,
    this.lastScrapedAt,
    this.lastPolledAt,
    this.commentary = const [],
    this.lastCommentaryAt,
    this.lineups,
    this.lineupsFetched,
    this.lineupsFetchedAt,
    this.statistics = const [],
    this.lastStatisticsMinute,
    this.forwardedEventSignatures = const [],
    required this.completedAt,
    required this.movedToHistory,
    required this.createdAt,
  });

  static DateTime? _parseMongoDate(dynamic value) {
    if (value == null) return null;
    try {
      if (value is DateTime) return value;
      if (value is String) {
        return DateTime.parse(value);
      }
      if (value is Map) {
        final dateObj = value['\$date'];
        if (dateObj != null) {
          if (dateObj is Map && dateObj['\$numberLong'] != null) {
            final timestamp = int.tryParse(dateObj['\$numberLong'].toString());
            if (timestamp != null) {
              return DateTime.fromMillisecondsSinceEpoch(timestamp);
            }
          }
          if (dateObj is String) {
            return DateTime.parse(dateObj);
          }
        }
        if (value['\$numberLong'] != null) {
          final timestamp = int.tryParse(value['\$numberLong'].toString());
          if (timestamp != null) {
            return DateTime.fromMillisecondsSinceEpoch(timestamp);
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Date parse error: $e for value: $value');
    }
    return null;
  }

  static String _detectSource(Map<String, dynamic> json) {
    if (json['threesixtyfiveGameId'] != null ||
        json['threesixtyfive_game_id'] != null) {
      return 'fixtures_history';
    }
    if (json['source'] != null) {
      final src = json['source'].toString().toLowerCase();
      if (src == '365scores' ||
          src.contains('fixture') ||
          src.contains('national')) {
        return 'fixtures_history';
      }
    }
    if (json['league'] != null) {
      final league = json['league'].toString().toLowerCase();
      if (league.contains('world cup') ||
          league.contains('euro') ||
          league.contains('copa') ||
          league.contains('nations') ||
          league.contains('friendlies')) {
        return 'fixtures_history';
      }
    }
    return 'games_history';
  }

  factory HistoryGame.fromJson(Map<String, dynamic> json) {
    int? homeScore;
    if (json['homeScore'] != null) {
      if (json['homeScore'] is int) {
        homeScore = json['homeScore'];
      } else if (json['homeScore'] is String) {
        homeScore = int.tryParse(json['homeScore']);
      }
    }

    int? awayScore;
    if (json['awayScore'] != null) {
      if (json['awayScore'] is int) {
        awayScore = json['awayScore'];
      } else if (json['awayScore'] is String) {
        awayScore = int.tryParse(json['awayScore']);
      }
    }

    DateTime completedAt;
    if (json['completedAt'] != null) {
      completedAt = _parseMongoDate(json['completedAt']) ?? DateTime.now();
    } else if (json['completed_at'] != null) {
      completedAt = _parseMongoDate(json['completed_at']) ?? DateTime.now();
    } else {
      completedAt = DateTime.now();
    }

    bool movedToHistory;
    if (json['movedToHistory'] != null) {
      movedToHistory = json['movedToHistory'] is bool
          ? json['movedToHistory']
          : json['movedToHistory'].toString().toLowerCase() == 'true';
    } else if (json['moved_to_history'] != null) {
      movedToHistory = json['moved_to_history'] is bool
          ? json['moved_to_history']
          : json['moved_to_history'].toString().toLowerCase() == 'true';
    } else {
      movedToHistory = true;
    }

    // ✅ Parse timeElapsed
    double? timeElapsed;
    if (json['timeElapsed'] != null) {
      timeElapsed = (json['timeElapsed'] as num?)?.toDouble();
    } else if (json['time_elapsed'] != null) {
      timeElapsed = (json['time_elapsed'] as num?)?.toDouble();
    }

    return HistoryGame(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      matchId:
          json['matchId']?.toString() ?? json['match_id']?.toString() ?? '',
      threesixtyfiveGameId: json['threesixtyfiveGameId']?.toString() ??
          json['threesixtyfive_game_id']?.toString(),
      homeTeam:
          json['homeTeam']?.toString() ?? json['home_team']?.toString() ?? '',
      awayTeam:
          json['awayTeam']?.toString() ?? json['away_team']?.toString() ?? '',
      league: json['league']?.toString() ?? '',
      homeWin: (json['homeWin'] as num?)?.toDouble() ??
          (json['home_win'] as num?)?.toDouble(),
      awayWin: (json['awayWin'] as num?)?.toDouble() ??
          (json['away_win'] as num?)?.toDouble(),
      draw: (json['draw'] as num?)?.toDouble(),
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      dateIso:
          json['dateIso']?.toString() ?? json['date_iso']?.toString() ?? '',
      kickoffUtc: _parseMongoDate(json['kickoffUtc'] ?? json['kickoff_utc']) ??
          DateTime.now(),
      homeScore: homeScore,
      awayScore: awayScore,
      status: json['status']?.toString() ?? 'completed',
      isLive: json['isLive'] as bool? ?? json['is_live'] as bool? ?? false,
      availableForVoting: json['availableForVoting'] as bool? ??
          json['available_for_voting'] as bool? ??
          false,
      timeElapsed: timeElapsed,
      result: json['result']?.toString(),
      source: _detectSource(json),
      scrapedAt: _parseMongoDate(json['scrapedAt'] ?? json['scraped_at']),
      lastScrapedAt:
          _parseMongoDate(json['lastScrapedAt'] ?? json['last_scraped_at']),
      lastPolledAt:
          _parseMongoDate(json['lastPolledAt'] ?? json['last_polled_at']),
      commentary: json['commentary'] ?? [],
      lastCommentaryAt: _parseMongoDate(
          json['lastCommentaryAt'] ?? json['last_commentary_at']),
      lineups: json['lineups'],
      lineupsFetched: json['lineupsFetched'] as bool? ??
          json['lineups_fetched'] as bool? ??
          false,
      lineupsFetchedAt: _parseMongoDate(
          json['lineupsFetchedAt'] ?? json['lineups_fetched_at']),
      statistics: json['statistics'] ?? [],
      lastStatisticsMinute: (json['lastStatisticsMinute'] as num?)?.toInt() ??
          (json['last_statistics_minute'] as num?)?.toInt(),
      forwardedEventSignatures: List<String>.from(
          json['forwardedEventSignatures'] ??
              json['forwarded_event_signatures'] ??
              []),
      completedAt: completedAt,
      movedToHistory: movedToHistory,
      createdAt: _parseMongoDate(json['createdAt'] ?? json['created_at']) ??
          DateTime.now(),
    );
  }

  bool get isFromFixtures =>
      source == 'fixtures_history' || threesixtyfiveGameId != null;
  bool get isFromGames =>
      source == 'games_history' || threesixtyfiveGameId == null;

  String get sourceIcon => isFromFixtures ? '🌍' : '⚽';
  String get sourceLabel => isFromFixtures ? 'National' : 'League';

  String get scoreDisplay {
    if (homeScore != null && awayScore != null) {
      return '$homeScore - $awayScore';
    }
    return 'VS';
  }

  String get resultDisplay {
    if (homeScore == null || awayScore == null) return '?';
    if (homeScore! > awayScore!) return '🏆 ${homeTeam} wins';
    if (awayScore! > homeScore!) return '🏆 ${awayTeam} wins';
    return '🤝 Draw';
  }

  Color get resultColor {
    if (homeScore == null || awayScore == null) return Colors.grey;
    if (homeScore! > awayScore!) return const Color(0xFF10B981);
    if (awayScore! > homeScore!) return const Color(0xFF3B82F6);
    return const Color(0xFF8B5CF6);
  }

  /// Get formatted minute display from timeElapsed
  String getFormattedMinuteDisplay() {
    if (timeElapsed == null) return '';

    final minutes = timeElapsed!.floor();
    final seconds = ((timeElapsed! % 1) * 60).round();

    if (status == 'half_time' || minutes == 45) {
      return 'Half Time';
    }
    if (minutes >= 90 && minutes < 120) {
      final etMinutes = minutes - 90;
      if (etMinutes == 0) {
        return 'Full Time';
      }
      return 'ET ${etMinutes}\'';
    }
    if (minutes >= 120) {
      return 'Penalties';
    }

    if (seconds > 0) {
      return "${minutes}'${seconds.toString().padLeft(2, '0')}";
    }
    return "${minutes}'";
  }

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'league': league,
      'homeScore': homeScore,
      'awayScore': awayScore,
      'status': status,
      'completedAt': completedAt.toIso8601String(),
      'movedToHistory': movedToHistory,
      'source': source,
      'timeElapsed': timeElapsed,
    };
  }

  Fixture toFixture() {
    return Fixture(
      id: id,
      matchId: matchId,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      league: league,
      homeWin: homeWin ?? 2.0,
      awayWin: awayWin ?? 2.0,
      draw: draw ?? 3.0,
      date: date,
      time: time,
      homeScore: homeScore,
      awayScore: awayScore,
      status: 'completed',
      isLive: false,
      availableForVoting: false,
      source: source ?? '',
      scrapedAt: completedAt,
      dateIso: dateIso,
      result: result,
      timeElapsed: timeElapsed,
    );
  }
}

// ============================================================================
// HISTORY QUERY PARAMS
// ============================================================================

class HistoryQueryParams {
  final int? limit;
  final int? skip;
  final String? league;
  final String? homeTeam;
  final String? awayTeam;
  final String? fromDate;
  final String? toDate;

  HistoryQueryParams({
    this.limit,
    this.skip,
    this.league,
    this.homeTeam,
    this.awayTeam,
    this.fromDate,
    this.toDate,
  });

  Map<String, String> toQueryParameters() {
    final params = <String, String>{};
    if (limit != null) params['limit'] = limit.toString();
    if (skip != null) params['skip'] = skip.toString();
    if (league != null && league!.isNotEmpty) params['league'] = league!;
    if (homeTeam != null && homeTeam!.isNotEmpty)
      params['home_team'] = homeTeam!;
    if (awayTeam != null && awayTeam!.isNotEmpty)
      params['away_team'] = awayTeam!;
    if (fromDate != null && fromDate!.isNotEmpty)
      params['from_date'] = fromDate!;
    if (toDate != null && toDate!.isNotEmpty) params['to_date'] = toDate!;
    return params;
  }
}

// ============================================================================
// HISTORY SERVICE
// ============================================================================

class HistoryService {
  static const String API_BASE_URL = 'https://clash-api-m5mr.onrender.com/api';
  static const Duration REQUEST_TIMEOUT = Duration(seconds: 15);

  static Future<List<HistoryGame>> fetchHistoryGames({
    HistoryQueryParams? params,
    String? authToken,
  }) async {
    try {
      final uri = Uri.parse('$API_BASE_URL/games/history')
          .replace(queryParameters: params?.toQueryParameters() ?? {});

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      debugPrint('🌐 Fetching history from: $uri');
      final response =
          await http.get(uri, headers: headers).timeout(REQUEST_TIMEOUT);

      debugPrint('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> gamesData = data['data'] ?? [];
        debugPrint('✅ Found ${gamesData.length} history games');
        return gamesData.map((j) => HistoryGame.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching history games: $e');
      return [];
    }
  }

  static Future<HistoryGame?> fetchHistoryGameById(
    String matchId, {
    String? authToken,
  }) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/games/history/$matchId'),
            headers: headers,
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return HistoryGame.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching history game: $e');
      return null;
    }
  }

  static Future<int> getTotalHistoryCount({String? authToken}) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/games/history/count'),
            headers: headers,
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['total'] ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('❌ Error fetching history count: $e');
      return 0;
    }
  }
}
