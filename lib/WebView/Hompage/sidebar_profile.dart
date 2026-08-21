// lib/widgets/sidebar_profile.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../pages/fan_Funzy_design.dart';
import '../../services/auth_service.dart';
import '../../services/toast_helper.dart';
import '../../main.dart';
import '../../services/payment_service.dart';
import '../Hompage/channels.dart';
import '../../models/user_channel.dart';

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
// CHANNEL MEMBER MODEL
// ============================================================================

class ChannelMember {
  final String userId;
  final String username;
  final int correctVotes;
  final int totalVotes;
  final int msgCount;
  final int seasonPoints;

  ChannelMember({
    required this.userId,
    required this.username,
    required this.correctVotes,
    required this.totalVotes,
    required this.msgCount,
    required this.seasonPoints,
  });

  factory ChannelMember.fromJson(Map<String, dynamic> json) => ChannelMember(
        userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        correctVotes: json['correct_votes'] ?? 0,
        totalVotes: json['total_votes'] ?? 0,
        msgCount: json['msg_count'] ?? 0,
        seasonPoints: json['season_points'] ?? 0,
      );
}

// ============================================================================
// USER CHANNEL MODEL
// ============================================================================



// ============================================================================
// SIDEBAR PROFILE WIDGET
// ============================================================================

class SidebarProfile extends StatefulWidget {
  final String apiBaseUrl;
  final String userId;
  final String username;
  final String phone;
  final VoidCallback? onLogout;
  final List<UserChannel> userChannels;

  const SidebarProfile({
    super.key,
    required this.apiBaseUrl,
    required this.userId,
    required this.username,
    required this.phone,
    this.onLogout,
    this.userChannels = const [],
  });

  @override
  State<SidebarProfile> createState() => _SidebarProfileState();
}

