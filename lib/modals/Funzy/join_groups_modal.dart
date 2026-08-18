// lib/modals/Funzy/join_groups_modal.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../models/user_channel.dart';
import '../../services/web_soecket.dart';
// Import your design file - this contains FanColors, FanTypography, etc.
import '../../pages/fan_Funzy_design.dart';

class JoinGroupsModal extends StatefulWidget {
  final String userId;
  final String username;
  final String? authToken;
  final List<UserChannel> userChannels;
  final Set<String> pendingRequests;
  final VoidCallback onClose;
  final Function(String) onChannelJoined;

  const JoinGroupsModal({
    super.key,
    required this.userId,
    required this.username,
    this.authToken,
    required this.userChannels,
    required this.pendingRequests,
    required this.onClose,
    required this.onChannelJoined,
  });

  @override
  State<JoinGroupsModal> createState() => _JoinGroupsModalState();
}

class _JoinGroupsModalState extends State<JoinGroupsModal> {
  List<UserChannel> _availableChannels = [];
  bool _loading = true;
  bool _joining = false;
  String? _joiningChannelId;
  Set<String> _pendingRequests = {};

  // ✅ Maximum channels a user can be in
  static const int MAX_CHANNELS = 3;

  static const String API_BASE_URL = 'https://clash-api-m5mr.onrender.com/api';

  @override
  void initState() {
    super.initState();
    _pendingRequests = Set.from(widget.pendingRequests);
    _fetchAvailableChannels();
    _setupWebSocketListener();
  }

