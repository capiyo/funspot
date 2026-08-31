import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../pages/posts_page.dart';
import '../pages/fixture_page.dart';
import 'package:flutter/foundation.dart' show kDebugMode, compute;
import '../modals/login_modal.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, compute;
import '../modals/FAB/add_post_modal.dart';

import '../modals/homepage/notifications_modal.dart';
import '../models/fixture_models.dart' as models;
import '../modals/FAB/profile_modal.dart';
import '../models/user_channel.dart';
import 'package:flutter/services.dart'; // ✅ for SystemChrome / SystemUiOverlayStyle
import '../pages/logs.dart';
//import '../modals/FAB/history_modal.dart';
import '../models/fixture_models.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import '../pages/logs.dart';
import '../pages/fixture_page.dart';
import '../../modals/homepage/admin_dashboard.dart';
import '../models/fixture_models.dart';
import 'dart:io' show Platform;
import '../pages/fan_Funzy_design.dart';
import '../services/comrade_service.dart';
import '../main.dart';
import 'dart:async';
import '../services/notification_service.dart';
import "../modals/homepage/channel_creation.dart";
import '../services/auth_service.dart';
import '../modals/Funzy/leaderboard.dart';
import '../utils/add_helper.dart';
import 'dart:ui' as ui;
import '../modals/Funzy/chat_screen.dart';
import 'package:just_bubble/just_bubble.dart';
import '../modals/FAB/comrade_list.dart';
import "../models/user_channel.dart";
import "../pages/fan_Funzy_design.dart";
import "../modals/Funzy/join_groups_modal.dart";

// ============================================================================
// TOAST HELPER - KEEP EXISTING
// ============================================================================
class ToastHelper {
  static void showSuccess(String message, {BuildContext? context}) {
    debugPrint('✅ $message');
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  static void showError(String message, {BuildContext? context}) {
    debugPrint('❌ $message');
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  static void showWarning(String message, {BuildContext? context}) {
    debugPrint('⚠️ $message');
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

// ============================================================================
// SPEECH BUBBLE - KEEP EXISTING
// ============================================================================
class SpeechBubble extends StatelessWidget {
  final Widget child;

  final bool isLeftAligned;

  const SpeechBubble({
    super.key,
    required this.child,
    this.isLeftAligned = true,
  });

  @override
  Widget build(BuildContext context) {
    return Bubble(
      color: FanColors.primary,
      border: BubbleBorder(
        tail: Tail.triangle(
          alignment: isLeftAligned
              ? BubbleAlignment.bottomLeft
              : BubbleAlignment.bottomRight,
          tailJoin: TailJoin.rounded,
          edgeGap: 8,
        ),
        borderRadius: BorderRadius.circular(12),
        width: 0.5,
        color: FanColors.border.withValues(alpha: 0.3),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: const BoxConstraints(minHeight: 48),
      child: child,
    );
  }
}

// ============================================================================
// ADD TO GROUPS MODAL - KEEP EXISTING
// ============================================================================
class AddToGroupsModal extends StatefulWidget {
  final String comradeId;
  final String comradeName;
  final String comradeUsername;
  final String currentUserId;
  final String? authToken;
  final List<UserChannel> userChannels;
  final Set<String> comradesInGroups;
  final VoidCallback onComradeAdded;

  const AddToGroupsModal({
    super.key,
    required this.comradeId,
    required this.comradeName,
    required this.comradeUsername,
    required this.currentUserId,
    this.authToken,
    required this.userChannels,
    required this.comradesInGroups,
    required this.onComradeAdded,
  });

  @override
  State<AddToGroupsModal> createState() => _AddToGroupsModalState();
}

class _AddToGroupsModalState extends State<AddToGroupsModal> {
  List<String> _selectedChannelIds = [];
  bool _selectAll = false;
  bool _isLoading = false;

  List<UserChannel> get _adminChannels =>
      widget.userChannels.where((c) => c.isAdmin).toList();

  @override
  Widget build(BuildContext context) {
    final adminChannels = _adminChannels;

    if (adminChannels.isEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: FanColors.background,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(FanRadius.xl),
            topRight: Radius.circular(FanRadius.xl),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off, size: 48, color: FanColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'You are not an admin of any channel',
              style: FanTypography.body.copyWith(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a channel first to add comrades',
              style: FanTypography.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                decoration: BoxDecoration(
                  color: FanColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: FanColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.50,
      decoration: BoxDecoration(
        color: FanColors.background,
        borderRadius: BorderRadius.only(
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
                    child: Text(
                      widget.comradeName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: FanColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add ${widget.comradeName}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '@${widget.comradeUsername}',
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
          if (adminChannels.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectAll = !_selectAll;
                    if (_selectAll) {
                      _selectedChannelIds =
                          adminChannels.map((c) => c.channelId).toList();
                    } else {
                      _selectedChannelIds.clear();
                    }
                  });
                },
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color:
                            _selectAll ? FanColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color:
                              _selectAll ? FanColors.primary : FanColors.border,
                          width: 2,
                        ),
                      ),
                      child: _selectAll
                          ? const Icon(Icons.check,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Select All Channels',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: FanColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${adminChannels.length} channels',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: adminChannels.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: FanColors.border.withValues(alpha: 0.3),
              ),
              itemBuilder: (context, index) {
                final channel = adminChannels[index];
                final isSelected =
                    _selectedChannelIds.contains(channel.channelId);
                final isComradeInGroup = widget.comradesInGroups
                    .contains('${widget.comradeId}_${channel.channelId}');

                return GestureDetector(
                  onTap: () {
                    if (isComradeInGroup) return;
                    setState(() {
                      if (isSelected) {
                        _selectedChannelIds.remove(channel.channelId);
                      } else {
                        _selectedChannelIds.add(channel.channelId);
                      }
                      _selectAll =
                          _selectedChannelIds.length == adminChannels.length;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? FanColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: isSelected
                                  ? FanColors.primary
                                  : FanColors.border,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  size: 12, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1A1A3E),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              channel.name[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: FanColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                channel.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Icons.people,
                                    size: 11,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      '${channel.memberCount} members • ${channel.isAdmin ? "Admin" : "Member"}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color:
                                            Colors.white.withValues(alpha: 0.5),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isComradeInGroup)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle,
                                    size: 10, color: Colors.green.shade400),
                                const SizedBox(width: 3),
                                Text(
                                  'Added',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: FanColors.background,
              border: Border(
                top: BorderSide(
                  color: FanColors.border.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          border: Border.all(color: FanColors.border, width: 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectedChannelIds.isEmpty
                          ? null
                          : _addComradeToGroups,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: _selectedChannelIds.isEmpty
                              ? FanColors.surface
                              : FanColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _isLoading
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  _selectedChannelIds.isEmpty
                                      ? 'Select Channels'
                                      : 'Add to ${_selectedChannelIds.length} ${_selectedChannelIds.length == 1 ? 'Channel' : 'Channels'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedChannelIds.isEmpty
                                        ? FanColors.textSecondary
                                        : Colors.white,
                                  ),
                                ),
                              ),
                      ),
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

  Future<void> _addComradeToGroups() async {
    const String API_BASE_URL = 'https://clash-api-m5mr.onrender.com/api';
    if (_selectedChannelIds.isEmpty || widget.authToken == null) return;

    setState(() => _isLoading = true);

    try {
      final List<Map<String, dynamic>> results = [];

      for (final channelId in _selectedChannelIds) {
        final response = await http.post(
          Uri.parse('$API_BASE_URL/channels/members/add'),
          headers: {
            'Authorization': 'Bearer ${widget.authToken}',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'channel_id': channelId,
            'members': [
              {
                'user_id': widget.comradeId,
                'username': widget.comradeUsername,
              }
            ],
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          results.add({
            'channel_id': channelId,
            'success': true,
            'message':
                json.decode(response.body)['message'] ?? 'Added successfully',
          });
        } else {
          results.add({
            'channel_id': channelId,
            'success': false,
            'message': json.decode(response.body)['message'] ?? 'Failed to add',
          });
        }
      }

      setState(() => _isLoading = false);

      final successCount = results.where((r) => r['success']).length;
      final failCount = results.where((r) => !r['success']).length;

      // ✅ Revalidate the channel cache (membership counts, comradesInGroups)
      // before notifying the parent, so onComradeAdded's rebuild uses fresh data.
      if (successCount > 0) {
        await AppCache.refreshChannels(
          widget.currentUserId,
          widget.authToken,
        );
      }

      widget.onComradeAdded();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successCount > 0
                  ? 'Added to $successCount ${successCount == 1 ? 'channel' : 'channels'}${failCount > 0 ? ' ($failCount failed)' : ''}'
                  : 'Failed to add to channels',
            ),
            backgroundColor:
                successCount > 0 ? FanColors.primary : FanColors.away,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: FanColors.away,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

// ============================================================================
// COMRADE PROFILE MODAL - KEEP EXISTING
// ============================================================================
class ComradeProfileModal extends StatefulWidget {
  final Map<String, dynamic> comrade;
  final String currentUserId;
  final String? authToken;
  final List<UserChannel> userChannels;
  final Set<String> comradesInGroups;
  final VoidCallback onComradeAdded;

  const ComradeProfileModal({
    super.key,
    required this.comrade,
    required this.currentUserId,
    this.authToken,
    required this.userChannels,
    required this.comradesInGroups,
    required this.onComradeAdded,
  });

  @override
  State<ComradeProfileModal> createState() => _ComradeProfileModalState();
}

class _ComradeProfileModalState extends State<ComradeProfileModal> {
  bool _isLoading = false;
  List<UserChannel> get _adminChannels =>
      widget.userChannels.where((c) => c.isAdmin).toList();

  @override
  Widget build(BuildContext context) {
    final nickname = widget.comrade['nickname'] ?? 'Fan';
    final username = widget.comrade['username'] ?? 'user';
    final club = widget.comrade['club'] ?? 'Football Fan';
    final country = widget.comrade['country'] ?? 'World';
    final comradeId = widget.comrade['id'] ?? '';

    final isInAnyGroup = widget.comradesInGroups.any(
      (key) => key.startsWith('${comradeId}_'),
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: FanColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(FanRadius.xl),
          topRight: Radius.circular(FanRadius.xl),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: FanColors.surfaceElevated,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0B1E),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      nickname[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: FanColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nickname,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D0B1E),
                        ),
                      ),
                      Text(
                        '@$username',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1A1A3E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D0B1E)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              club,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF0D0B1E),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D0B1E)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              country,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF0D0B1E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: FanColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  isInAnyGroup ? Icons.check_circle : Icons.group_add,
                  color: isInAnyGroup ? Colors.green : const Color(0xFF0D0B1E),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isInAnyGroup
                        ? 'Already in your groups'
                        : 'Not in any of your groups',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isInAnyGroup ? FontWeight.w600 : FontWeight.w400,
                      color:
                          isInAnyGroup ? Colors.green : const Color(0xFF0D0B1E),
                    ),
                  ),
                ),
                if (!isInAnyGroup && _adminChannels.isNotEmpty)
                  _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0D0B1E),
                          ),
                        )
                      : GestureDetector(
                          onTap: _showAddToGroupsModal,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D0B1E),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Add to Groups',
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
          ),
          if (isInAnyGroup) ...[
            Divider(height: 1, color: FanColors.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Groups with ${widget.comrade['nickname']}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D0B1E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.userChannels
                      .where((c) => widget.comradesInGroups.contains(
                            '${widget.comrade['id']}_${c.channelId}',
                          ))
                      .map((channel) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D0B1E),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      channel.name[0].toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: FanColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  channel.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF0D0B1E),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ],
              ),
            ),
          ],
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: FanColors.border,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D0B1E),
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

  void _showAddToGroupsModal() {
    if (_isLoading) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddToGroupsModal(
        comradeId: widget.comrade['id'] ?? '',
        comradeName: widget.comrade['nickname'] ?? 'Fan',
        comradeUsername: widget.comrade['username'] ?? 'user',
        currentUserId: widget.currentUserId,
        authToken: widget.authToken,
        userChannels: widget.userChannels,
        comradesInGroups: widget.comradesInGroups,
        onComradeAdded: () {
          widget.onComradeAdded();
          setState(() {});
        },
      ),
    );
  }
}

// ============================================================================
// AD MANAGER - KEEP EXISTING
// ============================================================================
// ============================================================================
// AD SLOT WIDGET - KEEP EXISTING
// ============================================================================

