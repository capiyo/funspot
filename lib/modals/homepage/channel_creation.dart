import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../main.dart';
import "../../pages/fan_Funzy_design.dart";

// ============================================================================
// CHANNEL CREATION MODAL - REDESIGNED WITH FANFunzy DESIGN SYSTEM
// ============================================================================
class CreateChannelModal extends StatefulWidget {
  final String userId;
  final String username;
  final String? authToken;
  final VoidCallback onChannelCreated;

  const CreateChannelModal({
    super.key,
    required this.userId,
    required this.username,
    this.authToken,
    required this.onChannelCreated,
  });

  @override
  State<CreateChannelModal> createState() => _CreateChannelModalState();
}

class _CreateChannelModalState extends State<CreateChannelModal> {
  // ==========================================================================
  // CONTROLLERS
  // ==========================================================================
  final TextEditingController _channelNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // ==========================================================================
  // STATE
  // ==========================================================================
  List<UserProfile> _allUsers = [];
  List<UserProfile> _filteredUsers = [];
  List<UserProfile> _selectedMembers = [];
  bool _isLoading = true;
  bool _isCreating = false;
  String _searchQuery = '';
  bool _showOnlyAvailable = false;

  // ==========================================================================
  // CONSTANTS
  // ==========================================================================
  static const String API_BASE_URL = 'https://clash-api-m5mr.onrender.com/api';

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================
  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _channelNameController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ==========================================================================
  // LOAD USERS (+ channel history)
  // ==========================================================================
  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (widget.authToken != null && widget.authToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${widget.authToken}';
      }

      // Fetch profiles and all channels in parallel so we can attach each
      // user's existing channel membership/role history to their tile.
      final results = await Future.wait([
        http
            .get(
              Uri.parse('$API_BASE_URL/profile/profiles'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 15)),
        http
            .get(
              Uri.parse('$API_BASE_URL/channels/all'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 15)),
      ]);

      final profilesResponse = results[0];
      final channelsResponse = results[1];

      if (profilesResponse.statusCode != 200 || !mounted) {
        setState(() => _isLoading = false);
        _showToast('Failed to load users', isError: true);
        return;
      }

      final List<dynamic> profileData = json.decode(profilesResponse.body);
      final List<UserProfile> users = profileData
          .map((item) => UserProfile.fromJson(item as Map<String, dynamic>))
          .where((user) => user.id != widget.userId)
          .toList();

      // Build a map of user_id -> [ChannelMembership] from every channel's
      // members array (mirrors the "channels" collection shape: each
      // channel has channel_id, name, and a members[] with the full
      // per-member document: user_id, username, role, joined_at,
      // season_points, correct_votes, total_votes, msg_count,
      // last_active_at, likes_count).
      final Map<String, List<ChannelMembership>> historyByUserId = {};

      if (channelsResponse.statusCode == 200) {
        try {
          final decoded = json.decode(channelsResponse.body);
          final List<dynamic> channelsList = decoded is Map
              ? (decoded['channels'] ?? [])
              : (decoded is List ? decoded : []);

          for (final rawChannel in channelsList) {
            if (rawChannel is! Map<String, dynamic>) continue;

            final channelId = rawChannel['channel_id']?.toString() ??
                rawChannel['_id']?.toString() ??
                '';
            final channelName = rawChannel['name']?.toString() ?? 'Channel';
            final List<dynamic> members = rawChannel['members'] ?? [];

            for (final rawMember in members) {
              if (rawMember is! Map<String, dynamic>) continue;

              final memberUserId = rawMember['user_id']?.toString() ?? '';
              if (memberUserId.isEmpty) continue;

              historyByUserId.putIfAbsent(memberUserId, () => []).add(
                    ChannelMembership.fromJson(
                      rawMember,
                      channelId: channelId,
                      channelName: channelName,
                    ),
                  );
            }
          }
        } catch (e) {
          debugPrint('⚠️ Failed to parse channel history: $e');
        }
      } else {
        debugPrint(
            '⚠️ Failed to load channels for history: ${channelsResponse.statusCode}');
      }

      // Attach history to each user (defaults to empty list if none found).
      for (final user in users) {
        user.channelHistory = historyByUserId[user.userId] ?? const [];
      }

