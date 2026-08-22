import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import "../pages/fan_Funzy_design.dart";
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io' show Platform;
import '../services/notification_service.dart';



import '../services/auth_service.dart';

// ============================================================================
//  CLASH LOGIN MODAL — Firebase Phone Auth + PIN fallback for uncertified devices
// ============================================================================
class LoginModal extends StatelessWidget {
  final Function(String userId, String username)? onLoginSuccess;
  final GlobalKey<ScaffoldMessengerState>? messengerKey;

  const LoginModal({super.key, this.onLoginSuccess, this.messengerKey});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {},
          child: DraggableScrollableSheet(
            initialChildSize: 0.60,
            minChildSize: 0.45,
            maxChildSize: 0.85,
            expand: false,
            builder: (context, scrollController) => _LoginContent(
              onLoginSuccess: onLoginSuccess,
              messengerKey: messengerKey,
              scrollController: scrollController,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  CONTENT STATE
// ============================================================================
class _LoginContent extends StatefulWidget {
  final Function(String userId, String username)? onLoginSuccess;
  final GlobalKey<ScaffoldMessengerState>? messengerKey;
  final ScrollController scrollController;

  const _LoginContent({
    required this.onLoginSuccess,
    required this.messengerKey,
    required this.scrollController,
  });

  @override
  State<_LoginContent> createState() => _LoginContentState();
}

class _LoginContentState extends State<_LoginContent> {
  // ── view state ─────────────────────────────
  bool _loading = false;
  bool _showOtp = false;
  bool _showPinFallback = false;
  bool _isNewPinUser = false;
  bool _acceptTerms = false;

  // ── country code — default Kenya ───────────
  String _dialCode = '+254';
  String _countryCode = 'KE';
  String? _existingUserId;

  // ── controllers ────────────────────────────
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _pinConfirmCtrl = TextEditingController();

  // ── OTP / PIN ──────────────────────────────
  String? _verificationId;
  String _verifiedPhone = '';

  // PIN visibility toggles
  bool _pinObscure = true;
  bool _pinConfirmObscure = true;

  static const _baseUrl = 'https://clash-api-m5mr.onrender.com/api/auth';

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _pinCtrl.dispose();
    _pinConfirmCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────
  String _buildE164(String raw) {
    String s = raw.trim().replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    if (s.startsWith('+')) return s;
    if (s.startsWith('00')) return '+${s.substring(2)}';
    final dialDigits = _dialCode.replaceFirst('+', '');
    if (s.startsWith(dialDigits) && s.length > dialDigits.length + 4)
      return '+$s';
    if (s.startsWith('0')) s = s.substring(1);
    return '$_dialCode$s';
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Map<String, dynamic>? _parseJson(String raw) {
    try {
      final d = jsonDecode(raw);
      return d is Map<String, dynamic> ? d : null;
    } catch (_) {
      return null;
    }
  }

  void _toast(String msg, {bool error = false, bool warn = false}) {
    final overlay = Navigator.of(context).overlay;
    if (overlay == null) return;
    late OverlayEntry entry;
    final displaySeconds = error ? 7 : (warn ? 4 : 3);
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + 60,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            builder: (_, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                  offset: Offset(0, (1 - v) * -20), child: child),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: error
                    ? FanColors.away
                    : warn
                        ? FanColors.draw
                        : FanColors.primary,
                borderRadius: FanRadius.lgAll,
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, 4))
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    error
                        ? Icons.error_outline
                        : warn
                            ? Icons.warning_amber_outlined
                            : Icons.check_circle_outline,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SelectableText(
                      msg,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(Duration(seconds: displaySeconds), entry.remove);
  }

  void _toastRawError(String context, Object e, {String? code}) {
    final label = code != null ? '[$code]' : '';
    _toast('$context $label ${e.toString()}'.trim(), error: true);
  }

  // ─────────────────────────────────────────
  //  BACKEND CALLS
  // ─────────────────────────────────────────
  Future<Map<String, dynamic>?> _getUserByPhoneFull(String e164) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/check-user/${Uri.encodeComponent(e164)}'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = _parseJson(res.body);
        if (data?['exists'] == true) {
          final user = data?['user'] as Map<String, dynamic>?;
          return {
            ...?user,
            'has_pin': data?['has_pin'],
          };
        }
      }
    } catch (e) {
      developer.log('getUserByPhoneFull: $e');
    }
    return null;
  }