  void _setupWebSocketListener() {
    final ws = WebSocketService();

    ws.on('join_approved', (data) {
      final channelId = data['channel_id']?.toString();
      if (channelId != null && mounted) {
        setState(() {
          _pendingRequests.remove(channelId);
        });
        widget.onChannelJoined(channelId);
      }
    });

    ws.on('join_rejected', (data) {
      final channelId = data['channel_id']?.toString();
      if (channelId != null && mounted) {
        setState(() {
          _pendingRequests.remove(channelId);
        });
        final channelName = data['channel_name']?.toString() ?? 'Unknown';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Request to join "$channelName" was declined'),
            backgroundColor: FanColors.away,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    ws.on('join_request_status', (data) {
      final channelId = data['channel_id']?.toString();
      final status = data['status']?.toString();

      if (channelId != null && mounted) {
        if (status == 'approved') {
          setState(() {
            _pendingRequests.remove(channelId);
          });
          widget.onChannelJoined(channelId);
        } else if (status == 'rejected') {
          setState(() {
            _pendingRequests.remove(channelId);
          });
        }
      }
    });
  }

  Future<void> _fetchAvailableChannels() async {
    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/channels/all'),
        headers: {
          'Authorization': 'Bearer ${widget.authToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> channelsData = data['channels'] ?? [];

        final userChannelIds =
            widget.userChannels.map((c) => c.channelId).toSet();
        _availableChannels = channelsData
            .map((c) => UserChannel.fromJson(c as Map<String, dynamic>))
            .where((c) => !userChannelIds.contains(c.channelId))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching channels: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ✅ Check if user can join more channels
  bool _canJoinMoreChannels() {
    // Count only approved channels (not pending)
    final approvedChannels =
        widget.userChannels.where((c) => c.isApproved == true).length;

    return approvedChannels < MAX_CHANNELS;
  }

  // ✅ Get remaining channel slots
  int _getRemainingSlots() {
    final approvedChannels =
        widget.userChannels.where((c) => c.isApproved == true).length;

    return MAX_CHANNELS - approvedChannels;
  }

  // ✅ Get current channel count
  int _getCurrentChannelCount() {
    return widget.userChannels.where((c) => c.isApproved == true).length;
  }

  Future<void> _requestJoinChannel(UserChannel channel) async {
    // ✅ Check if user has reached max channels
    if (!_canJoinMoreChannels()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ You can only join up to $MAX_CHANNELS channels. Leave a channel to join another.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: FanColors.away,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: FanRadius.lgAll),
        ),
      );
      return;
    }

    if (_joining || _pendingRequests.contains(channel.channelId)) return;

    setState(() {
      _joining = true;
      _joiningChannelId = channel.channelId;
    });

    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/channels/request-join'),
        headers: {
          'Authorization': 'Bearer ${widget.authToken}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'channel_id': channel.channelId,
          'user_id': widget.userId,
          'username': widget.username,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _pendingRequests.add(channel.channelId);
        });

        final prefs = await SharedPreferences.getInstance();
        final pending =
            prefs.getStringList('pending_join_requests_${widget.userId}') ?? [];
        if (!pending.contains(channel.channelId)) {
          pending.add(channel.channelId);
          await prefs.setStringList(
              'pending_join_requests_${widget.userId}', pending);
        }

        final ws = WebSocketService();
        if (ws.isConnected) {
          ws.send('join.request', {
            'channel_id': channel.channelId,
            'user_id': widget.userId,
            'username': widget.username,
            'channel_name': channel.name,
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📨 Join request sent to "${channel.name}" admin!'),
            backgroundColor: FanColors.primary,
            duration: const Duration(seconds: 3),
          ),
        );

        widget.onChannelJoined(channel.channelId);
      } else {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to send request'),
            backgroundColor: FanColors.away,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: FanColors.away,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _joining = false;
          _joiningChannelId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final remainingSlots = _getRemainingSlots();
    final canJoin = _canJoinMoreChannels();
    final currentCount = _getCurrentChannelCount();

    return Container(
      height: screenHeight * 0.75,
      decoration: BoxDecoration(
        color: FanColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(FanRadius.xl),
          topRight: Radius.circular(FanRadius.xl),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: FanColors.border.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header with channel limit indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A3E),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(Icons.group_add,
                        size: 22, color: FanColors.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Join a Channel',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '$currentCount / $MAX_CHANNELS channels • ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: canJoin
                                  ? FanColors.primary.withValues(alpha: 0.2)
                                  : FanColors.away.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              canJoin ? '$remainingSlots slots left' : 'FULL',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: canJoin
                                    ? FanColors.primary
                                    : FanColors.away,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: widget.onClose,
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

          // Info text with warning if at limit
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: canJoin
                    ? FanColors.primary.withValues(alpha: 0.06)
                    : FanColors.away.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: canJoin
                      ? FanColors.primary.withValues(alpha: 0.15)
                      : FanColors.away.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    canJoin ? Icons.info_outline : Icons.warning_amber_rounded,
                    size: 16,
                    color: canJoin ? FanColors.primary : FanColors.away,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      canJoin
                          ? 'Join a group to vote, comment, and like. Your request will be sent to the group admin for approval.'
                          : '⚠️ You have reached the maximum of $MAX_CHANNELS channels. Leave a channel to join another.',
                      style: TextStyle(
                        fontSize: 12,
                        color: canJoin
                            ? Colors.white.withValues(alpha: 0.7)
                            : FanColors.away,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Channel list
          Expanded(
            child: _loading
                ? Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: FanColors.primary,
                      ),
                    ),
                  )
                : _availableChannels.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.group_off,
                                size: 48, color: FanColors.textSecondary),
                            const SizedBox(height: 12),
                            const Text(
                              'No groups available',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Check back later for new groups',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _availableChannels.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: FanColors.border.withValues(alpha: 0.3),
                        ),
                        itemBuilder: (context, index) {
                          final channel = _availableChannels[index];
                          final isPending =
                              _pendingRequests.contains(channel.channelId);
                          final isJoining = _joining &&
                              _joiningChannelId == channel.channelId;
                          final isDisabled =
                              !canJoin && !isPending && !isJoining;

                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                // Channel avatar
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1A1A3E),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      channel.name[0].toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: FanColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Channel info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        channel.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDisabled
                                              ? Colors.white
                                                  .withValues(alpha: 0.4)
                                              : Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.people,
                                            size: 12,
                                            color: isDisabled
                                                ? Colors.white
                                                    .withValues(alpha: 0.2)
                                                : Colors.white
                                                    .withValues(alpha: 0.5),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${channel.memberCount} members',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDisabled
                                                  ? Colors.white
                                                      .withValues(alpha: 0.2)
                                                  : Colors.white
                                                      .withValues(alpha: 0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (channel.name != null &&
                                          channel.name!.isNotEmpty)
                                        Text(
                                          channel.name!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDisabled
                                                ? Colors.white
                                                    .withValues(alpha: 0.2)
                                                : Colors.white
                                                    .withValues(alpha: 0.4),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),

                                // Action button
                                if (isPending)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: FanColors.draw
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: FanColors.draw,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Pending',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: FanColors.draw,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (isJoining)
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: FanColors.primary,
                                    ),
                                  )
                                else if (isDisabled)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          FanColors.away.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: FanColors.away
                                            .withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.lock_outline,
                                          size: 12,
                                          color: FanColors.away
                                              .withValues(alpha: 0.6),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'FULL',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: FanColors.away
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  GestureDetector(
                                    onTap: () => _requestJoinChannel(channel),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: FanColors.primary
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: FanColors.primary
                                              .withValues(alpha: 0.4),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'JOIN',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: FanColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Bottom note with channel count
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    canJoin
                        ? 'Requests are reviewed by group admins'
                        : 'Maximum channels reached ($MAX_CHANNELS/$MAX_CHANNELS)',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