      if (mounted) {
        setState(() {
          _allUsers = users;
          _filteredUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showToast('Error loading users: $e', isError: true);
    }
  }

  // ==========================================================================
  // FILTER USERS
  // ==========================================================================
  void _filterUsers(String query) {
    setState(() {
      _searchQuery = query;
      _filteredUsers = _allUsers.where((user) {
        final matchesSearch = query.isEmpty ||
            user.nickname.toLowerCase().contains(query.toLowerCase()) ||
            user.username.toLowerCase().contains(query.toLowerCase()) ||
            user.clubFan.toLowerCase().contains(query.toLowerCase()) ||
            user.countryFan.toLowerCase().contains(query.toLowerCase());

        final isAvailable =
            !_selectedMembers.any((m) => m.userId == user.userId);

        return matchesSearch && (_showOnlyAvailable ? isAvailable : true);
      }).toList();
    });
  }

  // ==========================================================================
  // TOGGLE MEMBER SELECTION
  // ==========================================================================
  void _toggleMember(UserProfile user) {
    setState(() {
      if (_selectedMembers.any((m) => m.userId == user.userId)) {
        _selectedMembers.removeWhere((m) => m.userId == user.userId);
      } else {
        _selectedMembers.add(user);
      }
      _filterUsers(_searchQuery);
    });
  }

  // ==========================================================================
  // CREATE CHANNEL
  // ==========================================================================
  // NOTE: only user_id + username are sent per member. The backend's
  // create_channel_handler resolves and seeds season_points/correct_votes/
  // total_votes/msg_count/likes_count itself (via resolve_member_seed_stats),
  // pulling from the user's existing channel membership if they have one —
  // so the client doesn't need to compute or send any of that.
  Future<void> _createChannel() async {
    final channelName = _channelNameController.text.trim();

    if (channelName.isEmpty) {
      _showToast('Please enter a channel name', isError: true);
      return;
    }

    if (_selectedMembers.isEmpty) {
      _showToast('Please select at least one member', isError: true);
      return;
    }

    setState(() => _isCreating = true);

    try {
      final members = _selectedMembers.map((user) {
        return {
          'user_id': user.id,
          'username': user.username,
        };
      }).toList();

      final requestBody = {
        'name': channelName,
        'created_by': widget.userId,
        'created_by_username': widget.username,
        'season': '2024',
        'members': members,
      };

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (widget.authToken != null && widget.authToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${widget.authToken}';
      }

      final response = await http.post(
        Uri.parse('$API_BASE_URL/channels/create'),
        headers: headers,
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        _showToast('✅ Channel created! Invite: ${data['invite_code']}');
        widget.onChannelCreated();
        if (mounted) Navigator.pop(context);
      } else {
        final error = json.decode(response.body);
        _showToast('Error: ${error['message'] ?? response.body}',
            isError: true);
      }
    } catch (e) {
      _showToast('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  // ==========================================================================
  // TOAST
  // ==========================================================================
  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: isError ? FanColors.away : FanColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: FanRadius.lgAll,
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: FanDecorations.card(isActive: true).copyWith(
          color: FanColors.background,
          borderRadius: FanRadius.xlAll,
          border: Border.all(color: FanColors.border, width: 1),
        ),
        child: Column(
          children: [
            _buildHandle(),
            _buildHeader(),
            _buildChannelNameInput(),
            _buildMemberSection(),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD: HANDLE
  // ==========================================================================
  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: FanColors.border,
          borderRadius: FanRadius.pillAll,
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD: HEADER
  // ==========================================================================
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(FanSpacing.xl, 8, FanSpacing.xl, 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: FanColors.primaryMuted,
              shape: BoxShape.circle,
              border: Border.all(color: FanColors.borderActive, width: 1),
            ),
            child: Icon(
              Icons.group_add,
              color: FanColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Channel',
                  style: FanTypography.headline.copyWith(fontSize: 18),
                ),
                Text(
                  'Add members to your group',
                  style: FanTypography.caption,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: FanColors.surfaceSunken,
                shape: BoxShape.circle,
                border: Border.all(color: FanColors.border, width: 1),
              ),
              child: Icon(
                Icons.close,
                color: FanColors.textSecondary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BUILD: CHANNEL NAME INPUT
  // ==========================================================================
  Widget _buildChannelNameInput() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: FanSpacing.xl, vertical: 8),
      child: Container(
        decoration: FanDecorations.statChip,
        child: TextField(
          controller: _channelNameController,
          style: FanTypography.body,
          decoration: InputDecoration(
            hintText: 'Enter channel name...',
            hintStyle: FanTypography.body.copyWith(
              color: FanColors.textTertiary,
            ),
            prefixIcon: Icon(
              Icons.groups,
              color: FanColors.textTertiary,
              size: 18,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD: MEMBER SECTION
  // ==========================================================================
  Widget _buildMemberSection() {
    return Expanded(
      child: Column(
        children: [
          // Member count & filter
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: FanSpacing.xl, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Add Members (${_selectedMembers.length})',
                  style: FanTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: FanColors.textSecondary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showOnlyAvailable = !_showOnlyAvailable;
                      _filterUsers(_searchQuery);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _showOnlyAvailable
                          ? FanColors.primaryDim
                          : FanColors.surfaceSunken,
                      borderRadius: FanRadius.pillAll,
                      border: Border.all(
                        color: _showOnlyAvailable
                            ? FanColors.borderActive
                            : FanColors.border,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showOnlyAvailable
                              ? Icons.visibility
                              : Icons.visibility_off,
                          size: 14,
                          color: _showOnlyAvailable
                              ? FanColors.primary
                              : FanColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showOnlyAvailable ? 'Available' : 'All',
                          style: FanTypography.caption.copyWith(
                            color: _showOnlyAvailable
                                ? FanColors.primary
                                : FanColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: FanSpacing.xl, vertical: 4),
            child: Container(
              decoration: FanDecorations.statChip,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: FanTypography.body,
                onChanged: _filterUsers,
                decoration: InputDecoration(
                  hintText: 'Search by name, club, or country...',
                  hintStyle: FanTypography.body.copyWith(
                    color: FanColors.textTertiary,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: FanColors.textTertiary,
                    size: 18,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),

          // User list
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _filteredUsers.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) =>
                            _buildUserTile(_filteredUsers[index]),
                      ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BUILD: USER TILE (+ channel history chips)
  // ==========================================================================
  Widget _buildUserTile(UserProfile user) {
    final isSelected = _selectedMembers.any((m) => m.userId == user.userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: FanDecorations.card(
        isActive: isSelected,
        borderColor:
            isSelected ? FanColors.primary.withValues(alpha: 0.3) : null,
      ).copyWith(
        color: isSelected ? FanColors.primaryDim : FanColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: FanColors.primaryMuted,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        isSelected ? FanColors.primary : FanColors.borderActive,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    user.nickname[0].toUpperCase(),
                    style: FanTypography.title.copyWith(
                      fontSize: 18,
                      color: FanColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.nickname,
                      style: FanTypography.title,
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
                          user.clubFan,
                          style: FanTypography.caption,
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.flag,
                          size: 10,
                          color: FanColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.countryFan,
                          style: FanTypography.caption,
                        ),
                      ],
                    ),
                    Text(
                      '@${user.username}',
                      style: FanTypography.caption.copyWith(
                        color: FanColors.textTertiary,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),

              // Select button
              GestureDetector(
                onTap: () => _toggleMember(user),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? FanColors.primary
                        : FanColors.surfaceSunken,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? FanColors.primary : FanColors.border,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    isSelected ? Icons.check : Icons.add,
                    size: 16,
                    color: isSelected ? Colors.white : FanColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),

          // Existing channel history (admin/member of other channels,
          // including their synced stats)
          if (user.channelHistory.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildChannelHistoryRow(user.channelHistory),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // BUILD: CHANNEL HISTORY ROW
  // ==========================================================================
  Widget _buildChannelHistoryRow(List<ChannelMembership> history) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: history.map((membership) {
        final bool isAdmin = membership.role == 'admin';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isAdmin
                ? FanColors.primary.withValues(alpha: 0.1)
                : FanColors.surfaceSunken,
            borderRadius: FanRadius.pillAll,
            border: Border.all(
              color: isAdmin
                  ? FanColors.primary.withValues(alpha: 0.3)
                  : FanColors.border,
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isAdmin ? '👑' : '👥',
                style: const TextStyle(fontSize: 9),
              ),
              const SizedBox(width: 4),
              Text(
                membership.channelName,
                style: FanTypography.caption.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isAdmin ? FanColors.primary : FanColors.textSecondary,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                isAdmin ? '(admin)' : '(member)',
                style: FanTypography.caption.copyWith(
                  fontSize: 8,
                  color: FanColors.textTertiary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '⭐${membership.seasonPoints}',
                style: FanTypography.caption.copyWith(
                  fontSize: 8,
                  color: FanColors.textTertiary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ==========================================================================
  // BUILD: SELECTED MEMBERS CHIPS
  // ==========================================================================
  Widget _buildSelectedMembersChips() {
    if (_selectedMembers.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: FanSpacing.xl),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedMembers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final user = _selectedMembers[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: FanColors.primaryMuted,
              borderRadius: FanRadius.pillAll,
              border: Border.all(
                color: FanColors.borderActive,
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.nickname,
                  style: FanTypography.caption.copyWith(
                    color: FanColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _toggleMember(user),
                  child: Icon(
                    Icons.close,
                    size: 12,
                    color: FanColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================================================
  // BUILD: ACTION BUTTONS
  // ==========================================================================
  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildSelectedMembersChips(),
        Container(
          padding: const EdgeInsets.fromLTRB(
              FanSpacing.xl, 8, FanSpacing.xl, FanSpacing.xl),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: FanColors.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isCreating ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FanColors.textSecondary,
                    side: BorderSide(color: FanColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: FanRadius.lgAll,
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: FanTypography.button,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _createChannel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedMembers.isEmpty
                        ? FanColors.textTertiary
                        : FanColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: FanRadius.lgAll,
                    ),
                  ),
                  child: _isCreating
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: FanColors.textInverse,
                          ),
                        )
                      : Text(
                          _selectedMembers.isEmpty
                              ? 'Select Members'
                              : 'Create Channel (${_selectedMembers.length})',
                          style: FanTypography.button.copyWith(
                            color: _selectedMembers.isEmpty
                                ? FanColors.textInverse.withValues(alpha: 0.5)
                                : FanColors.textInverse,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // BUILD: LOADING STATE
  // ==========================================================================
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: FanColors.primary,
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 12),
          Text(
            'Loading users...',
            style: FanTypography.caption,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BUILD: EMPTY STATE
  // ==========================================================================
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: FanColors.surfaceSunken,
              shape: BoxShape.circle,
              border: Border.all(color: FanColors.border, width: 1),
            ),
            child: Icon(
              Icons.people_outline,
              size: 32,
              color: FanColors.textTertiary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty
                ? 'No matching users found'
                : 'No users available',
            style: FanTypography.title,
          ),
          const SizedBox(height: 4),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Check back later',
            style: FanTypography.caption,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CHANNEL MEMBERSHIP HISTORY
// ============================================================================
// Mirrors the full per-member sub-document shape stored in the "channels"
// collection's members[] array, so it can be shown to the admin while
// picking members (which channels they're already in, their role, and
// their current points) — purely informational, not sent back to the
// create-channel endpoint.
class ChannelMembership {
  final String channelId;
  final String channelName;
  final String role; // "admin" or "member"
  final String? joinedAt;
  final int seasonPoints;
  final int correctVotes;
  final int totalVotes;
  final int msgCount;
  final String? lastActiveAt;
  final int likesCount;

  ChannelMembership({
    required this.channelId,
    required this.channelName,
    required this.role,
    this.joinedAt,
    this.seasonPoints = 0,
    this.correctVotes = 0,
    this.totalVotes = 0,
    this.msgCount = 0,
    this.lastActiveAt,
    this.likesCount = 0,
  });

  factory ChannelMembership.fromJson(
    Map<String, dynamic> json, {
    required String channelId,
    required String channelName,
  }) {
    return ChannelMembership(
      channelId: channelId,
      channelName: channelName,
      role: json['role']?.toString() ?? 'member',
      joinedAt: json['joined_at']?.toString(),
      seasonPoints: (json['season_points'] as num?)?.toInt() ?? 0,
      correctVotes: (json['correct_votes'] as num?)?.toInt() ?? 0,
      totalVotes: (json['total_votes'] as num?)?.toInt() ?? 0,
      msgCount: (json['msg_count'] as num?)?.toInt() ?? 0,
      lastActiveAt: json['last_active_at']?.toString(),
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
    );
  }
}

// ============================================================================
// USER PROFILE MODEL
// ============================================================================
class UserProfile {
  final String id;
  final String userId;
  final String username;
  final String nickname;
  final String clubFan;
  final String countryFan;
  final String phone;
  final double balance;
  final int numberOfBets;

  // Populated separately after the initial profile fetch, by
  // cross-referencing every channel's members[] array for this user_id.
  List<ChannelMembership> channelHistory;

  UserProfile({
    required this.id,
    required this.userId,
    required this.username,
    required this.nickname,
    required this.clubFan,
    required this.countryFan,
    required this.phone,
    required this.balance,
    required this.numberOfBets,
    this.channelHistory = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      nickname: json['nickname']?.toString() ??
          json['username']?.toString() ??
          'User',
      clubFan: json['club_fan']?.toString() ?? 'Football Fan',
      countryFan: json['country_fan']?.toString() ?? 'World',
      phone: json['phone']?.toString() ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      numberOfBets: (json['number_of_bets'] as num?)?.toInt() ?? 0,
    );
  }
}
