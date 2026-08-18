// ============================================================================
// ADMIN DASHBOARD MODAL - With Admin Removal
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import '../../pages/fan_Funzy_design.dart';
import "../../screens/home_page.dart";
import '../../main.dart';
import "../../models/user_channel.dart";
import '../../services/payment_service.dart';

// ============================================================================
// ADMIN PAYOUT MODEL
// ============================================================================

class AdminPayoutData {
  final double amount;
  final String payoutType; // "signup_bonus" or "engagement_rate"
  final String status; // "pending", "paid", etc.
  final DateTime computedAt;

  AdminPayoutData({
    required this.amount,
    required this.payoutType,
    required this.status,
    required this.computedAt,
  });

  factory AdminPayoutData.fromJson(Map<String, dynamic> json) {
    return AdminPayoutData(
      amount: (json['amount'] ?? 0.0).toDouble(),
      payoutType: json['payout_type']?.toString() ?? 'engagement_rate',
      status: json['status']?.toString() ?? 'pending',
      computedAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  bool get isBonus => payoutType == 'signup_bonus';
}

class AdminDashboardCache {
  static final AdminDashboardCache _instance = AdminDashboardCache._internal();
  factory AdminDashboardCache() => _instance;
  AdminDashboardCache._internal();

  static const String _channelStatsCacheKey = 'admin_channel_stats_cache';
  static const String _membersCacheKey = 'admin_members_cache';
  static const String _timestampKey = 'admin_cache_timestamp';
  static const Duration _cacheDuration = Duration(minutes: 5);

  Future<void> cacheChannelStats(
      String channelId, Map<String, dynamic> stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = await _getCacheMap();
      cache[channelId] = {
        'stats': stats,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_channelStatsCacheKey, json.encode(cache));
    } catch (e) {
      debugPrint('Error caching channel stats: $e');
    }
  }

  Future<Map<String, dynamic>?> getCachedChannelStats(String channelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheStr = prefs.getString(_channelStatsCacheKey);
      if (cacheStr == null) return null;

      final cache = json.decode(cacheStr) as Map<String, dynamic>;
      final channelCache = cache[channelId];
      if (channelCache == null) return null;

      final timestamp = channelCache['timestamp'] as int;
      if (DateTime.now().millisecondsSinceEpoch - timestamp >
          _cacheDuration.inMilliseconds) {
        return null;
      }

      return channelCache['stats'] as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<void> cacheMembers(String channelId, List<dynamic> members) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = await _getMembersCacheMap();
      cache[channelId] = {
        'data': members,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_membersCacheKey, json.encode(cache));
    } catch (e) {
      debugPrint('Error caching members: $e');
    }
  }

  Future<List<dynamic>?> getCachedMembers(String channelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheStr = prefs.getString(_membersCacheKey);
      if (cacheStr == null) return null;

      final cache = json.decode(cacheStr) as Map<String, dynamic>;
      final channelCache = cache[channelId];
      if (channelCache == null) return null;

      final timestamp = channelCache['timestamp'] as int;
      if (DateTime.now().millisecondsSinceEpoch - timestamp >
          _cacheDuration.inMilliseconds) {
        return null;
      }

      return channelCache['data'] as List<dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _getCacheMap() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheStr = prefs.getString(_channelStatsCacheKey);
    if (cacheStr == null) return {};
    return json.decode(cacheStr) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _getMembersCacheMap() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheStr = prefs.getString(_membersCacheKey);
    if (cacheStr == null) return {};
    return json.decode(cacheStr) as Map<String, dynamic>;
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_channelStatsCacheKey);
    await prefs.remove(_membersCacheKey);
    await prefs.remove(_timestampKey);
  }
}

// ============================================================================
// CHANNEL MEMBER MODEL - Matching Rust struct
// ============================================================================

class ChannelMemberData {
  final String userId;
  final String username;
  final String role; // "admin" or "member"
  final DateTime joinedAt;
  final int seasonPoints;
  final int correctVotes;
  final int totalVotes;
  final int msgCount;

  ChannelMemberData({
    required this.userId,
    required this.username,
    required this.role,
    required this.joinedAt,
    required this.seasonPoints,
    required this.correctVotes,
    required this.totalVotes,
    required this.msgCount,
  });

  factory ChannelMemberData.fromJson(Map<String, dynamic> json) {
    return ChannelMemberData(
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? 'Anonymous',
      role: json['role']?.toString()?.toLowerCase() ?? 'member',
      joinedAt: DateTime.tryParse(json['joined_at']?.toString() ?? '') ??
          DateTime.now(),
      seasonPoints: json['season_points'] ?? 0,
      correctVotes: json['correct_votes'] ?? 0,
      totalVotes: json['total_votes'] ?? 0,
      msgCount: json['msg_count'] ?? 0,
    );
  }

  bool get isAdmin => role == 'admin';
}

// ============================================================================
// CHANNEL STATS MODEL
// ============================================================================

