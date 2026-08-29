// ============================================================================
// PAYMENT SERVICE - Shared across FixturesPage and AdminDashboard
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

// ============================================================================
// TRANSACTION FORMULA PATTERN
// ============================================================================
//
// Transaction Formula:
// [Transaction] = [Amount] + [Fee] + [Status] + [Reference] + [Timestamp] + [Type]
//
// Formula Components:
// - Amount: The monetary value of the transaction
// - Fee: Transaction fee (0.5% for withdrawals, 0 for deposits)
// - Status: pending → processing → completed/failed/cancelled
// - Reference: Unique identifier (generated or from M-Pesa)
// - Timestamp: When the transaction was created/completed
// - Type: deposit, withdrawal, pledge, payout, refund, fee
//
// Transaction Types:
// - DEPOSIT: Amount + 0 fee + Reference + M-Pesa Transaction ID
// - WITHDRAWAL: Amount + Fee (0.5%) + Reference + Phone Number
// - PLEDGE: Amount + 0 fee + Fixture Reference + Vote ID
// - PAYOUT: Amount + 0 fee + Channel Reference (admin engagement)
// - REFUND: Amount + 0 fee + Original Reference
// ============================================================================

// ============================================================================
// ENUMS
// ============================================================================

enum PaymentTransactionType {
  deposit('deposit'),
  withdrawal('withdrawal'),
  pledge('pledge'),
  payout('payout'),
  refund('refund'),
  fee('fee');

  final String value;
  const PaymentTransactionType(this.value);

  static PaymentTransactionType fromString(String value) {
    return PaymentTransactionType.values.firstWhere(
      (e) => e.value == value.toLowerCase(),
      orElse: () => PaymentTransactionType.deposit,
    );
  }
}

enum PaymentTransactionStatus {
  pending('pending'),
  processing('processing'),
  completed('completed'),
  failed('failed'),
  cancelled('cancelled'),
  refunded('refunded');

  final String value;
  const PaymentTransactionStatus(this.value);

  static PaymentTransactionStatus fromString(String value) {
    return PaymentTransactionStatus.values.firstWhere(
      (e) => e.value == value.toLowerCase(),
      orElse: () => PaymentTransactionStatus.pending,
    );
  }
}

// ============================================================================
// TRANSACTION MODEL
// ============================================================================

class PaymentTransaction {
  final String id;
  final String userId;
  final String username;
  final PaymentTransactionType type;
  final PaymentTransactionStatus status;
  final double amount;
  final double fee;
  final double netAmount;
  final String reference;
  final String? mpesaCode;
  final String? phoneNumber;
  final String? channelId;
  final String? fixtureId;
  final String? voteId;
  final String? description;
  final DateTime createdAt;
  final DateTime? completedAt;
  final Map<String, dynamic> metadata;

