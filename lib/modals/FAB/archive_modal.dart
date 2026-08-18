// archive_modal.dart
// Reusable Activity History Modal - Clean & Borderless Design

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../pages/fan_Funzy_design.dart';

// ============================================================================
// ACTIVITY TYPE ENUM
// ============================================================================
enum ActivityType {
  vote,
  comment,
  like;

  static ActivityType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'vote':
        return ActivityType.vote;
      case 'comment':
        return ActivityType.comment;
      case 'like':
        return ActivityType.like;
      default:
        return ActivityType.vote;
    }
  }
}

// ============================================================================
// ARCHIVE ACTIVITY MODEL
// ============================================================================
class ArchiveActivity {
  final String id;
  final String fixtureId;
  final String homeTeam;
  final String awayTeam;
  final ActivityType activityType;
  final String? selection;
  final String selectedTeam;
  final String? comment;
  final bool? isLiked;
  final DateTime timestamp;

  ArchiveActivity({
    required this.id,
    required this.fixtureId,
    required this.homeTeam,
    required this.awayTeam,
    required this.activityType,
    this.selection,
    required this.selectedTeam,
    this.comment,
    this.isLiked,
    required this.timestamp,
  });

  factory ArchiveActivity.fromJson(Map<String, dynamic> json) {
    DateTime timestamp;
    try {
      final timestampStr = json['timestamp'];
      if (timestampStr is String) {
        timestamp = DateTime.parse(timestampStr).toLocal();
      } else {
        timestamp = DateTime.now();
      }
    } catch (e) {
      timestamp = DateTime.now();
    }

    final activityType = ActivityType.fromString(
      json['activity_type']?.toString() ?? 'vote',
    );
    final selection = json['selection']?.toString();

    String selectedTeam = '';
    if (activityType == ActivityType.vote && selection != null) {
      switch (selection) {
        case 'home_team':
          selectedTeam = json['home_team']?.toString() ?? 'Home';
          break;
        case 'away_team':
          selectedTeam = json['away_team']?.toString() ?? 'Away';
          break;
        case 'draw':
          selectedTeam = 'Draw';
          break;
        default:
          selectedTeam = selection;
      }
    } else if (activityType == ActivityType.like) {
      selectedTeam = json['is_liked'] == true ? 'Liked' : 'Unliked';
    }

    return ArchiveActivity(
      id: json['_id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      fixtureId: json['fixture_id']?.toString() ?? '',
      homeTeam: json['home_team']?.toString() ?? 'Unknown',
      awayTeam: json['away_team']?.toString() ?? 'Unknown',
      activityType: activityType,
      selection: selection,
      selectedTeam: selectedTeam,
      comment: json['comment']?.toString(),
      isLiked: json['is_liked'] is bool ? json['is_liked'] as bool : null,
      timestamp: timestamp,
    );
  }

  String getFormattedDate() {
    return DateFormat('MMM d, yyyy • h:mm a').format(timestamp);
  }

  String getTimeAgo() {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(timestamp);
  }

  Color getActivityColor() {
    switch (activityType) {
      case ActivityType.vote:
        return FanColors.primary;
      case ActivityType.comment:
        return FanColors.reactionShare;
      case ActivityType.like:
        return FanColors.reactionLike;
    }
  }

  IconData getActivityIcon() {
    switch (activityType) {
      case ActivityType.vote:
        return Icons.how_to_vote;
      case ActivityType.comment:
        return Icons.comment;
      case ActivityType.like:
        return isLiked == true ? Icons.favorite : Icons.favorite_border;
    }
  }

  String getActivityTitle() {
    switch (activityType) {
      case ActivityType.vote:
        return 'Voted';
      case ActivityType.comment:
        return 'Commented';
      case ActivityType.like:
        return isLiked == true ? 'Liked' : 'Unliked';
    }
  }
}

// ============================================================================
// REUSABLE ARCHIVE MODAL - CLEAN & BORDERLESS
// ============================================================================
class ArchiveModal extends StatefulWidget {
  final String userId;
  final String userName;
  final String? authToken;
  final String? displayName;
  final String? profileImage;
  final String? clubFan;
  final String? countryFan;
  final bool isCurrentUser;

  const ArchiveModal({
    super.key,
    required this.userId,
    required this.userName,
    this.authToken,
    this.displayName,
    this.profileImage,
    this.clubFan,
    this.countryFan,
    this.isCurrentUser = false,
  });

  @override
  State<ArchiveModal> createState() => _ArchiveModalState();
}

class _ArchiveModalState extends State<ArchiveModal> {
  List<ArchiveActivity> _activities = [];
  bool _isLoading = true;
  bool _hasError = false;
  int _totalVotes = 0;
  int _totalComments = 0;
  int _totalLikes = 0;
  String _selectedFilter = 'All';

