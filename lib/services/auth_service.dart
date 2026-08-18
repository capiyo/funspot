import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // State variables
  bool _isLoggedIn = false;
  bool _isInitialized = false;
  String? _userId;
  String? _username;
  String? _phone;
  String? _authToken;
  String? _refreshToken; // Field for refresh token

  // Getters
  bool get isLoggedIn => _isLoggedIn;
  bool get isInitialized => _isInitialized;
  String? get userId => _userId;
  String? get username => _username;
  String? get phone => _phone;
  String? get authToken => _authToken;
  String? get refreshToken => _refreshToken;

  // ============================================
  // INITIALIZATION
  // ============================================

 Future<void> initialize() async {
  if (_isInitialized) {
    developer.log('⚠️ AuthService already initialized', name: 'AuthService');
    return;
  }

  developer.log('🔄 Initializing AuthService...', name: 'AuthService');

  try {
    final prefs = await SharedPreferences.getInstance();

    // Read all stored values
    _authToken = prefs.getString('usertoken');
    final userString = prefs.getString('user');
    final phone = prefs.getString('phone');
    _refreshToken = prefs.getString('refreshToken');

    developer.log('📖 Read from SharedPreferences:', name: 'AuthService');
    developer.log(
        '  - token: ${_authToken != null ? "✅ present (${_authToken!.length} chars)" : "❌ null"}',
        name: 'AuthService');
    developer.log('  - user: ${userString != null ? "✅ present" : "❌ null"}',
        name: 'AuthService');
    developer.log('  - phone: ${phone != null ? "✅ present" : "❌ null"}',
        name: 'AuthService');
    developer.log(
        '  - refreshToken: ${_refreshToken != null ? "✅ present" : "❌ null"}',
        name: 'AuthService');

    if (_authToken != null &&
        _authToken!.isNotEmpty &&
        userString != null &&
        userString.isNotEmpty) {
      try {
        final userData = jsonDecode(userString);
        _userId = userData['id'] ?? userData['userId'] ?? userData['_id'];
        _username = userData['username'] ?? userData['name'] ?? '';
        _phone = phone ?? userData['phone']?.toString() ?? '';
        _isLoggedIn = true;

        // Validate that we got a valid userId
        if (_userId == null || _userId!.isEmpty) {
          developer.log('⚠️ Invalid userId from stored data',
              name: 'AuthService');
          _isLoggedIn = false;
          _clearState();
        } else {
          developer.log(
              '✅ Session restored successfully for user: $_username ($_userId)',
              name: 'AuthService');
        }
      } catch (e) {
        developer.log('❌ Failed to parse user data: $e', name: 'AuthService');
        _isLoggedIn = false;
        _clearState();
      }
    } else {
      developer.log('❌ No valid session found', name: 'AuthService');
      _isLoggedIn = false;
      _clearState();
    }
  } catch (e) {
    developer.log('❌ Error initializing AuthService: $e',
        name: 'AuthService', error: e);
    _isLoggedIn = false;
    _clearState();
  }

  _isInitialized = true;
  developer.log(
      '✅ AuthService initialization complete. isLoggedIn: $_isLoggedIn',
      name: 'AuthService');
  notifyListeners();
}

  // ============================================
  // LOGIN
  // ============================================

  Future<bool> login(
    String userId,
    String username,
    String authToken, {
    String? phone,
    String? refreshToken,
  }) async {
    developer.log('🔐🔐🔐 AUTH SERVICE LOGIN START 🔐🔐🔐',
        name: 'AuthService');
    developer.log('🔐 userId: $userId', name: 'AuthService');
    developer.log('🔐 username: $username', name: 'AuthService');
    developer.log('🔐 phone: ${phone ?? "null"}', name: 'AuthService');
    developer.log('🔐 token length: ${authToken.length}', name: 'AuthService');

    try {
      final prefs = await SharedPreferences.getInstance();

      // Prepare user data
      final userData = {
        'id': userId,
        'username': username,
        'phone': phone ?? '',
      };

      // Save all data with error handling
      await Future.wait([
        prefs.setString('usertoken', authToken),
        prefs.setString('user', jsonEncode(userData)),
        prefs.setBool('isLoggedIn', true),
        if (phone != null && phone.isNotEmpty) prefs.setString('phone', phone),
        if (refreshToken != null && refreshToken.isNotEmpty)
          prefs.setString('refreshToken', refreshToken),
      ]);

      // Force flush to disk
      await prefs.reload();

      // Verify critical data was saved
      final verifyToken = prefs.getString('usertoken');
      final verifyUser = prefs.getString('user');
      final verifyPhone = prefs.getString('phone');

      if (verifyToken == null ||
          verifyToken.isEmpty ||
          verifyUser == null ||
          verifyUser.isEmpty) {
        throw Exception('Failed to verify session data was saved');
      }

      // Update state
      _userId = userId;
      _username = username;
      _phone = phone;
      _authToken = authToken;
      _refreshToken = refreshToken;
      _isLoggedIn = true;

      developer.log('✅ Session saved and verified', name: 'AuthService');
      developer.log('  - userId: $_userId', name: 'AuthService');
      developer.log('  - username: $_username', name: 'AuthService');
      developer.log('  - phone: $_phone', name: 'AuthService');
      developer.log('  - token length: ${_authToken?.length ?? 0}',
          name: 'AuthService');

      notifyListeners();

      developer.log('🔐🔐🔐 AUTH SERVICE LOGIN SUCCESS 🔐🔐🔐',
          name: 'AuthService');
      return true;
    } catch (e, stackTrace) {
      developer.log('❌ Login failed: $e',
          name: 'AuthService', error: e, stackTrace: stackTrace);
      _isLoggedIn = false;
      _clearState();
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // LOGOUT
  // ============================================

  Future<void> logout() async {
    developer.log('🚪🚪🚪 LOGOUT STARTED 🚪🚪🚪', name: 'AuthService');

    try {
      final prefs = await SharedPreferences.getInstance();

      // Get all keys to clear
      final keysToClear = [
        'usertoken',
        'user',
        'isLoggedIn',
        'userId',
        'username',
        'phone',
        'refreshToken',
        // User data caches
        'userBets',
        'userProfile',
        'availableGames',
        'notifications',
        'notificationCount',
        // Cached content
        'cachedPosts',
        'cachedFixtures',
        'lastCarouselFetch',
        'forceNewUser',
        // Any other app data
        'comrades',
        'channels',
        'votes',
        'messages',
      ];

      // Remove all keys
      await Future.wait(keysToClear.map((key) => prefs.remove(key)));

      developer.log(
          '✅ Cleared ${keysToClear.length} keys from SharedPreferences',
          name: 'AuthService');
    } catch (e) {
      developer.log('⚠️ Error during logout: $e',
          name: 'AuthService', error: e);
    }

    // Always clear state even if SharedPreferences fails
    _clearState();
    _isLoggedIn = false;

    notifyListeners();

    developer.log('🚪🚪🚪 LOGOUT COMPLETE 🚪🚪🚪', name: 'AuthService');
  }

  // ============================================
  // SESSION MANAGEMENT
  // ============================================

  /// Update the auth token with a new one (for Firebase or backend refresh flows)
  Future<bool> updateAuthToken(String newToken,
      {String? newRefreshToken}) async {
    if (!_isLoggedIn) {
      developer.log('⚠️ Cannot update token - not logged in',
          name: 'AuthService');
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('usertoken', newToken);

      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await prefs.setString('refreshToken', newRefreshToken);
        _refreshToken = newRefreshToken;
      }

      _authToken = newToken;
      notifyListeners();

      developer.log('✅ Token updated successfully', name: 'AuthService');
      return true;
    } catch (e) {
      developer.log('❌ Failed to update token: $e',
          name: 'AuthService', error: e);
      return false;
    }
  }

  /// Check if token is about to expire (for proactive refresh)
  bool isTokenExpiringSoon({Duration threshold = const Duration(minutes: 5)}) {
    // This would require parsing JWT expiry
    // For now, return false if token is null
    return _authToken == null || _authToken!.isEmpty;
  }

  // ============================================
  // USER DATA UPDATES
  // ============================================

  Future<void> updateUserData(String userId, String username,
      {String? phone}) async {
    developer.log('📝 Updating user data: $userId, $username',
        name: 'AuthService');

    try {
      final prefs = await SharedPreferences.getInstance();

      // Update stored user data
      final userString = prefs.getString('user');
      if (userString != null) {
        try {
          final userData = jsonDecode(userString) as Map<String, dynamic>;
          userData['username'] = username;
          if (phone != null) {
            userData['phone'] = phone;
          }
          await prefs.setString('user', jsonEncode(userData));
        } catch (e) {
          developer.log('⚠️ Failed to update user data: $e',
              name: 'AuthService');
        }
      }

      // Update state
      _userId = userId;
      _username = username;
      if (phone != null) {
        _phone = phone;
        await prefs.setString('phone', phone);
      }

      notifyListeners();

      developer.log('✅ User data updated successfully', name: 'AuthService');
    } catch (e) {
      developer.log('❌ Failed to update user data: $e',
          name: 'AuthService', error: e);
    }
  }

  // ============================================
  // VALIDATION HELPERS
  // ============================================

  /// Check if the current session is valid
  bool hasValidSession() {
    return _isLoggedIn &&
        _authToken != null &&
        _authToken!.isNotEmpty &&
        _userId != null &&
        _userId!.isNotEmpty;
  }

  /// Get session data as JSON (for debugging)
  Map<String, dynamic> getSessionInfo() {
    return {
      'isLoggedIn': _isLoggedIn,
      'isInitialized': _isInitialized,
      'userId': _userId,
      'username': _username,
      'phone': _phone,
      'hasToken': _authToken != null && _authToken!.isNotEmpty,
      'tokenLength': _authToken?.length ?? 0,
      'hasRefreshToken': _refreshToken != null && _refreshToken!.isNotEmpty,
    };
  }

  // ============================================
  // PRIVATE HELPERS
  // ============================================

  void _clearState() {
    _userId = null;
    _username = null;
    _phone = null;
    _authToken = null;
    _refreshToken = null;
  }

  // ============================================
  // DEBUGGING
  // ============================================

  /// Clear all app data (for debugging)
  Future<void> clearAllAppData() async {
    developer.log('🗑️ Clearing ALL app data...', name: 'AuthService');

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _clearState();
      _isLoggedIn = false;
      _isInitialized = false;
      notifyListeners();

      developer.log('✅ ALL app data cleared', name: 'AuthService');
    } catch (e) {
      developer.log('❌ Failed to clear app data: $e',
          name: 'AuthService', error: e);
    }
  }

  /// Simulate token expiry (for testing)
  Future<void> simulateTokenExpiry() async {
    developer.log('🧪 Simulating token expiry...', name: 'AuthService');

    if (_isLoggedIn) {
      // Clear token but keep user data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('usertoken');
      _authToken = null;
      _isLoggedIn = false;
      notifyListeners();

      developer.log('🧪 Token expired - user logged out', name: 'AuthService');
    }
  }
}
