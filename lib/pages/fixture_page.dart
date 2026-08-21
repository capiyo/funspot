import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../services/payment_service.dart';

// Your project imports
import '../services/comrade_service.dart';
import '../services/memory_manager.dart';
import '../modals/homepage/admin_dashboard.dart';
import '../modals/Funzy/leaderboard.dart';
import '../models/fixture_models.dart';
import '../services/notification_service.dart';
import '../../services/bet_service.dart';
import "../modals/Funzy/swipabledialogue.dart";
import "../modals/Funzy/cast_vote.dart";
import '../services/auth_service.dart';
import '../modals/login_modal.dart';
import "../modals/FAB/profile_modal.dart";
import '../screens/home_page.dart';
import '../main.dart';
import "../models/user_channel.dart";
import '../modals/Funzy/chat_screen.dart';
import '../modals/Funzy/match_details.dart';
import '../services/web_soecket.dart';
import 'fan_Funzy_design.dart';
import '../modals/Funzy/join_groups_modal.dart';

///import '../modals/Funzy/votes_modal.dart'; // Add this import
///
///
///

// ========== COMRADE ACTIVITY POPUP ==========
// ============================================================================
// SPEECH BUBBLE COMMENT INPUT - ADD INSIDE FixturesPageState
// ============================================================================
// Add after your other imports
class LiveCommentaryEntry {
  final String text;
  final String type;
  final int minute;
  final DateTime timestamp;
  final Color color;
  final IconData icon;
  final String? scorer;
  final String? team;

  LiveCommentaryEntry({
    required this.text,
    required this.type,
    required this.minute,
    required this.timestamp,
    this.color = Colors.white,
    this.icon = Icons.info_outline,
    this.scorer,
    this.team,
  });
}

class _SpeechBubbleInput extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final String hintText;
  final VoidCallback? onSend;
  final Function(String)? onSubmitted;
  final bool hasText;

  const _SpeechBubbleInput({
    required this.controller,
    required this.enabled,
    required this.hintText,
    this.onSend,
    this.onSubmitted,
    this.hasText = false,
  });

  @override
  State<_SpeechBubbleInput> createState() => _SpeechBubbleInputState();
}

class _SpeechBubbleInputState extends State<_SpeechBubbleInput> {
  @override
  Widget build(BuildContext context) {
    // In dark mode everything (surface/background/sunken) is the same
    // flat navy now, so the input needs its own slightly-lifted shade
    // to stay visually distinct from the card behind it. In light mode
    // we keep the existing white surface untouched.
    final Color inputBg = FanColors.isDark
        ? Color.alphaBlend(
            Colors.white.withValues(alpha: 0.04), FanColors.inputSurface)
        : FanColors.surface;

    final Color inputBgDisabled = FanColors.isDark
        ? Color.alphaBlend(
            Colors.white.withValues(alpha: 0.015), FanColors.inputSurface)
        : FanColors.surface.withValues(alpha: 0.4);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Avatar
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: FanColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: FanColors.primary.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              widget.controller.text.isNotEmpty
                  ? widget.controller.text[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: FanColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // SPEECH BUBBLE INPUT - THIS IS THE KEY PART
        Expanded(
          child: ClipPath(
            clipper: _SpeechBubbleClipper(),
            child: Container(
              decoration: BoxDecoration(
                color: widget.enabled ? inputBg : inputBgDisabled,
                border: Border.all(
                  color: widget.enabled
                      ? FanColors.primary.withValues(alpha: 0.15)
                      : FanColors.border.withValues(alpha: 0.1),
                  width: widget.enabled ? 1.0 : 0.5,
                ),
                boxShadow: widget.enabled
                    ? [
                        BoxShadow(
                          color: FanColors.primary.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      enabled: widget.enabled,
                      // ✅ Green + slim, in both light and dark mode.
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        color: widget.enabled
                            ? FanColors.primary
                            : FanColors.primary.withValues(alpha: 0.4),
                      ),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: FanColors.primary.withValues(alpha: 0.35),
                          fontStyle: widget.enabled
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                      maxLines: null,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (value) {
                        if (widget.enabled && value.trim().isNotEmpty) {
                          widget.onSubmitted?.call(value);
                        }
                      },
                    ),
                  ),
                  if (widget.enabled && widget.hasText)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: GestureDetector(
                        onTap: widget.onSend,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: FanColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.send_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
// ============================================================================
// SPEECH BUBBLE CLIPPER - CREATES THE TAIL SHAPE
// ============================================================================

class _SpeechBubbleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final double radius = 16.0;
    final double tailSize = 10.0;
    final double tailPosition = size.width * 0.08; // 8% from left

    // Main rounded rectangle
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(16),
      ),
    );

    // Add the tail at bottom-left (pointing to avatar)
    path.moveTo(tailPosition, size.height);
    path.lineTo(tailPosition - tailSize, size.height + tailSize);
    path.lineTo(tailPosition + tailSize, size.height + tailSize);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class ComradeActivityPopup extends StatefulWidget {
  final List<VoteUser> voters;
  final List<FixtureComment> comments;
  final Fixture fixture;
  final String currentUserId;
  final String currentUsername;
  final String? authToken;
  final String? userVoteSelection;
  final Set<String> comradesList;
  final VoidCallback onClose;
  final Future<void> Function(String comment)? onCommentPosted;
  final Future<List<FixtureComment>> Function()? onRefreshNeeded;
  final String? channelId;
  final Future<void> Function(String channelId, String fixtureId)?
      ensureChannelFixture;

  const ComradeActivityPopup({
    super.key,
    required this.voters,
    required this.comments,
    required this.fixture,
    required this.currentUserId,
    required this.currentUsername,
    this.authToken,
    this.userVoteSelection,
    required this.comradesList,
    required this.onClose,
    this.onCommentPosted,
    this.onRefreshNeeded,
    this.channelId,
    this.ensureChannelFixture,
  });

  @override
  State<ComradeActivityPopup> createState() => _ComradeActivityPopupState();
}

class _ComradeActivityPopupState extends State<ComradeActivityPopup> {
  final TextEditingController _commentController = TextEditingController();
  bool _isPosting = false;
  final List<Map<String, dynamic>> _activities = [];

  String _getVoteDisplayText(String? selection) {
    if (selection == 'home_team') return widget.fixture.homeTeam;
    if (selection == 'away_team') return widget.fixture.awayTeam;
    if (selection == 'draw') return 'draw';
    return selection ?? '';
  }

  Color _getVoteColor(String? selection) {
    if (selection == 'home_team') return FanColors.primary;
    if (selection == 'away_team') return const Color(0xFF2563EB);
    if (selection == 'draw') return const Color(0xFF8B5CF6);
    return FanColors.textSecondary;
  }

  void _rebuildActivitiesWithData(
    List<VoteUser> voters,
    List<FixtureComment> comments,
  ) {
    _activities.clear();

    // Add votes
    for (var voter in voters) {
      _activities.add({
        'type': 'vote',
        'userId': voter.userId,
        'username': voter.username,
        'selection': voter.selection,
        'timestamp': voter.votedAt,
        'comment': null,
        'isMe': voter.userId == widget.currentUserId,
        'isComrade': widget.comradesList.contains(voter.userId),
      });
    }

    // Add comments
    for (var comment in comments) {
      _activities.add({
        'type': 'comment',
        'userId': comment.userId,
        'username': comment.username,
        'selection': comment.selection,
        'timestamp': comment.timestamp,
        'comment': comment.comment,
        'isMe': comment.userId == widget.currentUserId,
        'isComrade': widget.comradesList.contains(comment.userId),
      });
    }

    // Sort by timestamp
    _activities.sort(
      (a, b) =>
          (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime),
    );
  }

  void _rebuildActivities() {
    _activities.clear();

    // Add votes
    for (var voter in widget.voters) {
      _activities.add({
        'type': 'vote',
        'userId': voter.userId,
        'username': voter.username,
        'selection': voter.selection,
        'timestamp': voter.votedAt,
        'comment': null,
        'isMe': voter.userId == widget.currentUserId,
        'isComrade': widget.comradesList.contains(voter.userId),
      });
    }

    // Add comments
    for (var comment in widget.comments) {
      _activities.add({
        'type': 'comment',
        'userId': comment.userId,
        'username': comment.username,
        'selection': comment.selection,
        'timestamp': comment.timestamp,
        'comment': comment.comment,
        'isMe': comment.userId == widget.currentUserId,
        'isComrade': widget.comradesList.contains(comment.userId),
      });
    }

    // Sort by timestamp (oldest first - newest at bottom)
    _activities.sort(
      (a, b) =>
          (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime),
    );
  }

  @override
  void initState() {
    super.initState();
    _rebuildActivities();
  }

  @override
  void didUpdateWidget(ComradeActivityPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.voters != widget.voters ||
        oldWidget.comments != widget.comments) {
      _rebuildActivities();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.85,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        decoration: FanDecorations.elevatedCard(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: FanColors.border.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.people_alt,
                        color: FanColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Comrade Activity',
                            style: FanTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${_activities.length} activities',
                            style: FanTypography.caption.copyWith(
                              fontSize: 11,
                              color: FanColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: FanColors.inputSurface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: FanColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Activity List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _activities.length,
                itemBuilder: (context, index) {
                  final activity = _activities[index];
                  final isVote = activity['type'] == 'vote';
                  final isMe = activity['isMe'] as bool;
                  final isComrade = activity['isComrade'] as bool;
                  final timeAgo = DateHelper.formatTimeAgo(
                    activity['timestamp'],
                  );
                  final voteDisplay =
                      isVote ? _getVoteDisplayText(activity['selection']) : '';
                  final voteColor = _getVoteColor(activity['selection']);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FootballAvatarManager.buildAvatar(
                              userId: activity['userId'],
                              username: activity['username'],
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        activity['username'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isMe
                                              ? FanColors.primary
                                              : FanColors.textPrimary,
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: FanColors.primary
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            'you',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: FanColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (!isMe && isComrade) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: FanColors.primary
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.people_alt,
                                                size: 9,
                                                color: FanColors.primary,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                'comrade',
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  color: FanColors.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 8),
                                      Text(
                                        timeAgo,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: FanColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  FutureBuilder<Map<String, dynamic>>(
                                    future: _fetchUserProfile(
                                      activity['userId'],
                                    ),
                                    builder: (context, snapshot) {
                                      final club = snapshot.hasData
                                          ? snapshot.data!['clubFan']
                                          : 'Loading...';
                                      return Row(
                                        children: [
                                          Icon(
                                            Icons.sports_soccer,
                                            size: 12,
                                            color: FanColors.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            club,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: FanColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            if (activity['selection'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: voteColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: voteColor.withValues(alpha: 0.3),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  voteDisplay,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: voteColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (!isVote && activity['comment'] != null)
                          Container(
                            margin: const EdgeInsets.only(left: 52),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? FanColors.primary.withValues(alpha: 0.08)
                                  : FanColors.inputSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: FanColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              activity['comment'],
                              style: TextStyle(
                                fontSize: 13,
                                color: FanColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        if (index != _activities.length - 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Divider(
                              color: FanColors.border.withValues(alpha: 0.2),
                              height: 1,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Comment Input Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: FanColors.border.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  FootballAvatarManager.buildAvatar(
                    userId: widget.currentUserId,
                    username: widget.currentUsername,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: FanColors.inputSurface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: FanColors.border.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _commentController,
                        style: TextStyle(
                            fontSize: 13, color: FanColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: widget.userVoteSelection == null
                              ? 'Vote first to comment'
                              : 'Write a comment...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: FanColors.textSecondary,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        enabled: widget.userVoteSelection != null,
                        onSubmitted: (_) => _postComment(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isPosting ? null : _postComment,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _commentController.text.trim().isEmpty ||
                                widget.userVoteSelection == null
                            ? FanColors.inputSurface
                            : FanColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: _isPosting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                Icons.send_rounded,
                                size: 18,
                                color: _commentController.text.trim().isEmpty ||
                                        widget.userVoteSelection == null
                                    ? FanColors.textSecondary
                                    : Colors.white,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _getChannelIdForComment() {
    // Try to get channelId from the widget's fixture or from parent
    // You may need to pass channelId as a parameter to ComradeActivityPopup

    // Option 1: If you add channelId to the widget
    // if (widget.channelId != null) return widget.channelId;

    // Option 2: Try to get from AppCache
    if (AppCache.channels.isNotEmpty) {
      return AppCache.channels.first.channelId;
    }

    // Option 3: Try from shared preferences
    // final prefs = await SharedPreferences.getInstance();
    // return prefs.getString('selected_channel_id');

    debugPrint('⚠️ No channel ID available for comment');
    return null;
  }

  Future<void> _postComment() async {
    final commentText = _commentController.text.trim();

    if (commentText.isEmpty) {
      ToastHelper.showWarning('Please enter a comment');
      return;
    }

    if (widget.userVoteSelection == null) {
      ToastHelper.showWarning('You must vote on this match before commenting');
      return;
    }

    // ✅ Use the channelId passed into the widget — the same one the parent
    // (FixturesPage) resolved via _resolveChannelIdFor. Do NOT re-derive it
    // here; that's what caused comments to land in a different channel than
    // the one ChatScreen opens.
    final String? channelId = widget.channelId;
    if (channelId == null) {
      ToastHelper.showError('No channel selected');
      return;
    }

    // ✅ ENSURE THE CHANNEL-FIXTURE CHAT EXISTS BEFORE POSTING
    // Same orphaning risk as _createComment: if this popup is the first
    // interaction the user has had with this fixture's chat, the
    // channel↔fixture association may never have been registered.
    if (widget.ensureChannelFixture != null) {
      await widget.ensureChannelFixture!(channelId, widget.fixture.matchId);
    }

    setState(() => _isPosting = true);

    final tempId =
        'temp_${DateTime.now().millisecondsSinceEpoch}_${widget.currentUserId}';

    // Optimistic update
    final optimisticComment = {
      'type': 'comment',
      'userId': widget.currentUserId,
      'username': widget.currentUsername,
      'selection': widget.userVoteSelection,
      'timestamp': DateTime.now(),
      'comment': commentText,
      'isMe': true,
      'isComrade': false,
      'id': tempId,
      'isPending': true,
    };

    setState(() {
      _activities.add(optimisticComment);
      _activities.sort((a, b) =>
          (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime));
    });

    _commentController.clear();

    try {
      final ws = WebSocketService();
      if (ws.isConnected) {
        ws.sendChatMessage(
          message: commentText,
          selection: widget.userVoteSelection ?? '',
          username: widget.currentUsername,
          messageId: tempId,
          replyTo: null,
          imageUrl: null,
          videoUrl: null,
          isImage: false,
          isVideo: false,
          channelId: channelId,
          fixtureId: widget.fixture.matchId,
          tempId: tempId,
        );

        setState(() {
          final index = _activities.indexWhere((a) => a['id'] == tempId);
          if (index != -1) {
            _activities[index]['isPending'] = false;
          }
        });

        ToastHelper.showSuccess('Comment posted! 🎉');

        if (widget.onCommentPosted != null) {
          await widget.onCommentPosted!(commentText);
        }
      } else {
        ToastHelper.showError('Not connected to chat server');
        setState(() {
          _activities.removeWhere((a) => a['id'] == tempId);
        });
      }
    } catch (e) {
      debugPrint('❌ Error posting comment: $e');
      setState(() {
        _activities.removeWhere((a) => a['id'] == tempId);
      });
      ToastHelper.showError('Network error. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  Future<Map<String, dynamic>> _fetchUserProfile(String userId) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://clash-api-m5mr.onrender.com/api/profile/profile/$userId',
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'clubFan': data['club_fan']?.toString() ?? 'Football Fan',
          'countryFan': data['country_fan']?.toString() ?? 'World',
        };
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
    return {'clubFan': 'Football Fan', 'countryFan': 'World'};
  }
}

// ==========================================================================
// CHANNEL-BASED MODELS (Add after imports)
// ==========================================================================

class ChannelFixtureData {
  final String fixtureId;
  final String channelId;
  final String matchName;
  final DateTime kickoffTime;
  final String status;
  final int homeVotes;
  final int awayVotes;
  final int drawVotes;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSender;
  final String? userVote;
  final int commentCount; // ADD THIS
  final Map<String, int> unreadCounts;

  ChannelFixtureData({
    required this.fixtureId,
    required this.channelId,
    required this.matchName,
    required this.kickoffTime,
    required this.status,
    required this.homeVotes,
    required this.awayVotes,
    required this.drawVotes,
    this.lastMessage,
    this.lastMessageAt,
    this.lastSender,
    this.userVote,
    this.commentCount = 0, // ADD
    this.unreadCounts = const {},
  });

  int get totalVotes => homeVotes + awayVotes + drawVotes;
  bool get hasUserVoted => userVote != null;
  bool get isLive => status == 'live';
  bool get isCompleted => status == 'completed';
  bool get isUpcoming => status == 'upcoming';

  factory ChannelFixtureData.fromJson(Map<String, dynamic> json) {
    final voteCounts = json['vote_counts'] ?? {};
    return ChannelFixtureData(
      fixtureId: json['fixture_id'] ?? '',
      channelId: json['channel_id'] ?? '',
      matchName: json['match_name'] ?? '',
      kickoffTime: DateTime.parse(
          json['kickoff_time'] ?? DateTime.now().toIso8601String()),
      status: json['status'] ?? 'upcoming',
      homeVotes: voteCounts['home'] ?? 0,
      awayVotes: voteCounts['away'] ?? 0,
      drawVotes: voteCounts['draw'] ?? 0,
      lastMessage: json['last_message'],
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'])
          : null,
      lastSender: json['last_sender'],
      userVote: json['user_vote'],
      commentCount: json['comment_count'] ?? 0, // ADD
      unreadCounts: Map<String, int>.from(json['unread_counts'] ?? {}), //
    );
  }
}

class LiveEvent {
  final String id;
  final String eventType; // "goal", "yellow_card", "red_card", "substitution"
  final String? scorer;
  final String? assist;
  final String? player;
  final String team; // "home" or "away"
  final int minute;
  final String minuteDisplay;
  final int homeScore;
  final int awayScore;
  final DateTime timestamp;

  LiveEvent({
    required this.id,
    required this.eventType,
    this.scorer,
    this.assist,
    this.player,
    required this.team,
    required this.minute,
    required this.minuteDisplay,
    required this.homeScore,
    required this.awayScore,
    required this.timestamp,
  });

  factory LiveEvent.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    return LiveEvent(
      id: json['_id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      eventType: json['event_type'] ?? '',
      scorer: data['scorer']?.toString(),
      assist: data['assist']?.toString(),
      player: data['player']?.toString(),
      team: data['team']?.toString() ?? '',
      minute: json['minute'] ?? 0,
      minuteDisplay: json['minute_display'] ?? '0',
      homeScore: json['home_score'] ?? 0,
      awayScore: json['away_score'] ?? 0,
      timestamp: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  String getDisplayText() {
    switch (eventType) {
      case 'goal':
        return '⚽ ${scorer ?? 'Goal'}${assist != null ? ' (assist: $assist)' : ''}';
      case 'yellow_card':
        return '🟨 Yellow - $player';
      case 'red_card':
        return '🟥 Red - $player';
      case 'substitution':
        return '🔄 Substitution';
      default:
        return eventType;
    }
  }

  Color getColor() {
    switch (eventType) {
      case 'goal':
        return Colors.green;
      case 'yellow_card':
        return Colors.orange;
      case 'red_card':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// ========== GLOBAL CACHE MANAGER ==========
class GlobalCacheManager {
  static final GlobalCacheManager _instance = GlobalCacheManager._internal();
  factory GlobalCacheManager() => _instance;
  GlobalCacheManager._internal();
  //Map<String, int>? _cachedCommentCounts;
  // Map<String, int>? get commentCounts => _cachedCommentCounts;
  // set commentCounts(Map<String, int>? value) => _cachedCommentCounts = value;

  // Cached data
  List<Fixture>? _cachedFixtures;
  Map<String, String?>? _cachedUserVotes;
  Map<String, FixtureVoteData>? _cachedFixtureVoteData;
  Map<String, List<FixtureComment>>? _cachedComments;
  Map<String, Map<String, SubFixtureVoteData>>? _cachedSubFixtureData;
  Map<String, bool>? _cachedUserLikes;
  Map<String, LikeStatsResponse>? _cachedLikeStats;
  Map<String, VoteStatsResponse>? _cachedVoteStats;
  Map<String, GameMetadata>? _cachedGameMetadata;
  Map<String, List<SubFixture>>? _cachedSubFixtures;
  Map<String, Map<String, String>>? _cachedCommenters;
  Map<String, FixtureNotificationState>? _cachedNotifications;

  // NEW: Cache for comrades
  Set<String>? _cachedUserComrades;
  Map<String, List<ComradeWithProfile>>? _cachedComradeVoters;
  Map<String, int>? _cachedUnreadCounts;
  Map<String, int>? get unreadCounts => _cachedUnreadCounts;
  set unreadCounts(Map<String, int>? value) => _cachedUnreadCounts = value;

  // Timestamps for cache invalidation
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  bool get isCacheValid {
    if (_lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheDuration;
  }

  void clearCache() {
    _cachedUnreadCounts = null;
    _cachedFixtures = null;
    _cachedUserVotes = null;
    _cachedFixtureVoteData = null;
    _cachedComments = null;
    _cachedSubFixtureData = null;
    _cachedUserLikes = null;
    _cachedLikeStats = null;
    _cachedVoteStats = null;
    _cachedGameMetadata = null;
    _cachedSubFixtures = null;
    _cachedCommenters = null;
    _cachedNotifications = null;
    _cachedUserComrades = null;
    _cachedComradeVoters = null;
    _lastFetchTime = null;
  }

  // Getters with lazy loading
  List<Fixture>? get fixtures => _cachedFixtures;
  set fixtures(List<Fixture>? value) {
    _cachedFixtures = value;
    if (value != null) _lastFetchTime = DateTime.now();
  }

  Map<String, String?>? get userVotes => _cachedUserVotes;
  set userVotes(Map<String, String?>? value) => _cachedUserVotes = value;
  // Add this with your other maps
  final Map<String, bool> _subFixturesExpanded = {};

  Map<String, FixtureVoteData>? get fixtureVoteData => _cachedFixtureVoteData;
  set fixtureVoteData(Map<String, FixtureVoteData>? value) =>
      _cachedFixtureVoteData = value;

  Map<String, List<FixtureComment>>? get comments => _cachedComments;
  set comments(Map<String, List<FixtureComment>>? value) =>
      _cachedComments = value;

  Map<String, Map<String, SubFixtureVoteData>>? get subFixtureData =>
      _cachedSubFixtureData;
  set subFixtureData(Map<String, Map<String, SubFixtureVoteData>>? value) =>
      _cachedSubFixtureData = value;

  Map<String, bool>? get userLikes => _cachedUserLikes;
  set userLikes(Map<String, bool>? value) => _cachedUserLikes = value;

  Map<String, LikeStatsResponse>? get likeStats => _cachedLikeStats;
  set likeStats(Map<String, LikeStatsResponse>? value) =>
      _cachedLikeStats = value;

  Map<String, VoteStatsResponse>? get voteStats => _cachedVoteStats;
  set voteStats(Map<String, VoteStatsResponse>? value) =>
      _cachedVoteStats = value;

  Map<String, GameMetadata>? get gameMetadata => _cachedGameMetadata;
  set gameMetadata(Map<String, GameMetadata>? value) =>
      _cachedGameMetadata = value;

  Map<String, List<SubFixture>>? get subFixtures => _cachedSubFixtures;
  set subFixtures(Map<String, List<SubFixture>>? value) =>
      _cachedSubFixtures = value;

  Map<String, Map<String, String>>? get commenters => _cachedCommenters;
  set commenters(Map<String, Map<String, String>>? value) =>
      _cachedCommenters = value;

  Map<String, FixtureNotificationState>? get notifications =>
      _cachedNotifications;
  set notifications(Map<String, FixtureNotificationState>? value) =>
      _cachedNotifications = value;

  Set<String>? get userComrades => _cachedUserComrades;
  set userComrades(Set<String>? value) => _cachedUserComrades = value;

  Map<String, List<ComradeWithProfile>>? get comradeVoters =>
      _cachedComradeVoters;
  set comradeVoters(Map<String, List<ComradeWithProfile>>? value) =>
      _cachedComradeVoters = value;
}

// ========== FOOTBALL AVATAR MANAGER ==========
class FootballAvatarManager {
  static const String _cacheKey = 'football_avatar_cache';
  static const String _timestampKey = 'avatar_timestamp';
  static const Duration _cacheDuration = Duration(days: 7);

  static const List<String> _avatarUrls = [
    'https://cdn-icons-png.flaticon.com/512/3095/3095207.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095212.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095216.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095221.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095225.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095230.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095234.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095239.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095243.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095248.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095252.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095257.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095261.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095266.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095270.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095275.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095279.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095284.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095288.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095293.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095297.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095302.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095306.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095311.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095315.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095320.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095324.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095329.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095333.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095338.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095342.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095347.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095351.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095356.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095360.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095365.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095369.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095374.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095378.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095383.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095387.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095392.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095396.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095401.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095405.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095410.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095414.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095419.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095423.png',
    'https://cdn-icons-png.flaticon.com/512/3095/3095428.png',
  ];

  static final Map<String, String> _memoryCache = {};

  static String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '⚽';
    List<String> parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '⚽';
  }

  static Future<String> getAvatarUrl(String userId) async {
    if (_memoryCache.containsKey(userId)) {
      return _memoryCache[userId]!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      final timestamp = prefs.getInt(_timestampKey);

      if (cached != null && timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final isValid = DateTime.now().difference(cacheTime) < _cacheDuration;

        if (isValid) {
          final Map<String, dynamic> cache = json.decode(cached);
          if (cache.containsKey(userId)) {
            final url = cache[userId] as String;
            _memoryCache[userId] = url;
            return url;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Avatar cache read error: $e');
    }

    final hash = userId.hashCode.abs();
    final url = _avatarUrls[hash % _avatarUrls.length];
    _memoryCache[userId] = url;

    _saveToDisk(userId, url);
    return url;
  }

  static Future<void> _saveToDisk(String userId, String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_cacheKey);
      Map<String, dynamic> cache = {};

      if (existing != null) {
        try {
          cache = json.decode(existing);
        } catch (e) {
          cache = {};
        }
      }

      cache[userId] = url;
      await prefs.setString(_cacheKey, json.encode(cache));
      await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('⚠️ Avatar cache save error: $e');
    }
  }

  static Widget buildAvatar({
    required String userId,
    String? username,
    double size = 32.0,
    VoidCallback? onTap,
  }) {
    return FutureBuilder<String>(
      future: getAvatarUrl(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildPlaceholder(size: size);
        }

        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          return GestureDetector(
            onTap: onTap,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: FanColors.primary.withValues(alpha: 0.3), // ✅ Changed
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: Image.network(
                  snapshot.data!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return _buildPlaceholder(size: size, showProgress: true);
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return _buildInitialsAvatar(username: username, size: size);
                  },
                ),
              ),
            ),
          );
        }

        return _buildInitialsAvatar(username: username, size: size);
      },
    );
  }

  static Widget _buildPlaceholder({
    required double size,
    bool showProgress = false,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: FanColors.background, // ✅ Changed
        border: Border.all(
          color: FanColors.primary.withValues(alpha: 0.2), // ✅ Changed
          width: 1,
        ),
      ),
      child: Center(
        child: showProgress
            ? SizedBox(
                width: size * 0.4,
                height: size * 0.4,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: FanColors.primary, // ✅ Changed
                ),
              )
            : Text(
                '⚽',
                style: TextStyle(
                  fontSize: size * 0.5,
                  color: FanColors.primary, // ✅ Changed
                ),
              ),
      ),
    );
  }

  static Widget _buildInitialsAvatar({
    required String? username,
    required double size,
  }) {
    final initials = _getInitials(username);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: FanColors.background, // ✅ Changed
        border: Border.all(
          color: FanColors.primary.withValues(alpha: 0.3), // ✅ Changed
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: FanColors.primary, // ✅ Changed
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }
}

// ========== NEW MODELS FOR COMRADE SYSTEM ==========

class ComradeWithProfile {
  final String userId;
  final String username;
  final String nickname;
  final String clubFan;
  final String countryFan;
  final String selection;
  final DateTime votedAt;
  final String? comment;

  ComradeWithProfile({
    required this.userId,
    required this.username,
    required this.nickname,
    required this.clubFan,
    required this.countryFan,
    required this.selection,
    required this.votedAt,
    this.comment,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'nickname': nickname,
      'clubFan': clubFan,
      'countryFan': countryFan,
      'selection': selection,
      'votedAt': votedAt.toIso8601String(),
      'comment': comment,
    };
  }

  factory ComradeWithProfile.fromJson(Map<String, dynamic> json) {
    return ComradeWithProfile(
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      nickname: json['nickname'] ?? '',
      clubFan: json['clubFan'] ?? '',
      countryFan: json['countryFan'] ?? '',
      selection: json['selection'] ?? '',
      votedAt: DateTime.parse(
        json['votedAt'] ?? DateTime.now().toIso8601String(),
      ),
      comment: json['comment'],
    );
  }
}

class FixtureNotificationState {
  final String fixtureId;
  int newVotes;
  int newComments;
  int newLikes;
  DateTime lastViewed;
  Set<String> seenVoteIds;
  Set<String> seenCommentIds;
  Set<String> seenLikeIds;

  FixtureNotificationState({
    required this.fixtureId,
    this.newVotes = 0,
    this.newComments = 0,
    this.newLikes = 0,
    required this.lastViewed,
    this.seenVoteIds = const {},
    this.seenCommentIds = const {},
    this.seenLikeIds = const {},
  });

  int get totalNew => newVotes + newComments + newLikes;

  factory FixtureNotificationState.fromJson(Map<String, dynamic> json) {
    return FixtureNotificationState(
      fixtureId: json['fixtureId'] ?? '',
      newVotes: json['newVotes'] ?? 0,
      newComments: json['newComments'] ?? 0,
      newLikes: json['newLikes'] ?? 0,
      lastViewed: DateTime.parse(
        json['lastViewed'] ?? DateTime.now().toIso8601String(),
      ),
      seenVoteIds: Set<String>.from(json['seenVoteIds'] ?? []),
      seenCommentIds: Set<String>.from(json['seenCommentIds'] ?? []),
      seenLikeIds: Set<String>.from(json['seenLikeIds'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fixtureId': fixtureId,
      'newVotes': newVotes,
      'newComments': newComments,
      'newLikes': newLikes,
      'lastViewed': lastViewed.toIso8601String(),
      'seenVoteIds': seenVoteIds.toList(),
      'seenCommentIds': seenCommentIds.toList(),
      'seenLikeIds': seenLikeIds.toList(),
    };
  }
}

// ========== FEATURED COMMENT MODEL ==========
class FeaturedComment {
  final String userId;
  final String username;
  final String comment;
  final String teamSupport;
  final String avatarUrl;
  final DateTime timestamp;

  FeaturedComment({
    required this.userId,
    required this.username,
    required this.comment,
    required this.teamSupport,
    required this.avatarUrl,
    required this.timestamp,
  });
}

// ========== COMMENT MODEL ==========
class FixtureComment {
  final String id;
  final String userId;
  final String username;
  final String fixtureId;
  final String comment;
  final String? selection;
  final DateTime timestamp;

  FixtureComment({
    required this.id,
    required this.userId,
    required this.username,
    required this.fixtureId,
    required this.comment,
    this.selection,
    required this.timestamp,
  });

  factory FixtureComment.fromJson(Map<String, dynamic> json) {
    String id = '';
    if (json['_id'] != null) {
      if (json['_id'] is Map) {
        id = json['_id']['\$oid'] ?? json['_id']['oid'] ?? '';
      } else if (json['_id'] is String) {
        id = json['_id'];
      }
    }

    DateTime timestamp;
    try {
      timestamp = DateTime.parse(
        json['timestamp'] ??
            json['createdAt'] ??
            DateTime.now().toIso8601String(),
      );
    } catch (e) {
      timestamp = DateTime.now();
    }

    return FixtureComment(
      id: id,
      userId: json['voterId']?.toString() ?? json['userId']?.toString() ?? '',
      username: json['username']?.toString() ?? 'Anonymous',
      fixtureId: json['fixtureId']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
      selection: json['selection']?.toString(),
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'fixtureId': fixtureId,
      'comment': comment,
      'selection': selection,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

// ========== SUB-FIXTURE VOTE MODELS ==========
class SubFixtureVote {
  final String id;
  final String voterId;
  final String username;
  final String subFixtureId;
  final String parentFixtureId;
  final String selection;
  final DateTime votedAt;

  SubFixtureVote({
    required this.id,
    required this.voterId,
    required this.username,
    required this.subFixtureId,
    required this.parentFixtureId,
    required this.selection,
    required this.votedAt,
  });

  factory SubFixtureVote.fromJson(Map<String, dynamic> json) {
    return SubFixtureVote(
      id: json['_id']?.toString() ?? '',
      voterId: json['voterId']?.toString() ?? '',
      username: json['username']?.toString() ?? 'Anonymous',
      subFixtureId: json['subFixtureId']?.toString() ?? '',
      parentFixtureId: json['parentFixtureId']?.toString() ?? '',
      selection: json['selection']?.toString() ?? '',
      votedAt: DateTime.parse(
        json['votedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class SubFixtureVoteData {
  final String subFixtureId;
  final String question;
  final Map<String, int> voteCounts;
  final String? currentUserSelection;
  final List<VoteUser> supporters;
  final List<VoteUser> rivals;

  SubFixtureVoteData({
    required this.subFixtureId,
    required this.question,
    required this.voteCounts,
    this.currentUserSelection,
    this.supporters = const [],
    this.rivals = const [],
  });

  int get totalVotes => voteCounts.values.fold(0, (sum, count) => sum + count);
}

// ========== VOTE MODELS ==========
class Vote {
  final String id;
  final String voterId;
  final String username;
  final String fixtureId;
  final String homeTeam;
  final String awayTeam;
  final String selection;
  final DateTime voteTimestamp;
  final DateTime createdAt;

  Vote({
    required this.id,
    required this.voterId,
    required this.username,
    required this.fixtureId,
    required this.homeTeam,
    required this.awayTeam,
    required this.selection,
    required this.voteTimestamp,
    required this.createdAt,
  });

  factory Vote.fromJson(Map<String, dynamic> json) {
    String id = '';
    if (json['_id'] != null) {
      if (json['_id'] is Map) {
        id = json['_id']['\$oid'] ?? json['_id']['oid'] ?? '';
      } else if (json['_id'] is String) {
        id = json['_id'];
      }
    }

    DateTime voteTimestamp;
    try {
      // ✅ Handle BOTH camelCase AND snake_case
      final timestampStr = json['voteTimestamp']?.toString() ??
          json['vote_timestamp']?.toString() ??
          json['createdAt']?.toString() ??
          DateTime.now().toIso8601String();
      voteTimestamp = DateTime.parse(timestampStr);
    } catch (e) {
      voteTimestamp = DateTime.now();
    }

    DateTime createdAt;
    try {
      final createdAtStr = json['createdAt']?.toString() ??
          json['created_at']?.toString() ??
          json['voteTimestamp']?.toString() ??
          json['vote_timestamp']?.toString() ??
          DateTime.now().toIso8601String();
      createdAt = DateTime.parse(createdAtStr);
    } catch (e) {
      createdAt = DateTime.now();
    }

    return Vote(
      id: id,
      // ✅ Handle BOTH camelCase AND snake_case
      voterId:
          json['voterId']?.toString() ?? json['voter_id']?.toString() ?? '',
      username: json['username']?.toString() ?? 'Unknown',
      fixtureId:
          json['fixtureId']?.toString() ?? json['fixture_id']?.toString() ?? '',
      homeTeam:
          json['homeTeam']?.toString() ?? json['home_team']?.toString() ?? '',
      awayTeam:
          json['awayTeam']?.toString() ?? json['away_team']?.toString() ?? '',
      selection: json['selection']?.toString() ?? '',
      voteTimestamp: voteTimestamp,
      createdAt: createdAt,
    );
  }
}

class VoteUser {
  final String userId;
  final String username;
  final String selection;
  final DateTime votedAt;

  VoteUser({
    required this.userId,
    required this.username,
    required this.selection,
    required this.votedAt,
  });

  factory VoteUser.fromVote(Vote vote) {
    return VoteUser(
      userId: vote.voterId,
      username: vote.username,
      selection: vote.selection,
      votedAt: vote.voteTimestamp,
    );
  }
}

class FixtureVoteData {
  final String fixtureId;
  final String homeTeam;
  final String awayTeam;
  final String? currentUserSelection;
  final List<VoteUser> supporters;
  final List<VoteUser> rivals;

  FixtureVoteData({
    required this.fixtureId,
    required this.homeTeam,
    required this.awayTeam,
    this.currentUserSelection,
    this.supporters = const [],
    this.rivals = const [],
  });

  int get supporterCount => supporters.length;
  int get rivalCount => rivals.length;
  bool get hasCurrentUserVoted => currentUserSelection != null;

  FixtureVoteData copyWith({
    String? currentUserSelection,
    List<VoteUser>? supporters,
    List<VoteUser>? rivals,
  }) {
    return FixtureVoteData(
      fixtureId: fixtureId,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      currentUserSelection: currentUserSelection ?? this.currentUserSelection,
      supporters: supporters ?? this.supporters,
      rivals: rivals ?? this.rivals,
    );
  }
}

// ========== RUST RESPONSE MODELS ==========
class RustVoteResponse {
  final bool success;
  final String message;
  final String? voteId;
  final Map<String, dynamic>? data;

  RustVoteResponse({
    required this.success,
    required this.message,
    this.voteId,
    this.data,
  });

  factory RustVoteResponse.fromJson(Map<String, dynamic> json) {
    return RustVoteResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      voteId: json['voteId'],
      data: json['data'],
    );
  }
}

class RustSubFixtureVoteResponse {
  final bool success;
  final String message;
  final String? voteId;
  final Map<String, dynamic>? data;

  RustSubFixtureVoteResponse({
    required this.success,
    required this.message,
    this.voteId,
    this.data,
  });

  factory RustSubFixtureVoteResponse.fromJson(Map<String, dynamic> json) {
    return RustSubFixtureVoteResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      voteId: json['voteId'],
      data: json['data'],
    );
  }
}

class RustLikeResponse {
  final bool success;
  final String message;
  final String? likeId;
  final int totalLikes;

  RustLikeResponse({
    required this.success,
    required this.message,
    this.likeId,
    required this.totalLikes,
  });

  factory RustLikeResponse.fromJson(Map<String, dynamic> json) {
    return RustLikeResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      likeId: json['likeId'],
      totalLikes: json['totalLikes'] ?? 0,
    );
  }
}

class RustCommentResponse {
  final bool success;
  final String message;
  final String? commentId;
  final Map<String, dynamic>? comment;

  RustCommentResponse({
    required this.success,
    required this.message,
    this.commentId,
    this.comment,
  });

  factory RustCommentResponse.fromJson(Map<String, dynamic> json) {
    return RustCommentResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      commentId: json['commentId'],
      comment: json['comment'],
    );
  }
}

class VoteStatsResponse {
  final String fixtureId;
  final String homeTeam;
  final String awayTeam;
  final int totalVotes;
  final int homeVotes;
  final int drawVotes;
  final int awayVotes;
  final double homePercentage;
  final double drawPercentage;
  final double awayPercentage;

  VoteStatsResponse({
    required this.fixtureId,
    required this.homeTeam,
    required this.awayTeam,
    required this.totalVotes,
    required this.homeVotes,
    required this.drawVotes,
    required this.awayVotes,
    required this.homePercentage,
    required this.drawPercentage,
    required this.awayPercentage,
  });

  factory VoteStatsResponse.fromJson(Map<String, dynamic> json) {
    return VoteStatsResponse(
      fixtureId: json['fixtureId'] ?? json['fixture_id'] ?? '',
      homeTeam: json['homeTeam'] ?? json['home_team'] ?? '',
      awayTeam: json['awayTeam'] ?? json['away_team'] ?? '',
      totalVotes: json['totalVotes'] ?? json['total_votes'] ?? 0,
      homeVotes: json['homeVotes'] ?? json['home_votes'] ?? 0,
      drawVotes: json['drawVotes'] ?? json['draw_votes'] ?? 0,
      awayVotes: json['awayVotes'] ?? json['away_votes'] ?? 0,
      homePercentage:
          (json['homePercentage'] ?? json['home_percentage'] ?? 0.0).toDouble(),
      drawPercentage:
          (json['drawPercentage'] ?? json['draw_percentage'] ?? 0.0).toDouble(),
      awayPercentage:
          (json['awayPercentage'] ?? json['away_percentage'] ?? 0.0).toDouble(),
    );
  }
}

class LikeStatsResponse {
  final String fixtureId;
  final int totalLikes;
  final bool userHasLiked;

  LikeStatsResponse({
    required this.fixtureId,
    required this.totalLikes,
    required this.userHasLiked,
  });

  factory LikeStatsResponse.fromJson(Map<String, dynamic> json) {
    return LikeStatsResponse(
      fixtureId: json['fixtureId'] ?? json['fixture_id'] ?? '',
      totalLikes: json['totalLikes'] ?? json['total_likes'] ?? 0,
      userHasLiked: json['userHasLiked'] ?? json['user_has_liked'] ?? false,
    );
  }
}

// ========== VOTE SERVICE ==========
// ========== IMPORT YOUR MODEL CLASSES ==========
// Make sure these are imported from your models files
// import '../models/fixture_models.dart';
// import '../modals/Funzy/comrades_modal.dart';

class VoteService {
  static const String API_BASE_URL = 'https://clash-api-m5mr.onrender.com/api';
  static const Duration REQUEST_TIMEOUT = Duration(seconds: 15);

  // ==========================================================================
  // FIXTURE-BASED VOTING (NEW - No votes collection)
  // ==========================================================================

  /// Cast a vote on a fixture (stores in fixtures.voters array)
  // In VoteService class - UPDATE these methods

  /// Cast a vote (GLOBAL - No channel_id)
  /// Cast a vote (GLOBAL - No channel_id)
  static Future<Map<String, dynamic>> castVote({
    required String fixtureId,
    required String userId,
    required String username,
    required String selection, // "home", "away", "draw"
    String? authToken,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/actions/vote/cast'),
            headers: headers,
            body: json.encode({
              'fixture_id': fixtureId,
              'user_id': userId,
              'username': username,
              'selection': selection,
            }),
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      return {
        'success': false,
        'message': 'Server error: ${response.statusCode}'
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Check if user voted (GLOBAL)
  static Future<Map<String, dynamic>> checkUserVoted(
    String fixtureId,
    String userId, {
    String? authToken,
  }) async {
    try {
      final headers = {'Content-Type': 'application/json'};
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      // ✅ NEW ENDPOINT: /api/actions/vote/check/:fixture_id/:user_id
      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/actions/vote/check/$fixtureId/$userId'),
            headers: headers,
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'has_voted': false, 'selection': null};
    } catch (e) {
      return {'has_voted': false, 'selection': null};
    }
  }

  /// Get fixture voters (GLOBAL)
  static Future<Map<String, dynamic>> getFixtureVoters(
    String fixtureId, {
    String? authToken,
  }) async {
    try {
      final headers = {'Content-Type': 'application/json'};
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      // ✅ NEW ENDPOINT: /api/actions/vote/fixture/:fixture_id/voters
      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/actions/vote/fixture/$fixtureId/voters'),
            headers: headers,
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'voters': [], 'total_votes': 0};
    } catch (e) {
      return {'success': false, 'voters': [], 'total_votes': 0};
    }
  }

  /// Get all voters for a fixture (from fixtures.voters array)

  /// Get fast vote count for a fixture (from fixtures.votes)
  static Future<int> getFastVoteCount(String fixtureId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/games/fixture/$fixtureId/counts/fast'),
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['votes'] ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('❌ Error getting fast vote count: $e');
      return 0;
    }
  }

  /// Get fast vote counts for multiple fixtures (batch)
  static Future<Map<String, int>> getFastBatchVoteCounts(
    List<String> fixtureIds,
  ) async {
    if (fixtureIds.isEmpty) return {};

    try {
      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/games/fixture/counts/batch'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(fixtureIds),
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final Map<String, int> counts = {};
        if (data['data'] is List) {
          for (var item in data['data']) {
            counts[item['fixture_id']] = item['votes'] ?? 0;
          }
        }
        return counts;
      }
      return {};
    } catch (e) {
      debugPrint('❌ Error getting batch counts: $e');
      return {};
    }
  }

  /// Check if a user has voted on a fixture (from fixtures.voters)

  // ==========================================================================
  // DEPRECATED METHODS (Keep for backward compatibility, but mark as deprecated)
  // These methods query the old 'votes' collection - avoid using them
  // ==========================================================================

  @Deprecated('Use castVote() instead - this uses the old votes collection')
  static Future<List<Vote>> fetchAllVotes() async {
    try {
      debugPrint('📤 Fetching all votes from database...');
      final response = await http.get(
        Uri.parse('$API_BASE_URL/votes/votes'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        List<Vote> votes = [];

        if (jsonData is Map<String, dynamic>) {
          if (jsonData['success'] == true && jsonData['data'] is List) {
            final dataList = jsonData['data'] as List;
            votes = dataList.map((item) => Vote.fromJson(item)).toList();
          } else if (jsonData['votes'] is List) {
            final dataList = jsonData['votes'] as List;
            votes = dataList.map((item) => Vote.fromJson(item)).toList();
          }
        } else if (jsonData is List) {
          votes = jsonData.map((item) => Vote.fromJson(item)).toList();
        }

        debugPrint('✅ Fetched ${votes.length} votes from database');
        return votes;
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching votes: $e');
      return [];
    }
  }

  @Deprecated(
      'Use checkUserVoted() instead - this uses the old votes collection')
  static Future<Map<String, String>> fetchUserVotes(String userId) async {
    try {
      debugPrint('🔄 Fetching user votes for: $userId');
      final response = await http.get(
        Uri.parse('$API_BASE_URL/votes/votes/user/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final dynamic jsonData = json.decode(response.body);
        final Map<String, String> userVotes = {};

        if (jsonData is List) {
          for (var vote in jsonData) {
            if (vote is Map) {
              final fixtureId = vote['fixtureId']?.toString() ??
                  vote['fixture_id']?.toString() ??
                  '';
              final selection = vote['selection']?.toString() ?? '';
              if (fixtureId.isNotEmpty && selection.isNotEmpty) {
                userVotes[fixtureId] = selection;
              }
            }
          }
        } else if (jsonData is Map && jsonData['data'] is List) {
          for (var vote in jsonData['data']) {
            final fixtureId = vote['fixtureId']?.toString() ??
                vote['fixture_id']?.toString() ??
                '';
            final selection = vote['selection']?.toString() ?? '';
            if (fixtureId.isNotEmpty && selection.isNotEmpty) {
              userVotes[fixtureId] = selection;
            }
          }
        }

        debugPrint('✅ Parsed ${userVotes.length} user votes');
        return userVotes;
      }
      return {};
    } catch (e) {
      debugPrint('❌ Error fetching user votes: $e');
      return {};
    }
  }

  @Deprecated(
      'Use checkUserVoted() instead - this uses the old votes collection')
  static Future<Map<String, String>> fetchUserVotesGlobal(String userId) async {
    try {
      debugPrint('📤 Fetching global votes for user: $userId');
      final response = await http.get(
        Uri.parse('$API_BASE_URL/channels/votes/user/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final Map<String, String> votes = {};

        if (jsonData['votes'] is List) {
          for (var vote in jsonData['votes']) {
            final fixtureId = vote['fixture_id']?.toString() ?? '';
            final selection = vote['selection']?.toString() ?? '';
            if (fixtureId.isNotEmpty && selection.isNotEmpty) {
              votes[fixtureId] = selection;
            }
          }
        } else if (jsonData is List) {
          for (var vote in jsonData) {
            if (vote is Map) {
              final fixtureId = vote['fixtureId']?.toString() ??
                  vote['fixture_id']?.toString() ??
                  '';
              final selection = vote['selection']?.toString() ?? '';
              if (fixtureId.isNotEmpty && selection.isNotEmpty) {
                votes[fixtureId] = selection;
              }
            }
          }
        }

        debugPrint('✅ Fetched ${votes.length} global votes');
        return votes;
      }
      return {};
    } catch (e) {
      debugPrint('❌ Error fetching global votes: $e');
      return {};
    }
  }

  @Deprecated('Use getFixtureVoters() instead')
  static Future<Map<String, String>> fetchVoteDataForFixtures(
    String userId,
    List<String> fixtureIds,
  ) async {
    try {
      debugPrint('📤 Fetching votes for ${fixtureIds.length} fixtures');
      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/votes/batch'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({'user_id': userId, 'fixture_ids': fixtureIds}),
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final Map<String, String> votes = {};

        if (jsonData['success'] == true && jsonData['data'] is Map) {
          final data = jsonData['data'] as Map;
          data.forEach((fixtureId, selection) {
            votes[fixtureId.toString()] = selection.toString();
          });
        }
        return votes;
      }
      return {};
    } catch (e) {
      debugPrint('❌ Error in batch vote fetch: $e');
      return {};
    }
  }

  @Deprecated('Use getFixtureVoters() instead')
  static Map<String, FixtureVoteData> organizeVotesByFixture(
    List<Vote> allVotes,
    String currentUserId,
  ) {
    final Map<String, FixtureVoteData> fixtureData = {};

    final Map<String, String> userVotes = {};
    for (var vote in allVotes) {
      if (vote.voterId == currentUserId) {
        userVotes[vote.fixtureId] = vote.selection;
      }
    }

    for (var vote in allVotes) {
      if (vote.voterId == currentUserId) continue;

      final fixtureId = vote.fixtureId;
      final userSelection = userVotes[fixtureId];

      if (!fixtureData.containsKey(fixtureId)) {
        fixtureData[fixtureId] = FixtureVoteData(
          fixtureId: fixtureId,
          homeTeam: vote.homeTeam,
          awayTeam: vote.awayTeam,
          currentUserSelection: userSelection,
        );
      }

      final fixtureVoteData = fixtureData[fixtureId]!;
      final voteUser = VoteUser.fromVote(vote);

      if (userSelection != null) {
        if (vote.selection == userSelection) {
          final updatedSupporters = [...fixtureVoteData.supporters, voteUser];
          fixtureData[fixtureId] = fixtureVoteData.copyWith(
            supporters: updatedSupporters,
          );
        } else {
          final updatedRivals = [...fixtureVoteData.rivals, voteUser];
          fixtureData[fixtureId] = fixtureVoteData.copyWith(
            rivals: updatedRivals,
          );
        }
      }
    }

    return fixtureData;
  }

  // ==========================================================================
  // SUB-FIXTURE VOTES (Keep as is - these are for prop bets)
  // ==========================================================================

  static Future<List<SubFixtureVote>> fetchSubFixtureVotes(
    String parentFixtureId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/votes/sub-fixtures/$parentFixtureId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        List<SubFixtureVote> votes = [];

        if (jsonData is Map &&
            jsonData['success'] == true &&
            jsonData['data'] is List) {
          votes = (jsonData['data'] as List)
              .map((item) => SubFixtureVote.fromJson(item))
              .toList();
        }

        debugPrint('✅ Fetched ${votes.length} sub-fixture votes');
        return votes;
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching sub-fixture votes: $e');
      return [];
    }
  }

  static Future<RustSubFixtureVoteResponse?> submitSubFixtureVote({
    required String userId,
    required String username,
    required String subFixtureId,
    required String parentFixtureId,
    required String selection,
    String? authToken,
  }) async {
    try {
      final voteData = {
        'voterId': userId,
        'username': username,
        'subFixtureId': subFixtureId,
        'parentFixtureId': parentFixtureId,
        'selection': selection,
        'votedAt': DateTime.now().toUtc().toIso8601String(),
      };

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/votes/sub-fixture'),
            headers: headers,
            body: json.encode(voteData),
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = json.decode(response.body);
        return RustSubFixtureVoteResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        debugPrint('❌ Authentication failed - invalid or missing auth token');
        return RustSubFixtureVoteResponse(
          success: false,
          message: 'Authentication failed. Please log in again.',
        );
      } else {
        debugPrint('❌ Server returned error: ${response.statusCode}');
        return RustSubFixtureVoteResponse(
          success: false,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } on TimeoutException catch (_) {
      debugPrint('❌ Sub-fixture vote timeout');
      return RustSubFixtureVoteResponse(
        success: false,
        message: 'Connection timeout. Please check your internet.',
      );
    } catch (e) {
      debugPrint('❌ Error submitting sub-fixture vote: $e');
      return RustSubFixtureVoteResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  static SubFixtureVoteData organizeSubFixtureVotes(
    List<SubFixtureVote> allVotes,
    String currentUserId,
    SubFixture subFixture,
  ) {
    String? currentUserSelection;
    try {
      final userVote = allVotes.firstWhere(
        (v) => v.voterId == currentUserId && v.subFixtureId == subFixture.id,
      );
      currentUserSelection = userVote.selection;
    } catch (e) {
      currentUserSelection = null;
    }

    Map<String, int> counts = {};
    List<VoteUser> supporters = [];
    List<VoteUser> rivals = [];

    counts[subFixture.optionA] = 0;
    counts[subFixture.optionB] = 0;
    if (subFixture.optionC != null) {
      counts[subFixture.optionC!] = 0;
    }

    for (var vote in allVotes.where((v) => v.subFixtureId == subFixture.id)) {
      counts[vote.selection] = (counts[vote.selection] ?? 0) + 1;

      if (vote.voterId == currentUserId) continue;

      final voteUser = VoteUser(
        userId: vote.voterId,
        username: vote.username,
        selection: vote.selection,
        votedAt: vote.votedAt,
      );

      if (currentUserSelection != null) {
        if (vote.selection == currentUserSelection) {
          supporters.add(voteUser);
        } else {
          rivals.add(voteUser);
        }
      }
    }

    return SubFixtureVoteData(
      subFixtureId: subFixture.id,
      question: subFixture.question,
      voteCounts: counts,
      currentUserSelection: currentUserSelection,
      supporters: supporters,
      rivals: rivals,
    );
  }

  // ==========================================================================
  // COMMENTS (Keep as is - these are for messages)
  // ==========================================================================

  static Future<List<FixtureComment>> fetchAllCommentsForFixture(
    String fixtureId, {
    String? authToken,
    String? channelId,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      if (channelId == null) return [];

      final response = await http
          .get(
            Uri.parse(
                '$API_BASE_URL/channels/$channelId/messages?fixture_id=$fixtureId&limit=100'),
            headers: headers,
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final messagesList = jsonData['messages'] ?? [];

        final List<FixtureComment> comments = [];
        for (var item in messagesList) {
          if (item is Map) {
            String id = item['message_id'] ?? '';
            if (id.isEmpty) {
              final idObj = item['_id'];
              if (idObj is Map && idObj['\$oid'] != null) {
                id = idObj['\$oid'];
              }
            }

            comments.add(FixtureComment(
              id: id,
              userId: item['sender_id']?.toString() ?? '',
              username: item['sender_name']?.toString() ?? 'Anonymous',
              fixtureId: fixtureId,
              comment: item['text']?.toString() ?? '',
              selection: item['selection']?.toString(),
              timestamp: DateTime.parse(item['sent_at']?['\$date'] ??
                  item['sent_at']?.toString() ??
                  DateTime.now().toIso8601String()),
            ));
          }
        }

        comments.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return comments;
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching comments for fixture $fixtureId: $e');
      return [];
    }
  }

  static Future<Map<String, VoteStatsResponse>> fetchVoteStatsBatch(
    List<String> fixtureIds,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/votes/stats/batch'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({'fixture_ids': fixtureIds}),
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final Map<String, VoteStatsResponse> stats = {};

        if (jsonData['success'] == true && jsonData['data'] is Map) {
          final data = jsonData['data'] as Map;
          data.forEach((fixtureId, statData) {
            stats[fixtureId.toString()] = VoteStatsResponse.fromJson(
              statData as Map<String, dynamic>,
            );
          });
        }

        debugPrint('✅ Fetched stats for ${stats.length} fixtures');
        return stats;
      }
      return {};
    } catch (e) {
      debugPrint('⚠️ Error fetching batch vote stats: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> rollbackVote({
    required String fixtureId,
    required String userId,
    String? authToken,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/vote/rollback'),
            headers: headers,
            body: json.encode({
              'fixture_id': fixtureId,
              'user_id': userId,
            }),
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {
        'success': false,
        'message': 'Server error: ${response.statusCode}'
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // ==========================================================================
  // DEPRECATED CHANNEL VOTE METHODS (Legacy)
  // ==========================================================================

  @Deprecated('Use checkUserVoted() instead - this is legacy')
  static Future<Map<String, String>> fetchUserChannelVotes(
    String userId,
    String channelId,
  ) async {
    // Redirect to deprecated method - channelId is ignored
    return fetchUserVotesGlobal(userId);
  }
}

// ========== COMMENT SERVICE ==========
class CommentService {
  static const String API_BASE_URL = 'https://clash-api-m5mr.onrender.com/api';
  static const Duration REQUEST_TIMEOUT = Duration(seconds: 15);

  static Future<List<FixtureComment>> fetchCommentsForFixture(
    String fixtureId, {
    int limit = 100,
    String? authToken,
    String? channelId, // ADD THIS
    bool forceRefresh = false,
  }) async {
    final cached = await LocalStorageManager.loadCommentsForFixture(fixtureId);

    final lastFetched =
        await LocalStorageManager.getCommentsLastFetched(fixtureId);
    final cacheAge = lastFetched != null
        ? DateTime.now().millisecondsSinceEpoch - lastFetched
        : 999999999;
    final isCacheStale = cacheAge > const Duration(minutes: 2).inMilliseconds;

    if (!forceRefresh && !isCacheStale && cached.isNotEmpty) {
      debugPrint('📦 Returning ${cached.length} cached comments');
      return cached;
    }

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      if (channelId == null) return cached;

      final response = await http
          .get(
            Uri.parse(
                '$API_BASE_URL/channels/$channelId/messages?fixture_id=$fixtureId&limit=$limit'),
            headers: headers,
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final messagesList = jsonData['messages'] ?? [];

        final List<FixtureComment> freshComments = [];
        for (var item in messagesList) {
          if (item is Map) {
            String id = item['message_id'] ?? '';
            if (id.isEmpty) {
              final idObj = item['_id'];
              if (idObj is Map && idObj['\$oid'] != null) {
                id = idObj['\$oid'];
              }
            }

            freshComments.add(FixtureComment(
              id: id,
              userId: item['sender_id']?.toString() ?? '',
              username: item['sender_name']?.toString() ?? 'Anonymous',
              fixtureId: fixtureId,
              comment: item['text']?.toString() ?? '',
              selection: item['selection']?.toString(),
              timestamp: DateTime.parse(item['sent_at']?['\$date'] ??
                  item['sent_at']?.toString() ??
                  DateTime.now().toIso8601String()),
            ));
          }
        }

        freshComments.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        await LocalStorageManager.saveCommentsForFixture(
            fixtureId, freshComments);
        return freshComments;
      }
      return cached;
    } catch (e) {
      debugPrint('❌ Error fetching comments: $e — returning cache');
      return cached;
    }
  }

// Add this new method to get ONLY comment count (fast)
  static Future<int> getCommentCountOnly(String fixtureId,
      {String? authToken}) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/votes/comments/fixture/$fixtureId/total'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['total'] ?? data['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('❌ Error getting comment count: $e');
      return 0;
    }
  }

  static Future<RustCommentResponse?> postComment({
    required String userId,
    required String username,
    required String fixtureId,
    required String comment,
    String? selection,
    String? authToken,
    String? channelId, // NEW: Add channelId parameter
  }) async {
    try {
      debugPrint('📤 ========== POST COMMENT ==========');
      debugPrint('📤 userId: $userId');
      debugPrint('📤 username: $username');
      debugPrint('📤 fixtureId: $fixtureId');
      debugPrint('📤 comment: $comment');
      debugPrint('📤 selection: $selection');
      debugPrint('📤 channelId: $channelId');

      if (channelId == null) {
        debugPrint('❌ No channelId provided');
        return RustCommentResponse(
          success: false,
          message: 'No channel selected',
        );
      }

      // ============================================================
      // UPDATED: Use chat endpoint with channel_id
      // ============================================================
      final messageData = {
        'channel_id': channelId,
        'fixture_id': fixtureId,
        'user_id': userId,
        'username': username,
        'text': comment.trim(),
        'selection': selection,
        'image_url': null,
        'video_url': null,
        'is_image': false,
        'is_video': false,
        'reply_to_message_id': null,
        'reply_to_text': null,
        'reply_to_username': null,
        'reply_to_selection': null,
        'temp_id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      };

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      debugPrint('📤 POSTING to: ${_getChatEndpoint()}');
      debugPrint('📤 Request body: ${jsonEncode(messageData)}');

      final response = await http
          .post(
            Uri.parse(_getChatEndpoint()),
            headers: headers,
            body: json.encode(messageData),
          )
          .timeout(REQUEST_TIMEOUT);

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = json.decode(response.body);
        debugPrint('✅ Comment posted successfully');

        // Send via WebSocket for real-time updates
        final ws = WebSocketService();
        if (ws.isConnected) {
          ws.send('chat.message', {
            'channelId': channelId,
            'fixtureId': fixtureId,
            'userId': userId,
            'username': username,
            'message': comment.trim(),
            'selection': selection,
            'messageId': jsonData['message_id'] ?? jsonData['id'],
            'tempId': jsonData['temp_id'],
            'timestamp': DateTime.now().toIso8601String(),
          });
        }

        return RustCommentResponse(
          success: true,
          message: 'Comment posted successfully',
          commentId: jsonData['message_id'] ?? jsonData['id'],
          comment: jsonData,
        );
      } else if (response.statusCode == 401) {
        debugPrint('❌ Authentication failed');
        return RustCommentResponse(
          success: false,
          message: 'Authentication failed. Please log in again.',
        );
      } else {
        debugPrint('❌ Server error: ${response.statusCode}');
        return RustCommentResponse(
          success: false,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('❌ Exception: $e');
      return RustCommentResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

// NEW: Helper to get chat endpoint
  static String _getChatEndpoint() {
    return '$API_BASE_URL/channels/messages';
  }

  static Future<Map<String, List<FixtureComment>>> fetchAllCommentsBulk({
    String? authToken,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/votes/comments/recent?perFixture=2'),
            headers: headers,
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final Map<String, List<FixtureComment>> result = {};

        if (jsonData is Map && jsonData['success'] == true) {
          final data = jsonData['data'];
          if (data is Map) {
            data.forEach((fixtureId, commentsList) {
              if (commentsList is List) {
                result[fixtureId.toString()] = commentsList
                    .map((c) => FixtureComment.fromJson(c))
                    .toList();
              }
            });
          }
        }

        return result;
      }
      return {};
    } catch (e) {
      debugPrint('❌ Error fetching all comments: $e');
      return {};
    }
  }
}

// ========== LOCAL STORAGE MANAGER ==========
// ========== LOCAL STORAGE MANAGER ==========
// ========== LOCAL STORAGE MANAGER - COMPLETE ==========
class LocalStorageManager {
  static const String _votesBaseKey = 'user_votes';
  static const String _subFixtureVotesBaseKey = 'user_sub_fixture_votes';
  static const String _likesBaseKey = 'user_likes';
  static const String _metadataKey = 'game_metadata';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _serverTimestampKey = 'server_timestamp';
  static const String _fixturesCacheKey = 'fixtures_cache';
  static const String _fixturesTimestampKey = 'fixtures_timestamp';
  static const String _fixturesEtagKey = 'fixtures_etag';
  static const String _authTokenKey = 'auth_token';
  static const String _commentersKey = 'commenters_cache';
  static const String _notificationsKey = 'fixture_notifications';
  static const String _commentCountsKey = 'comment_counts_cache';
  static const String _voteCountsKey = 'vote_counts_cache';

  // Comment cache keys
  static const String _commentsCacheKeyPrefix = 'cached_comments_';
  static const String _commentsCacheTimestampPrefix = 'cached_comments_ts_';

  // Comrade storage keys
  static const String _userComradesKey = 'user_comrades_cache';
  static const String _comradeVotersKey = 'comrade_voters_cache';
  static const String _userComradesTimestampKey = 'user_comrades_timestamp';
  static const Duration _comradesCacheDuration = Duration(minutes: 5);

  static Future<SharedPreferences> get _prefs async {
    return await SharedPreferences.getInstance();
  }

  // ========== COMMENT COUNT CACHING ==========

  // Add to LocalStorageManager class
  // OLD

// NEW (remove channelId)
  // ========== UPDATED: Remove channelId from saveVote ==========
  // Add to LocalStorageManager class
  static const String _perChannelVoteCountsKey =
      'per_channel_vote_counts_cache';

  static Future<void> savePerChannelVoteCount(
      String fixtureId, String channelId, int count) async {
    try {
      final prefs = await _prefs;
      final cacheKey = '${_perChannelVoteCountsKey}_${channelId}_$fixtureId';
      await prefs.setInt(cacheKey, count);
      debugPrint(
          '💾 Saved vote count $count for fixture $fixtureId in channel $channelId');
    } catch (e) {
      debugPrint('⚠️ Error saving per-channel vote count: $e');
    }
  }

  static Future<int?> getPerChannelVoteCount(
      String fixtureId, String channelId) async {
    try {
      final prefs = await _prefs;
      final cacheKey = '${_perChannelVoteCountsKey}_${channelId}_$fixtureId';
      return prefs.getInt(cacheKey);
    } catch (e) {
      debugPrint('⚠️ Error loading per-channel vote count: $e');
      return null;
    }
  }

  static Future<void> clearPerChannelVoteCounts() async {
    try {
      final prefs = await _prefs;
      final keys = prefs.getKeys();
      for (var key in keys) {
        if (key.startsWith(_perChannelVoteCountsKey)) {
          await prefs.remove(key);
        }
      }
      debugPrint('✅ Cleared all per-channel vote counts');
    } catch (e) {
      debugPrint('⚠️ Error clearing vote counts: $e');
    }
  }

  // In LocalStorageManager class - Add this method

  static Future<List<Fixture>?> loadFixturesFromCache() async {
    try {
      final prefs = await _prefs;
      final cachedJson = prefs.getString(_fixturesCacheKey);
      final cachedTimestamp = prefs.getInt(_fixturesTimestampKey);

      if (cachedJson == null || cachedTimestamp == null) {
        debugPrint('📭 No fixtures cache found in LocalStorageManager');
        return null;
      }

      final jsonList = jsonDecode(cachedJson) as List;
      final fixtures = jsonList.map((json) => Fixture.fromJson(json)).toList();

      debugPrint(
          '📦 LocalStorageManager: Loaded ${fixtures.length} fixtures from cache');
      return fixtures;
    } catch (e) {
      debugPrint(
          '⚠️ LocalStorageManager: Error loading fixtures from cache: $e');
      return null;
    }
  }

  static Future<void> saveVote(
      String userId, String fixtureId, String selection) async {
    try {
      final prefs = await _prefs;
      final key = 'vote_${userId}_$fixtureId'; // Removed channelId from key
      await prefs.setString(key, selection);
      debugPrint('✅ Saved vote for fixture $fixtureId');
    } catch (e) {
      debugPrint('⚠️ Error saving vote: $e');
    }
  }

// ========== UPDATED: Remove channelId from loadVotesForUser ==========
  static Future<Map<String, String>> loadVotesForUser(String userId) async {
    try {
      final prefs = await _prefs;
      final keys = prefs.getKeys();
      final votes = <String, String>{};
      final prefix = 'vote_${userId}_';

      for (var key in keys) {
        if (key.startsWith(prefix)) {
          final fixtureId = key.substring(prefix.length);
          final selection = prefs.getString(key);
          if (selection != null && selection.isNotEmpty) {
            votes[fixtureId] = selection;
          }
        }
      }
      debugPrint('📦 Loaded ${votes.length} votes from local storage');
      return votes;
    } catch (e) {
      debugPrint('⚠️ Error loading votes: $e');
      return {};
    }
  }

  static Future<void> saveCommentCount(String fixtureId, int count) async {
    try {
      final prefs = await _prefs;
      final countsJson = prefs.getString(_commentCountsKey);
      Map<String, int> counts = {};

      if (countsJson != null) {
        try {
          final decoded = json.decode(countsJson);
          if (decoded is Map) {
            counts = Map<String, int>.from(
              decoded.map((k, v) => MapEntry(k.toString(), v as int)),
            );
          }
        } catch (e) {
          counts = {};
        }
      }

      counts[fixtureId] = count;
      await prefs.setString(_commentCountsKey, json.encode(counts));
      debugPrint('💾 Saved comment count $count for fixture $fixtureId');
    } catch (e) {
      debugPrint('⚠️ Error saving comment count: $e');
    }
  }

  static Future<int?> getCommentCount(String fixtureId) async {
    try {
      final prefs = await _prefs;
      final countsJson = prefs.getString(_commentCountsKey);
      if (countsJson == null) return null;

      final decoded = json.decode(countsJson);
      if (decoded is Map) {
        return decoded[fixtureId] as int?;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Error loading comment count: $e');
      return null;
    }
  }

  static Future<Map<String, int>> getAllCommentCounts() async {
    try {
      final prefs = await _prefs;
      final countsJson = prefs.getString(_commentCountsKey);
      if (countsJson == null) return {};

      final decoded = json.decode(countsJson);
      if (decoded is Map) {
        return Map<String, int>.from(
          decoded.map((k, v) => MapEntry(k.toString(), v as int)),
        );
      }
      return {};
    } catch (e) {
      debugPrint('⚠️ Error loading all comment counts: $e');
      return {};
    }
  }

  // ========== VOTE COUNT CACHING ==========

  static Future<void> saveVoteCount(String fixtureId, int count) async {
    try {
      final prefs = await _prefs;
      final countsJson = prefs.getString(_voteCountsKey);
      Map<String, int> counts = {};

      if (countsJson != null) {
        try {
          final decoded = json.decode(countsJson);
          if (decoded is Map) {
            counts = Map<String, int>.from(
              decoded.map((k, v) => MapEntry(k.toString(), v as int)),
            );
          }
        } catch (e) {
          counts = {};
        }
      }

      counts[fixtureId] = count;
      await prefs.setString(_voteCountsKey, json.encode(counts));
      debugPrint('💾 Saved vote count $count for fixture $fixtureId');
    } catch (e) {
      debugPrint('⚠️ Error saving vote count: $e');
    }
  }

  static Future<int?> getVoteCount(String fixtureId) async {
    try {
      final prefs = await _prefs;
      final countsJson = prefs.getString(_voteCountsKey);
      if (countsJson == null) return null;

      final decoded = json.decode(countsJson);
      if (decoded is Map) {
        return decoded[fixtureId] as int?;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Error loading vote count: $e');
      return null;
    }
  }

  // ========== COMMENT CACHING METHODS ==========

  static Future<void> saveCommentsForFixture(
    String fixtureId,
    List<FixtureComment> comments,
  ) async {
    try {
      final prefs = await _prefs;
      final key = '$_commentsCacheKeyPrefix$fixtureId';
      final tsKey = '$_commentsCacheTimestampPrefix$fixtureId';

      // Load existing cached comments
      final existing = await loadCommentsForFixture(fixtureId);

      // MERGE: combine old + new, deduplicate by ID, keep newest
      final Map<String, FixtureComment> merged = {};
      for (var c in existing) {
        if (c.id.isNotEmpty) merged[c.id] = c;
      }
      for (var c in comments) {
        if (c.id.isNotEmpty) merged[c.id] = c;
      }

      final mergedList = merged.values.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      final jsonList = mergedList.map((c) => c.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
      await prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);

      // Also save comment count
      await saveCommentCount(fixtureId, mergedList.length);

      debugPrint('💾 Saved ${mergedList.length} comments for $fixtureId');
    } catch (e) {
      debugPrint('⚠️ Error saving comments: $e');
    }
  }

  static Future<int?> getCommentsLastFetched(String fixtureId) async {
    final prefs = await _prefs;
    return prefs.getInt('$_commentsCacheTimestampPrefix$fixtureId');
  }

  static Future<List<FixtureComment>> loadCommentsForFixture(
    String fixtureId,
  ) async {
    try {
      final prefs = await _prefs;
      final key = '$_commentsCacheKeyPrefix$fixtureId';
      final cachedJson = prefs.getString(key);
      if (cachedJson == null) return [];

      final jsonList = jsonDecode(cachedJson) as List;
      final comments =
          jsonList.map((json) => FixtureComment.fromJson(json)).toList();
      debugPrint(
        '📦 Loaded ${comments.length} comments from cache for fixture $fixtureId',
      );
      return comments;
    } catch (e) {
      debugPrint('⚠️ Error loading comments from cache: $e');
      return [];
    }
  }

  // ========== EXISTING METHODS (keep as is) ==========

  static Future<String?> getAuthToken() async {
    final prefs = await _prefs;
    return prefs.getString(_authTokenKey);
  }

  static Future<void> saveAuthToken(String token) async {
    final prefs = await _prefs;
    await prefs.setString(_authTokenKey, token);
  }

  static Future<DateTime?> getLastSyncTime() async {
    final prefs = await _prefs;
    final timestamp = prefs.getInt(_lastSyncKey);
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  static Future<void> updateSyncTime() async {
    final prefs = await _prefs;
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<bool> shouldSync() async {
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;
    final now = DateTime.now();
    return now.difference(lastSync).inMinutes > 5;
  }

  static Future<int?> getServerTimestamp() async {
    final prefs = await _prefs;
    return prefs.getInt(_serverTimestampKey);
  }

  static Future<void> setServerTimestamp(int timestamp) async {
    final prefs = await _prefs;
    await prefs.setInt(_serverTimestampKey, timestamp);
  }

  static Future<void> saveFixturesToCache(
    List<Fixture> fixtures, {
    String? etag,
  }) async {
    try {
      final prefs = await _prefs;
      final jsonList = fixtures.map((f) => f.toJson()).toList();
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await prefs.setString(_fixturesCacheKey, jsonEncode(jsonList));
      await prefs.setInt(_fixturesTimestampKey, timestamp);

      if (etag != null && etag.isNotEmpty) {
        await prefs.setString(_fixturesEtagKey, etag);
      }

      debugPrint('✅ Saved ${fixtures.length} fixtures to cache');
    } catch (e) {
      debugPrint('❌ Error saving fixtures to cache: $e');
    }
  }

  static Future<String?> getFixturesEtag() async {
    final prefs = await _prefs;
    return prefs.getString(_fixturesEtagKey);
  }

  static Future<void> saveCommenter(
    String fixtureId,
    String userId,
    String username,
  ) async {
    try {
      final prefs = await _prefs;
      final commentersJson = prefs.getString(_commentersKey);
      Map<String, Map<String, String>> commenters = {};

      if (commentersJson != null) {
        try {
          final decoded = json.decode(commentersJson);
          if (decoded is Map) {
            decoded.forEach((key, value) {
              if (value is Map) {
                commenters[key] = Map<String, String>.from(value);
              }
            });
          }
        } catch (e) {
          commenters = {};
        }
      }

      if (!commenters.containsKey(fixtureId)) {
        commenters[fixtureId] = {};
      }
      commenters[fixtureId]![userId] = username;

      await prefs.setString(_commentersKey, json.encode(commenters));
      debugPrint('✅ Saved commenter $username for fixture $fixtureId');
    } catch (e) {
      debugPrint('⚠️ Error saving commenter: $e');
    }
  }

  static Future<Map<String, Map<String, String>>> loadCommenters() async {
    try {
      final prefs = await _prefs;
      final commentersJson = prefs.getString(_commentersKey);
      if (commentersJson == null) return {};

      final decoded = json.decode(commentersJson);
      if (decoded is Map) {
        final result = <String, Map<String, String>>{};
        decoded.forEach((key, value) {
          if (value is Map) {
            result[key] = Map<String, String>.from(value);
          }
        });
        return result;
      }
      return {};
    } catch (e) {
      debugPrint('⚠️ Error loading commenters: $e');
      return {};
    }
  }

  static Future<void> saveSubFixtureVote(
    String userId,
    String subFixtureId,
    String selection,
  ) async {
    try {
      final prefs = await _prefs;
      await prefs.setString('sub_vote_${userId}_$subFixtureId', selection);
      debugPrint('✅ Saved sub-fixture vote for $subFixtureId');
    } catch (e) {
      debugPrint('⚠️ Error saving sub-fixture vote: $e');
    }
  }

  static Future<Map<String, String>> loadSubFixtureVotesForUser(
    String userId,
  ) async {
    try {
      final prefs = await _prefs;
      final keys = prefs.getKeys();
      final votes = <String, String>{};
      final prefix = 'sub_vote_${userId}_';

      for (var key in keys) {
        if (key.startsWith(prefix)) {
          final subFixtureId = key.substring(prefix.length);
          final selection = prefs.getString(key);
          if (selection != null) {
            votes[subFixtureId] = selection;
          }
        }
      }
      return votes;
    } catch (e) {
      debugPrint('⚠️ Error loading sub-fixture votes: $e');
      return {};
    }
  }

  static Future<void> saveLike(
    String userId,
    String fixtureId,
    bool isLiked,
  ) async {
    try {
      final prefs = await _prefs;
      final likesKey = 'likes_$userId';
      final likes = prefs.getStringList(likesKey) ?? [];
      if (isLiked) {
        if (!likes.contains(fixtureId)) likes.add(fixtureId);
      } else {
        likes.remove(fixtureId);
      }
      await prefs.setStringList(likesKey, likes);
    } catch (e) {
      debugPrint('⚠️ Error saving like: $e');
    }
  }

  static Future<Set<String>> loadLikesForUser(String userId) async {
    try {
      final prefs = await _prefs;
      final likeList = prefs.getStringList('likes_$userId') ?? [];
      return likeList.toSet();
    } catch (e) {
      debugPrint('⚠️ Error loading likes: $e');
      return {};
    }
  }

  static Future<void> saveGameMetadata(GameMetadata metadata) async {
    try {
      final prefs = await _prefs;
      final metadataList = prefs.getStringList(_metadataKey) ?? [];

      metadataList.removeWhere((item) {
        final data = json.decode(item);
        return data['fixtureId'] == metadata.fixtureId &&
            data['userId'] == metadata.userId;
      });

      metadataList.add(json.encode(metadata.toJson()));
      await prefs.setStringList(_metadataKey, metadataList);
      debugPrint('✅ Game metadata saved for fixture ${metadata.fixtureId}');
    } catch (e) {
      debugPrint('❌ Error saving game metadata: $e');
    }
  }

  static Future<List<GameMetadata>> loadUserGameMetadata(String userId) async {
    try {
      final prefs = await _prefs;
      final metadataList = prefs.getStringList(_metadataKey) ?? [];
      final userMetadata = <GameMetadata>[];

      for (var item in metadataList) {
        try {
          final data = json.decode(item);
          if (data['userId'] == userId) {
            userMetadata.add(GameMetadata.fromJson(data));
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing metadata item: $e');
        }
      }

      return userMetadata;
    } catch (e) {
      debugPrint('⚠️ Error loading game metadata: $e');
      return [];
    }
  }

  static Future<GameMetadata?> getGameMetadata(
    String fixtureId,
    String userId,
  ) async {
    try {
      final prefs = await _prefs;
      final metadataList = prefs.getStringList(_metadataKey) ?? [];

      for (var item in metadataList) {
        try {
          final data = json.decode(item);
          if (data['fixtureId'] == fixtureId && data['userId'] == userId) {
            return GameMetadata.fromJson(data);
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing metadata item: $e');
        }
      }

      return null;
    } catch (e) {
      debugPrint('⚠️ Error getting game metadata: $e');
      return null;
    }
  }

  static Future<void> saveFixtureNotification(
    FixtureNotificationState notification,
  ) async {
    try {
      final prefs = await _prefs;
      final notificationsJson = prefs.getString(_notificationsKey);
      Map<String, Map<String, dynamic>> notifications = {};

      if (notificationsJson != null) {
        try {
          notifications = json.decode(notificationsJson);
        } catch (e) {}
      }

      notifications[notification.fixtureId] = notification.toJson();
      await prefs.setString(_notificationsKey, json.encode(notifications));
      debugPrint('✅ Saved notification for fixture ${notification.fixtureId}');
    } catch (e) {
      debugPrint('⚠️ Error saving notification: $e');
    }
  }

  static Future<Map<String, FixtureNotificationState>>
      loadFixtureNotifications() async {
    try {
      final prefs = await _prefs;
      final notificationsJson = prefs.getString(_notificationsKey);
      if (notificationsJson == null) return {};

      final decoded = json.decode(notificationsJson);
      final result = <String, FixtureNotificationState>{};
      decoded.forEach((key, value) {
        result[key] = FixtureNotificationState.fromJson(value);
      });
      return result;
    } catch (e) {
      debugPrint('⚠️ Error loading notifications: $e');
      return {};
    }
  }

  // ========== COMRADE STORAGE METHODS ==========

  static Future<void> saveUserComrades(Set<String> comrades) async {
    try {
      final prefs = await _prefs;
      await prefs.setStringList(_userComradesKey, comrades.toList());
      await prefs.setInt(
        _userComradesTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      debugPrint('✅ Saved ${comrades.length} comrades to local storage');
    } catch (e) {
      debugPrint('⚠️ Error saving user comrades: $e');
    }
  }

  static Future<Set<String>> loadUserComrades() async {
    try {
      final prefs = await _prefs;
      final list = prefs.getStringList(_userComradesKey);
      if (list != null) {
        debugPrint('✅ Loaded ${list.length} comrades from local storage');
        return list.toSet();
      }
      return {};
    } catch (e) {
      debugPrint('⚠️ Error loading user comrades: $e');
      return {};
    }
  }

  static Future<bool> isUserComradesCacheValid() async {
    try {
      final prefs = await _prefs;
      final timestamp = prefs.getInt(_userComradesTimestampKey);
      if (timestamp == null) return false;
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final isValid =
          DateTime.now().difference(cacheTime) < _comradesCacheDuration;
      debugPrint('🔍 Comrades cache valid: $isValid');
      return isValid;
    } catch (e) {
      debugPrint('⚠️ Error checking comrades cache: $e');
      return false;
    }
  }

  static Future<void> saveComradeVoters(
    Map<String, List<ComradeWithProfile>> comradeVoters,
  ) async {
    try {
      final prefs = await _prefs;
      final serialized = <String, List<Map<String, dynamic>>>{};
      for (var entry in comradeVoters.entries) {
        serialized[entry.key] = entry.value.map((c) => c.toJson()).toList();
      }
      await prefs.setString(_comradeVotersKey, json.encode(serialized));
      debugPrint('✅ Saved ${comradeVoters.length} comrade voters');
    } catch (e) {
      debugPrint('⚠️ Error saving comrade voters: $e');
    }
  }

  static Future<Map<String, List<ComradeWithProfile>>>
      loadComradeVoters() async {
    try {
      final prefs = await _prefs;
      final jsonStr = prefs.getString(_comradeVotersKey);
      if (jsonStr == null) return {};

      final decoded = json.decode(jsonStr) as Map<String, dynamic>;
      final result = <String, List<ComradeWithProfile>>{};
      for (var entry in decoded.entries) {
        result[entry.key] = (entry.value as List)
            .map((c) => ComradeWithProfile.fromJson(c as Map<String, dynamic>))
            .toList();
      }
      return result;
    } catch (e) {
      debugPrint('⚠️ Error loading comrade voters: $e');
      return {};
    }
  }
}

// ========== UPDATE CHECK SERVICE ==========
class UpdateCheckService {
  static const String API_BASE_URL = 'https://clash-api-m5mr.onrender.com/api';

  static Future<bool> checkForUpdates() async {
    try {
      final shouldCheck = await LocalStorageManager.shouldSync();
      if (!shouldCheck) return false;

      final response = await http.get(
        Uri.parse('$API_BASE_URL/votes/timestamp'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final serverTimestamp = data['timestamp'] as int?;
        final lastLocalTimestamp =
            await LocalStorageManager.getServerTimestamp();

        if (serverTimestamp != null) {
          await LocalStorageManager.setServerTimestamp(serverTimestamp);
          await LocalStorageManager.updateSyncTime();

          if (lastLocalTimestamp == null ||
              serverTimestamp > lastLocalTimestamp) {
            debugPrint('🔄 Updates available');
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error checking for updates: $e');
    }
    return false;
  }
}

// ========== ARCHIVE ACTIVITY MODELS ==========
class ArchiveActivityRequest {
  final String user_id;
  final String username;
  final String fixture_id;
  final String home_team;
  final String away_team;
  final String activity_type;
  final String? selection;
  final bool? is_liked;
  final String? comment;
  final String timestamp;

  ArchiveActivityRequest({
    required this.user_id,
    required this.username,
    required this.fixture_id,
    required this.home_team,
    required this.away_team,
    required this.activity_type,
    this.selection,
    this.is_liked,
    this.comment,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': user_id,
      'username': username,
      'fixture_id': fixture_id,
      'home_team': home_team,
      'away_team': away_team,
      'activity_type': activity_type,
      'selection': selection,
      'is_liked': is_liked,
      'comment': comment,
      'timestamp': timestamp,
    };
  }
}

class ArchiveActivityResponse {
  final bool success;
  final String message;
  final String activity_id;

  ArchiveActivityResponse({
    required this.success,
    required this.message,
    required this.activity_id,
  });

  factory ArchiveActivityResponse.fromJson(Map<String, dynamic> json) {
    return ArchiveActivityResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      activity_id: json['activity_id'] ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

// ========== ARCHIVE SERVICE ==========
class ArchiveService {
  static const String API_BASE_URL = 'https://clash-api-m5mr.onrender.com/api';
  static const Duration REQUEST_TIMEOUT = Duration(seconds: 15);

  static String get archiveActivityEndpoint => '$API_BASE_URL/archive/activity';

  static Future<ArchiveActivityResponse?> _archive({
    required String userId,
    required String username,
    required String fixtureId,
    required String homeTeam,
    required String awayTeam,
    required String activityType,
    String? selection,
    bool? isLiked,
    String? comment,
  }) async {
    try {
      final request = ArchiveActivityRequest(
        user_id: userId,
        username: username,
        fixture_id: fixtureId,
        home_team: homeTeam,
        away_team: awayTeam,
        activity_type: activityType,
        selection: selection,
        is_liked: isLiked,
        comment: comment,
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );

      final response = await http
          .post(
            Uri.parse(archiveActivityEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(request.toJson()),
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final responseData = json.decode(response.body);
          final archiveResponse = ArchiveActivityResponse.fromJson(
            responseData,
          );
          if (archiveResponse.success) {
            debugPrint(
              '✅ $activityType activity archived: ${archiveResponse.activity_id}',
            );
            return archiveResponse;
          }
        } catch (e) {
          debugPrint('❌ Error parsing archive response: $e');
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error archiving $activityType activity: $e');
      return null;
    }
  }

  static Future<ArchiveActivityResponse?> archiveVoteActivity({
    required String userId,
    required String username,
    required String fixtureId,
    required String homeTeam,
    required String awayTeam,
    required String selection,
  }) async {
    return _archive(
      userId: userId,
      username: username,
      fixtureId: fixtureId,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      activityType: 'vote',
      selection: selection,
    );
  }

  static Future<ArchiveActivityResponse?> archiveLikeActivity({
    required String userId,
    required String username,
    required String fixtureId,
    required String homeTeam,
    required String awayTeam,
    required bool isLiked,
  }) async {
    return _archive(
      userId: userId,
      username: username,
      fixtureId: fixtureId,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      activityType: 'like',
      isLiked: isLiked,
    );
  }

  static Future<ArchiveActivityResponse?> archiveCommentActivity({
    required String userId,
    required String username,
    required String fixtureId,
    required String homeTeam,
    required String awayTeam,
    required String comment,
  }) async {
    return _archive(
      userId: userId,
      username: username,
      fixtureId: fixtureId,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      activityType: 'comment',
      comment: comment,
    );
  }
}

// ========== GAME METADATA MODEL ==========
class GameMetadata {
  final String fixtureId;
  final String userId;
  final String username;
  final String homeTeam;
  final String awayTeam;
  final String league;
  final String date;
  final String selection;
  final double homeOdds;
  final double drawOdds;
  final double awayOdds;
  final DateTime votedAt;
  final bool isActive;

  GameMetadata({
    required this.fixtureId,
    required this.userId,
    required this.username,
    required this.homeTeam,
    required this.awayTeam,
    required this.league,
    required this.date,
    required this.selection,
    required this.homeOdds,
    required this.drawOdds,
    required this.awayOdds,
    required this.votedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'fixtureId': fixtureId,
      'userId': userId,
      'username': username,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'league': league,
      'date': date,
      'selection': selection,
      'homeOdds': homeOdds,
      'drawOdds': drawOdds,
      'awayOdds': awayOdds,
      'votedAt': votedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory GameMetadata.fromJson(Map<String, dynamic> json) {
    return GameMetadata(
      fixtureId: json['fixtureId'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      homeTeam: json['homeTeam'] ?? '',
      awayTeam: json['awayTeam'] ?? '',
      league: json['league'] ?? '',
      date: json['date'] ?? '',
      selection: json['selection'] ?? '',
      homeOdds: (json['homeOdds'] ?? 0.0).toDouble(),
      drawOdds: (json['drawOdds'] ?? 0.0).toDouble(),
      awayOdds: (json['awayOdds'] ?? 0.0).toDouble(),
      votedAt: DateTime.parse(
        json['votedAt'] ?? DateTime.now().toIso8601String(),
      ),
      isActive: json['isActive'] ?? true,
    );
  }
}

// ========== GAME METADATA SERVICE ==========
class GameMetadataService {
  static Future<void> createGameMetadataAndArchive({
    required String fixtureId,
    required String userId,
    required String username,
    required Fixture fixture,
    required String selection,
  }) async {
    try {
      final metadata = GameMetadata(
        fixtureId: fixtureId,
        userId: userId,
        username: username,
        homeTeam: fixture.homeTeam,
        awayTeam: fixture.awayTeam,
        league: fixture.league,
        date: fixture.date,
        selection: selection,
        homeOdds: fixture.homeWin,
        drawOdds: fixture.draw,
        awayOdds: fixture.awayWin,
        votedAt: DateTime.now(),
        isActive: true,
      );

      await LocalStorageManager.saveGameMetadata(metadata);
      debugPrint('📝 Game metadata created for $fixtureId');

      await ArchiveService.archiveVoteActivity(
        userId: userId,
        username: username,
        fixtureId: fixtureId,
        homeTeam: fixture.homeTeam,
        awayTeam: fixture.awayTeam,
        selection: selection,
      );
    } catch (e) {
      debugPrint('❌ Error creating game metadata and archiving: $e');
    }
  }
}

// ========== TOAST HELPER ==========
class ToastHelper {
  static void showSuccess(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: FanColors.primary, // ✅ Changed from SocialTheme.primary
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  /// Shows top-up dialog and returns true if the user successfully topped up

  static void showError(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: FanColors.away, // ✅ Changed from Colors.red
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  static void showInfo(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: FanColors.primary, // ✅ Changed
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  static void showWarning(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: FanColors.draw, // ✅ Changed from Colors.orange
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }
}

// ========== DATE HELPER ==========
// ========== DATE HELPER - UPDATED ==========
// ========== DATE HELPER - COMPLETE ==========
class DateHelper {
  static DateTime parseFixtureDate(String dateString) {
    try {
      if (dateString.contains('T') && dateString.length >= 20) {
        return DateTime.parse(dateString);
      }

      if (RegExp(r'^\d{1,2}\s+[A-Za-z]{3}$').hasMatch(dateString.trim())) {
        final parts = dateString.trim().split(' ');
        final day = int.parse(parts[0]);
        final monthAbbr = parts[1];

        final monthMap = {
          'Jan': 1,
          'Feb': 2,
          'Mar': 3,
          'Apr': 4,
          'May': 5,
          'Jun': 6,
          'Jul': 7,
          'Aug': 8,
          'Sep': 9,
          'Oct': 10,
          'Nov': 11,
          'Dec': 12,
        };

        final month = monthMap[monthAbbr];
        if (month != null) {
          final now = DateTime.now();
          DateTime date = DateTime(now.year, month, day);
          if (date.isBefore(now.subtract(const Duration(days: 30)))) {
            date = DateTime(now.year + 1, month, day);
          }
          return date;
        }
      }

      if (dateString.contains('/') && dateString.split('/').length == 2) {
        final parts = dateString.split('/');
        final day = int.tryParse(parts[0].trim());
        final month = int.tryParse(parts[1].trim());

        if (day != null &&
            month != null &&
            day >= 1 &&
            day <= 31 &&
            month >= 1 &&
            month <= 12) {
          final now = DateTime.now();
          DateTime date = DateTime(now.year, month, day);
          if (date.isBefore(now.subtract(const Duration(days: 30)))) {
            date = DateTime(now.year + 1, month, day);
          }
          return date;
        }
      }

      if (dateString.contains('/') && dateString.split('/').length == 3) {
        final parts = dateString.split('/');
        final day = int.tryParse(parts[0].trim());
        final month = int.tryParse(parts[1].trim());
        final year = int.tryParse(parts[2].trim());

        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }

      if (dateString.contains('-') && dateString.length >= 10) {
        return DateTime.parse(dateString);
      }

      debugPrint(
        '⚠️ Warning: Could not parse date: "$dateString" - using current date',
      );
      return DateTime.now();
    } catch (e) {
      debugPrint('❌ Error parsing date "$dateString": $e');
      return DateTime.now();
    }
  }

  static bool isMatchUpcoming(DateTime date) {
    final now = DateTime.now();
    return date.isAfter(now);
  }

  static bool isMatchFinished(DateTime date) {
    final now = DateTime.now();
    // Consider a match finished if it's more than 2 hours old (typical match duration)
    return date.isBefore(now.subtract(const Duration(hours: 2)));
  }

  // Main formatting method for fixture display
  static String formatFixtureDate(String dateString, String timeString) {
    try {
      final date = parseFixtureDate(dateString);
      final now = DateTime.now();

      // Check if LIVE (within 2 hours before or after match)
      if (isMatchLive(dateString)) return 'LIVE';

      // Get date difference
      final today = DateTime(now.year, now.month, now.day);
      final matchDate = DateTime(date.year, date.month, date.day);
      final difference = matchDate.difference(today).inDays;

      // Format time (HH:MM)
      String formattedTime = _formatTimeString(timeString);

      // Today
      if (difference == 0) {
        return formattedTime.isNotEmpty ? 'Today, $formattedTime' : 'Today';
      }

      // Tomorrow
      if (difference == 1) {
        return formattedTime.isNotEmpty
            ? 'Tomorrow, $formattedTime'
            : 'Tomorrow';
      }

      // Within next 7 days - show day name
      if (difference > 1 && difference <= 7) {
        final dayName = _getDayName(date.weekday);
        return formattedTime.isNotEmpty ? '$dayName, $formattedTime' : dayName;
      }

      // Future beyond 7 days
      if (difference > 7) {
        return DateFormat('MMM d, HH:mm').format(date);
      }

      // Past matches
      if (difference < 0) {
        final absDiff = difference.abs();
        if (absDiff == 0) return 'Yesterday';
        if (absDiff == 1) return 'Yesterday';
        if (absDiff < 7) return '$absDiff days ago';
        return DateFormat('MMM d').format(date);
      }

      return DateFormat('MMM d, HH:mm').format(date);
    } catch (e) {
      debugPrint('⚠️ Error formatting fixture date: $e');
      return dateString;
    }
  }

  static String _formatTimeString(String timeString) {
    if (timeString.isEmpty) return '';
    if (timeString.contains(':')) return timeString;
    if (timeString.length >= 4) {
      // Handle format like "1430" -> "14:30"
      return '${timeString.substring(0, 2)}:${timeString.substring(2, 4)}';
    }
    return timeString;
  }

  static bool isMatchLive(String dateString) {
    try {
      final matchDate = parseFixtureDate(dateString);
      final now = DateTime.now();
      final difference = matchDate.difference(now).inMinutes;
      // Match is LIVE if within 2 hours before or 2 hours after scheduled time
      return difference.abs() <= 120;
    } catch (e) {
      return false;
    }
  }

  static String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }

  static String formatDate(String dateString) {
    try {
      final date = parseFixtureDate(dateString);
      final now = DateTime.now();
      final difference = date.difference(now);
      final diffHours = difference.inHours;

      if (diffHours <= 2 && diffHours >= -2) return 'LIVE';
      if (diffHours > 0) {
        if (diffHours < 24) return 'In ${diffHours}h';
        final diffDays = (diffHours / 24).floor();
        return 'In ${diffDays}d';
      }
      if (diffHours < 0) {
        final absHours = diffHours.abs();
        if (absHours < 24) return '${absHours}h ago';
        final diffDays = (absHours / 24).floor();
        return '${diffDays}d ago';
      }
      return DateFormat('HH:mm').format(date);
    } catch (e) {
      debugPrint('⚠️ Error formatting date "$dateString": $e');
      return dateString;
    }
  }

  static String formatFullDate(String dateString) {
    try {
      final date = parseFixtureDate(dateString);
      return DateFormat('MMM d, HH:mm').format(date);
    } catch (e) {
      debugPrint('⚠️ Error formatting full date "$dateString": $e');
      return dateString;
    }
  }

  static String formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }

  static bool isValidDate(String dateString) {
    try {
      parseFixtureDate(dateString);
      return true;
    } catch (e) {
      return false;
    }
  }
}

// ========== VOTERS POPUP DIALOG - PLAIN VERSION ==========
class VotersPopup extends StatelessWidget {
  final String title;
  final List<VoteUser> voters;
  final Color color;
  final VoidCallback onClose;

  const VotersPopup({
    super.key,
    required this.title,
    required this.voters,
    required this.color,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: FanDecorations.borderlessCard(), // ✅ Using FanDecorations
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: FanColors.border.withValues(alpha: 0.3), // ✅ Changed
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        title.contains('Rivals') ? Icons.groups : Icons.people,
                        color: color,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: FanTypography.body.copyWith(
                          // ✅ Changed
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: FanColors.surface, // ✅ Changed
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: FanColors.textSecondary, // ✅ Changed
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (voters.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      title.contains('Rivals')
                          ? Icons.emoji_events
                          : Icons.celebration,
                      size: 32,
                      color: FanColors.textSecondary, // ✅ Changed
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title.contains('Rivals')
                          ? 'No rivals yet'
                          : 'No supporters yet',
                      style: FanTypography.caption.copyWith(
                        // ✅ Changed
                        color: FanColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: voters.length,
                  itemBuilder: (context, index) {
                    final voter = voters[index];
                    final timeAgo = DateHelper.formatTimeAgo(voter.votedAt);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          FootballAvatarManager.buildAvatar(
                            userId: voter.userId,
                            username: voter.username,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  voter.username,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: FanColors.textPrimary, // ✅ Changed
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  timeAgo,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: FanColors.textSecondary, // ✅ Changed
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            voter.selection == 'home_team'
                                ? 'Home'
                                : voter.selection == 'away_team'
                                    ? 'Away'
                                    : voter.selection == 'draw'
                                        ? 'Draw'
                                        : (voter.selection.toLowerCase() ?? ''),
                            style: TextStyle(
                              fontSize: 12,
                              color: color,
                              fontWeight: FontWeight.w500,
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
      ),
    );
  }
}

// ========== SUB-FIXTURE VOTERS POPUP - PLAIN VERSION ==========

// ========== COMRADE COMMENTS POPUP ==========
class ComradeCommentsPopup extends StatelessWidget {
  final List<FixtureComment> comments;
  final Fixture fixture;
  final VoidCallback onClose;

  const ComradeCommentsPopup({
    super.key,
    required this.comments,
    required this.fixture,
    required this.onClose,
  });

  Color _getVoteColor(String? selection) {
    if (selection == 'home_team') return FanColors.primary; // ✅ Changed
    if (selection == 'away_team') return const Color(0xFF2563EB);
    if (selection == 'draw') return const Color(0xFF8B5CF6);
    return FanColors.textSecondary; // ✅ Changed
  }

  String _getVoteDisplayText(
    String? selection,
    String homeTeam,
    String awayTeam,
  ) {
    if (selection == 'home_team') return homeTeam;
    if (selection == 'away_team') return awayTeam;
    if (selection == 'draw') return 'draw';
    return selection ?? 'unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: FanDecorations.elevatedCard(), // ✅ Changed
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: FanColors.border.withValues(alpha: 0.3), // ✅ Changed
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.comment,
                          color: FanColors.primary, size: 20), // ✅ Changed
                      const SizedBox(width: 8),
                      Text(
                        'Comrade Comments (${comments.length})',
                        style: FanTypography.body.copyWith(
                          // ✅ Changed
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: FanColors.inputSurface, // ✅ Changed
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: FanColors.textSecondary, // ✅ Changed
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  final timeAgo = DateHelper.formatTimeAgo(comment.timestamp);
                  final voteColor = _getVoteColor(comment.selection);
                  final voteDisplay = _getVoteDisplayText(
                    comment.selection,
                    fixture.homeTeam,
                    fixture.awayTeam,
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FanColors.surfaceSunken, // ✅ Changed
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            FootballAvatarManager.buildAvatar(
                              userId: comment.userId,
                              username: comment.username,
                              size: 32,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comment.username,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: FanColors.textPrimary, // ✅ Changed
                                    ),
                                  ),
                                  Text(
                                    timeAgo,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color:
                                          FanColors.textSecondary, // ✅ Changed
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (comment.selection != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: voteColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  voteDisplay,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: voteColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: FanColors.background, // ✅ Changed
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            comment.comment,
                            style: TextStyle(
                              fontSize: 12,
                              color: FanColors.textPrimary, // ✅ Changed
                              height: 1.4,
                            ),
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
      ),
    );
  }
}

// ========== COMRADE ACTIVITY POPUP ==========
// ========== COMRADE ACTIVITY POPUP ==========

class SimpleComradeCommentsPopup extends StatelessWidget {
  final List<FixtureComment> comments;
  final Fixture fixture;
  final VoidCallback onClose;

  const SimpleComradeCommentsPopup({
    super.key,
    required this.comments,
    required this.fixture,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: FanDecorations.elevatedCard(), // ✅ Changed
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: FanColors.border.withValues(alpha: 0.3), // ✅ Changed
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.comment,
                          color: FanColors.primary, size: 20), // ✅ Changed
                      const SizedBox(width: 8),
                      Text(
                        'Comrade Comments (${comments.length})',
                        style: FanTypography.body.copyWith(
                          // ✅ Changed
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: FanColors.surface, // ✅ Changed
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: FanColors.textSecondary, // ✅ Changed
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  final timeAgo = DateHelper.formatTimeAgo(comment.timestamp);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FanColors.surfaceSunken, // ✅ Changed
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FootballAvatarManager.buildAvatar(
                          userId: comment.userId,
                          username: comment.username,
                          size: 32,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comment.username,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: FanColors.textPrimary, // ✅ Changed
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                comment.comment,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: FanColors.textPrimary, // ✅ Changed
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timeAgo,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: FanColors.textSecondary, // ✅ Changed
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
      ),
    );
  }
}

// ========== COMRADE ACTIVITY POPUP ==========
// ========== COMRADE ACTIVITY POPUP ==========

// ========== COMRADE ACTIVITY POPUP ==========
// ========== COMRADE ACTIVITY POPUP ==========
// ========== COMRADE ACTIVITY POPUP ==========

// ========== COMRADE ACTIVITY POPUP ==========

// ========== NEW COMRADE LIST POPUP ==========

class SubFixtureModal extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final Fixture fixture;
  final SubFixture subFixture;
  final String userId;
  final String username;
  final String? authToken;
  final Function(String) onVote;

  const SubFixtureModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.fixture,
    required this.subFixture,
    required this.userId,
    required this.username,
    this.authToken,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: FanColors.background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FanColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FanColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      subFixture.icon,
                      size: 20,
                      color: FanColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subFixture.question,
                          style: FanTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${fixture.homeTeam} vs ${fixture.awayTeam}',
                          style: FanTypography.tag.copyWith(
                            color: FanColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: FanColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: FanColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            Container(
              height: 1,
              color: FanColors.border.withValues(alpha: 0.3),
            ),

            // Options
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildCleanOption(
                    title: subFixture.optionA,
                    odds: subFixture.oddsA,
                    onTap: () => onVote(subFixture.optionA),
                  ),
                  const SizedBox(height: 12),
                  _buildCleanOption(
                    title: subFixture.optionB,
                    odds: subFixture.oddsB,
                    onTap: () => onVote(subFixture.optionB),
                  ),
                  if (subFixture.optionC != null) ...[
                    const SizedBox(height: 12),
                    _buildCleanOption(
                      title: subFixture.optionC!,
                      odds: subFixture.oddsC ?? 1.0,
                      onTap: () => onVote(subFixture.optionC!),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanOption({
    required String title,
    required double odds,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: FanColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: FanTypography.body.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: FanColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                odds.toStringAsFixed(2),
                style: FanTypography.tag.copyWith(
                  color: FanColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ComradeListPopup extends StatelessWidget {
  final List<ComradeWithProfile> comrades;
  final VoidCallback onClose;

  const ComradeListPopup({
    super.key,
    required this.comrades,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: FanDecorations.elevatedCard(), // ✅ Changed
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: FanColors.border.withValues(alpha: 0.3), // ✅ Changed
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.people_alt,
                        color: FanColors.primary, // ✅ Changed
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Comrades (${comrades.length})',
                        style: FanTypography.body.copyWith(
                          // ✅ Changed
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: FanColors.surface, // ✅ Changed
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: FanColors.textSecondary, // ✅ Changed
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (comrades.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 32,
                      color: FanColors.textSecondary, // ✅ Changed
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No comrades voted yet',
                      style: FanTypography.caption.copyWith(
                        // ✅ Changed
                        color: FanColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: comrades.length,
                  itemBuilder: (context, index) {
                    final comrade = comrades[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: FanColors.surfaceSunken, // ✅ Changed
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              FootballAvatarManager.buildAvatar(
                                userId: comrade.userId,
                                username: comrade.username,
                                size: 40,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      comrade.username,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            FanColors.textPrimary, // ✅ Changed
                                      ),
                                    ),
                                    Text(
                                      comrade.nickname,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: FanColors
                                            .textSecondary, // ✅ Changed
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.sports_soccer,
                                          size: 12,
                                          color: FanColors.primary, // ✅ Changed
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          comrade.clubFan,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                FanColors.primary, // ✅ Changed
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.flag,
                                          size: 12,
                                          color: FanColors.draw, // ✅ Changed
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          comrade.countryFan,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: FanColors.draw, // ✅ Changed
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: comrade.selection == 'home_team'
                                      ? FanColors.primary.withValues(
                                          alpha: 0.1,
                                        )
                                      : comrade.selection == 'away_team'
                                          ? Colors.blue.withValues(alpha: 0.1)
                                          : Colors.purple
                                              .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  comrade.selection == 'home_team'
                                      ? '🏠 Home'
                                      : comrade.selection == 'away_team'
                                          ? '✈️ Away'
                                          : '🤝 Draw',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: comrade.selection == 'home_team'
                                        ? FanColors.primary // ✅ Changed
                                        : comrade.selection == 'away_team'
                                            ? Colors.blue
                                            : Colors.purple,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (comrade.comment != null &&
                              comrade.comment!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: FanColors.background, // ✅ Changed
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.comment,
                                    size: 12,
                                    color: FanColors.textSecondary, // ✅ Changed
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      comrade.comment!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: FanColors
                                            .textSecondary, // ✅ Changed
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            'Voted ${DateHelper.formatTimeAgo(comrade.votedAt)}',
                            style: TextStyle(
                              fontSize: 9,
                              color: FanColors.textSecondary, // ✅ Changed
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
      ),
    );
  }
}

// ========== FIXTURES PAGE ==========
class FixturesPage extends StatefulWidget {
  final String userId;
  final String username;
  final String? authToken;
  final ScrollController? scrollController;
  final VoidCallback? onLogout;
  final bool isLoggedIn;
  final bool syncToFixtures;
  final String? selectedChannelId;
  final String? selectedChannelName;
  final List<UserChannel> userChannels;
  //StreamSubscription<List<Fixture>>? _appCacheSubscription;
  // For pulsing animation

  const FixturesPage({
    super.key,
    required this.userId,
    required this.username,
    this.authToken,
    this.scrollController,
    this.onLogout,
    this.isLoggedIn = false,
    this.syncToFixtures = true,
    this.selectedChannelId,
    this.selectedChannelName,
    this.userChannels = const [],
  });

  @override
  State<FixturesPage> createState() => FixturesPageState();
}

class FixturesPageState extends State<FixturesPage>
    with
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin,
        TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;
  List<Fixture> _fixtures = List.from(AppCache.fixtures); // Load from RAM cache
  Map<String, ChannelFixtureData> _channelFixtureDataMap =
      Map.from(AppCache.channelFixtures);
  final Map<String, String?> _userVotes = Map.from(AppCache.userVotes);
  Timer? _threeMinRefreshTimer; // was an unnamed inline Timer.periodic before
  bool _backgroundWorkPaused = false;
  StreamSubscription<List<Fixture>>? _appCacheSubscription;
  Timer? _commentPollTimer;
  bool _showPledgesTab = true;
  bool _isProcessingPayment = false;
  Timer? _backgroundRefreshTimer;
  bool _isBackgroundPaused = false;
  DateTime? _lastResumeTime;
  static const Duration _resumeThrottle = Duration(seconds: 5);
  String? _currentCheckoutRequestId;
  StreamSubscription<void>? _appCacheVotesSubscription;
  // Add this to your state variables
  bool _isReturningFromChat = false;
  Map<String, int> _pendingCommentCounts =
      {}; // Store fresh counts before they get overwritten

// Add this to track if we've already refreshed after chat
  Set<String> _refreshedAfterChat = {};
  Timer? _pollingTimer;
  // Add with your other state variables (around line 200)
  final Map<String, DateTime> _lastWebSocketCommentUpdate = {};
  final Map<String, DateTime> _lastWebSocketVoteUpdate = {};
  final Map<String, DateTime> _lastWebSocketLatestCommentUpdate = {};
  // Store latest 3 commentary entries per fixture (like WhatsApp messages)
  final Map<String, List<LiveCommentaryEntry>> _liveCommentary = {};
  bool _wsStatusListenerAttached = false;
  bool _hasSufficientBalance(double amount) => _userBalance >= amount;
  double get _currentUserBalance => _userBalance;

// Set _loading to false immediately - no spinner
  bool _loading = false;
  void refreshFromAppCache() {
    if (AppCache.fixtures.isNotEmpty && mounted) {
      _safeSetState(() {
        _fixtures = List.from(AppCache.fixtures);
        _loading = false;
      });
      debugPrint('🔄 FixturesPage manually refreshed from AppCache');
    }
  }

  /// Add commentary to the sliding window (keeps last 3 entries)
  /// Like WhatsApp messages - newest at bottom, oldest drops off
  void _addCommentaryToWindow(String fixtureId, LiveCommentaryEntry entry) {
  List<LiveCommentaryEntry> entries = _liveCommentary[fixtureId] ?? [];
  entries.removeWhere((e) => e.text == entry.text && e.minute == entry.minute);
  entries.add(entry);
  if (entries.length > 1) entries = [entries.last];
  _liveCommentary[fixtureId] = entries;

  // ✅ mirror into AppCache so it survives disposal
  AppCache.setLiveCommentary(fixtureId, {
    'text': entry.text,
    'type': entry.type,
    'minute': entry.minute,
    'timestamp': entry.timestamp.toIso8601String(),
    'scorer': entry.scorer,
    'team': entry.team,
  });

  _safeSetState(() {});
}
  /// Everything that previously ran inline in initState() now runs here,
  /// scheduled for right after the first frame is already on screen. This
  /// is the "background" half of the split: disk-cache reconciliation,
  /// channel list, comrades, votes/likes/comments network fetches, the
  /// WebSocket connection, FCM listeners, polling timers, and live
  /// commentary all start here instead of blocking widget construction -
  /// exactly like AppCache.load() defers everything past the 4 critical keys.
  ///
  void _startDeferredInitialization() {
    _loadFromDiskCacheInstantly();

    _loadUserChannels();
    _loadPendingJoinRequests();
    _loadSavedUnreadStatuses();

    // ✅ LISTEN TO APPCACHE VOTE CHANGES
    _appCacheVotesSubscription = AppCache.votesStream.listen((_) {
      if (mounted) {
        final updatedVotes = AppCache.userVotes;
        bool hasChanges = false;

        for (var entry in updatedVotes.entries) {
          if (_userVotes[entry.key] != entry.value) {
            hasChanges = true;
            break;
          }
        }

        if (hasChanges) {
          _safeSetState(() {
            _userVotes.clear();
            _userVotes.addAll(updatedVotes);
          });
          debugPrint(
              '🔄 FixturesPage: Updated votes from AppCache (${updatedVotes.length} votes)');
        }
      }
    });

    if (_isUserLoggedIn()) {
      _fetchUserComrades();
      _fetchAllComradesWithProfiles();
      _fetchUserVotesFromBackend();
      _fetchUserLikesFromBackend();
      _fetchAllComments(forceRefresh: false);
      _fetchSubFixtureVotesForAll();
      _loadUnreadCountsFromBackend();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isUserLoggedIn()) {
          _connectWebSocket();
          _setupWebSocketListeners();
          _loadSavedUnreadStatuses();
        }
      });
    }

    _setupFCMListeners();
    _checkAndStoreVisibility();
    _startBackgroundRefreshTimer();

    // ✅ Initialize live commentary after fixtures are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLiveCommentary();
    });
  }

  void _loadFromAppCache() {
    if (!AppCache.isLoaded) return;

    setState(() {
      // Load fixtures
      if (AppCache.fixtures.isNotEmpty) {
        _fixtures = List.from(AppCache.fixtures);
      }

      // Load user votes
      _userVotes.clear();
      _userVotes.addAll(AppCache.userVotes);

      // Load comment counts
      for (var entry in AppCache.channelFixtures.entries) {
        _commentCounts[entry.key] = entry.value.commentCount;
      }

      // Load latest comments
      for (var fixture in _fixtures) {
        final comment = AppCache.getLatestComment(fixture.matchId);
        if (comment != null) {
          _featuredComments[fixture.matchId] = FeaturedComment(
            userId:
                AppCache.getLatestCommentAuthor(fixture.matchId) ?? 'system',
            username:
                AppCache.getLatestCommentAuthor(fixture.matchId) ?? 'Anonymous',
            comment: comment,
            teamSupport: '',
            avatarUrl: '',
            timestamp: AppCache.getLatestCommentTimestamp(fixture.matchId) ??
                DateTime.now(),
          );
        }
      }
    });
  }

  /// Populates per-fixture UI controllers/flags synchronously from whatever
  /// is already sitting in `_fixtures` (loaded from AppCache via the field
  /// initializers). Pure in-memory work, no I/O - safe to run directly
  /// inside initState() without delaying first paint by even a frame.
  void _initializeUiControllersSync() {
    for (var fixture in _fixtures) {
      final fixtureId = fixture.matchId;
      _commentControllers.putIfAbsent(fixtureId, () => TextEditingController());
      _showingRivals.putIfAbsent(fixtureId, () => false);
      _showingSupporters.putIfAbsent(fixtureId, () => false);
      _showingAllComments.putIfAbsent(fixtureId, () => false);
      _subFixturesExpanded.putIfAbsent(fixtureId, () => false);
    }
  }

  Timer? _commentaryPollTimer;

  Future<void> _fetchLatestCommentaryViaHttp(String fixtureId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
                '$API_BASE_URL/games/$fixtureId/commentary/latest?limit=1'),
            headers: await _buildHeaders(),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final List<dynamic> raw = data['commentary'] ?? [];
        if (raw.isEmpty) return;

        final latest = raw.first as Map;
        final minute = latest['minute'] as int? ?? 0;
        final text = latest['text']?.toString() ?? '';
        final type = latest['type']?.toString() ?? 'update';
        final createdAt = latest['createdAt'] != null
            ? DateTime.tryParse(latest['createdAt'].toString()) ??
                DateTime.now()
            : DateTime.now();

        // Skip if it's the same entry we already have — avoids flicker
        final existing = _liveCommentary[fixtureId];
        if (existing != null &&
            existing.isNotEmpty &&
            existing.last.text == text &&
            existing.last.minute == minute) {
          return;
        }

        final style = _getCommentaryStyle(type);
        final entry = LiveCommentaryEntry(
          text: text,
          type: type,
          minute: minute,
          timestamp: createdAt,
          color: style['color'] as Color,
          icon: style['icon'] as IconData,
        );
        _addCommentaryToWindow(fixtureId, entry);
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching latest commentary for $fixtureId: $e');
    }
  }

  void _startCommentaryPolling() {
    _commentaryPollTimer?.cancel();
    _commentaryPollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      for (var fixture in _fixtures) {
        if (fixture.isLive == true) {
          _fetchLatestCommentaryViaHttp(fixture.matchId);
        }
      }
    });
  }

  Map<String, dynamic> _getCommentaryStyle(String type) {
    switch (type) {
      case 'goal':
        return {
          'color': Colors.green,
          'icon': Icons.sports_soccer,
        };
      case 'yellow_card':
        return {
          'color': Colors.orange,
          'icon': Icons.warning_amber_rounded,
        };
      case 'red_card':
        return {
          'color': Colors.red,
          'icon': Icons.dangerous_rounded,
        };
      case 'substitution':
        return {
          'color': Colors.blue,
          'icon': Icons.sync_alt,
        };
      case 'half_time':
        return {
          'color': Colors.purple,
          'icon': Icons.timer_off_rounded,
        };
      case 'full_time':
        return {
          'color': Colors.red,
          'icon': Icons.stop_circle_rounded,
        };
      default:
        return {
          'color': Colors.grey,
          'icon': Icons.info_outline,
        };
    }
  }

  static const String API_BASE_URL = 'https://clash-api-m5mr.onrender.com/api';
  static const Duration REQUEST_TIMEOUT = Duration(seconds: 15);
  // Add with your other maps (around line 200)
  final Map<String, AnimationController> _badgeTimers = {};
  final Map<String, int> _pledgeCounts = {}; // fixtureId -> count
  // Dedupe so we don't re-POST "ensure channel fixture" on every chat open
  final Set<String> _ensuredChannelFixtures = {};
  final Map<String, List<Bettor>> _pledgers = {}; // fixtureId -> pledgers
  final Map<String, List<Bettor>> _bettors = {}; // fixtureId -> bettors
  final Map<String, String> _userPledges = {}; // fixtureId -> selection
  final Map<String, double> _pledgeAmounts = {}; // fixtureId -> amount
  final Map<String, bool> _loadingPledge = {}; // fixtureId -> loading
  double _userBalance = 0.0;
  final Map<String, Animation<double>> _badgeScaleAnimations = {};

  // Add this with your other maps
  final Map<String, bool> _subFixturesExpanded = {};
  // Add this with your other maps
  final Map<String, Map<String, Map<String, String>>> _voters =
      {}; // fixtureId -> {userId: {username, selection}}

  // Add this with your other maps
  Map<String, int> _voteCounts = {}; // fixtureId -> vote count
  UserChannel? _localSelectedChannel;
  List<UserChannel> _userChannels = List.from(AppCache.channels);
  bool _loadingChannels = false;
  final Map<String, UserChannel?> _fixtureChannelOverrides = {};

  final Map<String, List<LiveEvent>> _liveEvents = {};
  final Map<String, Timer?> _eventScrollTimers = {};
  final bool _autoScrollEnabled = true;
  // Add this getter (around line 100-150, with your other getters)

  // Auth service
  late final AuthService _authService;
  bool _isUserLoggedIn() {
    return widget.isLoggedIn &&
        widget.userId.isNotEmpty &&
        widget.userId != 'guest';
  }

  // Use global cache
  final GlobalCacheManager _cache = GlobalCacheManager();

  bool _refreshing = false;
  bool _isFetching = false;
  String _error = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isDisposed = false;
  Timer? _syncTimer;
  Timer? _refreshDebounceTimer;
  Set<String> _pendingJoinRequests = {};
  // Add this field at the top of _FixturesPageState:
  DateTime? _lastCommentFetchTime;
  static const Duration _minCommentFetchInterval = Duration(minutes: 10);
  StreamSubscription<Map<String, dynamic>>? _fcmBadgeSubscription;

  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  final Map<String, int> _unreadCounts = {};

  // Track unread per fixtur// For pulsing animation
  final Map<String, bool> _userLikes = {};

  final Map<String, VoteStatsResponse> _voteStats = {};
  final Map<String, LikeStatsResponse> _likeStats = {};
  final Map<String, int> _commentCounts = {};
  final Map<String, GameMetadata> _gameMetadata = {};
  final Map<String, bool> _loadingVote = {};
  final Map<String, bool> _loadingLike = {};
  final Map<String, bool> _loadingComment = {};
  final Map<String, TextEditingController> _commentControllers = {};

  // Store commenters with both userId and username
  final Map<String, Map<String, String>> _fixtureCommenters =
      {}; // fixtureId -> {userId: username}

  final Map<String, List<FixtureComment>> _fixtureComments = {};
  final Map<String, bool> _loadingComments = {};
  final Map<String, bool> _showingAllComments = {};

  // Featured comment for each fixture (auto-populated)
  final Map<String, FeaturedComment?> _featuredComments = {};

  Map<String, FixtureVoteData> _fixtureVoteData = {};
  bool _loadingVotes = false;

  final Map<String, bool> _showingRivals = {};
  final Map<String, bool> _showingSupporters = {};

  final Map<String, List<SubFixture>> _fixtureSubFixtures = {};
  final Map<String, Map<String, SubFixtureVoteData>> _subFixtureVoteData = {};
  final Map<String, bool> _loadingSubFixtureVote = {};
  bool _isLoggingOut = false;

  String? _lastEtag;
  int? _lastCacheTimestamp;
  static const String _cacheKey = 'fixtures_cache';
  static const String _timestampKey = 'fixtures_timestamp';
  static const String _etagKey = 'fixtures_etag';
  static const Duration _cacheValidityDuration = Duration(minutes: 30);
  static const Duration _pollingInterval = Duration(minutes: 10);
  static const Duration _backgroundPollingInterval = Duration(minutes: 30);
  Timer? _cachePollingTimer;
  String? _selectedChannelId;
  //List<UserChannel> _userChannels = [];
  final bool _showChannelSelector = false;

  // Random generator for mock data
  final Random _random = Random();

  // Sample usernames and comments for mock data
  final List<String> _sampleUsernames = [
    '⚽ GoalMachine',
    '🔥 FireStriker',
    '🛡️ DefenseWall',
    '🎯 Sniper',
    '💪 PowerShot',
    '✨ MagicFeet',
    '🏃 SpeedDemon',
    '🧠 TacticalGenius',
    '🌟 StarPlayer',
    '🎭 FalseNine',
    '⚡ LightningBolt',
    '🎨 Playmaker',
    '🔒 CleanSheet',
    '🎪 CircusSave',
    '🏆 ChampionMind',
    '📊 AnalystPro',
  ];

  final List<String> _sampleComments = [
    "What a match this is going to be! 🔥",
    "Home team looking strong today 💪",
    "Away team has been in great form lately 📈",
    "Can't wait for kickoff! ⏰",
    "This rivalry never disappoints ⚔️",
    "Both teams need this win badly 🎯",
    "The atmosphere will be electric ⚡",
    "Key players to watch out for 👀",
    "Prediction: lots of goals! 🥅",
    "Defensive battle incoming 🛡️",
    "Midfield will decide this one 🧠",
    "History suggests a close contest 📚",
    "Underdogs might surprise everyone 🐕",
    "Star player back from injury 🙌",
    "Perfect weather for football ☀️",
    "This is a must-win situation 🏆",
  ];

  final List<String> _sampleTeamSupports = [
    '🔴 Reds',
    '🔵 Blues',
    '🟢 Greens',
    '🟡 Yellows',
    '⚪ Whites',
    '⚫ Blacks',
    '🟠 Oranges',
    '🟣 Purples',
  ];

  // ========== NEW FOR COMRADE SYSTEM ==========
  final Map<String, FixtureNotificationState> _fixtureNotifications = {};
  final Map<String, List<ComradeWithProfile>> _comradeVoters = {};
  bool _loadingComrades = false;
  Set<String> _userComrades = {};

  // ========== NOTIFICATION BADGE METHODS ==========

  Map<String, Map<String, String>> _getVotersForFixture(String fixtureId) {
    final Map<String, Map<String, String>> voters = {};

    // Add current user if they voted
    if (_userVotes.containsKey(fixtureId)) {
      voters[widget.userId] = {
        'username': widget.username,
        'selection': _userVotes[fixtureId]!,
      };
    }

    // Add comrades from _comradeVoters
    final comrades = _comradeVoters[fixtureId] ?? [];
    for (var comrade in comrades) {
      voters[comrade.userId] = {
        'username': comrade.username,
        'selection': comrade.selection,
      };
    }

    // Also add from _fixtureVoteData
    final voteData = _fixtureVoteData[fixtureId];
    if (voteData != null) {
      for (var supporter in voteData.supporters) {
        if (!voters.containsKey(supporter.userId)) {
          voters[supporter.userId] = {
            'username': supporter.username,
            'selection': supporter.selection,
          };
        }
      }
      for (var rival in voteData.rivals) {
        if (!voters.containsKey(rival.userId)) {
          voters[rival.userId] = {
            'username': rival.username,
            'selection': rival.selection,
          };
        }
      }
    }

    return voters;
  }

  /// Decides what goes in the match-card preview area: live commentary
  /// during active play, or the latest chat comment during halftime and
  /// when the match isn't live. This is the ONLY place that should make
  /// this decision — _buildMatchCard just calls it.
  Widget _buildCommentaryOrCommentsPreview({
    required BuildContext context,
    required Fixture fixture,
    required String fixtureId,
    required FeaturedComment? latestComment,
    required int maxCommentLines,
  }) {
    final bool isLive = fixture.isLive == true;
    final bool isHalfTime = fixture.status == 'half_time' ||
        (fixture.timeElapsed != null &&
            fixture.timeElapsed! >= 44 &&
            fixture.timeElapsed! <= 46);

    // Live and NOT at halftime (covers both first half and second half,
    // since isHalfTime naturally flips back to false once play resumes) →
    // show commentary.
    if (isLive && !isHalfTime) {
      return _buildLiveCommentary(context, fixtureId);
    }

    // Halftime, or not live at all (upcoming/soon/completed) → show comments.
    return _chatLinePreview(
      latestComment: latestComment,
      fixtureId: fixtureId,
      maxLines: maxCommentLines,
    );
  }

  void _showPledgersPopup(Fixture fixture) {
    final fixtureId = fixture.matchId;
    final pledgers = _pledgers[fixtureId] ?? [];

    if (pledgers.isEmpty) {
      ToastHelper.showInfo('No pledges yet');
      return;
    }

    // ✅ Check visibility
    if (!_showPledgesTab) {
      ToastHelper.showInfo('Pledges are currently disabled');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: FanColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.attach_money,
                    color: Colors.amber.shade400, size: 20),
                const SizedBox(width: 8),
                Text(
                  '💰 Pledges (${pledgers.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            content: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: pledgers.length,
                itemBuilder: (context, index) {
                  final pledger = pledgers[index];
                  final isMe = pledger.userId == widget.userId;
                  final canMatch = !isMe && pledger.status == 'open';

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: FanColors.border.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        FootballAvatarManager.buildAvatar(
                          userId: pledger.userId,
                          username: pledger.userName,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMe ? 'You' : pledger.userName,
                                style: TextStyle(
                                  color:
                                      isMe ? FanColors.primary : Colors.white,
                                  fontWeight:
                                      isMe ? FontWeight.w700 : FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                pledger.selectionDisplay,
                                style: TextStyle(
                                  color: _getVoteColor(pledger.selection),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (canMatch)
                          GestureDetector(
                            onTap: () {
                              // ✅ Use the complete match flow like the modal
                              _matchPledgeFromDialog(pledger, fixture);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: FanColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'MATCH',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        Text(
                          'KES ${pledger.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: FanColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: TextStyle(color: FanColors.textSecondary),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _checkAndStoreVisibility() async {
    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/visibility/votes_button_show'),
        headers: await _buildHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _safeSetState(() {
          _showPledgesTab = data['value'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('❌ Error checking visibility: $e');
      _showPledgesTab = true;
    }
  }

  void _setupFCMListeners() {
    // Listen for foreground messages (app is open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📨 Received foreground message');
      _handleFCMNotification(message);
    });

    // Listen when app is opened from background/terminated state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📨 App opened from notification');
      _handleFCMNotificationTap(message);
    });

    // Check initial notification
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        debugPrint('📨 App opened from terminated state with notification');
        _handleFCMNotificationTap(message);
      }
    });

    // Listen to NotificationService's badge stream
    NotificationService.badgeStream.listen((event) {
      debugPrint('🔔 Badge stream event received: $event');
      _handleBadgeUpdate(event);
    });
  }

  // ✅ Complete match flow - same as modal
  String? _selectedDialogMatchOption;
  bool _isDialogMatching = false;

  Future<void> _matchPledgeFromDialog(Bettor pledger, Fixture fixture) async {
    if (_isDialogMatching) return;

    // Refresh balance first
    await _fetchUserBalance();

    // Check if user has enough balance
    if (_userBalance < pledger.amount) {
      final shortfall = pledger.amount - _userBalance;

      final shouldTopUp = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: FanColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FanRadius.lg),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text('Insufficient Balance'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FanColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: FanColors.border.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You need KES ${pledger.amount.toStringAsFixed(2)} to match this pledge',
                      style: TextStyle(color: FanColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your balance: KES ${_userBalance.toStringAsFixed(2)}',
                      style: TextStyle(color: FanColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Shortfall: KES ${shortfall.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: FanColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: FanColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Top up the shortfall amount (KES ${shortfall.toStringAsFixed(2)}) to continue',
                        style: TextStyle(
                          fontSize: 11,
                          color: FanColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: FanColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: FanColors.primary,
              ),
              child: const Text('Top Up & Match'),
            ),
          ],
        ),
      );

      if (shouldTopUp != true) return;

      final topUpSuccess = await _initiateSTKPushFromDialog(
        shortfall,
        purpose: 'Top up to match pledge',
      );

      if (!topUpSuccess) {
        ToastHelper.showError('Top-up failed. Please try again.');
        return;
      }

      await _fetchUserBalance();

      if (_userBalance < pledger.amount) {
        ToastHelper.showError('Balance still insufficient after top-up');
        return;
      }
    }

    // ✅ Show match confirmation (only opposite selection)
    _showDialogMatchConfirmation(pledger, fixture);
  }

  void _showDialogMatchConfirmation(Bettor pledger, Fixture fixture) {
    // Get opposite selection only
    String oppositeSelection;
    String oppositeTitle;
    Color oppositeColor;

    if (pledger.selection == 'home_team' || pledger.selection == 'home') {
      oppositeSelection = 'away';
      oppositeTitle = fixture.awayTeam;
      oppositeColor = const Color(0xFF2563EB);
    } else if (pledger.selection == 'away_team' ||
        pledger.selection == 'away') {
      oppositeSelection = 'home';
      oppositeTitle = fixture.homeTeam;
      oppositeColor = FanColors.primary;
    } else {
      // Draw - show both options
      _showDialogDrawMatchConfirmation(pledger, fixture);
      return;
    }

    _selectedDialogMatchOption = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: FanColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FanRadius.lg),
            ),
            title: const Text('Match Pledge'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FanColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: FanColors.border.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pledger: ${pledger.userName}',
                        style: TextStyle(color: FanColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Their pick: ${pledger.selectionDisplay}',
                        style: TextStyle(color: FanColors.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Amount: KES ${pledger.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: FanColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your balance: KES ${_userBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You must pick the opposite team:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(
                      () => _selectedDialogMatchOption = oppositeSelection),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedDialogMatchOption == oppositeSelection
                          ? oppositeColor.withOpacity(0.15)
                          : FanColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedDialogMatchOption == oppositeSelection
                            ? oppositeColor
                            : FanColors.border.withOpacity(0.3),
                        width: _selectedDialogMatchOption == oppositeSelection
                            ? 2
                            : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        oppositeTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              _selectedDialogMatchOption == oppositeSelection
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                          color: _selectedDialogMatchOption == oppositeSelection
                              ? oppositeColor
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.block, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You cannot pick ${pledger.selectionDisplay} (already taken)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Vote will be auto-cast if you haven\'t voted yet',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _selectedDialogMatchOption = null;
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _selectedDialogMatchOption == null
                    ? null
                    : () async {
                        setState(() => _isDialogMatching = true);
                        await _executeDialogMatch(
                          pledger,
                          _selectedDialogMatchOption!,
                          fixture,
                        );
                        setState(() => _isDialogMatching = false);
                        Navigator.pop(context); // Close match dialog
                        Navigator.pop(context); // Close pledges dialog
                        // Refresh pledges
                        await _refreshPledgeDataForFixture(fixture.matchId);
                        _safeSetState(() {});
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FanColors.primary,
                ),
                child: _isDialogMatching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Confirm Match'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDialogDrawMatchConfirmation(Bettor pledger, Fixture fixture) {
    _selectedDialogMatchOption = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: FanColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FanRadius.lg),
            ),
            title: const Text('Match Pledge'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FanColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: FanColors.border.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pledger: ${pledger.userName}',
                        style: TextStyle(color: FanColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Their pick: ${pledger.selectionDisplay} (Draw)',
                        style: TextStyle(color: FanColors.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Amount: KES ${pledger.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: FanColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your balance: KES ${_userBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Choose your pick (Draw is taken):',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildDialogMatchOption(
                      title: fixture.homeTeam,
                      selection: 'home',
                      isSelected: _selectedDialogMatchOption == 'home',
                      color: FanColors.primary,
                      onTap: () =>
                          setState(() => _selectedDialogMatchOption = 'home'),
                    ),
                    const SizedBox(width: 8),
                    _buildDialogMatchOption(
                      title: fixture.awayTeam,
                      selection: 'away',
                      isSelected: _selectedDialogMatchOption == 'away',
                      color: const Color(0xFF2563EB),
                      onTap: () =>
                          setState(() => _selectedDialogMatchOption = 'away'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.block, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You cannot pick Draw (already taken)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Vote will be auto-cast if you haven\'t voted yet',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _selectedDialogMatchOption = null;
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _selectedDialogMatchOption == null
                    ? null
                    : () async {
                        setState(() => _isDialogMatching = true);
                        await _executeDialogMatch(
                          pledger,
                          _selectedDialogMatchOption!,
                          fixture,
                        );
                        setState(() => _isDialogMatching = false);
                        Navigator.pop(context);
                        Navigator.pop(context);
                        await _refreshPledgeDataForFixture(fixture.matchId);
                        _safeSetState(() {});
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FanColors.primary,
                ),
                child: _isDialogMatching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Confirm Match'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDialogMatchOption({
    required String title,
    required String selection,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : FanColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : FanColors.border.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _executeDialogMatch(
    Bettor pledger,
    String selection,
    Fixture fixture,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/actions/bet/fill'),
            headers: await _buildHeaders(),
            body: json.encode({
              'bet_id': pledger.betId,
              'finisher_id': widget.userId,
              'finisher_name': widget.username,
              'finisher_selection': selection,
              'amount': pledger.amount,
              'channel_id': '', // ✅ Send empty string to match database
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (data['success'] == true) {
        ToastHelper.showSuccess('✅ Bet matched successfully! 🎉');
        // Refresh will be handled by caller
      } else {
        ToastHelper.showError(data['message'] ?? 'Failed to match bet');
      }
    } catch (e) {
      ToastHelper.showError('Error: ${e.toString()}');
    }
  }

  Future<bool> _waitForSTKCompletion(String checkoutRequestId) async {
    final completer = Completer<bool>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: FanColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FanRadius.lg),
        ),
        title: const Text('Processing Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: FanColors.primary),
            const SizedBox(height: 16),
            Text(
              'Enter PIN on your phone to complete payment',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This will automatically update your balance',
              style: TextStyle(
                fontSize: 10,
                color: FanColors.primary.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _pollingTimer?.cancel();
                completer.complete(false);
              },
              child: const Text('Cancel Payment'),
            ),
          ],
        ),
      ),
    );

    bool isCompleted = false;
    int attempts = 0;
    const maxAttempts = 60;

    while (!isCompleted && attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 1));
      attempts++;

      try {
        final status = await _checkSTKStatus(checkoutRequestId);
        if (status == 'completed') {
          isCompleted = true;
          ToastHelper.showSuccess('Payment successful!');
          if (mounted) Navigator.pop(context);
          completer.complete(true);
          break;
        } else if (status == 'failed' || status == 'cancelled') {
          isCompleted = true;
          ToastHelper.showError(
              'Payment ${status == 'cancelled' ? 'cancelled' : 'failed'}');
          if (mounted) Navigator.pop(context);
          completer.complete(false);
          break;
        }
      } catch (e) {
        debugPrint('❌ Status check error: $e');
      }
    }

    if (!isCompleted) {
      ToastHelper.showWarning('Payment timeout - check your phone');
      if (mounted) Navigator.pop(context);
      completer.complete(false);
    }

    return completer.future;
  }

  Future<String> _checkSTKStatus(String checkoutRequestId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/lipaclash/check-payment-status'),
            headers: await _buildHeaders(),
            body: json.encode({'checkout_request_id': checkoutRequestId}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) return 'completed';
        if (data['failed'] == true) return 'failed';
        if (data['cancelled'] == true) return 'cancelled';
        return 'pending';
      }
      return 'pending';
    } catch (e) {
      debugPrint('❌ Status check error: $e');
      return 'pending';
    }
  }

  Future<bool> _waitForSTKCompletionFromDialog(String checkoutRequestId) async {
    final completer = Completer<bool>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: FanColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FanRadius.lg),
        ),
        title: const Text('Processing Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: FanColors.primary),
            const SizedBox(height: 16),
            Text(
              'Enter PIN on your phone to complete payment',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This will automatically update your balance',
              style: TextStyle(
                fontSize: 12,
                color: FanColors.primary.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _pollingTimer?.cancel();
                completer.complete(false);
              },
              child: const Text('Cancel Payment'),
            ),
          ],
        ),
      ),
    );

    bool isCompleted = false;
    int attempts = 0;
    const maxAttempts = 60;

    while (!isCompleted && attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 1));
      attempts++;

      try {
        final status = await _checkSTKStatusFromDialog(checkoutRequestId);
        if (status == 'completed') {
          isCompleted = true;
          ToastHelper.showSuccess('Payment successful!');
          if (mounted) Navigator.pop(context);
          completer.complete(true);
          break;
        } else if (status == 'failed' || status == 'cancelled') {
          isCompleted = true;
          ToastHelper.showError(
              'Payment ${status == 'cancelled' ? 'cancelled' : 'failed'}');
          if (mounted) Navigator.pop(context);
          completer.complete(false);
          break;
        }
      } catch (e) {
        debugPrint('❌ Status check error: $e');
      }
    }

    if (!isCompleted) {
      ToastHelper.showWarning('Payment timeout - check your phone');
      if (mounted) Navigator.pop(context);
      completer.complete(false);
    }

    return completer.future;
  }

  Future<String> _checkSTKStatusFromDialog(String checkoutRequestId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/lipaFunzy/check-payment-status'),
            headers: await _buildHeaders(),
            body: json.encode({'checkout_request_id': checkoutRequestId}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) return 'completed';
        if (data['failed'] == true) return 'failed';
        if (data['cancelled'] == true) return 'cancelled';
        return 'pending';
      }
      return 'pending';
    } catch (e) {
      debugPrint('❌ Status check error: $e');
      return 'pending';
    }
  }

  Future<void> _loadPendingJoinRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending =
          prefs.getStringList('pending_join_requests_${widget.userId}') ?? [];
      setState(() {
        _pendingJoinRequests = pending.toSet();
      });
      debugPrint(
          '✅ Loaded ${_pendingJoinRequests.length} pending join requests');
    } catch (e) {
      debugPrint('⚠️ Error loading pending requests: $e');
    }
  }

  void _handleFCMNotificationTap(RemoteMessage message) {
    try {
      final data = message.data;
      final fixtureId = data['fixture_id'] as String?;
      final notificationType = data['notificationType'] as String?;

      debugPrint(
        '📨 FCM Tap - Notification Type: $notificationType, FixtureId: $fixtureId',
      );

      if (fixtureId == null) return;

      // Find the fixture in the list
      final fixture = _fixtures.firstWhere(
        (f) => f.matchId == fixtureId,
        orElse: () => null as Fixture,
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _clearUnreadCount(fixtureId);
          if (_userVotes.containsKey(fixtureId)) {
            // _openComradeVotingModal(fixture);
          } else {
            _openVotesOnlyModal(fixture);
          }
        }
      });
    } catch (e) {
      debugPrint('❌ Error handling FCM tap: $e');
    }
  }
// ============================================================================
// PLEDGE METHODS
// ============================================================================

  /// Like _processVote, but returns whether the vote actually succeeded,
  /// and suppresses its own success/error toasts so the caller can decide
  /// what message to show (used by the pledge flow).
  Future<bool> _processVoteAndReturnSuccess(
      Fixture fixture, String selection) async {
    final fixtureId = fixture.matchId;

    String backendSelection = selection;
    if (selection == "home_team") {
      backendSelection = "home";
    } else if (selection == "away_team") {
      backendSelection = "away";
    } else if (selection == "draw") {
      backendSelection = "draw";
    }

    _safeSetState(() => _loadingVote[fixtureId] = true);

    try {
      final result = await VoteService.castVote(
        fixtureId: fixtureId,
        userId: widget.userId,
        username: widget.username,
        selection: backendSelection,
        authToken: widget.authToken,
      );

      if (result['success'] == true) {
        _safeSetState(() {
          _userVotes[fixtureId] = selection;
          _voteCounts[fixtureId] = (_voteCounts[fixtureId] ?? 0) + 1;

          if (!_comradeVoters.containsKey(fixtureId)) {
            _comradeVoters[fixtureId] = [];
          }
          _comradeVoters[fixtureId]!.add(
            ComradeWithProfile(
              userId: widget.userId,
              username: widget.username,
              nickname: widget.username,
              clubFan: '',
              countryFan: '',
              selection: selection,
              votedAt: DateTime.now(),
              comment: null,
            ),
          );
        });

        _refreshVotersDataForFixture(fixtureId);
        _refreshVoteDataForFixture(fixtureId);
        return true;
      }

      if (result['message']?.contains('already voted') == true) {
        // Already voted is not a failure for pledge purposes —
        // the selection is still recorded against this user.
        await _fetchUserVotesFromBackend();
        return true;
      }

      debugPrint('❌ Vote failed during pledge flow: ${result['message']}');
      return false;
    } catch (e) {
      debugPrint('❌ Error voting during pledge flow: $e');
      return false;
    } finally {
      _safeSetState(() => _loadingVote[fixtureId] = false);
    }
  }

  Future<double> _getUserBalance() async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (widget.authToken != null && widget.authToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${widget.authToken}';
      }

      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/auth/user/id/${widget.userId}'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return (data['user']['balance'] ?? 0.0).toDouble();
        }
        return 0.0;
      }
      return 0.0;
    } catch (e) {
      debugPrint('❌ Error fetching balance: $e');
      return 0.0;
    }
  }

  // fixture_page.dart — inside FixturesPageState, anywhere after initState()

  // ── Tab-visibility refresh (public API for HomePage) ──
  DateTime? _lastTabVisibleRefresh;
  static const Duration _tabVisibleStaleThreshold = Duration(seconds: 20);

  /// Called by HomePage every time the user swipes back to this tab.
  /// FixturesPage is kept alive (AutomaticKeepAliveClientMixin), so
  /// initState() never re-runs on tab switch — this is the replacement
  /// hook that guarantees fresh data is fetched when the tab becomes visible
  /// again, instead of silently showing whatever was cached at first load.
  void forceRefreshOnTabVisible() {
    if (!mounted) return;

    final now = DateTime.now();
    if (_lastTabVisibleRefresh != null &&
        now.difference(_lastTabVisibleRefresh!) < _tabVisibleStaleThreshold) {
      debugPrint(
        '⏭️ Skipping tab-visible refresh — refreshed '
        '${now.difference(_lastTabVisibleRefresh!).inSeconds}s ago',
      );
      return;
    }
    _lastTabVisibleRefresh = now;

    debugPrint('👀 Fixtures tab became visible — forcing fresh fetch');
    _fetchFixtures(forceRefresh: true, showNotification: false);
  }

  /// Called by HomePage on login/logout, replacing the old key-bump reset.
  void forceCompleteRefreshExternally() {
    if (!mounted) return;
    _lastTabVisibleRefresh =
        null; // reset the debounce so login/logout always forces through
    _forceCompleteRefresh();
  }

  Future<void> _fetchUserBalance({bool forceRefresh = false}) async {
    if (!_isUserLoggedIn()) {
      _safeSetState(() => _userBalance = 0.0);
      return;
    }

    try {
      final balance = await PaymentService.getUserBalance(
        userId: widget.userId,
        authToken: widget.authToken,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        _safeSetState(() => _userBalance = balance);
        debugPrint('✅ Balance refreshed: $_userBalance');
      }
    } catch (e) {
      debugPrint('❌ Error fetching balance: $e');
    }
  }

  Future<bool> _initiateSTKPush(
    double amount, {
    String? phoneNumber,
    String? purpose,
  }) async {
    if (_isProcessingPayment) return false;
    _safeSetState(() => _isProcessingPayment = true);

    try {
      String phone = phoneNumber ?? '';
      if (phone.isEmpty) {
        phone = await _getUserPhoneForPayment();
      }

      if (phone.isEmpty) {
        ToastHelper.showError(
          'Phone number required. Please update your profile.',
        );
        _safeSetState(() => _isProcessingPayment = false);
        return false;
      }

      final result = await PaymentService.initiateSTKPush(
        userId: widget.userId,
        username: widget.username,
        amount: amount,
        phoneNumber: phone,
        authToken: widget.authToken,
        purpose: purpose ?? 'Top up balance',
        fixtureId: null, // Not needed for generic top-up
        voteId: null,
      );

      _safeSetState(() => _isProcessingPayment = false);

      if (result.isSuccess) {
        if (result.newBalance != null) {
          _safeSetState(() => _userBalance = result.newBalance!);
        }
        ToastHelper.showSuccess(result.message ?? 'Payment successful!');
        return true;
      } else {
        ToastHelper.showError(result.error ?? 'Payment failed');
        return false;
      }
    } catch (e) {
      debugPrint('❌ STK Push error: $e');
      ToastHelper.showError('Failed to initiate payment');
      _safeSetState(() => _isProcessingPayment = false);
      return false;
    }
  }

  Future<bool> _initiateSTKPushFromDialog(double amount,
      {String? purpose}) async {
    if (_isProcessingPayment) return false;

    _safeSetState(() => _isProcessingPayment = true);

    try {
      final phoneNumber = await _getUserPhone();
      if (phoneNumber.isEmpty) {
        ToastHelper.showError(
          'Phone number required. Please update your profile.',
        );
        _safeSetState(() => _isProcessingPayment = false);
        return false;
      }

      final result = await PaymentService.initiateSTKPush(
        userId: widget.userId,
        username: widget.username,
        amount: amount,
        phoneNumber: phoneNumber,
        authToken: widget.authToken,
        purpose: purpose ?? 'Top up balance',
        fixtureId: null,
        voteId: null,
      );

      _safeSetState(() => _isProcessingPayment = false);

      if (result.isSuccess) {
        if (result.newBalance != null) {
          _safeSetState(() => _userBalance = result.newBalance!);
        }
        ToastHelper.showSuccess(result.message ?? 'Payment successful!');
        return true;
      } else {
        ToastHelper.showError(result.error ?? 'Payment failed');
        return false;
      }
    } catch (e) {
      debugPrint('❌ STK Push error: $e');
      ToastHelper.showError('Failed to initiate payment');
      _safeSetState(() => _isProcessingPayment = false);
      return false;
    }
  }

// REMOVE these methods entirely (they're now handled by PaymentService):
// - _waitForSTKCompletion
// - _waitForSTKCompletionFromDialog
// - _checkSTKStatus
// - _checkSTKStatusFromDialog

  Future<bool> _processWithdrawal({
    required double amount,
    required String phone,
  }) async {
    _safeSetState(() => _isProcessingPayment = true);

    try {
      // Use PaymentService for withdrawal (B2C)
      final result = await PaymentService.initiateB2CPayment(
        userId: widget.userId,
        username: widget.username,
        channelId: '', // Not needed for user withdrawals
        amount: amount,
        phoneNumber: phone,
        authToken: widget.authToken,
        remarks: 'User withdrawal',
        occasion: 'Withdrawal',
      );

      _safeSetState(() => _isProcessingPayment = false);

      if (result.isSuccess) {
        if (result.newBalance != null) {
          _safeSetState(() => _userBalance = result.newBalance!);
        }
        ToastHelper.showSuccess(result.message ?? 'Withdrawal successful!');
        return true;
      } else {
        ToastHelper.showError(result.error ?? 'Withdrawal failed');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Withdrawal error: $e');
      ToastHelper.showError('Failed to process withdrawal');
      _safeSetState(() => _isProcessingPayment = false);
      return false;
    }
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

 
  /// Initialize live commentary from existing events

  /// Add commentary to the sliding window (keeps last 3 entries)
  /// Like WhatsApp messages - newest at bottom, oldest drops off

  /// Get commentary style based on type

  /// Build the live commentary widget (sliding window of 3)
  ///
  Future<String?> _getSavedPhone(String kind) async {
    try {
      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/auth/user/${widget.userId}/$kind-phone'),
            headers: await _buildHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final phone = data['phone']?.toString();
          if (phone != null && phone.isNotEmpty) {
            debugPrint('📞 Loaded saved $kind phone: $phone');
            return phone;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Error fetching saved $kind phone: $e');
      return null;
    }
  }

  Future<void> _fetchVoteCountViaHttp(String fixtureId,
      {String? channelId}) async {
    // ✅ CHECK: If WebSocket updated within last 5 seconds, skip
    final lastWsUpdate = AppCache.getLastVoteUpdate(fixtureId);
    if (lastWsUpdate != null &&
        DateTime.now().difference(lastWsUpdate).inSeconds < 5) {
      debugPrint(
          '⏭️ Skipping HTTP vote count (WebSocket is fresher) for $fixtureId');
      return;
    }

    try {
      final effectiveChannelId = channelId ?? _resolveChannelIdFor(fixtureId);
      if (effectiveChannelId == null) return;

      final response = await http
          .get(
            Uri.parse(
                '$API_BASE_URL/actions/channel/$effectiveChannelId/$fixtureId/votes'),
            headers: await _buildHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final totalVotes = data['vote_count'] ?? data['count'] ?? 0;

        final wsUpdateDuringRequest = AppCache.getLastVoteUpdate(fixtureId);
        if (wsUpdateDuringRequest != null &&
            DateTime.now().difference(wsUpdateDuringRequest).inSeconds < 2) {
          debugPrint(
              '⏭️ Skipping HTTP vote count (WebSocket updated during request)');
          return;
        }

        _safeSetState(() {
          _voteCounts[fixtureId] = totalVotes;
        });

        AppCache.applyUpdate(
          fixtureId: fixtureId,
          updateType: 'vote',
          value: totalVotes,
          extraData: {'channelId': effectiveChannelId},
        );
        await AppCache.saveVoteCount(fixtureId, totalVotes);
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching vote count for $fixtureId: $e');
    }
  }

  // In FixturesPageState

// ============================================================================
// PROCESS VOTE - UPDATED WITH APPCACHE
// ============================================================================

// Helper methods to get vote counts
  int _homeVotesForFixture(String fixtureId) {
    return _channelFixtureDataMap[fixtureId]?.homeVotes ?? 0;
  }

  int _awayVotesForFixture(String fixtureId) {
    return _channelFixtureDataMap[fixtureId]?.awayVotes ?? 0;
  }

  int _drawVotesForFixture(String fixtureId) {
    return _channelFixtureDataMap[fixtureId]?.drawVotes ?? 0;
  }

  // In fixture_page.dart - Update _loadUserChannels method

  Future<void> _loadUserChannels() async {
    if (!widget.isLoggedIn || widget.authToken == null) {
      setState(() {
        _userChannels = [];
        _loadingChannels = false;
      });
      return;
    }

    // Show cached channels INSTANTLY if we have them
    if (AppCache.channels.isNotEmpty && _userChannels.isEmpty) {
      final cachedChannels = List<UserChannel>.from(AppCache.channels);

      // ✅ PRIORITIZE: Use selectedChannelId from widget first
      UserChannel? initialChannel;
      if (widget.selectedChannelId != null && cachedChannels.isNotEmpty) {
        initialChannel = cachedChannels.firstWhere(
          (c) => c.channelId == widget.selectedChannelId,
          orElse: () => cachedChannels.first,
        );
        debugPrint(
            '✅ Using selected channel from HomePage: ${initialChannel?.name}');
      } else if (cachedChannels.isNotEmpty) {
        initialChannel = cachedChannels.first;
      }

      setState(() {
        _userChannels = cachedChannels;
        _localSelectedChannel = initialChannel;
        _fixtureChannelOverrides.clear();
        _loadingChannels = false;
      });

      // ✅ Load data for the selected channel immediately
      if (initialChannel != null) {
        _loadAllDataForChannel(initialChannel.channelId);
      }

      debugPrint('⚡ INSTANT: ${cachedChannels.length} channels from AppCache');
    } else {
      setState(() => _loadingChannels = true);
    }

    // Always hit the network to keep AppCache fresh
    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/channels/user/${widget.userId}'),
        headers: {
          'Authorization': 'Bearer ${widget.authToken}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final List<dynamic> channelsData = data['channels'] ?? [];
        final loadedChannels =
            channelsData.map((c) => UserChannel.fromJson(c)).toList();

        AppCache.channels = List.from(loadedChannels);
        await AppCache.saveChannels(loadedChannels);

        // ✅ PRIORITIZE: Use selectedChannelId from widget
        UserChannel? initialChannel;
        if (widget.selectedChannelId != null && loadedChannels.isNotEmpty) {
          initialChannel = loadedChannels.firstWhere(
            (c) => c.channelId == widget.selectedChannelId,
            orElse: () => loadedChannels.first,
          );
          debugPrint(
              '✅ Using selected channel from HomePage (network): ${initialChannel?.name}');
        } else if (loadedChannels.isNotEmpty) {
          // Preserve current selection if it still exists
          if (_localSelectedChannel != null) {
            initialChannel = loadedChannels.firstWhere(
              (c) => c.channelId == _localSelectedChannel!.channelId,
              orElse: () => loadedChannels.first,
            );
          } else {
            initialChannel = loadedChannels.first;
          }
        }

        setState(() {
          _userChannels = loadedChannels;
          _localSelectedChannel = initialChannel;
          _loadingChannels = false;
        });

        // ✅ Load data for the selected channel
        if (initialChannel != null) {
          _loadAllDataForChannel(initialChannel.channelId);
        }

        debugPrint('✅ Loaded ${loadedChannels.length} channels from API');
      } else {
        debugPrint('⚠️ Channel fetch failed: ${response.statusCode}');
        _fallbackToCachedChannels();
      }
    } catch (e) {
      debugPrint('❌ Error loading channels: $e');
      _fallbackToCachedChannels();
    }
  }

// ✅ NEW METHOD: Load all data for a specific channel
  Future<void> _loadAllDataForChannel(String channelId) async {
    debugPrint('🔄 Loading ALL data for channel: $channelId');

    try {
      // Fetch channel fixtures
      await _fetchAndCacheChannelFixtures();

      // Fetch vote counts
      for (var fixture in _fixtures) {
        await _fetchVoteCountViaHttp(fixture.matchId, channelId: channelId);
        await _fetchCommentCountViaHttp(fixture.matchId, channelId: channelId);
        await _fetchPledgeDataForChannel(fixture.matchId, channelId);
      }

      // Fetch latest comments
      for (var fixture in _fixtures) {
        await _fetchLatestCommentViaHttp(fixture.matchId, fixture);
      }

      // Fetch user votes
      await _fetchUserVotesFromBackend();

      // Refresh UI
      _safeSetState(() {});
      debugPrint('✅ Loaded all data for channel: $channelId');
    } catch (e) {
      debugPrint('❌ Error loading data for channel $channelId: $e');
    }
  }

// ✅ NEW METHOD: Fetch pledges for a specific channel
  Future<void> _fetchPledgeDataForChannel(
      String fixtureId, String channelId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
                '$API_BASE_URL/actions/channel/$channelId/$fixtureId/pledges'),
            headers: await _buildHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final List<dynamic> pledgesData = data['pledges'] ?? [];
        final count = data['count'] ?? 0;

        _safeSetState(() {
          _pledgeCounts[fixtureId] = count;
          _pledgers[fixtureId] =
              pledgesData.map((p) => Bettor.fromOpenBet(p)).toList();
        });
        _saveToGlobalCache();
        debugPrint(
            '✅ Loaded ${pledgesData.length} pledges for fixture $fixtureId in channel $channelId');
      }
    } catch (e) {
      debugPrint(
          '⚠️ Error fetching pledges for $fixtureId in channel $channelId: $e');
    }
  }

// ✅ UPDATE: Force refresh when selected channel changes
  @override
  void didUpdateWidget(FixturesPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedChannelId != widget.selectedChannelId) {
      debugPrint('🔄 Selected channel changed');

      // ✅ CLEAR PENDING COUNTS ON CHANNEL SWITCH
      _clearPendingCounts();

      if (_userChannels.isNotEmpty) {
        final match = widget.selectedChannelId != null
            ? _userChannels.firstWhere(
                (c) => c.channelId == widget.selectedChannelId,
                orElse: () => _userChannels.first,
              )
            : _userChannels.first;

        _safeSetState(() {
          _localSelectedChannel = match;
          _fixtureChannelOverrides.clear();
        });

        if (match != null && match.channelId.isNotEmpty) {
          _loadAllDataForChannel(match.channelId);
          _fetchFixtures(forceRefresh: true, showNotification: false);
        }
      }
    }

    if (oldWidget.userId != widget.userId && widget.userId.isNotEmpty) {
      _refreshUserData();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _isUserLoggedIn()) {
          _forceReloadRivalsAndSupporters();
          _fetchUserComrades();
          _fetchAllComradesWithProfiles();
          if (_localSelectedChannel != null) {
            _loadAllDataForChannel(_localSelectedChannel!.channelId);
          }
        }
      });
    }
  }

// ✅ UPDATE: Method to change channel from within FixturesPage
  Future<void> _switchChannel(UserChannel newChannel) async {
    if (_localSelectedChannel?.channelId == newChannel.channelId) return;

    debugPrint('🔄 Switching to channel: ${newChannel.name}');

    _safeSetState(() {
      _localSelectedChannel = newChannel;
      _fixtureChannelOverrides.clear();
    });

    // ✅ CLEAR OLD DATA (optional - or just reload)
    _pledgeCounts.clear();
    _pledgers.clear();
    _bettors.clear();
    _voteCounts.clear();
    _commentCounts.clear();
    _featuredComments.clear();

    // ✅ LOAD NEW DATA
    await _loadAllDataForChannel(newChannel.channelId);
    await _fetchFixtures(forceRefresh: true, showNotification: false);

    ToastHelper.showSuccess('Switched to "${newChannel.name}"');
  }

  // Add after _getUserPhone() method

  void _fallbackToCachedChannels() {
    if (AppCache.channels.isNotEmpty) {
      setState(() {
        _userChannels = List<UserChannel>.from(AppCache.channels);
        _loadingChannels = false;
      });
      debugPrint('📦 Using AppCache channels as fallback');
    } else {
      setState(() {
        _userChannels = [];
        _loadingChannels = false;
      });
    }
  }

// ✅ BACKGROUND REFRESH METHOD
  Future<void> _refreshChannelsInBackground() async {
    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/channels/user/${widget.userId}'),
        headers: {
          'Authorization': 'Bearer ${widget.authToken}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final List<dynamic> channelsData = data['channels'] ?? [];
        final loadedChannels =
            channelsData.map((c) => UserChannel.fromJson(c)).toList();

        // Update AppCache
        AppCache.channels = List.from(loadedChannels);
        await AppCache.saveChannels(loadedChannels);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'channels_last_fetch', DateTime.now().toIso8601String());

        // Update UI if needed
        setState(() {
          _userChannels = loadedChannels;
        });

        debugPrint(
            '✅ Background channel refresh completed: ${loadedChannels.length} channels');
      }
    } catch (e) {
      debugPrint('❌ Background channel refresh error: $e');
    }
  }

  // Add this method to get the appropriate bets to display
  List<Bettor> _getDisplayBetsForFixture(String fixtureId) {
    final pledges = _pledgers[fixtureId] ?? [];

    // If there are pledges, return them
    if (pledges.isNotEmpty) {
      return pledges;
    }

    // Otherwise, return matched bets
    final matchedBets = _bettors[fixtureId] ?? [];
    return matchedBets.where((b) => b.isMatched).toList();
  }

// Add this method to get the display title
  String _getBetsDisplayTitle(String fixtureId) {
    final pledges = _pledgers[fixtureId] ?? [];
    if (pledges.isNotEmpty) {
      return '💰 Pledges';
    }
    final matchedBets = _bettors[fixtureId] ?? [];
    if (matchedBets.any((b) => b.isMatched)) {
      return '⚡ Matched Bets';
    }
    return 'No Bets';
  }

// Add this method to get the display icon
  IconData _getBetsDisplayIcon(String fixtureId) {
    final pledges = _pledgers[fixtureId] ?? [];
    if (pledges.isNotEmpty) {
      return Icons.attach_money;
    }
    return Icons.handshake;
  }

// Add this method to get the display color
  Color _getBetsDisplayColor(String fixtureId) {
    final pledges = _pledgers[fixtureId] ?? [];
    if (pledges.isNotEmpty) {
      return Colors.amber.shade400;
    }
    return Colors.blue;
  }

  void _showNotificationSnackbar(Map<String, dynamic> data) {
    final notificationType = data['notificationType'];
    final title = data['title'] ?? '';
    final body = data['body'] ?? '';
    final fixtureId = data['fixture_id'];
    final username =
        data['voter_username'] ?? data['commenter_username'] ?? 'Someone';

    IconData icon;
    Color color;

    if (notificationType?.contains('vote') == true) {
      icon = Icons.how_to_vote;
      color = Colors.purple;
    } else {
      icon = Icons.chat_bubble;
      color = FanColors.primary; // ✅ Changed
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                  Text(
                    body,
                    style: TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        backgroundColor: FanColors.surface, // ✅ Changed
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: color,
          onPressed: () {
            _scrollToFixtureAndOpenComradeModal(fixtureId);
          },
        ),
      ),
    );
  }

  void _scrollToFixtureAndOpenComradeModal(String fixtureId) {
    final index = _fixtures.indexWhere((f) => f.matchId == fixtureId);
    if (index != -1 && widget.scrollController != null) {
      // Calculate position to scroll to
      final position = index * 200.0; // Approximate card height
      widget.scrollController!.animateTo(
        position,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

      // Small delay to allow scroll to complete, then open modal
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          _markActivityAsRead(fixtureId);
          // _openComradeVotingModal(_fixtures[index]);
        }
      });
    }
  }

  void _stopPulsingAnimation(String fixtureId) {
    final controller = _badgeTimers[fixtureId];
    if (controller != null) {
      controller.dispose(); // Now safe because controller is not null
      _badgeTimers.remove(fixtureId);
    }
  }

  Future<void> _markActivityAsRead(String fixtureId) async {
    // Stop pulsing animation
    _stopPulsingAnimation(fixtureId);

    // Clear unread status in NotificationService
    await NotificationService.markFixtureAsRead(fixtureId);

    // Clear local state - UPDATE THIS
    _safeSetState(() {
      _unreadCounts[fixtureId] =
          0; // Replace: _hasUnreadActivity[fixtureId] = false;
    });
  }

  Future<void> _loadSavedUnreadStatuses() async {
    try {
      final unreadData = await NotificationService.getAllUnreadData();

      for (var entry in unreadData.entries) {
        final fixtureId = entry.key;
        final count = entry.value['count'] ?? 0;

        if (count > 0) {
          _safeSetState(() {
            _unreadCounts[fixtureId] = count;
          });
          _startPulsingAnimation(
            fixtureId,
          ); // 🔥 Start animation for existing unreads
          debugPrint('📊 Loaded unread count $count for fixture $fixtureId');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error loading saved unread statuses: $e');
    }
  }

  void _showWithdrawDialog() {
    _showFundsDialog(isWithdraw: true);
  }

  void _showFundsDialog({
    required bool isWithdraw,
    VoidCallback? onComplete,
  }) {
    final amountController = TextEditingController();
    final phoneController = TextEditingController();
    final kind = isWithdraw ? 'withdraw' : 'topup';
    bool useSavedPhone = true;
    String? savedPhone;
    bool isLoading = true;

    _getSavedPhone(kind).then((phone) {
      savedPhone = phone;
      if (phone != null && phone.isNotEmpty) {
        phoneController.text = phone;
      }
      isLoading = false;
      if (mounted) setState(() {});
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          if (isLoading) {
            Future.delayed(const Duration(milliseconds: 60), () {
              if (context.mounted) setStateDialog(() {});
            });
          }

          final accent = isWithdraw ? FanColors.away : FanColors.primary;

          return AlertDialog(
            backgroundColor: FanColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FanRadius.lg),
            ),
            title: Row(
              children: [
                Icon(
                  isWithdraw ? Icons.account_balance : Icons.add_circle,
                  color: accent,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  isWithdraw ? 'Withdraw Funds' : 'Top Up Balance',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: FanColors.textPrimary,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Balance display
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: FanColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: FanColors.border, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          size: 14,
                          color: FanColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Balance: KES ${_userBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: FanColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Amount field
                  TextField(
                    controller: amountController,
                    autofocus: !isWithdraw,
                    decoration: const InputDecoration(
                      labelText: 'Amount (KES)',
                      hintText: 'Enter amount',
                      prefixIcon: Icon(Icons.monetization_on),
                    ),
                    keyboardType: TextInputType.number,
                    style:
                        TextStyle(fontSize: 12, color: FanColors.textPrimary),
                  ),
                  const SizedBox(height: 10),

                  // Phone field
                  if (isWithdraw)
                    TextField(
                      controller: phoneController,
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Registered Phone Number',
                        hintText: 'Loading...',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: Icon(
                          Icons.check_circle,
                          color: FanColors.primary,
                          size: 16,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: FanColors.textSecondary,
                      ),
                    )
                  else
                    TextField(
                      controller: phoneController,
                      enabled: true,
                      decoration: InputDecoration(
                        labelText: 'M-Pesa Phone Number',
                        hintText: 'e.g., 0712345678',
                        prefixIcon: const Icon(Icons.phone_android),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.edit, size: 16),
                          onPressed: () => phoneController.clear(),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      style: TextStyle(
                        fontSize: 12,
                        color: FanColors.textPrimary,
                      ),
                    ),

                  const SizedBox(height: 6),

                  // Save checkbox — ONLY for top-up
                  if (!isWithdraw)
                    Row(
                      children: [
                        Checkbox(
                          value: useSavedPhone,
                          activeColor: FanColors.primary,
                          onChanged: (val) {
                            setStateDialog(() {
                              useSavedPhone = val ?? true;
                              if (useSavedPhone && savedPhone != null) {
                                phoneController.text = savedPhone!;
                              } else {
                                phoneController.clear();
                              }
                            });
                          },
                        ),
                        Expanded(
                          child: Text(
                            'Save this number for future top-ups',
                            style: TextStyle(
                              fontSize: 10,
                              color: FanColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Info message
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isWithdraw
                              ? Icons.warning_amber_rounded
                              : Icons.info_outline,
                          size: 12,
                          color: accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isWithdraw
                                ? 'Withdrawals must use your registered phone number'
                                : 'Enter any M-Pesa number. You will receive a prompt to enter your PIN.',
                            style: TextStyle(fontSize: 9, color: accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: FanColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amountText = amountController.text.trim();
                  final phone = phoneController.text.trim();

                  if (amountText.isEmpty ||
                      double.tryParse(amountText) == null ||
                      double.parse(amountText) <= 0) {
                    ToastHelper.showWarning('Please enter a valid amount');
                    return;
                  }

                  if (isWithdraw &&
                      (phone.isEmpty || !_isValidPhoneNumber(phone))) {
                    ToastHelper.showWarning(
                        'Please enter a valid phone number');
                    return;
                  }

                  final amount = double.parse(amountText);

                  if (isWithdraw) {
                    if (amount > _userBalance) {
                      ToastHelper.showWarning('Insufficient balance');
                      return;
                    }
                    Navigator.pop(context);
                    final success = await _processWithdrawal(
                      amount: amount,
                      phone: phone,
                    );
                    if (success && mounted) {
                      await _fetchUserBalance(forceRefresh: true);
                      ToastHelper.showSuccess('Withdrawal request submitted!');
                    }
                  } else {
                    Navigator.pop(context);
                    final success = await _initiateSTKPush(
                      amount,
                      phoneNumber: phone,
                      purpose: 'Top up balance',
                    );
                    if (success && mounted) {
                      if (useSavedPhone) await _savePhone(kind, phone);
                      await _fetchUserBalance(forceRefresh: true);
                      ToastHelper.showSuccess('Balance updated successfully!');
                      onComplete?.call();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  minimumSize: const Size(80, 32),
                ),
                child: _isProcessingPayment
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isWithdraw ? 'Withdraw' : 'Pay via M-Pesa',
                        style: const TextStyle(fontSize: 11),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openVotesOnlyModal(Fixture fixture) async {
    // ✅ Same guards as _handleVoteAction / _openChatScreen — without these,
    // the modal opened unconditionally even when logged out or channel-less,
    // letting votes go through with no channel and pledges silently fail
    // with a toast instead of routing the user to fix the actual problem.
    if (!_isUserLoggedIn()) {
      _showLoginModal();
      return;
    }

    if (_userChannels.isEmpty) {
      _showJoinGroupsModal();
      return;
    }

    final bool showFullModal = await _checkVotesButtonVisibility();

    final fixtureId = fixture.matchId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SwipeableVotePledgeModal(
        fixture: fixture,
        userId: widget.userId,
        username: widget.username,
        authToken: widget.authToken,
        isLoggedIn: _isUserLoggedIn(),
        hasUserVoted: _userVotes.containsKey(fixtureId),
        userVoteSelection: _userVotes[fixtureId],
        comradesList: _userComrades,
        showPledgesTab: showFullModal,
        showBetsTab: showFullModal,
        showSubFixturesTab: showFullModal,
        channelId: _localSelectedChannel?.channelId ?? '',
        onVote: (selection) => _processVote(fixture, selection, 0),
        onPledge: (selection, amount) =>
            _processPledge(fixture, selection, amount),
      ),
    );
  }

  // Add to your state
  final Map<String, bool> _visibilityCache = {};
  final Map<String, DateTime> _visibilityCacheTime = {};

// Cached check

  Future<void> _fetchAndCacheChannelFixtures() async {
    final channelId = _localSelectedChannel?.channelId ??
        (_userChannels.isNotEmpty ? _userChannels.first.channelId : null);

    if (channelId == null) return;

    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/channels/$channelId/fixtures'),
        headers: await _buildHeaders(),
      );

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final List<dynamic> fixturesData = data['fixtures'] ?? [];

        for (var fixtureData in fixturesData) {
          final channelData = ChannelFixtureData.fromJson(fixtureData);
          final fixtureId = channelData.fixtureId;

          // Update cache
          _channelFixtureDataMap[fixtureId] = channelData;
          _commentCounts[fixtureId] = channelData.commentCount;
          _voteCounts[fixtureId] = channelData.totalVotes;

          // Update unread counts for current user
          final userUnread = channelData.unreadCounts[widget.userId] ?? 0;
          if (userUnread > 0) {
            _unreadCounts[fixtureId] = userUnread;
            _startPulsingAnimation(fixtureId);
          }
        }

        _safeSetState(() {});
        debugPrint(
            '✅ Cached ${_channelFixtureDataMap.length} channel fixtures');

        // Save to local storage for offline
        await _saveChannelFixturesToCache(_channelFixtureDataMap);
      }
    } catch (e) {
      debugPrint('❌ Error fetching channel fixtures: $e');
      // Load from disk cache if network fails
      await _loadChannelFixturesFromCache();
    }
  }

  static const String _channelFixturesCacheKey = 'channel_fixtures_cache';
  Future<void> _loadChannelDataForFixture(
      String fixtureId, String channelId) async {
    debugPrint(
        '🔄 Loading channel data for fixture $fixtureId with channel $channelId');

    try {
      _safeSetState(() {
        _loadingVote[fixtureId] = true;
      });

      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/channels/$channelId/fixtures/$fixtureId'),
            headers: await _buildHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final channelData = ChannelFixtureData.fromJson(data);

        _safeSetState(() {
          _channelFixtureDataMap[fixtureId] = channelData;

          // Update vote counts from channel data
          _voteCounts[fixtureId] = channelData.totalVotes;

          // Update unread counts
          final userUnread = channelData.unreadCounts[widget.userId] ?? 0;
          if (userUnread > 0) {
            _unreadCounts[fixtureId] = userUnread;
            _startPulsingAnimation(fixtureId);
          } else {
            _unreadCounts[fixtureId] = 0;
            _stopPulsingAnimation(fixtureId);
          }

          _featuredComments.remove(fixtureId);
        });

        // Save to caches
        if (!AppCache.perChannelVoteCounts.containsKey(fixtureId)) {
          AppCache.perChannelVoteCounts[fixtureId] = {};
        }
        AppCache.perChannelVoteCounts[fixtureId]![channelId] =
            channelData.totalVotes;
        await LocalStorageManager.savePerChannelVoteCount(
            fixtureId, channelId, channelData.totalVotes);

        // Fetch comment count separately
        await _fetchCommentCountViaHttp(fixtureId, channelId: channelId);
        await _fetchVoteCountViaHttp(fixtureId, channelId: channelId);

        // Fetch latest comment
        final fixture = _fixtures.firstWhere((f) => f.matchId == fixtureId);
        await _fetchLatestCommentViaHttpWithChannel(
            fixtureId, fixture, channelId);

        _safeSetState(() {});

        debugPrint(
            '✅ Loaded channel data - Votes: ${channelData.totalVotes}, Comments: ${_commentCounts[fixtureId]}');
      }
    } catch (e) {
      debugPrint('❌ Error loading channel data for fixture $fixtureId: $e');
    } finally {
      _safeSetState(() {
        _loadingVote[fixtureId] = false;
      });
    }
  }

  Future<void> _saveChannelFixturesToCache(
      Map<String, ChannelFixtureData> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = <String, dynamic>{};
      for (var entry in data.entries) {
        serialized[entry.key] = {
          'fixtureId': entry.value.fixtureId,
          'channelId': entry.value.channelId,
          'matchName': entry.value.matchName,
          'kickoffTime': entry.value.kickoffTime.toIso8601String(),
          'status': entry.value.status,
          'homeVotes': entry.value.homeVotes,
          'awayVotes': entry.value.awayVotes,
          'drawVotes': entry.value.drawVotes,
          'lastMessage': entry.value.lastMessage,
          'lastMessageAt': entry.value.lastMessageAt?.toIso8601String(),
          'lastSender': entry.value.lastSender,
          'userVote': entry.value.userVote,
          'commentCount': entry.value.commentCount,
          'unreadCounts': entry.value.unreadCounts,
        };
      }
      await prefs.setString(_channelFixturesCacheKey, json.encode(serialized));
      debugPrint('💾 Saved ${data.length} channel fixtures to disk');
    } catch (e) {
      debugPrint('⚠️ Error saving channel fixtures: $e');
    }
  }

  Future<bool> _savePhone(String kind, String phone) async {
    try {
      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/auth/user/${widget.userId}/$kind-phone'),
            headers: await _buildHeaders(),
            body: json.encode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ Error saving $kind phone: $e');
      return false;
    }
  }

  Future<void> _loadChannelFixturesFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_channelFixturesCacheKey);
      if (cached == null) return;

      final Map<String, dynamic> decoded = json.decode(cached);
      for (var entry in decoded.entries) {
        final data = entry.value as Map<String, dynamic>;
        _channelFixtureDataMap[entry.key] = ChannelFixtureData(
          fixtureId: data['fixtureId'],
          channelId: data['channelId'],
          matchName: data['matchName'],
          kickoffTime: DateTime.parse(data['kickoffTime']),
          status: data['status'],
          homeVotes: data['homeVotes'],
          awayVotes: data['awayVotes'],
          drawVotes: data['drawVotes'],
          lastMessage: data['lastMessage'],
          lastMessageAt: data['lastMessageAt'] != null
              ? DateTime.parse(data['lastMessageAt'])
              : null,
          lastSender: data['lastSender'],
          userVote: data['userVote'],
          commentCount: data['commentCount'] ?? 0,
          unreadCounts: Map<String, int>.from(data['unreadCounts'] ?? {}),
        );
      }
      debugPrint(
          '📦 Loaded ${_channelFixtureDataMap.length} channel fixtures from DISK cache');
    } catch (e) {
      debugPrint('⚠️ Error loading channel fixtures from cache: $e');
    }
  }

  Future<void> _loadCommentersFromStorage() async {
    try {
      final savedCommenters = await LocalStorageManager.loadCommenters();
      _fixtureCommenters.addAll(savedCommenters);
      debugPrint('✅ Loaded ${savedCommenters.length} commenters from storage');
    } catch (e) {
      debugPrint('⚠️ Error loading commenters: $e');
    }
  }

  Future<void> _saveCommenter(
    String fixtureId,
    String userId,
    String username,
  ) async {
    if (!_fixtureCommenters.containsKey(fixtureId)) {
      _fixtureCommenters[fixtureId] = {};
    }
    _fixtureCommenters[fixtureId]![userId] = username;
    await LocalStorageManager.saveCommenter(fixtureId, userId, username);
  }

  Future<void> _generateFeaturedCommentForFixture(Fixture fixture) async {
    final fixtureId = fixture.matchId;

    // ✅ FIRST: Check AppCache for latest comment
    final cachedComment = AppCache.getLatestComment(fixtureId);
    if (cachedComment != null) {
      _featuredComments[fixtureId] = FeaturedComment(
        userId: AppCache.getLatestCommentAuthor(fixtureId) ?? 'system',
        username: AppCache.getLatestCommentAuthor(fixtureId) ?? 'Anonymous',
        comment: cachedComment,
        teamSupport: '',
        avatarUrl: '',
        timestamp:
            AppCache.getLatestCommentTimestamp(fixtureId) ?? DateTime.now(),
      );
      debugPrint('✅ Using cached latest comment for $fixtureId');
      return;
    }

    // ✅ SECOND: Check real comments
    final realComments = _fixtureComments[fixtureId] ?? [];
    if (realComments.isNotEmpty) {
      final latestComment = realComments.first;
      _featuredComments[fixtureId] = FeaturedComment(
        userId: latestComment.userId,
        username: latestComment.username,
        comment: latestComment.comment,
        teamSupport: _getTeamSupportForUser(latestComment.selection, fixture),
        avatarUrl:
            await FootballAvatarManager.getAvatarUrl(latestComment.userId),
        timestamp: latestComment.timestamp,
      );
      debugPrint('✅ Using REAL comment for $fixtureId');
      return;
    }

    // ✅ THIRD: Try HTTP fetch
    try {
      final channelId = _localSelectedChannel?.channelId ??
          (_userChannels.isNotEmpty ? _userChannels.first.channelId : null);

      if (channelId != null) {
        final response = await http
            .get(
              Uri.parse(
                  '$API_BASE_URL/channels/$channelId/fixtures/$fixtureId/comments/latest'),
              headers: await _buildHeaders(),
            )
            .timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final latestComment = data['latest_comment'];

          if (latestComment != null) {
            final commentText = latestComment['comment']?.toString() ?? '';
            if (commentText.isNotEmpty) {
              _featuredComments[fixtureId] = FeaturedComment(
                userId: latestComment['user_id']?.toString() ?? 'system',
                username: latestComment['username']?.toString() ?? 'Anonymous',
                comment: commentText,
                teamSupport: _getTeamSupportForUser(
                    latestComment['selection']?.toString(), fixture),
                avatarUrl: '',
                timestamp: DateTime.now(),
              );
              debugPrint('✅ Fetched latest comment from HTTP for $fixtureId');
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ HTTP latest comment fetch failed: $e');
    }

    // ✅ LAST RESORT: ONLY generate mock if NO comments exist and fixture is upcoming
    final isUpcoming = fixture.status == 'upcoming' || fixture.status == 'soon';
    final hasNoComments =
        realComments.isEmpty && _featuredComments[fixtureId] == null;

    if (isUpcoming && hasNoComments) {
      final randomUsername =
          _sampleUsernames[_random.nextInt(_sampleUsernames.length)];
      final randomComment =
          _sampleComments[_random.nextInt(_sampleComments.length)];
      final randomUserId = 'mock_${_random.nextInt(10000)}';

      _featuredComments[fixtureId] = FeaturedComment(
        userId: randomUserId,
        username: randomUsername,
        comment: randomComment,
        teamSupport: '',
        avatarUrl: '',
        timestamp:
            DateTime.now().subtract(Duration(minutes: _random.nextInt(120))),
      );
      debugPrint('🎲 Generated MOCK comment for $fixtureId (no real comments)');
    } else {
      _featuredComments.remove(fixtureId);
      debugPrint('📭 No comment available for $fixtureId');
    }
  }

  Future<void> _refreshFeaturedCommentForFixture(String fixtureId) async {
    final fixture = _fixtures.firstWhere((f) => f.matchId == fixtureId);
    await _generateFeaturedCommentForFixture(fixture);
    _safeSetState(() {});
  }

  String _getTeamSupportForUser(String? selection, Fixture fixture) {
    if (selection == 'home_team') {
      return '🏠 ${fixture.homeTeam}';
    } else if (selection == 'away_team') {
      return '✈️ ${fixture.awayTeam}';
    } else if (selection == 'draw') {
      return '🤝 Draw';
    }
    return '⚽ Football Fan';
  }

  Future<void> _backgroundRefresh() async {
    try {
      debugPrint('🔄 Background refresh started...');

      // Fetch fresh fixtures (cheap, single network call)
      await _fetchFixtures(forceRefresh: false, showNotification: false);

      // Only re-fetch comments if stale (>5 min) — unchanged
      final shouldForceRefresh = DateTime.now()
              .difference(_lastCommentFetchTime ?? DateTime.now())
              .inMinutes >
          5;
      await _fetchAllComments(forceRefresh: shouldForceRefresh);

      if (_isUserLoggedIn()) {
        // Keeps _userVotes in sync per-fixture — cheap, per-fixture checks.
        await _fetchUserVotesFromBackend();

        // ❌ REMOVED: VoteService.fetchAllVotes() + organizeVotesByFixture()
        // This was a deprecated full-collection scan of every vote in the
        // database, re-run on every single app resume. _fixtureVoteData
        // (rivals/supporters) is already kept current elsewhere via
        // _refreshVoteDataForFixture / _refreshVotersDataForFixture, which
        // are scoped to one fixture at a time — no need to rebuild the
        // whole map here.
      }

      await _fetchSubFixtureVotesForAll();

      for (var fixture in _fixtures) {
        await _generateFeaturedCommentForFixture(fixture);
      }

      // ✅ Comrades are expensive (N+1 profile fetch per comrade per
      // fixture) — only refresh them if the 5-minute cache has actually
      // gone stale, not unconditionally on every resume.
      if (_isUserLoggedIn()) {
        final comradesCacheValid =
            await LocalStorageManager.isUserComradesCacheValid();
        if (!comradesCacheValid) {
          await _fetchUserComrades();
          await _fetchAllComradesWithProfiles();
        } else {
          debugPrint('⏭️ Comrades cache still valid, skipping refresh');
        }
      }

      _saveToGlobalCache();
      _lastCommentFetchTime = DateTime.now();
      debugPrint('✅ Background refresh complete');
    } catch (e) {
      debugPrint('❌ Background refresh error: $e');
    }
  }

  // Add this helper method to check for new comments
  Future<void> _checkForNewComments() async {
    for (var fixture in _fixtures) {
      final fixtureId = fixture.matchId;
      final oldComments = _fixtureComments[fixtureId] ?? [];

      // Fetch fresh comments
      final freshComments = await CommentService.fetchCommentsForFixture(
        fixtureId,
        authToken: widget.authToken,
        forceRefresh: true,
      );

      if (freshComments.length > oldComments.length) {
        final newCommentCount = freshComments.length - oldComments.length;

        // Check if any new comments are from comrades
        final newComradeComments = freshComments
            .where(
              (c) =>
                  _userComrades.contains(c.userId) &&
                  !oldComments.any((old) => old.id == c.id),
            )
            .toList();

        if (newComradeComments.isNotEmpty) {
          debugPrint(
            '🔔 New comrade comments detected for $fixtureId: ${newComradeComments.length}',
          );

          _safeSetState(() {
            final currentCount = _unreadCounts[fixtureId] ?? 0;
            _unreadCounts[fixtureId] = currentCount + newComradeComments.length;
          });
          _startPulsingAnimation(fixtureId);

          await NotificationService.markFixtureAsUnread(
            fixtureId,
            'fixture_comment',
            {'fixture_id': fixtureId, 'count': newComradeComments.length},
          );
        }

        // Update comments
        _safeSetState(() {
          _fixtureComments[fixtureId] = freshComments;
        });
      }
    }
  }

  // Add this method to _FixturesPageState

  Future<void> _refreshVotersDataForFixture(String fixtureId) async {
    try {
      debugPrint('🔄 Refreshing voters data for fixture $fixtureId');

      final result = await VoteService.getFixtureVoters(fixtureId);

      if (result['success'] == true) {
        final votersList = result['voters'] ?? [];
        final totalVotes = result['total_votes'] ?? 0;

        // Build comrade voters from the list
        final List<ComradeWithProfile> comrades = [];
        for (var voter in votersList) {
          final uid = voter['userId']?.toString() ?? '';
          final username = voter['userName']?.toString() ?? '';
          final selection = voter['selection']?.toString() ?? '';

          if (uid.isNotEmpty && _userComrades.contains(uid)) {
            comrades.add(
              ComradeWithProfile(
                userId: uid,
                username: username,
                nickname: username,
                clubFan: '',
                countryFan: '',
                selection: selection,
                votedAt:
                    DateTime.tryParse(voter['votedAt'] ?? '') ?? DateTime.now(),
                comment: null,
              ),
            );
          }
        }

        _safeSetState(() {
          _comradeVoters[fixtureId] = comrades;
          _voteCounts[fixtureId] = totalVotes;
        });

        _saveToGlobalCache();
        debugPrint(
            '✅ Refreshed ${comrades.length} comrade voters for fixture $fixtureId');
      }
    } catch (e) {
      debugPrint('❌ Error refreshing voters data: $e');
    }
  }

  void _onAuthStateChanged() {
    if (!_authService.isLoggedIn && mounted) {
      _forceLogout();
    } else if (_authService.isLoggedIn && mounted) {
      debugPrint('🔄 Auth state changed: user logged in');
      _refreshUserData();

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _forceReloadRivalsAndSupporters();
          _fetchUserComrades();
          _fetchAllComradesWithProfiles();
        }
      });
    }
  }

  /// Called when the app is backgrounded. Drops everything that keeps the
  /// process "active" from Android's point of view: the open WebSocket,
  /// and every Timer.periodic that would otherwise keep firing (and keep
  /// the Dart isolate/event loop busy) while nobody can see the screen.
  /// None of this data is useful to a backgrounded app anyway — it'll all
  /// get refreshed on resume via _backgroundRefresh().
  void _pauseBackgroundWork() {
    if (_backgroundWorkPaused) return;
    _backgroundWorkPaused = true;

    debugPrint('⏸️ Pausing background work (app backgrounded)');

    // Stop live-commentary and comment polling — these were firing every
    // 6-8s per live fixture, which is the single biggest source of
    // background CPU/network wakeups on this page.
    _commentaryPollTimer?.cancel();
    _commentaryPollTimer = null;
    _stopCommentPolling();

    // Stop the 3-minute foreground refresh loop entirely rather than
    // leaving it ticking-and-no-op'ing every 3 minutes.
    _threeMinRefreshTimer?.cancel();
    _threeMinRefreshTimer = null;

    // Drop the socket. An open WebSocket doesn't protect a plain Flutter
    // app from being killed (no foreground service backs it), so keeping
    // it alive while backgrounded only costs battery and makes OEM
    // battery managers more likely to kill the process sooner.
    final ws = WebSocketService();
    if (ws.isConnected) {
      ws.disconnect();
      _wsConnected = false;
    }

    // Long-interval cache polling is still fine to leave running — it's
    // already lightweight (30 min in background) and cheap to keep.
    _restartPolling(isBackground: true);
  }

  /// Called on resume. Reconnects and restarts everything _pauseBackgroundWork
  /// tore down, then does one refresh pass to catch up on anything missed.
  void _resumeBackgroundWork() {
    if (!_backgroundWorkPaused) return;
    _backgroundWorkPaused = false;

    debugPrint('▶️ Resuming background work (app foregrounded)');

    _startBackgroundRefreshTimer();
    _restartPolling();

    if (_isUserLoggedIn() && _fixtures.isNotEmpty) {
      _connectWebSocket();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLiveCommentary(); // restarts commentary polling + comment polling
    });
  }

  void _handlePause() {
  debugPrint('⏸️ App paused - cleaning up (after ${_teardownDelay.inSeconds}s debounce)');

  _isBackgroundPaused = true;
  MemoryManager().onBackground();

  // Stop all timers
  _backgroundRefreshTimer?.cancel();
  _backgroundRefreshTimer = null;

  // Disconnect WebSocket
  final ws = WebSocketService();
  if (ws.isConnected) {
    ws.disconnect();
    _wsConnected = false;
  }

  // Trim AppCache memory — single owner of this call now.
  AppCache.reduceMemoryFootprint();

  // Clear heavy UI state
  _clearHeavyState();
}

  

  void _handleDetach() {
    // App is being killed - save critical data
    debugPrint('💀 App detached - saving state');

    _saveCriticalState();
    AppCache.reduceMemoryFootprint();
    AppCache.saveToDisk();
  }

  void _clearHeavyState() {
    // Clear large lists but keep minimal display data
    _fixtureComments.clear();
    _comradeVoters.clear();
    _liveEvents.clear();

    // Keep only the active fixture's comments
    final activeFixtureId = AppCache.getActiveFixtureId();
    if (activeFixtureId != null) {
      final activeComments = _fixtureComments[activeFixtureId];
      _fixtureComments.clear();
      if (activeComments != null) {
        _fixtureComments[activeFixtureId] = activeComments;
      }
    }

    // Trim comment controllers
    for (var controller in _commentControllers.values) {
      controller.dispose();
    }
    _commentControllers.clear();
  }

  void _saveCriticalState() {
    // Save votes
    for (var entry in _userVotes.entries) {
      if (entry.value != null) {
        AppCache.setUserVote(entry.key, entry.value!);
      }
    }

    // Save comment counts
    for (var entry in _commentCounts.entries) {
      AppCache.saveCommentCount(entry.key, entry.value);
    }
  }

  Future<void> _refreshDataWithTimeout() async {
    try {
      // Set a timeout to prevent hanging
      await Future.any([
        _backgroundRefresh(),
        Future.delayed(const Duration(seconds: 10)),
      ]);
    } catch (e) {
      debugPrint('⏱ Refresh timed out: $e');
    }
  }

  // Add this method to start periodic background refresh
  void _startBackgroundRefreshTimer() {
    _backgroundRefreshTimer?.cancel();
    _backgroundRefreshTimer = Timer.periodic(
      const Duration(minutes: 3),
      (_) {
        if (mounted && !_isBackgroundPaused) {
          _refreshDataWithTimeout();
        }
      },
    );
  }

  void _forceLogout() {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    debugPrint('🚪 FixturesPage: Force logout started (once)');

    _safeSetState(() {
      _userVotes.clear();
      _userLikes.clear();
      _fixtureVoteData.clear();
      _subFixtureVoteData.clear();
      _gameMetadata.clear();
      _fixtureComments.clear();
      _fixtureCommenters.clear();
      _featuredComments.clear();
      _loadingVote.clear();
      _loadingLike.clear();
      _loadingComment.clear();
      _loadingComments.clear();
      _loadingSubFixtureVote.clear();
      _showingRivals.clear();
      _showingSupporters.clear();
      _showingAllComments.clear();
      _voteStats.clear();
      _likeStats.clear();
      _commentCounts.clear();
      _loadingVotes = false;
      _comradeVoters.clear(); // NEW
      _fixtureNotifications.clear(); // NEW
      _userComrades.clear(); // NEW

      for (var controller in _commentControllers.values) {
        controller.dispose();
      }
      _commentControllers.clear();
    });

    _cache.clearCache();
    _saveToGlobalCache();

    widget.onLogout?.call();

    _fetchFixtures(forceRefresh: true, showNotification: false);

    Future.delayed(const Duration(seconds: 1), () {
      _isLoggingOut = false;
    });
  }

  Future<void> _refreshUserData() async {
    debugPrint('🔄 Refreshing user data...');

    if (mounted) _safeSetState(() => _refreshing = true);

    try {
      // ✅ REMOVED: _userVotes.clear();
      // ✅ REMOVED: _userLikes.clear();
      // ✅ REMOVED: _fixtureVoteData.clear();
      // ✅ REMOVED: _gameMetadata.clear();
      // ✅ REMOVED: _fixtureComments.clear();
      // ✅ REMOVED: _subFixtureVoteData.clear();

      // 2. Load user votes FIRST (critical)
      await _fetchUserVotesFromBackend();
      debugPrint('✅ User votes loaded: ${_userVotes.length}');

      // 3. Load cached comments from disk while we fetch fresh ones
      for (var fixture in _fixtures) {
        final cachedComments =
            await LocalStorageManager.loadCommentsForFixture(fixture.matchId);
        if (cachedComments.isNotEmpty) {
          _fixtureComments[fixture.matchId] = cachedComments;
          _commentCounts[fixture.matchId] = cachedComments.length;
        }
      }

      // 4. Now fetch all votes and organize with user votes
      final allVotes = await VoteService.fetchAllVotes();
      final organizedData = VoteService.organizeVotesByFixture(
        allVotes,
        widget.userId,
      );

      _safeSetState(() => _fixtureVoteData = organizedData);
      debugPrint(
          '✅ Built fixture vote data for ${organizedData.length} fixtures');

      // 5. Update vote counts
      for (var entry in organizedData.entries) {
        final supporterCount = entry.value.supporters.length;
        final rivalCount = entry.value.rivals.length;
        _voteCounts[entry.key] = supporterCount + rivalCount;
      }

      // 6. Run remaining fetches in parallel
      await Future.wait([
        _fetchUserLikesFromBackend(),
        _fetchAllComments(forceRefresh: true),
        _fetchSubFixtureVotesForAll(),
        _fetchUserComrades(),
        _fetchAllComradesWithProfiles(),
      ]);

      // 7. Regenerate featured comments
      for (var fixture in _fixtures) {
        await _generateFeaturedCommentForFixture(fixture);
      }

      // 8. Load unread badge counts
      await _loadSavedUnreadStatuses();

      _saveToGlobalCache();

      // 9. Force UI update
      if (mounted) _safeSetState(() {});

      debugPrint(
          '✅ User data refresh complete - ${_userVotes.length} votes loaded');
    } catch (e) {
      debugPrint('❌ Error refreshing user data: $e');
      ToastHelper.showError('Failed to load your data');
    } finally {
      if (mounted) _safeSetState(() => _refreshing = false);
    }
  }

  // Add this member variable at the top of _FixturesPageState (around line 200)

  // ========== INITSTATE ==========

  // ============================================================
// COMPLETE FixturesPage.initState
// ============================================================

  void _showJoinGroupsModal() {
    if (!_isUserLoggedIn()) {
      _showLoginModal();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => JoinGroupsModal(
        userId: widget.userId,
        username: widget.username,
        authToken: widget.authToken,
        userChannels: _userChannels,
        pendingRequests: _pendingJoinRequests,
        onClose: () => Navigator.pop(context),
        onChannelJoined: (channelId) async {
          // Add to pending
          _addPendingJoinRequest(channelId);

          // Refresh channels
          await _loadUserChannels();
          _safeSetState(() {});
          Navigator.pop(context);
          ToastHelper.showSuccess('Join request sent to admin!');
        },
      ),
    );
  }

// Add this new method to fetch fresh data in background
  Future<void> _fetchFreshDataInBackground() async {
    debugPrint('🔄 Fetching fresh data in background (non-blocking)...');

    try {
      // STEP 1: Load channels FIRST
      await _loadUserChannels();

      // STEP 2: Run all network calls in parallel
      await Future.wait([
        _fetchFixtures(forceRefresh: true, showNotification: false),
        _fetchAndCacheChannelFixtures(),
        _fetchUserVotesFromBackend(),
        _fetchUserLikesFromBackend(),
        _fetchSubFixtureVotesForAll(),
        _fetchUserComrades(),
        _fetchAllComradesWithProfiles(),
        _loadUnreadCountsFromBackend(),
        _fetchAllCommentCounts(),
        _fetchAllLatestComments(), // This now fetches real comments, then generates mocks for those without
      ]);

      // Update memory cache (AppCache)
      AppCache.fixtures = List.from(_fixtures);
      AppCache.userVotes = Map.from(_userVotes);
      AppCache.userComrades = Set.from(_userComrades);
      AppCache.comradeVoters = Map.from(_comradeVoters);
      AppCache.channels = List.from(_userChannels);
      AppCache.channelFixtures = Map.from(_channelFixtureDataMap);

      // Save to disk cache (persistent)
      await AppCache.saveFixtures(_fixtures);
      await AppCache.saveChannelFixtures(_channelFixtureDataMap);
      await AppCache.saveChannels(_userChannels);

      // Save votes to disk
      for (var entry in _userVotes.entries) {
        final voteValue = entry.value;
        if (voteValue != null && voteValue.isNotEmpty) {
          await LocalStorageManager.saveVote(
              widget.userId, entry.key, voteValue);
        }
      }

      // Save comrades to disk
      await LocalStorageManager.saveUserComrades(_userComrades);
      await LocalStorageManager.saveComradeVoters(_comradeVoters);

      // Update UI only if there are changes
      if (mounted) {
        _safeSetState(() {});
      }

      debugPrint('✅ Background refresh complete - both caches updated');
    } catch (e) {
      debugPrint('❌ Background refresh error: $e');
    }
  }

  Widget _buildLiveEventsWidget(String fixtureId) {
    final events = _liveEvents[fixtureId] ?? [];

    if (events.isEmpty) return const SizedBox.shrink();

    // Only show when match is live
    final fixture = _fixtures.firstWhere(
      (f) => f.matchId == fixtureId,
      orElse: () => null as Fixture,
    );

    if (fixture.isLive != true) {
      return const SizedBox.shrink();
    }

    // Take only latest 3 events
    final latestEvents = events.take(3).toList();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: latestEvents.map((event) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: event.getColor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: event.getColor().withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${event.minuteDisplay}'",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: event.getColor(),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  event.getDisplayText(),
                  style: TextStyle(
                    fontSize: 11,
                    color: event.getColor(),
                  ),
                ),
                if (event.eventType == 'goal') ...[
                  const SizedBox(width: 6),
                  Text(
                    '${event.homeScore}-${event.awayScore}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: event.getColor(),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(), // ← CRITICAL: .toList() converts Iterable to List
      ),
    );
  }

  Future<void> _fetchAllCommentCounts() async {
    if (_fixtures.isEmpty) return;

    final channelId = _localSelectedChannel?.channelId ??
        (_userChannels.isNotEmpty ? _userChannels.first.channelId : null);

    if (channelId == null) return;

    try {
      final List<Future> requests = [];
      for (var fixture in _fixtures) {
        requests.add(_fetchCommentCountViaHttp(fixture.matchId));
        requests.add(_fetchVoteCountViaHttp(fixture.matchId)); // ADD THIS
      }
      await Future.wait(requests);
      debugPrint('✅ Fetched all counts for all fixtures');
    } catch (e) {
      debugPrint('❌ Error fetching counts: $e');
    }
  }

  void _loadFromDiskCacheInstantly() async {
    try {
      // ✅ FIRST: Check if AppCache has fixtures
      if (AppCache.fixtures.isNotEmpty) {
        final filteredFixtures = AppCache.fixtures
            .where((f) => f.status != 'completed' && f.status != 'finished')
            .toList();

        if (filteredFixtures.isNotEmpty) {
          _safeSetState(() {
            _fixtures = filteredFixtures;
            _loading = false;
            _error = '';

            // ============================================================
            // 1. LOAD USER VOTES FROM APPCACHE
            // ============================================================
            _userVotes.clear();
            _userVotes.addAll(AppCache.userVotes);

            // ============================================================
            // 2. LOAD VOTE COUNTS FROM APPCACHE
            // ============================================================
            for (var fixture in filteredFixtures) {
              final voteCount = AppCache.getVoteCount(fixture.matchId);
              if (voteCount != null) {
                _voteCounts[fixture.matchId] = voteCount;
              }
            }

            // ============================================================
            // 3. LOAD COMMENT COUNTS - CHECK PENDING COUNTS FIRST
            // ============================================================
            for (var entry in AppCache.channelFixtures.entries) {
              final fixtureId = entry.key;
              final cachedCount = entry.value.commentCount;

              // ✅ USE PENDING COUNT IF AVAILABLE (from chat return)
              if (_pendingCommentCounts.containsKey(fixtureId)) {
                _commentCounts[fixtureId] = _pendingCommentCounts[fixtureId]!;
                debugPrint(
                    '📊 Using pending count ${_pendingCommentCounts[fixtureId]} for $fixtureId');
              }
              // ✅ USE CACHED COUNT IF HIGHER THAN CURRENT
              else if (cachedCount > (_commentCounts[fixtureId] ?? 0)) {
                _commentCounts[fixtureId] = cachedCount;
              }
              // ✅ OTHERWISE KEEP EXISTING COUNT

              // Load unread counts
              _unreadCounts[fixtureId] =
                  entry.value.unreadCounts[widget.userId] ?? 0;
            }

            // ============================================================
            // 4. LOAD LATEST COMMENTS FROM APPCACHE
            // ============================================================
            for (var fixture in filteredFixtures) {
              final fixtureId = fixture.matchId;
              final latestComment = AppCache.getLatestComment(fixtureId);

              if (latestComment != null) {
                _featuredComments[fixtureId] = FeaturedComment(
                  userId:
                      AppCache.getLatestCommentAuthor(fixtureId) ?? 'system',
                  username:
                      AppCache.getLatestCommentAuthor(fixtureId) ?? 'Anonymous',
                  comment: latestComment,
                  teamSupport: '',
                  avatarUrl: '',
                  timestamp: AppCache.getLatestCommentTimestamp(fixtureId) ??
                      DateTime.now(),
                );
              }

              // ============================================================
              // 5. LOAD LIKE COUNTS FROM APPCACHE
              // ============================================================
              final likeCount = AppCache.getLikeCount(fixtureId);
              if (likeCount != null) {
                _likeStats[fixtureId] = LikeStatsResponse(
                  fixtureId: fixtureId,
                  totalLikes: likeCount,
                  userHasLiked: _userLikes[fixtureId] ?? false,
                );
              }

              // ============================================================
              // 6. LOAD PLEDGE COUNTS FROM APPCACHE
              // ============================================================
              final pledgeCount = AppCache.getPledgeCount(fixtureId);
              if (pledgeCount != null) {
                _pledgeCounts[fixtureId] = pledgeCount;
              }

              // ============================================================
              // 7. LOAD USER LIKES FROM APPCACHE
              // ============================================================
              final userLike = AppCache.getUserLike(fixtureId);
              if (userLike != null) {
                _userLikes[fixtureId] = userLike;
              }

              // ============================================================
              // 8. LOAD LIVE EVENTS FROM APPCACHE
              // ============================================================
              final liveEvents = AppCache.getLiveEvents(fixtureId);
              if (liveEvents != null && liveEvents.isNotEmpty) {
                _liveEvents[fixtureId] = liveEvents
                    .map((event) => LiveEvent.fromJson(event))
                    .toList();
              }

              // ============================================================
              // 9. LOAD VOTERS FROM APPCACHE
              // ============================================================
              final voters = AppCache.getVotersList(fixtureId);
              if (voters != null && voters.isNotEmpty) {
                // Store voters if needed
              }
            }

            // ============================================================
            // 10. LOAD CHANNEL FIXTURES FROM APPCACHE
            // ============================================================
            _channelFixtureDataMap.clear();
            _channelFixtureDataMap.addAll(AppCache.channelFixtures);

            // ============================================================
            // 11. LOAD PER-CHANNEL VOTE COUNTS
            // ============================================================
            for (var entry in AppCache.perChannelVoteCounts.entries) {
              final counts = entry.value.values.toList();
              if (counts.isNotEmpty) {
                _voteCounts[entry.key] = counts.reduce((a, b) => a + b);
              }
            }

            // ============================================================
            // 12. LOAD UNREAD COUNTS FROM APPCACHE
            // ============================================================
            for (var entry in AppCache.channelFixtures.entries) {
              final userUnread = entry.value.unreadCounts[widget.userId] ?? 0;
              if (userUnread > 0) {
                _unreadCounts[entry.key] = userUnread;
                _startPulsingAnimation(entry.key);
              }
            }
          });

          debugPrint('⚡ Loaded ${_fixtures.length} fixtures from AppCache');
          debugPrint('📊 Comment counts loaded: ${_commentCounts.length}');
          debugPrint('📊 Pending counts: ${_pendingCommentCounts.length}');

          // ============================================================
          // 13. INITIALIZE UI CONTROLLERS FOR EACH FIXTURE
          // ============================================================
          for (var fixture in filteredFixtures) {
            final fixtureId = fixture.matchId;
            _commentControllers.putIfAbsent(
              fixtureId,
              () => TextEditingController(),
            );
            _showingRivals.putIfAbsent(fixtureId, () => false);
            _showingSupporters.putIfAbsent(fixtureId, () => false);
            _showingAllComments.putIfAbsent(fixtureId, () => false);
            _subFixturesExpanded.putIfAbsent(fixtureId, () => false);
          }

          // ============================================================
          // 14. ENSURE MOCK SUB-FIXTURES
          // ============================================================
          _ensureMockSubFixtures();

          // ============================================================
          // 15. GENERATE FEATURED COMMENTS
          // ============================================================
          for (var fixture in filteredFixtures) {
            await _generateFeaturedCommentForFixture(fixture);
          }

          // ============================================================
          // 16. SAVE TO GLOBAL CACHE
          // ============================================================
          _saveToGlobalCache();

          // ============================================================
          // 17. CONNECT WEBSOCKET IF USER IS LOGGED IN
          // ============================================================
          if (_isUserLoggedIn()) {
            _connectWebSocket();
          }

          // ============================================================
          // 18. REFRESH IN BACKGROUND
          // ============================================================
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              debugPrint('🔄 Background refresh after cache load...');
              _fetchFixtures(forceRefresh: true, showNotification: false);
            }
          });

          return;
        }
      }

      // ============================================================
      // FALLBACK: Load from disk cache if AppCache is empty
      // ============================================================
      final results = await Future.wait([
        LocalStorageManager.loadFixturesFromCache().catchError((e) {
          debugPrint('⚠️ Failed to load fixtures from cache: $e');
          return <Fixture>[];
        }),
        LocalStorageManager.loadVotesForUser(widget.userId).catchError((e) {
          debugPrint('⚠️ Failed to load votes from cache: $e');
          return <String, String>{};
        }),
        LocalStorageManager.loadLikesForUser(widget.userId).catchError((e) {
          debugPrint('⚠️ Failed to load likes from cache: $e');
          return <String>{};
        }),
        LocalStorageManager.loadUserComrades().catchError((e) {
          debugPrint('⚠️ Failed to load comrades from cache: $e');
          return <String>{};
        }),
        LocalStorageManager.loadComradeVoters().catchError((e) {
          debugPrint('⚠️ Failed to load comrade voters from cache: $e');
          return <String, List<ComradeWithProfile>>{};
        }),
        LocalStorageManager.getAllCommentCounts().catchError((e) {
          debugPrint('⚠️ Failed to load comment counts from cache: $e');
          return <String, int>{};
        }),
        LocalStorageManager.loadFixtureNotifications().catchError((e) {
          debugPrint('⚠️ Failed to load notifications from cache: $e');
          return <String, FixtureNotificationState>{};
        }),
        _loadChannelFixturesFromCache().catchError((e) {
          debugPrint('⚠️ Failed to load channel fixtures from cache: $e');
          return;
        }),
      ]);

      final cachedFixtures = results[0] as List<Fixture>?;
      final votes = results[1] as Map<String, String>;
      final likes = results[2] as Set<String>;
      final comrades = results[3] as Set<String>;
      final comradeVoters = results[4] as Map<String, List<ComradeWithProfile>>;
      final commentCounts = results[5] as Map<String, int>;
      final notifications = results[6] as Map<String, FixtureNotificationState>;

      if (cachedFixtures != null && cachedFixtures.isNotEmpty) {
        final filteredFixtures = cachedFixtures
            .where((f) => f.status != 'completed' && f.status != 'finished')
            .toList();

        if (filteredFixtures.isNotEmpty) {
          filteredFixtures.sort((a, b) =>
              '${a.dateIso}_${a.time}'.compareTo('${b.dateIso}_${b.time}'));

          _safeSetState(() {
            _fixtures = filteredFixtures;
            _loading = false;
            _error = '';

            _userVotes.clear();
            _userVotes.addAll(votes);

            _userLikes.clear();
            for (var id in likes) {
              _userLikes[id] = true;
            }

            _userComrades.clear();
            _userComrades.addAll(comrades);

            _comradeVoters.clear();
            _comradeVoters.addAll(comradeVoters);

            _fixtureNotifications.clear();
            _fixtureNotifications.addAll(notifications);

            // Load vote counts from AppCache
            for (var entry in AppCache.perChannelVoteCounts.entries) {
              final counts = entry.value.values.toList();
              if (counts.isNotEmpty) {
                _voteCounts[entry.key] = counts.reduce((a, b) => a + b);
              }
            }

            // Load comment counts - CHECK PENDING COUNTS FIRST
            for (var entry in commentCounts.entries) {
              final fixtureId = entry.key;
              final cachedCount = entry.value;

              if (_pendingCommentCounts.containsKey(fixtureId)) {
                _commentCounts[fixtureId] = _pendingCommentCounts[fixtureId]!;
              } else if (cachedCount > (_commentCounts[fixtureId] ?? 0)) {
                _commentCounts[fixtureId] = cachedCount;
              }
            }

            // Load channel fixture data
            for (var entry in _channelFixtureDataMap.entries) {
              if (!_voteCounts.containsKey(entry.key)) {
                _voteCounts[entry.key] = entry.value.totalVotes;
              }
              if (!_unreadCounts.containsKey(entry.key)) {
                final userUnread = entry.value.unreadCounts[widget.userId] ?? 0;
                if (userUnread > 0) {
                  _unreadCounts[entry.key] = userUnread;
                  _startPulsingAnimation(entry.key);
                }
              }
            }
          });

          AppCache.fixtures = List.from(filteredFixtures);
          AppCache.userVotes = Map.from(votes);
          AppCache.userComrades = Set.from(comrades);
          AppCache.comradeVoters = Map.from(comradeVoters);

          for (var fixture in filteredFixtures) {
            final fixtureId = fixture.matchId;
            _commentControllers.putIfAbsent(
              fixtureId,
              () => TextEditingController(),
            );
            _showingRivals.putIfAbsent(fixtureId, () => false);
            _showingSupporters.putIfAbsent(fixtureId, () => false);
            _showingAllComments.putIfAbsent(fixtureId, () => false);
            _subFixturesExpanded.putIfAbsent(fixtureId, () => false);

            if (!_fixtureComments.containsKey(fixtureId)) {
              final cachedComments =
                  await LocalStorageManager.loadCommentsForFixture(fixtureId);
              if (cachedComments.isNotEmpty && mounted) {
                _safeSetState(() {
                  _fixtureComments[fixtureId] = cachedComments;
                });
              }
            }

            if (!_featuredComments.containsKey(fixtureId) &&
                !_lastWebSocketLatestCommentUpdate.containsKey(fixtureId)) {
              await _generateFeaturedCommentForFixture(fixture);
            }
          }

          _ensureMockSubFixtures();
          _saveToGlobalCache();

          debugPrint(
              '⚡ DISK CACHE: ${filteredFixtures.length} fixtures loaded instantly');
          debugPrint('📊 Comment counts loaded: ${_commentCounts.length}');

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              debugPrint('🔄 Background refresh after disk cache load...');
              _fetchFixtures(forceRefresh: true, showNotification: false);
            }
          });

          if (_isUserLoggedIn()) {
            _connectWebSocket();
          }

          return;
        }
      }

      debugPrint('🔄 No active fixtures in cache, fetching from network...');
      await _fetchFixtures(forceRefresh: true, showNotification: false);
    } catch (e) {
      debugPrint('❌ _loadFromDiskCacheInstantly error: $e');
      await _fetchFixtures(forceRefresh: true, showNotification: false);
    }
  }

  void _generateMockCommentForFixture(Fixture fixture) {
    final fixtureId = fixture.matchId;

    // ONLY generate mock if no real comment exists
    if (_featuredComments.containsKey(fixtureId)) {
      return; // Already has real comment
    }

    final randomUsername =
        _sampleUsernames[_random.nextInt(_sampleUsernames.length)];
    final randomComment =
        _sampleComments[_random.nextInt(_sampleComments.length)];
    final List<String> teamOptions = [
      '🏠 ${fixture.homeTeam}',
      '✈️ ${fixture.awayTeam}',
      '🤝 Draw',
      '⚽ Football Fan',
    ];
    final randomTeamSupport = teamOptions[_random.nextInt(teamOptions.length)];
    final randomUserId = 'mock_${_random.nextInt(10000)}';

    _featuredComments[fixtureId] = FeaturedComment(
      userId: randomUserId,
      username: randomUsername,
      comment: randomComment,
      teamSupport: randomTeamSupport,
      avatarUrl: '',
      timestamp:
          DateTime.now().subtract(Duration(minutes: _random.nextInt(120))),
    );
    debugPrint(
        '🎲 Generated MOCK comment for fixture ${fixture.homeTeam} vs ${fixture.awayTeam} (NO real comments exist)');
  }

  /// Builds the minutes played display with "Half Time" when applicable
  /// Builds the minutes played display with "Half Time" when applicable
  /// Builds the minutes played display using timeElapsed
  /// Builds the minutes played display using timeElapsed only
  /// Builds the minutes played display using timeElapsed only
  /// Builds the minutes played display with "Half Time" when applicable
  Widget _buildMinutesDisplay(Fixture fixture) {
    // ✅ USE timeElapsed
    final timeElapsed = fixture.timeElapsed ?? 0;

    // If no time elapsed and not live, don't show anything
    if (timeElapsed <= 0 &&
        fixture.status != 'live' &&
        fixture.status != 'half_time') {
      return const SizedBox.shrink();
    }

    final isHalfTime = fixture.status == 'half_time' ||
        (timeElapsed >= 44 && timeElapsed <= 46);
    final isFullTime = fixture.status == 'full_time' ||
        fixture.status == 'completed' ||
        timeElapsed >= 90;

    // Calculate minutes and seconds
    final minutes = timeElapsed.floor();
    final seconds = ((timeElapsed % 1) * 60).round();

    String displayText;
    Color displayColor;
    FontWeight fontWeight = FontWeight.w500;

    if (isHalfTime) {
      displayText = 'HT';
      displayColor = Colors.orange;
      fontWeight = FontWeight.w600;
    } else if (isFullTime) {
      displayText = 'FT';
      displayColor = Colors.red;
      fontWeight = FontWeight.w600;
    } else if (timeElapsed > 0) {
      if (seconds > 0) {
        displayText = "${minutes}'${seconds.toString().padLeft(2, '0')}";
      } else {
        displayText = "${minutes}'";
      }
      displayColor = FanColors.textSecondary;
    } else {
      // Live but no time yet
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: FanColors.live.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'live',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: FanColors.live,
          ),
        ),
      );
    }

    // Animate for Half Time
    if (isHalfTime) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 1.05),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                displayText,
                style: TextStyle(
                  fontSize: 9,
                  color: displayColor,
                  fontWeight: fontWeight,
                ),
              ),
            ),
          );
        },
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: FanColors.surfaceSunken,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 9,
          color: displayColor,
          fontWeight: fontWeight,
        ),
      ),
    );
  }

// Helper to load all cached comments quickly
  Future<Map<String, List<FixtureComment>>> _loadAllCachedComments(
      List<Fixture> fixtures) async {
    final Map<String, List<FixtureComment>> allComments = {};
    final prefs = await SharedPreferences.getInstance();

    for (var fixture in fixtures) {
      final cached =
          await LocalStorageManager.loadCommentsForFixture(fixture.matchId);
      if (cached.isNotEmpty) {
        allComments[fixture.matchId] = cached;

        // ✅ Also load saved comment count from disk
        final savedCount =
            await LocalStorageManager.getCommentCount(fixture.matchId);
        if (savedCount != null) {
          _commentCounts[fixture.matchId] = savedCount;
        } else {
          _commentCounts[fixture.matchId] = cached.length;
        }
      } else {
        // ✅ Even if no comments, try to load saved count
        final savedCount =
            await LocalStorageManager.getCommentCount(fixture.matchId);
        if (savedCount != null) {
          _commentCounts[fixture.matchId] = savedCount;
        }
      }
    }
    return allComments;
  }

  /// Fetches latest comment and comment count for all fixtures via HTTP
  /// Called on app load and on refresh

  /// Fetch ONLY latest comment via HTTP
  ///
  ///
  /// Fetches latest comment and comment count for all fixtures via HTTP
  /// Called on app load and on refresh

  /// Fetch ONLY comment count via HTTP

  void _requestLatestCommentViaWebSocket(String fixtureId) {
  final ws = WebSocketService();
  if (ws.isConnected) {
    final channelId = _resolveChannelIdFor(fixtureId);
    if (channelId == null) return;
    ws.send('get.latest.comment', {
      'fixtureId': fixtureId,
      'channelId': channelId,
    });
    debugPrint('📤 Requested latest comment for fixture: $fixtureId (channel: $channelId)');
  }
}
// ✅ Add this new method

  /// Builds the appropriate action button based on match status:
  /// - Before match: Group/Comrades button that shows leaderboard
  /// - Live match: Watch button that opens match details
  /// Builds the appropriate action button based on match status:
  /// - Before match: Group/People ICON (opens leaderboard)
  /// - Live match: Watch ICON (opens match details)
  /// - Finished match: Reviews ICON (opens match details)
  /// Builds the appropriate action button based on match status:
  /// - Before match: Group/People ICON (opens leaderboard)
  /// - Live match: Watch ICON (opens match details)
  /// - Finished match: Reviews ICON (opens match details)
  ///
  ///
  ///
  // ═══════════════════════════════════════════════════════════════════════
// BEAUTIFIED MATCH CARD — "Sports + Chat App" redesign for FanFunzy
// ═══════════════════════════════════════════════════════════════════════
//
// HOW TO USE:
// 1. Replace your existing `_buildMatchCard(...)` method inside
//    `FixturesPageState` (in fixture_page.dart) with the version below.
// 2. Add the small helper widgets at the bottom of this file
//    (`_teamAvatar`, `_vsBadge`, `_footerPill`, `_liveDot`,
//    `_scorePill`) as private methods on `FixturesPageState` too —
//    just paste them alongside `_buildMatchCard`.
// 3. Nothing else changes — all your existing state, services, and
//    callbacks (_openChatScreen, _toggleLike, _openVotesOnlyModal,
//    _buildCommentInput, _buildPledgersPreview, etc.) are reused as-is.
//
// WHAT CHANGED VISUALLY:
//  • Real "card" feel: soft elevated surface, rounded 18px corners,
//    colored left accent strip (red = live, amber = soon, mint = voted).
//  • Header redesigned like a match-center header: league crest in a
//    ring, bold league name, animated LIVE pulse chip, pill-shaped
//    kickoff/date chip on the right.
//  • Team row now looks like a scoreboard: circular team initials
//    "avatars", a floating VS/score badge in the center, small
//    league-style team name labels underneath.
//  • Latest comment rendered as a genuine chat bubble (WhatsApp/iMessage
//    style) with avatar, name + timestamp header row, and a soft
//    mint-tinted bubble with tail — instead of plain text.
//  • Footer restyled as a chat-app action bar: pill-shaped icon buttons
//    with soft backgrounds, heart-fill animation on like, a red
//    notification-style badge for unread comments, and a rounded
//    channel-switcher chip on the right edge.
//  • Comment composer kept but wrapped in the same bubble shape so it
//    visually continues the "chat thread" feel.
//
// ═══════════════════════════════════════════════════════════════════════

// ─── PASTE THIS METHOD IN PLACE OF YOUR EXISTING _buildMatchCard ────────

  /// Inline chat-line rendering of the latest comment/commentary — avatar,
  /// name + timestamp header, then plain text that fades directly into the
  /// card's own background (no bubble/chip behind it).
  Widget _chatBubblePreview({
    required FeaturedComment? latestComment,
    required String fixtureId,
    required int maxLines,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipOval(
          child: Image.network(
            _getUserAvatarUrl(
              latestComment?.userId ?? fixtureId,
              latestComment?.username ?? 'fan',
            ),
            width: 30,
            height: 30,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: FanColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  latestComment != null && latestComment.username.isNotEmpty
                      ? latestComment.username[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: FanColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 3),
                child: Row(
                  children: [
                    Text(
                      latestComment?.username ?? 'Fan zone',
                      style: FanTypography.tag.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: FanColors.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (latestComment != null) ...[
                      const SizedBox(width: 5),
                      Text(
                        DateHelper.formatTimeAgo(latestComment.timestamp),
                        style: FanTypography.tag.copyWith(
                          fontSize: 8,
                          color: FanColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // No background/bubble shape here on purpose — the comment
              // text should read as part of the card itself, not a chip
              // floating on top of it.
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  latestComment?.comment ?? 'Say something about this match 💬',
                  style: FanTypography.body.copyWith(
                    color: latestComment != null
                        ? FanColors.textPrimary
                        : FanColors.textTertiary,
                    fontSize: 12,
                    height: 1.35,
                    fontStyle: latestComment == null
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                  maxLines: latestComment != null ? maxLines : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Small rounded footer icon+count pill (votes / likes / comments) —
  /// gives the action bar a chat-app toolbar feel rather than bare icons.

// ═══════════════════════════════════════════════════════════════════════════
// _liveBadge METHOD - Make sure this exists
// ═══════════════════════════════════════════════════════════════════════════
  Widget _liveBadge(Fixture fixture) {
    // ✅ USE timeElapsed (same as HistoryPage)
    final timeElapsed = fixture.timeElapsed ?? 0;

    // ✅ SAME DETECTION LOGIC AS HISTORY PAGE
    final isHalfTime = fixture.status == 'half_time' ||
        (timeElapsed >= 44 && timeElapsed <= 46);
    final isFullTime = fixture.status == 'full_time' ||
        fixture.status == 'completed' ||
        timeElapsed >= 90;

    if (isFullTime) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: FanColors.away.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'FT',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: FanColors.away,
              ),
            ),
          ],
        ),
      );
    }

    if (isHalfTime) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: FanColors.draw.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'HT',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: FanColors.draw,
              ),
            ),
          ],
        ),
      );
    }

    // LIVE badge with pulsing dot (same as HistoryPage)
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: FanColors.live.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FanColors.live.withValues(alpha: value),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: FanColors.live,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
// ═══════════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

  Widget _statusPill(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3)
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

// ═══════════════════════════════════════════════════════════════════════════
// CENTER BADGE - GRAY SCORES, NO BACKGROUND, SMALLER FONT
// ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: FanColors.background,
      body: RefreshIndicator(
       onRefresh: _handlePullToRefresh,
        color: FanColors.primary,
        backgroundColor: FanColors.background,
        child: CustomScrollView(
          controller: widget.scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    if (_loading && _fixtures.isEmpty)
                      _buildLoadingState()
                    else if (_error.isNotEmpty && _fixtures.isEmpty)
                      _buildErrorState()
                    else
                      _buildFixturesList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// ═══════════════════════════════════════════════════════════════════════════
// CENTER BADGE - GRAY SCORES, SMALLER FONT, NO BACKGROUND
// ═══════════════════════════════════════════════════════════════════════════

  Widget _footerPill({
    required IconData icon,
    required String label,
    required Color color,
    bool filled = false,
    Color? fillColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: filled
            ? (fillColor ?? color.withValues(alpha: 0.1))
            : FanColors.surfaceSunken,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  String _getLeagueIcon(String leagueName) {
    final leagueLower = leagueName.toLowerCase();
    if (leagueLower.contains('premier') || leagueLower.contains('epl'))
      return 'https://cdn-icons-png.flaticon.com/512/3095/3095207.png';
    if (leagueLower.contains('laliga') || leagueLower.contains('spain'))
      return 'https://cdn-icons-png.flaticon.com/512/3095/3095212.png';
    if (leagueLower.contains('serie a') || leagueLower.contains('italy'))
      return 'https://cdn-icons-png.flaticon.com/512/3095/3095216.png';
    if (leagueLower.contains('bundesliga') || leagueLower.contains('german'))
      return 'https://cdn-icons-png.flaticon.com/512/3095/3095221.png';
    if (leagueLower.contains('ligue 1') || leagueLower.contains('france'))
      return 'https://cdn-icons-png.flaticon.com/512/3095/3095225.png';
    if (leagueLower.contains('champions league') || leagueLower.contains('ucl'))
      return 'https://cdn-icons-png.flaticon.com/512/3095/3095230.png';
    if (leagueLower.contains('world cup') || leagueLower.contains('wc'))
      return 'https://cdn-icons-png.flaticon.com/512/3095/3095234.png';
    if (leagueLower.contains('europa'))
      return 'https://cdn-icons-png.flaticon.com/512/3095/3095239.png';
    return 'https://cdn-icons-png.flaticon.com/512/3095/3095243.png';
  }

  String _getUserAvatarUrl(String userId, String username) {
    final hash = (userId + username).hashCode.abs();
    final gender = hash % 2 == 0 ? 'men' : 'women';
    final photoNum = (hash % 100).abs();
    return 'https://randomuser.me/api/portraits/$gender/$photoNum.jpg';
  }

// ─── Helper widgets ───────────────────────────────────────────────────────

// ─── Helper widgets, restyled for light theme ───────────────────────────

// ═══════════════════════════════════════════════════════════════════════════
// MAIN CARD — Material 3
// ═══════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════
// COMMENT INPUT — unchanged behavior, always visible regardless of live state
// ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMatchCard(BuildContext context, Fixture fixture, int index) {
    final fixtureId = fixture.matchId;
    final isLive = fixture.isLive == true;
    final isSoon = fixture.status == 'soon';
    final isCompleted = fixture.status == 'completed';
    final hasUserVoted = _userVotes.containsKey(fixtureId);
    final formattedDate =
        DateHelper.formatFixtureDate(fixture.date, fixture.time);

    // ✅ Check if it's half-time
    final isHalfTime = fixture.status == 'half_time' ||
        (fixture.timeElapsed != null &&
            fixture.timeElapsed! >= 44 &&
            fixture.timeElapsed! <= 46);

    final latestComment = _getLatestComment(fixtureId);
    final homeScore = fixture.homeScore ?? 0;
    final awayScore = fixture.awayScore ?? 0;
    final channelData = _channelFixtureDataMap[fixtureId];
    final commentCount =
        channelData?.commentCount ?? _commentCounts[fixtureId] ?? 0;
    final unreadCount = channelData?.unreadCounts[widget.userId] ??
        _unreadCounts[fixtureId] ??
        0;

    final commentText = latestComment?.comment ?? '';
    final commentLineCount = _calculateCommentLines(commentText);
    final int maxCommentLines =
        commentLineCount > 60 ? 4 : (commentLineCount > 30 ? 3 : 2);

    final activeChannelId = _fixtureChannelOverrides[fixtureId]?.channelId ??
        _localSelectedChannel?.channelId ??
        (_userChannels.isNotEmpty ? _userChannels.first.channelId : null);

    return GestureDetector(
      onTap: () {
        _markFixtureAsViewed(fixtureId);
        _openChatScreen(fixture);
      },
      child: Container(
        key: ValueKey('${fixtureId}_${activeChannelId}'),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: FanColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: FanColors.border.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ══════════ HEADER ══════════
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: FanColors.surfaceSunken,
                      border: Border.all(
                        color: FanColors.border,
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        _getLeagueIcon(fixture.league),
                        width: 20,
                        height: 20,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: FanColors.primaryMuted,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              fixture.league.isNotEmpty
                                  ? fixture.league[0].toUpperCase()
                                  : '⚽',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: FanColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fixture.league.toUpperCase(),
                      style: FanTypography.tag.copyWith(
                        fontSize: 9,
                        letterSpacing: 0.8,
                        color: FanColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // ✅ Show appropriate status badge
                  if (isLive && !isHalfTime)
                    _liveBadge(fixture)
                  else if (isHalfTime)
                    _statusPill('HT', FanColors.draw,
                        icon: Icons.timer_off_rounded)
                  else if (isSoon)
                    _statusPill('SOON', FanColors.draw)
                  else if (hasUserVoted)
                    _statusPill('VOTED', FanColors.primary,
                        icon: Icons.check_circle_rounded)
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: FanColors.surfaceSunken,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        formattedDate,
                        style: FanTypography.tag.copyWith(
                          fontSize: 9,
                          color: FanColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 6),

              // ══════════ SCOREBOARD ══════════
              Row(
                children: [
                  Expanded(
                    child: _teamAvatarColumn(
                      fixture.homeTeam,
                      accentColor: FanColors.primary,
                      isWinner: isCompleted && homeScore > awayScore,
                    ),
                  ),
                  _centerBadge(
                    isLive: isLive,
                    isCompleted: isCompleted,
                    homeScore: homeScore,
                    awayScore: awayScore,
                  ),
                  Expanded(
                    child: _teamAvatarColumn(
                      fixture.awayTeam,
                      accentColor: FanColors.scoreAway,
                      isWinner: isCompleted && awayScore > homeScore,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),

              if (isLive) ...[
                const SizedBox(height: 4),
                Center(child: _buildMinutesDisplay(fixture)),
              ],

              _buildLiveEventsWidget(fixtureId),

              const SizedBox(height: 6),

              // ══════════ 🔥 LIVE COMMENTARY OR LATEST COMMENTS 🔥 ══════════
              _buildCommentaryOrCommentsPreview(
                context: context,
                fixture: fixture,
                fixtureId: fixtureId,
                latestComment: latestComment,
                maxCommentLines: maxCommentLines,
              ),

              const SizedBox(height: 6),

              // ══════════ PLEDGES / WATCH ROW ══════════
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_showPledgesTab && !isLive)
                    _buildPledgeOrMatchedBetsIndicator(fixture)
                  else if (isLive && !isHalfTime)
                    _statusPill('● ON AIR', FanColors.live)
                  else if (isHalfTime)
                    _statusPill('⏱️ HALF TIME', FanColors.draw)
                  else
                    const SizedBox.shrink(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (isLive) {
                        _onWatchPressed(fixture);
                      } else if (isCompleted) {
                        _showMatchDetailsModal(fixture);
                      } else {
                        _openComradeLeaderboardModal(fixture);
                      }
                    },
                    child: _footerPill(
                      icon: isLive
                          ? Icons.play_circle_fill_rounded
                          : isCompleted
                              ? Icons.rate_review_rounded
                              : Icons.groups_rounded,
                      label: isLive
                          ? 'watch'
                          : isCompleted
                              ? 'review'
                              : 'analysis',
                      color: isLive
                          ? FanColors.primary
                          : isCompleted
                              ? FanColors.textSecondary
                              : FanColors.primary,
                    ),
                  ),
                ],
              ),

              if (_showPledgesTab && !isLive) _buildPledgersPreview(fixture),           

              const SizedBox(height: 6),

              // ✅ Always show comment input (even when live or at half-time)
              _buildCommentInput(fixture, index),

              const SizedBox(height: 6),

             

              // ══════════ FOOTER ACTION BAR ══════════
              Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openVotesOnlyModal(fixture),
                    child: _footerPill(
                      icon: Icons.how_to_vote_rounded,
                      label: '${_totalVotesForFixture(fixtureId)}',
                      color: FanColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _toggleLike(fixture, index),
                    child: _footerPill(
                      icon: (_userLikes[fixtureId] ?? false)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: '${_likeStats[fixtureId]?.totalLikes ?? 0}',
                      color: (_userLikes[fixtureId] ?? false)
                          ? FanColors.reactionLike
                          : FanColors.textSecondary,
                      filled: _userLikes[fixtureId] ?? false,
                      fillColor: FanColors.awayDim,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _markFixtureAsViewed(fixtureId);
                      _openChatScreen(fixture);
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _footerPill(
                          icon: Icons.chat_bubble_rounded,
                          label: '$commentCount',
                          color: FanColors.textSecondary,
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              constraints: const BoxConstraints(minWidth: 16),
                              decoration: BoxDecoration(
                                color: FanColors.live,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        FanColors.live.withValues(alpha: 0.4),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  unreadCount > 9 ? '9+' : '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isLive && !isHalfTime)
                    _statusPill('live', FanColors.live),
                  if (isHalfTime) _statusPill('ht', FanColors.draw),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

 Widget _buildCommentInput(Fixture fixture, int index) {
    final String localFixtureId = fixture.matchId;
    final hasUserVoted = _userVotes.containsKey(localFixtureId);
    final isLoggedIn = _isUserLoggedIn();

    _commentControllers.putIfAbsent(
      localFixtureId,
      () => TextEditingController(),
    );
    final controller = _commentControllers[localFixtureId]!;
    final hasText = controller.text.trim().isNotEmpty;

    String hintText;
    bool enabled;
    if (!isLoggedIn) {
      hintText = '🔒 Log in to comment';
      enabled = false;
    } else if (!hasUserVoted) {
      hintText = '🗳️ Vote first to comment';
      enabled = false;
    } else {
      hintText = '💬 Write a comment...';
      enabled = true;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          FootballAvatarManager.buildAvatar(
            userId: widget.userId,
            username: widget.username,
            size: 28,
          ),
          const SizedBox(width: 10),

          // Underline text input - just the bottom border
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: enabled
                        ? FanColors.primary.withValues(alpha: 0.4)
                        : FanColors.border.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
              ),
              child: TextField(
                controller: controller,
                enabled: enabled,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: enabled
                      ? FanColors.textPrimary
                      : FanColors.textSecondary.withValues(alpha: 0.5),
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: FanColors.textSecondary.withValues(alpha: 0.5),
                    fontStyle: enabled ? FontStyle.normal : FontStyle.italic,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                maxLines: null,
                onChanged: (_) => setState(() {}),
                onSubmitted: (value) {
                  if (enabled && value.trim().isNotEmpty) {
                    _createComment(fixture, value, index);
                  }
                },
              ),
            ),
          ),

          // Send button
          if (enabled && hasText)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () {
                  if (enabled && hasText) {
                    _createComment(fixture, controller.text.trim(), index);
                  }
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: FanColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.send_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
// ═══════════════════════════════════════════════════════════════════════════
// M3 STATUS PILL — tonal container, optional pulsing dot for LIVE
// ═══════════════════════════════════════════════════════════════════════════
  Widget _m3Pill(
    BuildContext context, {
    required String label,
    required Color container,
    required Color onContainer,
    IconData? icon,
    bool pulsing = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulsing) ...[
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1.0),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOut,
              builder: (context, value, child) => Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: onContainer.withValues(alpha: value),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ] else if (icon != null) ...[
            Icon(icon, size: 11, color: onContainer),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: onContainer,
            ),
          ),
        ],
      ),
    );
  }

// ═══════════════════════════════════════════════════════════════════════════
// TEAM AVATAR COLUMN — tonal container circles
// ═══════════════════════════════════════════════════════════════════════════
  Widget _teamAvatarColumn(
    String teamName, {
    required Color accentColor,
    bool isWinner = false,
    bool alignEnd = false,
  }) {
    final initials = teamName.trim().isNotEmpty
        ? teamName
            .trim()
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0])
            .join()
            .toUpperCase()
        : '?';

    final avatar = Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor.withValues(alpha: isWinner ? 0.16 : 0.08),
        border: Border.all(
            color: accentColor.withValues(alpha: isWinner ? 0.6 : 0.25),
            width: isWinner ? 1.4 : 1),
      ),
      child: Center(
        child: Text(initials,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: accentColor)),
      ),
    );

    final label = Flexible(
      child: Text(
        teamName,
        style: FanTypography.title.copyWith(
          fontSize: 12.5,
          fontWeight: isWinner ? FontWeight.w800 : FontWeight.w600,
          color: isWinner ? FanColors.textPrimary : FanColors.textSecondary,
        ),
        overflow: TextOverflow.ellipsis,
        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
      ),
    );

    return Row(
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignEnd
          ? [label, const SizedBox(width: 8), avatar]
          : [avatar, const SizedBox(width: 8), label],
    );
  }

// ═══════════════════════════════════════════════════════════════════════════
// CENTER BADGE (score / VS)
// ═══════════════════════════════════════════════════════════════════════════
  Widget _centerBadge({
    required bool isLive,
    required bool isCompleted,
    required int homeScore,
    required int awayScore,
  }) {
    if (isLive || isCompleted) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: FanColors.surfaceSunken, // ✅ Always same background
          borderRadius: BorderRadius.circular(12),
          // ✅ No border when live
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$homeScore',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: FanColors.scoreHome,
                )),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('-',
                  style: TextStyle(
                    fontSize: 12,
                    color: FanColors.textSecondary,
                  )),
            ),
            Text('$awayScore',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: FanColors.scoreAway,
                )),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: FanColors.surfaceSunken,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FanColors.border),
      ),
      child: Text('VS',
          style: FanTypography.tag.copyWith(
              fontSize: 10,
              color: FanColors.textSecondary,
              letterSpacing: 1.0)),
    );
  }

// ═══════════════════════════════════════════════════════════════════════════
// M3 ACTION CHIP (Watch / Review / Analysis pill)
// ═══════════════════════════════════════════════════════════════════════════
  Widget _m3ActionChip(
    BuildContext context, {
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required Color container,
    required Color onContainer,
    bool tonal = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: container,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: onContainer),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: onContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// ═══════════════════════════════════════════════════════════════════════════
// M3 ICON CHIP (footer bar: vote / like / comment counts)
// ═══════════════════════════════════════════════════════════════════════════
  Widget _m3IconChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    Color? activeContainer,
    Color? activeOnContainer,
  }) {
    final cs = Theme.of(context).colorScheme;
    final container = active
        ? (activeContainer ?? cs.primaryContainer)
        : cs.surfaceContainerHigh;
    final onContainer = active
        ? (activeOnContainer ?? cs.onPrimaryContainer)
        : cs.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: container,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: onContainer),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: onContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// ═══════════════════════════════════════════════════════════════════════════
// CHAT LINE PREVIEW (non-live latest comment)
// ═══════════════════════════════════════════════════════════════════════════
  Widget _chatLinePreview({
    required FeaturedComment? latestComment,
    required String fixtureId,
    required int maxLines,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipOval(
          child: Image.network(
            _getUserAvatarUrl(
              latestComment?.userId ?? fixtureId,
              latestComment?.username ?? 'fan',
            ),
            width: 26,
            height: 26,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: FanColors.primaryMuted,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  latestComment != null && latestComment.username.isNotEmpty
                      ? latestComment.username[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: FanColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    latestComment?.username ?? 'Fan zone',
                    style: FanTypography.tag.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: FanColors.textPrimary,
                    ),
                  ),
                  if (latestComment != null) ...[
                    const SizedBox(width: 5),
                    Text(
                      DateHelper.formatTimeAgo(latestComment.timestamp),
                      style: FanTypography.tag.copyWith(
                        fontSize: 8,
                        color: FanColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                latestComment?.comment ?? 'Say something about this match 💬',
                style: FanTypography.body.copyWith(
                  color: latestComment != null
                      ? FanColors.textPrimary
                      : FanColors.textTertiary,
                  fontSize: 12,
                  height: 1.35,
                  fontStyle: latestComment == null
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
                maxLines: latestComment != null ? maxLines : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

// ═══════════════════════════════════════════════════════════════════════════
// LIVE COMMENTARY (replaces comment preview when live)
// ═══════════════════════════════════════════════════════════════════════════



  Widget _buildPledgeOrMatchedBetsIndicator(Fixture fixture) {
    final fixtureId = fixture.matchId;
    final pledgeCount = _pledgeCounts[fixtureId] ?? 0;

    // If there are pledges, show pledge count
    if (pledgeCount > 0) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showBetsPopup(fixture),
        child: Row(
          children: [
            Icon(Icons.attach_money, size: 11, color: Colors.amber.shade400),
            const SizedBox(width: 3),
            Text(
              '$pledgeCount',
              style: TextStyle(fontSize: 10, color: Colors.amber.shade400),
            ),
          ],
        ),
      );
    }

    // If no pledges, check for matched bets
    final matchedBets = _bettors[fixtureId] ?? [];
    final activeMatched = matchedBets.where((b) => b.isMatched).toList();

    if (activeMatched.isNotEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showBetsPopup(fixture),
        child: Row(
          children: [
            Icon(Icons.handshake, size: 11, color: Colors.blue),
            const SizedBox(width: 3),
            Text(
              '${activeMatched.length}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      );
    }

    // No bets at all
    return const SizedBox.shrink();
  }

  /// Calculates the number of lines a comment would take based on character count
  /// and typical screen width. Returns an approximate line count.
  int _calculateCommentLines(String comment) {
    if (comment.isEmpty) return 1;

    // Average characters per line on mobile (rough estimate)
    // This accounts for varying screen sizes
    final avgCharsPerLine = 35; // Adjust based on your font size

    final lineCount = (comment.length / avgCharsPerLine).ceil();

    // Clamp between 1 and 4 lines
    return lineCount.clamp(1, 4);
  }

  /// Inline, compact channel/group selector matching the font size and
  /// icon size of the votes/likes/comments items in the bottom row.

// Clean status action button

  FeaturedComment? _getLatestComment(String fixtureId) {
    // Purely returns the latest chat comment for this fixture — no
    // live/halftime branching here. _buildCommentaryOrCommentsPreview is
    // the single place that decides whether to show this or commentary.
    return _featuredComments[fixtureId];
  }

// ✅ Add this helper method to generate random comments
  FeaturedComment _generateRandomComment(Fixture fixture) {
    final random = Random();
    final randomIndex = random.nextInt(_sampleComments.length);
    final randomUserIndex = random.nextInt(_sampleUsernames.length);

    final comment = _sampleComments[randomIndex];
    final username = _sampleUsernames[randomUserIndex];

    // Random vote selection for generated comments
    final voteOptions = ['home_team', 'away_team', 'draw'];
    final randomVote = voteOptions[random.nextInt(voteOptions.length)];

    return FeaturedComment(
      userId: 'generated_${DateTime.now().millisecondsSinceEpoch}',
      username: username,
      comment: comment,
      teamSupport: _getTeamSupportForUser(randomVote, fixture),
      avatarUrl: '',
      timestamp: DateTime.now().subtract(Duration(minutes: random.nextInt(60))),
    );
  }

  Future<void> _fetchLiveEvents(String fixtureId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/games/$fixtureId/events?limit=10'),
            headers: await _buildHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<LiveEvent> events = [];

        if (data['success'] == true && data['data'] is List) {
          events =
              (data['data'] as List).map((e) => LiveEvent.fromJson(e)).toList();
        }

        _safeSetState(() {
          _liveEvents[fixtureId] = events;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching events for $fixtureId: $e');
    }
  }

  Future<bool> _checkVotesButtonVisibility() async {
  try {
    final response = await http
        .get(
          Uri.parse('$API_BASE_URL/visibility/votes_button_show'),
          headers: await _buildHeaders(),
        )
        .timeout(const Duration(seconds: 8));   // ← add this

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['value'] ?? true;
    }
    return true;
  } on TimeoutException {
    debugPrint('⏱️ Timeout checking votes button visibility');
    return true; // fail open, don't block the modal
  } catch (e) {
    debugPrint('❌ Error checking visibility: $e');
    return true;
  }
}


Future<void> _handlePullToRefresh() async {
  try {
    await Future.any([
      _fetchFixtures(forceRefresh: true, showNotification: true),
      Future.delayed(const Duration(seconds: 20)),
    ]);
  } catch (e) {
    debugPrint('⚠️ Pull-to-refresh error (spinner will still stop): $e');
  }
}
  Widget _buildMatchActionButton(Fixture fixture) {
    final matchDate = DateTime.tryParse(fixture.date) ?? DateTime.now();
    final isLive = DateHelper.isMatchLive(fixture.date);
    final isFinished = DateHelper.isMatchFinished(matchDate);

    // ✅ CONDITION 1: Match IS LIVE - Show WATCH ICON
    if (isLive) {
      return GestureDetector(
        onTap: () => _showMatchDetailsModal(fixture),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
          child: const Icon(
            Icons.play_circle_outline,
            size: 18,
            color: Colors.red,
          ),
        ),
      );
    }

    // ✅ CONDITION 2: Match FINISHED - Show REVIEW ICON
    if (isFinished) {
      return GestureDetector(
        onTap: () => _showMatchDetailsModal(fixture),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: FanColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.rate_review,
            size: 18,
            color: FanColors.textSecondary,
          ),
        ),
      );
    }

    // ✅ CONDITION 3: Match NOT STARTED (Upcoming) - Show GROUP/PEOPLE ICON
    return GestureDetector(
      onTap: () => _openComradeLeaderboardModal(fixture),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: FanColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          Icons.people_alt,
          size: 18,
          color: FanColors.primary,
        ),
      ),
    );
  }

  /// Opens the Comrade Leaderboard Modal
  void _openComradeLeaderboardModal(Fixture fixture, {String? channelId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ComradeModal(
        isOpen: true,
        onClose: () => Navigator.pop(context),
        currentUserId: widget.userId,
        currentUserName: widget.username,
        authToken: widget.authToken,
        channelId: channelId ?? _localSelectedChannel?.channelId,
        channelName: _localSelectedChannel?.name,
        fixture: fixture, // ← Pass fixture for Voters tab
        comradesList: _userComrades, // ← Pass comrades list
        comradesVoteMap: _getVotersForFixture(fixture.matchId), // ← Pass voters
        hasUserVoted: _userVotes.containsKey(fixture.matchId),
        userVoteSelection: _userVotes[fixture.matchId],
      ),
    );
  }

  // In fixture_page.dart - Updated WebSocket management
  void _connectWebSocket() {
  if (!_isUserLoggedIn()) return;
  if (_fixtures.isEmpty) return;

  final ws = WebSocketService();

  // The channelId passed to connect() only seeds the socket's *initial*
  // room join — joinRoom is additive, so it doesn't limit which other
  // rooms get joined afterward. Per-fixture joins below each resolve their
  // own channelId via _resolveChannelIdFor(), so a fixture with a
  // _fixtureChannelOverrides entry or one that only matches
  // widget.selectedChannelId (not _localSelectedChannel) still lands in
  // its correct room instead of whatever channel happened to seed the
  // connection.
  final initialChannelId = _resolveChannelIdFor(
    _fixtures.isNotEmpty ? _fixtures.first.matchId : '',
  );
  if (initialChannelId == null) return;

  if (!_wsStatusListenerAttached) {
    _wsStatusListenerAttached = true;
    ws.connectionStatus.listen((connected) {
      if (connected) {
        _wsConnected = true;
        _joinAllLiveFixtureRooms();
        for (var fixture in _fixtures) {
          if (fixture.isLive == true) {
            _requestCurrentMinute(fixture.matchId);
            _fetchLatestCommentaryViaHttp(fixture.matchId);
            final cid = _resolveChannelIdFor(fixture.matchId);
            if (cid != null) {
              _fetchLatestCommentViaHttpWithChannel(fixture.matchId, fixture, cid);
              _fetchCommentCountViaHttp(fixture.matchId, channelId: cid);
            }
          }
        }
      } else {
        debugPrint('⚠️ WebSocket disconnected');
        _wsConnected = false;
        if (!_isBackgroundPaused && mounted) {
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted && !_wsConnected && !_isBackgroundPaused) {
              _connectWebSocket();
            }
          });
        }
      }
    });
  }

  // ✅ Actually establish/reuse the connection — this was missing entirely.
  ws.connect(widget.userId, widget.authToken ?? '', initialChannelId, widget.username);

  // ✅ Handle the case where the socket is ALREADY connected (e.g. ChatScreen
  // connected it earlier). The listener above only reacts to future state
  // transitions on a broadcast stream — it will never see a "connected" event
  // that already happened before this listener was attached.
  if (ws.isConnected) {
    _wsConnected = true;
    _joinAllLiveFixtureRooms();
    for (var fixture in _fixtures) {
      if (fixture.isLive == true) {
        _requestCurrentMinute(fixture.matchId);
        _fetchLatestCommentaryViaHttp(fixture.matchId);
      }
    }
  }
}

 //ture-specific room for every currently-live fixture,
  /// so commentary/chat broadcasts for each one reach this screen —
  /// additive, does not evict any other joined room (e.g. an open
  /// ChatScreen's room on the same shared connection).
 /// Joins the fixture-specific room for every currently-live fixture,
  /// so commentary/chat broadcasts for each one reach this screen —
  /// additive, does not evict any other joined room (e.g. an open
  /// ChatScreen's room on the same shared connection).
  ///
  /// ✅ Resolves channelId PER FIXTURE via _resolveChannelIdFor() instead of
  /// using one page-level channelId for every fixture. A single shared
  /// channelId is wrong whenever a fixture has an entry in
  /// _fixtureChannelOverrides, or whenever widget.selectedChannelId (set by
  /// HomePage) hasn't been mirrored into _localSelectedChannel yet — in
  /// either case this used to join the wrong room, so that fixture's
  /// commentary/vote/chat broadcasts would silently never arrive even
  /// though the socket itself was connected and healthy.
  void _joinAllLiveFixtureRooms() {
    final ws = WebSocketService();

    for (var fixture in _fixtures) {
      if (fixture.isLive == true) {
        final channelId = _resolveChannelIdFor(fixture.matchId);
        if (channelId == null) continue;
        ws.joinChannelFixtureRoom(channelId, fixtureId: fixture.matchId);
      }
    }
  }
  // ============================================================================
// REQUEST CURRENT MINUTE
// ============================================================================

  void _requestCurrentMinute(String fixtureId) {
    final ws = WebSocketService();
    if (!ws.isConnected) return;

    final channelId = _localSelectedChannel?.channelId ??
        (_userChannels.isNotEmpty ? _userChannels.first.channelId : null);

    ws.requestCurrentMinute(fixtureId: fixtureId, channelId: channelId);
    debugPrint(
        '📤 Requested current minute for fixture: $fixtureId (channel: $channelId)');
  }

  void _requestAllCurrentMinutes() {
    final ws = WebSocketService();
    if (!ws.isConnected) return;

    for (var fixture in _fixtures) {
      if (fixture.isLive == true ||
          fixture.status == 'live' ||
          fixture.status == 'half_time') {
        ws.requestCurrentMinute(fixtureId: fixture.matchId);
      }
    }
    debugPrint('📤 Requested current minutes for all live fixtures');
  }

  /// Same per-fixture channel resolution fix as _joinAllLiveFixtureRooms —
/// this was the other call site using a single page-level channelId for
/// every live fixture's room join, called from _fetchFixturesFromBackend()
/// when the socket is already connected and a fixture has newly gone live.
void _joinFixtureRooms() {
  final ws = WebSocketService();

  for (var fixture in _fixtures) {
    if (fixture.isLive == true) {
      final channelId = _resolveChannelIdFor(fixture.matchId);
      if (channelId == null) {
        debugPrint('⚠️ No channel resolved for fixture ${fixture.matchId}, skipping room join');
        continue;
      }
      ws.joinChannelFixtureRoom(channelId, fixtureId: fixture.matchId);
      debugPrint('📡 Joined room for live fixture: ${fixture.matchId} (channel: $channelId)');
    }
  }
}

  /// Fetch ONLY comment count via HTTP
  Future<void> _fetchInitialCommentData() async {
    debugPrint(
        '📥 Fetching initial comment data for ${_fixtures.length} fixtures...');

    for (var fixture in _fixtures) {
      final fixtureId = fixture.matchId;
      await _fetchCommentCountViaHttp(fixtureId);
      await _fetchLatestCommentViaHttp(fixtureId, fixture);
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // ✅ Force rebuild after all data is loaded
    _safeSetState(() {
      _fixtures = List.from(_fixtures);
    });

    debugPrint('✅ Initial comment data loaded for all fixtures');
  }

// Update _fetchCommentCountViaHttp to save to disk
  Future<int?> _fetchCommentCountViaHttp(String fixtureId,
      {String? channelId}) async {
    // ✅ SKIP if WebSocket updated recently
    final lastWsUpdate = AppCache.getLastCommentUpdate(fixtureId);
    if (lastWsUpdate != null &&
        DateTime.now().difference(lastWsUpdate).inSeconds < 5) {
      debugPrint(
          '⏭️ Skipping HTTP comment count (WebSocket is fresher) for $fixtureId');
      return null;
    }

    try {
      final effectiveChannelId = channelId ?? _resolveChannelIdFor(fixtureId);
      if (effectiveChannelId == null) return null;

      final response = await http
          .get(
            Uri.parse(
                '$API_BASE_URL/channels/$effectiveChannelId/fixtures/$fixtureId/comments/count'),
            headers: await _buildHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final count = data['count'] ?? 0;

        final wsUpdateDuringRequest = AppCache.getLastCommentUpdate(fixtureId);
        if (wsUpdateDuringRequest != null &&
            DateTime.now().difference(wsUpdateDuringRequest).inSeconds < 2) {
          debugPrint(
              '⏭️ Skipping HTTP comment count (WebSocket updated during request)');
          return null;
        }

        _safeSetState(() {
          _commentCounts[fixtureId] = count;
        });

        AppCache.applyUpdate(
          fixtureId: fixtureId,
          updateType: 'comment',
          value: count,
          extraData: {'channelId': effectiveChannelId},
        );
        await AppCache.saveCommentCount(fixtureId, count);

        _pendingCommentCounts[fixtureId] = count;

        return count;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Error fetching comment count for $fixtureId: $e');
      return null;
    }
  }

// Call this when you want to clear pending counts (e.g., on channel switch)
  void _clearPendingCounts() {
    _pendingCommentCounts.clear();
    _refreshedAfterChat.clear();
    _isReturningFromChat = false;
  }

  Future<void> _fetchLatestCommentViaHttp(
      String fixtureId, Fixture fixture) async {
    try {
      final channelId = _resolveChannelIdFor(fixtureId);

      if (channelId == null) return;

      final response = await http
          .get(
            Uri.parse(
                '$API_BASE_URL/channels/$channelId/messages?fixture_id=$fixtureId&limit=1'),
            headers: await _buildHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final messagesList = data['messages'] ?? [];

        if (messagesList.isNotEmpty) {
          final latestComment = messagesList.first as Map;

          final shouldUpdate =
              !_lastWebSocketLatestCommentUpdate.containsKey(fixtureId) ||
                  _lastWebSocketLatestCommentUpdate[fixtureId]!.isBefore(
                      DateTime.now().subtract(const Duration(seconds: 5)));

          if (shouldUpdate && mounted) {
            final commentText = latestComment['text']?.toString() ?? '';
            final username = latestComment['sender_name']?.toString() ?? 'Fan';
            final userId = latestComment['sender_id']?.toString() ?? '';
            final selection = latestComment['selection']?.toString();

            DateTime timestamp;
            try {
              timestamp = DateTime.parse(latestComment['sent_at']?['\$date'] ??
                  latestComment['sent_at']?.toString() ??
                  DateTime.now().toIso8601String());
            } catch (e) {
              timestamp = DateTime.now();
            }

            _safeSetState(() {
              _featuredComments[fixtureId] = FeaturedComment(
                userId: userId,
                username: username,
                comment: commentText,
                teamSupport: _getTeamSupportForUser(selection, fixture),
                avatarUrl: '',
                timestamp: timestamp,
              );
            });

            AppCache.applyUpdate(
              fixtureId: fixtureId,
              updateType: 'latest_comment',
              value: 1,
              extraData: {
                'comment': commentText,
                'username': username,
                'selection': selection,
              },
            );
            await AppCache.saveLatestComment(fixtureId, commentText, username);

            debugPrint(
                '💬 LATEST comment for $fixtureId: "$commentText" from $username (channel: $channelId)');
          }
        } else {
          _featuredComments.remove(fixtureId);
          debugPrint(
              '📭 No comments for fixture $fixtureId in channel $channelId');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching latest comment for $fixtureId: $e');
    }
  }

  Future<void> _fetchAllLatestComments() async {
    if (_fixtures.isEmpty) return;

    debugPrint(
        '💬 Fetching latest comments for ${_fixtures.length} fixtures...');

    final channelId = _localSelectedChannel?.channelId ??
        (_userChannels.isNotEmpty ? _userChannels.first.channelId : null);

    if (channelId == null) {
      debugPrint('⚠️ No channelId available for fetching latest comments');
      return;
    }

    try {
      final List<Future> requests = [];
      for (var fixture in _fixtures) {
        requests.add(_fetchLatestCommentViaHttp(fixture.matchId, fixture));
      }
      await Future.wait(requests);

      // ✅ AFTER all real comments are fetched, generate mock ONLY for fixtures that have NO comments
      // AND haven't been updated by WebSocket recently
      for (var fixture in _fixtures) {
        final fixtureId = fixture.matchId;
        final hasRealComment = _featuredComments.containsKey(fixtureId);
        final hasWebSocketUpdate = _lastWebSocketLatestCommentUpdate
                .containsKey(fixtureId) &&
            _lastWebSocketLatestCommentUpdate[fixtureId]!
                .isAfter(DateTime.now().subtract(const Duration(seconds: 10)));

        if (!hasRealComment && !hasWebSocketUpdate) {
          // This fixture has NO real comments and no recent WebSocket update - generate mock
          _generateMockCommentForFixture(fixture);
        }
      }

      debugPrint(
          '✅ Fetched latest comments and generated mocks for fixtures with no comments');
    } catch (e) {
      debugPrint('❌ Error fetching latest comments: $e');
      // On error, still generate mocks for all fixtures (but only if no WebSocket update)
      for (var fixture in _fixtures) {
        final fixtureId = fixture.matchId;
        final hasWebSocketUpdate = _lastWebSocketLatestCommentUpdate
                .containsKey(fixtureId) &&
            _lastWebSocketLatestCommentUpdate[fixtureId]!
                .isAfter(DateTime.now().subtract(const Duration(seconds: 10)));
        if (!hasWebSocketUpdate) {
          _generateMockCommentForFixture(fixture);
        }
      }
    }
  }

// Add this helper method if not already present

  /// Handle comment count update from WebSocket
  // Make sure _handleCommentCountUpdate saves to disk properly
  void _handleCommentCountUpdate(Map<String, dynamic> payload) {
    final fixtureId = payload['fixture_id']?.toString();
    final count = payload['count'] as int?;

    if (fixtureId == null || count == null) return;

    AppCache.applyUpdate(
      fixtureId: fixtureId,
      updateType: 'comment',
      value: count,
    );

    _safeSetState(() {
      _commentCounts[fixtureId] = count;

      // ✅ Also update _channelFixtureDataMap
      if (_channelFixtureDataMap.containsKey(fixtureId)) {
        final existing = _channelFixtureDataMap[fixtureId]!;
        _channelFixtureDataMap[fixtureId] = ChannelFixtureData(
          fixtureId: existing.fixtureId,
          channelId: existing.channelId,
          matchName: existing.matchName,
          kickoffTime: existing.kickoffTime,
          status: existing.status,
          homeVotes: existing.homeVotes,
          awayVotes: existing.awayVotes,
          drawVotes: existing.drawVotes,
          lastMessage: existing.lastMessage,
          lastMessageAt: existing.lastMessageAt,
          lastSender: existing.lastSender,
          userVote: existing.userVote,
          commentCount: count,
          unreadCounts: existing.unreadCounts,
        );
      }
    });
  }

// Add this helper method
  Future<void> _saveCommentCountToCache(String fixtureId, int count) async {
    await LocalStorageManager.saveCommentCount(fixtureId, count);
    debugPrint('💾 Saved comment count $count for fixture $fixtureId to disk');
  }

  /// Handle vote update from WebSocket
  /// Handle vote update from WebSocket
  void _handleVoteUpdateFromWebSocket(Map<String, dynamic> payload) {
    final fixtureId = payload['fixture_id']?.toString();
    final totalVotes = payload['total_votes'] as int?;
    final homeVotes = payload['home_votes'] as int?;
    final awayVotes = payload['away_votes'] as int?;
    final drawVotes = payload['draw_votes'] as int?;
    final userVote = payload['user_vote'] as String?; // ✅ ADD THIS
    final userId = payload['user_id'] as String?;

    if (fixtureId == null || totalVotes == null) return;

    // ✅ UPDATE AppCache - Vote counts
    AppCache.applyUpdate(
      fixtureId: fixtureId,
      updateType: 'vote',
      value: totalVotes,
      extraData: {
        'homeVotes': homeVotes ?? 0,
        'awayVotes': awayVotes ?? 0,
        'drawVotes': drawVotes ?? 0,
      },
    );

    // ✅ UPDATE USER VOTE IF IT'S FOR THE CURRENT USER
    if (userVote != null && userId == widget.userId) {
      String frontendSelection;
      if (userVote == 'home') {
        frontendSelection = 'home_team';
      } else if (userVote == 'away') {
        frontendSelection = 'away_team';
      } else if (userVote == 'draw') {
        frontendSelection = 'draw';
      } else {
        frontendSelection = userVote;
      }

      // ✅ UPDATE LOCAL STATE
      _safeSetState(() {
        _userVotes[fixtureId] = frontendSelection;
      });

      // ✅ UPDATE APPCACHE - User vote (triggers votesStream)
      AppCache.setUserVote(fixtureId, frontendSelection);

      debugPrint(
          '✅ FixturesPage: User vote updated via WebSocket: $frontendSelection');
    }

    // ✅ UPDATE _channelFixtureDataMap (UI reads this)
    _safeSetState(() {
      if (_channelFixtureDataMap.containsKey(fixtureId)) {
        final existing = _channelFixtureDataMap[fixtureId]!;
        _channelFixtureDataMap[fixtureId] = ChannelFixtureData(
          fixtureId: existing.fixtureId,
          channelId: existing.channelId,
          matchName: existing.matchName,
          kickoffTime: existing.kickoffTime,
          status: existing.status,
          homeVotes: homeVotes ?? existing.homeVotes,
          awayVotes: awayVotes ?? existing.awayVotes,
          drawVotes: drawVotes ?? existing.drawVotes,
          lastMessage: existing.lastMessage,
          lastMessageAt: existing.lastMessageAt,
          lastSender: existing.lastSender,
          userVote: userVote ?? existing.userVote,
          commentCount: existing.commentCount,
          unreadCounts: existing.unreadCounts,
        );
      } else {
        // Create new entry if it doesn't exist
        _channelFixtureDataMap[fixtureId] = ChannelFixtureData(
          fixtureId: fixtureId,
          channelId: '',
          matchName: '',
          kickoffTime: DateTime.now(),
          status: '',
          homeVotes: homeVotes ?? 0,
          awayVotes: awayVotes ?? 0,
          drawVotes: drawVotes ?? 0,
          commentCount: 0,
          unreadCounts: {},
        );
      }
    });

    // ✅ Notify AppCache listeners (for ChatScreen)
    AppCache.notifyVotesChanged();
  }

  void _handleLatestCommentUpdate(Map<String, dynamic> payload) {
    final fixtureId =
        payload['fixture_id']?.toString() ?? payload['fixtureId']?.toString();
    final commentText =
        payload['comment']?.toString() ?? payload['text']?.toString();
    final username = payload['username']?.toString() ?? 'Anonymous';
    final userId =
        payload['user_id']?.toString() ?? payload['userId']?.toString() ?? '';
    final selection = payload['selection']?.toString();
    final timestampStr = payload['timestamp']?.toString();

    if (fixtureId == null || commentText == null) return;

    debugPrint(
        '💬 WebSocket latest comment: $fixtureId → "$commentText" from $username');

    // ✅ Set timestamp so HTTP doesn't overwrite
    _lastWebSocketLatestCommentUpdate[fixtureId] = DateTime.now();

    DateTime timestamp;
    try {
      timestamp =
          timestampStr != null ? DateTime.parse(timestampStr) : DateTime.now();
    } catch (e) {
      timestamp = DateTime.now();
    }

    // Find the fixture
    final fixture = _fixtures.firstWhere(
      (f) => f.matchId == fixtureId,
      orElse: () => null as Fixture,
    );

    if (fixture != null) {
      _safeSetState(() {
        _featuredComments[fixtureId] = FeaturedComment(
          userId: userId,
          username: username,
          comment: commentText,
          teamSupport: _getTeamSupportForUser(selection, fixture),
          avatarUrl: '',
          timestamp: timestamp,
        );
      });

      // ✅ UPDATE APPCACHE - Latest comment
      AppCache.applyUpdate(
        fixtureId: fixtureId,
        updateType: 'latest_comment',
        value: 1,
        extraData: {
          'comment': commentText,
          'username': username,
          'selection': selection,
        },
      );
      AppCache.saveLatestComment(fixtureId, commentText, username);

      // ✅ Also update ChannelFixtureData
      if (_channelFixtureDataMap.containsKey(fixtureId)) {
        final existing = _channelFixtureDataMap[fixtureId]!;
        _channelFixtureDataMap[fixtureId] = ChannelFixtureData(
          fixtureId: existing.fixtureId,
          channelId: existing.channelId,
          matchName: existing.matchName,
          kickoffTime: existing.kickoffTime,
          status: existing.status,
          homeVotes: existing.homeVotes,
          awayVotes: existing.awayVotes,
          drawVotes: existing.drawVotes,
          lastMessage: commentText,
          lastMessageAt: DateTime.now(),
          lastSender: username,
          userVote: existing.userVote,
          commentCount: existing.commentCount,
          unreadCounts: Map.from(existing.unreadCounts),
        );
        _saveChannelFixturesToCache(_channelFixtureDataMap);
      }

      // Also add to comments list if it's a new comment
      if (userId.isNotEmpty && userId != widget.userId) {
        final newComment = FixtureComment(
          id: 'ws_${DateTime.now().millisecondsSinceEpoch}',
          userId: userId,
          username: username,
          fixtureId: fixtureId,
          comment: commentText,
          selection: selection,
          timestamp: timestamp,
        );

        if (!_fixtureComments.containsKey(fixtureId)) {
          _fixtureComments[fixtureId] = [];
        }

        // Check for duplicate
        final exists = _fixtureComments[fixtureId]!.any((c) =>
            c.userId == userId &&
            c.comment == commentText &&
            c.timestamp.difference(timestamp).abs().inSeconds < 5);

        if (!exists) {
          _fixtureComments[fixtureId]!.insert(0, newComment);
          _commentCounts[fixtureId] = (_commentCounts[fixtureId] ?? 0) + 1;
          _saveCommentsToDisk(fixtureId);
        }
      }

      _saveToGlobalCache();
    }
  }

  /// Handle like update from WebSocket
  void _handleLikeUpdateFromWebSocket(Map<String, dynamic> payload) {
    final fixtureId = payload['fixture_id']?.toString();
    final totalLikes = payload['total_likes'] as int?;

    if (fixtureId != null && totalLikes != null) {
      _safeSetState(() {
        _likeStats[fixtureId] = LikeStatsResponse(
          fixtureId: fixtureId,
          totalLikes: totalLikes,
          userHasLiked: _userLikes[fixtureId] ?? false,
        );
      });

      // ✅ UPDATE APPCACHE - Like count
      final channelId = _localSelectedChannel?.channelId ??
          (_userChannels.isNotEmpty ? _userChannels.first.channelId : null);

      AppCache.applyUpdate(
        fixtureId: fixtureId,
        updateType: 'like',
        value: totalLikes,
        extraData: {
          'channelId': channelId,
          'liked': _userLikes[fixtureId] ?? false,
        },
      );
      AppCache.saveLikeCount(fixtureId, totalLikes);
    }
  }

  /// Setup WebSocket listeners

// When WebSocket sends new.event
  void _handleNewLiveEvent(Map<String, dynamic> payload) {
    final fixtureId = payload['fixture_id']?.toString();
    final eventData = payload['event'];

    if (fixtureId == null || eventData == null) return;

    final newEvent = LiveEvent.fromJson(eventData as Map<String, dynamic>);

    // Add to live events (existing code)
    _safeSetState(() {
      final currentEvents = _liveEvents[fixtureId] ?? [];
      _liveEvents[fixtureId] = [newEvent, ...currentEvents].take(20).toList();
    });

    // ✅ ADD TO COMMENTARY WINDOW (sliding 3)
    final style = _getCommentaryStyle(newEvent.eventType);
    final entry = LiveCommentaryEntry(
      text: newEvent.getDisplayText(),
      type: newEvent.eventType,
      minute: newEvent.minute,
      timestamp: newEvent.timestamp,
      color: style['color'] as Color,
      icon: style['icon'] as IconData,
      scorer: newEvent.scorer,
      team: newEvent.team,
    );

    _addCommentaryToWindow(fixtureId, entry);
  }

  // ============================================================================
// WEB SOCKET LISTENER SETUP - COMPLETE
// ============================================================================

  // ============================================================================
// WEB SOCKET LISTENER SETUP - COMPLETE
// ============================================================================

  void _setupWebSocketListeners() {
    final ws = WebSocketService();

    // ============================================================
    // 1. CHAT MESSAGE HANDLER (NEW COMMENT)
    // ============================================================
   ws.on('chat.message', (payload) async {
      final fixtureId = payload['fixtureId'] as String?;
      final comment = payload['message'] as String?;
      final username = payload['username'] as String?;
      final selection = payload['selection'] as String?;
      final userId = payload['userId'] as String?;
      final messageId = payload['messageId'] as String?;
      final channelId = payload['channelId'] as String?;

      if (fixtureId == null || comment == null || userId == null) return;
      if (userId == widget.userId) return;

      debugPrint('💬 New comment from WebSocket: $fixtureId');

      // Update AppCache for comment count
      final currentCount = AppCache.channelFixtures[fixtureId]?.commentCount ??
          _commentCounts[fixtureId] ??
          0;
      final newCount = currentCount + 1;

      AppCache.applyUpdate(
        fixtureId: fixtureId,
        updateType: 'comment',
        value: newCount,
        extraData: {'channelId': channelId},
      );
      await AppCache.saveCommentCount(fixtureId, newCount);

      // Update AppCache for latest comment
      AppCache.applyUpdate(
        fixtureId: fixtureId,
        updateType: 'latest_comment',
        value: 1,
        extraData: {
          'comment': comment,
          'username': username,
          'selection': selection,
        },
      );
      await AppCache.saveLatestComment(
          fixtureId, comment ?? '', username ?? 'Anonymous');

      // Update local state
      _safeSetState(() {
        _commentCounts[fixtureId] = newCount;
        _unreadCounts[fixtureId] = (_unreadCounts[fixtureId] ?? 0) + 1;

        final fixture = _fixtures.firstWhere((f) => f.matchId == fixtureId);
        _featuredComments[fixtureId] = FeaturedComment(
          userId: userId,
          username: username ?? 'Anonymous',
          comment: comment,
          teamSupport: _getTeamSupportForUser(selection, fixture),
          avatarUrl: '',
          timestamp: DateTime.now(),
        );

        final newComment = FixtureComment(
          id: messageId ?? 'ws_${DateTime.now().millisecondsSinceEpoch}',
          userId: userId,
          username: username ?? 'Anonymous',
          fixtureId: fixtureId,
          comment: comment,
          selection: selection,
          timestamp: DateTime.now(),
        );
        if (!_fixtureComments.containsKey(fixtureId)) {
          _fixtureComments[fixtureId] = [];
        }
        _fixtureComments[fixtureId]!.insert(0, newComment);
      });

      _startPulsingAnimation(fixtureId);

      // ✅ Same cache-currency fix as _createComment, for messages arriving
      // from OTHER users while FixturesPage (not ChatScreen) is open.
      AppCache.appendCachedMessage(channelId ?? '', fixtureId, {
        'id': messageId ?? 'ws_${DateTime.now().millisecondsSinceEpoch}',
        'userId': userId,
        'username': username ?? 'Anonymous',
        'text': comment,
        'selection': selection,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 1,
        'isSeen': false,
        'isCommentary': false,
        'commentaryType': null,
      });

      AppCache.saveChannelFixtures(AppCache.channelFixtures);
      await LocalStorageManager.saveCommentsForFixture(
          fixtureId, _fixtureComments[fixtureId]!);
    });

    // ============================================================
    // 2. COMMENT COUNT UPDATE
    // ============================================================
    ws.on('comment.count', (payload) {
      final fixtureId = payload['fixture_id']?.toString();
      final count = payload['count'] as int?;

      if (fixtureId == null || count == null) return;

      AppCache.applyUpdate(
        fixtureId: fixtureId,
        updateType: 'comment',
        value: count,
      );

      _safeSetState(() {
        _commentCounts[fixtureId] = count;
        if (_channelFixtureDataMap.containsKey(fixtureId)) {
          final existing = _channelFixtureDataMap[fixtureId]!;
          _channelFixtureDataMap[fixtureId] = ChannelFixtureData(
            fixtureId: existing.fixtureId,
            channelId: existing.channelId,
            matchName: existing.matchName,
            kickoffTime: existing.kickoffTime,
            status: existing.status,
            homeVotes: existing.homeVotes,
            awayVotes: existing.awayVotes,
            drawVotes: existing.drawVotes,
            lastMessage: existing.lastMessage,
            lastMessageAt: existing.lastMessageAt,
            lastSender: existing.lastSender,
            userVote: existing.userVote,
            commentCount: count,
            unreadCounts: existing.unreadCounts,
          );
        }
      });
    });

    // ============================================================
    // 3. VOTE UPDATE
    // ============================================================
    ws.on('vote.update', (payload) {
      final fixtureId = payload['fixture_id']?.toString();
      final totalVotes = payload['total_votes'] as int?;
      final homeVotes = payload['home_votes'] as int?;
      final awayVotes = payload['away_votes'] as int?;
      final drawVotes = payload['draw_votes'] as int?;
      final userVote = payload['user_vote'] as String?;
      final userId = payload['user_id'] as String?;

      if (fixtureId == null || totalVotes == null) return;

      AppCache.applyUpdate(
        fixtureId: fixtureId,
        updateType: 'vote',
        value: totalVotes,
        extraData: {
          'homeVotes': homeVotes ?? 0,
          'awayVotes': awayVotes ?? 0,
          'drawVotes': drawVotes ?? 0,
        },
      );

      if (userVote != null && userId == widget.userId) {
        String frontendSelection;
        if (userVote == 'home') {
          frontendSelection = 'home_team';
        } else if (userVote == 'away') {
          frontendSelection = 'away_team';
        } else if (userVote == 'draw') {
          frontendSelection = 'draw';
        } else {
          frontendSelection = userVote;
        }

        _safeSetState(() {
          _userVotes[fixtureId] = frontendSelection;
        });
        AppCache.setUserVote(fixtureId, frontendSelection);
      }

      _safeSetState(() {
        if (_channelFixtureDataMap.containsKey(fixtureId)) {
          final existing = _channelFixtureDataMap[fixtureId]!;
          _channelFixtureDataMap[fixtureId] = ChannelFixtureData(
            fixtureId: existing.fixtureId,
            channelId: existing.channelId,
            matchName: existing.matchName,
            kickoffTime: existing.kickoffTime,
            status: existing.status,
            homeVotes: homeVotes ?? existing.homeVotes,
            awayVotes: awayVotes ?? existing.awayVotes,
            drawVotes: drawVotes ?? existing.drawVotes,
            lastMessage: existing.lastMessage,
            lastMessageAt: existing.lastMessageAt,
            lastSender: existing.lastSender,
            userVote: userVote ?? existing.userVote,
            commentCount: existing.commentCount,
            unreadCounts: existing.unreadCounts,
          );
        }
      });

      AppCache.notifyVotesChanged();
    });

    // ============================================================
    // 4. LIKE UPDATE
    // ============================================================
    ws.on('like', (payload) {
      final fixtureId = payload['fixture_id']?.toString();
      final totalLikes = payload['total_likes'] as int?;

      if (fixtureId != null && totalLikes != null) {
        _safeSetState(() {
          _likeStats[fixtureId] = LikeStatsResponse(
            fixtureId: fixtureId,
            totalLikes: totalLikes,
            userHasLiked: _userLikes[fixtureId] ?? false,
          );
        });

        final channelId = _localSelectedChannel?.channelId ??
            (_userChannels.isNotEmpty ? _userChannels.first.channelId : null);

        AppCache.applyUpdate(
          fixtureId: fixtureId,
          updateType: 'like',
          value: totalLikes,
          extraData: {
            'channelId': channelId,
            'liked': _userLikes[fixtureId] ?? false,
          },
        );
        AppCache.saveLikeCount(fixtureId, totalLikes);
      }
    });

    // ============================================================
    // 5. LATEST COMMENT UPDATE
    // ============================================================
    ws.on('latest.comment', (payload) {
      final fixtureId =
          payload['fixture_id']?.toString() ?? payload['fixtureId']?.toString();
      final commentText =
          payload['comment']?.toString() ?? payload['text']?.toString();
      final username = payload['username']?.toString() ?? 'Anonymous';
      final userId =
          payload['user_id']?.toString() ?? payload['userId']?.toString() ?? '';
      final selection = payload['selection']?.toString();
      final timestampStr = payload['timestamp']?.toString();

      if (fixtureId == null || commentText == null) return;

      _lastWebSocketLatestCommentUpdate[fixtureId] = DateTime.now();

      DateTime timestamp;
      try {
        timestamp = timestampStr != null
            ? DateTime.parse(timestampStr)
            : DateTime.now();
      } catch (e) {
        timestamp = DateTime.now();
      }

      final fixture = _fixtures.firstWhere(
        (f) => f.matchId == fixtureId,
        orElse: () => null as Fixture,
      );

      if (fixture != null) {
        _safeSetState(() {
          _featuredComments[fixtureId] = FeaturedComment(
            userId: userId,
            username: username,
            comment: commentText,
            teamSupport: _getTeamSupportForUser(selection, fixture),
            avatarUrl: '',
            timestamp: timestamp,
          );
        });

        AppCache.applyUpdate(
          fixtureId: fixtureId,
          updateType: 'latest_comment',
          value: 1,
          extraData: {
            'comment': commentText,
            'username': username,
            'selection': selection,
          },
        );
        AppCache.saveLatestComment(fixtureId, commentText, username);

        if (_channelFixtureDataMap.containsKey(fixtureId)) {
          final existing = _channelFixtureDataMap[fixtureId]!;
          _channelFixtureDataMap[fixtureId] = ChannelFixtureData(
            fixtureId: existing.fixtureId,
            channelId: existing.channelId,
            matchName: existing.matchName,
            kickoffTime: existing.kickoffTime,
            status: existing.status,
            homeVotes: existing.homeVotes,
            awayVotes: existing.awayVotes,
            drawVotes: existing.drawVotes,
            lastMessage: commentText,
            lastMessageAt: DateTime.now(),
            lastSender: username,
            userVote: existing.userVote,
            commentCount: existing.commentCount,
            unreadCounts: Map.from(existing.unreadCounts),
          );
          _saveChannelFixturesToCache(_channelFixtureDataMap);
        }

        _saveToGlobalCache();
      }
    });

    // ============================================================
    // 6. GOAL EVENT
    // ============================================================
    ws.on('goal', (payload) {
      final fixtureId = payload['fixture_id']?.toString();
      final homeScore = payload['home_score'] as int? ?? 0;
      final awayScore = payload['away_score'] as int? ?? 0;
      final minute = payload['minute'] as int? ?? 0;
      final minuteDisplay = payload['minute_display']?.toString() ?? "$minute'";
      final scorer = payload['scorer']?.toString() ?? 'Unknown';
      final team = payload['team']?.toString() ?? '';
      final timeElapsed =
          (payload['timeElapsed'] as num?)?.toDouble() ?? minute.toDouble();

      if (fixtureId == null) return;

      final index = _fixtures.indexWhere((f) => f.matchId == fixtureId);
      if (index != -1) {
        final oldFixture = _fixtures[index];
        _safeSetState(() {
          _fixtures[index] = Fixture(
            id: oldFixture.id,
            matchId: oldFixture.matchId,
            homeTeam: oldFixture.homeTeam,
            awayTeam: oldFixture.awayTeam,
            league: oldFixture.league,
            homeWin: oldFixture.homeWin,
            awayWin: oldFixture.awayWin,
            draw: oldFixture.draw,
            date: oldFixture.date,
            time: oldFixture.time,
            homeScore: homeScore,
            awayScore: awayScore,
            status: oldFixture.status,
            isLive: oldFixture.isLive,
            availableForVoting: oldFixture.availableForVoting,
            source: oldFixture.source,
            scrapedAt: oldFixture.scrapedAt,
            dateIso: oldFixture.dateIso,
            subFixtures: oldFixture.subFixtures,
            timeElapsed: timeElapsed,
          );
        });
      }

      final event = LiveEvent(
        id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
        eventType: 'goal',
        scorer: scorer,
        assist: payload['assist']?.toString(),
        player: null,
        team: team,
        minute: minute,
        minuteDisplay: minuteDisplay,
        homeScore: homeScore,
        awayScore: awayScore,
        timestamp: DateTime.now(),
      );

      _safeSetState(() {
        final events = _liveEvents[fixtureId] ?? [];
        _liveEvents[fixtureId] = [event, ...events].take(20).toList();
      });

      final style = _getCommentaryStyle('goal');
      final entry = LiveCommentaryEntry(
        text:
            "⚽ GOAL! $scorer scores at $minuteDisplay ${team == 'home' ? '🏠' : '✈️'}",
        type: 'goal',
        minute: minute,
        timestamp: DateTime.now(),
        color: style['color'] as Color,
        icon: style['icon'] as IconData,
        scorer: scorer,
        team: team,
      );
      _addCommentaryToWindow(fixtureId, entry);

      ToastHelper.showInfo("⚽ GOAL! $scorer scores at $minuteDisplay");
      _safeSetState(() {});
    });

    // ============================================================
    // 7. MATCH STATUS UPDATE
    // ============================================================

    ws.on('match.status', (payload) {
      final fixtureId = payload['fixture_id']?.toString();
      final status = payload['status']?.toString();
      final homeScore = payload['home_score'] as int?;
      final awayScore = payload['away_score'] as int?;
      final timeElapsed = (payload['timeElapsed'] as num?)?.toDouble();

      if (fixtureId == null || status == null) return;

      final bool isHalfTime = status == 'half_time' ||
          (timeElapsed != null && timeElapsed >= 44 && timeElapsed <= 46);

      final bool isFullTime = status == 'full_time' ||
          status == 'completed' ||
          (timeElapsed != null && timeElapsed >= 90);

      final index = _fixtures.indexWhere((f) => f.matchId == fixtureId);
      if (index != -1) {
        final oldFixture = _fixtures[index];
        _safeSetState(() {
          String displayStatus = status;
          if (isHalfTime) {
            displayStatus = 'half_time';
          } else if (isFullTime) {
            displayStatus = 'completed';
          }

          _fixtures[index] = Fixture(
            id: oldFixture.id,
            matchId: oldFixture.matchId,
            homeTeam: oldFixture.homeTeam,
            awayTeam: oldFixture.awayTeam,
            league: oldFixture.league,
            homeWin: oldFixture.homeWin,
            awayWin: oldFixture.awayWin,
            draw: oldFixture.draw,
            date: oldFixture.date,
            time: oldFixture.time,
            homeScore: homeScore ?? oldFixture.homeScore,
            awayScore: awayScore ?? oldFixture.awayScore,
            status: displayStatus,
            isLive: status == 'live' || status == 'half_time' || isHalfTime,
            availableForVoting: status == 'upcoming' || status == 'soon',
            source: oldFixture.source,
            scrapedAt: oldFixture.scrapedAt,
            dateIso: oldFixture.dateIso,
            subFixtures: oldFixture.subFixtures,
            timeElapsed: timeElapsed ?? oldFixture.timeElapsed,
          );
        });
      }

      if (isHalfTime) {
        _safeSetState(() {
          _liveCommentary.remove(fixtureId);
        });
        ToastHelper.showInfo('⏱️ Half Time');
        // ✅ Leave the room — no more live commentary needed until it resumes.
        final channelId = _localSelectedChannel?.channelId ??
            (_userChannels.isNotEmpty ? _userChannels.first.channelId : null);
        if (channelId != null)
          ws.leaveChannelFixtureRoom(channelId, fixtureId: fixtureId);
      } else if (isFullTime) {
        _safeSetState(() {
          _liveCommentary.remove(fixtureId);
        });
        ToastHelper.showInfo('🏁 Full Time!');
        final channelId = _localSelectedChannel?.channelId ??
            (_userChannels.isNotEmpty ? _userChannels.first.channelId : null);
        if (channelId != null)
          ws.leaveChannelFixtureRoom(channelId, fixtureId: fixtureId);
        _fetchFixtures(forceRefresh: true, showNotification: false);
      } else if (status == 'live') {
        // ✅ Fixture just went live (or resumed from HT) — join its room now.
        // This is the case _joinFixtureRooms() previously never covered: the
        // socket was already connected when this fixture transitioned to live,
        // so the one-time connectionStatus listener in _connectWebSocket()
        // never re-fires and this room would otherwise never be joined.
        final channelId = _localSelectedChannel?.channelId ??
            (_userChannels.isNotEmpty ? _userChannels.first.channelId : null);
        if (channelId != null)
          ws.joinChannelFixtureRoom(channelId, fixtureId: fixtureId);
        _refreshVoteDataForFixture(fixtureId);
        _refreshVotersDataForFixture(fixtureId);
        _fetchLiveEvents(fixtureId);
      }

      _safeSetState(() {});
    });

    // ============================================================
    // 8. CARD EVENT
    // ============================================================
    ws.on('card', (payload) {
      final fixtureId = payload['fixture_id']?.toString();
      final cardType = payload['card_type']?.toString();
      final player = payload['player']?.toString();
      final team = payload['team']?.toString();
      final minute = payload['minute'] as int? ?? 0;
      final timeElapsed =
          (payload['timeElapsed'] as num?)?.toDouble() ?? minute.toDouble();
      final minuteDisplay = payload['minute_display']?.toString() ?? "$minute'";

      if (fixtureId == null || player == null) return;

      final index = _fixtures.indexWhere((f) => f.matchId == fixtureId);
      if (index != -1) {
        final oldFixture = _fixtures[index];
        _safeSetState(() {
          _fixtures[index] = Fixture(
            id: oldFixture.id,
            matchId: oldFixture.matchId,
            homeTeam: oldFixture.homeTeam,
            awayTeam: oldFixture.awayTeam,
            league: oldFixture.league,
            homeWin: oldFixture.homeWin,
            awayWin: oldFixture.awayWin,
            draw: oldFixture.draw,
            date: oldFixture.date,
            time: oldFixture.time,
            homeScore: oldFixture.homeScore,
            awayScore: oldFixture.awayScore,
            status: oldFixture.status,
            isLive: oldFixture.isLive,
            availableForVoting: oldFixture.availableForVoting,
            source: oldFixture.source,
            scrapedAt: oldFixture.scrapedAt,
            dateIso: oldFixture.dateIso,
            subFixtures: oldFixture.subFixtures,
            timeElapsed: timeElapsed,
          );
        });
      }

      final event = LiveEvent(
        id: '${cardType}_${DateTime.now().millisecondsSinceEpoch}',
        eventType: cardType == 'yellow' ? 'yellow_card' : 'red_card',
        scorer: null,
        assist: null,
        player: player,
        team: team ?? '',
        minute: minute,
        minuteDisplay: minuteDisplay,
        homeScore: 0,
        awayScore: 0,
        timestamp: DateTime.now(),
      );

      _safeSetState(() {
        final events = _liveEvents[fixtureId] ?? [];
        _liveEvents[fixtureId] = [event, ...events].take(20).toList();
      });

      final style = _getCommentaryStyle(
          cardType == 'yellow' ? 'yellow_card' : 'red_card');
      final emoji = cardType == 'yellow' ? '🟨' : '🟥';
      final entry = LiveCommentaryEntry(
        text: "$emoji $cardType card! $player ($team) at $minuteDisplay",
        type: cardType == 'yellow' ? 'yellow_card' : 'red_card',
        minute: minute,
        timestamp: DateTime.now(),
        color: style['color'] as Color,
        icon: style['icon'] as IconData,
      );
      _addCommentaryToWindow(fixtureId, entry);

      _safeSetState(() {});
    });

    // ============================================================
    // 9. NEW LIVE EVENT
    // ============================================================
    ws.on('new.event', (payload) {
      final fixtureId = payload['fixture_id']?.toString();
      final eventData = payload['event'];

      if (fixtureId == null || eventData == null) return;

      final newEvent = LiveEvent.fromJson(eventData as Map<String, dynamic>);

      final timeElapsed = (eventData['timeElapsed'] as num?)?.toDouble();
      if (timeElapsed != null) {
        final index = _fixtures.indexWhere((f) => f.matchId == fixtureId);
        if (index != -1) {
          final old = _fixtures[index];
          _safeSetState(() {
            _fixtures[index] = Fixture(
              id: old.id,
              matchId: old.matchId,
              homeTeam: old.homeTeam,
              awayTeam: old.awayTeam,
              league: old.league,
              homeWin: old.homeWin,
              awayWin: old.awayWin,
              draw: old.draw,
              date: old.date,
              time: old.time,
              homeScore: old.homeScore,
              awayScore: old.awayScore,
              status: old.status,
              isLive: old.isLive,
              availableForVoting: old.availableForVoting,
              source: old.source,
              scrapedAt: old.scrapedAt,
              dateIso: old.dateIso,
              subFixtures: old.subFixtures,
              timeElapsed: timeElapsed,
            );
          });
        }
      }

      _safeSetState(() {
        final events = _liveEvents[fixtureId] ?? [];
        _liveEvents[fixtureId] = [newEvent, ...events].take(20).toList();
      });

      final style = _getCommentaryStyle(newEvent.eventType);
      final entry = LiveCommentaryEntry(
        text: newEvent.getDisplayText(),
        type: newEvent.eventType,
        minute: newEvent.minute,
        timestamp: newEvent.timestamp,
        color: style['color'] as Color,
        icon: style['icon'] as IconData,
        scorer: newEvent.scorer,
        team: newEvent.team,
      );
      _addCommentaryToWindow(fixtureId, entry);

      _safeSetState(() {});
    });

    // ============================================================
    // 10. COMMENTARY NEW
    // ============================================================
    ws.on('commentary.new', (payload) {
      final fixtureId = payload['fixture_id']?.toString();
      final entry = payload['entry'] ?? payload['payload'];

      if (fixtureId == null || entry == null) return;

      final minute = entry['minute'] as int? ?? 0;
      final text = entry['text'] as String? ?? '';
      final type = entry['type'] as String? ?? 'update';
      final createdAt = entry['createdAt'] != null
          ? DateTime.tryParse(entry['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now();

      final style = _getCommentaryStyle(type);
      final commentaryEntry = LiveCommentaryEntry(
        text: text,
        type: type,
        minute: minute,
        timestamp: createdAt,
        color: style['color'] as Color,
        icon: style['icon'] as IconData,
        scorer: entry['scorer'] as String?,
        team: entry['team'] as String?,
      );
      _addCommentaryToWindow(fixtureId, commentaryEntry);
      _safeSetState(() {});
    });

    // ============================================================
    // 11. COMMENTARY BULK
    // ============================================================
    ws.on('commentary.bulk', (payload) {
      final fixtureId = payload['fixture_id']?.toString();
      final entries = payload['entries'] ?? payload['payload'] ?? [];

      if (fixtureId == null || entries.isEmpty) return;

      for (var entryData in entries.reversed) {
        final minute = entryData['minute'] as int? ?? 0;
        final text = entryData['text'] as String? ?? '';
        final type = entryData['type'] as String? ?? 'update';
        final createdAt = entryData['createdAt'] != null
            ? DateTime.tryParse(entryData['createdAt'].toString()) ??
                DateTime.now()
            : DateTime.now();

        final style = _getCommentaryStyle(type);
        final entry = LiveCommentaryEntry(
          text: text,
          type: type,
          minute: minute,
          timestamp: createdAt,
          color: style['color'] as Color,
          icon: style['icon'] as IconData,
          scorer: entryData['scorer'] as String?,
          team: entryData['team'] as String?,
        );
        _addCommentaryToWindow(fixtureId, entry);
      }
      _safeSetState(() {});
    });

    // ============================================================
    // 12. MINUTE UPDATE
    // ============================================================
    ws.on('minute.update', (payload) {
      final fixtureId = payload['fixture_id']?.toString();
      final minute = (payload['minute'] as num?)?.toDouble() ?? 0.0;
      final minuteDisplay = payload['minute_display']?.toString() ?? "0'";
      final status = payload['status']?.toString() ?? 'live';

      if (fixtureId == null) return;

      final index = _fixtures.indexWhere((f) => f.matchId == fixtureId);
      if (index != -1) {
        final oldFixture = _fixtures[index];
        _safeSetState(() {
          String newStatus = oldFixture.status;
          bool isLive = oldFixture.isLive;

          if (status == 'half_time' || (minute >= 44 && minute <= 46)) {
            newStatus = 'half_time';
            isLive = true;
            _liveCommentary.remove(fixtureId);
          } else if (status == 'full_time' || minute >= 90) {
            newStatus = 'completed';
            isLive = false;
            _liveCommentary.remove(fixtureId);
          } else if (status == 'live' || status == 'injury_time') {
            newStatus = 'live';
            isLive = true;
          }

          _fixtures[index] = Fixture(
            id: oldFixture.id,
            matchId: oldFixture.matchId,
            homeTeam: oldFixture.homeTeam,
            awayTeam: oldFixture.awayTeam,
            league: oldFixture.league,
            homeWin: oldFixture.homeWin,
            awayWin: oldFixture.awayWin,
            draw: oldFixture.draw,
            date: oldFixture.date,
            time: oldFixture.time,
            homeScore: oldFixture.homeScore,
            awayScore: oldFixture.awayScore,
            status: newStatus,
            isLive: isLive,
            availableForVoting: oldFixture.availableForVoting,
            source: oldFixture.source,
            scrapedAt: oldFixture.scrapedAt,
            dateIso: oldFixture.dateIso,
            subFixtures: oldFixture.subFixtures,
            timeElapsed: minute,
          );
        });
      }

      if (status == 'half_time') {
        _addCommentaryToWindow(
            fixtureId,
            LiveCommentaryEntry(
              text: '⏱️ Half Time',
              type: 'half_time',
              minute: minute.toInt(),
              timestamp: DateTime.now(),
              color: Colors.orange,
              icon: Icons.timer_off_rounded,
            ));
      } else if (status == 'full_time' || minute >= 90) {
        _addCommentaryToWindow(
            fixtureId,
            LiveCommentaryEntry(
              text: '🏁 Full Time',
              type: 'full_time',
              minute: minute.toInt(),
              timestamp: DateTime.now(),
              color: Colors.red,
              icon: Icons.stop_circle_rounded,
            ));
      }

      _safeSetState(() {});
    });

    // ============================================================
    // 13. MINUTE RESPONSE
    // ============================================================
    ws.on('minute.response', (payload) {
      final fixtureId = payload['fixture_id']?.toString();
      final minute = (payload['minute'] as num?)?.toDouble() ?? 0.0;
      final minuteDisplay = payload['minute_display']?.toString() ?? "0'";
      final status = payload['status']?.toString() ?? 'upcoming';

      if (fixtureId == null) return;

      final index = _fixtures.indexWhere((f) => f.matchId == fixtureId);
      if (index != -1) {
        final oldFixture = _fixtures[index];
        _safeSetState(() {
          String newStatus = oldFixture.status;
          bool isLive = oldFixture.isLive;

          if (status == 'half_time' || (minute >= 44 && minute <= 46)) {
            newStatus = 'half_time';
            isLive = true;
          } else if (status == 'full_time' || minute >= 90) {
            newStatus = 'completed';
            isLive = false;
          } else if (status == 'live' || status == 'injury_time') {
            newStatus = 'live';
            isLive = true;
          }

          _fixtures[index] = Fixture(
            id: oldFixture.id,
            matchId: oldFixture.matchId,
            homeTeam: oldFixture.homeTeam,
            awayTeam: oldFixture.awayTeam,
            league: oldFixture.league,
            homeWin: oldFixture.homeWin,
            awayWin: oldFixture.awayWin,
            draw: oldFixture.draw,
            date: oldFixture.date,
            time: oldFixture.time,
            homeScore: oldFixture.homeScore,
            awayScore: oldFixture.awayScore,
            status: newStatus,
            isLive: isLive,
            availableForVoting: oldFixture.availableForVoting,
            source: oldFixture.source,
            scrapedAt: oldFixture.scrapedAt,
            dateIso: oldFixture.dateIso,
            subFixtures: oldFixture.subFixtures,
            timeElapsed: minute,
          );
        });
      }
      _safeSetState(() {});
    });

    // ============================================================
    // 14. PLEDGE UPDATE
    // ============================================================
    ws.on('pledge.update', (payload) async {
      final fixtureId = payload['fixture_id']?.toString();
      final totalPledges = payload['total_pledges'] as int?;
      final channelId = payload['channel_id']?.toString();

      if (fixtureId == null || totalPledges == null) return;

      _safeSetState(() {
        _pledgeCounts[fixtureId] = totalPledges;
      });

      AppCache.applyUpdate(
        fixtureId: fixtureId,
        updateType: 'pledge',
        value: totalPledges,
        extraData: {'channelId': channelId},
      );

      if (_channelFixtureDataMap.containsKey(fixtureId)) {
        final existing = _channelFixtureDataMap[fixtureId]!;
        _channelFixtureDataMap[fixtureId] = ChannelFixtureData(
          fixtureId: existing.fixtureId,
          channelId: existing.channelId,
          matchName: existing.matchName,
          kickoffTime: existing.kickoffTime,
          status: existing.status,
          homeVotes: existing.homeVotes,
          awayVotes: existing.awayVotes,
          drawVotes: existing.drawVotes,
          lastMessage: existing.lastMessage,
          lastMessageAt: existing.lastMessageAt,
          lastSender: existing.lastSender,
          userVote: existing.userVote,
          commentCount: existing.commentCount,
          unreadCounts: Map.from(existing.unreadCounts),
        );
        _saveChannelFixturesToCache(_channelFixtureDataMap);
      }

      await _refreshPledgeDataForFixture(fixtureId);
      _saveToGlobalCache();
      _safeSetState(() {});
    });

    // ============================================================
    // 15. BET UPDATE
    // ============================================================
    ws.on('bet.update', (payload) async {
      final fixtureId = payload['fixture_id']?.toString();
      final totalBets = payload['total_bets'] as int?;
      final channelId = payload['channel_id']?.toString();

      if (fixtureId == null || totalBets == null) return;

      AppCache.applyUpdate(
        fixtureId: fixtureId,
        updateType: 'bet',
        value: totalBets,
        extraData: {'channelId': channelId},
      );

      await _refreshBettorsForFixture(fixtureId);
      _saveToGlobalCache();
      _safeSetState(() {});
    });

    // ============================================================
    // 16. JOIN APPROVED
    // ============================================================
    ws.on('join_approved', (payload) {
      final channelId = payload['channel_id']?.toString();
      final channelName = payload['channel_name']?.toString() ?? 'Unknown';
      final message =
          payload['message']?.toString() ?? 'You have been added to the group';
      final userId = payload['user_id']?.toString();

      if (channelId == null) return;
      if (userId != null && userId != widget.userId) return;

      _removePendingJoinRequest(channelId);
      _loadUserChannels();
      _safeSetState(() {});

      AppCache.channels = List.from(_userChannels);
      AppCache.saveChannels(_userChannels);

      if (mounted) {
        ToastHelper.showSuccess('You joined "$channelName" 🎉');
        _refreshAllData();
      }
    });

    // ============================================================
    // 17. JOIN REJECTED
    // ============================================================
    ws.on('join_rejected', (payload) {
      final channelId = payload['channel_id']?.toString();
      final channelName = payload['channel_name']?.toString() ?? 'Unknown';
      final reason = payload['reason']?.toString() ?? 'No reason provided';
      final userId = payload['user_id']?.toString();

      if (channelId == null) return;
      if (userId != null && userId != widget.userId) return;

      _removePendingJoinRequest(channelId);

      if (mounted) {
        ToastHelper.showWarning('Join request to "$channelName" was declined');
      }
    });

    // ============================================================
    // 18. ERROR HANDLER
    // ============================================================
    ws.on('error', (payload) {
      final error = payload['message']?.toString() ?? 'Unknown error';
      debugPrint('❌ WebSocket error: $error');
      if (mounted) {
        ToastHelper.showError('WebSocket error: $error');
      }
    });
  }

  /// Single source of truth for "which channel is fixture X currently in".
  /// Every place that reads or writes fixture-scoped data (comments, votes,
  /// pledges, chat) must resolve through this — never re-implement the ladder.
  String? _resolveChannelIdFor(String fixtureId) {
    String? channelId = widget.selectedChannelId;
    channelId ??= _fixtureChannelOverrides[fixtureId]?.channelId;
    channelId ??= _localSelectedChannel?.channelId;
    channelId ??=
        _userChannels.isNotEmpty ? _userChannels.first.channelId : null;
    return channelId;
  }

  bool _isValidPhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final regex = RegExp(r'^(0|254)?[7-9][0-9]{8}$');
    return regex.hasMatch(cleaned);
  }

  Future<String> _getUserPhoneForPayment() async {
    // Try saved topup phone first
    final saved = await _getSavedPhone('topup');
    if (saved != null && saved.isNotEmpty && _isValidPhoneNumber(saved)) {
      return saved;
    }

    // Fallback: fetch from user profile
    try {
      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/auth/user/id/${widget.userId}'),
            headers: await _buildHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final phone = data['user']['phone']?.toString() ?? '';
          if (phone.isNotEmpty && _isValidPhoneNumber(phone)) {
            return phone;
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching phone: $e');
    }
    return '';
  }

// 11b. Join approved
  void _handleJoinApproved(Map<String, dynamic> data) {
    final channelId = data['channel_id']?.toString();
    final channelName = data['channel_name']?.toString() ?? 'Unknown';
    final message =
        data['message']?.toString() ?? 'You have been added to the group';
    final userId = data['user_id']?.toString();

    if (channelId == null) return;
    if (userId != null && userId != widget.userId) return;

    debugPrint('✅ Join approved: $channelName');

    _onJoinApproved(channelId, channelName, message);
  }

// 11c. Join rejected
  void _handleJoinRejected(Map<String, dynamic> data) {
    final channelId = data['channel_id']?.toString();
    final channelName = data['channel_name']?.toString() ?? 'Unknown';
    final reason = data['reason']?.toString() ?? 'No reason provided';
    final userId = data['user_id']?.toString();

    if (channelId == null) return;
    if (userId != null && userId != widget.userId) return;

    debugPrint('❌ Join rejected: $channelName - $reason');

    _onJoinRejected(channelId, channelName, reason);
  }

  void _handleJoinResponse(Map<String, dynamic> data) {
    final channelId = data['channel_id']?.toString();
    final approved = data['approved'] as bool?;
    final message = data['message']?.toString() ?? '';
    final channelName = data['channel_name']?.toString() ?? 'Unknown';
    final userId = data['user_id']?.toString();

    if (channelId == null) return;
    if (userId != null && userId != widget.userId)
      return; // Only handle our own requests

    debugPrint(
        '📨 Join response: channel=$channelId, approved=$approved, message=$message');

    // Remove from pending
    _removePendingJoinRequest(channelId);

    if (approved == true) {
      // Successfully joined
      _onJoinApproved(channelId, channelName);
    } else {
      // Request was declined
      _onJoinRejected(channelId, channelName, message);
    }
  }

// 11d. Join request status update
  void _handleJoinRequestStatus(Map<String, dynamic> data) {
    final channelId = data['channel_id']?.toString();
    final status =
        data['status']?.toString(); // 'pending', 'approved', 'rejected'
    final channelName = data['channel_name']?.toString() ?? 'Unknown';
    final userId = data['user_id']?.toString();

    if (channelId == null) return;
    if (userId != null && userId != widget.userId) return;

    debugPrint('📨 Join request status: $status for $channelName');

    switch (status) {
      case 'pending':
        // Still pending - ensure it's in the list
        if (!_pendingJoinRequests.contains(channelId)) {
          _addPendingJoinRequest(channelId);
        }
        ToastHelper.showInfo(
            'Your request to join "$channelName" is still pending...');
        break;

      case 'approved':
        _onJoinApproved(channelId, channelName);
        break;

      case 'rejected':
        final reason = data['reason']?.toString() ?? 'No reason provided';
        _onJoinRejected(channelId, channelName, reason);
        break;

      default:
        debugPrint('⚠️ Unknown join status: $status');
    }
  }

// 11e. New join request received (for admins)
  void _handleJoinRequestReceived(Map<String, dynamic> data) {
    final channelId = data['channel_id']?.toString();
    final channelName = data['channel_name']?.toString() ?? 'Unknown';
    final requesterId = data['requester_id']?.toString();
    final requesterName = data['requester_name']?.toString() ?? 'Someone';

    if (channelId == null || requesterId == null) return;

    debugPrint('📨 New join request from $requesterName for $channelName');

    // Show notification for admins
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📥 $requesterName wants to join "$channelName"'),
          backgroundColor: FanColors.primary,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.white,
            onPressed: () {
              // Navigate to admin dashboard or show request details
              _showAdminDashboardForChannel(channelId);
            },
          ),
        ),
      );
    }
  }

// 11f. Join request processed (admin processed a request)
  void _handleJoinRequestProcessed(Map<String, dynamic> data) {
    final channelId = data['channel_id']?.toString();
    final channelName = data['channel_name']?.toString() ?? 'Unknown';
    final userId = data['user_id']?.toString();
    final approved = data['approved'] as bool?;
    final message = data['message']?.toString() ?? '';

    if (channelId == null) return;
    if (userId != null && userId != widget.userId) return;

    debugPrint('📨 Join request processed: $channelName, approved=$approved');

    // Remove from pending
    _removePendingJoinRequest(channelId);

    if (approved == true) {
      _onJoinApproved(channelId, channelName, message);
    } else {
      _onJoinRejected(channelId, channelName, message);
    }
  }

// ============================================================================
// HELPER METHODS FOR JOIN HANDLERS
// ============================================================================

  void _onJoinApproved(String channelId, String channelName,
      [String? message]) {
    // Remove from pending
    _removePendingJoinRequest(channelId);

    // Refresh channels
    _loadUserChannels();
    _safeSetState(() {});

    // Update AppCache
    AppCache.channels = List.from(_userChannels);
    AppCache.saveChannels(_userChannels);

    if (mounted) {
      ToastHelper.showSuccess('You joined "$channelName" 🎉');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${message ?? 'You joined "$channelName"'}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Refresh the page to show new channel
      _refreshAllData();
    }

    debugPrint('✅ User joined channel: $channelName');
  }

  void _onJoinRejected(String channelId, String channelName, String reason) {
    // Remove from pending
    _removePendingJoinRequest(channelId);

    if (mounted) {
      ToastHelper.showWarning('Join request to "$channelName" was declined');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('❌ Request to join "$channelName" was declined: $reason'),
          backgroundColor: FanColors.away,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    debugPrint('❌ User rejected from channel: $channelName - $reason');
  }

  void _showAdminDashboardForChannel(String channelId) {
    // Find the channel
    final channel = _userChannels.firstWhere(
      (c) => c.channelId == channelId,
      orElse: () => null as UserChannel,
    );

    if (channel == null) {
      ToastHelper.showError('Channel not found');
      return;
    }

    // Open admin dashboard with the specific channel
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AdminDashboardModal(
        isOpen: true,
        onClose: () => Navigator.pop(context),
        userId: widget.userId,
        username: widget.username,
        authToken: widget.authToken,
        userChannels: [channel],
        pendingJoinCount: _pendingJoinRequests.length,
      ),
    );
  }
// ============================================================================
// PENDING REQUESTS MANAGEMENT
// ============================================================================

  void _addPendingJoinRequest(String channelId) {
    setState(() {
      _pendingJoinRequests.add(channelId);
    });
    _savePendingJoinRequests();
    debugPrint('✅ Added pending request: $channelId');
  }

  void _removePendingJoinRequest(String channelId) {
    setState(() {
      _pendingJoinRequests.remove(channelId);
    });
    _savePendingJoinRequests();
    debugPrint('✅ Removed pending request: $channelId');
  }

  Future<void> _savePendingJoinRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'pending_join_requests_${widget.userId}',
        _pendingJoinRequests.toList(),
      );
      debugPrint(
          '✅ Saved ${_pendingJoinRequests.length} pending join requests');
    } catch (e) {
      debugPrint('⚠️ Error saving pending requests: $e');
    }
  }

// ============================================================================
// EXISTING HANDLERS (Keep these as they are)
// ============================================================================

  void _handleMatchStatusUpdate(Map<String, dynamic> payload) {
    final fixtureId = payload['fixture_id']?.toString();
    final status = payload['status']?.toString();
    final homeScore = payload['home_score'] as int?;
    final awayScore = payload['away_score'] as int?;
    final timeElapsed = (payload['timeElapsed'] as num?)?.toDouble();

    if (fixtureId == null || status == null) return;

    // ✅ Check for half-time using status OR timeElapsed
    final bool isHalfTime = status == 'half_time' ||
        (timeElapsed != null && timeElapsed >= 44 && timeElapsed <= 46);

    final bool isFullTime =
        status == 'full_time' || (timeElapsed != null && timeElapsed >= 90);

    debugPrint(
        '📺 MATCH STATUS UPDATE: $fixtureId → $status (time: $timeElapsed)');

    _safeSetState(() {
      final index = _fixtures.indexWhere((f) => f.matchId == fixtureId);
      if (index != -1) {
        final oldFixture = _fixtures[index];

        // ✅ Determine display status
        String displayStatus = status;
        if (isHalfTime) {
          displayStatus = 'half_time';
        } else if (isFullTime) {
          displayStatus = 'completed';
        }

        _fixtures[index] = Fixture(
          id: oldFixture.id,
          matchId: oldFixture.matchId,
          homeTeam: oldFixture.homeTeam,
          awayTeam: oldFixture.awayTeam,
          league: oldFixture.league,
          homeWin: oldFixture.homeWin,
          awayWin: oldFixture.awayWin,
          draw: oldFixture.draw,
          date: oldFixture.date,
          time: oldFixture.time,
          homeScore: homeScore ?? oldFixture.homeScore,
          awayScore: awayScore ?? oldFixture.awayScore,
          status: displayStatus,
          isLive: status == 'live' || status == 'half_time' || isHalfTime,
          availableForVoting: status == 'upcoming' || status == 'soon',
          source: oldFixture.source,
          scrapedAt: oldFixture.scrapedAt,
          dateIso: oldFixture.dateIso,
          subFixtures: oldFixture.subFixtures,
          timeElapsed: timeElapsed ?? oldFixture.timeElapsed,
        );
      }
    });

    // ✅ Handle half-time specifically - switch to comments
    if (isHalfTime) {
      ToastHelper.showInfo('⏱️ Half Time');
      // Force refresh to show comments instead of live commentary
      _safeSetState(() {});
    } else if (isFullTime) {
      ToastHelper.showInfo('🏁 Full Time!');
      _fetchFixtures(forceRefresh: true, showNotification: false);
    }
  }

  void _handleHalfTimeState(String fixtureId) {
    // ✅ Clear live commentary for this fixture to force showing comments
    _safeSetState(() {
      _liveCommentary.remove(fixtureId);
    });

    // ✅ Refresh the fixture to show comments
    final fixture = _fixtures.firstWhere((f) => f.matchId == fixtureId);
    if (fixture != null) {
      _generateFeaturedCommentForFixture(fixture);
    }

    _safeSetState(() {});
  }

  void _handleGoalEvent(Map<String, dynamic> payload) {
    final fixtureId = payload['fixture_id']?.toString();
    final homeScore = payload['home_score'] as int? ?? 0;
    final awayScore = payload['away_score'] as int? ?? 0;
    final minute = payload['minute'] as int? ?? 0;
    final minuteDisplay = payload['minute_display']?.toString() ?? "$minute'";
    final scorer = payload['scorer']?.toString() ?? 'Unknown';
    final team = payload['team']?.toString() ?? '';

    // ✅ EXTRACT timeElapsed
    final timeElapsed =
        (payload['timeElapsed'] as num?)?.toDouble() ?? minute.toDouble();

    if (fixtureId != null) {
      // Update fixture with new score and time
      final index = _fixtures.indexWhere((f) => f.matchId == fixtureId);
      if (index != -1) {
        final oldFixture = _fixtures[index];
        _safeSetState(() {
          _fixtures[index] = Fixture(
            id: oldFixture.id,
            matchId: oldFixture.matchId,
            homeTeam: oldFixture.homeTeam,
            awayTeam: oldFixture.awayTeam,
            league: oldFixture.league,
            homeWin: oldFixture.homeWin,
            awayWin: oldFixture.awayWin,
            draw: oldFixture.draw,
            date: oldFixture.date,
            time: oldFixture.time,
            homeScore: homeScore,
            awayScore: awayScore,
            status: oldFixture.status,
            isLive: oldFixture.isLive,
            availableForVoting: oldFixture.availableForVoting,
            source: oldFixture.source,
            scrapedAt: oldFixture.scrapedAt,
            dateIso: oldFixture.dateIso,
            subFixtures: oldFixture.subFixtures,
            // ✅ UPDATE TIME
            timeElapsed: timeElapsed,
          );
        });
      }

      // Add to live events
      final event = LiveEvent(
        id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
        eventType: 'goal',
        scorer: scorer,
        assist: payload['assist']?.toString(),
        player: null,
        team: team,
        minute: minute,
        minuteDisplay: minuteDisplay,
        homeScore: homeScore,
        awayScore: awayScore,
        timestamp: DateTime.now(),
      );

      _safeSetState(() {
        final events = _liveEvents[fixtureId] ?? [];
        _liveEvents[fixtureId] = [event, ...events].take(20).toList();
      });

      // Add to commentary window
      final style = _getCommentaryStyle('goal');
      final entry = LiveCommentaryEntry(
        text:
            "⚽ GOAL! $scorer scores at $minuteDisplay ${team == 'home' ? '🏠' : '✈️'}",
        type: 'goal',
        minute: minute,
        timestamp: DateTime.now(),
        color: style['color'] as Color,
        icon: style['icon'] as IconData,
        scorer: scorer,
        team: team,
      );
      _addCommentaryToWindow(fixtureId, entry);

      ToastHelper.showInfo("⚽ GOAL! $scorer scores at $minuteDisplay");
    }
  }

  void _handleCardEvent(Map<String, dynamic> payload) {
    final fixtureId = payload['fixture_id']?.toString();
    final cardType = payload['card_type']?.toString();
    final player = payload['player']?.toString();
    final team = payload['team']?.toString();
    final minute = payload['minute'] as int? ?? 0;

    // ✅ EXTRACT timeElapsed
    final timeElapsed =
        (payload['timeElapsed'] as num?)?.toDouble() ?? minute.toDouble();
    final minuteDisplay = payload['minute_display']?.toString() ?? "$minute'";

    if (fixtureId != null && player != null) {
      // Update fixture time
      final index = _fixtures.indexWhere((f) => f.matchId == fixtureId);
      if (index != -1) {
        final oldFixture = _fixtures[index];
        _safeSetState(() {
          _fixtures[index] = Fixture(
            id: oldFixture.id,
            matchId: oldFixture.matchId,
            homeTeam: oldFixture.homeTeam,
            awayTeam: oldFixture.awayTeam,
            league: oldFixture.league,
            homeWin: oldFixture.homeWin,
            awayWin: oldFixture.awayWin,
            draw: oldFixture.draw,
            date: oldFixture.date,
            time: oldFixture.time,
            homeScore: oldFixture.homeScore,
            awayScore: oldFixture.awayScore,
            status: oldFixture.status,
            isLive: oldFixture.isLive,
            availableForVoting: oldFixture.availableForVoting,
            source: oldFixture.source,
            scrapedAt: oldFixture.scrapedAt,
            dateIso: oldFixture.dateIso,
            subFixtures: oldFixture.subFixtures,
            // ✅ UPDATE TIME
            timeElapsed: timeElapsed,
          );
        });
      }

      final event = LiveEvent(
        id: '${cardType}_${DateTime.now().millisecondsSinceEpoch}',
        eventType: cardType == 'yellow' ? 'yellow_card' : 'red_card',
        scorer: null,
        assist: null,
        player: player,
        team: team ?? '',
        minute: minute,
        minuteDisplay: minuteDisplay,
        homeScore: 0,
        awayScore: 0,
        timestamp: DateTime.now(),
      );

      _safeSetState(() {
        final events = _liveEvents[fixtureId] ?? [];
        _liveEvents[fixtureId] = [event, ...events].take(20).toList();
      });

      // Add to commentary window
      final style = _getCommentaryStyle(
          cardType == 'yellow' ? 'yellow_card' : 'red_card');
      final emoji = cardType == 'yellow' ? '🟨' : '🟥';
      final entry = LiveCommentaryEntry(
        text: "$emoji $cardType card! $player ($team) at $minuteDisplay",
        type: cardType == 'yellow' ? 'yellow_card' : 'red_card',
        minute: minute,
        timestamp: DateTime.now(),
        color: style['color'] as Color,
        icon: style['icon'] as IconData,
      );
      _addCommentaryToWindow(fixtureId, entry);
    }
  }
// ✅ New method to handle 'chat.message' from backend

// ✅ Add this helper method
  Future<void> _saveCommentsToDisk(String fixtureId) async {
    final comments = _fixtureComments[fixtureId];
    if (comments != null && comments.isNotEmpty) {
      await LocalStorageManager.saveCommentsForFixture(fixtureId, comments);
      debugPrint(
          '💾 Saved ${comments.length} comments to disk for fixture $fixtureId');
    }
  }

  void _handleNewCommentFromWebSocket(Map<String, dynamic> payload) {
    // Parse payload - support both nested and flat structures
    final fixtureId =
        payload['fixtureId']?.toString() ?? payload['fixture_id']?.toString();
    final comment =
        payload['message']?.toString() ?? payload['text']?.toString();
    final username =
        payload['username']?.toString() ?? payload['sender_name']?.toString();
    final selection = payload['selection']?.toString();
    final userId =
        payload['fromUserId']?.toString() ?? payload['sender_id']?.toString();
    final messageId =
        payload['messageId']?.toString() ?? payload['message_id']?.toString();
    final tempId = payload['tempId']?.toString();

    if (fixtureId == null || comment == null || userId == null) {
      debugPrint('⚠️ Incomplete WebSocket comment payload: $payload');
      return;
    }

    // Check if this is our own message being confirmed
    if (tempId != null && tempId.isNotEmpty) {
      final pendingIndex =
          _fixtureComments[fixtureId]?.indexWhere((c) => c.id == tempId) ?? -1;
      if (pendingIndex != -1) {
        // This is our own message being confirmed - update with real ID
        final realId = messageId ?? tempId;
        _safeSetState(() {
          final comments = _fixtureComments[fixtureId]!;
          comments[pendingIndex] = FixtureComment(
            id: realId,
            userId: userId,
            username: username ?? 'Anonymous', // ✅ Provide default value
            fixtureId: fixtureId,
            comment: comment,
            selection: selection,
            timestamp: DateTime.now(),
          );
        });
        _saveCommentsToDisk(fixtureId);
        debugPrint('✅ Own message confirmed: $realId');
        return;
      }
    }

    // Skip if it's from us (already handled optimistically)
    if (userId == widget.userId) {
      debugPrint('ℹ️ Skipping own comment from WebSocket');
      return;
    }

    // Check for duplicate comments by ID
    final existingComments = _fixtureComments[fixtureId] ?? [];
    if (messageId != null && existingComments.any((c) => c.id == messageId)) {
      debugPrint('⚠️ Duplicate comment skipped: $messageId');
      return;
    }

    // Also check by content + userId within last 5 seconds
    final now = DateTime.now();
    final recentDuplicate = existingComments.any((c) =>
        c.userId == userId &&
        c.comment == comment &&
        now.difference(c.timestamp).inSeconds < 5);

    if (recentDuplicate) {
      debugPrint('⚠️ Recent duplicate comment skipped (by content)');
      return;
    }

    debugPrint(
        '💬 New comment from WebSocket for fixture: $fixtureId from $username');

    final newComment = FixtureComment(
      id: messageId ??
          'ws_${DateTime.now().millisecondsSinceEpoch}_${userId.hashCode}',
      userId: userId,
      username: username ?? 'Anonymous',
      fixtureId: fixtureId,
      comment: comment,
      selection: selection,
      timestamp: DateTime.now(),
    );

    _safeSetState(() {
      if (!_fixtureComments.containsKey(fixtureId)) {
        _fixtureComments[fixtureId] = [];
      }
      _fixtureComments[fixtureId]!.insert(0, newComment);
      _commentCounts[fixtureId] = (_commentCounts[fixtureId] ?? 0) + 1;

      final currentUnread = _unreadCounts[fixtureId] ?? 0;
      _unreadCounts[fixtureId] = currentUnread + 1;
    });

    _startPulsingAnimation(fixtureId);

    // Regenerate featured comment
    final fixture = _fixtures.firstWhere(
      (f) => f.matchId == fixtureId,
      orElse: () => null as Fixture,
    );
    if (fixture != null) {
      _generateFeaturedCommentForFixture(fixture);
    }

    _saveCommentsToDisk(fixtureId);
    _saveToGlobalCache();

    // Update channel fixture data cache
    if (_channelFixtureDataMap.containsKey(fixtureId)) {
      final existing = _channelFixtureDataMap[fixtureId]!;
      _channelFixtureDataMap[fixtureId] = ChannelFixtureData(
        fixtureId: existing.fixtureId,
        channelId: existing.channelId,
        matchName: existing.matchName,
        kickoffTime: existing.kickoffTime,
        status: existing.status,
        homeVotes: existing.homeVotes,
        awayVotes: existing.awayVotes,
        drawVotes: existing.drawVotes,
        lastMessage: comment,
        lastMessageAt: DateTime.now(),
        lastSender: username,
        userVote: existing.userVote,
        commentCount: (_commentCounts[fixtureId] ?? 0),
        unreadCounts: Map.from(existing.unreadCounts),
      );
      _saveChannelFixturesToCache(_channelFixtureDataMap);
    }

    debugPrint('✅ Comment added to cache for fixture $fixtureId');
  }

  Future<void> _loadInitialBadgeCounts() async {
    try {
      debugPrint('📊 Loading initial badge counts from NotificationService...');

      // Get all unread data from NotificationService
      final unreadData = await NotificationService.getAllUnreadData();

      debugPrint(
        '📊 Found ${unreadData.length} fixtures with unread notifications',
      );

      for (var entry in unreadData.entries) {
        final fixtureId = entry.key;
        final count = entry.value['count'] ?? 0;

        if (count > 0) {
          _safeSetState(() {
            _unreadCounts[fixtureId] = count;
          });
          _startPulsingAnimation(fixtureId);
          debugPrint(
            '🔔 Loaded initial unread count: $count for fixture $fixtureId',
          );
        }
      }

      // Also get total unread count for debugging
      final totalUnread = await NotificationService.getTotalUnreadCount();
      debugPrint(
        '📊 Total unread notifications across all fixtures: $totalUnread',
      );
    } catch (e) {
      debugPrint('⚠️ Error loading initial badge counts: $e');
    }
  }

  Future<bool> _processVote(
      Fixture fixture, String selection, int index) async {
    final fixtureId = fixture.matchId;

    String backendSelection = selection;
    if (selection == "home_team") {
      backendSelection = "home";
    } else if (selection == "away_team") {
      backendSelection = "away";
    } else if (selection == "draw") {
      backendSelection = "draw";
    }

    _safeSetState(() => _loadingVote[fixtureId] = true);

    try {
      final result = await VoteService.castVote(
        fixtureId: fixtureId,
        userId: widget.userId,
        username: widget.username,
        selection: backendSelection,
        authToken: widget.authToken,
      );

      if (result['success'] == true) {
        // ✅ UPDATE LOCAL STATE
        _safeSetState(() {
          _userVotes[fixtureId] = selection;
          _voteCounts[fixtureId] = (_voteCounts[fixtureId] ?? 0) + 1;
        });

        // ✅ UPDATE APPCACHE - SHARED ACROSS ALL SCREENS
        AppCache.setUserVote(fixtureId, selection);

        // ✅ UPDATE APPCACHE VOTE COUNT
        AppCache.applyUpdate(
          fixtureId: fixtureId,
          updateType: 'vote',
          value: _voteCounts[fixtureId] ?? 0,
          extraData: {
            'channelId': _localSelectedChannel?.channelId ?? '',
            'homeVotes': _homeVotesForFixture(fixtureId),
            'awayVotes': _awayVotesForFixture(fixtureId),
            'drawVotes': _drawVotesForFixture(fixtureId),
          },
        );
        await AppCache.saveVoteCount(fixtureId, _voteCounts[fixtureId] ?? 0);
        await AppCache.saveUserVotes();

        ToastHelper.showSuccess('Vote submitted successfully!');

        // ✅ SEND VIA WEBSOCKET FOR OTHER DEVICES
        final ws = WebSocketService();
        if (ws.isConnected) {
          ws.send('vote.update', {
            'fixture_id': fixtureId,
            'user_id': widget.userId,
            'user_vote': backendSelection,
            'home_votes': _homeVotesForFixture(fixtureId),
            'away_votes': _awayVotesForFixture(fixtureId),
            'draw_votes': _drawVotesForFixture(fixtureId),
            'channel_id': _localSelectedChannel?.channelId ?? '',
          });
          debugPrint('📤 Vote update sent via WebSocket');
        }

        // ✅ NOTIFY APPCACHE LISTENERS
        AppCache.notifyVotesChanged();

        // ✅ REFRESH DATA
        _refreshVotersDataForFixture(fixtureId);
        _refreshVoteDataForFixture(fixtureId);

        // ✅ SAVE TO DISK CACHE
        _saveToGlobalCache();

        return true;
      } else if (result['message']?.contains('already voted') == true) {
        ToastHelper.showWarning('You have already voted for this fixture');
        await _fetchUserVotesFromBackend();
        return true;
      } else {
        ToastHelper.showError(result['message'] ?? 'Failed to submit vote');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error voting: $e');
      ToastHelper.showError('Network error: ${e.toString()}');
      return false;
    } finally {
      _safeSetState(() => _loadingVote[fixtureId] = false);
    }
  }

  // Replace sequential with parallel

// Add helper to check if cache needs refresh

  // ========== DISPOSE ==========
  @override
  void dispose() {
    // ✅ Cancel AppCache subscription
    FanTheme.controller.removeListener(_onThemeChanged);
    _appCacheSubscription?.cancel();
    _appCacheSubscription = null;
    _appCacheVotesSubscription?.cancel(); // ✅ Cancel votes subscription
    _appCacheVotesSubscription = null;
    _threeMinRefreshTimer?.cancel();
    _backgroundTeardownTimer?.cancel();

    // Disconnect WebSocket
    final ws = WebSocketService();
    ws.disconnect();
    _wsConnected = false;

    // Cancel FCM subscription
    _fcmBadgeSubscription?.cancel();
    _fcmBadgeSubscription = null;

    // Remove auth listener
    _authService.removeListener(_onAuthStateChanged);

    // Remove widget binding observer
    WidgetsBinding.instance.removeObserver(this);

    // Mark as disposed
    _isDisposed = true;

    // Cancel all timers
    _searchController.dispose();
    _syncTimer?.cancel();
    _cachePollingTimer?.cancel();
    _refreshDebounceTimer?.cancel();

    // Dispose all comment controllers
    for (var controller in _commentControllers.values) {
      controller.dispose();
    }

    // Dispose all badge animation controllers
    for (var controller in _badgeTimers.values) {
      controller.dispose();
    }
    _badgeTimers.clear();
    _badgeScaleAnimations.clear();
    _commentaryPollTimer?.cancel();
    _commentPollTimer?.cancel(); // ✅ ADD THIS

    super.dispose();
  }

  void _handleBadgeUpdate(Map<String, dynamic> event) {
    debugPrint('🔔 FixturesPage received badge event: $event');

    final type = event['type'] as String?;
    final fixtureId = event['fixture_id'] as String?;
    final totalUnread = event['total_unread'] as int?;

    // Handle comment badge update (from NotificationService)
    if (type == 'comment_badge_update' && fixtureId != null) {
      final newCount =
          totalUnread ?? (event['total_unread_comments'] as int? ?? 1);
      _safeSetState(() {
        final currentCount = _unreadCounts[fixtureId] ?? 0;
        _unreadCounts[fixtureId] = currentCount + 1;
        debugPrint(
          '🔔 Updated unread count for $fixtureId: ${_unreadCounts[fixtureId]}',
        );
      });
      _startPulsingAnimation(fixtureId);
      _refreshVotersDataForFixture(fixtureId);
      _refreshVoteDataForFixture(fixtureId);
    }

    // Handle badge cleared
    if (type == 'comment_badge_cleared' && fixtureId != null) {
      _safeSetState(() {
        _unreadCounts[fixtureId] = 0;
        debugPrint('🔔 Cleared unread count for $fixtureId');
      });
      _stopPulsingAnimation(fixtureId);
    }

    // Handle all comments cleared
    if (type == 'comment_badge_cleared_all') {
      _safeSetState(() {
        _unreadCounts.clear();
        debugPrint('🔔 Cleared ALL unread counts');
      });
      // Stop all animations
      for (var controller in _badgeTimers.values) {
        controller.dispose();
      }
      _badgeTimers.clear();
    }
  }

  Future<void> _refreshVoteDataForFixture(String fixtureId) async {
    try {
      debugPrint('🔄 Refreshing vote data for fixture $fixtureId');

      final String? channelId = _resolveChannelIdFor(fixtureId);

      if (channelId == null) {
        debugPrint(
            '⚠️ No channelId available, skipping vote refresh for $fixtureId');
        return;
      }

      await _fetchVoteCountViaHttp(fixtureId, channelId: channelId);

      debugPrint(
          '✅ Refreshed vote count for fixture $fixtureId: ${_voteCounts[fixtureId]}');
    } catch (e) {
      debugPrint('❌ Error refreshing vote data: $e');
    }
  }
  // ========== ADD THIS METHOD TO REFRESH VOTE DATA FOR A FIXTURE ==========

  void _showLoginModal() {
    Navigator.of(context).popUntil((route) => route.isFirst);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LoginModal(
        messengerKey: messengerKey,
        onLoginSuccess: (String userId, String username) async {
          Navigator.pop(context);
          ToastHelper.showInfo('Loading your data...');

          // ✅ Force a complete refresh with proper ordering
          await _forceCompleteRefresh();

          ToastHelper.showSuccess('Welcome back, $username!');
        },
      ),
    );
  }

// Add this new method
  Future<void> _forceCompleteRefresh() async {
    debugPrint('🔄 FORCE COMPLETE REFRESH STARTED');

    _safeSetState(() => _refreshing = true);

    try {
      // Fetch fresh fixtures
      await _fetchFixtures(forceRefresh: true, showNotification: false);

      // ✅ Sync votes (compare backend vs local, update if different)
      await _syncVotesWithBackend();

      // Refresh other data
      await _fetchUserLikesFromBackend();
      await _fetchAllComments(forceRefresh: true);
      await _fetchSubFixtureVotesForAll();
      await _fetchUserComrades();
      await _fetchAllComradesWithProfiles();

      _saveToGlobalCache();
      _safeSetState(() {});

      debugPrint('✅ Force refresh complete - ${_userVotes.length} votes');
    } catch (e) {
      debugPrint('❌ Force refresh error: $e');
    } finally {
      _safeSetState(() => _refreshing = false);
    }
  }

  Future<void> _syncVotesWithBackend() async {
    if (!_isUserLoggedIn()) return;

    debugPrint('🔄 Syncing votes with backend...');

    // 1. Fetch from backend (source of truth)
    final backendVotes = await VoteService.fetchUserVotesGlobal(widget.userId);

    // 2. Load from local storage
    final localVotes =
        await LocalStorageManager.loadVotesForUser(widget.userId);

    // 3. Compare
    bool hasChanges = false;

    // Check for new votes or changed votes
    for (var entry in backendVotes.entries) {
      if (localVotes[entry.key] != entry.value) {
        debugPrint(
            '🔄 Vote changed: ${entry.key} -> ${entry.value} (was: ${localVotes[entry.key]})');
        hasChanges = true;
        break;
      }
    }

    // Check for deleted votes
    for (var entry in localVotes.entries) {
      if (!backendVotes.containsKey(entry.key)) {
        debugPrint('🔄 Vote removed: ${entry.key}');
        hasChanges = true;
        break;
      }
    }

    // 4. Update if changed
    if (hasChanges) {
      debugPrint('✅ Updating local storage and UI with backend votes');

      // Update local storage
      for (var entry in backendVotes.entries) {
        await LocalStorageManager.saveVote(
            widget.userId, entry.key, entry.value);
      }

      // Update UI
      _safeSetState(() {
        _userVotes.clear();
        _userVotes.addAll(backendVotes);
      });

      _saveToGlobalCache();
    } else {
      debugPrint('✅ Votes match - no update needed');
    }
  }

  void _loadFromGlobalCache() {
    // Load fixtures
    if (_cache.fixtures != null) {
      _fixtures = List.from(_cache.fixtures!);
    }

    // Load user votes
    if (_cache.userVotes != null) {
      _userVotes.addAll(_cache.userVotes!);
    }

    // Load fixture vote data
    if (_cache.fixtureVoteData != null) {
      _fixtureVoteData.addAll(_cache.fixtureVoteData!);
    }

    // ✅ Load comments from cache (for offline display)
    if (_cache.comments != null) {
      _fixtureComments.addAll(_cache.comments!);
    }

    // Load sub-fixture data
    if (_cache.subFixtureData != null) {
      _subFixtureVoteData.addAll(_cache.subFixtureData!);
    }

    // Load user likes
    if (_cache.userLikes != null) {
      _userLikes.addAll(_cache.userLikes!);
    }

    // Load like stats
    if (_cache.likeStats != null) {
      _likeStats.addAll(_cache.likeStats!);
    }

    // Load vote stats
    if (_cache.voteStats != null) {
      _voteStats.addAll(_cache.voteStats!);
    }

    // Load game metadata
    if (_cache.gameMetadata != null) {
      _gameMetadata.addAll(_cache.gameMetadata!);
    }

    // Load sub fixtures
    if (_cache.subFixtures != null) {
      _fixtureSubFixtures.addAll(_cache.subFixtures!);
    }

    // Load commenters
    if (_cache.commenters != null) {
      _fixtureCommenters.addAll(_cache.commenters!);
    }

    // Load notifications
    if (_cache.notifications != null) {
      _fixtureNotifications.addAll(_cache.notifications!);
    }

    // Load comrades
    if (_cache.userComrades != null) {
      _userComrades = Set.from(_cache.userComrades!);
    }
    if (_cache.comradeVoters != null) {
      _comradeVoters.addAll(_cache.comradeVoters!);
    }

    // Load unread counts
    if (_cache.unreadCounts != null) {
      _unreadCounts.addAll(_cache.unreadCounts!);
      for (var entry in _unreadCounts.entries) {
        if (entry.value > 0) {
          _startPulsingAnimation(entry.key);
        }
      }
    }

    // ❌ DO NOT load _commentCounts from cache - will come from WebSocket

    // Initialize comment counts as empty (will be populated by WebSocket)
    _commentCounts.clear();

    // Initialize UI controllers and states
    for (var fixture in _fixtures) {
      final fixtureId = fixture.matchId;
      _commentControllers.putIfAbsent(fixtureId, () => TextEditingController());
      _showingRivals.putIfAbsent(fixtureId, () => false);
      _showingSupporters.putIfAbsent(fixtureId, () => false);
      _showingAllComments.putIfAbsent(fixtureId, () => false);
      _subFixturesExpanded.putIfAbsent(fixtureId, () => false);
    }

    _safeSetState(() {
      _loading = false;
    });

    // Generate featured comments from cached comments (if any)
    for (var fixture in _fixtures) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _generateFeaturedCommentForFixture(fixture);
      });
    }

    _ensureMockSubFixtures();

    debugPrint('📦 Loaded from global cache:');
    debugPrint('   Fixtures: ${_fixtures.length}');
    debugPrint(
        '   Comments: ${_fixtureComments.length} fixture(s) have cached comments');
    debugPrint('   ❌ Comment counts NOT loaded - waiting for WebSocket');

    // If cache is old, refresh in background
    if (!_cache.isCacheValid) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          debugPrint('🔄 Cache is stale, refreshing in background...');
          _fetchFixtures(forceRefresh: true, showNotification: false);
        }
      });
    }
  }

  Future<void> _sendNotificationSafe({
    required String userId,
    required String notificationType,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      debugPrint('📤 Sending "$notificationType" notification to $userId');
      final success = await NotificationService.sendNotification(
        userId: userId,
        notificationType: notificationType,
        title: title,
        body: body,
        data: data,
      );
      if (success) {
        debugPrint('✅ Notification delivered to $userId');
      } else {
        debugPrint('❌ Notification FAILED for $userId (returned false)');
      }
    } catch (e) {
      debugPrint('❌ Notification exception for $userId: $e');
    }
  }

  void _ensureMockSubFixtures() {
    if (_fixtures.isNotEmpty) {
      bool needsUpdate = false;
      for (var fixture in _fixtures) {
        if (fixture.subFixtures.isEmpty) {
          fixture.subFixtures = [
            SubFixture(
              id: 'goal_${fixture.matchId}',
              parentFixtureId: fixture.matchId,
              type: SubFixtureType.firstGoal,
              format: SubFixtureFormat.threeWay,
              question: 'Who scores first?',
              optionA: fixture.homeTeam,
              optionB: fixture.awayTeam,
              optionC: 'No Goal',
              oddsA: 2.10,
              oddsB: 2.30,
              oddsC: 8.00,
              isActive: true,
              displayOrder: 1,
              icon: Icons.sports_soccer,
            ),
            SubFixture(
              id: 'yellow_${fixture.matchId}',
              parentFixtureId: fixture.matchId,
              type: SubFixtureType.firstYellowCard,
              format: SubFixtureFormat.threeWay,
              question: 'Who gets first yellow card?',
              optionA: fixture.homeTeam,
              optionB: fixture.awayTeam,
              optionC: 'No Card',
              oddsA: 2.20,
              oddsB: 2.20,
              oddsC: 5.00,
              isActive: true,
              displayOrder: 2,
              icon: Icons.warning_amber_rounded,
            ),
            SubFixture(
              id: 'corner_${fixture.matchId}',
              parentFixtureId: fixture.matchId,
              type: SubFixtureType.firstCorner,
              format: SubFixtureFormat.teamVsTeam,
              question: 'Who gets first corner?',
              optionA: fixture.homeTeam,
              optionB: fixture.awayTeam,
              oddsA: 1.95,
              oddsB: 1.95,
              isActive: true,
              displayOrder: 3,
              icon: Icons.flag,
            ),
            SubFixture(
              id: 'offside_${fixture.matchId}',
              parentFixtureId: fixture.matchId,
              type: SubFixtureType.firstOffside,
              format: SubFixtureFormat.teamVsTeam,
              question: 'Who gets first offside?',
              optionA: fixture.homeTeam,
              optionB: fixture.awayTeam,
              oddsA: 2.10,
              oddsB: 2.20,
              isActive: true,
              displayOrder: 4,
              icon: Icons.outlined_flag,
            ),
          ];
          _fixtureSubFixtures[fixture.matchId] = fixture.subFixtures;
          needsUpdate = true;
        }
      }
      if (needsUpdate) {
        _saveToGlobalCache();
        _safeSetState(() {});
      }
    }
  }

  Future<void> _fetchUserVotesFromBackend() async {
    if (!_isUserLoggedIn()) return;

    try {
      // ✅ Use the fast check endpoint (from fixtures.voters)
      // Since we're using fixture-based voting, we need to check each fixture
      // or use a batch endpoint if available

      // Option 1: Check each fixture individually (slower but works)
      for (var fixture in _fixtures) {
        final result = await VoteService.checkUserVoted(
          fixture.matchId,
          widget.userId,
        );
        if (result['has_voted'] == true && result['selection'] != null) {
          _safeSetState(() {
            _userVotes[fixture.matchId] = result['selection'];
          });
          // Save to local storage
          await LocalStorageManager.saveVote(
            widget.userId,
            fixture.matchId,
            result['selection'],
          );
        }
      }

      debugPrint('✅ Loaded ${_userVotes.length} user votes from backend');
    } catch (e) {
      debugPrint('❌ Error fetching user votes: $e');
    }
  }

  void _updateFixtureVoteDataWithUserVotes() {
    if (!_isUserLoggedIn()) return;

    for (var fixtureId in _userVotes.keys) {
      final userSelection = _userVotes[fixtureId];
      if (userSelection != null && _fixtureVoteData.containsKey(fixtureId)) {
        final currentData = _fixtureVoteData[fixtureId]!;
        _fixtureVoteData[fixtureId] = currentData.copyWith(
          currentUserSelection: userSelection,
        );
      }
    }
    if (mounted) setState(() {});
  }
  // In FixturesPageState

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Force refresh when tab becomes visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _appLifecycleState == AppLifecycleState.resumed) {
        // Check if we need to refresh
        _checkAndRefreshOnVisibility();
      }
    });
  }

  void _checkAndRefreshOnVisibility() async {
    // Don't refresh too frequently
    final now = DateTime.now();
    if (_lastTabVisibleRefresh != null &&
        now.difference(_lastTabVisibleRefresh!) < const Duration(seconds: 30)) {
      return;
    }
    _lastTabVisibleRefresh = now;

    // Refresh in background
    _fetchFixtures(forceRefresh: true, showNotification: false);
  }

  DateTime? _lastBackgroundRefreshTime;
  static const Duration _backgroundRefreshThrottle = Duration(seconds: 30);

 Timer? _backgroundTeardownTimer;
static const Duration _teardownDelay = Duration(seconds: 1800);

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  switch (state) {
    case AppLifecycleState.resumed:
      _handleResume();
      break;
    case AppLifecycleState.paused:
      _backgroundTeardownTimer?.cancel();
      _backgroundTeardownTimer = Timer(_teardownDelay, _handlePause);
      break;
    case AppLifecycleState.inactive:
    case AppLifecycleState.detached:
    case AppLifecycleState.hidden:
      // Transient — no teardown, no refetch.
      break;
  }
}



void _handleResume() {
  // Cancel any pending pause teardown — we never actually left long enough
  // for it to have fired, so there's nothing to undo.
  _backgroundTeardownTimer?.cancel();
  _backgroundTeardownTimer = null;

  if (!_isBackgroundPaused) {
    // We were never actually paused (only briefly inactive) — nothing to
    // resume, and critically, no need to refetch anything.
    debugPrint('▶️ Resumed without having paused - skipping refresh');
    return;
  }

  // Throttle rapid resume/pause cycles
  final now = DateTime.now();
  if (_lastResumeTime != null &&
      now.difference(_lastResumeTime!) < _resumeThrottle) {
    debugPrint('⏭️ Resume throttled - too soon');
    return;
  }
  _lastResumeTime = now;

  debugPrint('▶️ App resumed - refreshing data');

  _isBackgroundPaused = false;
  MemoryManager().onForeground();

  _startBackgroundRefreshTimer();

  // ✅ Only hit the network if data is actually stale, instead of always
  // refetching. Mirrors the staleness gate _fetchFixtures already has.
  final isStale = _lastCommentFetchTime == null ||
      now.difference(_lastCommentFetchTime!) > const Duration(minutes: 2);
  if (isStale) {
    _refreshDataWithTimeout();
  } else {
    debugPrint('⏭️ Data still fresh (${now.difference(_lastCommentFetchTime!).inSeconds}s old) - skipping refetch');
  }

  if (_isUserLoggedIn() && !_wsConnected) {
    _connectWebSocket();
  }
}

  @override
  void initState() {
    super.initState();
    _setupLifecycle();
    _initializeData();
  }

  void _setupLifecycle() {
    WidgetsBinding.instance.addObserver(this);
    _authService = AuthService();
    _authService.addListener(_onAuthStateChanged);
  }

  void _initializeData() {
    // Load from memory cache instantly
    if (AppCache.isLoaded) {
      _loadFromAppCache();
    }

    // Defer network calls
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDeferredData();
    });
  }

  /// Loads deferred data after the first frame is painted
void _loadDeferredData() {
  // Load channels
  _loadUserChannels();
  
  // Load pending join requests
  _loadPendingJoinRequests();
  
  // Load saved unread statuses
  _loadSavedUnreadStatuses();
  
  // Load comrades if logged in
  if (_isUserLoggedIn()) {
    _fetchUserComrades();
    _fetchAllComradesWithProfiles();
  }
  
  // Setup FCM listeners
  _setupFCMListeners();
  
  // Check visibility
  _checkAndStoreVisibility();
  
  // Start background refresh timer
  _startBackgroundRefreshTimer();
  
  // Start WebSocket after data is ready
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _isUserLoggedIn()) {
      _connectWebSocket();
      _setupWebSocketListeners();
      _loadSavedUnreadStatuses();
    }
  });
  
  // Initialize live commentary after fixtures are loaded
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeLiveCommentary();
  });
}

  void _restartPolling({bool isBackground = false}) {
    _cachePollingTimer?.cancel();

    final interval =
        isBackground ? _backgroundPollingInterval : _pollingInterval;

    _cachePollingTimer = Timer.periodic(interval, (_) {
      if (!_loading &&
          !_refreshing &&
          mounted &&
          _appLifecycleState == AppLifecycleState.resumed) {
        _backgroundRefresh();
      }
    });
  }

  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) setState(fn);
  }

  Future<Map<String, String>> _buildHeaders({bool forceRefresh = false}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (widget.authToken != null && widget.authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${widget.authToken}';
    } else {
      final token = await LocalStorageManager.getAuthToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    // ✅ IMPORTANT: When forceRefresh is true, add no-cache header
    if (forceRefresh) {
      headers['Cache-Control'] = 'no-cache, no-store, must-revalidate';
      headers['Pragma'] = 'no-cache';
    } else {
      headers['Cache-Control'] = 'max-age=300';
    }

    return headers;
  }

  Future<void> _saveFixturesToCache(
    List<Fixture> fixtures, {
    String? etag,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = fixtures.map((f) => f.toJson()).toList();
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await prefs.setString(_cacheKey, jsonEncode(jsonList));
      await prefs.setInt(_timestampKey, timestamp);

      if (etag != null && etag.isNotEmpty) {
        await prefs.setString(_etagKey, etag);
        _lastEtag = etag;
      }

      _lastCacheTimestamp = timestamp;
      debugPrint('✅ Saved ${fixtures.length} fixtures to cache');
    } catch (e) {
      debugPrint('❌ Error saving fixtures to cache: $e');
    }
  }

  Future<void> _loadCachedData() async {
    try {
      final results = await Future.wait([
        //LocalStorageManager.loadVotesForUser(widget.userId),
        LocalStorageManager.loadSubFixtureVotesForUser(widget.userId),
        LocalStorageManager.loadLikesForUser(widget.userId),
        LocalStorageManager.loadUserGameMetadata(widget.userId),
        LocalStorageManager.loadFixturesFromCache(),
        LocalStorageManager.loadCommenters(),
        LocalStorageManager.loadFixtureNotifications(),
        // NEW: Load comrades from local storage
        LocalStorageManager.loadUserComrades(),
        LocalStorageManager.loadComradeVoters(),
      ]);

      final votes = results[0] as Map<String, String>;
      final subFixtureVotes = results[1] as Map<String, String>;
      final likes = results[2] as Set<String>;
      final metadata = results[3] as List<GameMetadata>;
      final cachedFixtures = results[4] as List<Fixture>?;
      final savedCommenters = results[5] as Map<String, Map<String, String>>;
      final savedNotifications =
          results[6] as Map<String, FixtureNotificationState>;
      // NEW: Load comrades
      final loadedUserComrades = results[7] as Set<String>;
      final loadedComradeVoters =
          results[8] as Map<String, List<ComradeWithProfile>>;

      _safeSetState(() {
        _userVotes.clear();
        _userVotes.addAll(votes);
        _userLikes.clear();
        for (var fixtureId in likes) {
          _userLikes[fixtureId] = true;
        }
        _gameMetadata.clear();
        for (var m in metadata) {
          _gameMetadata[m.fixtureId] = m;
        }
        _fixtureCommenters.clear();
        _fixtureCommenters.addAll(savedCommenters);
        _fixtureNotifications.clear();
        _fixtureNotifications.addAll(savedNotifications);

        // NEW: Load comrades into state
        _userComrades.clear();
        _userComrades.addAll(loadedUserComrades);
        _comradeVoters.clear();
        _comradeVoters.addAll(loadedComradeVoters);
      });

      debugPrint(
        '📦 Loaded local data: ${votes.length} votes, '
        '${subFixtureVotes.length} sub-fixture votes, ${likes.length} likes, '
        '${savedCommenters.length} commenters, ${savedNotifications.length} notifications, '
        '${_userComrades.length} comrades, ${_comradeVoters.length} comrade voters',
      );

      if (cachedFixtures != null && cachedFixtures.isNotEmpty) {
        cachedFixtures.sort((a, b) {
          final aKey = '${a.dateIso}_${a.time}';
          final bKey = '${b.dateIso}_${b.time}';
          return aKey.compareTo(bKey);
        });

        _safeSetState(() {
          _fixtures = cachedFixtures;
          _loading = false;
        });

        // Initialize all fixture-specific maps
        for (var fixture in cachedFixtures) {
          final fixtureId = fixture.matchId;
          _commentControllers.putIfAbsent(
            fixtureId,
            () => TextEditingController(),
          );
          _showingRivals.putIfAbsent(fixtureId, () => false);
          _showingSupporters.putIfAbsent(fixtureId, () => false);
          _showingAllComments.putIfAbsent(fixtureId, () => false);
          _subFixturesExpanded[fixtureId] = false; // Initialize expanded state
        }

        _ensureMockSubFixtures();

        for (var fixture in cachedFixtures) {
          await _generateFeaturedCommentForFixture(fixture);
        }

        _saveToGlobalCache();
        debugPrint('✅ Loaded ${cachedFixtures.length} fixtures from cache');

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Future.wait([
              _fetchVotes().catchError(
                (e) => debugPrint('Vote fetch error: $e'),
              ),
              _fetchUserLikesFromBackend().catchError(
                (e) => debugPrint('Likes fetch error: $e'),
              ),
              _fetchAllComments().catchError(
                (e) => debugPrint('Comments fetch error: $e'),
              ),
              _fetchSubFixtureVotesForAll().catchError(
                (e) => debugPrint('Sub-fixture votes error: $e'),
              ),
              // NEW: Refresh comrades in background
              _fetchUserComrades().catchError(
                (e) => debugPrint('Comrades fetch error: $e'),
              ),
              _fetchAllComradesWithProfiles().catchError(
                (e) => debugPrint('Comrade voters fetch error: $e'),
              ),
            ]);
          }
        });

        return;
      }

      debugPrint('🔄 No valid cache found, fetching from API...');
      await _fetchFixtures(forceRefresh: false);
    } catch (e) {
      debugPrint('❌ Error in _loadCachedData: $e');
      if (_fixtures.isEmpty) {
        await _fetchFixtures(forceRefresh: false);
      }
    }
  }

  bool _haveFixturesChanged(List<Fixture> newFixtures) {
    if (_fixtures.length != newFixtures.length) return true;
    for (int i = 0; i < min(_fixtures.length, 5); i++) {
      if (_fixtures[i].matchId != newFixtures[i].matchId) return true;
    }
    return false;
  }

  Future<void> _fetchAllComments({bool forceRefresh = false}) async {
    if (_fixtures.isEmpty) return;

    try {
      final headers = await _buildHeaders();
      final channelId = _localSelectedChannel?.channelId ??
          (_userChannels.isNotEmpty ? _userChannels.first.channelId : null);

      if (channelId == null) {
        debugPrint('⚠️ No channelId available for fetching comments');
        return;
      }

      // Batch all HTTP requests in parallel
      final List<Future<http.Response>> requests = [];
      for (var fixture in _fixtures) {
        // ✅ FIXED: channel_id must be a path segment (/:channel_id/messages),
        // not a query param — the router only registers the path-based route,
        // so the old query-param URL 404'd on every call, leaving
        // _fixtureComments/_commentCounts empty despite messages existing in Mongo.
        requests.add(http
            .get(
              Uri.parse(
                  '$API_BASE_URL/channels/$channelId/messages?fixture_id=${fixture.matchId}&limit=100'),
              headers: headers,
            )
            .timeout(REQUEST_TIMEOUT));
      }

      final List<http.Response> responses = await Future.wait(requests);

      final List<Future> saveFutures = [];

      for (int i = 0; i < responses.length; i++) {
        final response = responses[i];
        final fixture = _fixtures[i];

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          final messagesList = jsonData['messages'] ?? [];

          final List<FixtureComment> comments = [];
          for (var item in messagesList) {
            if (item is Map) {
              String id = item['message_id'] ?? '';
              if (id.isEmpty) {
                final idObj = item['_id'];
                if (idObj is Map && idObj['\$oid'] != null) {
                  id = idObj['\$oid'];
                }
              }

              final comment = FixtureComment(
                id: id,
                userId: item['sender_id']?.toString() ?? '',
                username: item['sender_name']?.toString() ?? 'Anonymous',
                fixtureId: fixture.matchId,
                comment: item['text']?.toString() ?? '',
                selection: item['selection']?.toString(),
                timestamp: DateTime.parse(item['sent_at']?['\$date'] ??
                    item['sent_at']?.toString() ??
                    DateTime.now().toIso8601String()),
              );
              comments.add(comment);
            }
          }
          comments.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          _safeSetState(() {
            _fixtureComments[fixture.matchId] = comments;
            _commentCounts[fixture.matchId] = comments.length;
          });

          saveFutures.add(LocalStorageManager.saveCommentsForFixture(
              fixture.matchId, comments));
        }
      }

      await Future.wait(saveFutures);
      _saveToGlobalCache();
      _lastCommentFetchTime = DateTime.now();

      // Regenerate featured comments after loading real comments
      for (var fixture in _fixtures) {
        await _generateFeaturedCommentForFixture(fixture);
      }

      _safeSetState(() {});
      debugPrint('✅ Fetched and cached comments for all fixtures');
    } catch (e) {
      debugPrint('❌ Error in _fetchAllComments: $e');
    }
  }

  static Future<List<FixtureComment>> fetchCommentsForFixture(
    String fixtureId, {
    int limit = 100,
    String? authToken,
    String? channelId,
    bool forceRefresh = false,
  }) async {
    final cached = await LocalStorageManager.loadCommentsForFixture(fixtureId);

    final lastFetched =
        await LocalStorageManager.getCommentsLastFetched(fixtureId);
    final cacheAge = lastFetched != null
        ? DateTime.now().millisecondsSinceEpoch - lastFetched
        : 999999999;
    final isCacheStale = cacheAge > const Duration(minutes: 2).inMilliseconds;

    if (!forceRefresh && !isCacheStale && cached.isNotEmpty) {
      debugPrint('📦 Returning ${cached.length} cached comments');
      return cached;
    }

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      if (channelId == null) return cached;

      // ============================================================
      // UPDATED: Use chat endpoint
      // ============================================================
      final response = await http
          .get(
            Uri.parse(
                '$API_BASE_URL/channels/$channelId/messages?fixture_id=$fixtureId&limit=100'),
            headers: headers,
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final messagesList = jsonData['messages'] ?? [];

        final List<FixtureComment> freshComments = [];
        for (var item in messagesList) {
          if (item is Map) {
            String id = item['message_id'] ?? '';
            if (id.isEmpty) {
              final idObj = item['_id'];
              if (idObj is Map && idObj['\$oid'] != null) {
                id = idObj['\$oid'];
              }
            }

            freshComments.add(FixtureComment(
              id: id,
              userId: item['sender_id']?.toString() ?? '',
              username: item['sender_name']?.toString() ?? 'Anonymous',
              fixtureId: fixtureId,
              comment: item['text']?.toString() ?? '',
              selection: item['selection']?.toString(),
              timestamp: DateTime.parse(item['sent_at']?['\$date'] ??
                  item['sent_at']?.toString() ??
                  DateTime.now().toIso8601String()),
            ));
          }
        }

        freshComments.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        await LocalStorageManager.saveCommentsForFixture(
            fixtureId, freshComments);
        return freshComments;
      }
      return cached;
    } catch (e) {
      debugPrint('❌ Error fetching comments: $e — returning cache');
      return cached;
    }
  }

  Future<void> _fetchVotes() async {
    if (_loadingVotes) return;

    _safeSetState(() => _loadingVotes = true);

    try {
      if (_fixtures.isEmpty) {
        _safeSetState(() => _loadingVotes = false);
        return;
      }

      final String? channelId = _localSelectedChannel?.channelId ??
          (_userChannels.isNotEmpty ? _userChannels.first.channelId : null);

      if (channelId == null) {
        debugPrint('⚠️ No channelId available, skipping vote fetch');
        _safeSetState(() => _loadingVotes = false);
        return;
      }

      // Same per-fixture, channel-scoped pattern as pledges —
      // one call per fixture instead of a global batch endpoint
      for (var fixture in _fixtures) {
        final overrideChannelId =
            _fixtureChannelOverrides[fixture.matchId]?.channelId ?? channelId;
        await _fetchVoteCountViaHttp(fixture.matchId,
            channelId: overrideChannelId);
      }

      if (_isUserLoggedIn()) {
        unawaited(_fetchUserVotesFromBackend());
      }

      _saveToGlobalCache();
      debugPrint(
          '✅ Fetched channel-scoped vote counts for ${_fixtures.length} fixtures');
    } catch (e) {
      debugPrint('❌ Error loading vote counts: $e');
    } finally {
      _safeSetState(() => _loadingVotes = false);
    }
  }

  Future<void> _fetchSubFixtureVotesForAll() async {
    final List<String> fixtureIds = _fixtureSubFixtures.keys.toList();
    if (fixtureIds.isEmpty) return;

    // BATCH ALL SUB-FIXTURE VOTE FETCHES
    await Future.wait(fixtureIds
        .map((fixtureId) => _fetchSubFixtureVotesForFixture(fixtureId)));

    _saveToGlobalCache();
  }

  Future<void> _fetchSubFixtureVotesForFixture(String fixtureId) async {
    try {
      final allVotes = await VoteService.fetchSubFixtureVotes(fixtureId);
      final subFixtures = _fixtureSubFixtures[fixtureId] ?? [];

      final Map<String, SubFixtureVoteData> voteData = {};
      final savedVotes = await LocalStorageManager.loadSubFixtureVotesForUser(
        widget.userId,
      );

      for (var subFixture in subFixtures) {
        final data = VoteService.organizeSubFixtureVotes(
          allVotes,
          widget.userId,
          subFixture,
        );

        if (data.currentUserSelection == null &&
            savedVotes.containsKey(subFixture.id)) {
          voteData[subFixture.id] = SubFixtureVoteData(
            subFixtureId: data.subFixtureId,
            question: data.question,
            voteCounts: data.voteCounts,
            currentUserSelection: savedVotes[subFixture.id],
            supporters: data.supporters,
            rivals: data.rivals,
          );
        } else {
          voteData[subFixture.id] = data;
        }
      }

      _safeSetState(() => _subFixtureVoteData[fixtureId] = voteData);
      debugPrint('✅ Loaded sub-fixture votes for fixture $fixtureId');
    } catch (e) {
      debugPrint('❌ Error fetching sub-fixture votes for $fixtureId: $e');
    }
  }

  Future<void> _fetchUserLikesFromBackend() async {
    try {
      final headers = await _buildHeaders();

      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/votes/likes/user/${widget.userId}'),
            headers: headers,
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        _safeSetState(() => _userLikes.clear());

        if (jsonData is Map &&
            jsonData['success'] == true &&
            jsonData['data'] != null) {
          final data = jsonData['data'];
          if (data is List) {
            for (var item in data) {
              if (item is Map) {
                final fixtureId = item['fixtureId']?.toString() ?? '';
                final hasLiked = item['liked'] ?? false;
                if (fixtureId.isNotEmpty) {
                  _safeSetState(() => _userLikes[fixtureId] = hasLiked);
                }
              }
            }
          }
        }
        _saveToGlobalCache();
        debugPrint('✅ Loaded ${_userLikes.length} likes from backend');
      } else if (response.statusCode == 401) {
        debugPrint('⚠️ Authentication failed when loading likes');
        ToastHelper.showError('Please log in again to see your likes');
      } else {
        debugPrint('⚠️ Error loading likes: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ Error loading likes: $e');
    }
  }

  bool _wsConnected = false;

  // ============================================================
// REPLACE THIS ENTIRE METHOD
// ============================================================
  // ============================================================
// COMPLETE _fetchFixtures METHOD
// ============================================================
  // ============================================================
// COMPLETE _fetchFixtures METHOD
// ============================================================
  Future<void> _fetchFixtures({
    bool forceRefresh = false,
    bool showNotification = false,
  }) async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      // ✅ Always hit the backend. Frequency is already controlled by
      // the polling timer (_pollingInterval / _backgroundPollingInterval)
      // and WebSocket push updates — the old SharedPreferences staleness
      // gate was reading a desynced timestamp and silently skipping
      // real fetches, which is why fixtures could go stale for weeks.
      debugPrint(
        forceRefresh
            ? '🔄 FORCE REFRESH - fetching from backend...'
            : '🔄 Scheduled/background refresh - fetching from backend...',
      );
      await _fetchFixturesFromBackend();
    } catch (e) {
      debugPrint('❌ Error in _fetchFixtures: $e');
    } finally {
      _isFetching = false;
    }
  }

// ============================================================
// ADD/REPLACE THIS METHOD
// ============================================================
  // ============================================================
// COMPLETE _fetchFixturesFromBackend METHOD
// ============================================================
  // ============================================================
// COMPLETE _fetchFixturesFromBackend METHOD
// ============================================================

// ✅ NEW: Separate method for backend fetch

  Future<void> _refreshAllData() async {
    await Future.wait([
      _fetchFixtures(forceRefresh: true, showNotification: true),
      _fetchVotes(),
      _fetchUserLikesFromBackend(),
      _fetchAllComments(),
      _fetchSubFixtureVotesForAll(),
    ]);
  }

  // ============================================================
// COMPLETE _fetchFixturesFromBackend METHOD
// ============================================================
  Future<void> _fetchFixturesFromBackend() async {
    debugPrint('🌐 FETCHING FROM BACKEND API...');

    try {
      final headers = await _buildHeaders(forceRefresh: true);
      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/games'),
            headers: headers,
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        List<Fixture> fixtures = [];

        if (jsonData is Map<String, dynamic>) {
          if (jsonData['success'] == true && jsonData['data'] is List) {
            fixtures = _parseFixtures(jsonData['data'] as List);
          } else if (jsonData.containsKey('fixtures') &&
              jsonData['fixtures'] is List) {
            fixtures = _parseFixtures(jsonData['fixtures'] as List);
          }
        } else if (jsonData is List) {
          fixtures = _parseFixtures(jsonData);
        }

        // ✅ FILTER OUT COMPLETED GAMES
        fixtures = fixtures
            .where((f) => f.status != 'completed' && f.status != 'finished')
            .toList();

        if (fixtures.isNotEmpty) {
          fixtures.sort((a, b) {
            final aKey = '${a.dateIso}_${a.time}';
            final bKey = '${b.dateIso}_${b.time}';
            return aKey.compareTo(bKey);
          });

          _safeSetState(() {
            _fixtures = fixtures;
            _error = '';
            _loading = false;
          });

          _saveToGlobalCache();
          await _saveFixturesToCache(fixtures);

          AppCache.fixtures = List.from(fixtures);
          AppCache.notifyFixturesChanged();
          await AppCache.saveFixtures(fixtures);

          for (var fixture in fixtures) {
            final fixtureId = fixture.matchId;
            _commentControllers.putIfAbsent(
                fixtureId, () => TextEditingController());
            _showingRivals.putIfAbsent(fixtureId, () => false);
            _showingSupporters.putIfAbsent(fixtureId, () => false);
            _showingAllComments.putIfAbsent(fixtureId, () => false);
          }

          _ensureMockSubFixtures();

          for (var fixture in fixtures) {
            await _generateFeaturedCommentForFixture(fixture);
          }

          // ✅ REFRESH PLEDGE DATA - SILENTLY (NO TOASTS)
          for (var fixture in fixtures) {
            await _refreshPledgeDataForFixture(fixture.matchId);
            // ✅ ALSO LOAD BETTORS (MATCHED BETS)
            await _loadBettorsForFixture(fixture.matchId);
          }

          // ✅ FORCE REBUILD AFTER PLEDGES ARE LOADED
          _safeSetState(() {});

          if (_isUserLoggedIn() && _fixtures.isNotEmpty) {
            final ws = WebSocketService();
            if (ws.isConnected) {
              // ✅ Socket was already connected before this refresh — the
              // connectionStatus listener in _connectWebSocket() only fires
              // once on transition to connected, so it never re-runs here.
              // Any fixture that has newly become live since the last fetch
              // needs to be (re)joined explicitly, or it silently gets zero
              // commentary/chat pushes despite the socket being healthy.
              _joinFixtureRooms();
            } else {
              _connectWebSocket();
            }
          }

          unawaited(_fetchVotes());
          unawaited(_fetchUserLikesFromBackend());
          unawaited(_fetchAllComments(forceRefresh: true));
          unawaited(_fetchSubFixtureVotesForAll());

          _safeSetState(() {});
        }
      }
    } catch (e) {
      ToastHelper.showError('❌ Error: ${e.toString()}');
    }
  }

// Helper method to parse fixtures from JSON
  List<Fixture> _parseFixtures(List<dynamic> dataList) {
    final fixtures = <Fixture>[];
    for (var i = 0; i < dataList.length; i++) {
      try {
        fixtures.add(Fixture.fromJson(dataList[i] as Map<String, dynamic>));
      } catch (e) {
        debugPrint('❌ Error parsing fixture at index $i: $e');
      }
    }
    return fixtures;
  }

  void _refreshFixtureUI(String fixtureId) {
    _safeSetState(() {
      // Touch the fixture to force rebuild
      final index = _fixtures.indexWhere((f) => f.matchId == fixtureId);
      if (index != -1) {
        _fixtures[index] = Fixture(
          id: _fixtures[index].id,
          matchId: _fixtures[index].matchId,
          homeTeam: _fixtures[index].homeTeam,
          awayTeam: _fixtures[index].awayTeam,
          league: _fixtures[index].league,
          homeWin: _fixtures[index].homeWin,
          awayWin: _fixtures[index].awayWin,
          draw: _fixtures[index].draw,
          date: _fixtures[index].date,
          time: _fixtures[index].time,
          homeScore: _fixtures[index].homeScore,
          awayScore: _fixtures[index].awayScore,
          status: _fixtures[index].status,
          isLive: _fixtures[index].isLive,
          availableForVoting: _fixtures[index].availableForVoting,
          source: _fixtures[index].source,
          scrapedAt: _fixtures[index].scrapedAt,
          dateIso: _fixtures[index].dateIso,
          subFixtures: _fixtures[index].subFixtures,
        );
      }
    });
  }

  Future<void> _refreshFixtures() async {
    debugPrint('🔄 Refreshing fixtures and comments...');

    // ❌ REMOVED the visible refreshing indicator
    // _safeSetState(() => _refreshing = true);

    try {
      // Fetch fresh fixtures
      await _fetchFixtures(forceRefresh: true, showNotification: true);

      // Fetch fresh comment data (counts + latest comments)
      await _fetchInitialCommentData();

      // Fetch other data
      await _fetchVotes();
      await _fetchUserLikesFromBackend();
      await _fetchSubFixtureVotesForAll();

      _saveToGlobalCache();
      _safeSetState(() {});

      debugPrint('✅ Refresh complete');
    } catch (e) {
      debugPrint('❌ Refresh error: $e');
    } finally {
      // ❌ REMOVED the visible refreshing indicator
      // _safeSetState(() => _refreshing = false);
    }
  }

  Color _getVoteColor(String? selection) {
    if (selection == 'home_team') return FanColors.primary; // ✅ Changed
    if (selection == 'away_team') return const Color(0xFF2563EB);
    if (selection == 'draw') return const Color(0xFF8B5CF6);
    return FanColors.textSecondary; // ✅ Changed
  }

  String _getVoteDisplayText(
    String? selection,
    String homeTeam,
    String awayTeam,
  ) {
    if (selection == 'home_team') return homeTeam;
    if (selection == 'away_team') return awayTeam;
    if (selection == 'draw') return 'draw';
    return selection ?? 'unknown';
  }

  String _getOddsForSelection(Fixture fixture, String selection) {
    switch (selection) {
      case 'home_team':
        return fixture.homeWin.toStringAsFixed(2);
      case 'away_team':
        return fixture.awayWin.toStringAsFixed(2);
      case 'draw':
        return fixture.draw.toStringAsFixed(2);
      default:
        return 'N/A';
    }
  }

  // ========== NEW COMRADE SYSTEM METHODS WITH CACHING ==========

  Future<void> _fetchUserComrades() async {
    try {
      if (!_isUserLoggedIn()) {
        _userComrades.clear();
        await LocalStorageManager.saveUserComrades(_userComrades);
        return;
      }

      // Check if we have valid cached comrades
      final isCacheValid = await LocalStorageManager.isUserComradesCacheValid();
      if (isCacheValid) {
        final cachedComrades = await LocalStorageManager.loadUserComrades();
        if (cachedComrades.isNotEmpty) {
          _userComrades.clear();
          _userComrades.addAll(cachedComrades);
          debugPrint(
            '✅ Loaded ${_userComrades.length} comrades from local cache',
          );
          _saveToGlobalCache();
          return;
        }
      }

      // Fetch from API using ComradeService
      final comradesList = await ComradeService.getUserComrades(
        userId: widget.userId,
        authToken: widget.authToken,
      );

      _userComrades.clear();
      for (var comrade in comradesList) {
        final comradeId = comrade['comrade_id']?.toString();
        if (comradeId != null && comradeId.isNotEmpty) {
          _userComrades.add(comradeId);
        }
      }

      debugPrint('✅ Found ${_userComrades.length} comrades for user');

      // Save to local storage
      await LocalStorageManager.saveUserComrades(_userComrades);
      _saveToGlobalCache();
    } catch (e) {
      debugPrint('⚠️ Error fetching comrades: $e');
      if (_userComrades.isEmpty) {
        final cachedComrades = await LocalStorageManager.loadUserComrades();
        _userComrades.addAll(cachedComrades);
        debugPrint(
          '📦 Using cached comrades (${_userComrades.length}) due to network error',
        );
      }
    }
  }
  // ============================================================================
// UNREAD MESSAGE METHODS
// ============================================================================

  Future<void> markChatAsRead(
      String channelId, String fixtureId, String userId) async {
    try {
      final response = await http.put(
        Uri.parse(
            '$API_BASE_URL/channels/$channelId/fixtures/$fixtureId/read/$userId'),
        headers: await _buildHeaders(),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Marked chat as read for fixture $fixtureId');

        // Clear local unread count
        _safeSetState(() {
          _unreadCounts[fixtureId] = 0;
        });
        _stopPulsingAnimation(fixtureId);
      } else {
        debugPrint('⚠️ Failed to mark chat as read: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error marking chat as read: $e');
    }
  }

  Future<int> getUnreadCount(
      String channelId, String fixtureId, String userId) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$API_BASE_URL/channels/$channelId/fixtures/$fixtureId/unread/$userId'),
        headers: await _buildHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['unread_count'] ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('❌ Error getting unread count: $e');
      return 0;
    }
  }

  Future<Map<String, int>> getAllUnreadCounts(
      String channelId, String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/channels/$channelId/user/$userId/unread/all'),
        headers: await _buildHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final Map<String, int> unreadMap = {};
        if (data['unread_counts'] is Map) {
          data['unread_counts'].forEach((fixtureId, count) {
            unreadMap[fixtureId.toString()] = (count as num).toInt();
          });
        }
        return unreadMap;
      }
      return {};
    } catch (e) {
      debugPrint('❌ Error getting all unread counts: $e');
      return {};
    }
  }

// ============================================================================
// LOAD UNREAD COUNTS FROM BACKEND
// ============================================================================

  Future<void> _loadUnreadCountsFromBackend() async {
    if (!_isUserLoggedIn()) return;

    final channelId = _localSelectedChannel?.channelId ??
        (_userChannels.isNotEmpty ? _userChannels.first.channelId : null);

    if (channelId == null) return;

    try {
      final unreadMap = await getAllUnreadCounts(channelId, widget.userId);

      _safeSetState(() {
        for (var entry in unreadMap.entries) {
          if (entry.value > 0) {
            _unreadCounts[entry.key] = entry.value;
            _startPulsingAnimation(entry.key);
          }
        }
      });

      debugPrint('✅ Loaded ${unreadMap.length} unread counts from backend');
    } catch (e) {
      debugPrint('❌ Error loading unread counts: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchUserProfile(String userId) async {
    try {
      final headers = await _buildHeaders();
      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/profile/profile/$userId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 5));

      debugPrint(
        '🔍 Fetching profile for user $userId: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final dynamic jsonData = json.decode(response.body);

        Map<String, dynamic> profileData = {};

        if (jsonData is Map) {
          profileData = Map<String, dynamic>.from(jsonData);
        } else if (jsonData is List && jsonData.isNotEmpty) {
          for (var profile in jsonData) {
            if (profile is Map) {
              final id = profile['user_id']?.toString() ??
                  profile['userId']?.toString() ??
                  '';
              if (id == userId) {
                profileData = Map<String, dynamic>.from(profile);
                break;
              }
            }
          }
        }

        final nickname = profileData['nickname']?.toString() ??
            profileData['username']?.toString() ??
            'Fan';
        final clubFan = profileData['club_fan']?.toString() ??
            profileData['club']?.toString() ??
            'Football Fan';
        final countryFan = profileData['country_fan']?.toString() ??
            profileData['country']?.toString() ??
            'World';

        return {
          'nickname': nickname,
          'clubFan': clubFan,
          'countryFan': countryFan,
        };
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching profile for $userId: $e');
    }
    return {
      'nickname': 'Fan',
      'clubFan': 'Football Fan',
      'countryFan': 'World',
    };
  }

  Future<void> _fetchAllComradesWithProfiles() async {
    if (!_isUserLoggedIn()) {
      _safeSetState(() => _comradeVoters.clear());
      await LocalStorageManager.saveComradeVoters(_comradeVoters);
      return;
    }

    // First, try to load from local storage
    final cachedComradeVoters = await LocalStorageManager.loadComradeVoters();
    if (cachedComradeVoters.isNotEmpty) {
      _comradeVoters.clear();
      _comradeVoters.addAll(cachedComradeVoters);
      debugPrint(
        '✅ Loaded ${_comradeVoters.length} comrade voters from local cache',
      );
      _saveToGlobalCache();

      final isCacheValid = await LocalStorageManager.isUserComradesCacheValid();
      if (isCacheValid && _userComrades.isNotEmpty) {
        return;
      }
    }

    _loadingComrades = true;
    final Map<String, Map<String, dynamic>> profileCache = {};
    final Map<String, List<ComradeWithProfile>> newComradeVoters = {};

    try {
      for (var fixture in _fixtures) {
        // Use ComradeService to get comrades who voted on this fixture
        final comradesData = await ComradeService.getComradesWhoVotedOnFixture(
          fixtureId: fixture.matchId,
          userId: widget.userId,
          authToken: widget.authToken,
        );

        if (comradesData.isEmpty) continue;

        final List<ComradeWithProfile> comradesWithProfile = [];

        for (var comradeData in comradesData) {
          final comradeId = comradeData['comrade_id']?.toString() ?? '';
          if (comradeId == widget.userId) continue;

          Map<String, dynamic> profile;
          if (profileCache.containsKey(comradeId)) {
            profile = profileCache[comradeId]!;
          } else {
            profile = await _fetchUserProfile(comradeId);
            profileCache[comradeId] = profile;
          }

          // Get comment if exists
          String? comment;
          final fixtureComments = _fixtureComments[fixture.matchId];
          if (fixtureComments != null) {
            final userComment = fixtureComments.firstWhere(
              (c) => c.userId == comradeId,
              orElse: () => null as FixtureComment,
            );
            comment = userComment.comment;
          }

          comradesWithProfile.add(
            ComradeWithProfile(
              userId: comradeId,
              username:
                  comradeData['comrade_username']?.toString() ?? 'Unknown',
              nickname: comradeData['comrade_nickname']?.toString() ??
                  profile['nickname'],
              clubFan:
                  comradeData['comrade_club']?.toString() ?? profile['clubFan'],
              countryFan: comradeData['comrade_country']?.toString() ??
                  profile['countryFan'],
              selection: comradeData['selection']?.toString() ?? '',
              votedAt: DateTime.parse(
                comradeData['voted_at'] ?? DateTime.now().toIso8601String(),
              ),
              comment: comment,
            ),
          );
        }

        if (comradesWithProfile.isNotEmpty) {
          newComradeVoters[fixture.matchId] = comradesWithProfile;
        }
      }

      _comradeVoters.clear();
      _comradeVoters.addAll(newComradeVoters);

      await LocalStorageManager.saveComradeVoters(_comradeVoters);
      _saveToGlobalCache();

      debugPrint(
        '✅ Saved ${_comradeVoters.length} comrade voters to local storage',
      );
    } catch (e) {
      debugPrint('❌ Error fetching comrades with profiles: $e');
      if (_comradeVoters.isEmpty) {
        final saved = await LocalStorageManager.loadComradeVoters();
        _comradeVoters.addAll(saved);
      }
    } finally {
      _loadingComrades = false;
      _safeSetState(() {});
    }
  }

  void _markFixtureAsViewed(String fixtureId) {
    if (!_fixtureNotifications.containsKey(fixtureId)) {
      _fixtureNotifications[fixtureId] = FixtureNotificationState(
        fixtureId: fixtureId,
        lastViewed: DateTime.now(),
      );
    }
    final notification = _fixtureNotifications[fixtureId]!;
    notification.lastViewed = DateTime.now();
    notification.newVotes = 0;
    notification.newComments = 0;
    notification.newLikes = 0;
    _safeSetState(() {});
    LocalStorageManager.saveFixtureNotification(notification);
    _saveToGlobalCache();
  }

  void _updateNotificationCounts(
    String fixtureId, {
    String? voteId,
    String? commentId,
    String? likeId,
  }) {
    if (!_fixtureNotifications.containsKey(fixtureId)) {
      _fixtureNotifications[fixtureId] = FixtureNotificationState(
        fixtureId: fixtureId,
        lastViewed: DateTime.now(),
      );
    }
    final notification = _fixtureNotifications[fixtureId]!;
    if (voteId != null && !notification.seenVoteIds.contains(voteId)) {
      notification.newVotes++;
      notification.seenVoteIds = {...notification.seenVoteIds, voteId};
    }
    if (commentId != null && !notification.seenCommentIds.contains(commentId)) {
      notification.newComments++;
      notification.seenCommentIds = {...notification.seenCommentIds, commentId};
    }
    if (likeId != null && !notification.seenLikeIds.contains(likeId)) {
      notification.newLikes++;
      notification.seenLikeIds = {...notification.seenLikeIds, likeId};
    }
    _safeSetState(() {});
    LocalStorageManager.saveFixtureNotification(notification);
    _saveToGlobalCache();
  }

  // Add these variables at the top of _FixturesPageState
  // Replace _hasUnreadActivity

  // Update the FCM handler

  void _handleFCMNotification(RemoteMessage message) {
    try {
      final data = message.data;
      final notificationType = data['notificationType'];
      final fixtureId = data['fixture_id'];
      final title = data['title'] ?? '';
      final body = data['body'] ?? '';

      debugPrint('📨 FCM Notification received');
      debugPrint('📨 Type: $notificationType');
      debugPrint('📨 FixtureId: $fixtureId');
      debugPrint('📨 Title: $title');
      debugPrint('📨 Body: $body');
      debugPrint('📨 Full data: $data');

      // Handle vote notifications
      if (notificationType == 'vote_supporter' ||
          notificationType == 'vote_rival' ||
          notificationType == 'fixture_comment' ||
          notificationType == 'fixture_comment_push') {
        if (fixtureId != null) {
          // Increment unread count locally
          _safeSetState(() {
            final currentCount = _unreadCounts[fixtureId] ?? 0;
            _unreadCounts[fixtureId] = currentCount + 1;
            debugPrint(
              '🔔 Updated unread count for $fixtureId to ${_unreadCounts[fixtureId]}',
            );
          });

          // Start pulsing animation on the bell
          _startPulsingAnimation(fixtureId);

          // Show in-app snackbar notification
          _showNotificationSnackbar(data);

          // Update NotificationService to persist the unread count
          NotificationService.markFixtureAsUnread(
            fixtureId,
            notificationType,
            data,
          );

          // Refresh data to show new activity
          _refreshVotersDataForFixture(fixtureId);
          _refreshVoteDataForFixture(fixtureId);
        }
      }

      // Handle comrade added notifications
      if (notificationType == 'comrade_added') {
        debugPrint('🎉 New comrade added notification received');
        // Refresh comrades list
        _fetchUserComrades();
        _fetchAllComradesWithProfiles();
        _showNotificationSnackbar(data);
      }

      // Handle like notifications
      if (notificationType == 'fixture_like') {
        if (fixtureId != null) {
          _refreshVoteDataForFixture(fixtureId);
          _showNotificationSnackbar(data);
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling FCM notification: $e');
    }
  }

  // Updated badge widget with numbers
  Widget _buildNotificationBadge(String fixtureId) {
    final unreadCount = _unreadCounts[fixtureId] ?? 0;

    if (unreadCount == 0) return const SizedBox.shrink();

    String displayCount = unreadCount > 99 ? '99+' : unreadCount.toString();
    bool isSmall = unreadCount < 10;

    return Positioned(
      top: -6,
      right: -6,
      child: AnimatedBuilder(
        animation: _badgeTimers[fixtureId] ?? const AlwaysStoppedAnimation(1.0),
        builder: (context, child) {
          final timer = _badgeTimers[fixtureId];
          double scale = 1.0;

          if (timer is AnimationController) {
            scale = 0.8 + (timer.value * 0.4);
          }

          return Transform.scale(
            scale: scale,
            child: Container(
              constraints: BoxConstraints(
                minWidth: isSmall ? 18 : 22,
                minHeight: 18,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 6 : 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: isSmall ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: isSmall ? null : BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  displayCount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Updated comrade button that USES the badge

  void _clearUnreadCount(String fixtureId) {
    _safeSetState(() {
      _unreadCounts[fixtureId] = 0;
    });
    _stopPulsingAnimation(fixtureId);
    NotificationService.markFixtureAsRead(fixtureId);
  }

  // Update the pulsing animation start method
  void _startPulsingAnimation(String fixtureId) {
    if (_badgeTimers.containsKey(fixtureId)) return;

    // Only animate if there are unread items
    final count = _unreadCounts[fixtureId] ?? 0;
    if (count == 0) return;

    final controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    controller.repeat(reverse: true);
    _badgeTimers[fixtureId] = controller;
  }
  // ============================================================================
// CHANNEL CHECK ACTION HANDLERS
// ============================================================================

  void _handleVoteAction(Fixture fixture) {
    // Check if user is logged in first
    if (!_isUserLoggedIn()) {
      _showLoginModal();
      return;
    }

    // Check if user has channels
    if (_userChannels.isEmpty) {
      _showJoinGroupsModal();
      return;
    }

    // Proceed with voting
    _showVoteDialog(fixture);
  }

  /// Build the live commentary widget (sliding window of 3)

Future<void> _initializeLiveCommentary() async {
  for (var fixture in _fixtures) {
    if (fixture.isLive != true) continue;

    final cached = AppCache.getLiveCommentary(fixture.matchId);
    if (cached != null) {
      _liveCommentary[fixture.matchId] = [_entryFromCachedMap(cached)];
    } else {
      await _fetchLatestCommentaryViaHttp(fixture.matchId); // seed
    }
  }
  // ✅ WebSocket push alone isn't reliable enough here — a dropped room
  // join or reconnect race can silently mean commentary.new never fires
  // for this fixture again. Poll every 6s as a guaranteed floor so the
  // card never goes stale just because the socket missed something.
  _startCommentaryPolling();
}



// ── helper: build a LiveCommentaryEntry from an AppCache-cached map ──
LiveCommentaryEntry _entryFromCachedMap(Map<String, dynamic> cached) {
  final type = cached['type'] as String? ?? 'update';
  final style = _getCommentaryStyle(type);
  return LiveCommentaryEntry(
    text: cached['text'] as String? ?? '',
    type: type,
    minute: cached['minute'] as int? ?? 0,
    timestamp: DateTime.tryParse(cached['timestamp'] as String? ?? '') ??
        DateTime.now(),
    color: style['color'] as Color,
    icon: style['icon'] as IconData,
    scorer: cached['scorer'] as String?,
    team: cached['team'] as String?,
  );
}

Widget _buildLiveCommentary(BuildContext context, String fixtureId) {
  // ✅ Prefer in-memory state; fall back to AppCache (survives page
  // disposal/rebuild) before ever showing the "starting..." placeholder.
  List<LiveCommentaryEntry> entries = _liveCommentary[fixtureId] ?? [];

  if (entries.isEmpty) {
    final cached = AppCache.getLiveCommentary(fixtureId);
    if (cached != null) {
      entries = [_entryFromCachedMap(cached)];
      // Hydrate local state too, so subsequent builds don't re-hit AppCache
      // and so _addCommentaryToWindow's dedup logic has something to diff against.
      _liveCommentary[fixtureId] = entries;
    }
  }

  if (entries.isEmpty) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: FanColors.live,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '🔴 Live coverage starting...',
          style: TextStyle(
            fontSize: 11,
            color: FanColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  final entry = entries.last;
  final timeStr = DateFormat('HH:mm').format(entry.timestamp);

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: entry.color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(entry.icon, size: 14, color: entry.color),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.text,
              style: TextStyle(
                fontSize: 11.5,
                color: FanColors.textPrimary,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 2),
            Text(timeStr,
                style: TextStyle(fontSize: 8, color: FanColors.textTertiary)),
          ],
        ),
      ),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: FanColors.surface,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          "${entry.minute}'",
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: FanColors.textSecondary,
          ),
        ),
      ),
    ],
  );
}

  void _startCommentPolling() {
    _commentPollTimer?.cancel();
    _commentPollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      for (var fixture in _fixtures) {
        final channelId = _resolveChannelIdFor(fixture.matchId);
        if (channelId == null) continue;
        _fetchLatestCommentViaHttpWithChannel(
            fixture.matchId, fixture, channelId);
        _fetchCommentCountViaHttp(fixture.matchId, channelId: channelId);
      }
    });
  }

  void _stopCommentPolling() {
    _commentPollTimer?.cancel();
    _commentPollTimer = null;
  }

  void _handleCommentAction(Fixture fixture, String comment, int index) {
    // Check if user is logged in first
    if (!_isUserLoggedIn()) {
      _showLoginModal();
      return;
    }

    // Check if user has channels
    if (_userChannels.isEmpty) {
      _showJoinGroupsModal();
      return;
    }

    // Proceed with commenting
    _createComment(fixture, comment, index);
  }

  void _handleLikeAction(Fixture fixture, int index) {
    // Check if user is logged in first
    if (!_isUserLoggedIn()) {
      _showLoginModal();
      return;
    }

    // Check if user has channels
    if (_userChannels.isEmpty) {
      _showJoinGroupsModal();
      return;
    }

    // Proceed with liking
    _toggleLike(fixture, index);
  }

  // Remove or comment out the old _hasUnreadActivity references
  // Or keep them for backward compatibility

  // ============================================================================
  // PLEDGE METHODS — FIXED
  // ============================================================================

  // ============================================================================
  // PLEDGE METHODS — FIXED
  // ============================================================================


  // ============================================================
// ✅ UPDATED: Process Pledge with Vote First + Rollback
// ============================================================

// Add this helper method

  Future<bool> _processPledge(
      Fixture fixture, String selection, double amount) async {
    final fixtureId = fixture.matchId;

    if (_userPledges.containsKey(fixtureId)) {
      ToastHelper.showWarning('You have already pledged on this fixture');
      return false;
    }

    final balance = await _getUserBalance();
    if (balance < amount) {
      ToastHelper.showWarning(
          'Insufficient balance. You have ₿${balance.toStringAsFixed(2)}');
      return false;
    }

    String backendSelection = selection;
    if (selection == "home_team")
      backendSelection = "home";
    else if (selection == "away_team") backendSelection = "away";

    _safeSetState(() => _loadingPledge[fixtureId] = true);

    try {
      final String? channelId =
          _fixtureChannelOverrides[fixtureId]?.channelId ??
              _localSelectedChannel?.channelId ??
              (_userChannels.isNotEmpty ? _userChannels.first.channelId : null);

      if (channelId == null) {
        ToastHelper.showError('No channel selected');
        return false;
      }

      if (!_userVotes.containsKey(fixtureId)) {
        ToastHelper.showInfo('🗳️ Casting vote first...');
        final voteResult = await VoteService.castVote(
          fixtureId: fixtureId,
          userId: widget.userId,
          username: widget.username,
          selection: backendSelection,
          authToken: widget.authToken,
        );

        if (voteResult['success'] != true) {
          final msg = voteResult['message']?.toString() ?? '';
          if (!msg.contains('already voted')) {
            ToastHelper.showError('Failed to vote: $msg');
            return false;
          }
        } else {
          _safeSetState(() {
            _userVotes[fixtureId] = selection;
            _voteCounts[fixtureId] = (_voteCounts[fixtureId] ?? 0) + 1;
          });
          await LocalStorageManager.saveVote(
              widget.userId, fixtureId, backendSelection);
        }
      }

      final String voteId = widget.userId;

      ToastHelper.showInfo('💰 Creating pledge...');
      final pledgeResult = await BetService.createBetWithVoteId(
        fixtureId: fixtureId,
        starterId: widget.userId,
        starterName: widget.username,
        starterSelection: backendSelection,
        amount: amount,
        channelId: channelId,
        voteId: voteId,
        authToken: widget.authToken,
      );

      if (pledgeResult['success'] != true) {
        if (!_userVotes.containsKey(fixtureId)) {
          await VoteService.rollbackVote(
            fixtureId: fixtureId,
            userId: widget.userId,
            authToken: widget.authToken,
          );
          _safeSetState(() {
            _userVotes.remove(fixtureId);
          });
        }
        ToastHelper.showError(
            pledgeResult['message'] ?? 'Failed to create pledge');
        return false;
      }

      final newBalance =
          (pledgeResult['new_balance'] ?? (balance - amount)).toDouble();

      _safeSetState(() {
        _userVotes[fixtureId] = selection;
        _userPledges[fixtureId] = selection;
        _pledgeAmounts[fixtureId] = amount;
        _userBalance = newBalance;
        _pledgeCounts[fixtureId] = (_pledgeCounts[fixtureId] ?? 0) + 1;

        if (!_pledgers.containsKey(fixtureId)) {
          _pledgers[fixtureId] = [];
        }
        _pledgers[fixtureId]!.add(Bettor(
          userId: widget.userId,
          userName: widget.username,
          selection: selection,
          amount: amount,
          opponentId: null,
          opponentName: null,
          opponentSelection: null,
          opponentAmount: null,
          totalPot: null,
          betId: '',
          status: 'open',
          winner: null,
          payout: null,
          matchedAt: DateTime.now(),
          resolvedAt: null,
          createdAt: DateTime.now(),
        ));

        if (!_comradeVoters.containsKey(fixtureId)) {
          _comradeVoters[fixtureId] = [];
        }
        _comradeVoters[fixtureId]!.add(ComradeWithProfile(
          userId: widget.userId,
          username: widget.username,
          nickname: widget.username,
          clubFan: '',
          countryFan: '',
          selection: selection,
          votedAt: DateTime.now(),
          comment: null,
        ));
      });

      // ✅ UPDATE APPCACHE - Pledge count
      AppCache.applyUpdate(
        fixtureId: fixtureId,
        updateType: 'pledge',
        value: _pledgeCounts[fixtureId] ?? 0,
        extraData: {
          'channelId': channelId,
          'userId': widget.userId,
          'selection': selection,
          'amount': amount,
        },
      );

      ToastHelper.showInfo('🔄 Refreshing pledge data...');
      await _refreshPledgeDataForFixture(fixtureId);

      // ✅ FORCE REBUILD AFTER PLEDGE DATA REFRESH
      _safeSetState(() {});

      await _refreshVotersDataForFixture(fixtureId);
      await _refreshVoteDataForFixture(fixtureId);
      await _fetchUserBalance();
      _saveToGlobalCache();

      ToastHelper.showSuccess('✅ Vote and Pledge created! 🎉');
      return true;
    } catch (e) {
      ToastHelper.showError('❌ Error: ${e.toString()}');
      return false;
    } finally {
      _safeSetState(() => _loadingPledge[fixtureId] = false);
    }
  }

  Future<void> _ensureChannelFixture(String channelId, String fixtureId) async {
    final dedupeKey = '${channelId}_$fixtureId';
    if (_ensuredChannelFixtures.contains(dedupeKey)) {
      debugPrint('⏭️ Channel fixture already ensured for $dedupeKey, skipping');
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse(
                'https://clash-api-m5mr.onrender.com/api/channels/fixture/chat'),
            headers: await _buildHeaders(),
            body: json.encode({
              'channel_id': channelId,
              'fixture_id': fixtureId,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        _ensuredChannelFixtures.add(dedupeKey);

        final data = json.decode(response.body);
        debugPrint('✅ Channel fixture ensured for $channelId / $fixtureId');

        if (data['already_exists'] == false) {
          _fetchFixtures(forceRefresh: true, showNotification: false);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Channel fixture check failed: $e');
    }
  }

  Widget _buildPledgersPreview(Fixture fixture) {
    final fixtureId = fixture.matchId;
    final isLive = fixture.isLive == true;

    // If live, show nothing
    if (isLive) return const SizedBox.shrink();

    final displayBets = _getDisplayBetsForFixture(fixtureId);

    if (displayBets.isEmpty) return const SizedBox.shrink();

    final displayBetsLimited = displayBets.take(2).toList();
    final isPledges = _pledgers[fixtureId]?.isNotEmpty ?? false;

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (displayBets.length > 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: GestureDetector(
                onTap: () => _showBetsPopup(fixture),
                child: Row(
                  children: [
                    Icon(
                      _getBetsDisplayIcon(fixtureId),
                      size: 12,
                      color: _getBetsDisplayColor(fixtureId),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${displayBets.length} ${isPledges ? 'pledges' : 'matched bets'} (view all)',
                      style: TextStyle(
                        fontSize: 10,
                        color: _getBetsDisplayColor(fixtureId),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (displayBets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    _getBetsDisplayIcon(fixtureId),
                    size: 11,
                    color: _getBetsDisplayColor(fixtureId),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${displayBets.length} ${isPledges ? 'pledges' : 'matched bets'}',
                    style: TextStyle(
                      fontSize: 10,
                      color: _getBetsDisplayColor(fixtureId),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ...displayBetsLimited.map((bet) {
            final isMe = bet.userId == widget.userId;
            if (!isPledges && bet.isMatched) {
              return _buildMatchedBetPreview(bet, fixture);
            }
            return _buildPledgePreview(bet, fixture, isMe);
          }).toList(),
        ],
      ),
    );
  }

// Helper for pledge preview
  Widget _buildPledgePreview(Bettor bet, Fixture fixture, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Icon(Icons.attach_money, size: 11, color: Colors.amber.shade400),
          const SizedBox(width: 4),
          Text(
            isMe ? 'You' : bet.userName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isMe ? FontWeight.w600 : FontWeight.w400,
              color: isMe ? FanColors.primary : Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'pledged',
            style: TextStyle(fontSize: 10, color: Colors.white54),
          ),
          const SizedBox(width: 4),
          Text(
            _getVoteDisplayText(
                bet.selection, fixture.homeTeam, fixture.awayTeam),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _getVoteColor(bet.selection),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'KES ${bet.amount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 10, color: Colors.white54),
          ),
        ],
      ),
    );
  }

// Helper for matched bet preview
  Widget _buildMatchedBetPreview(Bettor bet, Fixture fixture) {
    final isMe = bet.userId == widget.userId;
    final opponentName = bet.opponentName ?? 'Unknown';
    final opponentSelection = bet.opponentSelection ?? '';
    final totalPot = bet.totalPot ?? bet.amount + (bet.opponentAmount ?? 0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Column(
        children: [
          // User's bet
          Row(
            children: [
              Icon(Icons.handshake, size: 11, color: Colors.blue),
              const SizedBox(width: 4),
              Text(
                isMe ? 'You' : bet.userName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isMe ? FontWeight.w600 : FontWeight.w400,
                  color: isMe ? FanColors.primary : Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'vs',
                style: TextStyle(fontSize: 10, color: Colors.white54),
              ),
              const SizedBox(width: 4),
              Text(
                opponentName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Pot: KES ${totalPot.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.purple,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          // Selections
          Row(
            children: [
              const SizedBox(width: 16),
              Text(
                '${bet.selectionDisplay} vs ${_getVoteDisplayText(opponentSelection, fixture.homeTeam, fixture.awayTeam)}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
          // Bet status
          if (bet.isSettled)
            Row(
              children: [
                const SizedBox(width: 16),
                Text(
                  bet.isWon ? '🏆 Won' : '💔 Lost',
                  style: TextStyle(
                    fontSize: 9,
                    color: bet.isWon ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

// Show all bets popup
  void _showBetsPopup(Fixture fixture) {
    final fixtureId = fixture.matchId;
    final displayBets = _getDisplayBetsForFixture(fixtureId);
    final isPledges = _pledgers[fixtureId]?.isNotEmpty ?? false;

    if (displayBets.isEmpty) {
      ToastHelper.showInfo('No bets available');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: FanColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  _getBetsDisplayIcon(fixtureId),
                  color: _getBetsDisplayColor(fixtureId),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _getBetsDisplayTitle(fixtureId),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  '(${displayBets.length})',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            content: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: displayBets.length,
                itemBuilder: (context, index) {
                  final bet = displayBets[index];
                  final isMe = bet.userId == widget.userId;
                  final canMatch = isPledges && !isMe && bet.status == 'open';

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: FanColors.border.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    child: isPledges
                        ? _buildPledgePopupItem(bet, fixture, isMe, canMatch)
                        : _buildMatchedBetPopupItem(bet, fixture, isMe),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: TextStyle(color: FanColors.textSecondary),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

// Pledge popup item
  Widget _buildPledgePopupItem(
      Bettor bet, Fixture fixture, bool isMe, bool canMatch) {
    return Row(
      children: [
        FootballAvatarManager.buildAvatar(
          userId: bet.userId,
          username: bet.userName,
          size: 32,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMe ? 'You' : bet.userName,
                style: TextStyle(
                  color: isMe ? FanColors.primary : Colors.white,
                  fontWeight: isMe ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                bet.selectionDisplay,
                style: TextStyle(
                  color: _getVoteColor(bet.selection),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        if (canMatch)
          GestureDetector(
            onTap: () {
              _matchPledgeFromDialog(bet, fixture);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: FanColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'MATCH',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        Text(
          'KES ${bet.amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: FanColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

// Matched bet popup item
  Widget _buildMatchedBetPopupItem(Bettor bet, Fixture fixture, bool isMe) {
    final opponentName = bet.opponentName ?? 'Unknown';
    final opponentAmount = bet.opponentAmount ?? 0;
    final totalPot = bet.totalPot ?? bet.amount + opponentAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FootballAvatarManager.buildAvatar(
              userId: bet.userId,
              username: bet.userName,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? 'You' : bet.userName,
                    style: TextStyle(
                      color: isMe ? FanColors.primary : Colors.white,
                      fontWeight: isMe ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        bet.selectionDisplay,
                        style: TextStyle(
                          color: _getVoteColor(bet.selection),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'KES ${bet.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: FanColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (bet.isSettled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bet.isWon
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  bet.isWon ? '🏆 WON' : '💔 LOST',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: bet.isWon ? Colors.green : Colors.red,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 44),
          child: Row(
            children: [
              Text(
                'vs $opponentName',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'KES ${opponentAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Pot: KES ${totalPot.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.purple,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchedBetsCount(Fixture fixture) {
    final fixtureId = fixture.matchId;
    final matchedBets = _bettors[fixtureId] ?? [];
    final activeMatched = matchedBets.where((b) => b.isMatched).toList();

    if (activeMatched.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showBetsPopup(fixture),
      child: Row(
        children: [
          Icon(Icons.handshake, size: 11, color: Colors.blue),
          const SizedBox(width: 3),
          Text(
            '${activeMatched.length}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  // Send notifications only to comrades
  Future<void> _notifyComradesAboutNewVote(
    String fixtureId,
    Fixture fixture,
    String userSelection,
  ) async {
    try {
      if (_userComrades.isEmpty) {
        debugPrint('📭 No comrades to notify');
        return;
      }

      final fixtureVoteData = _fixtureVoteData[fixtureId];
      if (fixtureVoteData == null) return;

      final allVoters = [
        ...fixtureVoteData.supporters,
        ...fixtureVoteData.rivals,
      ];
      final comradesToNotify = allVoters
          .where(
            (v) =>
                _userComrades.contains(v.userId) && v.userId != widget.userId,
          )
          .toList();

      if (comradesToNotify.isEmpty) {
        debugPrint('📭 No comrades among voters for fixture $fixtureId');
        return;
      }

      final teamName = _getVoteDisplayText(
        userSelection,
        fixture.homeTeam,
        fixture.awayTeam,
      );
      final fixtureName = '${fixture.homeTeam} vs ${fixture.awayTeam}';
      final currentTime = DateTime.now().toIso8601String();

      for (var user in comradesToNotify) {
        final isRival = fixtureVoteData.rivals.any(
          (r) => r.userId == user.userId,
        );

        await _sendNotificationSafe(
          userId: user.userId,
          notificationType: isRival ? 'vote_rival' : 'vote_supporter',
          title: isRival
              ? '⚔️ Your comrade voted against you!'
              : '🎉 Your comrade agrees with you!',
          body: '@${widget.username} voted for $teamName in $fixtureName',
          data: {
            'fixture_id': fixtureId,
            'voter_id': widget.userId,
            'voter_username': widget.username,
            'voter_selection': userSelection,
            'team_name': teamName,
            'home_team': fixture.homeTeam,
            'away_team': fixture.awayTeam,
            'type': isRival ? 'rival' : 'supporter',
            'timestamp': currentTime,
          },
        );
        await Future.delayed(const Duration(milliseconds: 100));
      }

      debugPrint(
        '✅ Vote notifications sent to ${comradesToNotify.length} comrades',
      );
    } catch (e) {
      debugPrint('❌ Error in _notifyComradesAboutNewVote: $e');
    }
  }

 Future<void> _createComment(
      Fixture fixture, String commentText, int index) async {
    final fixtureId = fixture.matchId;

    // ==========================================================================
    // VALIDATION
    // ==========================================================================

    if (!_isUserLoggedIn()) {
      _showLoginModal();
      return;
    }

    if (!_userVotes.containsKey(fixtureId)) {
      ToastHelper.showWarning('You must vote on this match before commenting');
      return;
    }

    final trimmed = commentText.trim();
    if (trimmed.isEmpty) {
      ToastHelper.showWarning('Comment cannot be empty');
      return;
    }

    if (_loadingComment[fixtureId] == true) {
      ToastHelper.showWarning('Already posting...');
      return;
    }

    // ==========================================================================
    // GET CHANNEL ID — SAME RESOLUTION AS _openChatScreen, so this comment
    // lands in exactly the conversation ChatScreen will read back.
    // ==========================================================================

    final String? channelId = _resolveChannelIdFor(fixtureId);
    if (channelId == null) {
      debugPrint('❌ No channel ID available for fixture $fixtureId');
      ToastHelper.showError('Unable to post comment: No channel selected');
      return;
    }

    // ==========================================================================
    // ✅ ENSURE THE CHANNEL-FIXTURE CHAT EXISTS BEFORE POSTING
    // Without this, comments posted from FixturesPage before ChatScreen has
    // ever been opened for this fixture get saved server-side but never show
    // up in ChatScreen's GET /channels/messages fetch.
    // ==========================================================================

    await _ensureChannelFixture(channelId, fixtureId);

    final tempId =
        'temp_${DateTime.now().millisecondsSinceEpoch}_${widget.userId}';
    final userSelection = _userVotes[fixtureId];
    final timestamp = DateTime.now();

    // ==========================================================================
    // OPTIMISTIC UPDATE
    // ==========================================================================

    _safeSetState(() {
      if (!_fixtureComments.containsKey(fixtureId)) {
        _fixtureComments[fixtureId] = [];
      }
      _fixtureComments[fixtureId]!.insert(
          0,
          FixtureComment(
            id: tempId,
            userId: widget.userId,
            username: widget.username,
            fixtureId: fixtureId,
            comment: trimmed,
            selection: userSelection,
            timestamp: timestamp,
          ));
      _commentCounts[fixtureId] = (_commentCounts[fixtureId] ?? 0) + 1;
      _loadingComment[fixtureId] = true;
    });

    _commentControllers[fixtureId]?.clear();

    // ✅ Keep AppCache's message cache current so ChatScreen sees this
    // comment immediately whenever it's next opened — without this,
    // ChatScreen's per-session hydration guard means it would only ever
    // pick this up on a cold app restart.
    AppCache.appendCachedMessage(channelId, fixtureId, {
      'id': tempId,
      'tempId': tempId,
      'userId': widget.userId,
      'username': widget.username,
      'text': trimmed,
      'selection': userSelection,
      'timestamp': timestamp.toIso8601String(),
      'status': 1,
      'isSeen': false,
      'isCommentary': false,
      'commentaryType': null,
    });

    // ==========================================================================
    // ✅ SEND VIA WEBSOCKET — WITH RECONNECT-AND-RETRY (matches ChatScreen)
    // ==========================================================================

    final sent = await WebSocketService().sendChatMessageReliable(
      message: trimmed,
      selection: userSelection ?? '',
      username: widget.username,
      messageId: tempId,
      channelId: channelId,
      fixtureId: fixtureId,
      tempId: tempId,
      onReconnectAttempt: () async => _connectWebSocket(),
    );

    if (!sent) {
      debugPrint('⚠️ Failed to send comment for $fixtureId after retry');
      ToastHelper.showError('Not connected to chat server');

      // Revert optimistic update
      _safeSetState(() {
        _fixtureComments[fixtureId]!.removeWhere((c) => c.id == tempId);
        _commentCounts[fixtureId] = (_commentCounts[fixtureId] ?? 1) - 1;
      });
    }

    _safeSetState(() => _loadingComment[fixtureId] = false);
  }

// ==========================================================================
// SHARED SEND HELPER — reconnect once, wait briefly, retry once.
// Returns true only if the message was actually handed to a connected
// socket. Callers own the optimistic-update revert on false.
// ==========================================================================

  
  // Notify comrades about new comment
  Future<void> _notifyComradesAboutNewComment(
    String fixtureId,
    Fixture fixture,
    String commentText,
  ) async {
    try {
      if (_userComrades.isEmpty) return;

      final fixtureVoteData = _fixtureVoteData[fixtureId];
      if (fixtureVoteData == null) return;

      final allVoters = [
        ...fixtureVoteData.supporters,
        ...fixtureVoteData.rivals,
      ];
      final commentersMap = _fixtureCommenters[fixtureId] ?? {};

      final allUsers = <VoteUser>[...allVoters];
      for (var entry in commentersMap.entries) {
        if (!allUsers.any((u) => u.userId == entry.key)) {
          allUsers.add(
            VoteUser(
              userId: entry.key,
              username: entry.value,
              selection: '',
              votedAt: DateTime.now(),
            ),
          );
        }
      }

      final comradesToNotify = allUsers
          .where(
            (v) =>
                _userComrades.contains(v.userId) && v.userId != widget.userId,
          )
          .toList();

      if (comradesToNotify.isEmpty) return;

      final fixtureName = '${fixture.homeTeam} vs ${fixture.awayTeam}';
      final commentPreview = commentText.length > 50
          ? '${commentText.substring(0, 50)}...'
          : commentText;
      final currentTime = DateTime.now().toIso8601String();

      for (var user in comradesToNotify) {
        final isRival = fixtureVoteData.rivals.any(
          (r) => r.userId == user.userId,
        );

        await _sendNotificationSafe(
          userId: user.userId,
          notificationType: 'fixture_comment',
          title: isRival
              ? '⚔️ Your comrade commented'
              : '💬 Your comrade commented',
          body: '"$commentPreview" • $fixtureName',
          data: {
            'fixture_id': fixtureId,
            'commenter_id': widget.userId,
            'commenter_username': widget.username,
            'comment_text': commentText,
            'home_team': fixture.homeTeam,
            'away_team': fixture.awayTeam,
            'timestamp': currentTime,
            'type': 'comment',
          },
        );
        await Future.delayed(const Duration(milliseconds: 50));
      }

      debugPrint(
          '✅ Comment notifications sent to ${comradesToNotify.length} comrades');
    } catch (e) {
      debugPrint('❌ Error in comment notification: $e');
    }
  }

  Future<void> _toggleLike(Fixture fixture, int index) async {
    final fixtureId = fixture.matchId;
    final isCurrentlyLiked = _userLikes[fixtureId] ?? false;

    if (!_isUserLoggedIn()) {
      _showLoginModal();
      return;
    }

    if (_loadingLike[fixtureId] == true) return;

    _safeSetState(() {
      _loadingLike[fixtureId] = true;
      _userLikes[fixtureId] = !isCurrentlyLiked;

      final currentTotal = _likeStats[fixtureId]?.totalLikes ?? 0;
      _likeStats[fixtureId] = LikeStatsResponse(
        fixtureId: fixtureId,
        totalLikes: isCurrentlyLiked ? currentTotal - 1 : currentTotal + 1,
        userHasLiked: !isCurrentlyLiked,
      );
      _saveToGlobalCache();
    });

    try {
      final timestamp = DateTime.now().toIso8601String();
      final action = isCurrentlyLiked ? 'unlike' : 'like';

      // ✅ SEND VIA WEBSOCKET (instead of HTTP)
      final ws = WebSocketService();
      ws.send('like', {
        'fixtureId': fixtureId,
        'userId': widget.userId,
        'username': widget.username,
        'action': action,
        'timestamp': timestamp,
      });

      ToastHelper.showSuccess(isCurrentlyLiked ? 'Like removed' : 'Liked!');
      await LocalStorageManager.saveLike(
        widget.userId,
        fixtureId,
        !isCurrentlyLiked,
      );
      await ArchiveService.archiveLikeActivity(
        userId: widget.userId,
        username: widget.username,
        fixtureId: fixtureId,
        homeTeam: fixture.homeTeam,
        awayTeam: fixture.awayTeam,
        isLiked: !isCurrentlyLiked,
      );

      // ✅ UPDATE APPCACHE - Like count
      final channelId = _localSelectedChannel?.channelId ??
          (_userChannels.isNotEmpty ? _userChannels.first.channelId : null);

      final totalLikes = _likeStats[fixtureId]?.totalLikes ?? 0;
      AppCache.applyUpdate(
        fixtureId: fixtureId,
        updateType: 'like',
        value: totalLikes,
        extraData: {
          'channelId': channelId,
          'liked': !isCurrentlyLiked,
        },
      );
      await AppCache.saveLikeCount(fixtureId, totalLikes);

      // Send FCM notification for new like only
      if (!isCurrentlyLiked) {
        await _notifyComradesAboutLike(fixtureId, fixture);
      }
      _updateNotificationCounts(fixtureId, likeId: timestamp);
    } catch (e) {
      debugPrint('❌ Error toggling like via WebSocket: $e');
      ToastHelper.showError('Network error: ${e.toString()}');

      // Revert optimistic update
      _revertLike(fixtureId, isCurrentlyLiked);
    } finally {
      _safeSetState(() => _loadingLike[fixtureId] = false);
    }
  }

  void _revertLike(String fixtureId, bool wasLiked) {
    _safeSetState(() {
      _userLikes[fixtureId] = wasLiked;
      if (_likeStats.containsKey(fixtureId)) {
        final s = _likeStats[fixtureId]!;
        _likeStats[fixtureId] = LikeStatsResponse(
          fixtureId: fixtureId,
          totalLikes: s.totalLikes,
          userHasLiked: wasLiked,
        );
      }
      _saveToGlobalCache();
    });
  }

  // Notify comrades about like
  Future<void> _notifyComradesAboutLike(
    String fixtureId,
    Fixture fixture,
  ) async {
    try {
      if (_userComrades.isEmpty) return;

      final fixtureVoteData = _fixtureVoteData[fixtureId];
      if (fixtureVoteData == null) return;

      final allVoters = [
        ...fixtureVoteData.supporters,
        ...fixtureVoteData.rivals,
      ];
      final commentersMap = _fixtureCommenters[fixtureId] ?? {};

      final allUsers = <VoteUser>[...allVoters];
      for (var entry in commentersMap.entries) {
        if (!allUsers.any((u) => u.userId == entry.key)) {
          allUsers.add(
            VoteUser(
              userId: entry.key,
              username: entry.value,
              selection: '',
              votedAt: DateTime.now(),
            ),
          );
        }
      }

      final comradesToNotify = allUsers
          .where(
            (v) =>
                _userComrades.contains(v.userId) && v.userId != widget.userId,
          )
          .toList();

      if (comradesToNotify.isEmpty) return;

      final fixtureName = '${fixture.homeTeam} vs ${fixture.awayTeam}';
      final likeCount = _likeStats[fixtureId]?.totalLikes ?? 1;
      final currentTime = DateTime.now().toIso8601String();

      for (var user in comradesToNotify) {
        final isRival = fixtureVoteData.rivals.any(
          (r) => r.userId == user.userId,
        );

        final body = likeCount > 10
            ? 'Now $likeCount people like $fixtureName'
            : fixtureName;

        await _sendNotificationSafe(
          userId: user.userId,
          notificationType: 'fixture_like',
          title: isRival
              ? '❤️ Your comrade liked this match'
              : '❤️ Your comrade liked this match',
          body: body,
          data: {
            'fixture_id': fixtureId,
            'liker_id': widget.userId,
            'liker_username': widget.username,
            'home_team': fixture.homeTeam,
            'away_team': fixture.awayTeam,
            'like_count': likeCount,
            'timestamp': currentTime,
            'type': 'like',
          },
        );
        await Future.delayed(const Duration(milliseconds: 50));
      }

      debugPrint(
        '✅ Like notifications sent to ${comradesToNotify.length} comrades',
      );
    } catch (e) {
      debugPrint('❌ Error in like notification: $e');
    }
  }

  void _openSubFixtureModal(Fixture fixture, SubFixture subFixture) {
    final fixtureId = fixture.matchId;

    SubFixtureVoteData? voteData;
    if (_subFixtureVoteData.containsKey(fixtureId)) {
      voteData = _subFixtureVoteData[fixtureId]?[subFixture.id];
    }

    Map<String, int> supporterCounts = {};
    Map<String, int> rivalCounts = {};

    if (voteData != null) {
      for (var supporter in voteData.supporters) {
        supporterCounts[supporter.selection] =
            (supporterCounts[supporter.selection] ?? 0) + 1;
      }
      for (var rival in voteData.rivals) {
        rivalCounts[rival.selection] = (rivalCounts[rival.selection] ?? 0) + 1;
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SubFixtureModal(
        isOpen: true,
        onClose: () => Navigator.pop(context),
        fixture: fixture,
        subFixture: subFixture,
        userId: widget.userId,
        username: widget.username,
        authToken: widget.authToken,
        onVote: (String selection) async {
          await _submitSubFixtureVote(fixture, subFixture, selection);
        },
      ),
    );
  }

  Future<void> _submitSubFixtureVote(
    Fixture fixture,
    SubFixture subFixture,
    String selection,
  ) async {
    final subFixtureId = subFixture.id;
    final fixtureId = fixture.matchId;

    _safeSetState(() => _loadingSubFixtureVote[subFixtureId] = true);

    try {
      final response = await VoteService.submitSubFixtureVote(
        userId: widget.userId,
        username: widget.username,
        subFixtureId: subFixtureId,
        parentFixtureId: fixtureId,
        selection: selection,
        authToken: widget.authToken,
      );

      if (response != null && response.success) {
        ToastHelper.showSuccess('Prop bet submitted successfully!');

        await LocalStorageManager.saveSubFixtureVote(
          widget.userId,
          subFixtureId,
          selection,
        );

        await _fetchSubFixtureVotesForFixture(fixtureId);
        _saveToGlobalCache();

        _notifyComradesAboutNewSubFixtureVote(
          fixture,
          subFixture,
          selection,
        ).catchError(
          (e) => debugPrint('❌ Sub-fixture notification failed: $e'),
        );
      } else if (response != null) {
        ToastHelper.showError(response.message);
      } else {
        ToastHelper.showError('Failed to submit prop bet. Please try again.');
      }
    } catch (e) {
      debugPrint('❌ Error submitting sub-fixture vote: $e');
      ToastHelper.showError('Network error: ${e.toString()}');
    } finally {
      _safeSetState(() => _loadingSubFixtureVote[subFixtureId] = false);
    }
  }

  // Notify comrades about sub-fixture vote
  Future<void> _notifyComradesAboutNewSubFixtureVote(
    Fixture fixture,
    SubFixture subFixture,
    String userSelection,
  ) async {
    try {
      if (_userComrades.isEmpty) return;

      final fixtureId = fixture.matchId;
      final voteData = _subFixtureVoteData[fixtureId]?[subFixture.id];

      if (voteData == null) return;

      final allVoters = [...voteData.supporters, ...voteData.rivals];
      final comradesToNotify = allVoters
          .where(
            (v) =>
                _userComrades.contains(v.userId) && v.userId != widget.userId,
          )
          .toList();

      if (comradesToNotify.isEmpty) return;

      final fixtureName = '${fixture.homeTeam} vs ${fixture.awayTeam}';
      final currentTime = DateTime.now().toIso8601String();

      for (var user in comradesToNotify) {
        final isRival = voteData.rivals.any((r) => r.userId == user.userId);

        await _sendNotificationSafe(
          userId: user.userId,
          notificationType:
              isRival ? 'sub_fixture_rival' : 'sub_fixture_supporter',
          title: isRival
              ? '⚔️ Your comrade voted against your prop'
              : '🎯 Your comrade agrees with your prop',
          body:
              '@${widget.username} voted ${userSelection.toLowerCase()} for ${subFixture.question} in $fixtureName',
          data: {
            'fixture_id': fixtureId,
            'sub_fixture_id': subFixture.id,
            'sub_fixture_question': subFixture.question,
            'voter_id': widget.userId,
            'voter_username': widget.username,
            'voter_selection': userSelection,
            'type': isRival ? 'rival' : 'supporter',
            'timestamp': currentTime,
          },
        );
        await Future.delayed(const Duration(milliseconds: 50));
      }

      debugPrint(
        '✅ Sub-fixture notifications sent to ${comradesToNotify.length} comrades',
      );
    } catch (e) {
      debugPrint('❌ Error in sub-fixture notification: $e');
    }
  }

  // ========== ODDS BUTTON WITH GREEN TICK ONLY ==========

  // ========== FEATURED COMMENT - PLAIN TEXT ==========

  // ========== COMMENT PREVIEW (KEPT - SHOWS EXISTING COMMENTS) ==========

  /// Builds the appropriate action button based on match status:
  /// - Before match: Comrades button that shows leaderboard
  /// - Live match: Watch button that opens match details
  /// - Finished match: Reviews button that opens match details
  ///
  ///
  ///

  /// Builds the appropriate action button based on match status:
  /// - Before match: Group/People ICON (opens leaderboard)
  /// - Live match: Watch ICON (opens match details)
  /// - Finished match: Reviews ICON (opens match details)

  /// Opens the Comrade Leaderboard Modal
  ///
  ///
  void _saveToGlobalCache() {
    // Save to memory cache (GlobalCacheManager)
    _cache.fixtures = List.from(_fixtures);
    _cache.userVotes = Map.from(_userVotes);
    _cache.fixtureVoteData = Map.from(_fixtureVoteData);
    _cache.comments = Map.from(_fixtureComments);
    _cache.subFixtureData = Map.from(_subFixtureVoteData);
    _cache.userLikes = Map.from(_userLikes);
    _cache.likeStats = Map.from(_likeStats);
    _cache.voteStats = Map.from(_voteStats);
    _cache.gameMetadata = Map.from(_gameMetadata);
    _cache.subFixtures = Map.from(_fixtureSubFixtures);
    _cache.commenters = Map.from(_fixtureCommenters);
    _cache.notifications = Map.from(_fixtureNotifications);
    _cache.userComrades = Set.from(_userComrades);
    _cache.comradeVoters = Map.from(_comradeVoters);
    _cache.unreadCounts = Map.from(_unreadCounts);

    debugPrint('💾 Saved to MEMORY cache (GlobalCacheManager)');
  }

  // Helper method for the status button (changes based on match state)
  Widget _buildStatusButton(
    Fixture fixture,
    bool hasUserVoted,
    bool isUpcoming,
    bool isLive,
    bool isFinished,
  ) {
    if (isUpcoming) {
      // WATCH button - DISABLED (but still opens match details)
      return Opacity(
        opacity: 0.5,
        child: GestureDetector(
          onTap: () {
            _showMatchDetailsModal(fixture);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: FanColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.play_circle_outline,
                  size: 14,
                  color: FanColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'watch',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: FanColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (isLive) {
      // WATCH button - ENABLED (opens match details)
      return GestureDetector(
        onTap: () {
          _showMatchDetailsModal(fixture);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: FanColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_outline, size: 14, color: Colors.red),
              const SizedBox(width: 4),
              Text(
                'watch live',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (isFinished) {
      // REVIEWS button - ENABLED (opens match details)
      return GestureDetector(
        onTap: () {
          _showMatchDetailsModal(fixture);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: hasUserVoted
                ? FanColors.primary.withValues(alpha: 0.1)
                : FanColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.rate_review,
                size: 14,
                color:
                    hasUserVoted ? FanColors.primary : FanColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'reviews',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: hasUserVoted
                      ? FanColors.primary
                      : FanColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Default fallback - opens match details
      return GestureDetector(
        onTap: () {
          _showMatchDetailsModal(fixture);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: FanColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: FanColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'details',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: FanColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
  // Helper method for the status button (changes based on match state)

  // Helper method for pulsing badge
  Widget _buildPulsingBadge(int count, String fixtureId) {
    return AnimatedBuilder(
      animation: _badgeTimers.containsKey(fixtureId)
          ? _badgeTimers[fixtureId]!
          : const AlwaysStoppedAnimation(1.0),
      builder: (context, child) {
        double scale = 1.0;
        if (_badgeTimers.containsKey(fixtureId)) {
          scale = 0.8 + (_badgeTimers[fixtureId]!.value * 0.5);
        }
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            constraints: const BoxConstraints(minWidth: 16),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Add this method to your _FixturesPageState
  // Add goal handler
  void _onGoalReceived(
    String fixtureId,
    int homeScore,
    int awayScore,
    int minute,
    String scorer,
  ) {
    _safeSetState(() {
      // Update fixture scores
      final index = _fixtures.indexWhere((f) => f.matchId == fixtureId);
      if (index != -1) {
        // _fixtures[index].homeScore = homeScore;
        // _fixtures[index].awayScore = awayScore;
      }

      // Add to timeline
      final timelineEvent = {
        'event_type': 'goal',
        'data': {
          'minute': minute,
          'scorer': scorer,
          'home_score': homeScore,
          'away_score': awayScore,
          'score_display': '$homeScore-$awayScore',
        },
      };

      // Add to local timeline cache if you have one
      // _timelineEvents[fixtureId] = [timelineEvent, ...(_timelineEvents[fixtureId] ?? [])];
    });

    // Show toast or snackbar
    ToastHelper.showInfo("⚽ GOAL! $scorer scores at $minute'");
  }

  // Add match status handler
  void _onMatchStatusUpdate(String fixtureId, String status) {
    // Don't modify final fields - just refresh from API
    _fetchFixtures(forceRefresh: true, showNotification: false);
  }

  void _onNewCommentReceived(
    String fixtureId,
    String comment,
    String username,
    String? selection,
  ) {
    debugPrint("🔔 New comment received for fixture $fixtureId");

    _safeSetState(() {
      // Update comment count
      final currentCount = _commentCounts[fixtureId] ?? 0;
      _commentCounts[fixtureId] = currentCount + 1;

      // Add to local comment list for instant display
      final newComment = FixtureComment(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        userId: username,
        username: username,
        fixtureId: fixtureId,
        comment: comment,
        selection: selection,
        timestamp: DateTime.now(),
      );

      _fixtureComments[fixtureId] = [
        newComment,
        ...(_fixtureComments[fixtureId] ?? []),
      ];

      // Update unread count
      _unreadCounts[fixtureId] = (_unreadCounts[fixtureId] ?? 0) + 1;
    });

    _startPulsingAnimation(fixtureId);
    _saveToGlobalCache();
    _fetchCommentsForFixture(fixtureId, forceRefresh: true);
  }

  Future<void> _fetchCommentsForFixture(
    String fixtureId, {
    bool forceRefresh = false,
  }) async {
    if (_loadingComments[fixtureId] == true) return;

    _safeSetState(() => _loadingComments[fixtureId] = true);

    try {
      // Get channel ID
      final String? channelId =
          _fixtureChannelOverrides[fixtureId]?.channelId ??
              _localSelectedChannel?.channelId ??
              (_userChannels.isNotEmpty ? _userChannels.first.channelId : null);

      if (channelId == null) {
        debugPrint(
            '⚠️ No channelId available for fetching comments for fixture $fixtureId');
        _safeSetState(() => _loadingComments[fixtureId] = false);
        return;
      }

      // Use the chat endpoint (matches ChatScreen)
      final response = await http
          .get(
            Uri.parse(
                '$API_BASE_URL/channels/messages?channel_id=$channelId&fixture_id=$fixtureId&limit=100'),
            headers: await _buildHeaders(),
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> messagesData = data['messages'] ?? [];

        final List<FixtureComment> freshComments = [];
        for (var item in messagesData) {
          // Get message ID
          String id = item['message_id'] ?? '';
          if (id.isEmpty) {
            final idObj = item['_id'];
            if (idObj is Map && idObj['\$oid'] != null) {
              id = idObj['\$oid'];
            } else if (idObj is String) {
              id = idObj;
            }
          }

          // Parse timestamp
          DateTime timestamp;
          final sentAt = item['sent_at'];
          if (sentAt is Map) {
            final dateObj = sentAt['\$date'];
            if (dateObj is Map && dateObj['\$numberLong'] != null) {
              final milliseconds =
                  int.parse(dateObj['\$numberLong'].toString());
              timestamp = DateTime.fromMillisecondsSinceEpoch(milliseconds);
            } else if (dateObj is String) {
              timestamp = DateTime.parse(dateObj);
            } else {
              timestamp = DateTime.now();
            }
          } else if (sentAt is String) {
            timestamp = DateTime.parse(sentAt);
          } else {
            timestamp = DateTime.now();
          }

          final comment = FixtureComment(
            id: id,
            userId: item['sender_id']?.toString() ?? '',
            username: item['sender_name']?.toString() ?? 'Anonymous',
            fixtureId: fixtureId,
            comment: item['text']?.toString() ?? '',
            selection: item['selection']?.toString(),
            timestamp: timestamp,
          );
          freshComments.add(comment);
        }

        // Sort by timestamp (newest first)
        freshComments.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        _safeSetState(() {
          _fixtureComments[fixtureId] = freshComments;
          _commentCounts[fixtureId] = freshComments.length;
          _loadingComments[fixtureId] = false;
        });

        // Save to cache
        await LocalStorageManager.saveCommentsForFixture(
            fixtureId, freshComments);
        _saveToGlobalCache();

        debugPrint(
            '✅ Loaded ${freshComments.length} comments for fixture $fixtureId');
      } else {
        debugPrint('⚠️ Failed to fetch comments: ${response.statusCode}');
        _safeSetState(() => _loadingComments[fixtureId] = false);
      }
    } catch (e) {
      debugPrint('❌ Error fetching comments for fixture $fixtureId: $e');
      _safeSetState(() => _loadingComments[fixtureId] = false);
    }
  }

  // Helper method for pulsing badge

  // ========== MATCH DETAILS MODAL (Timeline, Stats, Lineups) ==========
  void _onWatchPressed(Fixture fixture) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MatchDetailsModal(
        fixture: fixture,
        userId: widget.userId,
        username: widget.username,
        authToken: widget.authToken,
      ),
    );
  }

  void _showMatchDetailsModal(Fixture fixture) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MatchDetailsModal(
        fixture: fixture,
        userId: widget.userId,
        username: widget.username,
        authToken: widget.authToken,
      ),
    );
  }

  Future<void> _openChatScreen(Fixture fixture) async {
    if (!_isUserLoggedIn()) {
      _showLoginModal();
      return;
    }
    if (_userChannels.isEmpty) {
      _showJoinGroupsModal();
      return;
    }

    final fixtureId = fixture.matchId;
    final String? channelId = _resolveChannelIdFor(fixtureId);
    if (channelId == null) {
      debugPrint('❌ No channel ID found for fixture $fixtureId');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to open chat: No channel selected')),
      );
      return;
    }

    final channelName = _userChannels
        .firstWhere((c) => c.channelId == channelId,
            orElse: () => _userChannels.first)
        .name;

    debugPrint(
        '🔗 Opening chat for fixture $fixtureId with channel: $channelName ($channelId)');

    _isReturningFromChat = true;
    _refreshedAfterChat.remove(fixtureId);

    // ✅ Clear unread state locally + fire the read-receipt in the background —
    // do NOT block the screen transition on a network round trip.
    _safeSetState(() {
      _unreadCounts[fixtureId] = 0;
    });
    _stopPulsingAnimation(fixtureId);
    unawaited(markChatAsRead(channelId, fixtureId, widget.userId));

    final userVote = _userVotes[fixtureId];

    final chatScreen = ChatScreen(
      channelId: channelId,
      fixtureId: fixtureId,
      fixture: fixture,
      userId: widget.userId,
      username: widget.username,
      authToken: widget.authToken,
      isLoggedIn: _isUserLoggedIn(),
      comradesList: _userComrades,
      userVoteSelection: userVote,
    );

    // ✅ Wide screens (desktop web) get a modal dialog; mobile app and
    // narrow/mobile web keep the existing full-page push behavior.
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth >= 900;

    final Future<dynamic> navigationFuture = isWideScreen
        ? showDialog(
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
          )
        : Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => chatScreen,
            ),
          );

    unawaited(_ensureChannelFixture(channelId, fixtureId));

    await navigationFuture;

    await _refreshAfterChatReturn(fixtureId);
    _isReturningFromChat = false;
    _refreshedAfterChat.add(fixtureId);
    _safeSetState(() {});
  }

  Future<void> _executeMatchFromDialog(
    Bettor pledger,
    String selection,
    Fixture fixture,
    VoidCallback onRefresh,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/actions/bet/fill'),
            headers: await _buildHeaders(),
            body: json.encode({
              'bet_id': pledger.betId,
              'finisher_id': widget.userId,
              'finisher_name': widget.username,
              'finisher_selection': selection,
              'amount': pledger.amount,
              'channel_id': '', // ✅ Send empty string
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (data['success'] == true) {
        ToastHelper.showSuccess('✅ Bet matched successfully! 🎉');

        // ✅ Refresh both pledges and bettors
        await _refreshPledgeDataForFixture(fixture.matchId);
        await _refreshBettorsForFixture(fixture.matchId);

        onRefresh();
      } else {
        ToastHelper.showError(data['message'] ?? 'Failed to match bet');
      }
    } catch (e) {
      ToastHelper.showError('Error: ${e.toString()}');
    }
  }

  Future<void> _refreshPledgeDataForFixture(String fixtureId) async {
    try {
      final String? channelId =
          _fixtureChannelOverrides[fixtureId]?.channelId ??
              _localSelectedChannel?.channelId ??
              (_userChannels.isNotEmpty ? _userChannels.first.channelId : null);

      if (channelId == null) {
        return;
      }

      // Load pledges
      final pledgesResponse = await http
          .get(
            Uri.parse(
                '$API_BASE_URL/actions/channel/$channelId/$fixtureId/pledges'),
            headers: await _buildHeaders(),
          )
          .timeout(REQUEST_TIMEOUT);

      if (pledgesResponse.statusCode == 200) {
        final data = json.decode(pledgesResponse.body);
        final List<dynamic> pledgesData = data['pledges'] ?? [];
        final count = data['count'] ?? 0;

        _safeSetState(() {
          _pledgeCounts[fixtureId] = count;
          _pledgers[fixtureId] =
              pledgesData.map((p) => Bettor.fromOpenBet(p)).toList();
        });

        _saveToGlobalCache();
      }

      // ✅ ALSO LOAD BETTORS (MATCHED BETS)
      await _loadBettorsForFixture(fixtureId);
    } catch (e) {
      debugPrint('❌ Error refreshing pledge data: $e');
    }
  }

  // Add this method to _FixturesPageState
  Future<void> _loadBettorsForFixture(String fixtureId) async {
    try {
      final String? channelId =
          _fixtureChannelOverrides[fixtureId]?.channelId ??
              _localSelectedChannel?.channelId ??
              (_userChannels.isNotEmpty ? _userChannels.first.channelId : null);

      if (channelId == null) {
        return;
      }

      final response = await http
          .get(
            Uri.parse(
                '$API_BASE_URL/actions/channel/$channelId/$fixtureId/bettors'),
            headers: await _buildHeaders(),
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> bettorsData = data['bettors'] ?? [];

        // Parse bettors using Bettor.fromMatchedBet for matched bets
        final List<Bettor> bettors = [];
        for (var betData in bettorsData) {
          // Check if it's a matched bet (has finisher)
          if (betData['finisher_id'] != null &&
              betData['finisher_id'].toString().isNotEmpty) {
            bettors.add(Bettor.fromMatchedBet(betData, widget.userId));
          }
        }

        _safeSetState(() {
          _bettors[fixtureId] = bettors;
        });

        debugPrint('✅ Loaded ${bettors.length} bettors for fixture $fixtureId');
      }
    } catch (e) {
      debugPrint('❌ Error loading bettors for fixture $fixtureId: $e');
    }
  }

  // Add this method to refresh bettors after a bet is matched
  Future<void> _refreshBettorsForFixture(String fixtureId) async {
    await _loadBettorsForFixture(fixtureId);
    _safeSetState(() {});
  }

  void _showMatchConfirmationInDialog(
    BuildContext dialogContext,
    Bettor pledger,
    Fixture fixture,
    VoidCallback onRefresh,
  ) {
    String? selectedOption;
    bool isProcessing = false;

    // Get opposite selection only
    final String oppositeSelection;
    final String oppositeTitle;
    final Color oppositeColor;

    if (pledger.selection == 'home_team' || pledger.selection == 'home') {
      oppositeSelection = 'away';
      oppositeTitle = fixture.awayTeam;
      oppositeColor = const Color(0xFF2563EB);
    } else if (pledger.selection == 'away_team' ||
        pledger.selection == 'away') {
      oppositeSelection = 'home';
      oppositeTitle = fixture.homeTeam;
      oppositeColor = FanColors.primary;
    } else {
      // If draw, show both options
      // _showDrawMatchConfirmation(dialogContext, pledger, fixture, onRefresh);
      return;
    }

    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: FanColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FanRadius.lg),
            ),
            title: const Text('Match Pledge'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FanColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: FanColors.border.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pledger: ${pledger.userName}',
                        style: TextStyle(color: FanColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Their pick: ${pledger.selectionDisplay}',
                        style: TextStyle(color: FanColors.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Amount: KES ${pledger.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: FanColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You must pick the opposite team:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () =>
                      setState(() => selectedOption = oppositeSelection),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selectedOption == oppositeSelection
                          ? oppositeColor.withOpacity(0.15)
                          : FanColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selectedOption == oppositeSelection
                            ? oppositeColor
                            : FanColors.border.withOpacity(0.3),
                        width: selectedOption == oppositeSelection ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        oppositeTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selectedOption == oppositeSelection
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: selectedOption == oppositeSelection
                              ? oppositeColor
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.block, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You cannot pick ${pledger.selectionDisplay} (already taken)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Vote will be auto-cast if you haven\'t voted yet',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  selectedOption = null;
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedOption == null
                    ? null
                    : () async {
                        setState(() => isProcessing = true);
                        await _executeMatchFromDialog(
                          pledger,
                          selectedOption!,
                          fixture,
                          onRefresh,
                        );
                        setState(() => isProcessing = false);
                        Navigator.pop(context); // Close match dialog
                        Navigator.pop(context); // Close pledges dialog
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FanColors.primary,
                ),
                child: isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Confirm Match'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _refreshAfterChatReturn(String fixtureId) async {
    debugPrint(
        '🔄 Silently refreshing data after returning from chat for fixture: $fixtureId');

    try {
      final fixture = _fixtures.firstWhere((f) => f.matchId == fixtureId);

      final String? channelId =
          _fixtureChannelOverrides[fixtureId]?.channelId ??
              _localSelectedChannel?.channelId ??
              (_userChannels.isNotEmpty ? _userChannels.first.channelId : null);

      if (channelId != null) {
        // ✅ FETCH FRESH COMMENT COUNT
        final freshCount =
            await _fetchCommentCountViaHttp(fixtureId, channelId: channelId);

        if (freshCount != null) {
          // ✅ STORE IN PENDING COUNTS (to survive cache reload)
          _pendingCommentCounts[fixtureId] = freshCount;

          // ✅ UPDATE LOCAL STATE IMMEDIATELY
          _safeSetState(() {
            _commentCounts[fixtureId] = freshCount;
          });

          // ✅ UPDATE APPCACHE
          AppCache.applyUpdate(
            fixtureId: fixtureId,
            updateType: 'comment',
            value: freshCount,
            extraData: {'channelId': channelId},
          );
          await AppCache.saveCommentCount(fixtureId, freshCount);
        }

        // ✅ FETCH LATEST COMMENT
        await _fetchLatestCommentViaHttpWithChannel(
            fixtureId, fixture, channelId);

        // ✅ FETCH VOTE COUNT
        await _fetchVoteCountViaHttp(fixtureId, channelId: channelId);
      }

      // ✅ FETCH UNREAD COUNT
      if (channelId != null && _isUserLoggedIn()) {
        final unreadCount =
            await getUnreadCount(channelId, fixtureId, widget.userId);
        _safeSetState(() {
          _unreadCounts[fixtureId] = unreadCount;
        });
        if (unreadCount == 0) {
          _stopPulsingAnimation(fixtureId);
        }
      }

      // ✅ REGENERATE FEATURED COMMENT
      await _generateFeaturedCommentForFixture(fixture);

      // ✅ SAVE TO DISK
      _saveToGlobalCache();
      await _saveChannelFixturesToCache(_channelFixtureDataMap);

      // ✅ MARK AS REFRESHED
      _refreshedAfterChat.add(fixtureId);

      debugPrint(
          '✅ Silent refresh after chat complete for fixture: $fixtureId - Count: ${_commentCounts[fixtureId]}');
    } catch (e) {
      debugPrint('❌ Error in silent refresh after chat: $e');
    }
  }

  Future<void> _fetchLatestCommentViaHttpWithChannel(
      String fixtureId, Fixture fixture, String channelId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
                '$API_BASE_URL/channels/$channelId/fixtures/$fixtureId/comments/latest'),
            headers: await _buildHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final latestComment = data['latest_comment'];

        _safeSetState(() {
          if (latestComment != null) {
            // Real comment exists - store it
            final commentText = latestComment['comment']?.toString() ?? '';
            final username = latestComment['username']?.toString() ?? 'Fan';
            final userId = latestComment['user_id']?.toString() ?? '';
            final selection = latestComment['selection']?.toString();

            DateTime timestamp;
            try {
              timestamp = DateTime.parse(
                  latestComment['timestamp']?.toString() ??
                      DateTime.now().toIso8601String());
            } catch (e) {
              timestamp = DateTime.now();
            }

            _featuredComments[fixtureId] = FeaturedComment(
              userId: userId,
              username: username,
              comment: commentText,
              teamSupport: _getTeamSupportForUser(selection, fixture),
              avatarUrl: '',
              timestamp: timestamp,
            );
            debugPrint(
                '💬 REAL latest comment for $fixtureId in channel $channelId: "$commentText"');
          } else {
            // No comments in this channel - remove any existing comment
            _featuredComments.remove(fixtureId);
            debugPrint(
                '📭 No comments for fixture $fixtureId in channel $channelId');
          }
        });
      }
    } catch (e) {
      debugPrint(
          '⚠️ Error fetching latest comment for $fixtureId with channel $channelId: $e');
    }
  }

  // Option A: Remove this method entirely
// Option B: Change to request via WebSocket
  Future<void> _refreshCommentCountOnly(String fixtureId) async {
    // Don't use HTTP - wait for WebSocket comment.count
    // Or request via WebSocket if backend supports it
    final ws = WebSocketService();
    if (ws.isConnected) {
      ws.send('get.comment.count', {'fixtureId': fixtureId});
    }
  }

  Future<void> _showVoteConfirmationDialog(
    Fixture fixture,
    String selection,
    int index,
  ) async {
    if (!_isUserLoggedIn()) {
      _showLoginModal();
      return;
    }

    if (_userChannels.isEmpty) {
      _showJoinGroupsModal();
      return;
    }

    final fixtureId = fixture.matchId;

    final hasVoted = await _checkUserVotedOnServer(fixtureId);
    if (hasVoted) {
      ToastHelper.showWarning('You have already voted for this fixture');
      await _fetchUserVotesFromBackend();
      return;
    }

    if (_userVotes.containsKey(fixtureId)) {
      ToastHelper.showWarning('You have already voted for this fixture');
      return;
    }

    final teamName = selection == 'home_team'
        ? fixture.homeTeam
        : selection == 'away_team'
            ? fixture.awayTeam
            : 'Draw';

    final odds = selection == 'home_team'
        ? fixture.homeWin
        : selection == 'away_team'
            ? fixture.awayWin
            : fixture.draw;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: FanColors.background, // ✅ Changed
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.how_to_vote,
                color: FanColors.primary, size: 24), // ✅ Changed
            const SizedBox(width: 12),
            Text(
              'Confirm Your Vote',
              style: TextStyle(
                color: FanColors.textPrimary, // ✅ Changed
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FanColors.surface, // ✅ Changed
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: FanColors.primary.withValues(alpha: 0.3), // ✅ Changed
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${fixture.homeTeam} vs ${fixture.awayTeam}',
                    style: TextStyle(
                      color: FanColors.textPrimary, // ✅ Changed
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(
                      color:
                          FanColors.border.withValues(alpha: 0.3)), // ✅ Changed
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your selection:',
                        style: TextStyle(
                          color: FanColors.textSecondary, // ✅ Changed
                          fontSize: 13,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _getVoteColor(selection).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          teamName.toUpperCase(),
                          style: TextStyle(
                            color: _getVoteColor(selection),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Odds:',
                        style: TextStyle(
                          color: FanColors.textSecondary, // ✅ Changed
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        odds.toStringAsFixed(2),
                        style: TextStyle(
                          color: FanColors.primary, // ✅ Changed
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FanColors.draw.withValues(alpha: 0.1), // ✅ Changed
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: FanColors.draw), // ✅ Changed
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. You cannot change your vote after submission.',
                      style: TextStyle(
                          fontSize: 11, color: FanColors.draw), // ✅ Changed
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'CANCEL',
              style: TextStyle(
                color: FanColors.textSecondary, // ✅ Changed
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: FanColors.primary, // ✅ Changed
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'CONFIRM',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _processVote(fixture, selection, index);
    }
  }

  Future<bool> _checkUserVotedOnServer(String fixtureId) async {
    try {
      // ✅ NEW: No channel_id needed
      final response = await http
          .get(
            Uri.parse(
                '$API_BASE_URL/channels/votes/check/$fixtureId/${widget.userId}'),
            headers: await _buildHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['has_voted'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ Error checking vote status: $e');
      return false;
    }
  }

  // NEW: Vote Dialog with odds
  void _showVoteDialog(Fixture fixture) {
    if (!_isUserLoggedIn()) {
      _showLoginModal();
      return;
    }

    if (_userChannels.isEmpty) {
      _showJoinGroupsModal();
      return;
    }

    final fixtureId = fixture.matchId;
    final hasUserVoted = _userVotes.containsKey(fixtureId);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => VoteCastingModal(
        fixture: fixture,
        userId: widget.userId,
        username: widget.username,
        authToken: widget.authToken,
        isLoggedIn: _isUserLoggedIn(),
        hasUserVoted: hasUserVoted,
        userVoteSelection: _userVotes[fixtureId],
        onVote: (selection) => _processVote(fixture, selection, 0),
      ),
    );
  }

  Widget _buildVoteOption({
    required String title,
    required double odds,
    required String selection,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                odds.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
// CHANNEL-BASED METHODS (Add to _FixturesPageState)
// ==========================================================================

  Future<Map<String, ChannelFixtureData>> _getBatchChannelVotes(
      String channelId) async {
    if (widget.authToken == null || _fixtures.isEmpty) return {};

    final fixtureIds = _fixtures.map((f) => f.matchId).toList();

    try {
      final response = await http
          .post(
            Uri.parse(
                '$API_BASE_URL/channels/channel/$channelId/fixtures/votes/batch'),
            headers: {
              'Authorization': 'Bearer ${widget.authToken}',
              'Content-Type': 'application/json',
            },
            body: json.encode({'fixture_ids': fixtureIds}),
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final Map<String, ChannelFixtureData> result = {};
        if (data['data'] is List) {
          for (var item in data['data']) {
            final voteData = ChannelFixtureData.fromJson(item);
            result[voteData.fixtureId] = voteData;
          }
        }
        return result;
      }
      return {};
    } catch (e) {
      debugPrint('Error getting batch votes: $e');
      return {};
    }
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      height: 250,
      color: FanColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: FanColors.primary,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading fixtures...',
              style: FanTypography.body.copyWith(
                color: FanColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      height: 250,
      color: FanColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: FanColors.surfaceSunken,
                  shape: BoxShape.circle,
                  border: Border.all(color: FanColors.border),
                ),
                child: Center(
                  child: Icon(
                    Icons.error_outline,
                    color: FanColors.primary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Failed to load fixtures',
                style: FanTypography.headline.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                _error,
                style: FanTypography.body.copyWith(
                  color: FanColors.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _fetchFixtures(forceRefresh: true),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: FanDecorations.primaryButton,
                  child: Center(
                    child: Text(
                      'Try Again',
                      style: FanTypography.button.copyWith(
                        color: FanColors.textInverse,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
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

  Future<bool> _hasUserProfile() async {
    try {
      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/profile/profile/${widget.userId}'),
            headers: await _buildHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('🔍 Profile check response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic jsonData = json.decode(response.body);

        Map<String, dynamic> profileData = {};

        if (jsonData is Map) {
          profileData = Map<String, dynamic>.from(jsonData);
        } else if (jsonData is List && jsonData.isNotEmpty) {
          for (var profile in jsonData) {
            if (profile is Map) {
              final userId = profile['user_id']?.toString() ??
                  profile['userId']?.toString() ??
                  '';
              if (userId == widget.userId) {
                profileData = Map<String, dynamic>.from(profile);
                break;
              }
            }
          }
        }

        final hasNickname = profileData['nickname'] != null &&
            profileData['nickname'].toString().isNotEmpty &&
            profileData['nickname'].toString() != 'null';

        final hasClub = profileData['club_fan'] != null &&
            profileData['club_fan'].toString().isNotEmpty &&
            profileData['club_fan'].toString() != 'null';

        final hasCountry = profileData['country_fan'] != null &&
            profileData['country_fan'].toString().isNotEmpty &&
            profileData['country_fan'].toString() != 'null';

        debugPrint(
          '📋 Has nickname: $hasNickname, club: $hasClub, country: $hasCountry',
        );

        if (profileData.isNotEmpty) {
          return hasNickname && hasClub && hasCountry;
        }

        return false;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error checking user profile: $e');
      return false;
    }
  }

  void _showProfileModalForVote({VoidCallback? onComplete}) async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phone') ?? '';

    debugPrint('🔍🔍🔍 Phone from SharedPreferences: "$phone"');

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => SwipeableProfileModal(
          apiBaseUrl: API_BASE_URL.replaceAll('/api', ''),
          userId: widget.userId,
          username: widget.username,
          phone: phone,
          onUserUpdated: (userData) async {
            debugPrint('[PROFILE] Saved: ${userData.nickname}');
            Navigator.pop(context);
            if (onComplete != null) {
              onComplete();
            } else {
              await _refreshUserData();
              setState(() {});
            }
          },
          onLogout: () {},
        ),
      );
    }
  }

  Future<String> _getUserPhone() async {
    try {
      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/auth/user/id/${widget.userId}'),
            headers: await _buildHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final phone = data['user']['phone']?.toString() ?? '';
          debugPrint('📞 Fetched phone for pledge: "$phone"');
          return phone;
        }
      } else {
        debugPrint('⚠️ Failed to fetch phone: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error getting phone: $e');
    }
    return '';
  }

  Future<void> _forceReloadRivalsAndSupporters() async {
    debugPrint('🔄 Force reloading rivals and supporters...');

    try {
      final allVotes = await VoteService.fetchAllVotes();
      final organizedData = VoteService.organizeVotesByFixture(
        allVotes,
        widget.userId,
      );

      _safeSetState(() {
        _fixtureVoteData = organizedData;
      });

      // Force another rebuild to update comrade buttons
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _safeSetState(() {});
        }
      });

      for (var entry in organizedData.entries) {
        if (entry.value.currentUserSelection != null) {
          _userVotes[entry.key] = entry.value.currentUserSelection;
        }
      }

      _saveToGlobalCache();
      debugPrint(
        '✅ Force reloaded ${organizedData.length} fixture vote data entries',
      );
    } catch (e) {
      debugPrint('❌ Error force reloading rivals/supporters: $e');
    }
  }

  void _debugComradeStatus() {
    debugPrint('========== COMRADE DEBUG ==========');
    debugPrint('User logged in: ${_isUserLoggedIn()}');
    debugPrint('User ID: ${widget.userId}');
    debugPrint('User comrades count: ${_userComrades.length}');
    debugPrint('User comrades list: $_userComrades');
    debugPrint('Comrade voters map size: ${_comradeVoters.length}');
    for (var entry in _comradeVoters.entries) {
      debugPrint('  Fixture ${entry.key}: ${entry.value.length} comrades');
    }
    debugPrint('===================================');
  }

  void _toggleSubFixturesExpanded(String fixtureId) {
    _safeSetState(() {
      _subFixturesExpanded[fixtureId] =
          !(_subFixturesExpanded[fixtureId] ?? false);
    });
  }

  // Helper method to get vote button color based on user's vote or team colors
  Color _getVoteButtonColor(Fixture fixture, String? userVote) {
    if (userVote == 'home_team') {
      return FanColors.primary; // ✅ Changed
    } else if (userVote == 'away_team') {
      return const Color(0xFF2563EB);
    } else if (userVote == 'draw') {
      return const Color(0xFF8B5CF6);
    }

    final hashCode = fixture.matchId.hashCode;
    if (hashCode % 2 == 0) {
      return FanColors.primary; // ✅ Changed
    } else {
      return const Color(0xFF2563EB);
    }
  }

  // Helper for the team column
  Widget _buildTeamColumn({
    required String abbr,
    required String name,
    required bool isVoted,
  }) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isVoted
                ? FanColors.primary.withValues(alpha: 0.1)
                : FanColors.surface.withValues(alpha: 0.4),
          ),
          child: Center(
            child: Text(
              abbr,
              style: FanTypography.body.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isVoted ? FanColors.primary : FanColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 90,
          child: Text(
            name,
            style: FanTypography.tag.copyWith(
              fontSize: 11,
              color: FanColors.textSecondary,
              fontWeight: isVoted ? FontWeight.w600 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // Helper method to get total votes for a fixture
  int _totalVotesForFixture(String fixtureId) {
    return _voteCounts[fixtureId] ?? 0;
  }

  Widget _buildFixturesList() {
    // Filter out completed fixtures
    final sortedFixtures = List<Fixture>.from(_fixtures)
      ..removeWhere((f) => f.status == 'completed' || f.status == 'finished')
      ..sort((a, b) {
        final aKey = '${a.dateIso}_${a.time}';
        final bKey = '${b.dateIso}_${b.time}';
        return aKey.compareTo(bKey);
      });

    if (sortedFixtures.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedFixtures
          .map((f) => _buildMatchCard(context, f, _fixtures.indexOf(f)))
          .toList(),
    );
  }

// Helper methods
  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const Spacer(),
          Text(
            '${_getCountForStatus(title)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  int _getCountForStatus(String title) {
    if (title.contains('LIVE')) {
      return _fixtures.where((f) => f.status == 'live').length;
    } else if (title.contains('SOON')) {
      return _fixtures.where((f) => f.status == 'soon').length;
    } else if (title.contains('UPCOMING')) {
      return _fixtures.where((f) => f.status == 'upcoming').length;
    }
    return 0;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.sports_soccer, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 12),
            Text(
              'No upcoming matches',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Check back later for new fixtures',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
