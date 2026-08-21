// lib/pages/home_page_web.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../pages/fan_Funzy_design.dart';
import '../WebView/Hompage/navbar.dart';
import 'Hompage/sidebar_profile.dart';
import '../WebView/Hompage/main_content_tabs.dart';
import '../pages/fixture_page.dart';
import "../pages/posts_page.dart";
import '../pages/logs.dart';
import '../../models/user_channel.dart';
import '../../services/auth_service.dart';
import '../../services/toast_helper.dart';
import '../main.dart'; // AppCache
import '../WebView/Hompage/sidebar_profile.dart' as profile_modal;

class HomePageWeb extends StatefulWidget {
  const HomePageWeb({super.key});

  @override
  State<HomePageWeb> createState() => _HomePageWebState();
}

class _HomePageWebState extends State<HomePageWeb> {
  static const String API_BASE_URL = 'https://clash-api-m5mr.onrender.com/api';
  static const int MAX_CHANNELS = 3;
  static const int TARGET_DISPLAY_COUNT = 5;

  String _selectedChannel = 'All Channels';
  String? _selectedChannelId;
  int _notificationCount = 3;

  final PageController _arenaPageController = PageController();
  final PageController _feedPageController = PageController();
  final PageController _logsPageController = PageController();

  bool _isLoggedIn = false;
  List<UserChannel> _userChannels = [];
  List<UserChannel> _allChannels = [];
  Set<String> _joiningChannelIds = {};
  int _maxChannels = MAX_CHANNELS;
  bool _isLoading = true;
  bool _isFull = false;