  PaymentTransaction({
    required this.id,
    required this.userId,
    required this.username,
    required this.type,
    required this.status,
    required this.amount,
    this.fee = 0.0,
    required this.reference,
    this.mpesaCode,
    this.phoneNumber,
    this.channelId,
    this.fixtureId,
    this.voteId,
    this.description,
    required this.createdAt,
    this.completedAt,
    this.metadata = const {},
  }) : netAmount = amount - fee;

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: json['id'] ?? json['_id'] ?? '',
      userId: json['userId'] ?? json['user_id'] ?? '',
      username: json['username'] ?? '',
      type: PaymentTransactionType.fromString(
        json['type'] ?? json['transaction_type'] ?? 'deposit',
      ),
      status: PaymentTransactionStatus.fromString(
        json['status'] ?? 'pending',
      ),
      amount: (json['amount'] ?? 0.0).toDouble(),
      fee: (json['fee'] ?? 0.0).toDouble(),
      reference: json['reference'] ?? '',
      mpesaCode: json['mpesa_code'] ?? json['mpesaCode'],
      phoneNumber: json['phone_number'] ?? json['phoneNumber'],
      channelId: json['channel_id'] ?? json['channelId'],
      fixtureId: json['fixture_id'] ?? json['fixtureId'],
      voteId: json['vote_id'] ?? json['voteId'],
      description: json['description'],
      createdAt: DateTime.tryParse(
            json['created_at'] ??
                json['createdAt'] ??
                DateTime.now().toIso8601String(),
          ) ??
          DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : json['completedAt'] != null
              ? DateTime.tryParse(json['completedAt'].toString())
              : null,
      metadata: json['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'type': type.value,
      'status': status.value,
      'amount': amount,
      'fee': fee,
      'netAmount': netAmount,
      'reference': reference,
      'mpesaCode': mpesaCode,
      'phoneNumber': phoneNumber,
      'channelId': channelId,
      'fixtureId': fixtureId,
      'voteId': voteId,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  bool get isPending => status == PaymentTransactionStatus.pending;
  bool get isProcessing => status == PaymentTransactionStatus.processing;
  bool get isCompleted => status == PaymentTransactionStatus.completed;
  bool get isFailed => status == PaymentTransactionStatus.failed;
  bool get isCancelled => status == PaymentTransactionStatus.cancelled;
  bool get isRefunded => status == PaymentTransactionStatus.refunded;

  String get statusDisplay {
    switch (status) {
      case PaymentTransactionStatus.pending:
        return '⏳ Pending';
      case PaymentTransactionStatus.processing:
        return '🔄 Processing';
      case PaymentTransactionStatus.completed:
        return '✅ Completed';
      case PaymentTransactionStatus.failed:
        return '❌ Failed';
      case PaymentTransactionStatus.cancelled:
        return '🚫 Cancelled';
      case PaymentTransactionStatus.refunded:
        return '↩️ Refunded';
    }
  }

  String get typeDisplay {
    switch (type) {
      case PaymentTransactionType.deposit:
        return '💰 Deposit';
      case PaymentTransactionType.withdrawal:
        return '🏦 Withdrawal';
      case PaymentTransactionType.pledge:
        return '🎯 Pledge';
      case PaymentTransactionType.payout:
        return '🏆 Payout';
      case PaymentTransactionType.refund:
        return '↩️ Refund';
      case PaymentTransactionType.fee:
        return '💸 Fee';
    }
  }

  Color get statusColor {
    switch (status) {
      case PaymentTransactionStatus.pending:
        return const Color(0xFFFFA726);
      case PaymentTransactionStatus.processing:
        return const Color(0xFF42A5F5);
      case PaymentTransactionStatus.completed:
        return const Color(0xFF66BB6A);
      case PaymentTransactionStatus.failed:
        return const Color(0xFFEF5350);
      case PaymentTransactionStatus.cancelled:
        return const Color(0xFF78909C);
      case PaymentTransactionStatus.refunded:
        return const Color(0xFFAB47BC);
    }
  }
}

// ============================================================================
// RESULT CLASSES
// ============================================================================

/// STK Push Result
class STKPushResult {
  final bool success;
  final String? transactionId;
  final String? mpesaCode;
  final double? newBalance;
  final String? message;
  final String? error;

  STKPushResult({
    required this.success,
    this.transactionId,
    this.mpesaCode,
    this.newBalance,
    this.message,
    this.error,
  });

  factory STKPushResult.success({
    required String transactionId,
    String? mpesaCode,
    double? newBalance,
    String? message,
  }) {
    return STKPushResult(
      success: true,
      transactionId: transactionId,
      mpesaCode: mpesaCode,
      newBalance: newBalance,
      message: message,
    );
  }

  factory STKPushResult.error(String error) {
    return STKPushResult(
      success: false,
      error: error,
    );
  }

  bool get isSuccess => success;
  bool get isError => !success;
}

/// STK Status Result
class STKStatusResult {
  final String status; // 'pending', 'completed', 'failed', 'cancelled'
  final String? transactionId;
  final String? mpesaCode;
  final String? message;

  STKStatusResult({
    required this.status,
    this.transactionId,
    this.mpesaCode,
    this.message,
  });

  factory STKStatusResult.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString() ?? 'pending';
    return STKStatusResult(
      status: status,
      transactionId: json['transaction_id']?.toString(),
      mpesaCode: json['mpesa_code']?.toString(),
      message: json['message']?.toString(),
    );
  }

