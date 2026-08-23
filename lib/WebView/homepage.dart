// lib/pages/home_page_web.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:funspot/modals/FAB/profile_modal.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/fan_Funzy_design.dart';
import '../WebView/Hompage/navbar.dart';
import '../WebView/Hompage/sidebar_profile.dart';
import '../WebView/Hompage/main_content_tabs.dart';
import '../pages/fixture_page.dart' hide ToastHelper;
import "../pages/posts_page.dart";
import '../modals/homepage/notifications_modal.dart';
import '../pages/logs.dart';
import '../modals/Funzy/leaderboard.dart';
import '../../models/user_channel.dart';
import '../../services/auth_service.dart';
import '../../services/toast_helper.dart';
import '../../services/notification_service.dart';
import '../../modals/Funzy/chat_screen.dart';
import '../../modals/login_modal.dart';
import '../../modals/FAB/add_post_modal.dart';
import '../../modals/FAB/comrade_list.dart';
import '../../modals/Funzy/swipabledialogue.dart';
import '../../modals/homepage/admin_dashboard.dart';
import '../../modals/homepage/channel_creation.dart';
import '../main.dart'; // ✅ for AppCache — single source of truth for channels

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
  int _notificationCount = 0;
  int _pendingJoinCount = 0;
  Set<String> _pendingJoinRequests = {};

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

  // Track if we need to rebuild FixturesPage
  int _fixturesPageKey = 0;

  final AuthService _authService = AuthService();
  bool _isModalOpen = false;

  // Menu state
  bool _isMenuOpen = false;
  OverlayEntry? _menuOverlay;

  // Notification state
  List<Map<String, dynamic>> _notifications = [];
  bool _hasUnreadNotifications = false;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _authService.addListener(_onAuthStateChanged);
    _isLoggedIn = _authService.isLoggedIn;
    _loadAllData();
    _loadPendingJoinRequests();
    _loadStoredNotifications();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthStateChanged);
    _notificationSubscription?.cancel();
    _badgeStreamSubscription?.cancel();
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (mounted) {
      setState(() {
        _isLoggedIn = _authService.isLoggedIn;
      });
      _loadAllData();
      _loadPendingJoinRequests();
    }
  }

  // ==========================================================================
  // NOTIFICATION SYSTEM
  // ==========================================================================

  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;
  StreamSubscription<Map<String, dynamic>>? _badgeStreamSubscription;

  void _subscribeToNotifications() {
    _notificationSubscription = NotificationService.notificationStream
        .listen(_handleIncomingNotification);
    _badgeStreamSubscription =
        NotificationService.badgeStream.listen(_handleBadgeUpdate);
  }

  void _handleIncomingNotification(Map<String, dynamic> message) {
    if (!mounted) return;

    final notificationType =
        message['type'] ?? message['notificationType'] ?? 'general';
    final data = message['data'] ?? {};

    if (notificationType == 'join_request') {
      final channelId = data['channel_id']?.toString() ?? '';
      final channelName = data['channel_name']?.toString() ?? 'Unknown Channel';
      final username = data['username']?.toString() ?? 'Someone';

      setState(() {
        if (channelId.isNotEmpty) {
          _pendingJoinRequests.add(channelId);
          _pendingJoinCount++;
          _notificationCount++;
        }
      });

      _savePendingJoinRequests();

      return;
    }

    if (notificationType == 'join_approved') {
      final channelId = data['channel_id']?.toString() ?? '';
      final channelName = data['channel_name']?.toString() ?? 'Unknown Channel';

      setState(() {
        if (channelId.isNotEmpty) {
          _pendingJoinRequests.remove(channelId);
          _pendingJoinCount = _pendingJoinCount > 0 ? _pendingJoinCount - 1 : 0;
          _notificationCount =
              _notificationCount > 0 ? _notificationCount - 1 : 0;
        }
      });

      _savePendingJoinRequests();
      _loadAllData();

      return;
    }

    if (notificationType == 'join_rejected') {
      final channelId = data['channel_id']?.toString() ?? '';
      final channelName = data['channel_name']?.toString() ?? 'Unknown Channel';

      setState(() {
        if (channelId.isNotEmpty) {
          _pendingJoinRequests.remove(channelId);
          _pendingJoinCount = _pendingJoinCount > 0 ? _pendingJoinCount - 1 : 0;
          _notificationCount =
              _notificationCount > 0 ? _notificationCount - 1 : 0;
        }
      });

      _savePendingJoinRequests();

      return;
    }

    // Add to notification list
    _addToNotificationList({
      'type': notificationType,
      'title': message['title'] ?? 'Notification',
      'body': message['body'] ?? '',
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'isUnread': true,
    });
  }

  void _handleBadgeUpdate(Map<String, dynamic> event) {
    if (!mounted) return;

    final type = event['type'] as String?;

    if (type == 'join_request') {
      final channelId = event['channel_id']?.toString() ?? '';
      if (channelId.isNotEmpty) {
        setState(() {
          _pendingJoinRequests.add(channelId);
          _pendingJoinCount = (_pendingJoinCount ?? 0) + 1;
          _notificationCount = (_notificationCount ?? 0) + 1;
        });
        _savePendingJoinRequests();
      }
    } else if (type == 'join_approved' || type == 'join_rejected') {
      final channelId = event['channel_id']?.toString() ?? '';
      if (channelId.isNotEmpty) {
        setState(() {
          _pendingJoinRequests.remove(channelId);
          _pendingJoinCount = _pendingJoinCount > 0 ? _pendingJoinCount - 1 : 0;
          _notificationCount =
              _notificationCount > 0 ? _notificationCount - 1 : 0;
        });
        _savePendingJoinRequests();
      }
    } else if (type == 'notification_badge_update') {
      final total = event['total_unread_notifications'] as int? ?? 0;
      setState(() {
        _notificationCount = total;
        _hasUnreadNotifications = total > 0;
      });
    } else if (type == 'notification_badge_cleared_all') {
      setState(() {
        _notificationCount = 0;
        _hasUnreadNotifications = false;
      });
    }
  }

  void _addToNotificationList(Map<String, dynamic> notification) {
    setState(() {
      _notifications.insert(0, notification);
      if (_notifications.length > 50) {
        _notifications = _notifications.take(50).toList();
      }
      _notificationCount =
          _notifications.where((n) => n['isUnread'] == true).length;
      _hasUnreadNotifications = _notificationCount > 0;
    });
    _saveNotifications();
  }

  Future<void> _loadStoredNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('notifications');
      if (stored != null) {
        final loaded = jsonDecode(stored) as List;
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(loaded);
          _notificationCount =
              _notifications.where((n) => n['isUnread'] == true).length;
          _hasUnreadNotifications = _notificationCount > 0;
        });
      }
      final savedCount = prefs.getInt('notificationCount') ?? 0;
      if (_notificationCount == 0) {
        setState(() => _notificationCount = savedCount);
      }
    } catch (e) {}
  }

  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notifications', jsonEncode(_notifications));
      await prefs.setInt('notificationCount', _notificationCount);
    } catch (e) {}
  }

  Future<void> _loadPendingJoinRequests() async {
    try {
      final requests = await NotificationService.getPendingJoinRequests();
      setState(() {
        _pendingJoinCount = requests.length;
        _pendingJoinRequests.clear();
        for (final request in requests) {
          final channelId = request['channel_id']?.toString();
          if (channelId != null) {
            _pendingJoinRequests.add(channelId);
          }
        }
      });
    } catch (e) {
      debugPrint('Failed to load pending join requests: $e');
    }
  }

  Future<void> _savePendingJoinRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final requests = _pendingJoinRequests
          .map((id) => {
                'channel_id': id,
                'timestamp': DateTime.now().toIso8601String(),
              })
          .toList();
      await prefs.setString('pending_join_requests', jsonEncode(requests));
    } catch (e) {
      debugPrint('Failed to save pending join requests: $e');
    }
  }

  // ==========================================================================