class ChannelStats {
  final int totalMessages;
  final int messagesThisWeek;
  final int totalLikes;
  final int totalVotes;
  final int memberCount;
  final double balance;

  ChannelStats({
    required this.totalMessages,
    required this.messagesThisWeek,
    required this.totalLikes,
    required this.totalVotes,
    required this.memberCount,
    required this.balance,
  });

  factory ChannelStats.fromJson(Map<String, dynamic> json) {
    return ChannelStats(
      totalMessages: json['total_messages'] ?? 0,
      messagesThisWeek: json['messages_this_week'] ?? 0,
      totalLikes: json['total_likes'] ?? 0,
      totalVotes: json['total_votes'] ?? 0,
      memberCount: json['member_count'] ?? 0,
      balance: (json['balance'] ?? 0.0).toDouble(),
    );
  }
}

// ============================================================================
// ADMIN DASHBOARD MODAL
// ============================================================================

class AdminDashboardModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final String userId;
  final String username;
  final String? authToken;
  final List<UserChannel> userChannels;
  final int pendingJoinCount;

  const AdminDashboardModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.userId,
    required this.username,
    this.authToken,
    required this.userChannels,
    this.pendingJoinCount = 0,
  });

  @override
  State<AdminDashboardModal> createState() => _AdminDashboardModalState();
}

class _AdminDashboardModalState extends State<AdminDashboardModal> {
  final PageController _channelPageController = PageController();
  int _currentChannelIndex = 0;

  bool _isLoading = true;
  bool _isLoadingMembers = true;
  bool _isLoadingPayment = false;
  bool _isWithdrawing = false;
  bool _isRemovingMember = false;
  String? _error;
  bool _showPaymentFeatures = true;

  // Real data
  ChannelStats? _channelStats;
  List<ChannelMemberData> _members = [];
  List<ChannelMemberData> _filteredMembers = [];
  String _searchQuery = '';

  String _adminPhoneNumber = '';

  // User balance from users collection
  double _userBalance = 0.0;
  bool _isLoadingBalance = false;

  final AdminDashboardCache _cache = AdminDashboardCache();

  static const String _api = 'https://clash-api-m5mr.onrender.com/api';
  static const Duration _timeout = Duration(seconds: 15);
  AdminPayoutData? _adminPayout;
  bool _isLoadingPayout = false;

  // FILTER: Only show channels where user is admin
  List<UserChannel> get _adminChannels {
    return widget.userChannels.where((channel) {
      return channel.isAdmin == true;
    }).toList();
  }

  UserChannel? get _currentChannel {
    if (_adminChannels.isEmpty) return null;
    if (_currentChannelIndex >= _adminChannels.length) {
      _currentChannelIndex = 0;
    }
    return _adminChannels[_currentChannelIndex];
  }

 @override
  void initState() {
    super.initState();
    _loadData();
    _fetchAdminPhoneNumber();
    _fetchUserBalance();
    _fetchAdminPayout();
    _checkPaymentVisibility(); // ✅ added
  }

