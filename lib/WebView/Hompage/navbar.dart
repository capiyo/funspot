// lib/widgets/web_navbar.dart
import 'dart:async';
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

/// ✅ Shared tappable wrapper used everywhere in this navbar.
///
/// Flutter Web can silently drop taps on a bare `GestureDetector` when it
/// wraps non-opaque children (Row/Icon/Text with transparent backgrounds)
/// inside horizontally-scrolling ancestors — the gesture arena resolves
/// to the scroll view instead of the tap. Wrapping every interactive
/// element in `Material` + `InkWell` (with `HitTestBehavior.opaque` via
/// the `onTap` always being attached directly to `InkWell`, which uses
/// its own opaque `_InkResponseState` hit test) fixes this reliably, and
/// also gives free hover/click cursor + ripple feedback on web/desktop.
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
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

  // NOTE: the old 3-channel cap has been removed per product decision —
  // users can join/create as many channels as they like now. This field
  // is kept (unused) only so existing call sites that still pass
  // `maxChannels:` don't break the build; feel free to delete both the
  // field and the callers' argument once every call site is updated.
  @Deprecated('The 3-channel limit was removed; this value is now ignored.')
  final int maxChannels;

  final ValueChanged<UserChannel> onChannelSelected;
  final ValueChanged<UserChannel> onJoinChannel;
  final VoidCallback onCreateChannel;

  final VoidCallback onMenuTap;
  final VoidCallback onNotificationTap;
  final int notificationCount;

  // Identity used to pick a deterministic avatar photo.
  final String? userId;

  // Profile summary shown near the logo — sourced from UserData
  // (nickname / clubFan / countryFan) in the parent page.
  final String? nickname;
  final String? teamName;
  final String? country;

  // Tap channel name -> open chat. Tap leader badge -> open leaderboard.
  final ValueChanged<UserChannel>? onOpenChat;
  final ValueChanged<UserChannel>? onOpenLeaderboard;

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
    this.notificationCount = 0,
    this.userId,
    this.nickname,
    this.teamName,
    this.country,
    this.onOpenChat,
    this.onOpenLeaderboard,
  });

  bool get _hasProfileInfo =>
      (nickname != null && nickname!.isNotEmpty) ||
      (teamName != null && teamName!.isNotEmpty) ||
      (country != null && country!.isNotEmpty);

  Set<String> get _memberChannelIds =>
      userChannels.map((c) => c.channelId).toSet();

  // Pool of 20 placeholder avatar photo indices from pravatar.cc
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

  /// Deterministic pick so the same user always gets the same avatar
  /// (instead of a new random face on every rebuild).
  String _avatarUrlFor(String? id) {
    final key = (id == null || id.isEmpty) ? 'guest' : id;
    final index = key.hashCode.abs() % _avatarPool.length;
    final imgNumber = _avatarPool[index];
    return 'https://i.pravatar.cc/150?img=$imgNumber';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52, // slimmer bar (was 68)
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: FunspotGradients.navbar,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: const Border(
          bottom: BorderSide(
            color: Color(0x33FFD166),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16), // was 24
      child: Row(
        children: [
          // 1. App name / logo
          _buildLogo(),
          const SizedBox(width: 14),

          if (isLoggedIn && _hasProfileInfo) ...[
            _buildProfileInfo(),
            const SizedBox(width: 14),
          ],

          // 2. All-channels carousel — sized to its content (not stretched
          //    across the whole Row anymore), still auto-scrolls internally
          //    if it has more items than fit in the cap.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _ChannelCarousel(
              channels: allChannels,
              memberChannelIds: _memberChannelIds,
              joiningChannelIds: joiningChannelIds,
              onJoinChannel: onJoinChannel,
              onChannelTap: onChannelSelected,
            ),
          ),

          // ✅ Real spacer — absorbs whatever space is left so the entire
          // right-hand cluster (search, my channels, +, bell, avatar) stays
          // glued together and pinned flush against the right edge no
          // matter the screen width or how many carousel/channel chips
          // exist.
          const Spacer(),

          // 3. Search bar
          _buildSearch(),
          const SizedBox(width: 12),

          // 4. The user's own joined channels — capped so it can never
          //    push notification/avatar off-screen; scrolls internally.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: _buildUserChannels(context),
          ),
          const SizedBox(width: 12),

          _buildNotificationIcon(),
          const SizedBox(width: 12),
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
          width: 32, // was 42
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1,
            ),
          ),
          child: ClipOval(
            child: Container(
              color: const Color(0xFF0B3D2E),
              padding: const EdgeInsets.all(
                  5), // small inset so the mark doesn't touch the ring
              child: Image.asset(
                'assets/icons/funspot.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.sports_soccer,
                  color: Color(0xFF34D399),
                  size: 18,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10), // was 12
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFDFF7EA)],
          ).createShader(bounds),
          child: const Text(
            'Funspot',
            style: TextStyle(
              fontSize: 16, // was 21
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: FunspotGradients.gold,
            ),
            borderRadius: BorderRadius.circular(5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF5B841).withValues(alpha: 0.4),
                blurRadius: 5,
              ),
            ],
          ),
          child: const Text(
            'BETA',
            style: TextStyle(
              fontSize: 7, // was 8
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
  // PROFILE INFO — nickname / team / country
  // ==========================================================================
  Widget _buildProfileInfo() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 5), // was 14/8
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 0.7,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (nickname != null && nickname!.isNotEmpty)
            _buildProfileInfoItem(
              icon: Icons.shield_outlined,
              value: nickname!,
            ),
          if (teamName != null && teamName!.isNotEmpty) ...[
            _buildProfileInfoDivider(),
            _buildProfileInfoItem(
              icon: Icons.sports_soccer_outlined,
              value: teamName!,
            ),
          ],
          if (country != null && country!.isNotEmpty) ...[
            _buildProfileInfoDivider(),
            _buildProfileInfoItem(
              icon: Icons.flag_outlined,
              value: country!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileInfoItem({
    required IconData icon,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: const Color(0xFF6EE7B7)), // was 13
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 100),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11, // was 12
              fontWeight: FontWeight.w600,
              color: Colors.white,
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
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 1,
      height: 12,
      color: Colors.white.withValues(alpha: 0.18),
    );
  }

  // ==========================================================================
  // USER'S OWN CHANNELS — shown after the search bar, no join-count cap
  // ==========================================================================
  Widget _buildUserChannels(BuildContext context) {
    if (!isLoggedIn) {
      return const SizedBox.shrink();
    }

    if (userChannels.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No channels joined',
            style: FanTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          _buildCreateChip(),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // ✅ 'clamping' avoids the bouncing-scroll physics grabbing short
      // horizontal drags before a tap can resolve — common cause of
      // "taps only work after a few tries" on web trackpads/mice.
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

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 2, vertical: 2), // was 4/4
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (channel.isAdmin) ...[
            const Text('👑', style: TextStyle(fontSize: 10)),
            const SizedBox(width: 3),
          ],

          // ✅ Tap channel name -> open chat (also marks it selected)
          _WebTappable(
            onTap: () {
              onChannelSelected(channel);
              onOpenChat?.call(channel);
            },
            borderRadius: BorderRadius.circular(8),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            child: Text(
              channel.name,
              style: TextStyle(
                fontSize: 12, // was 13
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF6EE7B7) : Colors.white,
                decoration: isSelected ? TextDecoration.underline : null,
              ),
            ),
          ),

          // ✅ Tap leader badge -> open leaderboard
          if (leader != null) ...[
            const SizedBox(width: 4),
            _WebTappable(
              onTap: () => onOpenLeaderboard?.call(channel),
              borderRadius: BorderRadius.circular(7),
              padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: FunspotGradients.gold),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '${leader.username} (${leader.seasonPoints}pts)',
                  style: const TextStyle(
                    fontSize: 9, // was 10
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0B3D2E),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCreateChip() {
    // No cap anymore — always tappable.
    return _WebTappable(
      onTap: onCreateChannel,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: const Icon(
        Icons.add_rounded,
        size: 15, // was 17
        color: Color(0xFF6EE7B7),
      ),
    );
  }

  // ==========================================================================
  // SEARCH
  // ==========================================================================
  Widget _buildSearch() {
    return Container(
      width: 180, // was 200
      height: 32, // was 40
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 0.7,
        ),
      ),
      child: TextField(
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12, // was 13
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: 'Search...',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 16, // was 18
            color: Colors.white.withValues(alpha: 0.6),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 4), // was 8
        ),
      ),
    );
  }

  // ==========================================================================
  // NOTIFICATIONS — plain bell icon
  // ==========================================================================
  Widget _buildNotificationIcon() {
    return _WebTappable(
      onTap: onNotificationTap,
      borderRadius: BorderRadius.circular(18),
      padding:
          const EdgeInsets.all(4), // was 6, bigger hit area than the bare icon
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.notifications_none_outlined,
            size: 20, // was 24
            color: Colors.white,
          ),
          if (notificationCount > 0)
            Positioned(
              top: -2,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  notificationCount > 99 ? '99+' : notificationCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 7, // was 8
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
  // AVATAR — circular with border, loads a real placeholder photo
  // ==========================================================================
  Widget _buildAvatar() {
    return _WebTappable(
      onTap: onMenuTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        width: 34, // was 42
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
            width: 1,
          ),
        ),
        child: ClipOval(
          child: isLoggedIn
              ? Image.network(
                  _avatarUrlFor(userId),
                  fit: BoxFit.cover,
                  width: 34,
                  height: 34,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: const Color(0xFF0B3D2E),
                      child: const Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor:
                                AlwaysStoppedAnimation(Color(0xFF34D399)),
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFF0B3D2E),
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                )
              : Container(
                  color: const Color(0xFF0B3D2E),
                  child: const Icon(
                    Icons.person_outline,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
        ),
      ),
    );
  }
}

