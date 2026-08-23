// lib/WebView/Hompage/web_profile_panel.dart

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
// CHANNEL MEMBER MODEL
// ============================================================================

class WebChannelMember {
  final String userId;
  final String username;
  final int correctVotes;
  final int totalVotes;
  final int msgCount;
  final int seasonPoints;

  WebChannelMember({
    required this.userId,
    required this.username,
    required this.correctVotes,
    required this.totalVotes,
    required this.msgCount,
    required this.seasonPoints,
  });

  factory WebChannelMember.fromJson(Map<String, dynamic> json) =>
      WebChannelMember(
        userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        correctVotes: json['correct_votes'] ?? 0,
        totalVotes: json['total_votes'] ?? 0,
        msgCount: json['msg_count'] ?? 0,
        seasonPoints: json['season_points'] ?? 0,
      );
}

// ============================================================================
// WEB PROFILE PANEL - SUPPORTS BOTH OWN AND OTHER USER PROFILES
// ============================================================================

class WebProfilePanel extends StatefulWidget {
  final String? userId;
  final String? username;
  final String? phone;
  final VoidCallback? onLogout;

  const WebProfilePanel({
    super.key,
    this.userId,
    this.username,
    this.phone,
    this.onLogout,
  });

  @override
  State<WebProfilePanel> createState() => _WebProfilePanelState();
}