class _SidebarProfileState extends State<SidebarProfile>
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

  bool _showPaymentFeatures = true;
  bool _isCheckingVisibility = false;

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
  // PAYMENT GATE
  // ==========================================================================

  Future<void> _initPaymentGate() async {
    await _loadAuthToken();
    await _checkPaymentVisibility();
    if (_showPaymentFeatures) {
      _fetchBalance();
      _fetchSavedPhones();
    }
  }

  // ==========================================================================
  // DATA LOADING
  // ==========================================================================

  Future<void> _loadUserData() async {
  setState(() => _isLoading = true);

  // Instant paint from AppCache if this is the current user and cache matches
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
      return; // ✅ Return early if cache is valid
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
          debugPrint('📭 No profile found - showing no profile view');
          setState(() {
            _isLoading = false;
            _isEditing = false; // ✅ DON'T set to true
          });
          return;
        }
        final Map<String, dynamic> userMap =
            Map<String, dynamic>.from(decoded.first as Map);
        final user = UserData.fromJson(userMap);
        _applyUserData(user);
        if (_isCurrentUser) await AppCache.saveProfile(userMap);
      } else if (decoded is Map) {
        final Map<String, dynamic> userMap =
            Map<String, dynamic>.from(decoded);
        final user = UserData.fromJson(userMap);
        _applyUserData(user);
        if (_isCurrentUser) await AppCache.saveProfile(userMap);
      } else {
        setState(() {
          _isLoading = false;
          _isEditing = false; // ✅ DON'T set to true
        });
      }
    } else if (response.statusCode == 404) {
      debugPrint('📭 Profile not found (404) - showing no profile view');
      setState(() {
        _isLoading = false;
        _isEditing = false; // ✅ DON'T set to true - show _buildNoProfileView()
      });
    } else {
      // Other errors - if we don't have data from cache, show no profile view
      if (_userData == null) {
        setState(() {
          _isLoading = false;
          _isEditing = false;
        });
      }
    }
  } catch (e) {
    debugPrint('❌ Load user error: $e');
    if (_userData == null) {
      setState(() {
        _isLoading = false;
        _isEditing = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }
}

  @override
  void didUpdateWidget(covariant SidebarProfile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userChannels != oldWidget.userChannels) {
      setState(() {

        _userChannels = List.from(widget.userChannels);
      });
      // TabController length is immutable after creation — must recreate it
      final newCount = _userChannels.length.clamp(0, 3);
      if (newCount != _tabController.length) {
        _tabController.dispose();
        _tabController = TabController(length: newCount, vsync: this);
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
      _isEditing = false;
    });
  }

  // ==========================================================================
  // SAVE PROFILE
  // ==========================================================================

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

      final bool isNewUser = _userData == null;

      final url = isNewUser
          ? '${widget.apiBaseUrl}/api/profile/create_profile'
          : '${widget.apiBaseUrl}/api/profile/profiles/${widget.userId}';

      debugPrint('📤 SAVING: ${isNewUser ? "NEW" : "UPDATE"} user');
      debugPrint('   URL: $url');
      debugPrint('   Body: ${jsonEncode(body)}');

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

        ToastHelper.showSuccess('Profile saved!');
        await AppCache.saveProfile(userMap);
        _unfocusAll();
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

  // ==========================================================================
  // HEADERS WITH AUTH TOKEN
  // ==========================================================================

  Map<String, String> _headers() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

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

  Future<void> _checkPaymentVisibility() async {
    if (!_isCurrentUser) {
      setState(() => _showPaymentFeatures = false);
      return;
    }

    setState(() => _isCheckingVisibility = true);

    try {
      final response = await http
          .get(
            Uri.parse('$_api/visibility/votes_button_show'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          _showPaymentFeatures = data['value'] ?? false;
        });
      } else {
        debugPrint('⚠️ Visibility check non-200: ${response.statusCode}');
        setState(() => _showPaymentFeatures = false);
      }
    } catch (e) {
      debugPrint('❌ Error checking visibility: $e');
      setState(() => _showPaymentFeatures = false);
    } finally {
      if (mounted) setState(() => _isCheckingVisibility = false);
    }
  }

  Future<void> _fetchBalance() async {
    if (!_isCurrentUser) return;
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
      debugPrint('❌ Fetch balance error: $e');
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
  // STK PUSH - TOP UP
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
          bool isProcessing = false;
          String statusMessage = '';

          return AlertDialog(
            backgroundColor: FanColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FanRadius.lg),
              side: BorderSide(color: FanColors.border),
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

                        setStateDialog(() {
                          isProcessing = true;
                          statusMessage =
                              '⏳ Processing... Please check your phone';
                        });

                        final success = await _initiateSTKPush(
                          amount: amount,
                          phone: phone,
                          useSaved: useSaved,
                        );

                        if (success) {
                          setStateDialog(() {
                            statusMessage = '✅ Payment successful!';
                          });

                          await Future.delayed(const Duration(seconds: 1));
                          Navigator.pop(context, true);
                          await _refreshBalanceAfterTransaction();
                          ToastHelper.showSuccess(
                              'Balance updated to KES ${_balance.toStringAsFixed(2)}');
                        } else {
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
  // B2C WITHDRAWAL
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
            side: BorderSide(color: FanColors.border),
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
                await _showProcessingDialog();

                final success = await _processWithdrawal(
                  amount: amount,
                  phone: phone,
                  useSaved: useSaved,
                );

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

  void _unfocusAll() {
    _nicknameFocus.unfocus();
    _clubFocus.unfocus();
    _countryFocus.unfocus();
    FocusScope.of(context).unfocus();
  }

  void _showMemberProfile(ChannelMember member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SidebarProfile(
        apiBaseUrl: widget.apiBaseUrl,
        userId: member.userId,
        username: member.username,
        phone: '',
        userChannels: _userChannels,
        onLogout: () {},
      ),
    );
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
              ? SizedBox(
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
  // PROFILE VIEWS
  // ==========================================================================

  Widget _buildProfileView() {
    return Column(
      children: [
        _buildInfoRow(
          icon: Icons.person_outline,
          label: 'Username',
          value: '@${_userData!.username}',
        ),
        const SizedBox(height: 5),
        _buildInfoRow(
          icon: Icons.shield_outlined,
          label: 'Team Nickname',
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
        _buildTextField(
          controller: _nicknameController,
          focusNode: _nicknameFocus,
          label: 'TEAM NICKNAME',
          hint: 'e.g., Red Devils, The Gunners',
          icon: Icons.shield_outlined,
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
          hint: 'Country  you support?',
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
        _buildTextField(
          controller: _nicknameController,
          focusNode: _nicknameFocus,
          label: 'TEAM NICKNAME',
          hint: 'e.g., Red Devils, The Gunners',
          icon: Icons.shield_outlined,
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

  // ==========================================================================
  // CHANNEL TAB BAR
  // ==========================================================================

  Widget _buildChannelTabBar() {
    final channelCount = _userChannels.length.clamp(0, 3);

    if (channelCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
    final channelCount = _userChannels.length.clamp(0, 3);

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: FanColors.surfaceElevated,
        border: Border(
          right: BorderSide(
            color: FanColors.border.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: FanColors.primaryDim,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(),
                      style: TextStyle(
                        fontSize: 12,
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
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: FanColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '@${widget.username}',
                        style: TextStyle(
                          fontSize: 10,
                          color: FanColors.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (_isCurrentUser && _showPaymentFeatures)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: FanColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isBalanceLoading
                          ? '...'
                          : 'KES ${_balance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: FanColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  // Loading state
                  if (_isLoading || _isCheckingVisibility)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: FanColors.primary,
                          ),
                        ),
                      ),
                    ),

                  // Profile Content
                  if (!_isLoading && !_isCheckingVisibility) ...[
                    // Balance card (only for current user when enabled)
                    if (_isCurrentUser &&
                        _showPaymentFeatures &&
                        _userData != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildBalanceCard(),
                      ),

                    if (_isEditing) ...[
                      _buildEditMode(),
                    ] else if (_userData != null) ...[
                      _buildProfileView(),
                    ] else ...[
                      _buildNoProfileView(),
                    ],

                    // Channels Section
                    if (_userData != null && channelCount > 0) ...[
                      const Divider(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.people_alt_outlined,
                              size: 14,
                              color: FanColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Channels',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: FanColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    FanColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_userChannels.length}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: FanColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ],
                ],
              ),
            ),
          ),

          // Channel Tab Bar (fixed at bottom)
          if (!_isLoading && !_isCheckingVisibility && channelCount > 0) ...[
            _buildChannelTabBar(),
            const SizedBox(height: 2),
            SizedBox(
              height: 180,
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: List.generate(
                  channelCount,
                  (index) => _buildChannelFragment(index),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