// ============================================================================
// CHANNEL CAROUSEL
// ----------------------------------------------------------------------------
// Auto-scrolling, unstyled (no background/border) horizontal list of every
// channel — name, current top leader, and a Join button for channels the
// user hasn't joined. Sized to its content (capped by the parent's
// ConstrainedBox) rather than stretching across the whole Row, so it no
// longer leaves a dead empty gap before the search bar. Manual horizontal
// drag still works.
// ============================================================================

class _ChannelCarousel extends StatefulWidget {
  final List<UserChannel> channels;
  final Set<String> memberChannelIds;
  final Set<String> joiningChannelIds;
  final ValueChanged<UserChannel> onJoinChannel;
  final ValueChanged<UserChannel> onChannelTap;

  const _ChannelCarousel({
    required this.channels,
    required this.memberChannelIds,
    required this.joiningChannelIds,
    required this.onJoinChannel,
    required this.onChannelTap,
  });

  @override
  State<_ChannelCarousel> createState() => _ChannelCarouselState();
}

class _ChannelCarouselState extends State<_ChannelCarousel> {
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;

  // Roughly the width of one carousel entry (name + leader + join button).
  // Used as the auto-scroll step so each "tick" advances by about one
  // channel at a time.
  static const double _stepWidth = 170;
  static const Duration _tickInterval = Duration(seconds: 3);
  static const Duration _scrollAnimDuration = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(_tickInterval, (_) => _advance());
  }

  void _advance() {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return; // nothing to scroll — fits in view already

    final current = _scrollController.offset;
    final next = current + _stepWidth;

    if (next >= maxExtent) {
      // Loop back to the start.
      _scrollController.animateTo(
        0,
        duration: _scrollAnimDuration,
        curve: Curves.easeInOut,
      );
    } else {
      _scrollController.animateTo(
        next,
        duration: _scrollAnimDuration,
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channels = widget.channels;

    if (channels.isEmpty) {
      return Text(
        'No channels available',
        style: FanTypography.caption.copyWith(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 11,
        ),
      );
    }

    // Shrink-wraps to its content (up to the parent's maxWidth cap) instead
    // of an Expanded/SizedBox(width: double.infinity) that stretched across
    // the whole Row and left a visible dead gap when there weren't enough
    // channels to fill it.
    return SizedBox(
      height: 32, // was 40
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        shrinkWrap: true,
        itemCount: channels.length,
        itemBuilder: (context, index) {
          final channel = channels[index];
          final isMember = widget.memberChannelIds.contains(channel.channelId);
          final isJoining =
              widget.joiningChannelIds.contains(channel.channelId);
          return _CarouselEntry(
            channel: channel,
            isMember: isMember,
            isJoining: isJoining,
            onJoin: () => widget.onJoinChannel(channel),
            onTap: () => widget.onChannelTap(channel),
          );
        },
      ),
    );
  }
}