  factory STKStatusResult.pending() {
    return STKStatusResult(status: 'pending');
  }

  factory STKStatusResult.error(String message) {
    return STKStatusResult(
      status: 'failed',
      message: message,
    );
  }

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled';
}

/// B2C Result (Admin withdrawal)
class B2CResult {
  final bool success;
  final String? transactionId;
  final double? newBalance;
  final String? message;
  final String? error;

  B2CResult({
    required this.success,
    this.transactionId,
    this.newBalance,
    this.message,
    this.error,
  });

  factory B2CResult.success({
    required String transactionId,
    double? newBalance,
    String? message,
  }) {
    return B2CResult(
      success: true,
      transactionId: transactionId,
      newBalance: newBalance,
      message: message,
    );
  }

  factory B2CResult.error(String error) {
    return B2CResult(
      success: false,
      error: error,
    );
  }

  bool get isSuccess => success;
  bool get isError => !success;
}

/// Admin Payout Result
class AdminPayoutResult {
  final bool success;
  final double? amount;
  final String? payoutType;
  final String? status;
  final DateTime? computedAt;
  final String? error;

  AdminPayoutResult({
    required this.success,
    this.amount,
    this.payoutType,
    this.status,
    this.computedAt,
    this.error,
  });

  factory AdminPayoutResult.success({
    required double amount,
    required String payoutType,
    required String status,
    required DateTime computedAt,
  }) {
    return AdminPayoutResult(
      success: true,
      amount: amount,
      payoutType: payoutType,
      status: status,
      computedAt: computedAt,
    );
  }

  factory AdminPayoutResult.error(String error) {
    return AdminPayoutResult(
      success: false,
      error: error,
    );
  }

  bool get isSuccess => success;
  bool get isError => !success;
}

/// Transaction History Result
class TransactionHistoryResult {
  final bool success;
  final List<PaymentTransaction> transactions;
  final int total;
  final bool hasMore;
  final String? error;

  TransactionHistoryResult({
    required this.success,
    this.transactions = const [],
    this.total = 0,
    this.hasMore = false,
    this.error,
  });

  factory TransactionHistoryResult.success({
    required List<PaymentTransaction> transactions,
    int total = 0,
    bool hasMore = false,
  }) {
    return TransactionHistoryResult(
      success: true,
      transactions: transactions,
      total: total > 0 ? total : transactions.length,
      hasMore: hasMore,
    );
  }

  factory TransactionHistoryResult.error(String error) {
    return TransactionHistoryResult(
      success: false,
      error: error,
    );
  }

  bool get isSuccess => success;
  bool get isError => !success;
}

// ============================================================================
// PAYMENT SERVICE
// ============================================================================

class PaymentService {
  static const String API_BASE_URL = 'https://clash-api-m5mr.onrender.com/api';
  static const Duration REQUEST_TIMEOUT = Duration(seconds: 30);
  static const Duration POLLING_INTERVAL = Duration(seconds: 2);
  static const int MAX_POLLING_ATTEMPTS = 90; // 3 minutes

  // ==========================================================================
  // STK PUSH - For user deposits and channel loading
  // ==========================================================================