class _WebProfilePanelState extends State<WebProfilePanel>
    with SingleTickerProviderStateMixin {
  // ==========================================================================
  // STATE
  // ==========================================================================

  final AuthService _authService = AuthService();

  String get _viewingUserId => widget.userId ?? _authService.userId ?? '';
  String get _viewingUsername => widget.username ?? _authService.username ?? '';
  String get _viewingPhone => widget.phone ?? _authService.phone ?? '';

  bool get _isCurrentUser => _viewingUserId == _authService.userId;

  WebUserData? _userData;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoggingOut = false;

  List<UserChannel> _userChannels = [];
  bool _isChannelsLoading = true;
  late TabController _tabController;
  int _selectedTab = 0;

  late TextEditingController _nicknameController;
  late TextEditingController _clubController;
  late TextEditingController _countryController;
  final FocusNode _nicknameFocus = FocusNode();
  final FocusNode _clubFocus = FocusNode();
  final FocusNode _countryFocus = FocusNode();

  double _balance = 0.0;
  bool _isBalanceLoading = true;

  bool _isProcessingPayment = false;
  bool _isWithdrawing = false;
  String? _authToken;

  static const String _apiBaseUrl = 'https://clash-api-m5mr.onrender.com/api';
  static const Duration _timeout = Duration(seconds: 15);

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

    _tabController = TabController(length: 0, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _selectedTab = _tabController.index);
      }
    });

    _loadAllData();
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

  Future<void> _loadAllData() async {
    if (_viewingUserId.isEmpty) {
      setState(() {
        _isLoading = false;
        _isChannelsLoading = false;
        _userData = null;
        _userChannels = [];
      });
      return;
    }

    await Future.wait([
      _loadUserData(),
      _loadUserChannels(),
    ]);

    if (_isCurrentUser) {
      _initPaymentGate();
    }
  }

  Future<void> _loadUserData() async {
    if (_viewingUserId.isEmpty) return;

    setState(() => _isLoading = true);

    if (_isCurrentUser &&
        AppCache.profile != null &&
        (AppCache.profile!['user_id']?.toString() ??
                AppCache.profile!['userId']?.toString() ??
                '') ==
            _viewingUserId) {
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
            Uri.parse('$_apiBaseUrl/profile/profile/$_viewingUserId'),
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
              _isEditing = _isCurrentUser;
            });
            return;
          }
          final userMap = Map<String, dynamic>.from(decoded.first as Map);
          final user = WebUserData.fromJson(userMap);
          _applyUserData(user);
          if (_isCurrentUser) await AppCache.saveProfile(userMap);
        } else if (decoded is Map) {
          final userMap = Map<String, dynamic>.from(decoded);
          final user = WebUserData.fromJson(userMap);
          _applyUserData(user);
          if (_isCurrentUser) await AppCache.saveProfile(userMap);
        } else {
          setState(() {
            _isLoading = false;
            _isEditing = _isCurrentUser;
          });
        }
      } else if (response.statusCode == 404) {
        setState(() {
          _isLoading = false;
          _isEditing = _isCurrentUser;
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
      }
    }
  }

  Future<void> _loadUserChannels() async {
    if (_viewingUserId.isEmpty) {
      setState(() {
        _userChannels = [];
        _isChannelsLoading = false;
      });
      return;
    }

    setState(() => _isChannelsLoading = true);

    try {
      final headers = _headers();
      final token = _authService.authToken;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .get(
            Uri.parse('$_apiBaseUrl/channels/user/$_viewingUserId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final List<dynamic> channelsData = data['channels'] ?? [];
        final channels = channelsData
            .map((c) => UserChannel.fromJson(c as Map<String, dynamic>))
            .toList();

        setState(() {
          _userChannels = channels;
          _isChannelsLoading = false;
        });

        final newCount = channels.length.clamp(0, 3);
        if (newCount != _tabController.length) {
          _tabController.dispose();
          _tabController = TabController(length: newCount, vsync: this);
          _tabController.addListener(() {
            if (_tabController.indexIsChanging) {
              setState(() => _selectedTab = _tabController.index);
            }
          });
        }
      } else {
        setState(() {
          _userChannels = [];
          _isChannelsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Load channels error: $e');
      setState(() {
        _userChannels = [];
        _isChannelsLoading = false;
      });
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
  // PAYMENT GATE - ONLY FOR CURRENT USER
  // ==========================================================================

  Future<void> _initPaymentGate() async {
    await _loadAuthToken();
    await _checkPaymentVisibility();
    if (_showPaymentFeatures) {
      _fetchBalance();
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
    if (!_isCurrentUser) return;
    setState(() => _isBalanceLoading = true);

    try {
      final balance = await PaymentService.getUserBalance(
        userId: _viewingUserId,
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
  // SAVE PROFILE - ONLY FOR CURRENT USER
  // ==========================================================================

  Future<void> _saveProfile() async {
    if (!_isCurrentUser) {
      ToastHelper.showWarning('You can only edit your own profile');
      return;
    }

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
        'user_id': _viewingUserId,
        'username': _viewingUsername,
        'phone': _viewingPhone,
        'nickname': nickname,
        'club_fan': club,
        'country_fan': country,
        'balance': _balance,
        'number_of_bets': _userData?.numberOfBets ?? 0,
      };

      final bool isNewUser = _userData == null;

      final url = isNewUser
          ? '$_apiBaseUrl/profile/create_profile'
          : '$_apiBaseUrl/profile/profiles/$_viewingUserId';

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

  // ==========================================================================
  // LOGOUT - ONLY FOR CURRENT USER
  // ==========================================================================

  Future<void> _logout() async {
    if (!_isCurrentUser) return;
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);

    try {
      await FirebaseAuth.instance.signOut();
      await _authService.logout();
      widget.onLogout?.call();
      if (mounted) {
        ToastHelper.showSuccess('Logged out');
        setState(() {
          _userData = null;
          _userChannels = [];
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
    final name = _userData?.nickname ?? _viewingUsername;
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  void _unfocusAll() {
    _nicknameFocus.unfocus();
    _clubFocus.unfocus();
    _countryFocus.unfocus();
    FocusScope.of(context).unfocus();
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
                  : '${_viewingUsername} has no channels',
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
    final sortedMembers = List<WebChannelMember>.from(
      channel.members.map((m) => WebChannelMember(
            userId: m.userId,
            username: m.username,
            correctVotes: m.correctVotes,
            totalVotes: m.totalVotes,
            msgCount: m.msgCount,
            seasonPoints: m.seasonPoints,
          )),
    )..sort((a, b) => b.seasonPoints.compareTo(a.seasonPoints));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member.username,
                                    style: FanTypography.body.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: FanColors.textPrimary,
                                    ),
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
            _isCurrentUser ? 'Complete Your Profile' : 'No profile available',
            style: FanTypography.title.copyWith(
              fontSize: 14,
              color: FanColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Center(
          child: Text(
            _isCurrentUser
                ? 'Tell us about yourself'
                : 'This user has not set up their profile yet',
            style: FanTypography.caption.copyWith(
              color: FanColors.textTertiary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_isCurrentUser) ...[
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
        ] else ...[
          Center(
            child: Text(
              'No profile information available',
              style: FanTypography.body.copyWith(
                color: FanColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
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
          hint: 'Which country you support?',
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
  // CHANNELS SECTION (header + tab bar + tab view, all rendered together)
  // ==========================================================================

  Widget _buildChannelsSection() {
    final channelCount = _userChannels.length.clamp(0, 3);

    if (channelCount == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        const Divider(height: 1),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 2),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: FanColors.primary.withValues(alpha: 0.15),
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
        const SizedBox(height: 2),

        // Tab bar sits directly under the "Channels" header now — no gap.
        _buildChannelTabBar(),
        const SizedBox(height: 2),

        // Fixed-height tab view so it can live inside the outer scroll view.
        // Horizontal swipe between tabs still works; vertical drag physics
        // are disabled here so it doesn't fight the outer scroll gesture.
        SizedBox(
          height: 180,
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(
              channelCount,
              (index) => _buildChannelFragment(index),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  // ==========================================================================
  // MAIN BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (_viewingUserId.isEmpty) {
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
                _isCurrentUser ? 'Not logged in' : 'User not found',
                style: TextStyle(
                  color: FanColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              if (_isCurrentUser)
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

    if (_isLoading || _isCheckingVisibility || _isChannelsLoading) {
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
                        _userData?.nickname ?? _viewingUsername,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: FanColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '@$_viewingUsername',
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

          // Everything below lives in ONE scrollable region now, so the
          // Channels section sits immediately after the profile content
          // instead of being pushed down by leftover Expanded space.
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  // Balance card - only for current user
                  if (_isCurrentUser &&
                      _showPaymentFeatures &&
                      _userData != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
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

                  // Channels section (header + tab bar + tab view together)
                  if (_userData != null) _buildChannelsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}