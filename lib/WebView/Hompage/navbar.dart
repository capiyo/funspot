// lib/widgets/web_navbar.dart
import 'package:flutter/material.dart';
import '../../pages/fan_Funzy_design.dart';
import '../../models/user_channel.dart';

/// Funspot brand gradient — deep emerald → jade → gold accent.
class FunspotGradients {
  static const List<Color> navbar = [
    Color(0xFF0B3D2E),
    Color(0xFF10583F),
    Color(0xFF1C7A52),
  ];

  static const List<Color> logo = [
    Color(0xFF34D399),
    Color(0xFF059669),
    Color(0xFF065F46),
  ];

  static const List<Color> gold = [
    Color(0xFFFFE08A),
    Color(0xFFF5B841),
    Color(0xFFD68F0E),
  ];

  static const List<Color> avatarRing = [
    Color(0xFF34D399),
    Color(0xFFFFD166),
  ];
}

class WebNavbar extends StatelessWidget {
  final bool isLoggedIn;
  final List<UserChannel> userChannels;
  final List<UserChannel> allChannels;
  final String? selectedChannelId;
  final Set<String> joiningChannelIds;
  final int maxChannels;

  final ValueChanged<UserChannel> onChannelSelected;
  final ValueChanged<UserChannel> onJoinChannel;
  final VoidCallback onCreateChannel;

  final VoidCallback onMenuTap;
  final VoidCallback onNotificationTap;
  final int notificationCount;

  const WebNavbar({
    super.key,
    required this.isLoggedIn,
    required this.userChannels,
    required this.allChannels,
    this.selectedChannelId,
    this.joiningChannelIds = const {},
    this.maxChannels = 3,
    required this.onChannelSelected,
    required this.onJoinChannel,
    required this.onCreateChannel,
    required this.onMenuTap,
    required this.onNotificationTap,
    this.notificationCount = 0,
  });

  bool get _hasChannels => userChannels.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: FunspotGradients.navbar,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        border: const Border(
          bottom: BorderSide(
            color: Color(0x33FFD166),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _buildLogo(),
          const SizedBox(width: 32),
          _buildSearch(),
          const SizedBox(width: 24),
          Expanded(child: _buildChannelSection(context)),
          const SizedBox(width: 16),
          _buildNotificationIcon(),
          const SizedBox(width: 16),
          _buildAvatar(),
        ],
      ),
    );
  }

  // ==========================================================================
  // LOGO — circular with border
  // ==========================================================================
  Widget _buildLogo() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1,
            ),
          ),
          child: const CircleAvatar(
            backgroundColor: Color(0xFF0B3D2E),
            child: Icon(
              Icons.sports_soccer,
              color: Color(0xFF34D399),
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFDFF7EA)],
          ).createShader(bounds),
          child: const Text(
            'Funspot',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: FunspotGradients.gold,
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF5B841).withValues(alpha: 0.4),
                blurRadius: 6,
              ),
            ],
          ),
          child: const Text(
            'BETA',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0B3D2E),
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // CHANNEL SECTION
  // ==========================================================================
  Widget _buildChannelSection(BuildContext context) {
    if (!isLoggedIn || !_hasChannels) {
      return _buildBrowseChannels(context);
    }
    return _buildMemberChannels(context);
  }

  Widget _buildBrowseChannels(BuildContext context) {
    final displayChannels = allChannels.isNotEmpty ? allChannels : userChannels;

    if (displayChannels.isEmpty) {
      return Text(
        'No channels available',
        style: FanTypography.caption.copyWith(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 12,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...displayChannels.map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildJoinChip(context, c),
              )),
          _buildCreateChip(),
        ],
      ),
    );
  }

  Widget _buildJoinChip(BuildContext context, UserChannel channel) {
    final bool isJoining = joiningChannelIds.contains(channel.channelId);

    return GestureDetector(
      onTap: () => onJoinChannel(channel),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              channel.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            isJoining
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation(Color(0xFF34D399)),
                    ),
                  )
                : const Text(
                    'join',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6EE7B7),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberChannels(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...userChannels.map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
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

    return GestureDetector(
      onTap: () => onChannelSelected(channel),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (channel.isAdmin) ...[
              const Text('👑', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
            ],
            Text(
              channel.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF6EE7B7) : Colors.white,
                decoration: isSelected ? TextDecoration.underline : null,
              ),
            ),
            if (leader != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: FunspotGradients.gold),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${leader.username} (${leader.seasonPoints}pts)',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0B3D2E),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCreateChip() {
    final bool isFull = userChannels.length >= maxChannels;
    return GestureDetector(
      onTap: isFull ? null : onCreateChannel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(
          Icons.add_rounded,
          size: 17,
          color: isFull
              ? Colors.white.withValues(alpha: 0.25)
              : const Color(0xFF6EE7B7),
        ),
      ),
    );
  }

  // ==========================================================================
  // SEARCH
  // ==========================================================================
  Widget _buildSearch() {
    return Container(
      width: 200,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 0.7,
        ),
      ),
      child: TextField(
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: 'Search...',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  // ==========================================================================
  // NOTIFICATIONS — plain bell icon
  // ==========================================================================
  Widget _buildNotificationIcon() {
    return GestureDetector(
      onTap: onNotificationTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 24,
            color: Colors.white,
          ),
          if (notificationCount > 0)
            Positioned(
              top: -4,
              right: -6,
              child: Container(
                padding: const EdgeInsets.all(3),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  notificationCount > 99 ? '99+' : notificationCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
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
  // AVATAR — circular with border, loads account image
  // ==========================================================================
  Widget _buildAvatar() {
    return GestureDetector(
      onTap: onMenuTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
            width: 1,
          ),
        ),
        child: CircleAvatar(
          backgroundColor: const Color(0xFF0B3D2E),
          backgroundImage: isLoggedIn
              ? const NetworkImage('https://i.pravatar.cc/150?img=1')
              : null,
          child: !isLoggedIn
              ? const Icon(
                  Icons.person_outline,
                  color: Colors.white,
                  size: 20,
                )
              : null,
        ),
      ),
    );
  }
}
