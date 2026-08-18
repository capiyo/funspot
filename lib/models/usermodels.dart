// Add this to your User model or create a separate model
class UserTransactionSettings {
  final String userId;
  final String? defaultTopUpNumber; // Phone for topping up
  final String? defaultWithdrawNumber; // Phone for withdrawing
  final double balance;
  final DateTime updatedAt;

  UserTransactionSettings({
    required this.userId,
    this.defaultTopUpNumber,
    this.defaultWithdrawNumber,
    required this.balance,
    required this.updatedAt,
  });

  factory UserTransactionSettings.fromJson(Map<String, dynamic> json) {
    return UserTransactionSettings(
      userId: json['userId'] ?? '',
      defaultTopUpNumber: json['defaultTopUpNumber'],
      defaultWithdrawNumber: json['defaultWithdrawNumber'],
      balance: (json['balance'] ?? 0.0).toDouble(),
      updatedAt:
          DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'defaultTopUpNumber': defaultTopUpNumber,
      'defaultWithdrawNumber': defaultWithdrawNumber,
      'balance': balance,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
