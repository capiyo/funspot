// lib/widgets/web_navbar.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../pages/fan_Funzy_design.dart';
import '../../models/user_channel.dart';

/// Shared tappable wrapper for navbar interactions
class _WebTappable extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;

  const _WebTappable({
    required this.onTap,
    this.onLongPress,
    required this.child,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(8);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: radius,
        splashColor: FanColors.primary.withValues(alpha: 0.18),
        highlightColor: FanColors.primary.withValues(alpha: 0.08),
        hoverColor: FanColors.textPrimary.withValues(alpha: 0.06),
        mouseCursor:
            onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class WebNavbar extends StatelessWidget {
  final bool isLoggedIn;
  final List<UserChannel> userChannels;
  final List<UserChannel> allChannels;
  final String? selectedChannelId;
  final Set<String> joiningChannelIds;

  @Deprecated('The 3-channel limit was removed; this value is now ignored.')
  final int maxChannels;

  final ValueChanged<UserChannel> onChannelSelected;
  final ValueChanged<UserChannel> onJoinChannel;
  final VoidCallback onCreateChannel;

  final VoidCallback onMenuTap;
  final VoidCallback onNotificationTap;
  final int notificationCount;
  final Set<String> pendingChannelIds;

  final String? userId;
  final String? nickname;
  final String? teamName;
  final String? country;

  final ValueChanged<UserChannel>? onOpenChat;
  final ValueChanged<UserChannel>? onOpenLeaderboard;
  final VoidCallback? onShowLoginModal;

  const WebNavbar({
    super.key,
    required this.isLoggedIn,
    required this.userChannels,
    required this.allChannels,
    this.selectedChannelId,
    this.joiningChannelIds = const {},
    @Deprecated('The 3-channel limit was removed; this value is now ignored.')
    this.maxChannels = 3,
    required this.onChannelSelected,
    required this.onJoinChannel,
    required this.onCreateChannel,
    required this.onMenuTap,
    required this.onNotificationTap,
    this.pendingChannelIds = const {},
    this.notificationCount = 0,
    this.userId,
    this.nickname,
    this.teamName,
    this.country,
    this.onOpenChat,
    this.onOpenLeaderboard,
    this.onShowLoginModal,
  });

  bool get _hasProfileInfo =>
      (nickname != null && nickname!.isNotEmpty) ||
      (teamName != null && teamName!.isNotEmpty) ||
      (country != null && country!.isNotEmpty);

  Set<String> get _memberChannelIds =>
      userChannels.map((c) => c.channelId).toSet();

  static const List<int> _avatarPool = [
    1,
    3,
    5,
    7,
    8,
    11,
    12,
    14,
    15,
    16,
    18,
    22,
    25,
    28,
    32,
    33,
    36,
    41,
    44,
    47,
  ];

  String _avatarUrlFor(String? id) {
    final key = (id == null || id.isEmpty) ? 'guest' : id;
    final index = key.hashCode.abs() % _avatarPool.length;
    final imgNumber = _avatarPool[index];
    return 'https://i.pravatar.cc/150?img=$imgNumber';
  }

  @override
  Widget build(BuildContext context) {
    // ✅ History page coloring - surfaceElevated background, clean text
    return Container(
      height: 48,
      color: FanColors.surfaceElevated,
      child: Row(
        children: [
          const SizedBox(width: 18),

          // 1. App name / logo
          _buildLogo(),
          const SizedBox(width: 16),

          if (isLoggedIn && _hasProfileInfo) ...[
            _buildProfileInfo(),
            const SizedBox(width: 16),
          ],

          // 2. All channels - clean text display (no carousel)
          _buildChannelDisplay(),

          const Spacer(),

          // 3. Search - minimal underline
          _buildSearch(),
          const SizedBox(width: 12),

          // 4. User's channels
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: _buildUserChannels(),
          ),
          const SizedBox(width: 12),

          _buildNotificationIcon(),
          const SizedBox(width: 12),
          _buildAvatar(),
          const SizedBox(width: 18),
        ],
      ),
    );
  }

  // ==========================================================================
  // HANDLE JOIN
  // ==========================================================================
  void _handleJoinChannel(UserChannel channel) {
    if (!isLoggedIn) {
      onShowLoginModal?.call();
      return;
    }
    onJoinChannel(channel);
  }

  // ==========================================================================
  // LOGO - Simple with gradient ring
  // ==========================================================================
  Widget _buildLogo() {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          padding: const EdgeInsets.all(1.6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6EE7B7),
                Color(0xFF34D399),
                Color(0xFF059669),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF34D399).withValues(alpha: 0.45),
                blurRadius: 10,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: ClipOval(
            child: Container(
              color: const Color(0xFF07291E),
              padding: const EdgeInsets.all(4.5),
              child: Image.asset(
                'assets/icons/funspot.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.sports_soccer,
                  color: Color(0xFF6EE7B7),
                  size: 15,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFE3FBEF)],
          ).createShader(bounds),
          child: const Text(
            'Funspot',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.2,
              height: 1,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(left: 7),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFE9A8),
                Color(0xFFF5B841),
                Color(0xFFD68F0E),
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF5B841).withValues(alpha: 0.55),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Text(
            'BETA',
            style: TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0B3D2E),
              letterSpacing: 1.1,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // PROFILE INFO - Clean text, no background
  // ==========================================================================
  Widget _buildProfileInfo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (nickname != null && nickname!.isNotEmpty)
          _buildProfileInfoItem(
            icon: Icons.shield_rounded,
            value: nickname!,
          ),
        if (teamName != null && teamName!.isNotEmpty) ...[
          _buildProfileInfoDivider(),
          _buildProfileInfoItem(
            icon: Icons.sports_soccer_rounded,
            value: teamName!,
          ),
        ],
        if (country != null && country!.isNotEmpty) ...[
          _buildProfileInfoDivider(),
          _buildProfileInfoItem(
            icon: Icons.flag_rounded,
            value: country!,
          ),
        ],
      ],
    );
  }

  Widget _buildProfileInfoItem({
    required IconData icon,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: FanColors.textTertiary),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 100),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: FanColors.textSecondary,
              height: 1,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfoDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 9),
      width: 1,
      height: 14,
      color: FanColors.border.withValues(alpha: 0.3),
    );
  }

  // ==========================================================================
  // CHANNEL DISPLAY - Clean text, no backgrounds
  // ==========================================================================
  Widget _buildChannelDisplay() {
    if (!isLoggedIn) {
      return Text(
        'Browse channels',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: FanColors.textTertiary,
          height: 1,
        ),
      );
    }

    if (allChannels.isEmpty) {
      return Text(
        'No channels available',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: FanColors.textTertiary,
          height: 1,
        ),
      );
    }

    final displayChannels = allChannels.take(3).toList();
    final hasMore = allChannels.length > 3;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...displayChannels.map((channel) {
          final isMember = _memberChannelIds.contains(channel.channelId);
          final isJoining = joiningChannelIds.contains(channel.channelId);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    onChannelSelected(channel);
                    onOpenChat?.call(channel);
                  },
                  child: Text(
                    channel.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isMember ? FontWeight.w600 : FontWeight.w400,
                      color: isMember
                          ? FanColors.primary
                          : FanColors.textSecondary,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                if (isMember)
                  Icon(
                    Icons.circle,
                    size: 4,
                    color: FanColors.primary,
                  )
                else if (!isJoining)
                  GestureDetector(
                    onTap: () {
                      if (!isLoggedIn) {
                        onShowLoginModal?.call();
                        return;
                      }
                      onJoinChannel(channel);
                    },
                    child: Text(
                      '+',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: FanColors.primary,
                        height: 1,
                      ),
                    ),
                  ),
                if (isJoining)
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                    ),
                  ),
              ],
            ),
          );
        }),
        if (hasMore)
          Text(
            '+${allChannels.length - 3}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: FanColors.textTertiary,
              height: 1,
            ),
          ),
      ],
    );
  }

  // ==========================================================================
  // USER'S CHANNELS - Clean text, no backgrounds
  // ==========================================================================
  Widget _buildUserChannels() {
    if (!isLoggedIn) {
      return const SizedBox.shrink();
    }

    if (userChannels.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No channels joined',
            style: TextStyle(
              color: FanColors.textTertiary,
              fontSize: 11,
              height: 1,
            ),
          ),
          const SizedBox(width: 8),
          _buildCreateChip(),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Row(
        children: [
          ...userChannels.map((c) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _buildMemberChip(c),
              )),
          _buildCreateChip(),
        ],
      ),
    );
  }

  Widget _buildMemberChip(UserChannel channel) {
    final bool isSelected = selectedChannelId != null
        ? selectedChannelId == channel.channelId
        : (userChannels.isNotEmpty &&
            channel.channelId == userChannels.first.channelId);

    final sortedMembers = List<ChannelMember>.from(channel.members)
      ..sort((a, b) => b.seasonPoints.compareTo(a.seasonPoints));
    final leader = sortedMembers.isNotEmpty ? sortedMembers.first : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (channel.isAdmin) ...[
          const Text('👑', style: TextStyle(fontSize: 10)),
          const SizedBox(width: 2),
        ],
        _WebTappable(
          onTap: () {
            onChannelSelected(channel);
            onOpenChat?.call(channel);
          },
          borderRadius: BorderRadius.circular(8),
          padding: EdgeInsets.symmetric(
            horizontal: channel.isAdmin ? 4 : 8,
            vertical: 5,
          ),
          child: Text(
            channel.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? FanColors.primary : FanColors.textPrimary,
              letterSpacing: -0.1,
              height: 1,
            ),
          ),
        ),
        if (leader != null) ...[
          const SizedBox(width: 2),
          _WebTappable(
            onTap: () => onOpenLeaderboard?.call(channel),
            borderRadius: BorderRadius.circular(7),
            padding: const EdgeInsets.only(right: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFE9A8),
                    Color(0xFFF5B841),
                    Color(0xFFD68F0E),
                  ],
                ),
                borderRadius: BorderRadius.circular(7),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF5B841).withValues(alpha: 0.35),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      size: 9, color: Color(0xFF0B3D2E)),
                  const SizedBox(width: 3),
                  Text(
                    '${leader.username} · ${leader.seasonPoints}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0B3D2E),
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCreateChip() {
    return _WebTappable(
      onTap: onCreateChannel,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(2),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: FanColors.primary.withValues(alpha: 0.08),
          border: Border.all(
            color: FanColors.primary.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: Icon(
          Icons.add_rounded,
          size: 15,
          color: FanColors.primary,
        ),
      ),
    );
  }

  // ==========================================================================
  // SEARCH - Minimal underline style
  // ==========================================================================
  Widget _buildSearch() {
    return Container(
      width: 168,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: FanColors.border.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: TextField(
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12.5,
          color: FanColors.textPrimary,
          height: 1,
        ),
        cursorColor: FanColors.primary,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search…',
          hintStyle: TextStyle(
            color: FanColors.textTertiary,
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
            height: 1,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 16,
            color: FanColors.textTertiary,
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 32, minHeight: 16),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  // ==========================================================================
  // NOTIFICATIONS
  // ==========================================================================
  Widget _buildNotificationIcon() {
    final bool hasNotifications = notificationCount > 0;
    return _WebTappable(
      onTap: onNotificationTap,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(6),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            hasNotifications
                ? Icons.notifications_rounded
                : Icons.notifications_none_rounded,
            size: 19,
            color:
                hasNotifications ? FanColors.primary : FanColors.textSecondary,
          ),
          if (hasNotifications)
            Positioned(
              top: -3,
              right: -5,
              child: Container(
                padding: const EdgeInsets.all(3),
                constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFE0303A)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: FanColors.surfaceElevated,
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE0303A).withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  notificationCount > 99 ? '99+' : notificationCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // AVATAR
  // ==========================================================================
  Widget _buildAvatar() {
    return _WebTappable(
      onTap: onMenuTap,
      borderRadius: BorderRadius.circular(19),
      padding: const EdgeInsets.all(1),
      child: Container(
        width: 32,
        height: 32,
        padding: const EdgeInsets.all(1.8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6EE7B7),
              Color(0xFFFFD166),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD166).withValues(alpha: 0.35),
              blurRadius: 8,
            ),
          ],
        ),
        child: ClipOval(
          child: isLoggedIn
              ? Image.network(
                  _avatarUrlFor(userId),
                  fit: BoxFit.cover,
                  width: 28,
                  height: 28,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: FanColors.surfaceElevated,
                      child: const Center(
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: FanColors.surfaceElevated,
                    child: Icon(
                      Icons.person_rounded,
                      color: FanColors.textTertiary,
                      size: 15,
                    ),
                  ),
                )
              : Container(
                  color: FanColors.surfaceElevated,
                  child: Icon(
                    Icons.person_rounded,
                    color: FanColors.textTertiary,
                    size: 15,
                  ),
                ),
        ),
      ),
    );
  }
}
