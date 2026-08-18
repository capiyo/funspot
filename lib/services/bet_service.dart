import 'dart:convert';
import 'package:http/http.dart' as http;
import "../models/fixture_models.dart";
import 'package:flutter/material.dart';

// ============================================================
// BET SERVICE
// ============================================================
class BetService {
  static const String API_BASE_URL = 'https://clash-api-m5mr.onrender.com/api';
  static const Duration REQUEST_TIMEOUT = Duration(seconds: 15);

  // ============================================================
  // ✅ NEW: Create Bet with Vote ID (Pledge + Vote)
  // ============================================================
  static Future<Map<String, dynamic>> createBetWithVoteId({
    required String fixtureId,
    required String starterId,
    required String starterName,
    required String starterSelection,
    required double amount,
    required String channelId,
    required String voteId,
    String? authToken,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/actions/bet/create'),
            headers: headers,
            body: json.encode({
              'fixture_id': fixtureId,
              'starter_id': starterId,
              'starter_name': starterName,
              'starter_selection': starterSelection,
              'amount': amount,
              'channel_id': channelId,
              'vote_id': voteId,
            }),
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      return {
        'success': false,
        'message': 'Server error: ${response.statusCode}'
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // ============================================================
  // ✅ KEEP: Original createBet (for backward compatibility)
  // ============================================================
  @Deprecated('Use createBetWithVoteId instead')
  static Future<Map<String, dynamic>> createBet({
    required String fixtureId,
    required String starterId,
    required String starterName,
    required String starterSelection,
    required double amount,
    required String channelId,
    String? authToken,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/actions/bet/create'),
            headers: headers,
            body: json.encode({
              'fixture_id': fixtureId,
              'starter_id': starterId,
              'starter_name': starterName,
              'starter_selection': starterSelection,
              'amount': amount,
              'channel_id': channelId,
            }),
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      return {
        'success': false,
        'message': 'Server error: ${response.statusCode}'
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // ============================================================
  // GET OPEN BETS (Channel-Specific)
  // ============================================================
  static Future<List<Bet>> getOpenBets({
    required String channelId,
    required String fixtureId,
    String? authToken,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/actions/bet/open/$channelId/$fixtureId'),
            headers: headers,
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> betsData = data['open_bets'] ?? [];
        return betsData.map((json) => Bet.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // GET CHANNEL BETTORS (Matched + Settled)
  // ============================================================
  static Future<List<Bet>> getChannelBettors({
    required String channelId,
    required String fixtureId,
    String? authToken,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http
          .get(
            Uri.parse(
                '$API_BASE_URL/actions/bet/channel/$channelId/$fixtureId'),
            headers: headers,
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> betsData = data['bettors'] ?? [];
        return betsData.map((json) => Bet.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // FILL BET (Finisher accepts)
  // ============================================================
  static Future<Map<String, dynamic>> fillBet({
    required String betId,
    required String finisherId,
    required String finisherName,
    required String finisherSelection,
    required double amount,
    required String channelId,
    String? authToken,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/actions/bet/fill'),
            headers: headers,
            body: json.encode({
              'bet_id': betId,
              'finisher_id': finisherId,
              'finisher_name': finisherName,
              'finisher_selection': finisherSelection,
              'amount': amount,
              'channel_id': channelId,
            }),
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      return {
        'success': false,
        'message': 'Server error: ${response.statusCode}'
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }
}

// ============================================================
// BET MODEL
// ============================================================
class Bet {
  final String? id;
  final String fixtureId;
  final String starterId;
  final String starterName;
  final String starterSelection;
  final double starterAmount;
  final String? finisherId;
  final String? finisherName;
  final String? finisherSelection;
  final double? finisherAmount;
  final String? voteId;
  final String channelId;
  final String status;
  final String? winnerId;
  final String? starterResult;
  final String? finisherResult;
  final DateTime createdAt;
  final DateTime? matchedAt;
  final DateTime? settledAt;

  Bet({
    this.id,
    required this.fixtureId,
    required this.starterId,
    required this.starterName,
    required this.starterSelection,
    required this.starterAmount,
    this.finisherId,
    this.finisherName,
    this.finisherSelection,
    this.finisherAmount,
    this.voteId,
    required this.channelId,
    required this.status,
    this.winnerId,
    this.starterResult,
    this.finisherResult,
    required this.createdAt,
    this.matchedAt,
    this.settledAt,
  });

  factory Bet.fromJson(Map<String, dynamic> json) {
    return Bet(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      fixtureId: json['fixture_id'] ?? '',
      starterId: json['starter_id'] ?? '',
      starterName: json['starter_name'] ?? '',
      starterSelection: json['starter_selection'] ?? '',
      starterAmount: (json['starter_amount'] ?? 0.0).toDouble(),
      finisherId: json['finisher_id']?.toString(),
      finisherName: json['finisher_name']?.toString(),
      finisherSelection: json['finisher_selection']?.toString(),
      finisherAmount: json['finisher_amount']?.toDouble(),
      voteId: json['vote_id']?.toString(),
      channelId: json['channel_id'] ?? '',
      status: json['status'] ?? 'open',
      winnerId: json['winner_id']?.toString(),
      starterResult: json['starter_result']?.toString(),
      finisherResult: json['finisher_result']?.toString(),
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      matchedAt: json['matched_at'] != null
          ? DateTime.parse(json['matched_at'])
          : null,
      settledAt: json['settled_at'] != null
          ? DateTime.parse(json['settled_at'])
          : null,
    );
  }

  bool get isOpen => status == 'open';
  bool get isMatched => status == 'matched';
  bool get isSettled => status == 'settled';

  double get totalPot => starterAmount + (finisherAmount ?? 0.0);
}

// ============================================================
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
  final String status;
  final DateTime createdAt;
  final DateTime? settledAt;
  final String? result;

  // Additional fields from SubFixtureBet
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

  // Factory for SubFixtureBet response from Rust backend
  static SubFixturePledge fromBetJson(Map<String, dynamic> json) {
    // Handle both snake_case (Rust) and camelCase (legacy)
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

  // Factory for market/pledge response (legacy)
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
        return const Color(0xFF00A86B);
      case 'away':
        return const Color(0xFFE74C3C);
      case 'none':
        return const Color(0xFF9E9E9E);
      case 'over':
        return const Color(0xFF00A86B);
      case 'under':
        return const Color(0xFFE74C3C);
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}

// ============================================================
// SUB-FIXTURE SERVICE - Matches Rust Routes
// ============================================================
class SubFixtureService {
  static const String _api = 'https://clash-api-m5mr.onrender.com/api';
  static const Duration _timeout = Duration(seconds: 15);

  /// Get open sub-fixture bets for a match
  /// GET /api/sub_fixtures/sub-fixture/bets/open/:match_id
  static Future<List<SubFixturePledge>> getOpenBets({
    required String matchId,
    String? authToken,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };

      final response = await http
          .get(
            Uri.parse('$_api/sub_fixtures/sub-fixture/bets/open/$matchId'),
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

  /// Get bets for a specific market
  /// GET /api/sub_fixtures/sub-fixture/bets/market/:match_id/:market_id
  static Future<List<SubFixturePledge>> getMarketBets({
    required String matchId,
    required String marketId,
    String? authToken,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };

      final response = await http
          .get(
            Uri.parse(
                '$_api/sub_fixtures/sub-fixture/bets/market/$matchId/$marketId'),
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

  /// Get user's sub-fixture bets
  /// GET /api/sub_fixtures/sub-fixture/bets/user/:user_id
  static Future<List<SubFixturePledge>> getUserBets({
    required String userId,
    String? authToken,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };

      final response = await http
          .get(
            Uri.parse('$_api/sub_fixtures/sub-fixture/bets/user/$userId'),
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

  /// Place a bet on a sub-fixture
  /// POST /api/sub_fixtures/sub-fixture/bet
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
            Uri.parse('$_api/sub_fixtures/sub-fixture/bet'),
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

  /// Fill a sub-fixture bet
  /// POST /api/sub_fixtures/sub-fixture/bet/:bet_id/fill
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
            Uri.parse('$_api/sub_fixtures/sub-fixture/bet/$betId/fill'),
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

  /// Get market details with stats
  /// GET /api/sub_fixtures/markets/:match_id/:market_id
  static Future<Map<String, dynamic>> getMarketDetails({
    required String matchId,
    required String marketId,
    String? authToken,
  }) async {
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
}