  /// Initiate STK Push payment (for deposits and channel loading)
    /// Initiate STK Push payment (for deposits and channel loading)
  static Future<STKPushResult> initiateSTKPush({
    required String userId,
    required String username,
    required double amount,
    String? phoneNumber,
    String? authToken,
    String? purpose,
    String? channelId,
    String? fixtureId,
    String? voteId,
  }) async {
    try {
      // Validate amount
      if (amount < 1.0) {
        return STKPushResult.error('Minimum amount is KES 1.00');
      }
      if (amount > 100000.0) {
        return STKPushResult.error('Maximum amount is KES 100,000.00');
      }

      // Get phone number if not provided
      String phone = phoneNumber ?? '';
      if (phone.isEmpty) {
        phone = await _getUserPhone(userId, authToken);
      }

      if (phone.isEmpty || !_isValidPhoneNumber(phone)) {
        return STKPushResult.error('Valid phone number is required');
      }

      final normalizedPhone = _normalizePhone(phone);

      final headers = _buildHeaders(authToken);

      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/lipaclash/stk-push'),
            headers: headers,
            body: json.encode({
              'phone_number': normalizedPhone,
              'amount': amount.toString(),
              'account_reference': username,
              'transaction_desc': purpose ?? 'Top up balance',
              'user_id': userId,
              'channel_id': channelId,
              'fixture_id': fixtureId,
              'vote_id': voteId,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final checkoutRequestId =
              data['checkout_request_id']?.toString() ?? '';
          final transactionId = data['transaction_id']?.toString();

          // Start polling for status
          final result = await _pollSTKStatus(
            checkoutRequestId: checkoutRequestId,
            userId: userId,
            authToken: authToken,
          );

          return result;
        } else {
          return STKPushResult.error(
            data['message'] ?? 'Payment initiation failed',
          );
        }
      } else {
        return STKPushResult.error('Payment service unavailable');
      }
    } catch (e) {
      return STKPushResult.error('Network error: ${e.toString()}');
    }
  }

  // ==========================================================================
  // B2C PAYMENT - For admin withdrawals (payouts)
  // ==========================================================================

  /// Initiate B2C payment (admin withdrawal/payout)
   /// Initiate B2C payment (admin withdrawal/payout)
  static Future<B2CResult> initiateB2CPayment({
    required String userId,
    required String username,
    required String channelId,
    required double amount,
    required String phoneNumber,
    String? authToken,
    String? remarks,
    String? occasion,
  }) async {
    try {
      // Validate
      if (amount < 1.0) {
        return B2CResult.error('Minimum withdrawal is KES 1.00');
      }
      if (amount > 50000.0) {
        return B2CResult.error('Maximum withdrawal is KES 50,000.00');
      }

      if (!_isValidPhoneNumber(phoneNumber)) {
        return B2CResult.error('Valid phone number is required');
      }

      final normalizedPhone = _normalizePhone(phoneNumber);

      // Check balance first
      final balance = await _getUserBalance(userId, authToken);
      if (balance < amount) {
        return B2CResult.error(
          'Insufficient balance. You have KES ${balance.toStringAsFixed(2)}',
        );
      }

      final headers = _buildHeaders(authToken);

      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/lipaclash/b2c/send'),
            headers: headers,
            body: json.encode({
              'phone_number': normalizedPhone,
              'amount': amount.toString(),
              'remarks': remarks ?? 'Channel withdrawal',
              'occasion': occasion ?? 'Channel Payout',
              'user_id': userId,
              'username': username,
              'channel_id': channelId,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return B2CResult.success(
            transactionId: data['transaction_id']?.toString() ?? '',
            message: data['message'] ?? 'Withdrawal initiated successfully',
            newBalance: (data['new_balance'] ?? 0.0).toDouble(),
          );
        } else {
          return B2CResult.error(
            data['message'] ?? 'Withdrawal failed',
          );
        }
      } else {
        return B2CResult.error('Withdrawal service unavailable');
      }
    } catch (e) {
      return B2CResult.error('Network error: ${e.toString()}');
    }
  }

  // ==========================================================================
  // CHECK PAYMENT STATUS
  // ==========================================================================

