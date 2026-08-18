// lib/pages/home_page_web.dart
import 'package:flutter/material.dart';
import '../pages/fan_Funzy_design.dart';
import '../WebView/Hompage/channels.dart';
import '../WebView/Hompage/navbar.dart';
import 'Hompage/sidebar_profile.dart';
import '../WebView/Hompage/main_content_tabs.dart';
import '../pages/fixture_page.dart';
import "../pages/posts_page.dart";
import '../pages/logs.dart';
import '../../models/user_channel.dart';
import '../../services/auth_service.dart';
import '../../services/toast_helper.dart';

class HomePageWeb extends StatefulWidget {
  const HomePageWeb({super.key});

  @override
  State<HomePageWeb> createState() => _HomePageWebState();
}

class _HomePageWebState extends State<HomePageWeb> {
  String _selectedChannel = 'All Channels';
  String? _selectedChannelId;
  List<Channel> _channels = [];
  int _notificationCount = 3;

  final PageController _arenaPageController = PageController();
  final PageController _feedPageController = PageController();
  final PageController _logsPageController = PageController();

  bool _isLoggedIn = false;
  List<UserChannel> _userChannels = [];
  List<UserChannel> _allChannels = [];
  Set<String> _joiningChannelIds = {};
  int _maxChannels = 3;
  bool _isLoading = true;

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
      await _loadChannels();
      await _loadAllChannels();

      if (_isLoggedIn) {
        await _loadUserChannels();
      } else {
        setState(() {
          _userChannels = [];
        });
      }

      if (_channels.isNotEmpty && _selectedChannelId == null) {
        _selectedChannelId = _channels.first.id;
        _selectedChannel = _channels.first.name;
      }
    } catch (e) {
      print('❌ Error loading data: $e');
      
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadChannels() async {
    print('🔄 _loadChannels: Starting...');
    try {
      final channels = await _fetchChannelsFromApi();
      print('✅ _fetchChannelsFromApi returned ${channels.length} channels');
      setState(() {
        _channels = channels;
      });
    } catch (e) {
      print('❌ _loadChannels failed: $e');
      setState(() {
        _channels = MockChannelData.getChannels();
        print('📦 Fallback: ${_channels.length} mock channels loaded');
      });
    }
  }

  Future<void> _loadUserChannels() async {
    final userId = _authService.userId;
    if (userId == null || userId.isEmpty) {
      setState(() {
        _userChannels = [];
      });
      return;
    }

    print('🔄 _loadUserChannels: Starting for userId: $userId');
    try {
      final userChannels = await _fetchUserChannelsFromApi(userId);
      setState(() {
        _userChannels = userChannels;
      });
      print('✅ Loaded ${_userChannels.length} user channels');
    } catch (e) {
      print('❌ Failed to load user channels: $e');
      setState(() {
        _userChannels = [];
      });
    }
  }

  Future<void> _loadAllChannels() async {
    print('🔄 _loadAllChannels: Starting...');
    print('   _channels length before: ${_channels.length}');
    try {
      final allChannels = await _fetchAllChannelsFromApi();
      print(
          '✅ _fetchAllChannelsFromApi returned ${allChannels.length} channels');
      setState(() {
        _allChannels = allChannels;
      });
    } catch (e) {
      print('❌ _loadAllChannels failed: $e');
      setState(() {
        _allChannels = _channels
            .map((c) => UserChannel(
                  channelId: c.id,
                  name: c.name,
                  members: [],
                  memberCount: c.memberCount,
                  season: '1',
                  isAdmin: false,
                ))
            .toList();
        print(
            '📦 Fallback: ${_allChannels.length} UserChannels from _channels');
      });
    }
  }

  // ==========================================================================
  // API METHODS
  // ==========================================================================

  Future<List<Channel>> _fetchChannelsFromApi() async {
    print('🌐 _fetchChannelsFromApi: Returning mock channels...');
    return MockChannelData.getChannels();
  }

  Future<List<UserChannel>> _fetchUserChannelsFromApi(String userId) async {
    print('🌐 _fetchUserChannelsFromApi: userId: $userId');
    final allChannels = await _fetchAllChannelsFromApi();
    if (allChannels.length >= 2) {
      return allChannels.take(2).toList();
    }
    return [];
  }

  Future<List<UserChannel>> _fetchAllChannelsFromApi() async {
    print(
        '🌐 _fetchAllChannelsFromApi: Converting _channels to UserChannel...');
    print('   _channels length: ${_channels.length}');

    if (_channels.isEmpty) {
      print('⚠️ _channels is empty, loading mock channels...');
      await _loadChannels();
    }

    final result = _channels
        .map((c) => UserChannel(
              channelId: c.id,
              name: c.name,
              members: [],
              memberCount: c.memberCount,
              season: '1',
              isAdmin: false,
            ))
        .toList();
    print('✅ Converted ${result.length} channels to UserChannel');
    return result;
  }

  Future<bool> _joinChannelApi(String userId, String channelId) async {
    print('🌐 _joinChannelApi: userId: $userId, channelId: $channelId');
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  // ==========================================================================
  // MOCK DATA
  // ==========================================================================


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
        await _loadUserChannels();
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
