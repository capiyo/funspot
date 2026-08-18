// modals/comrade_list_modal.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../pages/fan_Funzy_design.dart';
import '../../services/auth_service.dart';
import '../../services/toast_helper.dart';
import '../../models/fixture_models.dart';
import '../../screens/home_page.dart' show UserChannel;
import "../../models/user_channel.dart";

// ============================================================================
// COMRADE MODEL
// ============================================================================
class ComradeProfile {
  final String id;
  final String username;
  final String nickname;
  final String clubFan;
  final String countryFan;
  final String phone;
  final double balance;
  final int numberOfBets;

  ComradeProfile({
    required this.id,
    required this.username,
    required this.nickname,
    required this.clubFan,
    required this.countryFan,
    required this.phone,
    required this.balance,
    required this.numberOfBets,
  });

  factory ComradeProfile.fromJson(Map<String, dynamic> json) {
    return ComradeProfile(
      id: json['user_id']?.toString() ?? json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      nickname:
          json['nickname']?.toString() ?? json['username']?.toString() ?? 'Fan',
      clubFan: json['club_fan']?.toString() ?? '⚽ Football Fan',
      countryFan: json['country_fan']?.toString() ?? '🌍 World',
      phone: json['phone']?.toString() ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      numberOfBets: json['number_of_bets'] ?? 0,
    );
  }

  String get initials => nickname.isNotEmpty ? nickname[0].toUpperCase() : '?';
  String get displayBalance => 'KES ${balance.toStringAsFixed(2)}';
}

// ============================================================================
// MAIN MODAL
// ============================================================================
class ComradeListModal extends StatefulWidget {
  final String currentUserId;
  final String? authToken;
  final List<UserChannel> userChannels;
  final Set<String> comradesList;
  final VoidCallback? onComradeAdded;

  const ComradeListModal({
    super.key,
    required this.currentUserId,
    this.authToken,
    required this.userChannels,
    required this.comradesList,
    this.onComradeAdded,
  });

  @override
  State<ComradeListModal> createState() => _ComradeListModalState();
}

class _ComradeListModalState extends State<ComradeListModal> {
  // ==========================================================================
  // STATE
  // ==========================================================================
  List<ComradeProfile> _comrades = [];
  List<ComradeProfile> _filteredComrades = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _error;

  // Selection for add/invite
  Set<String> _selectedComradeIds = {};
  Set<String> _selectedChannelIds = {};
  bool _isProcessing = false;

  // View profile
  ComradeProfile? _viewingProfile;

  // Admin channels
  List<UserChannel> get _adminChannels =>
      widget.userChannels.where((c) => c.isAdmin).toList();

  bool get _hasAdminChannels => _adminChannels.isNotEmpty;

  static const String _api = 'https://clash-api-m5mr.onrender.com/api';

  // ==========================================================================
  // INIT
  // ==========================================================================
  @override
  void initState() {
    super.initState();
    _fetchComrades();
  }

  // ==========================================================================
  // FETCH COMRADES
  // ==========================================================================
  Future<void> _fetchComrades() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final headers = {
        'Content-Type': 'application/json',
      };
      if (widget.authToken != null && widget.authToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${widget.authToken}';
      }

