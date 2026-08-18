// modals/profile/swipeable_profile_modal.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../pages/fan_Funzy_design.dart';
import '../../services/auth_service.dart';
import '../../screens/home_page.dart' show UserChannel;
import '../../services/toast_helper.dart';
import 'dart:async';
import "../../models/user_channel.dart";
import '../../main.dart';
import '../../services/payment_service.dart';

// ============================================================================
// USER DATA MODEL
// ============================================================================

class UserData {
  final String userId;
  final String username;
  final String phone;
  final String nickname;
  final String clubFan;
  final String countryFan;
  final int numberOfBets;
  final double balance;

  UserData({
    required this.userId,
    required this.username,
    required this.phone,
    required this.nickname,
    required this.clubFan,
    required this.countryFan,
    required this.numberOfBets,
    required this.balance,
  });

  factory UserData.fromJson(Map<String, dynamic> json) => UserData(
        userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        nickname: json['nickname']?.toString() ?? '',
        clubFan: json['club_fan']?.toString() ?? '',
        countryFan: json['country_fan']?.toString() ?? '',
        numberOfBets: json['number_of_bets'] ?? 0,
        balance: (json['balance'] ?? 0.0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'username': username,
        'phone': phone,
        'nickname': nickname,
        'club_fan': clubFan,
        'country_fan': countryFan,
        'number_of_bets': numberOfBets,
        'balance': balance,
      };
}

// ============================================================================
// MAIN MODAL
// ============================================================================

class SwipeableProfileModal extends StatefulWidget {
  final String apiBaseUrl;
  final String userId;
  final String username;
  final String phone;
  final Function(UserData)? onUserUpdated;
  final VoidCallback? onLogout;
  final List<UserChannel> userChannels;

  const SwipeableProfileModal({
    super.key,
    required this.apiBaseUrl,
    required this.userId,
    required this.username,
    required this.phone,
    this.onUserUpdated,
    this.onLogout,
    this.userChannels = const [],
  });

  @override
  State<SwipeableProfileModal> createState() => _SwipeableProfileModalState();
}

class _SwipeableProfileModalState extends State<SwipeableProfileModal>
    with SingleTickerProviderStateMixin {
  // ==========================================================================
  // STATE
  // ==========================================================================

  late TabController _tabController;
  int _selectedTab = 0;

  // Profile data
  UserData? _userData;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoggingOut = false;

  // Text controllers
  late TextEditingController _nicknameController;
  late TextEditingController _clubController;
  late TextEditingController _countryController;
  final FocusNode _nicknameFocus = FocusNode();
  final FocusNode _clubFocus = FocusNode();
  final FocusNode _countryFocus = FocusNode();

  // Balance
  double _balance = 0.0;
  bool _isBalanceLoading = true;

  // Payment
  bool _isProcessingPayment = false;
  bool _isWithdrawing = false;
  String? _authToken;

  // Top up phone
  String? _savedTopUpPhone;
  String? _savedWithdrawPhone;

  final AuthService _authService = AuthService();

  static const String _api = 'https://clash-api-m5mr.onrender.com/api';
  static const Duration _timeout = Duration(seconds: 15);

  bool get _isCurrentUser => widget.userId == _authService.userId;

  // Local channels list
  List<UserChannel> _userChannels = [];

  // ==========================================================================
  // INIT
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    _userChannels = List.from(widget.userChannels);

    final channelCount = _userChannels.length.clamp(0, 3);
    _tabController = TabController(length: channelCount, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _selectedTab = _tabController.index);
      }
    });

    _nicknameController = TextEditingController();
    _clubController = TextEditingController();
    _countryController = TextEditingController();

    _loadUserData();

    if (_isCurrentUser) {
      _initPaymentGate();
    }
  }

