// lib/widgets/web_profile_panel.dart

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
import '../../models/user_channel.dart';

// ============================================================================
// USER DATA MODEL
// ============================================================================

class WebUserData {
  final String userId;
  final String username;
  final String phone;
  final String nickname;
  final String clubFan;
  final String countryFan;
  final int numberOfBets;
  final double balance;

  WebUserData({
    required this.userId,
    required this.username,
    required this.phone,
    required this.nickname,
    required this.clubFan,
    required this.countryFan,
    required this.numberOfBets,
    required this.balance,
  });

  factory WebUserData.fromJson(Map<String, dynamic> json) => WebUserData(
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
// WEB PROFILE PANEL - SELF CONTAINED
// ============================================================================

class WebProfilePanel extends StatefulWidget {
  final VoidCallback? onLogout;

  const WebProfilePanel({
    super.key,
    this.onLogout,
  });

  @override
  State<WebProfilePanel> createState() => _WebProfilePanelState();
}

class _WebProfilePanelState extends State<WebProfilePanel> {
  // ==========================================================================
  // STATE - SELF CONTAINED
  // ==========================================================================

  // Auth
  final AuthService _authService = AuthService();
  String get _userId => _authService.userId ?? '';
  String get _username => _authService.username ?? '';
  String get _phone => _authService.phone ?? '';
  bool get _isLoggedIn => _authService.isLoggedIn;

  // Profile data
  WebUserData? _userData;
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

  static const String _apiBaseUrl = 'https://clash-api-m5mr.onrender.com/api';
  static const Duration _timeout = Duration(seconds: 15);

  bool get _isCurrentUser => true;

  bool _showPaymentFeatures = true;
  bool _isCheckingVisibility = false;

  // ==========================================================================
  // INIT
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    _nicknameController = TextEditingController();
    _clubController = TextEditingController();
    _countryController = TextEditingController();

    _loadUserData();
    _initPaymentGate();
  }

  @override
  void dispose() {
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
    }
  }

  // ==========================================================================
  // DATA LOADING - SELF CONTAINED
  // ==========================================================================

  Future<void> _loadUserData() async {
    if (!_isLoggedIn) {
      setState(() {
        _isLoading = false;
        _userData = null;
      });
      return;
    }

    setState(() => _isLoading = true);

    // Instant paint from AppCache
    if (AppCache.profile != null &&
        (AppCache.profile!['user_id']?.toString() ??
                AppCache.profile!['userId']?.toString() ??
                '') ==
            _userId) {
      try {
        final cachedUser = WebUserData.fromJson(AppCache.profile!);
        _applyUserData(cachedUser);
        debugPrint('⚡ Loaded profile instantly from AppCache');
        return;
      } catch (e) {
        debugPrint('⚠️ Failed to apply cached profile: $e');
      }
    }

    try {
      final response = await http
          .get(
            Uri.parse('$_apiBaseUrl/profile/profile/$_userId'),
            headers: _headers(),
          )
          .timeout(_timeout);

      debugPrint('📥 GET profile: ${response.statusCode}');

      if (response.statusCode == 200 && mounted) {
        final decoded = jsonDecode(response.body);

        if (decoded is List) {
          if (decoded.isEmpty) {
            setState(() {
              _isLoading = false;
              _isEditing = true;
            });
            return;
          }
          final userMap = Map<String, dynamic>.from(decoded.first as Map);
          final user = WebUserData.fromJson(userMap);
          _applyUserData(user);
          await AppCache.saveProfile(userMap);
        } else if (decoded is Map) {
          final userMap = Map<String, dynamic>.from(decoded);
          final user = WebUserData.fromJson(userMap);
          _applyUserData(user);
          await AppCache.saveProfile(userMap);
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
        if (_userData == null) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('❌ Load user error: $e');
      if (_userData == null) {
        setState(() => _isLoading = false);
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyUserData(WebUserData user) {
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
  // SAVE PROFILE - SELF CONTAINED
  // ==========================================================================

  Future<void> _saveProfile() async {
    if (!_isLoggedIn) return;

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
        'user_id': _userId,
        'username': _username,
        'phone': _phone,
        'nickname': nickname,
        'club_fan': club,
        'country_fan': country,
        'balance': _balance,
        'number_of_bets': _userData?.numberOfBets ?? 0,
      };

      final bool isNewUser = _userData == null;

      final url = isNewUser
          ? '$_apiBaseUrl/profile/create_profile'
          : '$_apiBaseUrl/profile/profiles/$_userId';

      debugPrint('📤 SAVING: ${isNewUser ? "NEW" : "UPDATE"} user');

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

        final user = WebUserData.fromJson(userMap);

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
      }
    } catch (e) {
      debugPrint('❌ Save profile error: $e');
      ToastHelper.showError('Network error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ==========================================================================
  // HEADERS
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
    if (!_isLoggedIn) {
      setState(() => _showPaymentFeatures = false);
      return;
    }

    setState(() => _isCheckingVisibility = true);

    try {
      final response = await http
          .get(
            Uri.parse('$_apiBaseUrl/visibility/votes_button_show'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          _showPaymentFeatures = data['value'] ?? false;
        });
      } else {
        setState(() => _showPaymentFeatures = false);
      }
    } catch (e) {
      setState(() => _showPaymentFeatures = false);
    } finally {
      if (mounted) setState(() => _isCheckingVisibility = false);
    }
  }

  Future<void> _fetchBalance() async {
    if (!_isLoggedIn) return;
    setState(() => _isBalanceLoading = true);

    try {
      final balance = await PaymentService.getUserBalance(
        userId: _userId,
        authToken: _authToken,
        forceRefresh: true,
      );

      if (mounted) {
        setState(() {
          _balance = balance;
          if (_userData != null) {
            _userData = WebUserData(
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

  // ==========================================================================
  // LOGOUT - SELF CONTAINED
  // ==========================================================================

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);

    try {
      await FirebaseAuth.instance.signOut();
      await _authService.logout();
      widget.onLogout?.call();
      if (mounted) {
        ToastHelper.showSuccess('Logged out');
        // Clear local state
        setState(() {
          _userData = null;
          //_isLoggedIn = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Logout error: $e');
      ToastHelper.showError('Logout failed');
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  String _getInitials() {
    final name = _userData?.nickname ?? _username;
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  void _unfocusAll() {
    _nicknameFocus.unfocus();
    _clubFocus.unfocus();
    _countryFocus.unfocus();
    FocusScope.of(context).unfocus();
  }

  // ==========================================================================
  // UI BUILDERS
  // ==========================================================================

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
          hint: 'Country you support?',
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
  // MAIN BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    // Not logged in
    if (!_isLoggedIn) {
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_outline,
                size: 40,
                color: FanColors.textTertiary,
              ),
              const SizedBox(height: 8),
              Text(
                'Not logged in',
                style: TextStyle(
                  color: FanColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  // Navigate to login
                },
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      );
    }

    // Loading state
    if (_isLoading || _isCheckingVisibility) {
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
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Main content
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: FanColors.surfaceElevated,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(2, 0),
          ),
        ],
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: FanColors.primaryDim,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(),
                      style: TextStyle(
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
                        _userData?.nickname ?? _username,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: FanColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '@$_username',
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
                  // Balance card
                  if (_showPaymentFeatures && _userData != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildBalanceCard(),
                    ),

                  // Profile content
                  if (_isEditing) ...[
                    _buildEditMode(),
                  ] else if (_userData != null) ...[
                    _buildProfileView(),
                  ] else ...[
                    _buildNoProfileView(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