// HANDLE OPEN LEADERBOARD — mirrors mobile home_page.dart's
// _showChannelLeaderboard exactly (opens ComradeModal, selects channel first)
// ==========================================================================
  void _handleOpenLeaderboard(UserChannel channel) {
    print('🏆 Leaderboard tap on channel: ${channel.name}');

    if (!_isLoggedIn) {
      _showLoginModal();
      return;
    }

    // Select the channel first, same as mobile.
    _handleChannelSelected(channel);

    if (_isModalOpen) return;
    _isModalOpen = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ComradeModal(
        isOpen: true,
        onClose: () {
          Navigator.pop(context);
          _isModalOpen = false;
        },
        currentUserId: _authService.userId ?? '',
        currentUserName: _authService.username ?? '',
        authToken: _authService.authToken,
        channelId: channel.channelId,
        channelName: channel.name,
        fixture: null,
        comradesList: const <String>{},
        comradesVoteMap: const {},
        hasUserVoted: false,
        userVoteSelection: null,
      ),
    ).then((_) {
      _isModalOpen = false;
    });
  }

  String _getBadgeDisplayCount() {
    final int total = _notificationCount + _pendingJoinCount;
    if (total == 0) return '';
    if (total > 99) return '99+';
    return total.toString();
  }

  void _onNotificationsViewed() {
    if (_pendingJoinCount > 0) {
      _showPendingRequestsModal();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NotificationsListModal(
        notifications: _notifications,
        onMarkAllRead: () {
          if (!mounted) return;
          setState(() {
            for (var notification in _notifications) {
              notification['isUnread'] = false;
            }
            _notificationCount = 0;
            _hasUnreadNotifications = false;
          });
          _saveNotifications();
        },
        onClearAll: () {
          if (!mounted) return;
          setState(() {
            _notifications.clear();
            _notificationCount = 0;
            _hasUnreadNotifications = false;
          });
          _saveNotifications();
        },
        onNotificationTap: (tapped) {
          Navigator.pop(context); // close the modal first
          _routeNotificationTap(tapped);
        },
      ),
    );
  }

  /// Optional routing — sends the user somewhere useful depending on the
  /// notification type. Safe to leave as a no-op stub for types you don't
  /// want to route yet; extend as needed.
  void _routeNotificationTap(Map<String, dynamic> tapped) {
    final type = tapped['type']?.toString() ?? '';
    final data = tapped['data'] is Map
        ? Map<String, dynamic>.from(tapped['data'])
        : <String, dynamic>{};

    switch (type) {
      case 'comrade_added':
        _showComradesModal();
        break;
      case 'channel_invite':
      case 'join_link':
        // channel_id available in `data['channel_id']` if you want to
        // navigate straight into that channel's chat.
        break;
      default:
        break;
    }
  }

  void _showPendingRequestsModal() {
    if (_isModalOpen || !mounted) return;

    if (_pendingJoinCount == 0) {
      return;
    }

    _isModalOpen = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PendingRequestsModal(
        userId: _authService.userId ?? '',
        username: _authService.username ?? '',
        authToken: _authService.authToken,
        userChannels: _userChannels,
        onRequestProcessed: () {
          _loadPendingJoinRequests();
          _loadAllData();
          setState(() {});
        },
      ),
    ).then((_) {
      _isModalOpen = false;
      _loadPendingJoinRequests();
    });
  }

  // ==========================================================================
  // MENU SYSTEM
  // ==========================================================================

  void _showMenu() {
    if (_isMenuOpen) {
      _hideMenu();
      return;
    }
    _isMenuOpen = true;

    final RenderBox? avatarBox = context.findRenderObject() as RenderBox?;
    if (avatarBox == null) {
      _isMenuOpen = false;
      return;
    }

    final Offset avatarPosition = avatarBox.localToGlobal(Offset.zero);

    _menuOverlay = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _hideMenu,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Container(color: Colors.transparent),
            Positioned(
              top: avatarPosition.dy + 50,
              right: 24,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: FanColors.surfaceElevated,
                child: Container(
                  width: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: FanColors.border.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMenuItem(
                        icon: Icons.person_outline,
                        title: 'Profile',
                        onTap: () {
                          _hideMenu();
                          _showMyProfile();
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.group_add_outlined,
                        title: 'Comrades',
                        onTap: () {
                          _hideMenu();
                          _showComradesModal();
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.post_add,
                        title: 'Create Post',
                        onTap: () {
                          _hideMenu();
                          _showPostModal();
                        },
                      ),
                      if (_isLoggedIn && _userChannels.isNotEmpty)
                        _buildMenuItem(
                          icon: Icons.post_add,
                          title: 'Create Channel',
                          onTap: () {
                            _hideMenu();
                            _showCreateChannelModal();
                          },
                        ),
                      if (_isLoggedIn && _userChannels.isNotEmpty)
                        _buildMenuItem(
                          icon: Icons.bolt,
                          title: 'Admin Dashboard',
                          onTap: () {
                            _hideMenu();
                            _showAdminDashboard();
                          },
                        ),
                      const Divider(height: 1),
                      if (_isLoggedIn)
                        _buildMenuItem(
                          icon: Icons.logout,
                          title: 'Logout',
                          isDestructive: true,
                          onTap: () {
                            _hideMenu();
                            _handleLogout();
                          },
                        )
                      else
                        _buildMenuItem(
                          icon: Icons.login,
                          title: 'Login',
                          onTap: () {
                            _hideMenu();
                            _showLoginModal();
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_menuOverlay!);
  }

  void _hideMenu() {
    _menuOverlay?.remove();
    _menuOverlay = null;
    _isMenuOpen = false;
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isDestructive ? FanColors.away : FanColors.textPrimary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDestructive ? FanColors.away : FanColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // MODAL SHOW METHODS - FULL IMPLEMENTATION
  // ==========================================================================
  void _showMyProfile() {
    if (!_isLoggedIn) {
      _showLoginModal();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SwipeableProfileModal(
        apiBaseUrl: API_BASE_URL.replaceAll('/api', ''),
        userId: _authService.userId ?? '',
        username: _authService.username ?? '',
        phone: _authService.phone ?? '',
        userChannels: _userChannels,
        onUserUpdated: (userData) {
          setState(() {});
        },
        onLogout: _handleLogout,
      ),
    );
  }

  void _showComradesModal() {
    if (!_isLoggedIn) {
      _showLoginModal();
      return;
    }

    final Set<String> comradesList = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ComradeListModal(
        currentUserId: _authService.userId ?? '',
        authToken: _authService.authToken,
        userChannels: _userChannels,
        comradesList: comradesList,
        onComradeAdded: () {
          _loadAllData();
          setState(() {});
        },
      ),
    );
  }

  void _showPostModal() {
    if (!_isLoggedIn) {
      _showLoginModal();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPostModal(
        userId: _authService.userId ?? '',
        username: _authService.username ?? '',
        onPostCreated: () {
          Navigator.pop(context);
          setState(() {});
        },
      ),
    );
  }

  void _showCreateChannelModal() {
    if (_isModalOpen || !mounted) return;
    if (!_isLoggedIn) {
      _showLoginModal();
      return;
    }

    // Block channel creation once user already belongs to 3 groups
    if (_userChannels.length >= MAX_CHANNELS) {
      return;
    }

    _isModalOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateChannelModal(
        userId: _authService.userId ?? '',
        username: _authService.username ?? '',
        authToken: _authService.authToken,
        onChannelCreated: () {
          _loadAllData();
          setState(() {});
        },
      ),
    ).then((_) {
      _isModalOpen = false;
    });
  }

  void _showAdminDashboard() {
    if (_isModalOpen || !mounted) return;
    if (!_isLoggedIn) {
      _showLoginModal();
      return;
    }
    if (_userChannels.isEmpty) return;

    _isModalOpen = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AdminDashboardModal(
        isOpen: true,
        onClose: () => Navigator.pop(context),
        userId: _authService.userId ?? '',
        username: _authService.username ?? '',
        authToken: _authService.authToken,
        userChannels: _userChannels,
        pendingJoinCount: _pendingJoinCount,
      ),
    ).then((_) {
      _isModalOpen = false;
    });
  }

  // ==========================================================================
  // DATA LOADING METHODS
  // ==========================================================================
  //
  // ✅ REWRITTEN to mirror mobile's home_page.dart pattern exactly:
  //   - Cache shown instantly (AppCache.channels) when available.
  //   - Real revalidation always goes through AppCache.refreshChannels,
  //     never a raw http.get to /channels/user/$userId.
  //   - Browsable-channel rules (MAX_CHANNELS / TARGET_DISPLAY_COUNT) are
  //     applied in one shared place (_applyJoinedChannels) so cache and
  //     network paths can't drift apart.
  // ==========================================================================

  Future<void> _loadAllData() async {
    print('🔄 _loadAllData: Starting...');
    print('   isLoggedIn: $_isLoggedIn');

    try {
      if (!_isLoggedIn) {
        setState(() => _isLoading = true);
        final browsable = await _fetchBrowsableChannels(
          excludeIds: const {},
          limit: TARGET_DISPLAY_COUNT,
        );
        setState(() {
          _userChannels = [];
          _allChannels = browsable;
          _isFull = false;
          _selectedChannelId = null;
          _selectedChannel = 'All Channels';
        });
        return;
      }

      // ✅ Cache-first: show whatever AppCache already has instantly.
      if (AppCache.channels.isNotEmpty) {
        final cached = List<UserChannel>.from(AppCache.channels);
        await _applyJoinedChannels(cached);
        if (mounted) setState(() => _isLoading = false);

        // Cache might be stale — always revalidate in the background.
        await _refreshChannelsInBackground();
        return;
      }

      // No cache at all — go straight to network.
      setState(() => _isLoading = true);
      await _refreshChannelsInBackground();
    } catch (e) {
      print('❌ Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// ✅ Single source of truth for joined channels. Always goes through
  /// AppCache.refreshChannels — this is what mobile's home_page.dart does
  /// via its own _refreshChannelsInBackground(), and keeps web in sync
  /// with whatever logic AppCache uses internally.
  Future<void> _refreshChannelsInBackground() async {
    final userId = _authService.userId ?? '';
    if (userId.isEmpty) return;

    await AppCache.refreshChannels(userId, _authService.authToken);

    if (!mounted) return;

    final joined = List<UserChannel>.from(AppCache.channels);
    print('✅ Loaded ${joined.length} user channels (via AppCache)');

    await _applyJoinedChannels(joined);

    if (mounted) setState(() => _isLoading = false);
  }

  /// Shared logic for applying the MAX_CHANNELS / browsable-fill rules
  /// once we have a joined-channels list, whether it came from cache or
  /// a fresh AppCache.refreshChannels() call.
  Future<void> _applyJoinedChannels(List<UserChannel> joined) async {
    if (joined.length >= MAX_CHANNELS) {
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

    // If no channel is selected yet, select the first one.
    if (_selectedChannelId == null && _userChannels.isNotEmpty) {
      _selectedChannelId = _userChannels.first.channelId;
      _selectedChannel = _userChannels.first.name;
    }
    if (_allChannels.isNotEmpty && _selectedChannelId == null) {
      _selectedChannelId = _allChannels.first.channelId;
      _selectedChannel = _allChannels.first.name;
    }
  }

  // ==========================================================================
  // API METHODS
  // ==========================================================================
  //
  // ⚠️ NOTE: _fetchUserChannelsFromApi has been REMOVED. It used to call
  // GET /channels/user/$userId directly, bypassing AppCache entirely, which
  // is what caused web to show only 1 joined channel while mobile (which
  // always reads through AppCache.channels) showed the correct count.
  // All joined-channel reads now go through AppCache — see
  // _refreshChannelsInBackground() above.
  // ==========================================================================

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

    // Fallback: best-effort from AppCache, still excluding joined ones.
    return AppCache.channels
        .where((c) => !excludeIds.contains(c.channelId))
        .take(limit)
        .toList();
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
            'members': [
              {'user_id': userId, 'username': _authService.username ?? ''},
            ],
          }),
        )
        .timeout(const Duration(seconds: 10));

    return response.statusCode == 200 || response.statusCode == 201;
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

  if (!_isLoggedIn) {
    _showLoginModal();
    return;
  }

  // ✅ Don't join a channel that already has a pending request.
  if (_pendingJoinRequests.contains(channel.channelId)) {
    return;
  }

  // ✅ Double-tap guard — mirrors mobile's _joinChannelDirectly.
  if (_joiningChannelIds.contains(channel.channelId)) {
    return;
  }

  setState(() {
    _joiningChannelIds.add(channel.channelId);
  });

  try {
    final success = await _joinChannelApi(
      _authService.userId ?? '',
      channel.channelId,
    );

    if (success && mounted) {
      // ✅ Revalidate through AppCache instead of a full _loadAllData(),
      // which used to just re-read the same stale source. This mirrors
      // mobile's _joinChannelDirectly -> _refreshChannelsInBackground.
      await _refreshChannelsInBackground();
      _loadPendingJoinRequests();
    } else if (mounted) {
      //ToastHelper.showError('Failed to join channel', context: context);
    }
  } catch (e) {
    print('❌ Join channel error: $e');
    if (mounted) {
      //ToastHelper.showError('Error: $e', context: context);
    }
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
      _fixturesPageKey++;
    });
  }

  void _handleCreateChannel() {
    print('➕ _handleCreateChannel');
    _showCreateChannelModal();
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    try {
      await _authService.logout();
      setState(() {
        _isLoggedIn = false;
        _userChannels = [];
        _selectedChannelId = null;
        _selectedChannel = 'All Channels';
        _fixturesPageKey++;
        _notificationCount = 0;
        _pendingJoinCount = 0;
        _pendingJoinRequests.clear();
        _notifications.clear();
      });
      _saveNotifications();
      _savePendingJoinRequests();
    } catch (e) {
      // Logout failed
    } finally {
      _isLoggingOut = false;
    }
  }

  // ==========================================================================
  // HANDLE OPEN CHAT - WITH WIDE SCREEN CONDITIONAL
  // ==========================================================================

  Future<void> _handleOpenChat(UserChannel channel) async {
    print('📱 Long press on channel: ${channel.name}');

    if (!_isLoggedIn) {
      _showLoginModal();
      return;
    }

    final chatScreen = ChatScreen(
      channelId: channel.channelId,
      fixtureId: null,
      fixture: null,
      userId: _authService.userId ?? '',
      username: _authService.username ?? '',
      authToken: _authService.authToken,
      isLoggedIn: _isLoggedIn,
      comradesList: Set<String>(),
      userVoteSelection: null,
    );

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth >= 900;

    if (isWideScreen) {
      await showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.5),
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 80,
            vertical: 40,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 480,
              height: MediaQuery.of(context).size.height * 0.85,
              constraints: const BoxConstraints(maxHeight: 900),
              color: FanColors.background,
              child: chatScreen,
            ),
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => chatScreen),
      );
    }
  }

  // ==========================================================================
  // SHOW LOGIN MODAL
  // ==========================================================================

  void _showLoginModal() {
    if (_isModalOpen) return;
    _isModalOpen = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LoginModal(
        onLoginSuccess: (userId, username) async {
          if (mounted) {
            _isModalOpen = false;
            Navigator.pop(context);
            _loadAllData();
            _loadPendingJoinRequests();
          }
        },
      ),
    ).then((_) {
      _isModalOpen = false;
    });
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
            pendingChannelIds: _pendingJoinRequests,
            onOpenChat: _handleOpenChat,
            onOpenLeaderboard: _handleOpenLeaderboard,
            onMenuTap: _showMenu,
            onNotificationTap: _onNotificationsViewed,
            notificationCount: _notificationCount + _pendingJoinCount,
            userId: _authService.userId,
            nickname: null,
            teamName: null,
            country: null,
            // ✅ Pass the login modal trigger to the navbar
            onShowLoginModal: _showLoginModal,
          ),
          Expanded(
            child: Row(
              children: [
                const SizedBox(
                  width: 280,
                  child: WebProfilePanel(),
                ),
                Expanded(
                  child: MainContentTabs(
                    arenaContent: FixturesPage(
                      key: ValueKey(_fixturesPageKey),
                      userId: _authService.userId ?? '',
                      username: _authService.username ?? '',
                      authToken: _authService.authToken,
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
                      authToken: _authService.authToken,
                      scrollController: null,
                      onLogout: _handleLogout,
                      isLoggedIn: _isLoggedIn,
                    ),
                    logsContent: HistoryPage(
                      userId: _authService.userId ?? '',
                      username: _authService.username ?? '',
                      authToken: _authService.authToken,
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
}

// ============================================================================
// PENDING REQUESTS MODAL - SAME AS MOBILE
// ============================================================================

class PendingRequestsModal extends StatefulWidget {
  final String userId;
  final String username;
  final String? authToken;
  final List<UserChannel> userChannels;
  final VoidCallback onRequestProcessed;

  const PendingRequestsModal({
    super.key,
    required this.userId,
    required this.username,
    this.authToken,
    required this.userChannels,
    required this.onRequestProcessed,
  });

  @override
  State<PendingRequestsModal> createState() => _PendingRequestsModalState();
}

class _PendingRequestsModalState extends State<PendingRequestsModal> {
  Map<String, List<Map<String, dynamic>>> _pendingRequests = {};
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _processingUserId;
  String? _processingChannelId;

  static const String API_BASE_URL = 'https://clash-api-m5mr.onrender.com/api';

  @override
  void initState() {
    super.initState();
    _fetchAllPendingRequests();
  }

  Future<void> _fetchAllPendingRequests() async {
    setState(() => _isLoading = true);

    try {
      final Map<String, List<Map<String, dynamic>>> allRequests = {};

      for (final channel in widget.userChannels) {
        final response = await http.get(
          Uri.parse(
              '$API_BASE_URL/channels/${channel.channelId}/pending-requests'),
          headers: {
            'Authorization': 'Bearer ${widget.authToken}',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List<dynamic> requests = data['pending_requests'] ?? [];

          if (requests.isNotEmpty) {
            allRequests[channel.channelId] = requests
                .map((r) => ({
                      'user_id': r['user_id']?.toString() ?? '',
                      'username': r['username']?.toString() ?? 'Unknown',
                      'requested_at': DateTime.tryParse(
                              r['requested_at']?.toString() ?? '') ??
                          DateTime.now(),
                    }))
                .toList();
          }
        }
      }

      setState(() {
        _pendingRequests = allRequests;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching pending requests: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approveRequest(
      String channelId, String userId, String username) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _processingUserId = userId;
      _processingChannelId = channelId;
    });

    try {
      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/channels/approve-request'),
            headers: {
              'Authorization': 'Bearer ${widget.authToken}',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'channel_id': channelId,
              'user_id': userId,
              'username': username,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _pendingRequests[channelId]
              ?.removeWhere((r) => r['user_id'] == userId);
          if (_pendingRequests[channelId]?.isEmpty ?? false) {
            _pendingRequests.remove(channelId);
          }
        });

        widget.onRequestProcessed();
      }
    } catch (e) {
      // Approve failed
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingUserId = null;
          _processingChannelId = null;
        });
      }
    }
  }

  Future<void> _rejectRequest(
      String channelId, String userId, String username) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _processingUserId = userId;
      _processingChannelId = channelId;
    });

    try {
      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/channels/reject-request'),
            headers: {
              'Authorization': 'Bearer ${widget.authToken}',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'channel_id': channelId,
              'user_id': userId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _pendingRequests[channelId]
              ?.removeWhere((r) => r['user_id'] == userId);
          if (_pendingRequests[channelId]?.isEmpty ?? false) {
            _pendingRequests.remove(channelId);
          }
        });

        widget.onRequestProcessed();
      }
    } catch (e) {
      // Reject failed
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingUserId = null;
          _processingChannelId = null;
        });
      }
    }
  }

  int get _totalPendingCount {
    int count = 0;
    for (final requests in _pendingRequests.values) {
      count += requests.length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      decoration: BoxDecoration(
        color: FanColors.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(FanRadius.xl),
          topRight: Radius.circular(FanRadius.xl),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: FanColors.border.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: FanColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(Icons.person_add,
                        size: 22, color: FanColors.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Join Requests',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$_totalPendingCount request${_totalPendingCount > 1 ? 's' : ''} pending',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: FanColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.close, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: FanColors.border),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _pendingRequests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 48, color: FanColors.textSecondary),
                            const SizedBox(height: 12),
                            Text(
                              'No pending requests',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'All join requests have been processed',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: _pendingRequests.entries.map((entry) {
                          final channelId = entry.key;
                          final requests = entry.value;

                          final channel = widget.userChannels.firstWhere(
                            (c) => c.channelId == channelId,
                            orElse: () => UserChannel(
                                channelId: '',
                                name: 'Unknown',
                                memberCount: 0,
                                season: ''),
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: FanColors.primary
                                            .withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          channel.name.isNotEmpty
                                              ? channel.name[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: FanColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      channel.name.isNotEmpty
                                          ? channel.name
                                          : 'Unknown Channel',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: FanColors.primary
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${requests.length}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: FanColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...requests.map((request) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: FanColors.surface,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: FanColors.primary
                                                .withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              request['username']?[0]
                                                      ?.toUpperCase() ??
                                                  '?',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: FanColors.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                request['username'],
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                DateHelper.formatTimeAgo(
                                                    request['requested_at']),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.4),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            GestureDetector(
                                              onTap: _isProcessing
                                                  ? null
                                                  : () => _rejectRequest(
                                                      channelId,
                                                      request['user_id'],
                                                      request['username']),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: FanColors.away
                                                      .withValues(alpha: 0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.close_rounded,
                                                  size: 18,
                                                  color: FanColors.away,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: _isProcessing
                                                  ? null
                                                  : () => _approveRequest(
                                                      channelId,
                                                      request['user_id'],
                                                      request['username']),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: FanColors.secondary
                                                      .withValues(alpha: 0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.check_rounded,
                                                  size: 18,
                                                  color: FanColors.secondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  )),
                              const SizedBox(height: 8),
                              Divider(height: 1, color: FanColors.border),
                            ],
                          );
                        }).toList(),
                      ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    border: Border.all(color: FanColors.border, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DATE HELPER
// ============================================================================

class DateHelper {
  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }
}