class _CarouselEntry extends StatelessWidget {
  final UserChannel channel;
  final bool isMember;
  final bool isJoining;
  final VoidCallback onJoin;
  final VoidCallback onTap;

  const _CarouselEntry({
    required this.channel,
    required this.isMember,
    required this.isJoining,
    required this.onJoin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sortedMembers = List<ChannelMember>.from(channel.members)
      ..sort((a, b) => b.seasonPoints.compareTo(a.seasonPoints));
    final leader = sortedMembers.isNotEmpty ? sortedMembers.first : null;

    // No background color or border here by design — just plain content,
    // inked via _WebTappable so clicks/hover still register on web.
    return _WebTappable(
      onTap: onTap,
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // was 10/8
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            channel.name,
            style: const TextStyle(
              fontSize: 12, // was 13
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (leader != null) ...[
            const SizedBox(width: 5),
            const Icon(Icons.emoji_events, size: 11, color: Color(0xFFF5B841)),
            const SizedBox(width: 3),
            Text(
              leader.username,
              style: const TextStyle(
                fontSize: 10, // was 11
                fontWeight: FontWeight.w600,
                color: Color(0xFFFFE08A),
              ),
            ),
          ],
          if (!isMember) ...[
            const SizedBox(width: 6),
            _WebTappable(
              onTap: isJoining ? null : onJoin,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              child: isJoining
                  ? const SizedBox(
                      width: 11,
                      height: 11,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation(Color(0xFF34D399)),
                      ),
                    )
                  : const Text(
                      'Join',
                      style: TextStyle(
                        fontSize: 10, // was 11
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6EE7B7),
                        decoration: TextDecoration.underline,
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