// ==========================================================================
// PAYMENT GATE - loads auth token BEFORE checking visibility, then only
// fetches balance/phones if payment features are actually allowed to show
// ==========================================================================

  Future<void> _initPaymentGate() async {
    await _loadAuthToken();
    await _checkPaymentVisibility();
    if (_showPaymentFeatures) {
      _fetchBalance();
      _fetchSavedPhones();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nicknameController.dispose();
    _clubController.dispose();
    _countryController.dispose();
    _nicknameFocus.dispose();
    _clubFocus.dispose();
    _countryFocus.dispose();
    super.dispose();
  }

  // ==========================================================================
  // DATA LOADING
  // ==========================================================================

  // ============================================================================
// LOAD USER DATA - HANDLES BOTH OBJECT AND ARRAY
// ============================================================================

  Future<void> _loadUserData() async {
  setState(() => _isLoading = true);

  // ✅ Instant paint from AppCache if this is the current user and cache matches
  if (_isCurrentUser &&
      AppCache.profile != null &&
      (AppCache.profile!['user_id']?.toString() ??
              AppCache.profile!['userId']?.toString() ??
              '') ==
          widget.userId) {
    try {
      final cachedUser = UserData.fromJson(AppCache.profile!);
      _applyUserData(cachedUser);
      debugPrint('⚡ Loaded profile instantly from AppCache');
    } catch (e) {
      debugPrint('⚠️ Failed to apply cached profile: $e');
    }
  }

  try {
    final response = await http
        .get(
          Uri.parse(
              '${widget.apiBaseUrl}/api/profile/profile/${widget.userId}'),
          headers: _headers(),
        )
        .timeout(_timeout);

    debugPrint('📥 GET profile: ${response.statusCode}');

    if (response.statusCode == 200 && mounted) {
      final decoded = jsonDecode(response.body);

      if (decoded is List) {
        if (decoded.isEmpty) {
          debugPrint('📭 No profile found - going to edit mode');
          setState(() {
            _isLoading = false;
            _isEditing = true;
          });
          return;
        }
        final Map<String, dynamic> userMap =
            Map<String, dynamic>.from(decoded.first as Map);
        final user = UserData.fromJson(userMap);
        _applyUserData(user);
        if (_isCurrentUser) await AppCache.saveProfile(userMap); // ✅ keep cache fresh
      } else if (decoded is Map) {
        final Map<String, dynamic> userMap =
            Map<String, dynamic>.from(decoded);
        final user = UserData.fromJson(userMap);
        _applyUserData(user);
        if (_isCurrentUser) await AppCache.saveProfile(userMap); // ✅ keep cache fresh
      } else {
        setState(() {
          _isLoading = false;
          _isEditing = true;
        });
      }
    } else if (response.statusCode == 404) {
      setState(() {
        _isLoading = false;
        _isEditing = true;
      });
    } else {
      // ✅ Network failed but we already painted from cache above (if any) — don't force edit mode
      if (_userData == null) {
        setState(() => _isLoading = false);
      }
    }
  } catch (e) {
    debugPrint('❌ Load user error: $e');
    // ✅ If cache already populated the view, just stop the spinner silently
    if (_userData == null) {
      setState(() => _isLoading = false);
    } else {
      setState(() => _isLoading = false);
    }
  }
}

  void _applyUserData(UserData user) {
    setState(() {
      _userData = user;
      _balance = user.balance;
      _nicknameController.text = user.nickname;
      _clubController.text = user.clubFan;
      _countryController.text = user.countryFan;
      _isLoading = false;
      _isEditing = false; // ✅ Show view mode for existing user
    });
  }

// ============================================================================
// SAVE PROFILE - CORRECT URL AND METHOD
// ============================================================================

  Future<void> _saveProfile() async {
    if (!_isCurrentUser) return;

    final nickname = _nicknameController.text.trim();
    final club = _clubController.text.trim();
    final country = _countryController.text.trim();

    if (nickname.isEmpty) {
      ToastHelper.showWarning('Nickname is required');
      return;
    }
    if (club.isEmpty) {
      ToastHelper.showWarning('Favorite club is required');
      return;
    }
    if (country.isEmpty) {
      ToastHelper.showWarning('Country is required');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final body = {
        'user_id': widget.userId,
        'username': widget.username,
        'phone': widget.phone,
        'nickname': nickname,
        'club_fan': club,
        'country_fan': country,
        'balance': _balance,
        'number_of_bets': _userData?.numberOfBets ?? 0,
      };

      // ✅ CORRECT: New user = POST, Existing user = PUT
      final bool isNewUser = _userData == null;

      final url = isNewUser
          ? '${widget.apiBaseUrl}/api/profile/create_profile'
          : '${widget.apiBaseUrl}/api/profile/profiles/${widget.userId}';

      debugPrint('📤 SAVING: ${isNewUser ? "NEW" : "UPDATE"} user');
      debugPrint('   URL: $url');
      debugPrint('   Body: ${jsonEncode(body)}');

      // ✅ Use correct method
      final response = isNewUser
          ? await http
              .post(
                Uri.parse(url),
                headers: _headers(),
                body: jsonEncode(body),
              )
              .timeout(_timeout)
          : await http
              .put(
                Uri.parse(url),
                headers: _headers(),
                body: jsonEncode(body),
              )
              .timeout(_timeout);

      debugPrint('📥 Status: ${response.statusCode}');
      debugPrint('📥 Body: ${response.body}');

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          mounted) {
        final decoded = jsonDecode(response.body);

        // ✅ Convert Map<dynamic, dynamic> to Map<String, dynamic>
        Map<String, dynamic> userMap;
        if (decoded is List) {
          if (decoded.isEmpty) {
            ToastHelper.showError('Empty response from server');
            setState(() => _isSaving = false);
            return;
          }
          userMap = Map<String, dynamic>.from(decoded.first as Map);
        } else if (decoded is Map) {
          userMap = Map<String, dynamic>.from(decoded);
        } else {
          ToastHelper.showError('Invalid response format');
          setState(() => _isSaving = false);
          return;
        }

        final user = UserData.fromJson(userMap);

        setState(() {
          _userData = user;
          _balance = user.balance;
          _isEditing = false;
        });

        widget.onUserUpdated?.call(user);
        ToastHelper.showSuccess('Profile saved!');
        await AppCache.saveProfile(userMap);
        _unfocusAll();

        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        ToastHelper.showError('Save failed (${response.statusCode})');
        debugPrint('❌ Error response: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Save profile error: $e');
      ToastHelper.showError('Network error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

// ============================================================================
// HEADERS WITH AUTH TOKEN
// ============================================================================

  Map<String, String> _headers() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // ✅ Add auth token if available (required by backend)
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
  }

  Future<void> _loadAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('auth_token');
    } catch (e) {
      debugPrint('❌ Failed to load auth token: $e');
    }
  }

  Future<void> _fetchBalance() async {
    if (!_isCurrentUser) return;
    setState(() => _isBalanceLoading = true);

    try {
      // Use PaymentService static method directly
      final balance = await PaymentService.getUserBalance(
        userId: widget.userId,
        authToken: _authToken,
        forceRefresh: true,
      );

      if (mounted) {
        setState(() {
          _balance = balance;
          if (_userData != null) {
            _userData = UserData(
              userId: _userData!.userId,
              username: _userData!.username,
              phone: _userData!.phone,
              nickname: _userData!.nickname,
              clubFan: _userData!.clubFan,
              countryFan: _userData!.countryFan,
              numberOfBets: _userData!.numberOfBets,
              balance: balance,
            );
          }
          _isBalanceLoading = false;
        });

        // Cache balance
        await TransactionLocalStorage.cacheBalance(balance);
      }
    } catch (e) {
      debugPrint('❌ Fetch balance error: $e');
      // Try cached balance
      final cachedBalance = await TransactionLocalStorage.getCachedBalance();
      if (cachedBalance != null && mounted) {
        setState(() {
          _balance = cachedBalance;
          _isBalanceLoading = false;
        });
      } else {
        if (mounted) setState(() => _isBalanceLoading = false);
      }
    }
  }

  Future<void> _fetchSavedPhones() async {
    if (!_isCurrentUser) return;
    try {
      // Try to get saved top-up phone from user profile
      final response = await http
          .get(
            Uri.parse('$_api/auth/user/id/${widget.userId}'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final phone = data['user']['phone']?.toString() ?? '';
          if (phone.isNotEmpty) {
            setState(() {
              _savedTopUpPhone = phone;
              _savedWithdrawPhone = phone;
            });
          }
        }
      }

      // Try saved topup phone endpoint
      final topUpRes = await http
          .get(
            Uri.parse('$_api/auth/user/${widget.userId}/topup-phone'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 5));
      if (topUpRes.statusCode == 200) {
        final data = jsonDecode(topUpRes.body);
        if (data['success'] == true &&
            data['phone']?.toString().isNotEmpty == true) {
          setState(() => _savedTopUpPhone = data['phone']?.toString());
        }
      }

      // Try saved withdraw phone endpoint
      final withdrawRes = await http
          .get(
            Uri.parse('$_api/auth/user/${widget.userId}/withdraw-phone'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 5));
      if (withdrawRes.statusCode == 200) {
        final data = jsonDecode(withdrawRes.body);
        if (data['success'] == true &&
            data['phone']?.toString().isNotEmpty == true) {
          setState(() => _savedWithdrawPhone = data['phone']?.toString());
        }
      }
    } catch (e) {
      debugPrint('❌ Fetch phones error: $e');
    }
  }

  // ==========================================================================
  // SAVE PROFILE
  // ==========================================================================

  void _unfocusAll() {
    _nicknameFocus.unfocus();
    _clubFocus.unfocus();
    _countryFocus.unfocus();
    FocusScope.of(context).unfocus();
  }

  // ==========================================================================
  // LOGOUT
  // ==========================================================================

  Future<void> _logout() async {
    if (!_isCurrentUser || _isLoggingOut) return;
    setState(() => _isLoggingOut = true);

    try {
      await FirebaseAuth.instance.signOut();
      await _authService.logout();
      widget.onLogout?.call();
      if (mounted) {
        Navigator.pop(context);
        ToastHelper.showSuccess('Logged out');
      }
    } catch (e) {
      debugPrint('❌ Logout error: $e');
      ToastHelper.showError('Logout failed');
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  // ==========================================================================
  // STK PUSH - TOP UP (USING PAYMENT SERVICE)
  // ==========================================================================

  Future<void> _showTopUpDialog() async {
    if (!_isCurrentUser) return;

    final amountController = TextEditingController();
    final phoneController = TextEditingController();
    bool useSaved = true;

    if (_savedTopUpPhone != null && _savedTopUpPhone!.isNotEmpty) {
      phoneController.text = _savedTopUpPhone!;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          // Local state for this dialog
          bool isProcessing = false;
          String statusMessage = '';

          return AlertDialog(
            backgroundColor: FanColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FanRadius.lg),
              side:  BorderSide(color: FanColors.border),
            ),
            title: Row(
              children: [
                Icon(Icons.add_circle, color: FanColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Top Up Balance',
                  style: FanTypography.title.copyWith(fontSize: 15),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBalanceDisplay(),
                const SizedBox(height: 12),

                // ✅ Disable inputs when processing
                AbsorbPointer(
                  absorbing: isProcessing,
                  child: Opacity(
                    opacity: isProcessing ? 0.5 : 1.0,
                    child: Column(
                      children: [
                        TextField(
                          controller: amountController,
                          decoration: const InputDecoration(
                            labelText: 'Amount (KES)',
                            hintText: 'Enter amount to top up',
                            prefixIcon: Icon(Icons.monetization_on),
                          ),
                          keyboardType: TextInputType.number,
                          autofocus: true,
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: phoneController,
                          decoration: InputDecoration(
                            labelText: 'M-Pesa Phone Number',
                            hintText: 'e.g., 0712345678',
                            prefixIcon: const Icon(Icons.phone_android),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => phoneController.clear(),
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Checkbox(
                              value: useSaved,
                              onChanged: isProcessing
                                  ? null
                                  : (val) {
                                      setStateDialog(() {
                                        useSaved = val ?? true;
                                        if (useSaved &&
                                            _savedTopUpPhone != null) {
                                          phoneController.text =
                                              _savedTopUpPhone!;
                                        } else {
                                          phoneController.clear();
                                        }
                                      });
                                    },
                              activeColor: FanColors.primary,
                            ),
                            Expanded(
                              child: Text(
                                'Save this number for future top-ups',
                                style: FanTypography.caption.copyWith(
                                  color: FanColors.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        _buildInfoBox(
                          icon: Icons.info_outline,
                          color: FanColors.primary,
                          text: 'You will receive a prompt to enter your PIN',
                        ),
                      ],
                    ),
                  ),
                ),

                // ✅ Status message during processing
                if (statusMessage.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusMessage.contains('✅')
                          ? FanColors.primaryDim
                          : FanColors.awayDim,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        if (statusMessage.contains('✅'))
                          Icon(Icons.check_circle,
                              size: 14, color: FanColors.primary)
                        else if (statusMessage.contains('❌'))
                          Icon(Icons.error_outline,
                              size: 14, color: FanColors.away)
                        else
                         SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: FanColors.primary,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            statusMessage,
                            style: TextStyle(
                              fontSize: 11,
                              color: statusMessage.contains('✅')
                                  ? FanColors.primary
                                  : FanColors.away,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              // ✅ Cancel button - disabled during processing
              TextButton(
                onPressed:
                    isProcessing ? null : () => Navigator.pop(context, false),
                child: Text(
                  isProcessing ? 'Processing...' : 'Cancel',
                  style: TextStyle(
                    color: isProcessing
                        ? FanColors.textTertiary
                        : FanColors.textSecondary,
                  ),
                ),
              ),

              // ✅ Pay button - shows loading state
              ElevatedButton(
                onPressed: isProcessing
                    ? null
                    : () async {
                        final amount =
                            double.tryParse(amountController.text.trim());
                        final phone = phoneController.text.trim();

                        if (amount == null || amount <= 0) {
                          ToastHelper.showWarning('Enter a valid amount');
                          return;
                        }
                        if (phone.isEmpty || !_isValidPhone(phone)) {
                          ToastHelper.showWarning('Enter a valid phone number');
                          return;
                        }

                        // ✅ 1. Switch to processing mode (dialog stays open)
                        setStateDialog(() {
                          isProcessing = true;
                          statusMessage =
                              '⏳ Processing... Please check your phone';
                        });

                        // ✅ 2. Wait for payment to complete
                        final success = await _initiateSTKPush(
                          amount: amount,
                          phone: phone,
                          useSaved: useSaved,
                        );

                        if (success) {
                          // ✅ 3a. Success - show success, then close
                          setStateDialog(() {
                            statusMessage = '✅ Payment successful!';
                          });

                          // Wait a moment for user to see success
                          await Future.delayed(const Duration(seconds: 1));

                          // Close dialog with success
                          Navigator.pop(context, true);

                          // Refresh balance
                          await _refreshBalanceAfterTransaction();
                          ToastHelper.showSuccess(
                              'Balance updated to KES ${_balance.toStringAsFixed(2)}');
                        } else {
                          // ✅ 3b. Failure - show error, keep dialog open
                          setStateDialog(() {
                            statusMessage =
                                '❌ Payment failed. Please try again.';
                            isProcessing = false;
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FanColors.primary,
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
                    : const Text('Pay via M-Pesa'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showProcessingDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: FanColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FanRadius.lg),
        ),
        title: const Text('Processing Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
           CircularProgressIndicator(color: FanColors.primary),
            const SizedBox(height: 12),
            Text(
              'Please check your phone and enter your PIN',
              style: FanTypography.body.copyWith(
                color: FanColors.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This may take up to 3 minutes',
              style: FanTypography.caption.copyWith(
                color: FanColors.textTertiary,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Do not close this dialog while processing',
              style: FanTypography.caption.copyWith(
                color: FanColors.away,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshBalanceAfterTransaction() async {
    if (!mounted || !_isCurrentUser) return;

    setState(() => _isBalanceLoading = true);

    try {
      final balance = await PaymentService.getUserBalance(
        userId: widget.userId,
        authToken: _authToken,
        forceRefresh: true,
      );

      if (mounted) {
        setState(() {
          _balance = balance;
          if (_userData != null) {
            _userData = UserData(
              userId: _userData!.userId,
              username: _userData!.username,
              phone: _userData!.phone,
              nickname: _userData!.nickname,
              clubFan: _userData!.clubFan,
              countryFan: _userData!.countryFan,
              numberOfBets: _userData!.numberOfBets,
              balance: balance,
            );
          }
          _isBalanceLoading = false;
        });

        await TransactionLocalStorage.cacheBalance(balance);
      }
    } catch (e) {
      debugPrint('❌ Refresh balance error: $e');
      final cachedBalance = await TransactionLocalStorage.getCachedBalance();
      if (cachedBalance != null && mounted) {
        setState(() {
          _balance = cachedBalance;
          _isBalanceLoading = false;
        });
      } else {
        if (mounted) setState(() => _isBalanceLoading = false);
      }
    }
  }

  Future<bool> _initiateSTKPush({
    required double amount,
    required String phone,
    bool useSaved = false,
  }) async {
    if (_isProcessingPayment || !_isCurrentUser) return false;

    setState(() => _isProcessingPayment = true);

    try {
      final result = await PaymentService.initiateSTKPush(
        userId: widget.userId,
        username: widget.username,
        amount: amount,
        phoneNumber: phone,
        authToken: _authToken,
        purpose: 'Top up balance',
      );

      if (result.isSuccess) {
        if (useSaved) await _saveTopUpPhone(phone);

        // ✅ Update balance from result (same as admin)
        if (result.newBalance != null) {
          setState(() {
            _balance = result.newBalance!;
            if (_userData != null) {
              _userData = UserData(
                userId: _userData!.userId,
                username: _userData!.username,
                phone: _userData!.phone,
                nickname: _userData!.nickname,
                clubFan: _userData!.clubFan,
                countryFan: _userData!.countryFan,
                numberOfBets: _userData!.numberOfBets,
                balance: result.newBalance!,
              );
            }
          });
          await TransactionLocalStorage.cacheBalance(result.newBalance!);
        }

        setState(() => _isProcessingPayment = false);

        if (mounted) {
          ToastHelper.showSuccess(result.message ?? 'Payment successful!');
        }
        return true;
      } else {
        setState(() => _isProcessingPayment = false);

        if (mounted) {
          ToastHelper.showError(result.error ?? 'Payment failed');
        }
        return false;
      }
    } catch (e) {
      debugPrint('❌ STK Push error: $e');
      if (mounted) {
        ToastHelper.showError('Failed to initiate payment: ${e.toString()}');
      }
      setState(() => _isProcessingPayment = false);
      return false;
    }
  }
  // ==========================================================================
  // B2C WITHDRAWAL (USING PAYMENT SERVICE)
  // ==========================================================================

  Future<void> _showWithdrawDialog() async {
    if (!_isCurrentUser) return;

    final amountController = TextEditingController();
    final phoneController = TextEditingController();
    bool useSaved = true;

    if (_savedWithdrawPhone != null && _savedWithdrawPhone!.isNotEmpty) {
      phoneController.text = _savedWithdrawPhone!;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: FanColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FanRadius.lg),
            side:  BorderSide(color: FanColors.border),
          ),
          title: Row(
            children: [
              Icon(Icons.account_balance, color: FanColors.away, size: 20),
              const SizedBox(width: 8),
              Text(
                'Withdraw Funds',
                style: FanTypography.title.copyWith(fontSize: 15),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBalanceDisplay(),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (KES)',
                  hintText: 'Enter amount to withdraw',
                  prefixIcon: Icon(Icons.monetization_on),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'M-Pesa Phone Number',
                  hintText: 'e.g., 0712345678',
                  prefixIcon: const Icon(Icons.phone_android),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () => phoneController.clear(),
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Checkbox(
                    value: useSaved,
                    onChanged: (val) {
                      setState(() {
                        useSaved = val ?? true;
                        if (useSaved && _savedWithdrawPhone != null) {
                          phoneController.text = _savedWithdrawPhone!;
                        } else {
                          phoneController.clear();
                        }
                      });
                    },
                    activeColor: FanColors.primary,
                  ),
                  Expanded(
                    child: Text(
                      'Save this number for future withdrawals',
                      style: FanTypography.caption.copyWith(
                        color: FanColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
              _buildInfoBox(
                icon: Icons.warning_amber_rounded,
                color: FanColors.away,
                text: 'Withdrawals are processed within 24 hours',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: FanTypography.body.copyWith(
                  color: FanColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim());
                final phone = phoneController.text.trim();

                if (amount == null || amount <= 0) {
                  ToastHelper.showWarning('Enter a valid amount');
                  return;
                }
                if (amount > _balance) {
                  ToastHelper.showWarning('Insufficient balance');
                  return;
                }
                if (phone.isEmpty || !_isValidPhone(phone)) {
                  ToastHelper.showWarning('Enter a valid phone number');
                  return;
                }

                Navigator.pop(context);

                // Show processing dialog
                await _showProcessingDialog();

                final success = await _processWithdrawal(
                  amount: amount,
                  phone: phone,
                  useSaved: useSaved,
                );

                // Close processing dialog
                if (mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                }

                if (success && mounted) {
                  await _refreshBalanceAfterTransaction();
                  ToastHelper.showSuccess('Withdrawal submitted!');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FanColors.away,
              ),
              child: _isWithdrawing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Withdraw'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _processWithdrawal({
    required double amount,
    required String phone,
    bool useSaved = false,
  }) async {
    if (!_isCurrentUser) return false;

    setState(() => _isWithdrawing = true);

    try {
      final result = await PaymentService.initiateB2CPayment(
        userId: widget.userId,
        username: widget.username,
        channelId: 'user_withdrawal',
        amount: amount,
        phoneNumber: phone,
        authToken: _authToken,
        remarks: 'User withdrawal',
        occasion: 'User Withdrawal',
      );

      if (result.isSuccess) {
        if (useSaved) await _saveWithdrawPhone(phone);

        if (result.newBalance != null) {
          setState(() {
            _balance = result.newBalance!;
            if (_userData != null) {
              _userData = UserData(
                userId: _userData!.userId,
                username: _userData!.username,
                phone: _userData!.phone,
                nickname: _userData!.nickname,
                clubFan: _userData!.clubFan,
                countryFan: _userData!.countryFan,
                numberOfBets: _userData!.numberOfBets,
                balance: result.newBalance!,
              );
            }
          });
          await TransactionLocalStorage.cacheBalance(result.newBalance!);
        }

        setState(() => _isWithdrawing = false);
        ToastHelper.showSuccess(
            result.message ?? 'Withdrawal initiated successfully!');
        return true;
      } else {
        ToastHelper.showError(result.error ?? 'Withdrawal failed');
        setState(() => _isWithdrawing = false);
        return false;
      }
    } catch (e) {
      debugPrint('❌ Withdrawal error: $e');
      ToastHelper.showError('Failed to process withdrawal');
      setState(() => _isWithdrawing = false);
      return false;
    }
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  bool _isValidPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return RegExp(r'^(0|254)?[7-9][0-9]{8}$').hasMatch(cleaned);
  }

  Future<bool> _saveTopUpPhone(String phone) async {
    if (!_isCurrentUser) return false;
    try {
      final response = await http
          .post(
            Uri.parse('$_api/auth/user/${widget.userId}/topup-phone'),
            headers: _headers(),
            body: jsonEncode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        setState(() => _savedTopUpPhone = phone);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _saveWithdrawPhone(String phone) async {
    if (!_isCurrentUser) return false;
    try {
      final response = await http
          .post(
            Uri.parse('$_api/auth/user/${widget.userId}/withdraw-phone'),
            headers: _headers(),
            body: jsonEncode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        setState(() => _savedWithdrawPhone = phone);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  String _getInitials() {
    final name = _userData?.nickname ?? widget.username;
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  // ==========================================================================
  // UI BUILDERS
  // ==========================================================================

  Widget _buildBalanceDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: FanDecorations.statChip,
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 14, color: FanColors.primary),
          const SizedBox(width: 8),
          Text(
            _isBalanceLoading
                ? 'Loading...'
                : 'KES ${_balance.toStringAsFixed(2)}',
            style: FanTypography.body.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FanColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(
      {required IconData icon, required Color color, required String text}) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.1), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: FanTypography.caption.copyWith(
                fontSize: 9,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _showPaymentFeatures = true;
  bool _isCheckingVisibility = false;

// ============================================================================
// ADD THIS METHOD TO CHECK VISIBILITY
// ============================================================================

  Future<void> _checkPaymentVisibility() async {
  if (!_isCurrentUser) {
    setState(() => _showPaymentFeatures = false);
    return;
  }

  setState(() => _isCheckingVisibility = true);

  try {
    final response = await http.get(
      Uri.parse('$_api/visibility/votes_button_show'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200 && mounted) {
      final data = json.decode(response.body);
      setState(() {
        _showPaymentFeatures = data['value'] ?? false; // ⬅️ fail-closed default
      });
    } else {
      debugPrint('⚠️ Visibility check non-200: ${response.statusCode}');
      setState(() => _showPaymentFeatures = false);     // ⬅️ fail-closed
    }
  } catch (e) {
    debugPrint('❌ Error checking visibility: $e');
    setState(() => _showPaymentFeatures = false);        // ⬅️ fail-closed
  } finally {
    if (mounted) setState(() => _isCheckingVisibility = false);
  }
}
  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: _isProcessingPayment || _isWithdrawing ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isPrimary ? FanColors.primary : FanColors.surfaceSunken,
          borderRadius: BorderRadius.circular(16),
          border: isPrimary
              ? null
              : Border.all(color: FanColors.border, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 10,
              color: isPrimary ? Colors.white : FanColors.textSecondary,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: FanTypography.caption.copyWith(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: isPrimary ? Colors.white : FanColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandleBar() => Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        width: 32,
        height: 3,
        decoration: BoxDecoration(
          color: FanColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: FanDecorations.crestFrame,
              child: Center(
                child: Text(
                  _getInitials(),
                  style:  TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: FanColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userData?.nickname ?? widget.username,
                    style: FanTypography.title.copyWith(
                      fontSize: 14,
                      color: FanColors.textPrimary,
                    ),
                  ),
                  Text(
                    _userChannels.length == 0
                        ? 'No channels'
                        : '${_userChannels.length} ${_userChannels.length == 1 ? 'Channel' : 'Channels'}',
                    style: FanTypography.caption.copyWith(
                      color: FanColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: FanColors.surfaceSunken,
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.close, size: 14, color: FanColors.textSecondary),
              ),
            ),
          ],
        ),
      );

  // ==========================================================================
  // PROFILE SECTION
  // ==========================================================================

  Widget _buildProfileSection() {
  if (_isLoading || _isCheckingVisibility) {
    return  Center(
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: FanColors.primary,
        ),
      ),
    );
  }

  return SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    child: Column(
      children: [
        // ✅ Only show balance card when visibility allows it
        if (_isCurrentUser && _showPaymentFeatures) ...[
          _buildBalanceCard(),
          const SizedBox(height: 10),
        ],
        _userData == null ? _buildNoProfileView() : _buildProfileView(),
      ],
    ),
  );
}

  Widget _buildBalanceCard() {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: FanDecorations.card(
      borderColor: FanColors.borderActive,
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: FanColors.primaryDim,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.account_balance_wallet,
              size: 16, color: FanColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Balance',
                style: FanTypography.caption.copyWith(
                  color: FanColors.textTertiary,
                ),
              ),
              Text(
                _isBalanceLoading
                    ? 'Loading...'
                    : 'KES ${_balance.toStringAsFixed(2)}',
                style: FanTypography.title.copyWith(
                  fontSize: 14,
                  color: FanColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            _buildActionChip(
              icon: Icons.add,
              label: 'Deposit',
              onTap: _showTopUpDialog,
              isPrimary: true,
            ),
            const SizedBox(width: 6),
            _buildActionChip(
              icon: Icons.remove,
              label: 'Withdraw',
              onTap: _showWithdrawDialog,
              isPrimary: false,
            ),
          ],
        ),
      ],
    ),
  );
}

 Widget _buildProfileView() {
    return Column(
      children: [
        _buildInfoRow(
          icon: Icons.person_outline,
          label: 'Username',
          value: '@${_userData!.username}',
        ),
        const SizedBox(height: 5),

        // ✅ CHANGE THIS - Show team nickname
        _buildInfoRow(
          icon: Icons.shield_outlined,
          label: 'Team Nickname', // Changed
          value:
              _userData!.nickname.isNotEmpty ? _userData!.nickname : 'Not set',
        ),
        const SizedBox(height: 5),

        _buildInfoRow(
          icon: Icons.sports_soccer_outlined,
          label: 'Team/Club',
          value: _userData!.clubFan.isNotEmpty ? _userData!.clubFan : 'Not set',
        ),
        const SizedBox(height: 5),

        _buildInfoRow(
          icon: Icons.flag_outlined,
          label: 'Country You Support',
          value: _userData!.countryFan.isNotEmpty
              ? _userData!.countryFan
              : 'Not set',
        ),
        const SizedBox(height: 5),

        _buildInfoRow(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: _userData!.phone.isNotEmpty ? _userData!.phone : 'Not set',
        ),
        const SizedBox(height: 10),

        if (_isCurrentUser)
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  onTap: () => setState(() => _isEditing = true),
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  label: 'Logout',
                  icon: Icons.logout_outlined,
                  onTap: _logout,
                  isPrimary: false,
                  isLoading: _isLoggingOut,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: FanDecorations.statChip,
      child: Row(
        children: [
          Icon(icon, size: 12, color: FanColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: FanTypography.caption.copyWith(
                    color: FanColors.textTertiary,
                  ),
                ),
                Text(
                  value,
                  style: FanTypography.body.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: FanColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoProfileView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: FanColors.primaryDim,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.person_add_alt_1_outlined,
                size: 24,
                color: FanColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Complete Your Profile',
            style: FanTypography.title.copyWith(
              fontSize: 14,
              color: FanColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Center(
          child: Text(
            'Tell us about yourself',
            style: FanTypography.caption.copyWith(
              color: FanColors.textTertiary,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ✅ CHANGE THIS
        _buildTextField(
          controller: _nicknameController,
          focusNode: _nicknameFocus,
          label: 'TEAM NICKNAME', // Changed
          hint: 'e.g., Red Devils, The Gunners', // Changed
          icon: Icons.shield_outlined, // Changed
          onSubmitted: () => _clubFocus.requestFocus(),
        ),
        const SizedBox(height: 10),

        _buildTextField(
          controller: _clubController,
          focusNode: _clubFocus,
          label: 'FAVORITE CLUB',
          hint: 'Which club do you support?',
          icon: Icons.sports_soccer_outlined,
          onSubmitted: () => _countryFocus.requestFocus(),
        ),
        const SizedBox(height: 10),

        _buildTextField(
          controller: _countryController,
          focusNode: _countryFocus,
          label: 'COUNTRY',
          hint: 'Where are you from?',
          icon: Icons.flag_outlined,
          onSubmitted: _unfocusAll,
        ),
        const SizedBox(height: 16),

        _buildActionButton(
          label: 'Complete Profile',
          icon: Icons.check_circle_outline,
          onTap: _saveProfile,
          isPrimary: true,
          isLoading: _isSaving,
        ),
      ],
    );
  }

 Widget _buildEditMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: FanColors.primaryDim,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.person_outline,
                size: 20,
                color: FanColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ✅ CHANGE THIS - Use existing nickname controller but label it as Team Nickname
        _buildTextField(
          controller: _nicknameController,
          focusNode: _nicknameFocus,
          label: 'TEAM NICKNAME', // Changed from 'NICKNAME'
          hint: 'e.g., Red Devils, The Gunners', // Changed hint
          icon: Icons.shield_outlined, // Changed icon to shield
          onSubmitted: () => _clubFocus.requestFocus(),
        ),
        const SizedBox(height: 10),

        _buildTextField(
          controller: _clubController,
          focusNode: _clubFocus,
          label: 'FAVORITE CLUB',
          hint: 'Which club do you support?',
          icon: Icons.sports_soccer_outlined,
          onSubmitted: () => _countryFocus.requestFocus(),
        ),
        const SizedBox(height: 10),

        _buildTextField(
          controller: _countryController,
          focusNode: _countryFocus,
          label: 'COUNTRY',
          hint: 'Where are you from?',
          icon: Icons.flag_outlined,
          onSubmitted: _unfocusAll,
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'Cancel',
                icon: Icons.close_outlined,
                onTap: () {
                  setState(() => _isEditing = false);
                  _unfocusAll();
                },
                isPrimary: false,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                label: 'Save',
                icon: Icons.save_outlined,
                onTap: _saveProfile,
                isPrimary: true,
                isLoading: _isSaving,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    IconData? icon,
    VoidCallback? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: FanTypography.tag.copyWith(
            color: FanColors.textTertiary,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          decoration: BoxDecoration(
            color: FanColors.surfaceSunken,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: FanColors.border, width: 0.5),
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => onSubmitted?.call(),
            style: FanTypography.body.copyWith(
              fontSize: 12,
              color: FanColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: FanTypography.caption.copyWith(
                color: FanColors.textTertiary,
                fontSize: 10,
              ),
              prefixIcon: icon != null
                  ? Icon(icon, size: 12, color: FanColors.textTertiary)
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = true,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: isPrimary ? FanColors.primary : FanColors.surfaceSunken,
          borderRadius: BorderRadius.circular(8),
          border: isPrimary
              ? null
              : Border.all(color: FanColors.border, width: 0.5),
        ),
        child: Center(
          child: isLoading
              ?  SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: FanColors.primary,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 11,
                      color: isPrimary ? Colors.white : FanColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: FanTypography.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color:
                            isPrimary ? Colors.white : FanColors.textSecondary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ==========================================================================
  // CHANNEL FRAGMENT
  // ==========================================================================

  Widget _buildChannelFragment(int channelIndex) {
    if (_userChannels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_off_outlined,
              size: 32,
              color: FanColors.textTertiary.withOpacity(0.4),
            ),
            const SizedBox(height: 8),
            Text(
              _isCurrentUser
                  ? 'No channels joined'
                  : '${widget.username} has no channels',
              style: FanTypography.body.copyWith(
                fontSize: 11,
                color: FanColors.textTertiary.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    final channel = _userChannels[channelIndex];
    final sortedMembers = List<ChannelMember>.from(channel.members)
      ..sort((a, b) => b.seasonPoints.compareTo(a.seasonPoints));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Channel header - slim
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: FanColors.primaryDim,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: FanColors.borderActive, width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: FanColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      channel.name.isNotEmpty
                          ? channel.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.name,
                        style: FanTypography.title.copyWith(
                          fontSize: 11,
                          color: FanColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.people,
                              size: 8, color: FanColors.textTertiary),
                          const SizedBox(width: 2),
                          Text(
                            '${channel.memberCount}',
                            style: FanTypography.caption.copyWith(
                              color: FanColors.textTertiary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.emoji_events,
                              size: 8, color: FanColors.textTertiary),
                          const SizedBox(width: 2),
                          Text(
                            'S${channel.season}',
                            style: FanTypography.caption.copyWith(
                              color: FanColors.textTertiary,
                            ),
                          ),
                          if (channel.isAdmin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: FanColors.primaryMuted,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Admin',
                                style: FanTypography.caption.copyWith(
                                  fontSize: 6,
                                  fontWeight: FontWeight.w600,
                                  color: FanColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Members list - compact
          Expanded(
            child: sortedMembers.isEmpty
                ? Center(
                    child: Text(
                      'No members yet',
                      style: FanTypography.caption.copyWith(
                        color: FanColors.textTertiary.withOpacity(0.4),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: sortedMembers.length,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    itemBuilder: (context, index) {
                      final member = sortedMembers[index];
                      final isTop3 = index < 3;
                      final rankEmojis = ['🥇', '🥈', '🥉'];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: isTop3
                              ? FanColors.primaryDim
                              : FanColors.surfaceSunken,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isTop3
                                ? FanColors.borderActive
                                : FanColors.border,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Rank
                            Container(
                              width: 18,
                              alignment: Alignment.center,
                              child: isTop3
                                  ? Text(
                                      rankEmojis[index],
                                      style: const TextStyle(fontSize: 10),
                                    )
                                  : Text(
                                      '#${index + 1}',
                                      style: FanTypography.caption.copyWith(
                                        color: FanColors.textTertiary
                                            .withOpacity(0.4),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 4),

                            // Avatar
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: FanColors.primaryDim,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  member.username.isNotEmpty
                                      ? member.username[0].toUpperCase()
                                      : '?',
                                  style: FanTypography.caption.copyWith(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: FanColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Name
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        member.username,
                                        style: FanTypography.body.copyWith(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: FanColors.textPrimary,
                                        ),
                                      ),
                                      if (member.userId == widget.userId &&
                                          _isCurrentUser) ...[
                                        const SizedBox(width: 3),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: FanColors.primaryMuted,
                                            borderRadius:
                                                BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            'You',
                                            style:
                                                FanTypography.caption.copyWith(
                                              fontSize: 5,
                                              fontWeight: FontWeight.w600,
                                              color: FanColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Icon(Icons.check_circle_outline,
                                          size: 7,
                                          color: FanColors.textTertiary),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${member.correctVotes}/${member.totalVotes}',
                                        style: FanTypography.caption.copyWith(
                                          fontSize: 7,
                                          color: FanColors.textTertiary,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Icon(Icons.chat_bubble_outline,
                                          size: 7,
                                          color: FanColors.textTertiary),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${member.msgCount}',
                                        style: FanTypography.caption.copyWith(
                                          fontSize: 7,
                                          color: FanColors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Points
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isTop3
                                    ? FanColors.primary
                                    : FanColors.surface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 6,
                                    color: isTop3
                                        ? Colors.white
                                        : FanColors.textTertiary,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${member.seasonPoints}',
                                    style: FanTypography.caption.copyWith(
                                      fontSize: 7,
                                      fontWeight: FontWeight.w600,
                                      color: isTop3
                                          ? Colors.white
                                          : FanColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Profile button
                            if (_isCurrentUser)
                              GestureDetector(
                                onTap: () => _showMemberProfile(member),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: FanColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'View',
                                    style: FanTypography.caption.copyWith(
                                      fontSize: 6,
                                      fontWeight: FontWeight.w600,
                                      color: FanColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showMemberProfile(ChannelMember member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SwipeableProfileModal(
        apiBaseUrl: widget.apiBaseUrl,
        userId: member.userId,
        username: member.username,
        phone: '',
        userChannels: _userChannels,
        onUserUpdated: (_) {},
        onLogout: () {},
      ),
    );
  }

  // ==========================================================================
  // CHANNEL TAB BAR
  // ==========================================================================

  Widget _buildChannelTabBar() {
    final channelCount = _userChannels.length.clamp(0, 3);

    if (channelCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: FanColors.surfaceSunken,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FanColors.border, width: 0.5),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: FanColors.surface,
          borderRadius: BorderRadius.circular(6),
          boxShadow: FanShadows.subtle,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: FanColors.textPrimary,
        unselectedLabelColor: FanColors.textTertiary,
        labelStyle: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w400,
        ),
        tabs: _userChannels.take(3).map((channel) {
          return Tab(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                channel.name.length > 8
                    ? '${channel.name.substring(0, 8)}...'
                    : channel.name,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==========================================================================
  // MAIN BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final channelCount = _userChannels.length.clamp(0, 3);

    return Container(
      width: screenWidth,
      height: screenHeight * 0.78,
      decoration: BoxDecoration(
        color: FanColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandleBar(),
          _buildHeader(),
           Divider(height: 0.5, color: FanColors.border),
          Expanded(
            flex: 2,
            child: _buildProfileSection(),
          ),
          if (channelCount > 0) ...[
             Divider(height: 0.5, color: FanColors.border),
            const SizedBox(height: 4),
            _buildChannelTabBar(),
            const SizedBox(height: 3),
            Expanded(
              flex: 2,
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: List.generate(
                  channelCount,
                  (index) => _buildChannelFragment(index),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.group_off_outlined,
                      size: 32,
                      color: FanColors.textTertiary.withOpacity(0.3),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isCurrentUser
                          ? 'No Channels Joined'
                          : '${widget.username} has no channels',
                      style: FanTypography.body.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: FanColors.textTertiary.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isCurrentUser
                          ? 'Join a channel to see members'
                          : 'They haven\'t joined any channels yet',
                      style: FanTypography.caption.copyWith(
                        color: FanColors.textTertiary.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