  /// Check STK Push payment status
  static Future<STKStatusResult> checkSTKStatus({
    required String checkoutRequestId,
    String? authToken,
  }) async {
    try {
      final headers = _buildHeaders(authToken);

      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/lipaclash/check-payment-status'),
            headers: headers,
            body: json.encode({
              'checkout_request_id': checkoutRequestId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return STKStatusResult.fromJson(data);
      }
      return STKStatusResult.pending();
    } catch (e) {
      return STKStatusResult.error(e.toString());
    }
  }

  // ==========================================================================
  // ADMIN PAYOUT - Compute engagement payout
  // ==========================================================================

  /// Compute admin payout based on engagement metrics
  static Future<AdminPayoutResult> computeAdminPayout({
    required String channelId,
    required String userId,
    required String? authToken,
  }) async {
    try {
      final headers = _buildHeaders(authToken);

      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/channels/$channelId/admin-payout/compute'),
            headers: headers,
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['payout'] != null) {
          return AdminPayoutResult.success(
            amount: (data['payout']['amount'] ?? 0.0).toDouble(),
            payoutType:
                data['payout']['payout_type']?.toString() ?? 'engagement_rate',
            status: data['payout']['status']?.toString() ?? 'pending',
            computedAt: DateTime.tryParse(
                  data['payout']['created_at']?.toString() ?? '',
                ) ??
                DateTime.now(),
          );
        }
        return AdminPayoutResult.error(
          data['message'] ?? 'Failed to compute payout',
        );
      }
      return AdminPayoutResult.error('Server error: ${response.statusCode}');
    } catch (e) {
      return AdminPayoutResult.error('Network error: ${e.toString()}');
    }
  }

  // ==========================================================================
  // USER BALANCE
  // ==========================================================================

  /// Get user balance from users collection
  static Future<double> getUserBalance({
    required String userId,
    String? authToken,
    bool forceRefresh = false,
  }) async {
    return _getUserBalance(userId, authToken, forceRefresh: forceRefresh);
  }

  // ==========================================================================
  // TRANSACTION HISTORY
  // ==========================================================================

  /// Get transaction history for a user
  static Future<TransactionHistoryResult> getTransactionHistory({
    required String userId,
    String? authToken,
    int limit = 50,
    int offset = 0,
    PaymentTransactionType? type,
    PaymentTransactionStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final headers = _buildHeaders(authToken);

      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (type != null) queryParams['type'] = type.value;
      if (status != null) queryParams['status'] = status.value;
      if (fromDate != null) queryParams['from'] = fromDate.toIso8601String();
      if (toDate != null) queryParams['to'] = toDate.toIso8601String();

      final uri = Uri.parse('$API_BASE_URL/transactions/user/$userId')
          .replace(queryParameters: queryParams);

      final response = await http
          .get(
            uri,
            headers: headers,
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<PaymentTransaction> transactions = [];
        if (data['data'] is List) {
          for (var item in data['data']) {
            transactions.add(PaymentTransaction.fromJson(item));
          }
        }
        return TransactionHistoryResult.success(
          transactions: transactions,
          total: data['total'] ?? transactions.length,
          hasMore: data['has_more'] ?? false,
        );
      }
      return TransactionHistoryResult.error('Failed to fetch transactions');
    } catch (e) {
      return TransactionHistoryResult.error('Network error: ${e.toString()}');
    }
  }

  // ==========================================================================
  // PRIVATE HELPERS
  // ==========================================================================

  static Future<double> _getUserBalance(
    String userId,
    String? authToken, {
    bool forceRefresh = false,
  }) async {
    try {
      final headers = _buildHeaders(authToken);
      if (forceRefresh) {
        headers['Cache-Control'] = 'no-cache, no-store, must-revalidate';
      }

      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/auth/user/id/$userId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return (data['user']['balance'] ?? 0.0).toDouble();
        }
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  static Future<String> _getUserPhone(String userId, String? authToken) async {
    try {
      final headers = _buildHeaders(authToken);

      // Try saved topup phone first
      final savedResponse = await http
          .get(
            Uri.parse('$API_BASE_URL/auth/user/$userId/topup-phone'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 5));

      if (savedResponse.statusCode == 200) {
        final data = json.decode(savedResponse.body);
        if (data['success'] == true) {
          final phone = data['phone']?.toString();
          if (phone != null && phone.isNotEmpty && _isValidPhoneNumber(phone)) {
            return phone;
          }
        }
      }

      // Fallback: get from user profile
      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/auth/user/id/$userId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final phone = data['user']['phone']?.toString() ?? '';
          if (phone.isNotEmpty && _isValidPhoneNumber(phone)) {
            return phone;
          }
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  // In PaymentService.dart - Replace _pollSTKStatus with this:

  static Future<STKPushResult> _pollSTKStatus({
    required String checkoutRequestId,
    required String userId,
    String? authToken,
  }) async {
    int attempts = 0;
    STKStatusResult? lastResult;

    while (attempts < MAX_POLLING_ATTEMPTS) {
      await Future.delayed(POLLING_INTERVAL);
      attempts++;

      try {
        final result = await checkSTKStatus(
          checkoutRequestId: checkoutRequestId,
          authToken: authToken,
        );
        lastResult = result;

        debugPrint('🔄 Polling attempt $attempts: ${result.status}');

        if (result.isCompleted) {
          // Get updated balance
          final balance =
              await _getUserBalance(userId, authToken, forceRefresh: true);
          return STKPushResult.success(
            transactionId: result.transactionId ?? '',
            mpesaCode: result.mpesaCode,
            newBalance: balance,
            message: 'Payment completed successfully',
          );
        }

        if (result.isFailed) {
          return STKPushResult.error(
            result.message ?? 'Payment failed',
          );
        }

        if (result.isCancelled) {
          return STKPushResult.error('Payment cancelled by user');
        }
      } catch (e) {
        debugPrint('⚠️ Polling error (attempt $attempts): $e');
        // Continue polling on error
      }
    }

    // Timeout - check if we have a pending result
    return STKPushResult.error(
      'Payment is still processing. Please check your M-Pesa and refresh your balance.',
    );
  }

  static Map<String, String> _buildHeaders(String? authToken) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  static String _generateReference(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 10000;
    return '$prefix${timestamp.toString().substring(5)}${random.toString().padLeft(4, '0')}';
  }
    static bool _isValidPhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    // Kenyan mobile numbers, optionally prefixed with '0' or country code '254'.
    // 07xx / 01xx-legacy Safaricom/Airtel ranges (700-799),
    // plus the newer 01xx block:
    //   0100-0106 -> Airtel
    //   0110-0115 -> Safaricom
    final regex = RegExp(
      r'^(0|254)?(7[0-9]{8}|1(?:0[0-6]|1[0-5])[0-9]{6})$',
    );
    return regex.hasMatch(cleaned);
  }

  static String _normalizePhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) {
      return '254${cleaned.substring(1)}';
    }
    if (cleaned.length == 9 &&
        (cleaned.startsWith('7') || cleaned.startsWith('1'))) {
      return '254$cleaned';
    }
    return cleaned;
  }
}
// ============================================================================
// LOCAL STORAGE FOR TRANSACTIONS
// ============================================================================