  Future<bool> _isUsernameTaken(String username) async {
    try {
      final res = await http
          .get(
            Uri.parse(
                '$_baseUrl/user/username/${Uri.encodeComponent(username)}'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = _parseJson(res.body);
        return data?['success'] == true && data?['user'] != null;
      }
      return false;
    } catch (e) {
      developer.log('isUsernameTaken: $e');
    }
    return false;
  }

  // ─────────────────────────────────────────
  //  LOGIN HELPER - Uses AuthService
  // ─────────────────────────────────────────
  Future<void> _performLogin(
      String userId, String username, String token, String phone) async {
    final authService = AuthService();
    final success =
        await authService.login(userId, username, token, phone: phone);

    if (success) {
      developer.log('✅ Login successful via AuthService: $username ($userId)',
          name: 'LoginModal');

      // ✅ Register FCM token now that we have a confirmed user_id.
      // initializeFCM() in main.dart only registers if the user was ALREADY
      // logged in at the moment it happened to run — for a fresh login
      // during this session, that check fails and the token (already sitting
      // in SharedPreferences under 'fcm_token') never reaches the backend.
      // This closes that gap.
      _registerFcmTokenAfterLogin(userId, token);

      widget.onLoginSuccess?.call(userId, username);
      if (mounted) Navigator.pop(context);
    } else {
      _toast('Login failed. Please try again.', error: true);
    }
  }

  Future<void> _registerFcmTokenAfterLogin(
      String userId, String authToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? fcmToken = prefs.getString('fcm_token');

      // Fall back to a fresh fetch if it's not cached yet (e.g. permission
      // was granted after initializeFCM() already gave up, or this is a
      // very fast login before initializeFCM() finished).
      fcmToken ??= await FirebaseMessaging.instance.getToken();

      if (fcmToken != null) {
        final platform = Platform.isIOS ? 'ios' : 'android';
        await NotificationService.registerToken(
          userId: userId,
          fcmToken: fcmToken,
          platform: platform,
          authToken: authToken,
        );
      }
    } catch (e) {
      developer.log('⚠️ Post-login FCM registration failed: $e',
          name: 'LoginModal');
    }
  }
  // ─────────────────────────────────────────
  //  STEP 1 — SEND OTP (with PIN fallback)
  // ─────────────────────────────────────────
  Future<void> _sendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      _toast('Please accept Terms & Conditions', warn: true);
      return;
    }

    setState(() => _loading = true);
    final e164 = _buildE164(_phoneCtrl.text);
    _verifiedPhone = e164;

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: e164,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (cred) => _signIn(cred),
        verificationFailed: (e) {
          developer.log('verificationFailed: code=${e.code} msg=${e.message}');
          _toastRawError('verifyPhoneNumber failed', e.message ?? '',
              code: e.code);
          _switchToPinFlow(e164);
        },
        codeSent: (vid, _) {
          _verificationId = vid;
          _toast('OTP sent to $e164');
          setState(() {
            _showOtp = true;
            _loading = false;
          });
        },
        codeAutoRetrievalTimeout: (vid) => _verificationId = vid,
      );
    } on FirebaseAuthException catch (e) {
      developer.log('verifyPhoneNumber threw: code=${e.code} msg=${e.message}');
      _toastRawError('verifyPhoneNumber threw', e.message ?? '', code: e.code);
      _switchToPinFlow(e164);
    } catch (e) {
      developer.log('verifyPhoneNumber unexpected error: $e');
      _toastRawError('verifyPhoneNumber unexpected', e);
      if (_isNetworkError(e)) {
        setState(() => _loading = false);
      } else {
        _switchToPinFlow(e164);
      }
    }
  }

  // ─────────────────────────────────────────
  //  ERROR CLASSIFICATION
  // ─────────────────────────────────────────
  bool _isNetworkError(Object e) {
    final text = e.toString().toLowerCase();
    return text.contains('network-request-failed') ||
        text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection refused') ||
        text.contains('timeoutexception') ||
        text.contains('handshakeexception');
  }

  static const _rateLimitCodes = {
    'too-many-requests',
    'quota-exceeded',
  };

  static const _badInputCodes = {
    'invalid-phone-number',
    'missing-phone-number',
  };

  static const _configOrAccountCodes = {
    'operation-not-allowed',
    'user-disabled',
  };

  String _friendlyAuthError(FirebaseAuthException e) {
    if (_rateLimitCodes.contains(e.code)) {
      return 'Too many attempts. Please wait a few minutes and try again.';
    }
    if (_badInputCodes.contains(e.code)) {
      return 'That phone number looks invalid. Please check and try again.';
    }
    if (_configOrAccountCodes.contains(e.code)) {
      return e.code == 'user-disabled'
          ? 'This account has been disabled.'
          : 'Phone sign-in is temporarily unavailable. Please try again later.';
    }
    if (e.code == 'network-request-failed') {
      return 'Network error. Check your connection and try again.';
    }
    return 'Failed to send OTP: ${e.message ?? 'unknown error'}';
  }

  // ─────────────────────────────────────────
  //  PIN FALLBACK FLOW
  // ─────────────────────────────────────────
  Future<void> _switchToPinFlow(String e164) async {
    _verifiedPhone = e164;
    final userData = await _getUserByPhoneFull(e164);
    final exists = userData != null;
    final hasPin = userData?['has_pin'] == true;

    setState(() {
      _existingUserId = exists ? userData!['id']?.toString() : null;
      _isNewPinUser = !hasPin;
      _showPinFallback = true;
      _loading = false;
    });
  }

  String? validateUsername(String username) {
    if (username.isEmpty) return 'Username is required';
    final trimmed = username.trim();
    if (trimmed.length < 3) return 'Username must be at least 3 characters';
    if (trimmed.length > 20) return 'Username must be less than 20 characters';

    if (!RegExp(r'^[a-zA-Z]+$').hasMatch(trimmed)) {
      return 'Username must contain only letters (a-z)';
    }

    final lowerUsername = trimmed.toLowerCase();
    final blockedPatterns = [
      r'^admin$',
      r'^administrator$',
      r'^superadmin$',
      r'^root$',
      r'^sysadmin$',
      r'^moderator$',
      r'^mod$',
      r'^staff$',
      r'^support$',
      r'^helpdesk$',
      r'^webmaster$',
      r'^master$',
      r'^system$',
      r'^test$',
      r'^user$',
      r'^guest$',
      r'^anonymous$',
      r'^default$',
      r'^example$',
      r'^null$',
      r'^undefined$',
      r'^service$',
      r'^api$',
      r'^bot$',
      r'^cron$',
      r'^daemon$',
      r'^clash$',
      r'^fanclash$',
      r'^clashfan$',
      r'^clashadmin$',
      r'^clashmod$',
      r'^clashstaff$',
      r'.*admin.*',
      r'.*root.*',
      r'.*super.*',
      r'.*mod.*',
    ];
    for (final pattern in blockedPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lowerUsername)) {
        return 'This username is not allowed';
      }
    }

    if (RegExp(r'^[0-9+\-\s()]{8,}$').hasMatch(trimmed))
      return 'Username cannot be a phone number';
    if (RegExp(r'^(.)\1{2,}$').hasMatch(trimmed))
      return 'Username cannot have repeated characters only';

    final sequential = RegExp(
      r'(?:abc|bcd|cde|def|efg|fgh|ghi|hij|ijk|jkl|klm|lmn|mno|nop|opq|pqr|qrs|rst|stu|tuv|uvw|vwx|wxy|xyz)',
    );
    if (sequential.hasMatch(trimmed.toLowerCase()))
      return 'Username cannot contain sequential patterns (abc, 123)';

    final keyboardPatterns = RegExp(
      r'(?:qwerty|asdfgh|zxcvbn|qwert|asdf|zxcv|qwe|asd|zxc|poiu|poi|lkj|mnb)',
    );
    if (keyboardPatterns.hasMatch(trimmed.toLowerCase()))
      return 'Username cannot contain keyboard patterns';

    return null;
  }

  Future<void> _submitPin() async {
    final pin = _pinCtrl.text.trim();

    if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      _toast('Enter a 4-digit PIN', error: true);
      return;
    }

    if (_isNewPinUser) {
      if (_pinConfirmCtrl.text.trim() != pin) {
        _toast('PINs do not match', error: true);
        return;
      }

      if (_existingUserId != null) {
        await _attachPinToExistingUser(_existingUserId!, pin);
      } else {
        _showUsernameDialog(pin: pin);
      }
    } else {
      setState(() => _loading = true);
      try {
        final res = await http
            .post(
              Uri.parse('$_baseUrl/pin-login'),
              headers: _headers(),
              body: jsonEncode({'phone': _verifiedPhone, 'pin': pin}),
            )
            .timeout(const Duration(seconds: 15));

        final body = _parseJson(res.body);
        if (res.statusCode == 200) {
          final token = body?['token'] as String?;
          final user = body?['user'] as Map<String, dynamic>?;
          final userId = user?['id']?.toString();
          final username = user?['username']?.toString() ?? 'User';
          if (userId != null && token != null) {
            await _performLogin(userId, username, token, _verifiedPhone);
            _toast('Welcome back, $username! 🎉');
            setState(() => _loading = false);
          } else {
            _toast('Login failed — status ${res.statusCode}, body: ${res.body}',
                error: true);
            setState(() => _loading = false);
          }
        } else {
          _toast(
              '${body?['message'] ?? 'Incorrect PIN'} (status ${res.statusCode})',
              error: true);
          setState(() => _loading = false);
        }
      } catch (e) {
        _toastRawError('pin-login request failed', e);
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _attachPinToExistingUser(String userId, String pin) async {
    setState(() => _loading = true);
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/set-pin/$userId'),
            headers: _headers(),
            body: jsonEncode({'pin': pin}),
          )
          .timeout(const Duration(seconds: 15));

      final body = _parseJson(res.body);
      if (res.statusCode == 200) {
        final token = body?['token'] as String?;
        final user = body?['user'] as Map<String, dynamic>?;
        final username = user?['username']?.toString() ?? 'User';
        if (token != null) {
          await _performLogin(userId, username, token, _verifiedPhone);
          _toast('PIN set! Welcome back, $username 🎉');
          setState(() => _loading = false);
        } else {
          _toast(
              'PIN set, but login failed — status ${res.statusCode}, body: ${res.body}',
              error: true);
          setState(() => _loading = false);
        }
      } else {
        _toast(
            '${body?['message'] ?? 'Failed to set PIN'} (status ${res.statusCode})',
            error: true);
        setState(() => _loading = false);
      }
    } catch (e) {
      _toastRawError('set-pin request failed', e);
      setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────
  //  STEP 2 — VERIFY OTP (Firebase path)
  // ─────────────────────────────────────────
  Future<void> _verifyOtp() async {
    if (!_otpFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpCtrl.text.trim(),
      );
      await _signIn(cred);
    } catch (e) {
      _toastRawError('verifyOtp failed', e);
      setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────
  //  STEP 3 — SIGN IN (Firebase path)
  // ─────────────────────────────────────────
  Future<void> _signIn(PhoneAuthCredential cred) async {
    try {
      final uc = await FirebaseAuth.instance.signInWithCredential(cred);
      final fUser = uc.user!;
      final token = await fUser.getIdToken();
      final phone = fUser.phoneNumber ?? _verifiedPhone;

      final existing = await _getUserByPhoneFull(phone);

      if (existing != null) {
        final uid = existing['id']?.toString() ?? '';
        final username = existing['username']?.toString() ?? 'User';
        if (token != null) {
          await _performLogin(uid, username, token, phone);
          _toast('Welcome back, $username! 🎉');
          setState(() => _loading = false);
        } else {
          _toast('Failed to get auth token', error: true);
          setState(() => _loading = false);
        }
      } else {
        setState(() => _loading = false);
        _showUsernameDialog();
      }
    } catch (e) {
      _toastRawError('signIn failed', e);
      setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────
  //  NEW USER — USERNAME DIALOG
  // ─────────────────────────────────────────
  void _showUsernameDialog({String? pin}) {
    final ctrl = TextEditingController();
    String? err;

    String? validateUsername(String username) {
      if (username.isEmpty) return 'Username is required';
      final trimmed = username.trim();
      if (trimmed.length < 3) return 'Username must be at least 3 characters';
      if (trimmed.length > 20)
        return 'Username must be less than 20 characters';

      if (!RegExp(r'^[a-zA-Z]+$').hasMatch(trimmed)) {
        return 'Username must contain only letters (a-z)';
      }

      final lowerUsername = trimmed.toLowerCase();
      final blockedPatterns = [
        r'^admin$',
        r'^administrator$',
        r'^superadmin$',
        r'^root$',
        r'^sysadmin$',
        r'^moderator$',
        r'^mod$',
        r'^staff$',
        r'^support$',
        r'^helpdesk$',
        r'^webmaster$',
        r'^master$',
        r'^system$',
        r'^test$',
        r'^user$',
        r'^guest$',
        r'^anonymous$',
        r'^default$',
        r'^example$',
        r'^null$',
        r'^undefined$',
        r'^service$',
        r'^api$',
        r'^bot$',
        r'^cron$',
        r'^daemon$',
        r'^clash$',
        r'^fanclash$',
        r'^clashfan$',
        r'^clashadmin$',
        r'^clashmod$',
        r'^clashstaff$',
        r'.*admin.*',
        r'.*root.*',
        r'.*super.*',
        r'.*mod.*',
      ];
      for (final pattern in blockedPatterns) {
        if (RegExp(pattern, caseSensitive: false).hasMatch(lowerUsername)) {
          return 'This username is not allowed';
        }
      }

      if (RegExp(r'^(.)\1{2,}$').hasMatch(trimmed))
        return 'Username cannot have repeated characters only';

      final sequential = RegExp(
        r'(?:abc|bcd|cde|def|efg|fgh|ghi|hij|ijk|jkl|klm|lmn|mno|nop|opq|pqr|qrs|rst|stu|tuv|uvw|vwx|wxy|xyz)',
      );
      if (sequential.hasMatch(trimmed.toLowerCase()))
        return 'Username cannot contain sequential patterns (abc, xyz)';

      final keyboardPatterns = RegExp(
        r'(?:qwerty|asdfgh|zxcvbn|qwert|asdf|zxcv|qwe|asd|zxc|poiu|poi|lkj|mnb)',
      );
      if (keyboardPatterns.hasMatch(trimmed.toLowerCase()))
        return 'Username cannot contain keyboard patterns';

      return null;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: FanColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: FanRadius.lgAll,
              side:  BorderSide(color: FanColors.border)),
          title: Text('Create Username', style: FanTypography.headline),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Choose a username for your account (letters only)',
                  style: FanTypography.body),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: FanTypography.body,
                decoration: InputDecoration(
                  hintText: 'e.g. JohnDoe',
                  hintStyle: FanTypography.body,
                  errorText: err,
                  filled: true,
                  fillColor: FanColors.surfaceSunken,
                  border: OutlineInputBorder(
                    borderRadius: FanRadius.lgAll,
                    borderSide:  BorderSide(color: FanColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: FanRadius.lgAll,
                    borderSide:  BorderSide(color: FanColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: FanRadius.lgAll,
                    borderSide:
                         BorderSide(color: FanColors.primary, width: 1.4),
                  ),
                ),
                onChanged: (value) {
                  if (err != null) {
                    final newErr = validateUsername(value);
                    if (newErr != err) setD(() => err = newErr);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _resetPhone();
              },
              child: Text('Cancel',
                  style: TextStyle(color: FanColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FanColors.primary,
                foregroundColor: FanColors.textInverse,
                textStyle: FanTypography.button,
                shape: RoundedRectangleBorder(borderRadius: FanRadius.pillAll),
                padding: const EdgeInsets.symmetric(
                    horizontal: FanSpacing.lg, vertical: FanSpacing.md),
                elevation: 0,
              ),
              onPressed: () async {
                final name = ctrl.text.trim();
                final validationError = validateUsername(name);
                if (validationError != null) {
                  setD(() => err = validationError);
                  return;
                }
                setD(() => err = null);
                Navigator.pop(ctx);
                setState(() => _loading = true);
                if (await _isUsernameTaken(name)) {
                  _toast('Username already taken', error: true);
                  setState(() => _loading = false);
                  _showUsernameDialog(pin: pin);
                  return;
                }
                await _registerUser(name, pin: pin);
              },
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerUser(String username, {String? pin}) async {
    try {
      final body = {'username': username, 'phone': _verifiedPhone};
      if (pin != null) body['pin'] = pin;

      final res = await http
          .post(
            Uri.parse('$_baseUrl/register'),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      final respBody = _parseJson(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final token = respBody?['token'] as String?;
        final user = respBody?['user'] as Map<String, dynamic>?;
        final userId = user?['id']?.toString();
        if (userId != null && token != null) {
          await _performLogin(userId, username, token, _verifiedPhone);
          _toast('Welcome to Funspot, $username! 🎉');
          setState(() => _loading = false);
        } else {
          _toast(
              'Registration failed — status ${res.statusCode}, body: ${res.body}',
              error: true);
          setState(() => _loading = false);
        }
      } else {
        _toast(
            '${respBody?['message'] ?? 'Registration failed'} (status ${res.statusCode})',
            error: true);
        setState(() => _loading = false);
      }
    } catch (e) {
      _toastRawError('register request failed', e);
      setState(() => _loading = false);
    }
  }

  void _resetPhone() => setState(() {
        _showOtp = false;
        _showPinFallback = false;
        _isNewPinUser = false;
        _existingUserId = null;
        _verificationId = null;
        _otpCtrl.clear();
        _pinCtrl.clear();
        _pinConfirmCtrl.clear();
      });

  Future<void> _launch(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      _toastRawError('could not open link', e);
    }
  }

  // ─────────────────────────────────────────
  //  REUSABLE INPUT
  // ─────────────────────────────────────────
  Widget _input({
    required TextEditingController ctrl,
    required String hint,
    TextInputType? keyType,
    String? Function(String?)? validator,
    TextInputAction action = TextInputAction.next,
    void Function(String)? onSubmit,
    Widget? prefix,
    Widget? suffix,
    bool obscure = false,
    GlobalKey<FormState>? formKey,
  }) {
    final field = TextFormField(
      controller: ctrl,
      keyboardType: keyType,
      textInputAction: action,
      onFieldSubmitted: onSubmit,
      validator: validator,
      obscureText: obscure,
      style: FanTypography.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: FanTypography.body,
        prefixIcon: prefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: FanColors.surfaceSunken,
        border: OutlineInputBorder(
          borderRadius: FanRadius.lgAll,
          borderSide:  BorderSide(color: FanColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: FanRadius.lgAll,
          borderSide:  BorderSide(color: FanColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: FanRadius.lgAll,
          borderSide: BorderSide(color: FanColors.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: FanRadius.lgAll,
          borderSide:  BorderSide(color: FanColors.away),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: FanSpacing.base, vertical: FanSpacing.md),
      ),
    );
    return formKey != null ? Form(key: formKey, child: field) : field;
  }

  Widget _btn(
          {required String label,
          required VoidCallback onTap,
          IconData? icon}) =>
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: FanColors.primary,
            foregroundColor: FanColors.textInverse,
            textStyle: FanTypography.button,
            shape: RoundedRectangleBorder(borderRadius: FanRadius.pillAll),
            padding: const EdgeInsets.symmetric(vertical: FanSpacing.md),
            elevation: 0,
            disabledBackgroundColor: FanColors.border,
          ),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16),
                      const SizedBox(width: 8)
                    ],
                    Text(label,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
        ),
      );

  // ─────────────────────────────────────────
  //  PHONE SCREEN
  // ─────────────────────────────────────────
  Widget _phoneScreen() => Form(
        key: _phoneFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('Enter your phone number to continue',
                style: FanTypography.body),
            const SizedBox(height: 20),
            Text('PHONE NUMBER', style: FanTypography.caption),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: FanColors.surfaceSunken,
                borderRadius: FanRadius.lgAll,
                border: Border.all(color: FanColors.border),
              ),
              child: Row(
                children: [
                  CountryCodePicker(
                    onChanged: (code) => setState(() {
                      _dialCode = code.dialCode ?? '+254';
                      _countryCode = code.code ?? 'KE';
                    }),
                    initialSelection: 'KE',
                    favorite: const [
                      '+254',
                      'US',
                      'GB',
                      'NG',
                      'GH',
                      'ZA',
                      'TZ',
                      'UG'
                    ],
                    showCountryOnly: false,
                    showOnlyCountryWhenClosed: false,
                    alignLeft: false,
                    textStyle: FanTypography.body,
                    dialogBackgroundColor: FanColors.surface,
                    searchDecoration: InputDecoration(
                      hintText: 'Search country…',
                      hintStyle: FanTypography.body,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      filled: true,
                      fillColor: FanColors.background,
                      border: OutlineInputBorder(
                        borderRadius: FanRadius.lgAll,
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: FanSpacing.base, vertical: FanSpacing.md),
                    ),
                  ),
                  Container(width: 1, height: 28, color: FanColors.border),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _sendOtp(),
                      style: FanTypography.body,
                      decoration: InputDecoration(
                        hintText: 'Phone number',
                        hintStyle: FanTypography.body,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: FanSpacing.base,
                            vertical: FanSpacing.md),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final cleaned =
                            v.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
                        if (cleaned.length < 5) return 'Too short';
                        if (cleaned.length > 15) return 'Too long';
                        if (!RegExp(r'^[0-9+]+$').hasMatch(cleaned))
                          return 'Digits only';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _phoneCtrl,
              builder: (context, val, _) {
                if (val.text.trim().isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    'Will send to: ${_buildE164(val.text)}',
                    style: FanTypography.caption
                        .copyWith(color: FanColors.primary),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: _acceptTerms,
                    onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                    activeColor: FanColors.primary,
                    shape:
                        RoundedRectangleBorder(borderRadius: FanRadius.smAll),
                    side: BorderSide(color: FanColors.border),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: FanTypography.caption,
                      children: [
                        const TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Terms',
                          style: TextStyle(color: FanColors.primary),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () =>
                                _launch('https://clash-privacy.netlify.app/'),
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(color: FanColors.primary),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () =>
                                _launch('https://clash-privacy.netlify.app/'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _btn(label: 'Send OTP', onTap: _sendOtp, icon: Icons.send_outlined),
          ],
        ),
      );

  // ─────────────────────────────────────────
  //  OTP SCREEN
  // ─────────────────────────────────────────
  Widget _otpScreen() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: FanDecorations.card(),
            child: Column(
              children: [
                Icon(Icons.sms_outlined, size: 44, color: FanColors.primary),
                const SizedBox(height: 10),
                Text('Verify Your Phone',
                    style: FanTypography.headline.copyWith(fontSize: 17)),
                const SizedBox(height: 6),
                Text('OTP sent to $_verifiedPhone',
                    style: FanTypography.body, textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Form(
            key: _otpFormKey,
            child: _input(
              ctrl: _otpCtrl,
              hint: 'Enter 6-digit code',
              keyType: TextInputType.number,
              action: TextInputAction.done,
              onSubmit: (_) => _verifyOtp(),
              prefix:
                  Icon(Icons.pin_outlined, size: 18, color: FanColors.primary),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.trim().length != 6) return 'Enter 6 digits';
                return null;
              },
            ),
          ),
          const SizedBox(height: 18),
          _btn(
              label: 'Verify & Continue',
              onTap: _verifyOtp,
              icon: Icons.verified_outlined),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: _resetPhone,
              child: RichText(
                text: TextSpan(
                  style: FanTypography.caption,
                  children: [
                    TextSpan(
                        text: 'Wrong number? ',
                        style: TextStyle(color: FanColors.textTertiary)),
                    TextSpan(
                        text: 'Go back',
                        style: TextStyle(
                            color: FanColors.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

  // ─────────────────────────────────────────
  //  PIN FALLBACK SCREEN
  // ─────────────────────────────────────────
  Widget _pinScreen() => StatefulBuilder(
        builder: (ctx, setS) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── info banner ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: FanDecorations.card(),
              child: Column(
                children: [
                  Icon(
                    _isNewPinUser
                        ? Icons.lock_outline
                        : Icons.lock_open_outlined,
                    size: 44,
                    color: FanColors.primary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isNewPinUser ? 'Set Your PIN' : 'Enter Your PIN',
                    style: FanTypography.headline.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isNewPinUser
                        ? 'Create a 4-digit PIN to secure your account'
                        : 'Enter your 4-digit PIN for $_verifiedPhone',
                    style: FanTypography.body,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ── PIN input ──
            _input(
              ctrl: _pinCtrl,
              hint: _isNewPinUser ? 'Create 4-digit PIN' : 'Enter your PIN',
              keyType: TextInputType.number,
              obscure: _pinObscure,
              action:
                  _isNewPinUser ? TextInputAction.next : TextInputAction.done,
              onSubmit: _isNewPinUser ? null : (_) => _submitPin(),
              prefix:
                  Icon(Icons.pin_outlined, size: 18, color: FanColors.primary),
              suffix: IconButton(
                icon: Icon(
                  _pinObscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: FanColors.textTertiary,
                ),
                onPressed: () => setS(() => _pinObscure = !_pinObscure),
              ),
            ),

            // ── confirm PIN (new users only) ──
            if (_isNewPinUser) ...[
              const SizedBox(height: 12),
              _input(
                ctrl: _pinConfirmCtrl,
                hint: 'Confirm PIN',
                keyType: TextInputType.number,
                obscure: _pinConfirmObscure,
                action: TextInputAction.done,
                onSubmit: (_) => _submitPin(),
                prefix: Icon(Icons.pin_outlined,
                    size: 18, color: FanColors.primary),
                suffix: IconButton(
                  icon: Icon(
                    _pinConfirmObscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: FanColors.textTertiary,
                  ),
                  onPressed: () =>
                      setS(() => _pinConfirmObscure = !_pinConfirmObscure),
                ),
              ),
            ],

            const SizedBox(height: 18),
            _btn(
              label: _isNewPinUser ? 'Set PIN & Continue' : 'Login with PIN',
              onTap: _submitPin,
              icon: _isNewPinUser
                  ? Icons.check_circle_outline
                  : Icons.login_outlined,
            ),

            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: _resetPhone,
                child: RichText(
                  text: TextSpan(
                    style: FanTypography.caption,
                    children: [
                      TextSpan(
                          text: 'Wrong number? ',
                          style: TextStyle(color: FanColors.textTertiary)),
                      TextSpan(
                        text: 'Go back',
                        style: TextStyle(
                            color: FanColors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  // ─────────────────────────────────────────
  //  ROOT BUILD
  // ─────────────────────────────────────────
  String get _title {
    if (_showPinFallback) return _isNewPinUser ? 'Set PIN' : 'Enter PIN';
    if (_showOtp) return 'Verify Phone';
    return 'Join Funspot,Relax,Enjoy';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FanColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FanColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: FanColors.primaryDim,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: FanColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Center(
                      child: Text('⚔️', style: TextStyle(fontSize: 16))),
                ),
                const SizedBox(width: 10),
                Text(_title, style: FanTypography.headline),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: _showPinFallback
                  ? _pinScreen()
                  : _showOtp
                      ? _otpScreen()
                      : _phoneScreen(),
            ),
          ),
        ],
      ),
    );
  }
}