// ============================================================================
// Funzy AD PLACEHOLDER - KEEP EXISTING
// ============================================================================
class FunzydPlaceholder extends StatelessWidget {
  const FunzydPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        color: FanColors.primary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FanColors.primary.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF0D0B1E),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('⚔️', style: TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Funzy Ad',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D0B1E),
                ),
              ),
              Text(
                'Support the platform',
                style: TextStyle(
                  fontSize: 10,
                  color: const Color(0xFF0D0B1E).withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0B1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'View',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: FanColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ============================================================================
// CAROUSEL ITEM TYPE - UPDATED
// ============================================================================
enum CarouselItemType { comrade, channel, ad }

class CarouselItem {
  final CarouselItemType type;
  final Map<String, dynamic>? comradeData;
  final bool added;
  final String? adUnitId;
  final UserChannel? channelData;

  CarouselItem.comrade({this.comradeData, this.added = false})
      : type = CarouselItemType.comrade,
        adUnitId = null,
        channelData = null;

  CarouselItem.channel({required this.channelData})
      : type = CarouselItemType.channel,
        comradeData = null,
        added = false,
        adUnitId = null;

  CarouselItem.ad({required this.adUnitId})
      : type = CarouselItemType.ad,
        comradeData = null,
        added = false,
        channelData = null;
}

class HistoryGameItem {
  final Fixture game;
  final DateTime completedAt;
  final bool movedToHistory;
  final String? source; // "games_history" or "fixtures_history"

  HistoryGameItem({
    required this.game,
    required this.completedAt,
    this.movedToHistory = true,
    this.source,
  });

  // Convert from models.HistoryGame to HistoryGameItem
  factory HistoryGameItem.fromHistoryGame(models.HistoryGame history) {
    return HistoryGameItem(
      game: history.toFixture(),
      completedAt: history.completedAt,
      movedToHistory: history.movedToHistory,
      source: history.source,
    );
  }

  // Convert from Fixture (for backwards compatibility)
  factory HistoryGameItem.fromFixture(Fixture fixture, DateTime completedAt) {
    return HistoryGameItem(
      game: fixture,
      completedAt: completedAt,
      movedToHistory: true,
      source: null,
    );
  }

  String get sourceIcon {
    if (source == 'fixtures_history') return '🌍';
    if (source == 'games_history') return '⚽';
    return '⚽';
  }

  String get sourceLabel {
    if (source == 'fixtures_history') return 'National';
    if (source == 'games_history') return 'League';
    return 'League';
  }
}

// ============================================================================
// HOME PAGE - MAIN FILE (KEEP ALL EXISTING FUNCTIONS, UPDATE CAROUSEL)
// ============================================================================
class HomePage extends StatefulWidget {
  final int initialTab;
  const HomePage({super.key, this.initialTab = 0});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin,
        TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  // ==========================================================================
  // AUTHENTICATION - KEEP EXISTING
  // ==========================================================================
  late final AuthService _authService;
  bool get _isLoggedIn => _authService.isLoggedIn;
  final Set<int> _visitedPages = {
    0
  }; // fixtures tab counts as visited from the start
  // Add these to _HomePageState

// History dropdown
  OverlayEntry? _historyMenuOverlay;
  bool _isHistoryMenuOpen = false;
  List<HistoryGameItem> _historyGamesForMenu = [];
  bool _loadingHistoryMenu = false;

// In initState or where needed
  bool _appCacheReady = false;
  String get _userId => _authService.userId ?? '';
  String get _username => _authService.username ?? '';
  String? get _authToken => _authService.authToken;
  StreamSubscription<List<Fixture>>? _appCacheSubscription;
  static String? globalSelectedChannelId;
  static String? globalSelectedChannelName;
  final Set<String> _joiningChannelIds = {};
  List<UserChannel> _allChannels = [];
  // History dropdown
  bool _isLoadingAllChannels = false;
  int _pendingJoinCount = 0;
  Set<String> _pendingJoinRequests = {};
  Set<String> _addedComradeIds = {};
  final GlobalKey<FixturesPageState> _fixturesPageRefreshKey =
      GlobalKey<FixturesPageState>();

  // ==========================================================================
  // NAVIGATION - KEEP EXISTING
  // ==========================================================================
  late PageController _pageController;
  // ==========================================================================
// HEADER VISIBILITY - NEW
// ==========================================================================
  bool _isHeaderVisible = true;
  int _currentPageIndex = 0;
  ScrollController? _postsScrollController;
  ScrollController? _fixturesScrollController;
  ScrollController? _logsScrollController;
  bool _isAdminOfAnyChannel = false;

  // ==========================================================================
  // USER DATA - KEEP EXISTING
  // ==========================================================================
  Map<String, dynamic>? _userData;
  bool _isModalOpen = false;
  bool _isLoggingOut = false;

  // ==========================================================================
  // COMRADE SYSTEM - KEEP EXISTING
  // ==========================================================================
  int _comradeCount = 0;
  int _maxComrades = 10;
  final Set<String> _comradesInGroups = {};
  List<Map<String, dynamic>> _realComrades = List.from(AppCache.comrades);
  List<UserChannel> _userChannels = List.from(AppCache.channels);
  bool _loadingComrades = true;
  String? _comradesError;
  final bool _syncToFixtures = true;

  // ==========================================================================
  // CHANNELS - KEEP EXISTING
  // ==========================================================================
  bool _hasUserVoted = false;
  bool _hasSeenWelcomeDialog = false;
  String? _selectedChannelId;
  String? _selectedChannelName;
  bool _loadingChannels = false;

  // ==========================================================================
  // VOTE TEXTS - KEEP EXISTING
  // ==========================================================================
  final List<Map<String, String>> _voteTexts = const [
    {'team': 'Liverpool', 'fixture': 'Liverpool vs Everton'},
    {'team': 'Inter Miami', 'fixture': 'Inter Miami vs LAFC'},
    {'team': 'Al Nassr', 'fixture': 'Al Nassr vs Al Hilal'},
    {'team': 'Manchester City', 'fixture': 'Man City vs Arsenal'},
    {'team': 'PSG', 'fixture': 'PSG vs Marseille'},
    {'team': 'Al Hilal', 'fixture': 'Al Hilal vs Al Nassr'},
    {'team': 'Bayern Munich', 'fixture': 'Bayern vs Dortmund'},
    {'team': 'Real Madrid', 'fixture': 'Real Madrid vs Barcelona'},
  ];

  // ==========================================================================
  // REFRESH TRIGGERS - KEEP EXISTING
  // ==========================================================================
  int _postsPageKey = 0;
  int _fixturesPageKey = 0;

  // ==========================================================================
  // NOTIFICATION SYSTEM - KEEP EXISTING
  // ==========================================================================
  int _notificationCount = 0;
  List<Map<String, dynamic>> _notifications = [];
  static const int MAX_NOTIFICATIONS = 50;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseScaleAnimation;
  late Animation<double> _pulseOpacityAnimation;
  late AnimationController _bounceAnimationController;
  int _totalUnreadCount = 0;
  StreamSubscription<Map<String, dynamic>>? _badgeStreamSubscription;
  late Animation<double> _bounceScaleAnimation;
  bool _hasUnreadNotifications = false;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;
  final GlobalKey _notificationsModalKey = GlobalKey();

  // ==========================================================================
  // CAROUSEL SYSTEM - KEEP EXISTING
  // ==========================================================================
  PageController? _carouselController;
  int _currentCarouselIndex = 0;
  bool _isCarouselRunning = false;
  Timer? _carouselTimer;
  List<CarouselItem> _carouselItems = [];
  bool _isRebuildingCarousel = false;
  final Set<String> _preloadedAdUnitIds = {};

  // ==========================================================================
  // MENU - KEEP EXISTING
  // ==========================================================================
  OverlayEntry? _menuOverlay;
  bool _isMenuOpen = false;

  // ==========================================================================
  // SEARCH SYSTEM - KEEP EXISTING
  // ==========================================================================
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];

  // ==========================================================================
  // CONSTANTS - UPDATED
  // ==========================================================================
  static const String API_BASE_URL = 'https://clash-api-m5mr.onrender.com/api';
  static const int MAX_CHANNELS = 3;

  // ==========================================================================
  // INITIALIZATION - KEEP EXISTING
  // ==========================================================================
  @override
  void initState() {
    super.initState();
    FanTheme.controller.addListener(_onThemeChanged);
    _initControllers();
    _initServices();
    _initObservers();
    _initAnimations(); // cheap, keep sync — needed for TickerProvider setup

    // ✅ Only the truly free, in-memory work stays synchronous here.
    _checkAppCacheReady();
    _loadFromAppCache();

    _appCacheSubscription = AppCache.fixturesStream.listen((fixtures) {
      if (mounted && fixtures.isNotEmpty) {
        _fixturesPageRefreshKey.currentState?.refreshFromAppCache();
        if (_currentPageIndex == 0) {
          _fixturesPageRefreshKey.currentState?.forceRefreshOnTabVisible();
        }
      }
    });

    // ✅ Everything that hits SharedPreferences, spawns an isolate, or fires
    // an HTTP call moves to right after first frame — mirrors FixturesPage's
    // _initializeData() pattern. This is what actually lets the first frame
    // (and splash removal) happen without waiting on any of it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadThemePreference();
      _loadStoredNotifications();
      _subscribeToNotifications();
      _loadWelcomeDialogPreference();
      _loadUserChannels();
      _loadPendingJoinRequests();
      _fetchComradeStats();
      _checkUserVoteStatus();
      _setupBadgeSystem();
      _preloadInitialAds();
      _maybeFetchAllChannelsForBrowsing();
      if (_isLoggedIn && _userId.isNotEmpty) {
        _registerFCMToken(_userId);
      }

      if (AppCache.fixtures.isNotEmpty) {
        _fixturesPageRefreshKey.currentState?.refreshFromAppCache();
      }
      _buildCarouselWithAds(); // single call, not two
    });
  }

// ✅ New method — instantly rebuilds the whole HomePage subtree,
// including anything downstream that reads FanColors at build time.
  void _onThemeChanged() {
    if (!mounted) return;
    _applyStatusBarStyle();
    setState(() {});
  }