  Future<void> _checkPaymentVisibility() async {
    try {
      final response = await http
          .get(Uri.parse('$_api/visibility/votes_button_show'),
              headers: _headers())
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() => _showPaymentFeatures = data['value'] ?? true);
      }
    } catch (e) {
      debugPrint('❌ Error checking visibility: $e');
    }
  }

  @override
  void dispose() {
    _channelPageController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // LOAD DATA WITH CACHING
  // ==========================================================================

  Future<void> _loadData() async {
    final channel = _currentChannel;
    if (channel == null) {
      setState(() {
        _isLoading = false;
        _error = 'No admin channels found';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    await Future.wait([
      _loadChannelStats(),
      _loadMembers(),
    ]);

    setState(() => _isLoading = false);
  }

  Future<void> _loadChannelStats() async {
    final channel = _currentChannel;
    if (channel == null) return;

    final channelId = channel.channelId;

    // Check AppCache first (RAM - 0ms)
    final cachedStats = AppCache.getCachedChannelStats(channelId);
    if (cachedStats != null && mounted) {
      debugPrint('⚡ INSTANT: Channel stats from AppCache (RAM)');
      setState(() {
        _channelStats = ChannelStats(
          totalMessages: cachedStats['total_messages'] ?? 0,
          messagesThisWeek: cachedStats['messages_this_week'] ?? 0,
          totalLikes: cachedStats['total_likes'] ?? 0,
          totalVotes: cachedStats['total_votes'] ?? 0,
          memberCount: cachedStats['member_count'] ?? 0,
          balance: cachedStats['balance'] ?? 0.0,
        );
      });
    }

    // Fetch fresh from API
    try {
      final response = await http
          .get(
            Uri.parse('$_api/channels/$channelId'),
            headers: _headers(),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final channel = data['channel'];

        final stats = ChannelStats(
          totalMessages: channel['activity']['total_messages'] ?? 0,
          messagesThisWeek: channel['activity']['messages_this_week'] ?? 0,
          totalLikes: 0,
          totalVotes: 0,
          memberCount: channel['member_count'] ?? 0,
          balance: 0.0,
        );

        setState(() => _channelStats = stats);

        // Save to AppCache
        AppCache.cacheChannelStats(channelId, {
          'total_messages': stats.totalMessages,
          'messages_this_week': stats.messagesThisWeek,
          'total_likes': stats.totalLikes,
          'total_votes': stats.totalVotes,
          'member_count': stats.memberCount,
          'balance': stats.balance,
        });
      }
    } catch (e) {
      debugPrint('Error loading channel stats: $e');
    }
  }

  Future<void> _loadMembers() async {
    final channel = _currentChannel;
    if (channel == null) return;

    final channelId = channel.channelId;

    setState(() => _isLoadingMembers = true);

    // Check AppCache first (RAM - 0ms)
    final cachedMembers = AppCache.getCachedChannelMembers(channelId);
    if (cachedMembers != null && mounted) {
      debugPrint(
          '⚡ INSTANT: ${cachedMembers.length} members from AppCache (RAM)');
      final members =
          cachedMembers.map((m) => ChannelMemberData.fromJson(m)).toList();
      setState(() {
        _members = members;
        _filteredMembers = members;
        _isLoadingMembers = false;
      });
    }

    // Fetch fresh from API
    try {
      final response = await http
          .get(
            Uri.parse('$_api/channels/$channelId'),
            headers: _headers(),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final channel = data['channel'];
        final List<dynamic> membersData = channel['members'] ?? [];

        final members =
            membersData.map((m) => ChannelMemberData.fromJson(m)).toList();

        setState(() {
          _members = members;
          _filteredMembers = members;
          _isLoadingMembers = false;
        });

        // Save to AppCache
        AppCache.cacheChannelMembers(
            channelId, membersData.cast<Map<String, dynamic>>());
      } else {
        setState(() => _isLoadingMembers = false);
      }
    } catch (e) {
      debugPrint('Error loading members: $e');
      setState(() => _isLoadingMembers = false);
    }
  }

  // ==========================================================================
  // ADMIN REMOVAL - NEW METHOD
  // ==========================================================================

  void _showRemoveMemberConfirmation(ChannelMemberData member) {
    // Can't remove yourself
    if (member.userId == widget.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text('You cannot remove yourself from the admin dashboard'),
          backgroundColor: FanColors.away,
        ),
      );
      return;
    }

    // Can't remove other admins
    if (member.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text('Cannot remove another admin from the channel'),
          backgroundColor: FanColors.away,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: FanColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: FanRadius.lgAll,
          side: BorderSide(color: FanColors.border),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Icon
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: FanColors.away.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: FanColors.away,
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Remove Member',
                style: FanTypography.headline.copyWith(
                  fontSize: 18,
                  color: FanColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Remove ${member.username} from the channel?',
                style: TextStyle(
                  fontSize: 14,
                  color: FanColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FanColors.away.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: FanColors.away.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: FanColors.away,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️ This member will lose 30 points for leaving the channel. This helps prevent channel hopping.',
                      style: TextStyle(
                        fontSize: 10,
                        color: FanColors.textTertiary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap:
                        _isRemovingMember ? null : () => Navigator.pop(context),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        border: Border.all(color: FanColors.border),
                        borderRadius: FanRadius.pillAll,
                      ),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: FanColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap:
                        _isRemovingMember ? null : () => _removeMember(member),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            FanColors.away,
                            FanColors.away.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: FanRadius.pillAll,
                      ),
                      child: _isRemovingMember
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                'Remove',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeMember(ChannelMemberData member) async {
    final channel = _currentChannel;
    if (channel == null) return;

    setState(() => _isRemovingMember = true);

    try {
      final response = await http.post(
        Uri.parse('$_api/channels/members/remove'),
        headers: {
          'Content-Type': 'application/json',
          if (widget.authToken != null && widget.authToken!.isNotEmpty)
            'Authorization': 'Bearer ${widget.authToken}',
        },
        body: json.encode({
          'channel_id': channel.channelId,
          'user_id': member.userId,
          'removed_by': widget.userId, // Admin removing the member
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // ✅ UPDATE CACHE IMMEDIATELY
        _updateCacheAfterRemoval(channel.channelId, member.userId);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ ${member.username} removed from channel (30 points deducted)',
            ),
            backgroundColor: FanColors.primary,
            duration: const Duration(seconds: 3),
          ),
        );

        // Close dialog and refresh
        Navigator.pop(context);
        setState(() => _isRemovingMember = false);

        // Reload members
        await _loadMembers();
        await _loadChannelStats();
      } else {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to remove member'),
            backgroundColor: FanColors.away,
          ),
        );
        setState(() => _isRemovingMember = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: FanColors.away,
          ),
        );
        setState(() => _isRemovingMember = false);
      }
    }
  }

  // ==========================================================================
  // CACHE UPDATE AFTER REMOVAL - NEW METHOD
  // ==========================================================================

  void _updateCacheAfterRemoval(String channelId, String removedUserId) {
    try {
      // 1. Remove member from AppCache members list
      final cachedMembers = AppCache.getCachedChannelMembers(channelId);
      if (cachedMembers != null) {
        final updatedMembers = cachedMembers.where((m) {
          return m['user_id']?.toString() != removedUserId;
        }).toList();
        AppCache.cacheChannelMembers(channelId, updatedMembers);
      }

      // 2. Remove from _members list
      setState(() {
        _members.removeWhere((m) => m.userId == removedUserId);
        _filteredMembers.removeWhere((m) => m.userId == removedUserId);
      });

      // 3. Update channel stats - decrement member count
      if (_channelStats != null) {
        final updatedStats = ChannelStats(
          totalMessages: _channelStats!.totalMessages,
          messagesThisWeek: _channelStats!.messagesThisWeek,
          totalLikes: _channelStats!.totalLikes,
          totalVotes: _channelStats!.totalVotes,
          memberCount: _channelStats!.memberCount - 1,
          balance: _channelStats!.balance,
        );
        setState(() {
          _channelStats = updatedStats;
        });
        AppCache.cacheChannelStats(channelId, {
          'total_messages': updatedStats.totalMessages,
          'messages_this_week': updatedStats.messagesThisWeek,
          'total_likes': updatedStats.totalLikes,
          'total_votes': updatedStats.totalVotes,
          'member_count': updatedStats.memberCount,
          'balance': updatedStats.balance,
        });
      }

      // 4. Update user's channels list if they are in it
      AppCache.channels.removeWhere((c) =>
          c.channelId == channelId &&
          AppCache.channels.any((uc) => uc.memberIds == removedUserId));

      // 5. Save to disk
      AppCache.saveChannels(AppCache.channels);

      debugPrint(
          '🗑️ Cache updated after removing member: $removedUserId from $channelId');
    } catch (e) {
      debugPrint('⚠️ Error updating cache after removal: $e');
    }
  }

  // ==========================================================================
  // FETCH ADMIN PAYOUT - Using PaymentService
  // ==========================================================================

  Future<void> _fetchAdminPayout() async {
    final channel = _currentChannel;
    if (channel == null) return;

    setState(() => _isLoadingPayout = true);

    try {
      final result = await PaymentService.computeAdminPayout(
        channelId: channel.channelId,
        userId: widget.userId,
        authToken: widget.authToken,
      );

      if (result.isSuccess && mounted) {
        setState(() {
          _adminPayout = AdminPayoutData(
            amount: result.amount ?? 0.0,
            payoutType: result.payoutType ?? 'engagement_rate',
            status: result.status ?? 'pending',
            computedAt: result.computedAt ?? DateTime.now(),
          );
        });
        debugPrint('✅ Admin payout computed: ${result.amount}');
      }
    } catch (e) {
      debugPrint('❌ Error computing admin payout: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPayout = false);
    }
  }

  // ==========================================================================
  // FETCH USER BALANCE - Using PaymentService
  // ==========================================================================

  Future<void> _fetchUserBalance() async {
    final bool isLoggedIn =
        widget.authToken != null && widget.authToken!.isNotEmpty;

    if (!isLoggedIn || widget.authToken == null) {
      setState(() => _isLoadingBalance = false);
      return;
    }

    setState(() => _isLoadingBalance = true);
    try {
      final balance = await PaymentService.getUserBalance(
        userId: widget.userId,
        authToken: widget.authToken,
        forceRefresh: true,
      );

      if (mounted) {
        setState(() {
          _userBalance = balance;
        });
        debugPrint('✅ User balance fetched: $_userBalance');
      }
    } catch (e) {
      debugPrint('❌ Error fetching user balance: $e');
    } finally {
      if (mounted) setState(() => _isLoadingBalance = false);
    }
  }

  // ==========================================================================
  // FETCH ADMIN PHONE NUMBER
  // ==========================================================================

  Future<void> _fetchAdminPhoneNumber() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_api/profile/profile/${widget.userId}'),
            headers: _headers(),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          _adminPhoneNumber = data['phone']?.toString() ?? '';
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch phone number: $e');
    }
  }

  // ==========================================================================
  // LOAD BUTTON - STK PUSH using PaymentService
  // ==========================================================================

  void _showLoadPaymentDialog() {
    if (_adminPhoneNumber.isEmpty) {
      _showMissingPhoneDialog();
      return;
    }

    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          bool isProcessing = false;
          String statusMessage = '';

          return AlertDialog(
            backgroundColor: FanColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FanRadius.lg),
              side: BorderSide(color: FanColors.border),
            ),
            title: Row(
              children: [
                Icon(Icons.payments, color: FanColors.secondary, size: 24),
                SizedBox(width: 8),
                Text('Load Funds to Channel'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: FanColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: FanColors.border.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.phone_android,
                          size: 16, color: FanColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        _formatPhoneNumber(_adminPhoneNumber),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: FanColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.check_circle,
                          size: 14, color: FanColors.secondary),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AbsorbPointer(
                  absorbing: isProcessing,
                  child: Opacity(
                    opacity: isProcessing ? 0.5 : 1.0,
                    child: Column(
                      children: [
                        TextField(
                          controller: amountController,
                          decoration: const InputDecoration(
                            labelText: 'Amount (KES)',
                            hintText: 'Enter amount to load',
                            prefixIcon: Icon(Icons.monetization_on),
                          ),
                          keyboardType: TextInputType.number,
                          autofocus: true,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: FanColors.primary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 14, color: FanColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You will receive an M-Pesa prompt to enter your PIN',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: FanColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (statusMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusMessage.contains('✅')
                          ? FanColors.secondary.withOpacity(0.1)
                          : FanColors.away.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusMessage.contains('✅')
                            ? FanColors.secondary.withOpacity(0.2)
                            : FanColors.away.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (statusMessage.contains('✅'))
                          Icon(Icons.check_circle,
                              size: 18, color: FanColors.secondary)
                        else if (statusMessage.contains('❌'))
                          Icon(Icons.error_outline,
                              size: 18, color: FanColors.away)
                        else
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: FanColors.primary,
                            ),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            statusMessage,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: statusMessage.contains('✅')
                                  ? FanColors.secondary
                                  : statusMessage.contains('❌')
                                      ? FanColors.away
                                      : FanColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed:
                    isProcessing ? null : () => Navigator.pop(context, false),
                child: Text(
                  isProcessing ? 'Processing...' : 'Cancel',
                  style: TextStyle(
                    color: isProcessing
                        ? FanColors.textTertiary
                        : FanColors.textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: isProcessing
                    ? null
                    : () async {
                        final amount = amountController.text.trim();
                        if (amount.isEmpty ||
                            double.tryParse(amount) == null ||
                            double.parse(amount) <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid amount'),
                            ),
                          );
                          return;
                        }

                        setStateDialog(() {
                          isProcessing = true;
                          statusMessage =
                              '⏳ Processing... Please check your phone';
                        });

                        final result = await _initiateSTKPushWithResult(
                          _adminPhoneNumber,
                          amount,
                        );

                        if (result) {
                          setStateDialog(() {
                            statusMessage = '✅ Payment successful!';
                          });

                          await Future.delayed(const Duration(seconds: 1));
                          Navigator.pop(context, true);
                        } else {
                          setStateDialog(() {
                            statusMessage =
                                '❌ Payment failed. Please try again.';
                            isProcessing = false;
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FanColors.primary,
                ),
                child: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Pay via M-Pesa'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _initiateSTKPushWithResult(
      String phoneNumber, String amount) async {
    final channel = _currentChannel;
    if (channel == null) return false;

    try {
      final result = await PaymentService.initiateSTKPush(
        userId: widget.userId,
        username: widget.username,
        amount: double.parse(amount),
        phoneNumber: phoneNumber,
        authToken: widget.authToken,
        purpose: 'Load funds to ${channel.name}',
        channelId: channel.channelId,
      );

      if (result.isSuccess) {
        await _loadChannelStats();
        await _fetchUserBalance();
        return true;
      } else {
        if (result.error?.contains('still processing') == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Payment is still processing. Please check your M-Pesa messages and refresh manually.'),
              backgroundColor: FanColors.away,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Payment failed'),
              backgroundColor: FanColors.away,
            ),
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint('❌ STK Push error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: FanColors.away,
        ),
      );
      return false;
    }
  }

  void _showMissingPhoneDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FanColors.surfaceElevated,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FanRadius.lg)),
        title: const Text('Phone Number Missing'),
        content: const Text(
          'Please add your phone number to your profile first.\n\n'
          'Go to Profile → Edit Profile → Add Phone Number',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: FanColors.primary)),
          ),
        ],
      ),
    );
  }

  String _formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.startsWith('254') && cleaned.length == 12) {
      return '+${cleaned.substring(0, 3)} ${cleaned.substring(3, 6)} ${cleaned.substring(6)}';
    } else if (cleaned.startsWith('0') && cleaned.length == 10) {
      return '+254 ${cleaned.substring(1, 4)} ${cleaned.substring(4)}';
    }
    return '+$cleaned';
  }

  void _shareChannel() {
    final channel = _currentChannel;
    if (channel == null) return;

    final inviteCode = channel.inviteCode ?? '';

    if (inviteCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No invite code available for this channel')),
      );
      return;
    }

    final String shareLink =
        'https://Funzy-channel-join.netlify.app/join/$inviteCode';
    final String message = '🎉 Join "${channel.name}" on Funzy!\n\n'
        'Vote on matches, compete with friends, and win!\n\n'
        '🔗 $shareLink\n\n'
        'Download the app to join!';

    Share.share(
      message,
      subject: 'Join ${channel.name} on Funzy',
    );
  }

  // ==========================================================================
  // STK PUSH - Using PaymentService
  // ==========================================================================

  Future<void> _initiateSTKPush(String phoneNumber, String amount) async {
    final channel = _currentChannel;
    if (channel == null) return;

    setState(() => _isLoadingPayment = true);
    _showPaymentProcessingDialog();

    try {
      final result = await PaymentService.initiateSTKPush(
        userId: widget.userId,
        username: widget.username,
        amount: double.parse(amount),
        phoneNumber: phoneNumber,
        authToken: widget.authToken,
        purpose: 'Load funds to ${channel.name}',
        channelId: channel.channelId,
      );

      Navigator.pop(context);

      if (result.isSuccess) {
        await _loadChannelStats();
        await _fetchUserBalance();

        _showPaymentDialog(
          'Payment Successful!',
          'KES ${double.parse(amount).toStringAsFixed(2)} loaded successfully.\n'
              'New Balance: KES ${result.newBalance?.toStringAsFixed(2) ?? _userBalance.toStringAsFixed(2)}',
          false,
        );
      } else {
        if (result.error?.contains('still processing') == true) {
          _showPaymentDialog(
            'Payment Processing',
            '${result.error}\n\n'
                'Please check your M-Pesa messages and refresh your balance manually.',
            true,
          );
        } else {
          _showPaymentDialog(
            'Payment Failed',
            result.error ?? 'Unknown error',
            true,
          );
        }
      }
    } catch (e) {
      Navigator.pop(context);
      _showPaymentDialog(
        'Payment Failed',
        'Error: ${e.toString()}',
        true,
      );
    } finally {
      if (mounted) setState(() => _isLoadingPayment = false);
    }
  }

  void _showPaymentProcessingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: FanColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FanRadius.lg),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(
              'Processing Payment...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: FanColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your M-Pesa and enter your PIN.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: FanColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This may take up to 60 seconds.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: FanColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // WITHDRAW BUTTON - B2C using PaymentService
  // ==========================================================================

  Future<void> _withdrawCash() async {
    final channel = _currentChannel;
    if (channel == null) return;

    if (_adminPhoneNumber.isEmpty) {
      _showMissingPhoneDialog();
      return;
    }

    final TextEditingController amountController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FanColors.surfaceElevated,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FanRadius.lg)),
        title: const Text('Withdraw Funds'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: FanColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FanColors.border.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone_android, size: 16, color: FanColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    _formatPhoneNumber(_adminPhoneNumber),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: FanColors.textPrimary),
                  ),
                  const Spacer(),
                  Text('Auto-detected',
                      style: TextStyle(fontSize: 10, color: FanColors.primary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (KES)',
                hintText: 'Enter amount to withdraw',
                prefixIcon: Icon(Icons.monetization_on),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: FanColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: FanColors.primary),
            child: const Text('Confirm Withdrawal'),
          ),
        ],
      ),
    );

    if (result == true) {
      final amount = amountController.text.trim();
      setState(() => _isWithdrawing = true);
      await _initiateB2CPayment(_adminPhoneNumber, amount);
      setState(() => _isWithdrawing = false);
    }
  }

  // ==========================================================================
  // B2C PAYMENT - Using PaymentService
  // ==========================================================================

  Future<void> _initiateB2CPayment(String phoneNumber, String amount) async {
    final channel = _currentChannel;
    if (channel == null) return;

    setState(() => _isLoadingPayment = true);

    try {
      final result = await PaymentService.initiateB2CPayment(
        userId: widget.userId,
        username: widget.username,
        channelId: channel.channelId,
        amount: double.parse(amount),
        phoneNumber: phoneNumber,
        authToken: widget.authToken,
        remarks: 'Withdrawal from ${channel.name}',
        occasion: 'Channel Payout',
      );

      if (result.isSuccess) {
        if (result.newBalance != null) {
          setState(() => _userBalance = result.newBalance!);
        }

        await _fetchUserBalance();
        await _loadChannelStats();

        _showPaymentDialog(
          'Withdrawal Initiated',
          'KES $amount sent to ${_formatPhoneNumber(phoneNumber)}\n\n'
              'New Balance: KES ${_userBalance.toStringAsFixed(2)}',
          false,
        );
      } else {
        _showPaymentDialog(
          'Withdrawal Failed',
          result.error ?? 'B2C payment failed',
          true,
        );
      }
    } catch (e) {
      _showPaymentDialog('Withdrawal Failed', 'Error: ${e.toString()}', true);
    } finally {
      if (mounted) setState(() => _isLoadingPayment = false);
    }
  }

  void _showPaymentDialog(String title, String message, bool isError) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FanColors.surfaceElevated,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FanRadius.lg)),
        title: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle,
                color: isError ? FanColors.away : FanColors.secondary,
                size: 28),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('Close', style: TextStyle(color: FanColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // REFRESH
  // ==========================================================================

  Future<void> _refreshData() async {
    await _cache.clearCache();
    await _loadData();
    await _fetchUserBalance();
    await _fetchAdminPayout();
  }

  // ==========================================================================
  // HELPER METHODS
  // ==========================================================================

  Map<String, String> _headers() {
    final h = {'Content-Type': 'application/json'};
    if (widget.authToken != null && widget.authToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer ${widget.authToken}';
    }
    return h;
  }

  void _applySearch(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredMembers = List.from(_members);
      } else {
        _filteredMembers = _members.where((m) {
          return m.username.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Widget _buildPayoutBanner() {
    if (_isLoadingPayout) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text('Checking payout...',
                style: TextStyle(fontSize: 12, color: FanColors.textSecondary)),
          ],
        ),
      );
    }

    final payout = _adminPayout;
    if (payout == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: GestureDetector(
          onTap: _fetchAdminPayout,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: FanColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FanColors.border.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.refresh, size: 16, color: FanColors.textSecondary),
                const SizedBox(width: 8),
                Text('Pull down or tap to check your payout',
                    style: TextStyle(
                        fontSize: 12, color: FanColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: FanColors.secondary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FanColors.secondary.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(
              payout.isBonus ? Icons.celebration : Icons.payments,
              size: 22,
              color: FanColors.secondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payout.isBonus
                        ? '🎉 Welcome bonus earned!'
                        : 'Engagement payout',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: FanColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    payout.status == 'pending'
                        ? 'Pending — based on votes & messages'
                        : 'Status: ${payout.status}',
                    style:
                        TextStyle(fontSize: 10, color: FanColors.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              'KES ${payout.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: FanColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD METHODS
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    if (_adminChannels.isEmpty) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                color: FanColors.background,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(FanRadius.lg)),
              ),
              child: Column(
                children: [
                  _buildHandle(),
                  const SizedBox(height: 20),
                  Icon(Icons.admin_panel_settings,
                      size: 48, color: FanColors.textTertiary),
                  const SizedBox(height: 12),
                  Text(
                    'You are not an admin of any channel',
                    style: TextStyle(
                      fontSize: 14,
                      color: FanColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Admin features are only available for channel admins',
                    style: TextStyle(
                      fontSize: 12,
                      color: FanColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: widget.onClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FanColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final channel = _currentChannel;
    if (channel == null) return const SizedBox.shrink();

    final stats = _channelStats;
    final channelBalance = stats?.balance ?? 0.0;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: FanColors.background,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(FanRadius.lg)),
            ),
            child: Column(
              children: [
                _buildHandle(),
                _buildHeader(channelBalance),
                _buildPayoutBanner(),
                if (_adminChannels.length > 1) _buildHorizontalChannelList(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshData,
                    child: _isLoading
                        ? _buildLoadingState()
                        : SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              children: [
                                _buildStatsGrid(stats),
                                const SizedBox(height: 16),
                                _buildMembersHeader(),
                                _buildMembersList(),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // UI COMPONENTS
  // ==========================================================================

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: GestureDetector(
          onTap: () {
            final channel = _currentChannel;
            if (channel != null) {
              final String copyText = 'Admin Dashboard: ${channel.name}';
              Clipboard.setData(ClipboardData(text: copyText));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('📋 Copied: $copyText'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          onLongPress: () {
            final channel = _currentChannel;
            if (channel != null) {
              final String copyText = '📊 Channel: ${channel.name}\n'
                  '👥 Members: ${channel.memberCount}\n'
                  '👤 Admin: ${widget.username}\n'
                  '🏷️ ID: ${channel.channelId}';
              Clipboard.setData(ClipboardData(text: copyText));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('📋 Copied channel info!'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: FanColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

 Widget _buildHeader(double channelBalance) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FanColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.dashboard, size: 20, color: FanColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin Dashboard',
                      style: FanTypography.body
                          .copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  if (_currentChannel != null) ...[
                    Text(
                      '${_currentChannel!.name} • ${_currentChannel!.memberCount} members',
                      style: FanTypography.caption.copyWith(
                          color: FanColors.textSecondary, fontSize: 11),
                    ),
                  ],
                  if (_showPaymentFeatures)
                    Text(
                      _isLoadingBalance
                          ? 'Loading balance...'
                          : '💰 Your Balance: KES ${_userBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: FanColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),

            // SHARE CHANNEL BUTTON
            GestureDetector(
              onTap: _shareChannel,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: FanColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.share, size: 16, color: FanColors.primary),
                    const SizedBox(width: 4),
                    Text('SHARE',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: FanColors.primary)),
                  ],
                ),
              ),
            ),

            if (_showPaymentFeatures) ...[
              const SizedBox(width: 8),

              // LOAD BUTTON
              GestureDetector(
                onTap: _isLoadingPayment ? null : _showLoadPaymentDialog,
                child: Row(
                  children: [
                    if (_isLoadingPayment)
                      const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Icon(Icons.download_rounded,
                          size: 18, color: FanColors.primary),
                    const SizedBox(width: 4),
                    Text(_isLoadingPayment ? '' : 'LOAD',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: FanColors.primary)),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // WITHDRAW BUTTON
              GestureDetector(
                onTap: _isWithdrawing ? null : _withdrawCash,
                child: Row(
                  children: [
                    if (_isWithdrawing)
                      const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Icon(Icons.upload_rounded,
                          size: 18,
                          color: channelBalance > 0
                              ? FanColors.secondary
                              : FanColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(_isWithdrawing ? '' : 'WITHDRAW',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: channelBalance > 0
                                ? FanColors.secondary
                                : FanColors.textTertiary)),
                  ],
                ),
              ),
            ],
            const SizedBox(width: 12),
            GestureDetector(
              onTap: widget.onClose,
              child:
                  Icon(Icons.close, size: 20, color: FanColors.textSecondary),
            ),
          ],
        ),
      );

  Widget _buildHorizontalChannelList() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _adminChannels.length,
        itemBuilder: (context, index) {
          final channel = _adminChannels[index];
          final isSelected = _currentChannelIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _currentChannelIndex = index;
                _loadData();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? FanColors.primary.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(channel.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? FanColors.primary
                        : FanColors.textSecondary,
                  )),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsGrid(ChannelStats? stats) {
    if (stats == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('No stats available')),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 8,
        childAspectRatio: 1.0,
        children: [
          _buildStatTile('${stats.totalMessages}', 'Messages',
              Icons.chat_bubble_outline, FanColors.primary),
          _buildStatTile('${stats.messagesThisWeek}', 'Weekly',
              Icons.trending_up, FanColors.secondary),
          _buildStatTile('${stats.memberCount}', 'Members',
              Icons.people_outline, FanColors.textPrimary),
          _buildStatTile('${stats.totalVotes}', 'Votes',
              Icons.how_to_vote_outlined, FanColors.draw),
        ],
      ),
    );
  }

  Widget _buildStatTile(
      String value, String label, IconData icon, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: FanColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 10, color: FanColors.textSecondary),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildMembersHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Icon(Icons.people, size: 16, color: FanColors.primary),
          const SizedBox(width: 8),
          Text('MEMBERS',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: FanColors.textSecondary)),
          const Spacer(),
          Text('${_filteredMembers.length} total',
              style: TextStyle(fontSize: 11, color: FanColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    if (_isLoadingMembers && _members.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
            child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (_filteredMembers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.people_outline,
                  size: 40, color: FanColors.textTertiary),
              const SizedBox(height: 8),
              Text('No members found',
                  style:
                      TextStyle(fontSize: 12, color: FanColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredMembers.length,
      itemBuilder: (context, index) => _buildMemberRow(_filteredMembers[index]),
    );
  }

  // ==========================================================================
  // UPDATED MEMBER ROW WITH REMOVE BUTTON
  // ==========================================================================

  Widget _buildMemberRow(ChannelMemberData member) {
    final isAdmin = member.role == 'admin';
    final isCurrentUser = member.userId == widget.userId;
    final canRemove = !isCurrentUser && !isAdmin;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: FanColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canRemove
              ? FanColors.border.withOpacity(0.3)
              : Colors.transparent,
          width: 0.5,
        ),
      ),
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
                member.username.isNotEmpty
                    ? member.username[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: FanColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isCurrentUser ? 'You' : member.username,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isCurrentUser ? FontWeight.w600 : FontWeight.normal,
                        color: isCurrentUser
                            ? FanColors.primary
                            : FanColors.textPrimary,
                      ),
                    ),
                    if (isAdmin && !isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: FanColors.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'admin',
                          style: TextStyle(
                              fontSize: 8,
                              color: FanColors.secondary,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                    if (isCurrentUser && isAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: FanColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'you',
                          style: TextStyle(
                              fontSize: 8,
                              color: FanColors.primary,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 10, color: FanColors.textSecondary),
                    const SizedBox(width: 2),
                    Text('${member.msgCount} msgs',
                        style: TextStyle(
                            fontSize: 9, color: FanColors.textSecondary)),
                    const SizedBox(width: 8),
                    Icon(Icons.how_to_vote,
                        size: 10, color: FanColors.textSecondary),
                    const SizedBox(width: 2),
                    Text('${member.totalVotes} votes',
                        style: TextStyle(
                            fontSize: 9, color: FanColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: FanColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${member.seasonPoints} pts',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: FanColors.primary)),
          ),
          // ✅ REMOVE BUTTON - Only for non-admin, non-current-user members
          if (canRemove) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isRemovingMember
                  ? null
                  : () => _showRemoveMemberConfirmation(member),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: FanColors.away.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: _isRemovingMember
                    ?  SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: FanColors.away,
                        ),
                      )
                    : Icon(
                        Icons.remove_circle_outline,
                        color: FanColors.away,
                        size: 18,
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(height: 16),
          Text('Loading channel data...'),
        ],
      ),
    );
  }
}