      final response = await http
          .get(
            Uri.parse('$_api/profile/profiles'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = json.decode(response.body);
        final profiles = data
            .where(
                (item) => item['user_id']?.toString() != widget.currentUserId)
            .map((item) => ComradeProfile.fromJson(item))
            .toList();

        setState(() {
          _comrades = profiles;
          _filteredComrades = profiles;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load comrades';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================
  int get _userChannelCount => widget.userChannels.length;
  int get _maxChannels => 3;
  int get _remainingSlots => _maxChannels - _userChannelCount;

  bool _isComradeAdded(String comradeId) =>
      widget.comradesList.contains(comradeId);

  bool _isUserInChannel(String userId, String channelId) {
    final channel = widget.userChannels.firstWhere(
      (c) => c.channelId == channelId,
      orElse: () => UserChannel(
        channelId: '',
        name: '',
        memberCount: 0,
        season: '',
        members: [],
      ),
    );
    return channel.members.any((m) => m.userId == userId);
  }

  bool _canAddUser(String userId) {
    if (_remainingSlots <= 0) return false;
    if (_isComradeAdded(userId)) return false;
    return true;
  }

  // ==========================================================================
  // ADD TO CHANNELS (Admin)
  // ==========================================================================
  Future<void> _addToChannels(String comradeId, String comradeUsername) async {
    if (_selectedChannelIds.isEmpty || widget.authToken == null) return;

    setState(() => _isProcessing = true);

    try {
      final List<Map<String, dynamic>> results = [];

      for (final channelId in _selectedChannelIds) {
        if (_isUserInChannel(comradeId, channelId)) {
          results.add({
            'channel_id': channelId,
            'success': false,
            'message': 'Already in channel',
          });
          continue;
        }

        final response = await http.post(
          Uri.parse('$_api/channels/members/add'),
          headers: {
            'Authorization': 'Bearer ${widget.authToken}',
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
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          results.add({
            'channel_id': channelId,
            'success': true,
            'message': 'Added successfully',
          });

          await _sendNotification(
            userId: comradeId,
            title: '🎉 You\'ve been added!',
            body: 'You were added to ${_getChannelName(channelId)}',
            type: 'comrade_added',
          );
        } else {
          results.add({
            'channel_id': channelId,
            'success': false,
            'message': json.decode(response.body)['message'] ?? 'Failed to add',
          });
        }
      }

      setState(() => _isProcessing = false);

      final successCount = results.where((r) => r['success']).length;
      final failCount = results.where((r) => !r['success']).length;

      if (successCount > 0) {
        ToastHelper.showSuccess(
          'Added to $successCount ${successCount == 1 ? 'channel' : 'channels'}${failCount > 0 ? ' ($failCount failed)' : ''}',
        );
        widget.onComradeAdded?.call();
        _selectedComradeIds.clear();
        _selectedChannelIds.clear();
        _fetchComrades();
      } else {
        ToastHelper.showError('Failed to add to channels');
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ToastHelper.showError('Error: $e');
    }
  }

  String _getChannelName(String channelId) {
    final channel = widget.userChannels.firstWhere(
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

  Future<void> _sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      await http.post(
        Uri.parse('$_api/notifications/send'),
        headers: {
          'Authorization': 'Bearer ${widget.authToken}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'user_id': userId,
          'title': title,
          'body': body,
          'type': type,
          'data': {},
        }),
      );
    } catch (e) {
      debugPrint('Notification error: $e');
    }
  }

  // ==========================================================================
  // INVITE TO CHANNELS (Non-Admin)
  // ==========================================================================
  Future<void> _inviteToChannels(
      String comradeId, String comradeUsername) async {
    if (_selectedChannelIds.isEmpty || widget.authToken == null) return;

    setState(() => _isProcessing = true);

    try {
      for (final channelId in _selectedChannelIds) {
        final channelName = _getChannelName(channelId);

        await http.post(
          Uri.parse('$_api/notifications/send'),
          headers: {
            'Authorization': 'Bearer ${widget.authToken}',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'user_id': comradeId,
            'title': '📨 Channel Invite',
            'body': '$comradeUsername invited you to join "$channelName"',
            'type': 'channel_invite',
            'data': {
              'channel_id': channelId,
              'channel_name': channelName,
              'inviter_id': widget.currentUserId,
              'inviter_name': widget.userChannels
                  .firstWhere(
                    (c) => c.channelId == channelId,
                    orElse: () => UserChannel(
                      channelId: '',
                      name: '',
                      memberCount: 0,
                      season: '',
                      members: [],
                    ),
                  )
                  .name,
            },
          }),
        );
      }

      setState(() => _isProcessing = false);
      ToastHelper.showSuccess('Invites sent successfully!');
      _selectedComradeIds.clear();
      _selectedChannelIds.clear();
    } catch (e) {
      setState(() => _isProcessing = false);
      ToastHelper.showError('Failed to send invites: $e');
    }
  }

  // ==========================================================================
  // UI BUILDERS
  // ==========================================================================

  Widget _buildHandle() => Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: FanColors.border.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: FanColors.primaryDim,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(Icons.people, size: 22, color: FanColors.primary),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comrades',
                    style: FanTypography.body.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: FanColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${_filteredComrades.length} available',
                    style: FanTypography.caption.copyWith(
                      fontSize: 12,
                      color: FanColors.textSecondary,
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
                    Icon(Icons.close, size: 18, color: FanColors.textSecondary),
              ),
            ),
          ],
        ),
      );

  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: FanColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FanColors.border.withOpacity(0.3)),
          ),
          child: TextField(
            style: TextStyle(color: FanColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search comrades...',
              hintStyle: TextStyle(
                fontSize: 12,
                color: FanColors.textSecondary.withOpacity(0.6),
              ),
              prefixIcon: Icon(Icons.search_rounded,
                  size: 18, color: FanColors.textSecondary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (query) {
              setState(() {
                _searchQuery = query.toLowerCase();
                _filteredComrades = _comrades.where((c) {
                  final name = c.nickname.toLowerCase();
                  final username = c.username.toLowerCase();
                  final club = c.clubFan.toLowerCase();
                  return name.contains(query) ||
                      username.contains(query) ||
                      club.contains(query);
                }).toList();
              });
            },
          ),
        ),
      );

  // ==========================================================================
  // COMRADE CARD
  // ==========================================================================
  Widget _buildComradeCard(ComradeProfile comrade) {
    final isAdded = _isComradeAdded(comrade.id);
    final isSelected = _selectedComradeIds.contains(comrade.id);
    final isFull = _remainingSlots <= 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected
            ? FanColors.primaryDim
            : FanColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? FanColors.primary.withOpacity(0.5)
              : FanColors.border.withOpacity(0.15),
          width: isSelected ? 1.5 : 0.5,
        ),
      ),
      child: Column(
        children: [
          // Main row
          Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: FanColors.primaryDim,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: FanColors.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    comrade.initials,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: FanColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comrade.nickname,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: FanColors.textPrimary,
                          ),
                        ),
                        if (isAdded) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: FanColors.primaryDim,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '✓ Added',
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
                    const SizedBox(height: 2),
                    Text(
                      '@${comrade.username}',
                      style: TextStyle(
                        fontSize: 11,
                        color: FanColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.sports_soccer,
                          size: 10,
                          color: FanColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          comrade.clubFan,
                          style: TextStyle(
                            fontSize: 10,
                            color: FanColors.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.flag,
                          size: 10,
                          color: FanColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          comrade.countryFan,
                          style: TextStyle(
                            fontSize: 10,
                            color: FanColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Votes badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: FanColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: FanColors.border.withOpacity(0.3)),
                ),
                child: Text(
                  '${comrade.numberOfBets} votes',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: FanColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          // Actions row
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Profile button
              _buildActionButton(
                label: 'Profile',
                icon: Icons.person_outline,
                onTap: () => _showProfileView(comrade),
                color: FanColors.textSecondary,
              ),
              const SizedBox(width: 8),

              // Add/Invite button
              if (!isAdded)
                _buildActionButton(
                  label:
                      isFull ? 'Full' : (_hasAdminChannels ? 'Add' : 'Invite'),
                  icon: isFull
                      ? Icons.lock
                      : (_hasAdminChannels
                          ? Icons.person_add_alt_1
                          : Icons.send),
                  onTap: isFull ? null : () => _showActionModal(comrade),
                  isFull: isFull,
                  color: isFull ? FanColors.away : FanColors.primary,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
    bool isFull = false,
    Color? color,
  }) {
    final buttonColor = color ?? FanColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: buttonColor.withOpacity(0.08),
          border: Border.all(
            color: buttonColor.withOpacity(0.3),
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: buttonColor,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: buttonColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // ACTION MODAL (Add/Invite)
  // ==========================================================================
  void _showActionModal(ComradeProfile comrade) {
    final isAdmin = _hasAdminChannels;
    final isFull = _remainingSlots <= 0;

    if (isFull) {
      ToastHelper.showWarning('${comrade.nickname} already has 3 channels');
      return;
    }

    setState(() {
      _selectedComradeIds.add(comrade.id);
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.50,
        decoration:  BoxDecoration(
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
                color: FanColors.border.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: FanColors.primaryDim,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        comrade.initials,
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
                              ? 'Add ${comrade.nickname}'
                              : 'Invite ${comrade.nickname}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: FanColors.textPrimary,
                          ),
                        ),
                        Text(
                          isAdmin
                              ? 'Select channels to add ${comrade.nickname}'
                              : 'Select channels to invite ${comrade.nickname}',
                          style: TextStyle(
                            fontSize: 12,
                            color: FanColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedComradeIds.clear();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: FanColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close,
                          size: 18, color: FanColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: FanColors.border.withOpacity(0.3)),

            // Channel list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _adminChannels.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: FanColors.border.withOpacity(0.3),
                ),
                itemBuilder: (context, index) {
                  final channel = _adminChannels[index];
                  final isSelected =
                      _selectedChannelIds.contains(channel.channelId);
                  final isUserInChannel =
                      _isUserInChannel(comrade.id, channel.channelId);

                  return GestureDetector(
                    onTap: isUserInChannel
                        ? null
                        : () {
                            setState(() {
                              if (isSelected) {
                                _selectedChannelIds.remove(channel.channelId);
                              } else {
                                _selectedChannelIds.add(channel.channelId);
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
                            decoration: BoxDecoration(
                              color: FanColors.primaryDim,
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
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: FanColors.textPrimary,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.people,
                                      size: 11,
                                      color: FanColors.textTertiary,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${channel.memberCount} members',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: FanColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isUserInChannel)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: FanColors.primaryDim,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '✓ In',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: FanColors.primary,
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
                  onTap: _selectedChannelIds.isEmpty
                      ? null
                      : _isProcessing
                          ? null
                          : () {
                              Navigator.pop(context);
                              if (isAdmin) {
                                _addToChannels(comrade.id, comrade.username);
                              } else {
                                _inviteToChannels(comrade.id, comrade.username);
                              }
                              setState(() {
                                _selectedComradeIds.clear();
                              });
                            },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: _selectedChannelIds.isEmpty
                          ? FanColors.surface
                          : FanColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isProcessing
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
                                  : '${isAdmin ? 'Add' : 'Invite'} to ${_selectedChannelIds.length} ${_selectedChannelIds.length == 1 ? 'Channel' : 'Channels'}',
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
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // PROFILE VIEW
  // ==========================================================================
  void _showProfileView(ComradeProfile comrade) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FanColors.border.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: FanColors.primaryDim,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: FanColors.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        comrade.initials,
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
                          comrade.nickname,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: FanColors.textPrimary,
                          ),
                        ),
                        Text(
                          '@${comrade.username}',
                          style: TextStyle(
                            fontSize: 13,
                            color: FanColors.textSecondary,
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
                      child: Icon(Icons.close,
                          size: 18, color: FanColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: FanColors.border.withOpacity(0.3)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats row
                    Row(
                      children: [
                        _buildProfileStat(
                          '${comrade.numberOfBets}',
                          'Bets',
                          FanColors.primary,
                        ),
                        _buildProfileStat(
                          comrade.numberOfBets > 0 ? '✅' : '📭',
                          'Status',
                          FanColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Info rows
                    _buildProfileInfoRow(
                        'Club', comrade.clubFan, Icons.sports_soccer),
                    const SizedBox(height: 8),
                    _buildProfileInfoRow(
                        'Country', comrade.countryFan, Icons.flag),
                    const SizedBox(height: 8),
                    _buildProfileInfoRow('Phone', comrade.phone, Icons.phone),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: FanColors.surfaceSunken,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: FanColors.border.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: FanColors.textTertiary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isComradeAdded(comrade.id)
                                  ? '✅ Already in your comrades list'
                                  : '📨 Not in your comrades list',
                              style: TextStyle(
                                fontSize: 11,
                                color: _isComradeAdded(comrade.id)
                                    ? FanColors.primary
                                    : FanColors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    border: Border.all(color: FanColors.border, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: FanColors.textPrimary,
                      ),
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

  Widget _buildProfileStat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: FanColors.surfaceSunken,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: FanColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FanColors.surfaceSunken,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: FanColors.textSecondary),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: FanColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'Not set',
              style: TextStyle(
                fontSize: 12,
                color: FanColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // MAIN BUILD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration:  BoxDecoration(
        color: FanColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(FanRadius.xl),
          topRight: Radius.circular(FanRadius.xl),
        ),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          _buildSearchBar(),
          Divider(height: 1, color: FanColors.border.withOpacity(0.3)),
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: FanColors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Loading comrades...',
                          style: TextStyle(
                            fontSize: 13,
                            color: FanColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: FanColors.away.withOpacity(0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: TextStyle(
                                fontSize: 14,
                                color: FanColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: _fetchComrades,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: FanColors.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Retry',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _filteredComrades.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 48,
                                  color:
                                      FanColors.textTertiary.withOpacity(0.4),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No comrades found'
                                      : 'No results for "$_searchQuery"',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: FanColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: _filteredComrades.length,
                            itemBuilder: (context, index) {
                              return _buildComradeCard(
                                  _filteredComrades[index]);
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