class TransactionLocalStorage {
  static const String _transactionsKey = 'cached_transactions';
  static const String _balanceKey = 'cached_balance';
  static const String _balanceTimestampKey = 'balance_timestamp';
  static const Duration _cacheDuration = Duration(minutes: 5);

  static Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  static Future<void> cacheTransactions(
    List<PaymentTransaction> transactions,
  ) async {
    try {
      final prefs = await _prefs;
      final jsonList = transactions.map((t) => t.toJson()).toList();
      await prefs.setString(_transactionsKey, json.encode(jsonList));
    } catch (e) {
      // Ignore
    }
  }

  static Future<List<PaymentTransaction>> getCachedTransactions() async {
    try {
      final prefs = await _prefs;
      final jsonStr = prefs.getString(_transactionsKey);
      if (jsonStr == null) return [];
      final List<dynamic> jsonList = json.decode(jsonStr);
      return jsonList.map((json) => PaymentTransaction.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> cacheBalance(double balance) async {
    try {
      final prefs = await _prefs;
      await prefs.setDouble(_balanceKey, balance);
      await prefs.setInt(
          _balanceTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Ignore
    }
  }

  static Future<double?> getCachedBalance() async {
    try {
      final prefs = await _prefs;
      final timestamp = prefs.getInt(_balanceTimestampKey);
      if (timestamp != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (cacheAge > _cacheDuration.inMilliseconds) {
          return null; // Cache expired
        }
      }
      return prefs.getDouble(_balanceKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearCache() async {
    try {
      final prefs = await _prefs;
      await prefs.remove(_transactionsKey);
      await prefs.remove(_balanceKey);
      await prefs.remove(_balanceTimestampKey);
    } catch (e) {
      // Ignore
    }
  }
}
