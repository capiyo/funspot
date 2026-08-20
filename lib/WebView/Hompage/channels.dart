import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../main.dart'; // FanColors / FanTypography / FanRadius / AppCache
import '../../models/user_channel.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import "../../pages/fan_Funzy_design.dart";

// ============================================================================
// SMALL TOAST HELPER - LOCAL TO THIS FILE (avoids importing home_page.dart)
// ============================================================================
class ChannelToast {
  static void show(
    BuildContext context,
    String message, {
    Color? color,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? FanColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ============================================================================
// CHANNELS SERVICE - MIRRORS THE FETCH/CACHE LOGIC FROM HomePage
// ============================================================================
//
// Rules for what gets displayed:
//  - Not logged in            -> fetch & show up to TARGET_DISPLAY_COUNT
//                                 browsable channels to join.
//  - Logged in, 0-2 channels  -> show the user's joined channels PLUS enough
//                                 browsable (not-yet-joined) channels to reach
//                                 TARGET_DISPLAY_COUNT total.
//  - Logged in, MAX_CHANNELS  -> show only the user's joined channels
//    (i.e. 3) joined            (they're full, nothing to browse).
// ============================================================================
class ChannelsService {
  static const String API_BASE_URL = 'https://clash-api-m5mr.onrender.com/api';
  static const int MAX_CHANNELS = 3;
  static const int TARGET_DISPLAY_COUNT = 5;

  /// Loads the user's joined channels, going through AppCache exactly like
  /// HomePage does: show whatever's cached instantly, then revalidate.
  static Future<List<UserChannel>> fetchJoinedChannels(
    String userId,
    String? authToken,
  ) async {
    if (userId.isEmpty) return [];

    // Cached copy first (instant).
    List<UserChannel> cached = List<UserChannel>.from(AppCache.channels);

    // Revalidate against the network (single source of truth after this).
    try {
      await AppCache.refreshChannels(userId, authToken);
      return List<UserChannel>.from(AppCache.channels);
    } catch (e) {
      debugPrint('⚠️ Failed to refresh channels, falling back to cache: $e');
      return cached;
    }
  }

  /// Fetches channels available to browse/join, excluding any the user is
  /// already a member of. Mirrors HomePage's `_fetchAllChannelsForBrowsing`.
  static Future<List<UserChannel>> fetchBrowsableChannels({
    String? authToken,
    Set<String> excludeIds = const {},
    int limit = TARGET_DISPLAY_COUNT,
  }) async {
    try {
      final headers = {'Content-Type': 'application/json'};
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
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

        return fetched.take(limit).toList();
      }

      debugPrint(
          '⚠️ Failed to fetch browsable channels: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ Error fetching browsable channels: $e');
    }

    // Fallback: best-effort from AppCache, still excluding joined ones.
    return AppCache.channels
        .where((c) => !excludeIds.contains(c.channelId))
        .take(limit)
        .toList();
  }

  /// The single entry point the page calls. Applies the three rules above.
  static Future<ChannelsDisplayResult> resolveChannelsToDisplay({
    required bool isLoggedIn,
    required String userId,
    String? authToken,
  }) async {
    // Rule: not logged in -> just show browsable channels to join.
    if (!isLoggedIn || userId.isEmpty) {
      final browsable = await fetchBrowsableChannels(
        authToken: authToken,
        excludeIds: const {},
        limit: TARGET_DISPLAY_COUNT,
      );
      return ChannelsDisplayResult(
        joined: const [],
        browsable: browsable,
        isFull: false,
      );
    }

    final joined = await fetchJoinedChannels(userId, authToken);

    // Rule: already in MAX_CHANNELS -> only show those, nothing to browse.
    if (joined.length >= MAX_CHANNELS) {
      return ChannelsDisplayResult(
        joined: joined.take(MAX_CHANNELS).toList(),
        browsable: const [],
        isFull: true,
      );
    }

    // Rule: 0-2 joined -> fill the remainder with browsable channels.
    final needed = TARGET_DISPLAY_COUNT - joined.length;
    final joinedIds = joined.map((c) => c.channelId).toSet();
    final browsable = await fetchBrowsableChannels(
      authToken: authToken,
      excludeIds: joinedIds,
      limit: needed,
    );

    return ChannelsDisplayResult(
      joined: joined,
      browsable: browsable,
      isFull: false,
    );
  }

  static Future<bool> requestJoinChannel({
    required UserChannel channel,
    required String userId,
    required String username,
    String? nickname,
    required String? authToken,
  }) async {
    if (authToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/channels/request-join'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'channel_id': channel.channelId,
          'user_id': userId,
          'username': username,
          'user_nickname': nickname ?? username,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Error requesting to join channel: $e');
      return false;
    }
  }
}

class ChannelsDisplayResult {
  final List<UserChannel> joined;
  final List<UserChannel> browsable;
  final bool isFull;

  const ChannelsDisplayResult({
    required this.joined,
    required this.browsable,
    required this.isFull,
  });

  List<UserChannel> get combined => [...joined, ...browsable];
}

// ============================================================================
// CHANNELS PAGE
// ============================================================================
class ChannelsPage extends StatefulWidget {
  final void Function(UserChannel channel)? onChannelSelected;
  final void Function(UserChannel channel)? onOpenChat;

  const ChannelsPage({
    super.key,
    this.onChannelSelected,
    this.onOpenChat,
  });

  @override
  State<ChannelsPage> createState() => _ChannelsPageState();
}

class _ChannelsPageState extends State<ChannelsPage> {
  late final AuthService _authService;

  bool _isLoading = true;
  bool _isFull = false;
  List<UserChannel> _joinedChannels = [];
  List<UserChannel> _browsableChannels = [];
  final Set<String> _pendingChannelIds = {};
  final Set<String> _requestingChannelIds = {};

  bool get _isLoggedIn => _authService.isLoggedIn;
  String get _userId => _authService.userId ?? '';
  String get _username => _authService.username ?? '';
  String? get _authToken => _authService.authToken;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _authService.addListener(_onAuthChanged);
    _loadPendingRequests();
    _loadChannels();
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    _loadPendingRequests();
    _loadChannels();
  }

  Future<void> _loadPendingRequests() async {
    try {
      final requests = await NotificationService.getPendingJoinRequests();
      if (!mounted) return;
      setState(() {
        _pendingChannelIds
          ..clear()
          ..addAll(
            requests
                .map((r) => r['channel_id']?.toString())
                .whereType<String>(),
          );
      });
    } catch (e) {
      debugPrint('Failed to load pending join requests: $e');
    }
  }

  Future<void> _loadChannels() async {
    if (mounted) setState(() => _isLoading = true);

    final result = await ChannelsService.resolveChannelsToDisplay(
      isLoggedIn: _isLoggedIn,
      userId: _userId,
      authToken: _authToken,
    );

    if (!mounted) return;
    setState(() {
      _joinedChannels = result.joined;
      _browsableChannels = result.browsable;
      _isFull = result.isFull;
      _isLoading = false;
    });
  }

  Future<void> _handleJoin(UserChannel channel) async {
    if (!_isLoggedIn) {
      ChannelToast.show(context, 'Please log in to join a channel');
      return;
    }
    if (_joinedChannels.length >= ChannelsService.MAX_CHANNELS) {
      ChannelToast.show(
        context,
        'You already have ${ChannelsService.MAX_CHANNELS} channels',
        color: FanColors.away,
      );
      return;
    }
    if (_requestingChannelIds.contains(channel.channelId)) return;

    setState(() => _requestingChannelIds.add(channel.channelId));

    final success = await ChannelsService.requestJoinChannel(
      channel: channel,
      userId: _userId,
      username: _username,
      authToken: _authToken,
    );

    if (!mounted) return;
    setState(() {
      _requestingChannelIds.remove(channel.channelId);
      if (success) _pendingChannelIds.add(channel.channelId);
    });

    ChannelToast.show(
      context,
      success
          ? 'Join request sent to "${channel.name}"'
          : 'Failed to send join request',
      color: success ? FanColors.primary : FanColors.away,
    );
  }

  Future<void> _handleRefresh() async {
    await _loadPendingRequests();
    await _loadChannels();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FanColors.background,
      appBar: AppBar(
        backgroundColor: FanColors.surfaceElevated,
        elevation: 0,
        title: Text(
          'Channels',
          style: FanTypography.headline.copyWith(fontSize: 17),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final hasJoined = _joinedChannels.isNotEmpty;
    final hasBrowsable = _browsableChannels.isNotEmpty;

    if (!hasJoined && !hasBrowsable) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          Icon(Icons.group_off, size: 48, color: FanColors.textSecondary),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'No channels available',
              style:
                  FanTypography.body.copyWith(color: FanColors.textSecondary),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (hasJoined) ...[
          _sectionHeader(
            _isFull ? 'Your Channels (Full)' : 'Your Channels',
          ),
          const SizedBox(height: 8),
          ..._joinedChannels.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildChannelTile(c, isJoined: true),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (hasBrowsable) ...[
          _sectionHeader('Discover Channels'),
          const SizedBox(height: 8),
          ..._browsableChannels.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildChannelTile(c, isJoined: false),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: FanTypography.body.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: FanColors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildChannelTile(UserChannel channel, {required bool isJoined}) {
    final isPending = _pendingChannelIds.contains(channel.channelId);
    final isRequesting = _requestingChannelIds.contains(channel.channelId);
    final isAdmin = channel.isAdmin;

    final sortedMembers = List<ChannelMember>.from(channel.members)
      ..sort((a, b) => b.seasonPoints.compareTo(a.seasonPoints));
    final topMember = sortedMembers.isNotEmpty ? sortedMembers.first : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FanColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: FanColors.border.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A3E),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                channel.name.isNotEmpty ? channel.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: FanColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        channel.name,
                        style: FanTypography.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: FanColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 4),
                      const Text('👑', style: TextStyle(fontSize: 11)),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.people,
                        size: 11, color: FanColors.textSecondary),
                    const SizedBox(width: 3),
                    Text(
                      '${channel.memberCount} members',
                      style: FanTypography.tag.copyWith(
                        fontSize: 11,
                        color: FanColors.textSecondary,
                      ),
                    ),
                    if (topMember != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.emoji_events,
                          size: 11, color: const Color(0xFFFFD700)),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          '${topMember.username} (${topMember.seasonPoints}pts)',
                          style: FanTypography.tag.copyWith(
                            fontSize: 11,
                            color: FanColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            channel: channel,
            isJoined: isJoined,
            isPending: isPending,
            isRequesting: isRequesting,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required UserChannel channel,
    required bool isJoined,
    required bool isPending,
    required bool isRequesting,
  }) {
    if (isJoined) {
      return GestureDetector(
        onTap: () {
          widget.onChannelSelected?.call(channel);
          widget.onOpenChat?.call(channel);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: FanColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'chat',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: FanColors.primary,
            ),
          ),
        ),
      );
    }

    if (isPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: FanColors.draw.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'pending',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: FanColors.textSecondary,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: isRequesting ? null : () => _handleJoin(channel),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0B1E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: isRequesting
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: FanColors.primary,
                ),
              )
            : Text(
                'join',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: FanColors.primary,
                ),
              ),
      ),
    );
  }
}