  // Profile data — nickname / clubFan / countryFan for the navbar.
  profile_modal.UserData? _profile;
  bool _isProfileLoading = true;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _authService.addListener(_onAuthStateChanged);
    _isLoggedIn = _authService.isLoggedIn;
    _loadAllData();
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (mounted) {
      setState(() {
        _isLoggedIn = _authService.isLoggedIn;
      });
      _loadAllData();
    }
  }

  // ==========================================================================
  // DATA LOADING METHODS
  // ==========================================================================

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    print('🔄 _loadAllData: Starting...');
    print('   isLoggedIn: $_isLoggedIn');

    try {
      if (!_isLoggedIn) {
        // Not logged in -> just show browsable channels, no profile.
        final browsable = await _fetchBrowsableChannels(
          excludeIds: const {},
          limit: TARGET_DISPLAY_COUNT,
        );
        setState(() {
          _userChannels = [];
          _allChannels = browsable;
          _isFull = false;
          _profile = null;
          _isProfileLoading = false;
        });
      } else {
        final userId = _authService.userId ?? '';
        final joined = await _fetchUserChannelsFromApi(userId);

        // Fire the profile fetch in parallel with channel resolution below —
        // it doesn't gate the channel UI, so don't await it inline.
        _loadProfile(userId);

        if (joined.length >= MAX_CHANNELS) {
          // Full -> only show joined channels, don't bother browsing.
          setState(() {
            _userChannels = joined.take(MAX_CHANNELS).toList();
            _allChannels = joined.take(MAX_CHANNELS).toList();
            _isFull = true;
          });
        } else {
          final joinedIds = joined.map((c) => c.channelId).toSet();
          final needed = TARGET_DISPLAY_COUNT - joined.length;
          final browsable = await _fetchBrowsableChannels(
            excludeIds: joinedIds,
            limit: needed,
          );
          setState(() {
            _userChannels = joined;
            _allChannels = [...joined, ...browsable];
            _isFull = false;
          });
        }
      }

      if (_allChannels.isNotEmpty && _selectedChannelId == null) {
        _selectedChannelId = _allChannels.first.channelId;
        _selectedChannel = _allChannels.first.name;
      }
    } catch (e) {
      print('❌ Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ==========================================================================
  // PROFILE — mirrors SwipeableProfileModal._loadUserData()
  // ==========================================================================

  Future<void> _loadProfile(String userId) async {
    if (userId.isEmpty) {
      setState(() {
        _profile = null;
        _isProfileLoading = false;
      });
      return;
    }

    setState(() => _isProfileLoading = true);

    // Instant paint from AppCache if it matches this user, same as the modal.
    if (AppCache.profile != null &&
        (AppCache.profile!['user_id']?.toString() ??
                AppCache.profile!['userId']?.toString() ??
                '') ==
            userId) {
      try {
        final cached = profile_modal.UserData.fromJson(AppCache.profile!);
        if (mounted) {
          setState(() {
            _profile = cached;
            _isProfileLoading = false;
          });
        }
        print('⚡ home_page_web: profile loaded instantly from AppCache');
      } catch (e) {
        print('⚠️ home_page_web: failed to apply cached profile: $e');
      }
    }

    try {
      final headers = {'Content-Type': 'application/json'};
      final token = _authService.authToken;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/profile/profile/$userId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      print('📥 home_page_web: GET profile -> ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        Map<String, dynamic>? userMap;
        if (decoded is List) {
          if (decoded.isNotEmpty) {
            userMap = Map<String, dynamic>.from(decoded.first as Map);
          }
        } else if (decoded is Map) {
          userMap = Map<String, dynamic>.from(decoded);
        }

        if (userMap != null && mounted) {
          final user = profile_modal.UserData.fromJson(userMap);
          setState(() {
            _profile = user;
            _isProfileLoading = false;
          });
          await AppCache.saveProfile(userMap);
          return;
        }
      }

      // 404 / empty / unparsable -> no profile yet, but don't blow away
      // anything already painted from cache.
      if (mounted && _profile == null) {
        setState(() => _isProfileLoading = false);
      }
    } catch (e) {
      print('❌ home_page_web: _loadProfile error: $e');
      if (mounted) {
        setState(() => _isProfileLoading = false);
      }
    }
  }

  // ==========================================================================
  // API METHODS
  // ==========================================================================

  Future<List<UserChannel>> _fetchUserChannelsFromApi(String userId) async {
    print('🌐 _fetchUserChannelsFromApi: userId: $userId');
    if (userId.isEmpty) return [];

    try {
      final headers = {'Content-Type': 'application/json'};
      final token = _authService.authToken;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .get(Uri.parse('$API_BASE_URL/channels/user/$userId'),
              headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> channelsData = data['channels'] ?? [];
        final result = channelsData
            .map((c) => UserChannel.fromJson(c as Map<String, dynamic>))
            .toList();
        print('✅ Loaded ${result.length} user channels');
        return result;
      }

      print('❌ _fetchUserChannelsFromApi failed: ${response.statusCode}');
    } catch (e) {
      print('❌ _fetchUserChannelsFromApi error: $e');
    }
    return [];
  }

  Future<List<UserChannel>> _fetchBrowsableChannels({
    required Set<String> excludeIds,
    required int limit,
  }) async {
    print(
        '🌐 _fetchBrowsableChannels: limit=$limit, excluding=${excludeIds.length}');
    try {
      final headers = {'Content-Type': 'application/json'};
      final token = _authService.authToken;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .get(Uri.parse('$API_BASE_URL/channels/all'), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> channelsData = data['channels'] ?? [];
        final fetched = channelsData
            .map((c) => UserChannel.fromJson(c as Map<String, dynamic>))
            .where((c) => !excludeIds.contains(c.channelId))
            .toList();
        final result = fetched.take(limit).toList();
        print('✅ _fetchBrowsableChannels returned ${result.length} channels');
        return result;
      }

      print('❌ _fetchBrowsableChannels failed: ${response.statusCode}');
    } catch (e) {
      print('❌ _fetchBrowsableChannels error: $e');
    }
    return [];
  }

  Future<bool> _joinChannelApi(String userId, String channelId) async {
    print('🌐 _joinChannelApi: userId: $userId, channelId: $channelId');
    try {
      final headers = {'Content-Type': 'application/json'};
      final token = _authService.authToken;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/channels/members/add'),
            headers: headers,
            body: json.encode({
              'channel_id': channelId,
              'user_id': userId,
              'username': _authService.username ?? '',
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('❌ _joinChannelApi error: $e');
      return false;
    }
  }

  // ==========================================================================
  // EVENT HANDLERS
  // ==========================================================================

  Future<void> _handleJoinChannel(UserChannel channel) async {
    print('🔗 _handleJoinChannel: ${channel.name}');
    setState(() {
      _joiningChannelIds.add(channel.channelId);
    });

    try {
      final success = await _joinChannelApi(
        _authService.userId ?? '',
        channel.channelId,
      );

      if (success && mounted) {
        await _loadAllData();
        //ToastHelper.showSuccess('Joined ${channel.name} successfully!');
      } else {
        // ToastHelper.showError('Failed to join channel');
      }
    } catch (e) {
      print('❌ Join channel error: $e');
      // ToastHelper.showError('Error joining channel');
    } finally {
      if (mounted) {
        setState(() {
          _joiningChannelIds.remove(channel.channelId);
        });
      }
    }
  }

  void _handleChannelSelected(UserChannel channel) {
    print('📌 _handleChannelSelected: ${channel.name}');
    setState(() {
      _selectedChannelId = channel.channelId;
      _selectedChannel = channel.name;
    });
  }

  void _handleCreateChannel() {
    print('➕ _handleCreateChannel');
    //ToastHelper.showInfo('Create channel feature coming soon!');
  }

  void _handleLogout() {
    print('🚪 _handleLogout');
    _authService.logout();
    setState(() {
      _isLoggedIn = false;
      _userChannels = [];
      _profile = null;
    });
    // ToastHelper.showSuccess('Logged out successfully');
  }

  // ==========================================================================
  // UI METHODS
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: FanColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: FanColors.primary),
              const SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(color: FanColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: FanColors.background,
      body: Column(
        children: [
          WebNavbar(
            isLoggedIn: _isLoggedIn,
            userChannels: _userChannels,
            allChannels: _allChannels,
            selectedChannelId: _selectedChannelId,
            joiningChannelIds: _joiningChannelIds,
            maxChannels: _maxChannels,
            onChannelSelected: _handleChannelSelected,
            onJoinChannel: _handleJoinChannel,
            onCreateChannel: _handleCreateChannel,
            onMenuTap: _showMenu,
            onNotificationTap: _showNotifications,
            notificationCount: _notificationCount,
            userId: _authService.userId,
            nickname: _profile?.nickname,
            teamName: _profile?.clubFan,
            country: _profile?.countryFan,
          ),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 280,
                  child: SidebarProfile(
                    apiBaseUrl: 'https://clash-api-m5mr.onrender.com',
                    userId: _authService.userId ?? '',
                    username: _authService.username ?? '',
                    phone: _authService.phone ?? '',
                    onLogout: _handleLogout,
                    userChannels: _userChannels,
                  ),
                ),
                Expanded(
                  child: MainContentTabs(
                    arenaContent: FixturesPage(
                      userId: _authService.userId ?? '',
                      username: _authService.username ?? '',
                      authToken: null,
                      scrollController: null,
                      onLogout: _handleLogout,
                      isLoggedIn: _isLoggedIn,
                      syncToFixtures: true,
                      selectedChannelId: _selectedChannelId,
                      selectedChannelName: _selectedChannel,
                      userChannels: _userChannels,
                    ),
                    feedContent: PostsPage(
                      currentUserId: _authService.userId ?? '',
                      currentUsername: _authService.username ?? '',
                      authToken: null,
                      scrollController: null,
                      onLogout: _handleLogout,
                      isLoggedIn: _isLoggedIn,
                    ),
                    logsContent: HistoryPage(
                      userId: _authService.userId ?? '',
                      username: _authService.username ?? '',
                      authToken: null,
                      isLoggedIn: _isLoggedIn,
                      userChannels: _userChannels,
                      scrollController: null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 200,
        decoration: BoxDecoration(
          color: FanColors.surfaceElevated,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FanColors.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.person_outline, color: FanColors.textPrimary),
              title: Text('Profile',
                  style: TextStyle(color: FanColors.textPrimary)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading:
                  Icon(Icons.settings_outlined, color: FanColors.textPrimary),
              title: Text('Settings',
                  style: TextStyle(color: FanColors.textPrimary)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.logout, color: FanColors.away),
              title: Text('Logout', style: TextStyle(color: FanColors.away)),
              onTap: () {
                Navigator.pop(context);
                _handleLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 400,
        decoration: BoxDecoration(
          color: FanColors.surfaceElevated,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FanColors.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.notifications, color: FanColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: FanColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Mark all read',
                    style: TextStyle(
                      fontSize: 12,
                      color: FanColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildNotificationItem(
                    icon: '⚽',
                    title: 'New match added',
                    subtitle: 'Liverpool vs Everton added to Arena',
                    time: '2 min ago',
                  ),
                  _buildNotificationItem(
                    icon: '💬',
                    title: 'New comment',
                    subtitle: 'John commented on your post',
                    time: '15 min ago',
                  ),
                  _buildNotificationItem(
                    icon: '👤',
                    title: 'New follower',
                    subtitle: 'Sarah started following you',
                    time: '1 hour ago',
                  ),
                  _buildNotificationItem(
                    icon: '🏆',
                    title: 'Leaderboard update',
                    subtitle: 'You moved to #3 in Premier League',
                    time: '3 hours ago',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required String icon,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FanColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FanColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: FanColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 10,
              color: FanColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}