// ✅ New — makes the phone's status bar (battery/clock/signal) icons
// switch to light-on-dark or dark-on-light along with the app theme.
// Without this they stay frozen at whatever the OS default was,
// which is why they looked washed out/blurry in dark mode.
  void _applyStatusBarStyle() {
    final isDark = FanColors.isDark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark, // Android
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light, // iOS
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: FanColors.surfaceElevated,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  Future<void> _refreshProfileInBackground() async {
    if (!_isLoggedIn || _userId.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/profile/profile/$_userId'),
        headers: {
          'Content-Type': 'application/json',
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        final decoded = json.decode(response.body);
        final userMap = decoded is List
            ? Map<String, dynamic>.from(decoded.first as Map)
            : Map<String, dynamic>.from(decoded);

        setState(() {
          _userData = {...?_userData, ...userMap};
        });
        await AppCache.saveProfile(userMap);
      }
    } catch (e) {
      debugPrint('Background profile refresh error: $e');
    }
  }

// ✅ NEW METHOD - Load everything from AppCache instantly
  void _loadFromAppCache() {
    // ✅ Check if AppCache is loaded before accessing
    if (!AppCache.isLoaded) {
      debugPrint('⏳ AppCache not loaded yet, waiting...');
      return;
    }

    // ✅ Load profile from AppCache with defaults
    if (AppCache.profile != null) {
      final profile = AppCache.profile!;
      _userData = {
        ...?_userData,
        ...profile,
        'nickname': profile['nickname'] ?? profile['username'] ?? 'Fan',
        'club_fan': profile['club_fan'] ?? 'No Club',
        'country_fan': profile['country_fan'] ?? 'World',
        'points': profile['points'] ?? profile['season_points'] ?? 0,
      };
      debugPrint('✅ Loaded profile from AppCache: ${_userData?['nickname']}');
      debugPrint('   Club: ${_userData?['club_fan']}');
      debugPrint('   Country: ${_userData?['country_fan']}');
      debugPrint('   Points: ${_userData?['points']}');
    }

    // ✅ Load channels from AppCache
    if (AppCache.channels.isNotEmpty) {
      _userChannels = List<UserChannel>.from(AppCache.channels);
      _isAdminOfAnyChannel = _userChannels.any((c) => c.isAdmin);
      _loadingChannels = false;

      // Build comrades in groups
      final newComradesInGroups = <String>{};
      for (final channel in _userChannels) {
        for (final member in channel.members) {
          if (member.userId != _userId) {
            newComradesInGroups.add('${member.userId}_${channel.channelId}');
          }
        }
      }
      _comradesInGroups.clear();
      _comradesInGroups.addAll(newComradesInGroups);

      debugPrint('✅ Loaded ${_userChannels.length} channels from AppCache');
    } else {
      _loadingChannels = true;
    }

    // ✅ Load comrades from AppCache
    if (AppCache.comrades.isNotEmpty) {
      _realComrades = List<Map<String, dynamic>>.from(AppCache.comrades);
      _loadingComrades = false;
      _comradesError = null;
      debugPrint('✅ Loaded ${_realComrades.length} comrades from AppCache');
    } else {
      _loadingComrades = true;
    }

    // ✅ Load added comrade IDs from AppCache
    if (AppCache.addedComradeIds.isNotEmpty) {
      _addedComradeIds = Set<String>.from(AppCache.addedComradeIds);
      _comradeCount = _addedComradeIds.length;
      debugPrint('✅ Loaded ${_comradeCount} added comrades from AppCache');
    }

    // ✅ Load fixtures from AppCache
    if (AppCache.fixtures.isNotEmpty) {
      _fixturesPageRefreshKey.currentState?.refreshFromAppCache();
      debugPrint('✅ Loaded ${AppCache.fixtures.length} fixtures from AppCache');
    }

    // Build carousel
    _buildCarouselWithAds();

    // Start auto-scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCarouselAutoScroll();
    });
    _maybeFetchAllChannelsForBrowsing();
  }

  void _initControllers() {
    _pageController = PageController(initialPage: widget.initialTab);
    _carouselController = PageController();
    _postsScrollController = ScrollController();
    _fixturesScrollController = ScrollController();
    _logsScrollController = ScrollController();

    _postsScrollController!.addListener(_handleScroll);
    _fixturesScrollController!.addListener(_handleScroll);

    _logsScrollController!.addListener(_handleScroll);
  }

  // ✅ NEW - hide/show top bar based on scroll direction
  void _handleScroll() {
    final controller = switch (_currentPageIndex) {
      0 => _fixturesScrollController,
      1 => _postsScrollController,
      2 => _logsScrollController,
      _ => null,
    };
    if (controller == null || !controller.hasClients) return;

    final position = controller.position;

    // Always show near the very top
    if (position.pixels <= 0) {
      if (!_isHeaderVisible) setState(() => _isHeaderVisible = true);
      return;
    }

    final direction = position.userScrollDirection;
    if (direction == ScrollDirection.reverse && _isHeaderVisible) {
      setState(() => _isHeaderVisible = false); // scrolling down -> hide
    } else if (direction == ScrollDirection.forward && !_isHeaderVisible) {
      setState(() => _isHeaderVisible = true); // scrolling up -> show
    }
  }

  void _initServices() {
    _authService = AuthService();
    _authService.addListener(_onAuthStateChanged);
  }

  void _initObservers() {

    WidgetsBinding.instance.addObserver(this);
  }

  void _loadData() {
    _loadThemePreference();
    _loadStoredNotifications();
    _subscribeToNotifications();
    _loadWelcomeDialogPreference();
    _loadUserChannels();
    _loadPendingJoinRequests();

    _loadFromAppCache();
    _fetchComradeStats();
    _checkUserVoteStatus();

    _maybeFetchAllChannelsForBrowsing(); // ✅ initial check on app start
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

  String _adUnitIdForIndex(int index) {
    final ids = AdHelper.carouselAdUnitIds;
    return ids.isEmpty ? '' : ids[index % ids.length];
  }

  // ==========================================================================
  // LOAD COMRADES IN GROUPS - KEEP EXISTING
  // ==========================================================================
  Future<void> _loadComradesInGroups() async {
    if (!_isLoggedIn || _authToken == null || _userChannels.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/channels/comrades-in-groups/$_userId'),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final List<dynamic> comradesData = data['comrades'] ?? [];

        setState(() {
          _comradesInGroups.clear();
          for (var item in comradesData) {
            final comradeId = item['comrade_id']?.toString() ?? '';
            final channelId = item['channel_id']?.toString() ?? '';
            if (comradeId.isNotEmpty && channelId.isNotEmpty) {
              _comradesInGroups.add('${comradeId}_${channelId}');
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading comrades in groups: $e');
    }
  }

  // ==========================================================================
  // CHANNELS - KEEP EXISTING
  // ==========================================================================
  Future<void> _loadUserChannels() async {
    if (AppCache.channels.isNotEmpty) {
      final cachedChannels = List<UserChannel>.from(AppCache.channels);

      final newComradesInGroups = <String>{};
      for (final channel in cachedChannels) {
        for (final member in channel.members) {
          if (member.userId != _userId) {
            newComradesInGroups.add('${member.userId}_${channel.channelId}');
          }
        }
      }

      setState(() {
        _userChannels = cachedChannels;
        _comradesInGroups.clear();
        _comradesInGroups.addAll(newComradesInGroups);
        _isAdminOfAnyChannel = cachedChannels.any((c) => c.isAdmin);
        _loadingChannels = false;
      });

      _buildCarouselWithAds();

      // ✅ Cache is shown instantly, but it might be stale — always
      // kick off a real revalidation in the background.
      _refreshChannelsInBackground();
      return;
    }

    // No cache at all — show loading state and go straight to network.
    setState(() {
      _loadingChannels = true;
      _userChannels = [];
      _isAdminOfAnyChannel = false;
    });

    await _refreshChannelsInBackground();
  }

  Future<void> _refreshChannelsInBackground() async {
    if (_userId.isEmpty) return;

    await AppCache.refreshChannels(_userId, _authToken);

    if (!mounted) return;

    final userChannels = List<UserChannel>.from(AppCache.channels);
    final newComradesInGroups = <String>{};
    for (final channel in userChannels) {
      for (final member in channel.members) {
        if (member.userId != _userId) {
          newComradesInGroups.add('${member.userId}_${channel.channelId}');
        }
      }
    }

    setState(() {
      _userChannels = userChannels;
      _comradesInGroups.clear();
      _comradesInGroups.addAll(newComradesInGroups);
      _isAdminOfAnyChannel = userChannels.any((c) => c.isAdmin);
      _loadingChannels = false;
    });

    _buildCarouselWithAds();
    _maybeFetchAllChannelsForBrowsing(); // ✅ channel count just changed — re-evaluate browsing
  }

  void _openGroupChat(UserChannel channel) {
    if (!_isLoggedIn) {
      _showLoginModal();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          channelId: channel.channelId,
          fixtureId: null,
          fixture: null,
          userId: _userId,
          username: _username,
          authToken: _authToken,
          isLoggedIn: _isLoggedIn,
          comradesList: _addedComradeIds,
        ),
      ),
    );
  }

  // ==========================================================================
  // GROUP CHIPS - KEEP EXISTING
  // ==========================================================================
  // ==========================================================================
// GROUP CHIPS - KEEP EXISTING (UPDATED)
// ==========================================================================

  Future<void> _joinChannelDirectly(UserChannel channel) async {
    if (!_isLoggedIn) {
      _showLoginModal();
      return;
    }

    if (_userChannels.length >= MAX_CHANNELS) {
      ToastHelper.showWarning(
        'You already have $MAX_CHANNELS channels',
        context: context,
      );
      return;
    }

    if (_authToken == null || _joiningChannelIds.contains(channel.channelId)) {
      return;
    }

    setState(() => _joiningChannelIds.add(channel.channelId));

    try {
      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/channels/members/add'),
            headers: {
              'Authorization': 'Bearer $_authToken',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'channel_id': channel.channelId,
              'members': [
                {'user_id': _userId, 'username': _username},
              ],
            }),
          )
          .timeout(const Duration(seconds: 10));

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          mounted) {
        ToastHelper.showSuccess('Joined "${channel.name}"', context: context);
        _selectChannel(channel);

        // ✅ Was `await _loadUserChannels()`, which just re-read the same
        // stale cache since AppCache.channels hadn't changed yet. Now we
        // force an actual network revalidation.
        await _refreshChannelsInBackground();
      } else if (mounted) {
        String message = 'Failed to join channel';
        try {
          message = json.decode(response.body)['message'] ?? message;
        } catch (_) {}
        ToastHelper.showError(message, context: context);
      }
    } catch (e) {
      if (mounted) ToastHelper.showError('Error: $e', context: context);
    } finally {
      if (mounted) {
        setState(() => _joiningChannelIds.remove(channel.channelId));
      }
    }
  }

  Future<void> _fetchAllChannelsForBrowsing() async {
    if (!mounted) return;
    setState(() => _isLoadingAllChannels = true);

    try {
      final headers = {'Content-Type': 'application/json'};
      if (_authToken != null && _authToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_authToken';
      }

      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/channels/all'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final List<dynamic> channelsData = data['channels'] ?? [];
        final fetched = channelsData
            .map((c) => UserChannel.fromJson(c as Map<String, dynamic>))
            .toList();

        // ✅ Only show channels the user hasn't already joined —
        // no point "browsing" a channel you're already in.
        final joinedIds = _userChannels.map((c) => c.channelId).toSet();
        final browsable =
            fetched.where((c) => !joinedIds.contains(c.channelId)).toList();

        setState(() {
          _allChannels = browsable;
          _isLoadingAllChannels = false;
        });
        _buildCarouselWithAds();
        return;
      }

      debugPrint(
          '⚠️ Failed to fetch browsable channels: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ Error fetching browsable channels: $e');
    }

    // ✅ Fallback: fall back to whatever is in AppCache (best-effort),
    // still excluding channels already joined.
    if (mounted) {
      final joinedIds = _userChannels.map((c) => c.channelId).toSet();
      setState(() {
        _allChannels = AppCache.channels
            .where((c) => !joinedIds.contains(c.channelId))
            .toList();
        _isLoadingAllChannels = false;
      });
      _buildCarouselWithAds();
    }
  }

  void _maybeFetchAllChannelsForBrowsing() {
    if (!mounted) return;

    // Show "browse other channels to join" when:
    //  - the user isn't logged in yet, OR
    //  - the user is logged in but still has room (0, 1, or 2 of MAX_CHANNELS)
    final bool needsBrowsing =
        !_isLoggedIn || _userChannels.length < MAX_CHANNELS;

    if (needsBrowsing) {
      _fetchAllChannelsForBrowsing();
    } else if (_allChannels.isNotEmpty || _isLoadingAllChannels) {
      // Full on channels (3/3) — clear the browse list, nothing to show.
      setState(() {
        _allChannels = [];
        _isLoadingAllChannels = false;
      });
      _buildCarouselWithAds();
    }
  }

  void _selectChannel(UserChannel channel) {
    // Update local state
    setState(() {
      _selectedChannelId = channel.channelId;
      _selectedChannelName = channel.name;
    });

    // ✅ Store globally for history games to use
    _HomePageState.globalSelectedChannelId = channel.channelId;
    _HomePageState.globalSelectedChannelName = channel.name;

    debugPrint(
        '🔄 Switched to channel: ${channel.name} (${channel.channelId})');

    ToastHelper.showSuccess(
      'Switched to "${channel.name}"',
      context: context,
    );
  }

  void _showChannelLeaderboard(UserChannel channel) {
    if (!_isLoggedIn) {
      _showLoginModal();
      return;
    }

    // ✅ Select the channel
    _selectChannel(channel);

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
        currentUserId: _userId,
        currentUserName: _username,
        authToken: _authToken,
        channelId: channel.channelId,
        channelName: channel.name,
        fixture: null,
        comradesList: _addedComradeIds,
        comradesVoteMap: {},
        hasUserVoted: _hasUserVoted,
        userVoteSelection: null,
      ),
    ).then((_) {
      _isModalOpen = false;
    });
  }

  Widget _buildNewChannelChip() {
    return GestureDetector(
      onTap: _showLeaderborad,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: FanColors.border.withValues(alpha: 0.25),
            width: 0.5,
          ),
          color: FanColors.surface.withValues(alpha: 0.4),
        ),
        child: Icon(
          Icons.add_rounded,
          size: 14,
          color: FanColors.textSecondary.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildLiveTicker() {
    const String liveFixtureLabel = '';
    const String liveScore = '';

    if (liveFixtureLabel.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: FanColors.live.withValues(alpha: 0.06),
        border: Border(
          bottom: BorderSide(
            color: FanColors.live.withValues(alpha: 0.12),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.4, end: 1.0),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: child,
            ),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: FanColors.live,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: FanTypography.tag.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: FanColors.live,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              liveFixtureLabel,
              style: FanTypography.tag.copyWith(
                fontSize: 10,
                color: FanColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: FanColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: FanColors.border.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Text(
              liveScore,
              style: FanTypography.tag.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: FanColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHistoryDropdown() {
    if (_isHistoryMenuOpen) {
      _hideHistoryMenu();
      return;
    }

    if (!_isLoggedIn) {
      _showLoginModal();
      return;
    }

    _isHistoryMenuOpen = true;

    final RenderBox? historyBox = context.findRenderObject() as RenderBox?;
    if (historyBox == null) {
      _isHistoryMenuOpen = false;
      return;
    }

    final Offset historyPosition = historyBox.localToGlobal(Offset.zero);

    _historyGamesForMenu = [];
    _loadingHistoryMenu = true;

    _historyMenuOverlay = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _hideHistoryMenu,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Container(color: Colors.transparent),
            Positioned(
              top: historyPosition.dy + 45,
              right: 12,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(10),
                color: FanColors.surfaceElevated,
                child: Container(
                  width: 240,
                  constraints: const BoxConstraints(maxHeight: 560),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: FanColors.border.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.sports_soccer,
                                size: 16, color: FanColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Recent Matches',
                                    style: FanTypography.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: FanColors.textPrimary,
                                    ),
                                  ),
                                  if (_selectedChannelName != null)
                                    Text(
                                      'Channel: ${_selectedChannelName}',
                                      style: FanTypography.tag.copyWith(
                                        fontSize: 10,
                                        color: FanColors.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (_historyGamesForMenu.length > 15)
                              GestureDetector(
                                onTap: () {
                                  _hideHistoryMenu();
                                },
                                child: Text(
                                  'See All',
                                  style: FanTypography.tag.copyWith(
                                    color: FanColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: FanColors.border),
                      _loadingHistoryMenu
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _historyGamesForMenu.isEmpty
                              ? Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 20),
                                  child: Text(
                                    'No match history',
                                    style: FanTypography.body.copyWith(
                                      color: FanColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : Flexible(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    padding: EdgeInsets.zero,
                                    itemCount:
                                        _historyGamesForMenu.take(15).length,
                                    itemBuilder: (context, index) {
                                      final historyItem =
                                          _historyGamesForMenu[index];
                                      return _buildHistoryMenuItem(historyItem);
                                    },
                                  ),
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

    Overlay.of(context).insert(_historyMenuOverlay!);

    _fetchHistoryGamesForMenu();
  }
// ============================================================================
// HIDE HISTORY MENU
// ============================================================================

  void _hideHistoryMenu() {
    _historyMenuOverlay?.remove();
    _historyMenuOverlay = null;
    _isHistoryMenuOpen = false;
  }

  // home_page.dart - Update _fetchHistoryGamesForMenu()

  // ============================================================================
// FETCH HISTORY GAMES FOR MENU
// ============================================================================

  Future<void> _fetchHistoryGamesForMenu() async {
    if (!_isLoggedIn || _authToken == null) {
      setState(() {
        _historyGamesForMenu = [];
        _loadingHistoryMenu = false;
      });
      return;
    }

    // Show whatever's already in memory instantly
    if (AppCache.historyGames.isNotEmpty) {
      setState(() {
        _historyGamesForMenu = AppCache.historyGames
            .take(15)
            .map((g) => HistoryGameItem.fromHistoryGame(g))
            .toList();
        _loadingHistoryMenu = false;
      });
    } else {
      setState(() => _loadingHistoryMenu = true);
    }

    // Always refresh from API through AppCache (single source of truth)
    await AppCache.refreshHistoryGames(authToken: _authToken);

    if (mounted) {
      setState(() {
        _historyGamesForMenu = AppCache.historyGames
            .take(15)
            .map((g) => HistoryGameItem.fromHistoryGame(g))
            .toList();
        _loadingHistoryMenu = false;
      });
      _refreshHistoryMenu();
    }
  }

// ============================================================================
// FORMAT DATE HELPER
// ============================================================================

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 7) {
      return '${diff.inDays ~/ 7}w ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

// ============================================================================
// OPEN CHAT FROM HISTORY
// ============================================================================

  void _openChatFromHistory(Fixture fixture) async {
    if (!_isLoggedIn) {
      _showLoginModal();
      return;
    }

    if (_userChannels.isEmpty) {
      ToastHelper.showWarning('Join a channel first to chat', context: context);
      return;
    }

    // Get the selected channel from HomePage's state
    String? channelId = _selectedChannelId;
    String? channelName = _selectedChannelName;

    // Fallback to first channel if none selected
    if (channelId == null && _userChannels.isNotEmpty) {
      channelId = _userChannels.first.channelId;
      channelName = _userChannels.first.name;
    }

    // Guard: Ensure channelId is not null before navigating
    if (channelId == null) {
      ToastHelper.showError('No channel available', context: context);
      return;
    }

    debugPrint(
      '📢 Opening chat for history game: ${fixture.homeTeam} vs ${fixture.awayTeam} '
      'using channel: $channelName ($channelId)',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          channelId: channelId!,
          fixtureId: fixture.matchId,
          fixture: fixture,
          userId: _userId,
          username: _username,
          authToken: _authToken,
          isLoggedIn: _isLoggedIn,
          comradesList: _addedComradeIds,
          userVoteSelection: null,
        ),
      ),
    );
  }

// ============================================================================
// REFRESH HISTORY MENU (Update overlay)
// ============================================================================

// Helper to convert HistoryGame to Fixture (for display)

  // home_page.dart - Update _buildHistoryMenuItem()

  Widget _buildHistoryMenuItem(HistoryGameItem historyItem) {
    final game = historyItem.game;
    final homeScore = game.homeScore ?? 0;
    final awayScore = game.awayScore ?? 0;

    // Determine result indicator
    String resultText;
    Color resultColor;
    if (homeScore > awayScore) {
      resultColor = FanColors.primary;
      resultText = '🏆';
    } else if (awayScore > homeScore) {
      resultColor = const Color(0xFF2563EB);
      resultText = '🏆';
    } else {
      resultColor = const Color(0xFF8B5CF6);
      resultText = '🤝';
    }

    return GestureDetector(
      onTap: () {
        _hideHistoryMenu();
        _openChatFromHistory(game);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: FanColors.border.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Result indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: resultColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(resultText, style: const TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 10),
            // Teams
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${game.homeTeam} vs ${game.awayTeam}',
                    style: FanTypography.body.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: FanColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.sports_soccer,
                        size: 10,
                        color: FanColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        game.league,
                        style: FanTypography.tag.copyWith(
                          fontSize: 10,
                          color: FanColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$homeScore - $awayScore',
                          style: FanTypography.tag.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: FanColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Show source (games_history or fixtures_history)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: FanColors.primaryDim,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          historyItem.sourceIcon,
                          style: const TextStyle(fontSize: 8),
                        ),
                      ),
                    ],
                  ),
                  // Show when it was completed
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: FanColors.surfaceSunken,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDate(historyItem.completedAt),
                      style: FanTypography.tag.copyWith(
                        fontSize: 8,
                        color: FanColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: FanColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    final bool hasChannels = _userChannels.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ============================================================
        // ROW 1: App Name | Bundesliga | Notification | Menu
        // ============================================================
        Container(
          color: FanColors.surfaceElevated,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              // App name
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Funspot😂',
                      style: FanTypography.headline.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: FanColors.primary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Bundesliga icon (player kicking ball skeleton)

              // ← new toggle sits here
              const SizedBox(width: 4),
              // Notification icon
              _buildNotificationIcon(),
              const SizedBox(width: 8),
              // Menu avatar
              GestureDetector(
                onTap: _showTelegramMenu,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: FanColors.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipOval(
                        child: Image.network(
                          _isLoggedIn && _userId.isNotEmpty
                              ? 'https://i.pravatar.cc/150?u=$_userId'
                              : 'https://i.pravatar.cc/150?img=12',
                          width: 20,
                          height: 20,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, _) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [FanColors.primary, Color(0xFF06B6D4)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                _isLoggedIn && _username.isNotEmpty
                                    ? _username[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_isLoggedIn)
                        Positioned(
                          bottom: -1,
                          right: -1,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: FanColors.background,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // ============================================================
        // ROW 2: Channels | Club | Country | Points (Conditional)
        // ============================================================
        Container(
          color: FanColors.surfaceElevated,
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
          child: _buildRow2Content(),
        ),
        Container(
          height: 0.5,
          color: FanColors.border.withValues(alpha: 0.4),
        ),
        _buildLiveTicker(),
      ],
    );
  }
  // ============================================================
// THEME TOGGLE - Dark/Light mode switch
// ============================================================

  void _refreshHistoryMenu() {
    if (_historyMenuOverlay == null) return;
    // Rebuild the overlay with updated data
    _historyMenuOverlay!.markNeedsBuild();
  }

// ============================================================
// BUNDESLIGA ICON - Player Kicking Ball Skeleton
// ============================================================

// ============================================================
// ROW 2 CONTENT - Conditional
// ============================================================
  Widget _buildRow2Content() {
    final bool hasChannels = _userChannels.isNotEmpty;

    // Case 1: Not logged in OR logged in with NO channels
    if (!_isLoggedIn || !hasChannels) {
      return _buildAllChannelsWithJoin();
    }

    // Case 2: Logged in WITH channels - Show channels with leader info
    return _buildLoggedInWithChannels();
  }

// ============================================================
// CASE 1: All channels with JOIN button
// ============================================================
  Widget _buildAllChannelsWithJoin() {
    final displayChannels =
        _allChannels.isNotEmpty ? _allChannels : _userChannels;

    if (displayChannels.isEmpty) {
      return SizedBox(
        height: 26,
        child: Center(
          child: Text(
            'No channels available',
            style: FanTypography.caption.copyWith(
              color: FanColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...displayChannels.map((channel) => _buildChannelWithJoin(channel)),
          const SizedBox(width: 4),
          _buildNewChannelChip(),
        ],
      ),
    );
  }

// ============================================================
// Channel with JOIN button
// ============================================================
  Widget _buildChannelWithJoin(UserChannel channel) {
    final bool isJoining = _joiningChannelIds.contains(channel.channelId);

    return GestureDetector(
      onTap: () {
        if (!_isLoggedIn) {
          _showLoginModal();
          return;
        }
        _joinChannelDirectly(channel);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          // ✅ No background change
          color: FanColors.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          // ✅ NO BORDER
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              channel.name,
              style: FanTypography.tag.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: FanColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            isJoining
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                : Text(
                    'join',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: FanColors.primary,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

// ============================================================
// CASE 2: Logged in WITH channels - Selected Channel + Club + Country + Points
// ============================================================
  Widget _buildLoggedInWithChannels() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // ✅ ALL channels the user belongs to — with leader name + points
          ..._userChannels.map(
            (channel) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _buildUserChannelChip(channel),
            ),
          ),
          const SizedBox(width: 2),
          // ✅ New channel button
          _buildNewChannelChip(),
        ],
      ),
    );
  }

  Widget _buildUserChannelChip(UserChannel channel) {
    final bool isSelected = _selectedChannelId != null
        ? _selectedChannelId == channel.channelId
        : (_userChannels.isNotEmpty &&
            channel.channelId == _userChannels.first.channelId);

    // ✅ Find leader (top points)
    final sortedMembers = List<ChannelMember>.from(channel.members)
      ..sort((a, b) => b.seasonPoints.compareTo(a.seasonPoints));
    final leader = sortedMembers.isNotEmpty ? sortedMembers.first : null;

    return GestureDetector(
      onTap: () => _showChannelLeaderboard(channel),
      onLongPress: () => _openGroupChat(channel),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          // ✅ SAME background for both states - no background change
          color: FanColors.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          // ✅ NO BORDER
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (channel.isAdmin) ...[
              const Text('👑', style: TextStyle(fontSize: 9)),
              const SizedBox(width: 3),
            ],
            // Channel name - ✅ ONLY text color changes
            Text(
              channel.name,
              style: FanTypography.tag.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.normal,
                color: isSelected
                    ? FanColors.primary // ✅ Changed to primary instead of amber
                    : FanColors.textSecondary,
              ),
            ),
            // Leader name + points
            if (leader != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  // ✅ SAME background for both states
                  color: FanColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${leader.username} (${leader.seasonPoints}pts)',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.normal,
                    color: FanColors.primary, // ✅ Same color for both states
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

// ============================================================
// Selected Channel Chip
// ============================================================
  Widget _buildSelectedChannelChip() {
    // Get selected channel or first channel
    UserChannel? selectedChannel;
    if (_selectedChannelId != null) {
      selectedChannel = _userChannels.firstWhere(
        (c) => c.channelId == _selectedChannelId,
        orElse: () => _userChannels.isNotEmpty
            ? _userChannels.first
            : UserChannel(
                channelId: '',
                name: '',
                memberCount: 0,
                season: '',
                members: [],
              ),
      );
    } else if (_userChannels.isNotEmpty) {
      selectedChannel = _userChannels.first;
    }

    if (selectedChannel == null || selectedChannel.channelId.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get top points for this channel
    final sortedMembers = List<ChannelMember>.from(selectedChannel.members)
      ..sort((a, b) => b.seasonPoints.compareTo(a.seasonPoints));
    final topPoints =
        sortedMembers.isNotEmpty ? sortedMembers.first.seasonPoints : 0;

    return GestureDetector(
      onTap: () => _showChannelLeaderboard(selectedChannel!),
      onLongPress: () => _openGroupChat(selectedChannel!),
      child: Container(
        margin: const EdgeInsets.only(right: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: FanColors.surface.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: FanColors.primary,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedChannel.name,
              style: FanTypography.tag.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: FanColors.primary, // ✅ Only text color changes
              ),
            ),
            if (topPoints > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: FanColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${topPoints}pts',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: FanColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

// ============================================================
// Club Chip
// ============================================================
  Widget _buildClubChip() {
    return GestureDetector(
      onTap: _showMyProfile,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: FanColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_soccer, size: 10, color: FanColors.primary),
            const SizedBox(width: 3),
            Text(
              _userData?['club_fan']?.toString() ?? 'No Club',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: FanColors.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

// ============================================================
// Country Chip
// ============================================================
  Widget _buildCountryChip() {
    return GestureDetector(
      onTap: _showMyProfile,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: FanColors.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag, size: 10, color: FanColors.secondary),
            const SizedBox(width: 3),
            Text(
              _userData?['country_fan']?.toString() ?? 'World',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: FanColors.secondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

// ============================================================
// Points Chip
// ============================================================
  Widget _buildPointsChip() {
    return GestureDetector(
      onTap: _showMyProfile,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, size: 10, color: Colors.amber),
            const SizedBox(width: 3),
            Text(
              '${_userData?['points'] ?? 0}pts',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.amber,
              ),
            ),
          ],
        ),
      ),
    );
  }

// ============================================================
// New Channel Chip (+ button)
// ============================================================

  // ==========================================================================
  // BOTTOM CAROUSEL - UPDATED TO SHOW ALL CHANNELS
  // ==========================================================================
  // ==========================================================================
// BOTTOM CAROUSEL - WITH AD INTERLEAVING (3 content items per ad)
// ==========================================================================
  void _buildCarouselWithAds() {
    if (!mounted) return;
    _isRebuildingCarousel = false;

    final newItems = <CarouselItem>[];

    // Use ALL channels (not just user's)
    final displayChannels =
        _allChannels.isNotEmpty ? _allChannels : _userChannels;
    final displayComrades = _getDisplayComrades();

    // Separate lists
    final comrades = List<Map<String, dynamic>>.from(displayComrades);
    final channels = List<UserChannel>.from(displayChannels);
    final adIds = AdHelper.carouselAdUnitIds;

    int comradeIndex = 0;
    int channelIndex = 0;
    int adIndex = 0;
    const int maxItems = 100;

    // Ad frequency: show 3 content items, then 1 ad
    const int contentBeforeAd = 3;
    int itemsSinceLastAd = 0;

    // Interleave: 3 content → 1 ad → 3 content → 1 ad → ...
    for (int i = 0; i < maxItems; i++) {
      // Check if we should insert an ad
      if (itemsSinceLastAd >= contentBeforeAd && adIndex < adIds.length) {
        final adUnitId = adIds[adIndex % adIds.length];
        if (adUnitId.isNotEmpty) {
          newItems.add(CarouselItem.ad(adUnitId: adUnitId));
          adIndex++;
          itemsSinceLastAd = 0;
          continue;
        }
      }

      // Add content (alternate between comrade and channel)
      if (i % 2 == 0 && comradeIndex < comrades.length) {
        final comrade = comrades[comradeIndex++];
        final isAlreadyComrade =
            _isLoggedIn && _addedComradeIds.contains(comrade['id']);
        final voteText = _voteTexts[comradeIndex % _voteTexts.length];

        newItems.add(CarouselItem.comrade(
          comradeData: {
            'id': comrade['id'] ?? '',
            'nickname': comrade['nickname'] ?? 'Fan',
            'username': comrade['username'] ?? 'user',
            'club': comrade['club'] ?? 'Football',
            'country': comrade['country'] ?? 'World',
            'votedFor': comrade['votedFor'] ?? voteText['team'] ?? 'Unknown',
            'fixture': comrade['fixture'] ?? voteText['fixture'] ?? 'Match',
          },
          added: isAlreadyComrade,
        ));
        itemsSinceLastAd++;
      } else if (channelIndex < channels.length) {
        final channel = channels[channelIndex++];
        newItems.add(CarouselItem.channel(channelData: channel));
        itemsSinceLastAd++;
      } else if (comradeIndex < comrades.length) {
        // If no more channels, add comrades
        final comrade = comrades[comradeIndex++];
        final isAlreadyComrade =
            _isLoggedIn && _addedComradeIds.contains(comrade['id']);
        final voteText = _voteTexts[comradeIndex % _voteTexts.length];

        newItems.add(CarouselItem.comrade(
          comradeData: {
            'id': comrade['id'] ?? '',
            'nickname': comrade['nickname'] ?? 'Fan',
            'username': comrade['username'] ?? 'user',
            'club': comrade['club'] ?? 'Football',
            'country': comrade['country'] ?? 'World',
            'votedFor': comrade['votedFor'] ?? voteText['team'] ?? 'Unknown',
            'fixture': comrade['fixture'] ?? voteText['fixture'] ?? 'Match',
          },
          added: isAlreadyComrade,
        ));
        itemsSinceLastAd++;
      } else {
        // No more content - break
        break;
      }
    }

    // If we still have ad slots and items, add one more ad at the end
    if (itemsSinceLastAd > 0 && adIndex < adIds.length) {
      final adUnitId = adIds[adIndex % adIds.length];
      if (adUnitId.isNotEmpty) {
        newItems.add(CarouselItem.ad(adUnitId: adUnitId));
      }
    }

    // Fallback: if empty, add fallback items
    if (newItems.isEmpty) {
      if (displayChannels.isNotEmpty) {
        for (final channel in displayChannels.take(3)) {
          newItems.add(CarouselItem.channel(channelData: channel));
        }
      } else {
        for (int i = 0; i < 4; i++) {
          final adUnitId = adIds.isNotEmpty ? adIds[i % adIds.length] : '';
          if (adUnitId.isNotEmpty) {
            newItems.add(CarouselItem.ad(adUnitId: adUnitId));
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _carouselItems = newItems;
      });
      if (!_isCarouselRunning && newItems.length > 1) {
        _startCarouselAutoScroll();
      }
    }
  }

  void _preloadUpcomingAds(int currentIndex) {
    final totalItems = _carouselItems.length;
    if (currentIndex >= totalItems - 3) {
      final nextAdUnitIds = [
        _adUnitIdForIndex(totalItems),
        _adUnitIdForIndex(totalItems + 1),
        _adUnitIdForIndex(totalItems + 2),
      ].where((id) => id.isNotEmpty).toSet().toList();
      for (final adUnitId in nextAdUnitIds) {
        if (!_preloadedAdUnitIds.contains(adUnitId)) {
          _preloadedAdUnitIds.add(adUnitId);
        }
      }
    }
  }

  void _preloadInitialAds() {
    final List<String> adUnitIds = [];
    for (int i = 0; i < 10; i++) {
      final adUnitId = _adUnitIdForIndex(i);
      if (adUnitId.isNotEmpty && !adUnitIds.contains(adUnitId)) {
        adUnitIds.add(adUnitId);
      }
    }

    for (final adUnitId in adUnitIds) {
      for (int i = 0; i < 3; i++) {
        Future.delayed(Duration(milliseconds: i * 300), () {
          if (!_preloadedAdUnitIds.contains('${adUnitId}_$i')) {
            _preloadedAdUnitIds.add('${adUnitId}_$i');
          }
        });
      }
    }
  }

  List<Map<String, dynamic>> _getDisplayComrades() {
    if (_loadingComrades && _realComrades.isNotEmpty) {
      return List.from(_realComrades);
    }
    if (_loadingComrades) return [];
    if (_comradesError != null && _realComrades.isNotEmpty) {
      return List.from(_realComrades);
    }
    if (_realComrades.isEmpty) return [];
    return List.from(_realComrades);
  }

  void _startCarouselAutoScroll() {
    if (_isCarouselRunning || _carouselItems.length <= 1) return;
    _isCarouselRunning = true;
    _carouselTimer?.cancel();
    bool goingForward = true;
    _carouselTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (!mounted || !_isCarouselRunning) {
        timer.cancel();
        _isCarouselRunning = false;
        return;
      }
      final controller = _carouselController;
      if (controller == null || !controller.hasClients) {
        timer.cancel();
        _isCarouselRunning = false;
        return;
      }
      final itemCount = _carouselItems.length;
      if (itemCount <= 1) {
        timer.cancel();
        _isCarouselRunning = false;
        return;
      }
      int currentPage = controller.page?.round() ?? _currentCarouselIndex;
      int nextIndex;
      if (goingForward) {
        nextIndex = currentPage + 1;
        if (nextIndex >= itemCount) {
          goingForward = false;
          nextIndex = currentPage - 1;
        }
      } else {
        nextIndex = currentPage - 1;
        if (nextIndex < 0) {
          goingForward = true;
          nextIndex = currentPage + 1;
        }
      }
      nextIndex = nextIndex.clamp(0, itemCount - 1);
      controller.animateToPage(nextIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic);
    });
  }

  void _stopCarouselAutoScroll() {
    _isCarouselRunning = false;
    _carouselTimer?.cancel();
    _carouselTimer = null;
  }

  Widget _buildBottomCarousel() {
    if (_carouselItems.isEmpty) {
      if (!_isRebuildingCarousel) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _buildCarouselWithAds());
      }
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 56,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.62,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: PageView.builder(
            controller: _carouselController,
            scrollDirection: Axis.horizontal,
            onPageChanged: (index) {
              setState(() => _currentCarouselIndex = index);
              _preloadUpcomingAds(index);
            },
            itemCount: _carouselItems.length,
            itemBuilder: (context, index) => KeepAliveWrapper(
              key: ValueKey('bottom_carousel_$index'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: _buildCarouselItem(_carouselItems[index], index),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // CAROUSEL ITEMS - UPDATED WITH CHANNEL LIMIT CHECKING
  // ==========================================================================
  Widget _buildCarouselItem(CarouselItem item, int index) {
    final isLeftAligned = index % 2 == 0;

    if (item.type == CarouselItemType.comrade) {
      return SpeechBubble(
        isLeftAligned: isLeftAligned,
        child: _buildComradeCard(item.comradeData!, added: item.added),
      );
    }

    if (item.type == CarouselItemType.channel && item.channelData != null) {
      return SpeechBubble(
        isLeftAligned: isLeftAligned,
        child: _buildChannelCard(item.channelData!),
      );
    }

    final adUnitId = item.adUnitId ?? '';

    if (adUnitId.isEmpty) {
      return const SizedBox.shrink();
    }

    return SpeechBubble(
      isLeftAligned: isLeftAligned,
      child: SizedBox(
        height: 55,
      ),
    );
  }

  // ==========================================================================
  // COMRADE CARD - UPDATED WITH CHANNEL LIMIT AND FULL BUTTON
  // ==========================================================================
  Widget _buildComradeCard(Map<String, dynamic> comrade,
      {required bool added}) {
    final nickname = comrade['nickname'] ?? 'Fan';
    final username = comrade['username'] ?? 'user';
    final team = comrade['votedFor'] ?? 'Unknown';
    final comradeId = comrade['id'] ?? '';

    // Check if comrade is already in any of your channels
    final bool isInYourChannels = _userChannels.any((channel) =>
        _comradesInGroups.contains('${comradeId}_${channel.channelId}'));

    // Check channel limit
    final bool isFull = _userChannels.length >= MAX_CHANNELS;
    final bool isAdmin = _isAdminOfAnyChannel;

    return Row(
      children: [
        GestureDetector(
          onTap: () => _showComradeProfile(comrade),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF0D0B1E),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                nickname[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: FanColors.primary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      nickname,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D0B1E),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '@$username',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF1A1A3E),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0B1E).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.how_to_vote,
                          size: 10,
                          color: const Color(0xFF0D0B1E).withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          team,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF0D0B1E),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0B1E).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people,
                          size: 10,
                          color: const Color(0xFF0D0B1E).withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${_userChannels.length}/$MAX_CHANNELS',
                          style: TextStyle(
                            fontSize: 10,
                            color: _userChannels.length >= MAX_CHANNELS
                                ? FanColors.away
                                : const Color(0xFF0D0B1E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            if (isInYourChannels) {
              _showComradeProfile(comrade);
            } else if (isFull) {
              // Show toast that user is full
              ToastHelper.showWarning(
                'You already have $MAX_CHANNELS channels',
                context: context,
              );
            } else {
              _showAddToGroupsModal(comrade);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isInYourChannels
                  ? const Color(0xFF0D0B1E).withValues(alpha: 0.08)
                  : isFull
                      ? FanColors.away.withValues(alpha: 0.15)
                      : const Color(0xFF0D0B1E),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              isInYourChannels
                  ? 'PROFILE'
                  : isFull
                      ? 'FULL'
                      : isAdmin
                          ? 'ADD'
                          : 'INVITE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isInYourChannels
                    ? const Color(0xFF0D0B1E)
                    : isFull
                        ? FanColors.away
                        : FanColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // CHANNEL CARD - UPDATED TO SHOW TOP MEMBER AND DIRECT JOIN
  // ==========================================================================
  Widget _buildChannelCard(UserChannel channel) {
    final isMember = _isLoggedIn &&
        _userChannels.any((c) => c.channelId == channel.channelId);
    final isPending = _pendingJoinRequests.contains(channel.channelId);
    final isAdmin = channel.isAdmin;
    final isFull = _userChannels.length >= MAX_CHANNELS;

    // Find top member by points
    final sortedMembers = List<ChannelMember>.from(channel.members)
      ..sort((a, b) => b.seasonPoints.compareTo(a.seasonPoints));
    final topMember = sortedMembers.isNotEmpty ? sortedMembers.first : null;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF0D0B1E),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              channel.name.isNotEmpty ? channel.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: FanColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      channel.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D0B1E),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: FanColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '👑',
                        style: TextStyle(fontSize: 9),
                      ),
                    ),
                  ],
                  if (isMember) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '✓',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 10,
                    color: const Color(0xFF0D0B1E).withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${channel.memberCount} members',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF1A1A3E),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (topMember != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.emoji_events,
                      size: 10,
                      color: const Color(0xFFFFD700),
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '${topMember.username} (${topMember.seasonPoints}pts)',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF1A1A3E),
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
        GestureDetector(
          onTap: isMember
              ? () => _openGroupChat(channel)
              : isPending
                  ? null
                  : isFull
                      ? null
                      : () {
                          if (!_isLoggedIn) {
                            _showLoginModal();
                            return;
                          }
                          _requestJoinChannel(channel);
                        },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isMember
                  ? const Color(0xFF0D0B1E).withValues(alpha: 0.08)
                  : isPending
                      ? FanColors.draw.withValues(alpha: 0.2)
                      : isFull
                          ? FanColors.away.withValues(alpha: 0.15)
                          : const Color(0xFF0D0B1E),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              isMember
                  ? 'chat'
                  : isPending
                      ? 'pending'
                      : isFull
                          ? 'full'
                          : 'join',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isMember
                    ? const Color(0xFF0D0B1E)
                    : isPending
                        ? FanColors.textSecondary
                        : isFull
                            ? FanColors.away
                            : FanColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // SHOW ADD TO GROUPS MODAL - KEEP EXISTING
  // ==========================================================================
  void _showAddToGroupsModal(Map<String, dynamic> comrade) {
    if (!_isLoggedIn) {
      _showLoginModal();
      return;
    }

    // ✅ Check if user has any channels
    if (_userChannels.isEmpty) {
      ToastHelper.showWarning('You are not in any channel', context: context);
      return;
    }

    final adminChannels = _userChannels.where((c) => c.isAdmin).toList();

    // ✅ For BOTH admin and non-admin, show channel selection
    // But with different action (ADD vs INVITE)
    _showChannelSelectionModal(comrade, isAdmin: adminChannels.isNotEmpty);
  }

  void _showChannelSelectionModal(Map<String, dynamic> comrade,
      {required bool isAdmin}) {
    final channels = isAdmin
        ? _userChannels
            .where((c) => c.isAdmin)
            .toList() // Admin: only admin channels
        : _userChannels; // Non-admin: all channels

    if (channels.isEmpty) {
      ToastHelper.showWarning(
        isAdmin
            ? 'You are not an admin of any group'
            : 'You are not in any channel',
        context: context,
      );
      return;
    }

    Set<String> selectedChannelIds = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.50,
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
                  color: FanColors.border.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: FanColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          comrade['nickname']?[0]?.toUpperCase() ?? '?',
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
                          Text(
                            isAdmin
                                ? 'Add ${comrade['nickname']}'
                                : 'Invite ${comrade['nickname']}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            isAdmin
                                ? 'Select channels to add them to'
                                : 'Select channels to invite them to',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6),
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
                        child: const Icon(Icons.close,
                            size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: FanColors.border),
              // Channel list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: channels.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: FanColors.border.withOpacity(0.3),
                  ),
                  itemBuilder: (context, index) {
                    final channel = channels[index];
                    final isSelected =
                        selectedChannelIds.contains(channel.channelId);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedChannelIds.remove(channel.channelId);
                          } else {
                            selectedChannelIds.add(channel.channelId);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? FanColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: isSelected
                                      ? FanColors.primary
                                      : FanColors.border,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      size: 12, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1A1A3E),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  channel.name[0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
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
                                  Text(
                                    channel.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.people,
                                        size: 11,
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${channel.memberCount} members',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white.withOpacity(0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (!isAdmin && !isSelected)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: FanColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Member',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: FanColors.textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Action button
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color: FanColors.background,
                  border: Border(
                    top: BorderSide(
                      color: FanColors.border.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: GestureDetector(
                    onTap: selectedChannelIds.isEmpty
                        ? null
                        : () {
                            Navigator.pop(context);
                            if (isAdmin) {
                              _addComradeToChannels(
                                  comrade, selectedChannelIds.toList());
                            } else {
                              _sendInviteToChannels(
                                  comrade, selectedChannelIds.toList());
                            }
                          },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: selectedChannelIds.isEmpty
                            ? FanColors.surface
                            : FanColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          selectedChannelIds.isEmpty
                              ? 'Select Channels'
                              : '${isAdmin ? 'Add' : 'Invite'} to ${selectedChannelIds.length} ${selectedChannelIds.length == 1 ? 'Channel' : 'Channels'}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: selectedChannelIds.isEmpty
                                ? FanColors.textSecondary
                                : Colors.white,
                          ),
                        ),
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

  void _sendInviteToChannels(
      Map<String, dynamic> comrade, List<String> channelIds) {
    if (_authToken == null || channelIds.isEmpty) return;

    final comradeId = comrade['id'] ?? '';
    final comradeName = comrade['nickname'] ?? 'Fan';

    for (final channelId in channelIds) {
      final channelName = _getChannelName(channelId);

      _sendNotification(
        userId: comradeId,
        title: '📨 Channel Invite',
        body: '$_username invited you to join "$channelName"',
        type: 'channel_invite',
        data: {
          'channel_id': channelId,
          'channel_name': channelName,
          'inviter_id': _userId,
          'inviter_name': _username,
        },
      );
    }

    ToastHelper.showSuccess(
      'Invite sent to $comradeName for ${channelIds.length} ${channelIds.length == 1 ? 'channel' : 'channels'}',
      context: context,
    );
  }

  String _getChannelName(String channelId) {
    final channel = _userChannels.firstWhere(
      (c) => c.channelId == channelId,
      orElse: () => UserChannel(
        channelId: '',
        name: 'Unknown',
        memberCount: 0,
        season: '',
        members: [],
      ),
    );
    return channel.name;
  }

  void _addComradeToChannels(
      Map<String, dynamic> comrade, List<String> channelIds) async {
    if (_authToken == null || channelIds.isEmpty) return;

    final comradeId = comrade['id'] ?? '';
    final comradeUsername = comrade['username'] ?? '';
    final comradeName = comrade['nickname'] ?? 'Fan';

    // Fire all adds, then revalidate once everything's in flight.
    final requests = <Future<void>>[];

    for (final channelId in channelIds) {
      requests.add(
        http
            .post(
          Uri.parse('$API_BASE_URL/channels/members/add'),
          headers: {
            'Authorization': 'Bearer $_authToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'channel_id': channelId,
            'members': [
              {
                'user_id': comradeId,
                'username': comradeUsername,
              }
            ],
          }),
        )
            .then((_) {
          _sendNotification(
            userId: comradeId,
            title: '🎉 You\'ve been added!',
            body: 'You were added to ${_getChannelName(channelId)}',
            type: 'comrade_added',
          );
        }),
      );
    }

    await Future.wait(requests);

    ToastHelper.showSuccess(
      'Added $comradeName to ${channelIds.length} ${channelIds.length == 1 ? 'channel' : 'channels'}',
      context: context,
    );

    // ✅ Channel membership (comradesInGroups) changed server-side —
    // revalidate so the UI reflects it without waiting on the timer.
    await _refreshChannelsInBackground();
  }

  // ==========================================================================
  // REQUEST JOIN CHANNEL - UPDATED WITH TOAST AND LINK NOTIFICATION
  // ==========================================================================
  Future<void> _requestJoinChannel(UserChannel channel) async {
    if (_authToken == null) return;

    if (_userChannels.length >= MAX_CHANNELS) {
      ToastHelper.showWarning(
        'You already have $MAX_CHANNELS channels',
        context: context,
      );
      return;
    }

    setState(() {
      _pendingJoinRequests.add(channel.channelId);
    });

    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/channels/request-join'),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'channel_id': channel.channelId,
          'user_id': _userId,
          'username': _username,
          'user_nickname': _userData?['nickname'] ?? _username,
        }),
      );

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);

        // Send join link notification
        await _sendJoinLinkNotification(channel);

        ToastHelper.showSuccess(
          data['message'] ?? 'Join request sent to admin!',
          context: context,
        );
      } else {
        setState(() {
          _pendingJoinRequests.remove(channel.channelId);
        });

        ToastHelper.showError(
          json.decode(response.body)['message'] ?? 'Failed to send request',
          context: context,
        );
      }
    } catch (e) {
      setState(() {
        _pendingJoinRequests.remove(channel.channelId);
      });

      ToastHelper.showError('Error: $e', context: context);
    }
  }

  Future<void> _sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/notifications/send'),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'user_id': userId,
          'title': title,
          'body': body,
          'type': type,
          'data': data ?? {},
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Notification sent to $userId: $title');
      } else {
        debugPrint('❌ Failed to send notification: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Notification error: $e');
    }
  }

  Future<void> _sendJoinLinkNotification(UserChannel channel) async {
    try {
      await _sendNotification(
        userId: _userId,
        title: '🔗 Join Link',
        body: 'Click to join "${channel.name}"',
        type: 'join_link',
        data: {
          'channel_id': channel.channelId,
          'channel_name': channel.name,
          'join_link': 'Funzy://join/${channel.channelId}',
        },
      );
    } catch (e) {
      debugPrint('Failed to send join link: $e');
    }
  }

  // ==========================================================================
  // FETCH COMRADES - KEEP EXISTING
  // ==========================================================================
  Future<void> _fetchRealComrades({bool forceRefresh = false}) async {
    if (AppCache.comrades.isNotEmpty && !forceRefresh) {
      setState(() {
        _realComrades = List<Map<String, dynamic>>.from(AppCache.comrades);
        _addedComradeIds = Set<String>.from(AppCache.addedComradeIds);
        _comradeCount = _addedComradeIds.length;
        _loadingComrades = false;
        _comradesError = null;
      });
      _buildCarouselWithAds();
      _startCarouselAutoScroll();

      // ✅ Revalidate — cache shown immediately, network confirms/updates.
      _refreshComradesInBackground();
      return;
    }

    setState(() {
      _loadingComrades = true;
      _comradesError = null;
      _realComrades = [];
    });

    if (AppCache.comrades.isNotEmpty) {
      setState(() {
        _realComrades = List<Map<String, dynamic>>.from(AppCache.comrades);
        _loadingComrades = false;
      });
      _buildCarouselWithAds();
    }

    await _refreshComradesInBackground();
  }

  Future<void> _refreshComradesInBackground() async {
    await AppCache.refreshComrades(_authToken);

    if (!mounted) return;

    setState(() {
      _realComrades = List<Map<String, dynamic>>.from(AppCache.comrades);
      _loadingComrades = false;
      _comradesError = null;
    });

    _buildCarouselWithAds();
  }

  Future<void> _fetchRealComradesFromApi({bool forceRefresh = false}) async {
    if (!forceRefresh && _realComrades.isNotEmpty) {
      return;
    }

    setState(() {
      _loadingComrades = true;
      _comradesError = null;
    });

    try {
      if (_isLoggedIn) {
        final comradesList = await ComradeService.getUserComrades(
            userId: _userId, authToken: _authToken);
        _addedComradeIds.clear();
        for (var comrade in comradesList) {
          final comradeId = comrade['comrade_id']?.toString();
          if (comradeId != null && comradeId.isNotEmpty) {
            _addedComradeIds.add(comradeId);
          }
        }
        setState(() => _comradeCount = _addedComradeIds.length);
      } else {
        _addedComradeIds.clear();
      }

      final url = '$API_BASE_URL/profile/profiles';
      final headers = {'Content-Type': 'application/json'};
      if (_authToken != null && _authToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_authToken';
      }

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = json.decode(response.body);
        final List<Map<String, dynamic>> profiles =
            data.cast<Map<String, dynamic>>();

        List<Map<String, dynamic>> availableUsers;
        if (_isLoggedIn && _userId.isNotEmpty) {
          availableUsers = profiles
              .where((profile) => profile['user_id']?.toString() != _userId)
              .toList();
        } else {
          availableUsers = List.from(profiles);
        }

        final formattedComrades = availableUsers
            .map((item) => {
                  'id': item['user_id']?.toString() ?? '',
                  'nickname': item['nickname']?.toString() ??
                      item['username']?.toString() ??
                      'Fan',
                  'club': item['club_fan']?.toString() ?? 'Football Fan',
                  'country': item['country_fan']?.toString() ?? 'World',
                  'username': item['username']?.toString() ?? 'user',
                })
            .toList();

        setState(() {
          _realComrades = formattedComrades;
          _loadingComrades = false;
          _comradesError = null;
        });

        AppCache.comrades = List.from(formattedComrades);
        AppCache.addedComradeIds = Set.from(_addedComradeIds);

        await ComradeCacheService().cacheComrades(formattedComrades);
      } else {
        setState(() {
          _loadingComrades = false;
          _comradesError = 'Failed to load profiles';
        });
      }
    } catch (e) {
      setState(() {
        _loadingComrades = false;
        _comradesError = e.toString();
      });
    }

    _isRebuildingCarousel = false;
    _buildCarouselWithAds();

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _startCarouselAutoScroll());
  }

  // ==========================================================================
  // AUTH & VOTE STATUS - KEEP EXISTING
  // ==========================================================================
  Future<void> _checkUserVoteStatus() async {
    if (!_isLoggedIn || _userId.isEmpty) return;

    // ✅ Check from AppCache
    if (AppCache.userVotes.isNotEmpty) {
      setState(() {
        _hasUserVoted = AppCache.userVotes.containsKey(_userId);
      });
      // _checkAndShowWelcomeDialog();
      return;
    }

    // ✅ No votes in cache - set default
    setState(() {
      _hasUserVoted = false;
    });
  }

  void _checkAppCacheReady() {
    // Check if AppCache has data
    if (AppCache.isLoaded &&
        (AppCache.channels.isNotEmpty ||
            AppCache.comrades.isNotEmpty ||
            AppCache.profile != null)) {
      _appCacheReady = true;
      _loadFromAppCache();
    } else {
      // Wait for AppCache to load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _waitForAppCache();
      });
    }
  }

  Future<void> _waitForAppCache() async {
    int attempts = 0;
    while (!AppCache.isLoaded && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
    if (mounted) {
      setState(() {
        _appCacheReady = true;
        _loadFromAppCache();
      });
    }
  }

  Future<void> _loadWelcomeDialogPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() =>
        _hasSeenWelcomeDialog = prefs.getBool('hasSeenWelcomeDialog') ?? false);
  }

  Future<void> _markWelcomeDialogSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenWelcomeDialog', true);
    setState(() => _hasSeenWelcomeDialog = true);
  }

  void _showComradeProfile(Map<String, dynamic> comrade) {
    if (!_isLoggedIn) {
      _showLoginModal();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SwipeableProfileModal(
        apiBaseUrl: 'https://clash-api-m5mr.onrender.com',
        userId: comrade['id'].toString(),
        username: comrade['username'].toString(),
        phone: comrade['phone']?.toString() ?? '',
        userChannels: _userChannels,
        onUserUpdated: (_) {},
        onLogout: () {},
      ),
    );
  }

  // ==========================================================================
  // AUTH STATE HANDLER - KEEP EXISTING
  // ==========================================================================
  void _onAuthStateChanged() {
    if (!mounted) return;
    setState(() {
      _postsPageKey++;
      _fixturesPageKey++;
      if (!_authService.isLoggedIn) {
        _handleLogoutState();
      } else {
        _handleLoginState();
      }
    });
  }

  void _handleLoginState() {
    _loadFromAppCache();
    _fetchComradeStats();
    _checkUserVoteStatus();
    _fixturesPageRefreshKey.currentState?.forceCompleteRefreshExternally();
    _buildCarouselWithAds();
    if (_userId.isNotEmpty) {
      _registerFCMToken(_userId); // ✅ NEW
    }
    _maybeFetchAllChannelsForBrowsing(); // ✅ user may now have < 3 channels, or be full
  }

  Future<void> _loadUserDataFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');
      if (userString != null && mounted) {
        setState(() => _userData = jsonDecode(userString));
      }
    } catch (e) {}
  }

  void _handleLogoutState() {
    _stopCarouselAutoScroll();
    _userData = null;
    _notifications = [];
    _notificationCount = 0;
    _hasUnreadNotifications = false;
    _stopPulsing();
    _saveNotifications();
    _comradesError = null;
    _hasUserVoted = false;
    _loadFromAppCache();
    _fixturesPageRefreshKey.currentState?.forceCompleteRefreshExternally();
    _maybeFetchAllChannelsForBrowsing(); // ✅ logged out → always show browsable channels
  }

  Future<void> _initAsync() async {
    // ✅ Just load from AppCache - NO API CALLS
    if (_isLoggedIn && _userId.isNotEmpty) {
      await _registerFCMToken(_userId);
    }
    _loadFromAppCache();
    _fetchComradeStats();
    _checkUserVoteStatus();
  }

  Future<void> _fetchComradeStats() async {
    if (!_isLoggedIn || _authToken == null) return;

    // ✅ Read from AppCache
    setState(() {
      _comradeCount = AppCache.addedComradeIds.length;
      _maxComrades = 50;
    });
  }

  // ==========================================================================
  // NOTIFICATION HANDLERS - KEEP EXISTING
  // ==========================================================================
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📥 $username wants to join "$channelName"'),
          backgroundColor: FanColors.primary,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.white,
            onPressed: _showPendingRequestsModal,
          ),
        ),
      );

      _addToNotificationList({
        'type': 'join_request',
        'title': '📥 Join Request',
        'body': '$username wants to join "$channelName"',
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });

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
      _loadUserChannels();
      _buildCarouselWithAds();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ You joined "$channelName" 🎉'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      _addToNotificationList({
        'type': 'join_approved',
        'title': '✅ Request Approved!',
        'body': 'You have been added to "$channelName" 🎉',
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });

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
      _buildCarouselWithAds();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Request to join "$channelName" was declined'),
          backgroundColor: FanColors.away,
          duration: const Duration(seconds: 3),
        ),
      );

      _addToNotificationList({
        'type': 'join_rejected',
        'title': '❌ Request Declined',
        'body': 'Your request to join "$channelName" was declined',
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });

      return;
    }

    if (notificationType == 'comrade_added') {
      _fetchRealComrades();
      _fetchComradeStats();

      _addToNotificationList({
        'type': 'comrade_added',
        'title': message['title'] ?? 'New Comrade! 🎉',
        'body': message['body'] ?? 'Someone added you as a comrade',
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message['body'] ?? 'New Comrade added! 🎉'),
          backgroundColor: FanColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );

      return;
    }

    if (notificationType == 'vote_supporter' ||
        notificationType == 'vote_rival') {
      final fixtureId = data['fixture_id']?.toString() ?? '';
      final voterName = data['voter_username']?.toString() ?? 'Someone';
      final teamName = data['team_name']?.toString() ?? '';

      if (fixtureId.isNotEmpty) {
        setState(() {
          _notificationCount++;
        });
      }

      _addToNotificationList({
        'type': notificationType,
        'title': notificationType == 'vote_supporter'
            ? '🎉 Your comrade agrees with you!'
            : '⚔️ Your comrade voted against you!',
        'body': '$voterName voted for $teamName',
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });

      return;
    }

    if (notificationType == 'fixture_comment' ||
        notificationType == 'fixture_comment_push') {
      final fixtureId = data['fixture_id']?.toString() ?? '';
      final commenterName = data['commenter_username']?.toString() ?? 'Someone';
      final commentText = data['comment_text']?.toString() ?? '';

      if (fixtureId.isNotEmpty) {
        setState(() {
          _notificationCount++;
        });
      }

      _addToNotificationList({
        'type': 'fixture_comment',
        'title': '💬 New comment from $commenterName',
        'body': commentText.length > 50
            ? '${commentText.substring(0, 50)}...'
            : commentText,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });

      return;
    }

    if (notificationType == 'fixture_like') {
      final fixtureId = data['fixture_id']?.toString() ?? '';
      final likerName = data['liker_username']?.toString() ?? 'Someone';

      if (fixtureId.isNotEmpty) {
        setState(() {
          _notificationCount++;
        });
      }

      _addToNotificationList({
        'type': 'fixture_like',
        'title': '❤️ $likerName liked your match',
        'body': data['body']?.toString() ?? '',
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });

      return;
    }

    _addToNotificationList({
      'type': notificationType,
      'title': message['title'] ?? 'Notification',
      'body': message['body'] ?? '',
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void _subscribeToNotifications() {
    _notificationSubscription = NotificationService.notificationStream
        .listen(_handleIncomingNotification);
  }

  void _addToNotificationList(Map<String, dynamic> notification) {
    final notificationWithUnread = {
      ...notification,
      'isUnread': true,
    };

    setState(() {
      _notifications.insert(0, notificationWithUnread);
      if (_notifications.length > MAX_NOTIFICATIONS) {
        _notifications = _notifications.take(MAX_NOTIFICATIONS).toList();
      }
      _notificationCount =
          _notifications.where((n) => n['isUnread'] == true).length;
      _hasUnreadNotifications = _notificationCount > 0;
    });
    _saveNotifications();
    _animateNotificationBadge();
    _startPulsing();
  }

  void _animateNotificationBadge() {
    if (_bounceAnimationController.isAnimating) {
      _bounceAnimationController.stop();
    }
    _bounceAnimationController
        .forward()
        .then((_) => _bounceAnimationController.reset());
  }

  void _startPulsing() {
    if (_hasUnreadNotifications && !_pulseAnimationController.isAnimating) {
      _pulseAnimationController.repeat(reverse: true);
    }
  }

  void _stopPulsing() {
    _pulseAnimationController.stop();
    _pulseAnimationController.reset();
    _bounceAnimationController.stop();
    _bounceAnimationController.reset();
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
  Future<void> _syncPendingRequestsFromBackend() async {
    if (!_isLoggedIn || _authToken == null) return;

    try {
      final channelsResponse = await http.get(
        Uri.parse('$API_BASE_URL/channels/user/$_userId'),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
      );

      if (channelsResponse.statusCode != 200) {
        return;
      }

      final channelsData = json.decode(channelsResponse.body);
      final List<dynamic> channels = channelsData['channels'] ?? [];

      int totalPending = 0;
      final Set<String> pendingChannelIds = {};

      for (final channel in channels) {
        final isAdmin = channel['is_admin'] ?? false;
        if (!isAdmin) continue;

        final channelId = channel['channel_id']?.toString() ?? '';
        if (channelId.isEmpty) continue;

        final pendingResponse = await http.get(
          Uri.parse('$API_BASE_URL/channels/$channelId/pending-requests'),
          headers: {
            'Authorization': 'Bearer $_authToken',
            'Content-Type': 'application/json',
          },
        );

        if (pendingResponse.statusCode == 200) {
          final pendingData = json.decode(pendingResponse.body);
          final List<dynamic> requests = pendingData['pending_requests'] ?? [];

          if (requests.isNotEmpty) {
            totalPending += requests.length;
            pendingChannelIds.add(channelId);
          }
        }
      }

      setState(() {
        _pendingJoinCount = totalPending;
        _pendingJoinRequests = pendingChannelIds;
      });

      await _savePendingJoinRequests();
    } catch (e) {
      debugPrint('Failed to sync pending requests: $e');
    }
  }

  void _showPendingRequestsModal() {
    if (_isModalOpen || !mounted) return;

    if (_pendingJoinCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No pending join requests'),
          backgroundColor: FanColors.draw,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _isModalOpen = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PendingRequestsModal(
        userId: _userId,
        username: _username,
        authToken: _authToken,
        userChannels: _userChannels,
        onRequestProcessed: () {
          _loadPendingJoinRequests();
          _loadUserChannels();
          _buildCarouselWithAds();
          setState(() {});
        },
      ),
    ).then((_) {
      _isModalOpen = false;
      _loadPendingJoinRequests();
    });
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
      await prefs.setString('pending_join_requests', json.encode(requests));
    } catch (e) {
      debugPrint('Failed to save pending join requests: $e');
    }
  }

  Widget _buildNotificationIcon() {
    return GestureDetector(
      onTap: _onNotificationsViewed,
      child: SizedBox(
        width: 20,
        height: 20,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(
              child: Text(
                '🔔', // Bell emoji
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.green, // ✅ Green color
                ),
              ),
            ),
            if (_notificationCount > 0 || _pendingJoinCount > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  constraints:
                      const BoxConstraints(minWidth: 14, minHeight: 14),
                  decoration: BoxDecoration(
                    color: FanColors.live,
                    shape: BoxShape.circle,
                    border: Border.all(color: FanColors.background, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      _getBadgeDisplayCount(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getBadgeDisplayCount() {
    final int total = _notificationCount + _pendingJoinCount;

    if (total == 0) {
      return '';
    } else if (total > 99) {
      return '99+';
    } else {
      return total.toString();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      startAppCacheRefresh(); // from main.dart
      _handleAppResume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      stopAppCacheRefresh(); // from main.dart
      _handleAppPause();
    }
  }

  void _handleAppResume() {
    // ✅ Just reload from AppCache - NO API CALLS
    if (_isLoggedIn && _userId.isNotEmpty) {
      _loadFromAppCache();
      _fetchComradeStats();
      _checkUserVoteStatus();
    }
    _loadFromAppCache();
    if (_hasUnreadNotifications && mounted) _startPulsing();
    if (_carouselItems.length > 1 && !_isCarouselRunning) {
      _startCarouselAutoScroll();
    }
  }

  void _handleAppPause() {
    _saveNotifications();
    _stopPulsing();
    _stopCarouselAutoScroll();
  }

  Future<void> _registerFCMToken(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fcmToken = prefs.getString('fcm_token');
      if (fcmToken == null || fcmToken.isEmpty) return;
      final platform = Platform.isIOS ? 'ios' : 'android';
      await NotificationService.registerToken(
          userId: userId,
          fcmToken: fcmToken,
          platform: platform,
          authToken: _authToken);
    } catch (e) {}
  }
    static List<dynamic> _decodeNotifications(String jsonString) {
    try {
      return jsonDecode(jsonString) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  static String _encodeNotifications(List<Map<String, dynamic>> n) {
    try {
      return jsonEncode(n);
    } catch (_) {
      return '[]';
    }
  }

   Future<void> _loadStoredNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('notifications');
      if (stored != null) {
        // ✅ CHANGED — compute() doesn't run in a real isolate on Flutter
        // web; it just adds a Future/message-passing hop on the same UI
        // thread, so it was pure overhead there. Skip it on web.
        final loaded = kIsWeb
            ? _decodeNotifications(stored)
            : await compute(_decodeNotifications, stored);
        if (mounted) {
          setState(() {
            _notifications = List<Map<String, dynamic>>.from(loaded);
            _notificationCount =
                _notifications.where((n) => n['isUnread'] == true).length;
            _hasUnreadNotifications = _notificationCount > 0;
            if (_hasUnreadNotifications) _startPulsing();
          });
        }
      }
      final savedCount = prefs.getInt('notificationCount') ?? 0;
      if (mounted && _notificationCount == 0) {
        setState(() => _notificationCount = savedCount);
      }
    } catch (e) {}
  }

  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // ✅ CHANGED — same reasoning as above.
      final jsonString = kIsWeb
          ? _encodeNotifications(_notifications)
          : await compute(_encodeNotifications, _notifications);
      await prefs.setString('notifications', jsonString);
      await prefs.setInt('notificationCount', _notificationCount);
    } catch (e) {}
  }

  

  void _initAnimations() {
    _pulseAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _pulseScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(
            parent: _pulseAnimationController, curve: Curves.easeInOut));
    _pulseOpacityAnimation = Tween<double>(begin: 1.0, end: 0.6).animate(
        CurvedAnimation(
            parent: _pulseAnimationController, curve: Curves.easeInOut));
    _bounceAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _bounceScaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
        CurvedAnimation(
            parent: _bounceAnimationController, curve: Curves.elasticOut));
    _pulseAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _hasUnreadNotifications) {
        _pulseAnimationController.repeat(reverse: true);
      }
    });
  }

  void _setupBadgeSystem() {
    _loadInitialBadgeCounts();
    _listenForBadgeUpdates();
  }

  Future<void> _loadInitialBadgeCounts() async {
    final counts = await NotificationService.loadInitialBadgeCounts();
    if (mounted) {
      setState(() {
        _totalUnreadCount = counts['unread_comments'] ?? 0;
        _notificationCount = counts['unread_notifications'] ?? 0;
        _hasUnreadNotifications = _notificationCount > 0;
        if (_hasUnreadNotifications) _startPulsing();
      });
    }
  }

  void _listenForBadgeUpdates() {
    _badgeStreamSubscription = NotificationService.badgeStream.listen((event) {
      if (!mounted) return;
      final eventType = event['type'] as String?;

      if (eventType == 'join_request') {
        final channelId = event['channel_id']?.toString() ?? '';
        if (channelId.isNotEmpty) {
          setState(() {
            _pendingJoinRequests.add(channelId);
            _pendingJoinCount = (_pendingJoinCount ?? 0) + 1;
            _notificationCount = (_notificationCount ?? 0) + 1;
          });
          _savePendingJoinRequests();
        }
      } else if (eventType == 'join_approved' || eventType == 'join_rejected') {
        final channelId = event['channel_id']?.toString() ?? '';
        if (channelId.isNotEmpty) {
          setState(() {
            _pendingJoinRequests.remove(channelId);
            _pendingJoinCount =
                _pendingJoinCount > 0 ? _pendingJoinCount - 1 : 0;
            _notificationCount =
                _notificationCount > 0 ? _notificationCount - 1 : 0;
          });
          _savePendingJoinRequests();
        }
      } else if (eventType == 'comment_badge_update') {
        setState(() =>
            _totalUnreadCount = event['total_unread_comments'] as int? ?? 0);
      } else if (eventType == 'comment_badge_cleared') {
        setState(() =>
            _totalUnreadCount = event['total_unread_comments'] as int? ?? 0);
      } else if (eventType == 'comment_badge_cleared_all') {
        setState(() => _totalUnreadCount = 0);
      } else if (eventType == 'notification_badge_update') {
        final total = event['total_unread_notifications'] as int? ?? 0;
        setState(() {
          _notificationCount = total;
          _hasUnreadNotifications = total > 0;
        });
        if (_notificationCount > 0) _startPulsing();
      } else if (eventType == 'notification_badge_cleared_all') {
        setState(() {
          _notificationCount = 0;
          _hasUnreadNotifications = false;
        });
        _stopPulsing();
      }
    });
  }

  Future<void> _markAllCommentsAsRead() async {
    if (!_isLoggedIn || _userId.isEmpty) return;
    try {
      final headers = {'Content-Type': 'application/json'};
      if (_authToken != null && _authToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_authToken';
      }
      final response = await http.post(
          Uri.parse('$API_BASE_URL/comments/mark-all-read/$_userId'),
          headers: headers);
      if (response.statusCode == 200 && mounted) {
        await NotificationService.markAllCommentsAsRead();
      }
    } catch (e) {}
  }

  void _showLoginModal() {
    if (_isModalOpen) return;
    _isModalOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LoginModal(
        messengerKey: messengerKey,
        onLoginSuccess: (userId, username) async {
          await _registerFCMToken(userId);
          await _fetchComradeStats();
          await _fetchRealComrades();
          await _checkUserVoteStatus();
          if (mounted) Navigator.pop(context);
        },
      ),
    ).then((_) => _isModalOpen = false);
  }

  // ==========================================================================
  // MENU - KEEP EXISTING
  // ==========================================================================
  void _showTelegramMenu() {
    if (_isMenuOpen) {
      _hideMenu();
      return;
    }
    _isMenuOpen = true;
    final RenderBox avatarBox = context.findRenderObject() as RenderBox;
    final Offset avatarPosition = avatarBox.localToGlobal(Offset.zero);
    _menuOverlay = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _hideMenu,
        behavior: HitTestBehavior.opaque,
        child: Stack(children: [
          Container(color: FanColors.background.withValues(alpha: 0.7)),
          Positioned(
            top: avatarPosition.dy + 45,
            right: 12,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(10),
              color: FanColors.surfaceElevated,
              child: Container(
                width: 180,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: FanColors.border.withValues(alpha: 0.2),
                        width: 0.5)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _buildMenuItem(
                      icon: Icons.post_add,
                      title: 'Create Channel',
                      onTap: () {
                        _hideMenu();
                        _showCreateChannelModal();
                      }),
                  _buildMenuItem(
                      icon: Icons.post_add,
                      title: 'Create Post',
                      onTap: () {
                        _hideMenu();
                        _showPostModal();
                      }),
                  _buildMenuItem(
                      icon: Icons.person_outline,
                      title: 'Profile',
                      onTap: () {
                        _hideMenu();
                        _showMyProfile();
                      }),
                  _buildMenuItem(
                      icon: Icons.history,
                      title: 'History',
                      onTap: () {
                        _hideMenu();
                      }),
                  _buildMenuItem(
                      icon: Icons.group_add_outlined,
                      title: 'Comrades',
                      onTap: () {
                        _hideMenu();
                        _showComradesModal();
                      }),
                  if (_isAdminOfAnyChannel)
                    _buildMenuItem(
                        icon: Icons.bolt,
                        title: 'Admin Dashboard',
                        onTap: () {
                          _hideMenu();
                          _showAdminDashboard();
                        }),
                  const Divider(height: 1),
                  if (_isLoggedIn)
                    _buildMenuItem(
                        icon: Icons.logout,
                        title: 'Logout',
                        isDestructive: true,
                        onTap: () {
                          _hideMenu();
                          _handleLogout();
                        })
                  else
                    _buildMenuItem(
                        icon: Icons.login,
                        title: 'Login',
                        onTap: () {
                          _hideMenu();
                          _showLoginModal();
                        }),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
    Overlay.of(context).insert(_menuOverlay!);
  }

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
        apiBaseUrl: 'https://clash-api-m5mr.onrender.com',
        userId: _userId,
        username: _username,
        phone: _userData?['phone'] ?? '',
        userChannels: _userChannels,
        onUserUpdated: (userData) {
          setState(() {
            _userData = {
              ...?_userData,
              'nickname': userData.nickname,
              'club_fan': userData.clubFan,
              'country_fan': userData.countryFan,
              'phone': userData.phone,
              'points': userData.balance?.toInt() ?? 0,
            };
          });
          // ✅ Save to AppCache
          AppCache.saveProfile(_userData!);
        },
        onLogout: _handleLogout,
      ),
    );
  }

  void _showCreateChannelModal() {
    if (_isModalOpen || !mounted) return;
    if (!_isLoggedIn) {
      _showLoginModal();
      return;
    }

    // ✅ Block channel creation once the user already belongs to 3 groups
    if (_userChannels.length >= MAX_CHANNELS) {
      ToastHelper.showWarning(
        'You are already in $MAX_CHANNELS groups',
        context: context,
      );
      return;
    }

    _isModalOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateChannelModal(
        userId: _userId,
        username: _username,
        authToken: _authToken,
        onChannelCreated: () {
          _loadUserChannels();
          _buildCarouselWithAds();
          setState(() {});
        },
      ),
    ).then((_) => _isModalOpen = false);
  }

  void _showLeaderborad() {
    if (_isModalOpen || !mounted) return;
    if (!_isLoggedIn) {
      _showLoginModal();
      return;
    }

    // ✅ Check if user has reached max channels
    final approvedChannels =
        _userChannels.where((c) => c.isApproved == true).length;
    if (approvedChannels >= MAX_CHANNELS) {
      ToastHelper.showWarning(
        'You already have $MAX_CHANNELS channels',
        context: context,
      );
      return;
    }

    _isModalOpen = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => JoinGroupsModal(
        userId: _userId,
        username: _username,
        authToken: _authToken,
        userChannels: _userChannels,
        pendingRequests: _pendingJoinRequests,
        onClose: () {
          Navigator.pop(context);
          _isModalOpen = false;
        },
        onChannelJoined: (channelId) {
          // Refresh channels and rebuild UI
          _refreshChannelsInBackground();
          _buildCarouselWithAds();
          setState(() {});
        },
      ),
    ).then((_) {
      _isModalOpen = false;
    });
  }

  void _showLogsModal() {
    if (_isModalOpen || !mounted) return;
    if (!_isLoggedIn) {
      _showLoginModal();
      return;
    }
    _isModalOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
            color: FanColors.background,
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(FanRadius.xl),
                topRight: Radius.circular(FanRadius.xl))),
        child: Column(children: [
          Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                  color: FanColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Icon(Icons.list_alt, color: FanColors.primary, size: 18),
                      const SizedBox(width: 6),
                      Text('Activity Logs',
                          style: FanTypography.headline.copyWith(fontSize: 16))
                    ]),
                    GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                color: FanColors.surface,
                                shape: BoxShape.circle),
                            child: Icon(Icons.close,
                                size: 14, color: FanColors.textSecondary))),
                  ])),
          Divider(height: 1, color: FanColors.border),
        ]),
      ),
    ).then((_) => _isModalOpen = false);
  }

  void _hideMenu() {
    _menuOverlay?.remove();
    _menuOverlay = null;
    _isMenuOpen = false;
  }

  Widget _buildMenuItem(
      {required IconData icon,
      required String title,
      required VoidCallback onTap,
      bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Icon(icon,
                size: 14,
                color: isDestructive ? FanColors.away : FanColors.textPrimary),
            const SizedBox(width: 10),
            Expanded(
                child: Text(title,
                    style: FanTypography.body.copyWith(
                        color: isDestructive
                            ? FanColors.away
                            : FanColors.textPrimary,
                        fontSize: 12))),
          ])),
    );
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
        userId: _userId,
        username: _username,
        authToken: _authToken,
        userChannels: _userChannels,
        pendingJoinCount: _pendingJoinCount,
      ),
    ).then((_) => _isModalOpen = false);
  }

  void _showPostModal() {
    if (_isModalOpen || !mounted) return;
    if (!_isLoggedIn) {
      _showLoginModal();
      return;
    }
    _isModalOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPostModal(
          userId: _userId,
          username: _username,
          onPostCreated: () {
            Navigator.pop(context);
            _isModalOpen = false;
            setState(() => _postsPageKey++);
          }),
    ).then((_) => _isModalOpen = false);
  }

  void _showComradesModal() {
    if (_isModalOpen || !mounted) return;
    if (!_isLoggedIn) {
      _showLoginModal();
      return;
    }
    _isModalOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ComradeListModal(
        currentUserId: _userId,
        authToken: _authToken,
        userChannels: _userChannels,
        comradesList: _addedComradeIds,
        onComradeAdded: () {
          _fetchRealComrades();
          _loadUserChannels();
          _buildCarouselWithAds();
          setState(() {});
        },
      ),
    ).then((_) => _isModalOpen = false);
  }

  void _addComradeDirectly(Map<String, dynamic> comrade) {
    if (!_isLoggedIn) {
      _showLoginModal();
      return;
    }
    if (_addedComradeIds.contains(comrade['id'])) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${comrade['nickname']} is already your comrade'),
          backgroundColor: FanColors.draw,
          duration: const Duration(seconds: 1)));
      return;
    }
    if (_comradeCount >= _maxComrades) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Battalion full! Upgrade to add more comrades'),
          backgroundColor: FanColors.draw,
          duration: Duration(seconds: 1)));
      return;
    }
    setState(() {
      _addedComradeIds.add(comrade['id']);
      _comradeCount++;
    });
    _buildCarouselWithAds();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Added ${comrade['nickname']} as comrade!'),
        backgroundColor: FanColors.primary,
        duration: const Duration(seconds: 1)));
    _addComradeToBackend(comrade);
  }

  Future<void> _addComradeToBackend(Map<String, dynamic> comrade) async {
    if (_authToken == null) return;
    await ComradeService.addComrade(
      userId: _userId,
      comradeId: comrade['id'].toString(),
      username: _username,
      comradeUsername: comrade['username'].toString(),
      comradeNickname: comrade['nickname'].toString(),
      comradeClub: comrade['club']?.toString() ?? '',
      comradeCountry: comrade['country']?.toString() ?? '',
      authToken: _authToken!,
    );
    await _fetchRealComrades();
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    setState(() {
      _userData = null;
      _notifications = [];
      _notificationCount = 0;
      _hasUnreadNotifications = false;
      _stopPulsing();
      _comradeCount = 0;
      _addedComradeIds.clear();
      _comradesInGroups.clear();
      _postsPageKey++;
      _fixturesPageKey++;
      _hasUserVoted = false;
    });
    await _authService.logout();
    await _fetchRealComrades(forceRefresh: true);
    _buildCarouselWithAds();
    if (mounted) _showToast('Logged out successfully');
    _isLoggingOut = false;
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating));
  }

  void _debugInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FanColors.surface,
        title: const Text('Debug Info'),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User ID: $_userId', style: FanTypography.body),
              Text('Logged In: $_isLoggedIn', style: FanTypography.body),
              Text('Comrades: $_comradeCount/$_maxComrades',
                  style: FanTypography.body),
              Text('Real Comrades: ${_realComrades.length}',
                  style: FanTypography.body),
              Text('Carousel Items: ${_carouselItems.length}',
                  style: FanTypography.body),
              Text('Notifications: $_notificationCount',
                  style: FanTypography.body),
              Text('Has User Voted: $_hasUserVoted', style: FanTypography.body),
              Text('Comrades in Groups: ${_comradesInGroups.length}',
                  style: FanTypography.body),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close',
                  style: FanTypography.body
                      .copyWith(color: FanColors.textSecondary)))
        ],
      ),
    );
  }

  // ==========================================================================
  // BOTTOM NAVIGATION - KEEP EXISTING
  // ==========================================================================
  Widget _buildBottomNav() {
    return Positioned(
      bottom: 12,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              color: FanColors.surface,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNavItem(
                      icon: Icons.shield_outlined, label: 'arena', index: 0),
                  _buildNavItem(
                      icon: Icons.newspaper_outlined, label: 'feed', index: 1),
                  _buildNavItem(
                      icon: Icons.shield_outlined, label: 'logs', index: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentPageIndex == index;

    return GestureDetector(
      onTap: () => _onBottomNavItemTapped(index),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isSelected ? FanColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color:
                      isSelected ? FanColors.primary : const Color(0xFF404055),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? FanColors.primary
                        : const Color(0xFF404055),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          if (index == 0 && _totalUnreadCount > 0)
            Positioned(
              top: 6,
              right: 16,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: FanColors.live,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          if (index == 1 && _notificationCount > 0)
            Positioned(
              top: 6,
              right: 16,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: FanColors.live,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onBottomNavItemTapped(int index) {
    if (mounted && _pageController.hasClients) {
      if (index == 0 && _totalUnreadCount > 0) _markAllCommentsAsRead();
      if (index == 1 && _notificationCount > 0) _onNotificationsViewed();
      _pageController.animateToPage(index,
          duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
    }
  }

  void _onPageChanged(int index) {
    if (mounted) {
      setState(() {
        _currentPageIndex = index;
        _visitedPages.add(index);
      });
    }

    if (index == 0) {
      _fixturesPageRefreshKey.currentState?.forceRefreshOnTabVisible();
    } else if (index == 1) {
      if (_totalUnreadCount > 0) _markAllCommentsAsRead();
    }
  }

  Future<void> _loadThemePreference() async {
    // FanTheme.controller already picked up the OS brightness in its own
    // constructor and keeps itself in sync via didChangePlatformBrightness.
    // Nothing to read/write here anymore — just sync the status bar icons
    // to whatever it resolved to.
    _applyStatusBarStyle();
  }

  // ==========================================================================
  // BUILD - KEEP EXISTING
  // ==========================================================================
  @override
  void dispose() {
    _appCacheSubscription?.cancel();
    _appCacheSubscription = null;

    _postsScrollController?.removeListener(_handleScroll);
    _fixturesScrollController?.removeListener(_handleScroll);
    _logsScrollController?.removeListener(_handleScroll); // ✅ ADD

    _pageController.dispose();
    _carouselController?.dispose();
    _postsScrollController?.dispose();
    _fixturesScrollController?.dispose();
    _logsScrollController?.dispose(); // ✅ ADD
    _pulseAnimationController.dispose();
    _bounceAnimationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _notificationSubscription?.cancel();
    _badgeStreamSubscription?.cancel();
    _authService.removeListener(_onAuthStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    _stopCarouselAutoScroll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: FanColors.surfaceElevated, // ✅ Match card background
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isHeaderVisible ? 1.0 : 0.0,
                    child: _isHeaderVisible
                        ? _buildHeaderRow()
                        : const SizedBox.shrink(),
                  ),
                ),
                Expanded(
                  child: Container(
                    color: FanColors
                        .background, // ✅ Different color for fixtures/feed
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      itemCount: 3,
                      itemBuilder: (context, index) {
                        switch (index) {
                          case 0:
                            // Fixtures always builds immediately - it's the
                            // first thing the user sees on cold start.
                            return FixturesPage(
                              key: _fixturesPageRefreshKey,
                              userId: _userId,
                              username: _username,
                              authToken: _authToken,
                              scrollController: _fixturesScrollController,
                              onLogout: _handleLogout,
                              isLoggedIn: _isLoggedIn,
                              syncToFixtures: _syncToFixtures,
                              selectedChannelId: _selectedChannelId,
                              selectedChannelName: _selectedChannelName,
                              userChannels:
                                  _syncToFixtures ? _userChannels : const [],
                            );

                          case 1:
                            // Only construct PostsPage (and fire its
                            // initState) the first time the user actually
                            // swipes to this tab.
                            if (!_visitedPages.contains(1)) {
                              return const SizedBox.shrink();
                            }
                            return PostsPage(
                              key: ValueKey('posts_${_postsPageKey}_$_userId'),
                              currentUserId: _userId,
                              currentUsername: _username,
                              authToken: _authToken,
                              scrollController: _postsScrollController,
                              onLogout: _handleLogout,
                              isLoggedIn: _isLoggedIn,
                            );

                          case 2:
                            // Same deferred-build treatment for History.
                            if (!_visitedPages.contains(2)) {
                              return const SizedBox.shrink();
                            }
                            return HistoryPage(
                              userId: _userId,
                              username: _username,
                              authToken: _authToken,
                              isLoggedIn: _isLoggedIn,
                              userChannels: _userChannels,
                              scrollController: _logsScrollController,
                            );

                          default:
                            return const SizedBox.shrink();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            _buildBottomCarousel(),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PENDING JOIN REQUESTS MODAL - KEEP EXISTING
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $username approved!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        widget.onRequestProcessed();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve request'),
            backgroundColor: FanColors.away,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error approving request: $e');
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Request from $username declined'),
            backgroundColor: FanColors.away,
            duration: const Duration(seconds: 2),
          ),
        );

        widget.onRequestProcessed();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject request'),
            backgroundColor: FanColors.away,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error rejecting request: $e');
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
        borderRadius: BorderRadius.only(
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
                              ...requests.map((request) => _buildRequestTile(
                                    channelId: channelId,
                                    request: request,
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

  // ============================================================
// THEME TOGGLE - Dark/Light mode switch
// ============================================================

  Widget _buildRequestTile({
    required String channelId,
    required Map<String, dynamic> request,
  }) {
    final userId = request['user_id']?.toString() ?? '';
    final username = request['username']?.toString() ?? 'Unknown';
    final requestedAt = request['requested_at'] as DateTime? ?? DateTime.now();
    final timeAgo = DateHelper.formatTimeAgo(requestedAt);
    final isProcessing = _isProcessing && _processingUserId == userId;

    return Container(
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
              color: FanColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: isProcessing
                    ? null
                    : () => _rejectRequest(channelId, userId, username),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: FanColors.away.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: isProcessing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: FanColors.away,
                          ),
                        )
                      : Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: FanColors.away,
                        ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: isProcessing
                    ? null
                    : () => _approveRequest(channelId, userId, username),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: FanColors.secondary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: isProcessing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: FanColors.secondary,
                          ),
                        )
                      : Icon(
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
    );
  }
}

// ============================================================================
// COMRADE CACHE SERVICE - KEEP EXISTING
// ============================================================================
class ComradeCacheService {
  static final ComradeCacheService _instance = ComradeCacheService._internal();
  factory ComradeCacheService() => _instance;
  ComradeCacheService._internal();

  static const String _cacheKey = 'cached_comrades';
  static const String _timestampKey = 'comrades_cache_timestamp';
  static const Duration _cacheDuration = Duration(minutes: 30);

  Future<void> cacheComrades(List<Map<String, dynamic>> comrades) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(comrades));
      await prefs.setString(_timestampKey, DateTime.now().toIso8601String());
    } catch (e) {}
  }

  Future<List<Map<String, dynamic>>> getCachedComrades() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampStr = prefs.getString(_timestampKey);
      if (timestampStr != null) {
        final cacheTime = DateTime.parse(timestampStr);
        if (DateTime.now().difference(cacheTime) > _cacheDuration) return [];
      } else {
        return [];
      }
      final jsonString = prefs.getString(_cacheKey);
      if (jsonString != null) {
        final decoded = jsonDecode(jsonString) as List;
        return decoded.cast<Map<String, dynamic>>();
      }
    } catch (e) {}
    return [];
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_timestampKey);
    } catch (e) {}
  }
}

// ============================================================================
// USER CHANNEL MODEL - KEEP EXISTING
// ============================================================================

// ============================================================================
// CHANNEL MEMBER MODEL - KEEP EXISTING
// ============================================================================

// ============================================================================
// KEEP ALIVE WRAPPER - KEEP EXISTING
// ============================================================================
class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ============================================================================
// DATE HELPER - KEEP EXISTING
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
