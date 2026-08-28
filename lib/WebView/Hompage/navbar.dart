// lib/widgets/web_navbar.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../pages/fan_Funzy_design.dart';
import '../../models/user_channel.dart';

/// Funspot brand gradient — deep emerald → jade → gold accent.
class FunspotGradients {
  static const List<Color> navbar = [
    Color(0xFF07291E),
    Color(0xFF0E4A34),
    Color(0xFF15693F),
  ];

  static const List<Color> logo = [
    Color(0xFF6EE7B7),
    Color(0xFF34D399),
    Color(0xFF059669),
  ];

  static const List<Color> gold = [
    Color(0xFFFFE9A8),
    Color(0xFFF5B841),
    Color(0xFFD68F0E),
  ];

  static const List<Color> avatarRing = [
    Color(0xFF6EE7B7),
    Color(0xFFFFD166),
  ];

  static const List<Color> glassSheen = [
    Color(0x1AFFFFFF),
    Color(0x00FFFFFF),
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
    final radius = borderRadius ?? BorderRadius.circular(8);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: radius,
        splashColor: const Color(0xFF6EE7B7).withValues(alpha: 0.18),
        highlightColor: const Color(0xFF6EE7B7).withValues(alpha: 0.08),
        hoverColor: Colors.white.withValues(alpha: 0.06),
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
  final Set<String> pendingChannelIds;

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

  // Callback to show login modal when unauthenticated user tries to join
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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: FunspotGradients.navbar,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF03140E).withValues(alpha: 0.55),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: const Color(0xFF34D399).withValues(alpha: 0.10),
                blurRadius: 30,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Glass sheen — soft light strip along the very top edge.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 14,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: FunspotGradients.glassSheen,
                    ),
                  ),
                ),
              ),

              // Content row.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    // 1. App name / logo
                    _buildLogo(),
                    const SizedBox(width: 16),

                    if (isLoggedIn && _hasProfileInfo) ...[
                      _buildProfileInfo(),
                      const SizedBox(width: 16),
                    ],

                    // 2. All-channels carousel — sized to its content, not
                    //    stretched across the whole Row, still auto-scrolls
                    //    internally if it has more items than fit in the cap.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: _ChannelCarousel(
                        channels: allChannels,
                        memberChannelIds: _memberChannelIds,
                        joiningChannelIds: joiningChannelIds,
                        isLoggedIn: isLoggedIn,
                        onJoinChannel: _handleJoinChannel,
                        onChannelTap: onChannelSelected,
                        onShowLoginModal: onShowLoginModal,
                      ),
                    ),

                    // ✅ Real spacer — absorbs whatever space is left so the
                    // entire right-hand cluster stays glued together and
                    // pinned flush against the right edge.
                    const Spacer(),

                    // 3. Search bar
                    _buildSearch(),
                    const SizedBox(width: 12),

                    // 4. The user's own joined channels — capped so it can
                    //    never push notification/avatar off-screen.
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
              ),

              // Bottom accent line — a jewel-toned gradient hairline instead
              // of a flat solid border, brighter at the center.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 1.4,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0x00F5B841),
                        Color(0x99FFD166),
                        Color(0xFFF5B841),
                        Color(0x99FFD166),
                        Color(0x00F5B841),
                      ],
                      stops: [0.0, 0.28, 0.5, 0.72, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // HANDLE JOIN - Check login status first
  // ==========================================================================
  void _handleJoinChannel(UserChannel channel) {
    if (!isLoggedIn) {
      // Show login modal if user is not logged in
      onShowLoginModal?.call();
      return;
    }
    // Proceed with join if logged in
    onJoinChannel(channel);
  }

  // ==========================================================================
  // LOGO — circular mark with a soft gradient ring and glow
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
              colors: FunspotGradients.logo,
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
              shadows: [
                Shadow(
                  color: Color(0x40000000),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
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
              colors: FunspotGradients.gold,
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
  // PROFILE INFO — nickname / team / country, glass pill with soft border
  // ==========================================================================
  Widget _buildProfileInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.09),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 0.8,
        ),
      ),
      child: Row(
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
        Icon(icon, size: 12, color: const Color(0xFFFFD166)),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 100),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
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
      height: 12,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
      ),
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
              color: Colors.white.withValues(alpha: 0.65),
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
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF6EE7B7).withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(
                color: const Color(0xFF6EE7B7).withValues(alpha: 0.35),
                width: 0.8,
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (channel.isAdmin) ...[
            const SizedBox(width: 6),
            const Text('👑', style: TextStyle(fontSize: 10)),
            const SizedBox(width: 2),
          ],

          // ✅ Tap channel name -> open chat (also marks it selected)
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
                color: isSelected ? const Color(0xFF6EE7B7) : Colors.white,
                letterSpacing: -0.1,
                height: 1,
              ),
            ),
          ),

          // ✅ Tap leader badge -> open leaderboard
          if (leader != null) ...[
            const SizedBox(width: 2),
            _WebTappable(
              onTap: () => onOpenLeaderboard?.call(channel),
              borderRadius: BorderRadius.circular(7),
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: FunspotGradients.gold,
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
      ),
    );
  }

  Widget _buildCreateChip() {
    // No cap anymore — always tappable.
    return _WebTappable(
      onTap: onCreateChannel,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(2),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(
            color: const Color(0xFF6EE7B7).withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: const Icon(
          Icons.add_rounded,
          size: 15,
          color: Color(0xFF6EE7B7),
        ),
      ),
    );
  }

  // ==========================================================================
  // SEARCH — glass pill with a softly lit border
  // ==========================================================================
  Widget _buildSearch() {
    return Container(
      width: 168,
      height: 30,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
          color: Colors.white,
          height: 1,
        ),
        cursorColor: const Color(0xFF6EE7B7),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search…',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 16,
            color: Color(0xFF6EE7B7),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 32, minHeight: 16),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  // ==========================================================================
  // NOTIFICATIONS — bell with a soft glow halo and glossy badge
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
          Container(
            decoration: hasNotifications
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD166).withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  )
                : null,
            child: Icon(
              hasNotifications
                  ? Icons.notifications_rounded
                  : Icons.notifications_none_rounded,
              size: 19,
              color: Colors.white,
            ),
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
                    color: const Color(0xFF07291E),
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
  // AVATAR — circular photo with a two-tone gradient ring and glow
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
            colors: FunspotGradients.avatarRing,
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
                      color: const Color(0xFF07291E),
                      child: const Center(
                        child: SizedBox(
                          width: 12,
                          height: 12,
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
                    color: const Color(0xFF07291E),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                )
              : Container(
                  color: const Color(0xFF07291E),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 15,
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
// Auto-scrolling, softly-lit pill list of every channel — name, current top
// leader, and a Join button for channels the user hasn't joined. Sized to
// its content (capped by the parent's ConstrainedBox) rather than
// stretching across the whole Row. Manual horizontal drag still works.
// ============================================================================

class _ChannelCarousel extends StatefulWidget {
  final List<UserChannel> channels;
  final Set<String> memberChannelIds;
  final Set<String> joiningChannelIds;
  final bool isLoggedIn;
  final ValueChanged<UserChannel> onJoinChannel;
  final ValueChanged<UserChannel> onChannelTap;
  final VoidCallback? onShowLoginModal;

  const _ChannelCarousel({
    required this.channels,
    required this.memberChannelIds,
    required this.joiningChannelIds,
    required this.isLoggedIn,
    required this.onJoinChannel,
    required this.onChannelTap,
    this.onShowLoginModal,
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
          color: Colors.white.withValues(alpha: 0.65),
          fontSize: 11,
          height: 1,
        ),
      );
    }

    // Shrink-wraps to its content (up to the parent's maxWidth cap) instead
    // of stretching across the whole Row.
    return SizedBox(
      height: 28,
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
            isLoggedIn: widget.isLoggedIn,
            onJoin: () => widget.onJoinChannel(channel),
            onTap: () => widget.onChannelTap(channel),
            onShowLoginModal: widget.onShowLoginModal,
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
  final bool isLoggedIn;
  final VoidCallback onJoin;
  final VoidCallback onTap;
  final VoidCallback? onShowLoginModal;

  const _CarouselEntry({
    required this.channel,
    required this.isMember,
    required this.isJoining,
    required this.isLoggedIn,
    required this.onJoin,
    required this.onTap,
    this.onShowLoginModal,
  });

  @override
  Widget build(BuildContext context) {
    final sortedMembers = List<ChannelMember>.from(channel.members)
      ..sort((a, b) => b.seasonPoints.compareTo(a.seasonPoints));
    final leader = sortedMembers.isNotEmpty ? sortedMembers.first : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: _WebTappable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.7,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                channel.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.1,
                  height: 1,
                ),
              ),
              if (leader != null) ...[
                const SizedBox(width: 6),
                const Icon(Icons.emoji_events_rounded,
                    size: 11, color: Color(0xFFFFD166)),
                const SizedBox(width: 3),
                Text(
                  leader.username,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFFE08A),
                    height: 1,
                  ),
                ),
              ],
              if (!isMember) ...[
                const SizedBox(width: 7),
                _WebTappable(
                  onTap: () {
                    // Check if user is logged in before allowing join
                    if (!isLoggedIn) {
                      onShowLoginModal?.call();
                      return;
                    }
                    onJoin();
                  },
                  borderRadius: BorderRadius.circular(6),
                  padding: EdgeInsets.zero,
                  child: isJoining
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 3),
                          child: SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor:
                                  AlwaysStoppedAnimation(Color(0xFF34D399)),
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: FunspotGradients.logo,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF34D399)
                                    .withValues(alpha: 0.4),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          child: const Text(
                            'Join',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF07291E),
                              height: 1,
                            ),
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