  static const String _baseUrl = 'https://clash-api-m5mr.onrender.com/api';

  @override
  void initState() {
    super.initState();
    _fetchUserActivities();
  }

  Future<void> _fetchUserActivities() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final headers = <String, String>{'Content-Type': 'application/json'};

      if (widget.authToken != null && widget.authToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${widget.authToken}';
      }

      final url = Uri.parse('$_baseUrl/archive/user/${widget.userId}');
      print('📡 Fetching activities for user: ${widget.userName}');
      print('🌐 URL: $url');

      final response = await http.get(url, headers: headers);

      print('📥 Status code: ${response.statusCode}');

      if (response.statusCode == 200 && mounted) {
        if (response.body.isEmpty) {
          setState(() {
            _activities = [];
            _isLoading = false;
          });
          return;
        }

        final List<dynamic> data = json.decode(response.body);
        final List<ArchiveActivity> activities = [];
        int voteCount = 0;
        int commentCount = 0;
        int likeCount = 0;

        for (var item in data) {
          final activity = ArchiveActivity.fromJson(item);
          activities.add(activity);

          switch (activity.activityType) {
            case ActivityType.vote:
              voteCount++;
              break;
            case ActivityType.comment:
              commentCount++;
              break;
            case ActivityType.like:
              likeCount++;
              break;
          }
        }

        activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        setState(() {
          _activities = activities;
          _totalVotes = voteCount;
          _totalComments = commentCount;
          _totalLikes = likeCount;
          _isLoading = false;
        });

        print('✅ Loaded ${activities.length} activities');
      } else if (response.statusCode == 404) {
        setState(() {
          _activities = [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error fetching activities: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  List<ArchiveActivity> _getFilteredActivities() {
    if (_selectedFilter == 'All') {
      return _activities;
    }

    ActivityType? filterType;
    switch (_selectedFilter) {
      case 'Votes':
        filterType = ActivityType.vote;
        break;
      case 'Comments':
        filterType = ActivityType.comment;
        break;
      case 'Likes':
        filterType = ActivityType.like;
        break;
    }

    return _activities.where((a) => a.activityType == filterType).toList();
  }

  Color _getVoteColor(String? selection) {
    switch (selection) {
      case 'home_team':
        return FanColors.primary;
      case 'away_team':
        return FanColors.reactionShare;
      case 'draw':
        return FanColors.draw;
      default:
        return FanColors.textTertiary;
    }
  }

  String _getVoteText(String? selection) {
    switch (selection) {
      case 'home_team':
        return 'Home Win';
      case 'away_team':
        return 'Away Win';
      case 'draw':
        return 'Draw';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: FanColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border.all(color: FanColors.border),
      ),
      child: Column(
        children: [
          // Drag handle - slim
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: FanColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header - clean
          _buildHeader(),

          // Slim Stats Row - no borders, just text
          if (!_isLoading && !_hasError && _activities.isNotEmpty)
            _buildSlimStatsRow(),

          // Slim Filter Tabs - minimal
          if (!_isLoading && !_hasError && _activities.isNotEmpty)
            _buildSlimFilterTabs(),

          // Content
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          // Avatar - clean circle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: FanColors.primaryDim,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (widget.displayName ?? widget.userName)[0].toUpperCase(),
                style: FanTypography.title.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: FanColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.displayName ?? widget.userName,
                        style: FanTypography.title.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: FanColors.primaryDim,
                          borderRadius: FanRadius.pillAll,
                        ),
                        child: Text(
                          'You',
                          style: FanTypography.tag.copyWith(
                            color: FanColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '@${widget.userName}',
                  style: FanTypography.caption.copyWith(
                    color: FanColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (widget.clubFan != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.sports_soccer,
                        size: 10,
                        color: FanColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.clubFan!,
                        style: FanTypography.tag.copyWith(
                          color: FanColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Close button - minimal
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: FanColors.surfaceSunken,
                shape: BoxShape.circle,
                border: Border.all(color: FanColors.border),
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
    );
  }

  // SLIM STATS ROW - borderless, just text and icons
  Widget _buildSlimStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSlimStatChip(
            icon: Icons.how_to_vote,
            count: _totalVotes,
            label: 'votes',
            color: FanColors.primary,
          ),
          _buildSlimStatChip(
            icon: Icons.comment,
            count: _totalComments,
            label: 'comments',
            color: FanColors.reactionShare,
          ),
          _buildSlimStatChip(
            icon: Icons.favorite,
            count: _totalLikes,
            label: 'likes',
            color: FanColors.reactionLike,
          ),
        ],
      ),
    );
  }

  Widget _buildSlimStatChip({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(
          count.toString(),
          style: FanTypography.statValue.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: FanTypography.caption.copyWith(
            color: FanColors.textTertiary,
          ),
        ),
      ],
    );
  }

  // SLIM FILTER TABS - minimal, no borders
  Widget _buildSlimFilterTabs() {
    final filters = ['All', 'Votes', 'Comments', 'Likes'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                filter,
                style: FanTypography.caption.copyWith(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color:
                      isSelected ? FanColors.primary : FanColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading activity...',
              style: FanTypography.caption.copyWith(
                color: FanColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: FanColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to load activities',
              style: FanTypography.body.copyWith(
                color: FanColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _fetchUserActivities,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: FanDecorations.ghostButton,
                child: Text(
                  'Try Again',
                  style: FanTypography.button.copyWith(
                    color: FanColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final filteredActivities = _getFilteredActivities();

    if (filteredActivities.isEmpty) {
      String message = 'No activities yet';
      if (_selectedFilter != 'All') {
        message = 'No $_selectedFilter yet';
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: FanColors.textTertiary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: FanTypography.body.copyWith(
                color: FanColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isCurrentUser
                  ? 'Vote, comment, and like fixtures'
                  : 'No interactions yet',
              style: FanTypography.caption.copyWith(
                color: FanColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredActivities.length,
      itemBuilder: (context, index) =>
          _buildSlimActivityCard(filteredActivities[index]),
    );
  }

  // SLIM ACTIVITY CARD - borderless, minimal
  Widget _buildSlimActivityCard(ArchiveActivity activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main content area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with icon and type
                Row(
                  children: [
                    Icon(
                      activity.getActivityIcon(),
                      size: 14,
                      color: activity.getActivityColor(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      activity.getActivityTitle(),
                      style: FanTypography.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: activity.getActivityColor(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: FanTypography.caption.copyWith(
                        fontSize: 10,
                        color: FanColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      activity.getTimeAgo(),
                      style: FanTypography.caption.copyWith(
                        fontSize: 10,
                        color: FanColors.textTertiary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Teams (slim, no VS badge)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          activity.homeTeam,
                          style: FanTypography.title.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'vs',
                          style: FanTypography.tag.copyWith(
                            color: FanColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          activity.awayTeam,
                          style: FanTypography.title.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.left,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Activity specific content - clean and minimal
                _buildSlimActivityContent(activity),

                const SizedBox(height: 6),

                // Timestamp
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      activity.getFormattedDate(),
                      style: FanTypography.tag.copyWith(
                        color: FanColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Subtle divider
          Divider(
            color: FanColors.border.withValues(alpha: 0.15),
            height: 1,
            thickness: 0.5,
          ),
        ],
      ),
    );
  }

  Widget _buildSlimActivityContent(ArchiveActivity activity) {
    switch (activity.activityType) {
      case ActivityType.vote:
        return Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: _getVoteColor(activity.selection),
                borderRadius: FanRadius.pillAll,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.how_to_vote,
              size: 12,
              color: _getVoteColor(activity.selection).withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              _getVoteText(activity.selection),
              style: FanTypography.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _getVoteColor(activity.selection),
              ),
            ),
          ],
        );

      case ActivityType.comment:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: FanColors.reactionShare,
                borderRadius: FanRadius.pillAll,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.format_quote,
              size: 12,
              color: FanColors.reactionShare.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                activity.comment ?? 'No comment',
                style: FanTypography.body.copyWith(
                  fontSize: 12,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );

      case ActivityType.like:
        return Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: FanColors.reactionLike,
                borderRadius: FanRadius.pillAll,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.favorite,
              size: 12,
              color: FanColors.reactionLike.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              activity.isLiked == true ? 'Showed support' : 'Removed support',
              style: FanTypography.caption.copyWith(
                fontSize: 12,
                color: FanColors.textSecondary,
              ),
            ),
          ],
        );
    }
  }
}

// ============================================================================
// HELPER METHOD TO SHOW ARCHIVE MODAL
// ============================================================================
void showArchiveModal({
  required BuildContext context,
  required String userId,
  required String userName,
  String? authToken,
  String? displayName,
  String? profileImage,
  String? clubFan,
  String? countryFan,
  bool isCurrentUser = false,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ArchiveModal(
      userId: userId,
      userName: userName,
      authToken: authToken,
      displayName: displayName,
      profileImage: profileImage,
      clubFan: clubFan,
      countryFan: countryFan,
      isCurrentUser: isCurrentUser,
    ),
  );
}
