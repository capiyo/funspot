// lib/widgets/web_navbar.dart
import 'package:flutter/material.dart';
import '../../pages/fan_Funzy_design.dart';
import '../../models/user_channel.dart';

/// Funspot brand gradient — deep emerald → jade → gold accent.
/// Gives the navbar a premium, "podium" feel (olympiad-inspired)
/// while staying rooted in the Funspot green identity.
class FunspotGradients {
  static const List<Color> navbar = [
    Color(0xFF0B3D2E), // deep forest
    Color(0xFF10583F), // emerald
    Color(0xFF1C7A52), // jade
  ];

  static const List<Color> logo = [
    Color(0xFF34D399), // mint
    Color(0xFF059669), // emerald
    Color(0xFF065F46), // deep green
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

  // Channels the user actually belongs to.
  final List<UserChannel> userChannels;

  // Browsable channels (only relevant when logged out, or channels < max).
  final List<UserChannel> allChannels;

  final String? selectedChannelId;
  final Set<String> joiningChannelIds;
  final int maxChannels;

  final ValueChanged<UserChannel>
      onChannelSelected; // logged-in tap -> leaderboard/select
  final ValueChanged<UserChannel>
      onJoinChannel; // logged-out / not-yet-member tap -> join
  final VoidCallback onCreateChannel; // "+" chip

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
            color: Color(0x33FFD166), // faint gold hairline — podium accent
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _buildLogo(),
          const SizedBox(width: 32),
          Expanded(child: _buildChannelSection(context)),
          const SizedBox(width: 24),
          _buildSearch(),
          const SizedBox(width: 20),
          _buildNotificationIcon(),
          const SizedBox(width: 16),
          _buildAvatar(),
        ],
      ),
    );
  }

  // ==========================================================================
  // LOGO
  // ==========================================================================
  Widget _buildLogo() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: FunspotGradients.logo,
            ),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: const Color(0xFFFFD166).withValues(alpha: 0.55),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF34D399).withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'F',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
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
  // CHANNEL SECTION — mirrors HomePage._buildRow2Content()
  // ==========================================================================
  Widget _buildChannelSection(BuildContext context) {
    // Case 1: not logged in, OR logged in with zero channels -> browse + join
    if (!isLoggedIn || !_hasChannels) {
      return _buildBrowseChannels(context);
    }
    // Case 2: logged in with channels -> show membership, leaders, selection
    return _buildMemberChannels(context);
  }

  // ---- Case 1: browse/join, same source list as HomePage._buildAllChannelsWithJoin ----
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
            width: 0.7,
          ),
        ),
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

  // ---- Case 2: member channels, same source as HomePage._buildLoggedInWithChannels ----
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x4034D399), Color(0x40059669)],
                )
              : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6EE7B7).withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.14),
            width: isSelected ? 1.2 : 0.7,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF34D399).withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
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
                fontWeight: FontWeight.w700,
                color: isSelected ? const Color(0xFF6EE7B7) : Colors.white,
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
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: isFull ? 0.15 : 0.35),
            width: 0.8,
          ),
          color: Colors.white.withValues(alpha: 0.06),
        ),
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
  // NOTIFICATIONS — chat-bubble style, green accent
  // ==========================================================================
  Widget _buildNotificationIcon() {
    return GestureDetector(
      onTap: onNotificationTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF34D399).withValues(alpha: 0.18),
                  const Color(0xFF059669).withValues(alpha: 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF6EE7B7).withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: const Icon(
              Icons.chat_bubble_rounded,
              size: 19,
              color: Color(0xFF6EE7B7),
            ),
          ),
          if (notificationCount > 0)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: FunspotGradients.gold),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF0B3D2E),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF5B841).withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  notificationCount > 99 ? '99+' : notificationCount.toString(),
                  style: const TextStyle(
                    color: Color(0xFF0B3D2E),
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
  // AVATAR — medal-ring style
  // ==========================================================================
  Widget _buildAvatar() {
    return GestureDetector(
      onTap: onMenuTap,
      child: Container(
        width: 42,
        height: 42,
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: FunspotGradients.avatarRing, // mint -> gold ring
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: FunspotGradients.logo,
            ),
          ),
          child: Center(
            child: Icon(
              isLoggedIn ? Icons.person_rounded : Icons.login_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}