// ========== POST_COMMENTS.WIDGET - UPDATED ==========

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../models/post_models.dart';
import '../../models/comments_model.dart'; // ✅ Import Comment model
import '../../pages/fan_Funzy_design.dart';
import '../../services/notification_service.dart';
import "../../main.dart";

class PostComments extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final Post post;
  final String currentUserId;
  final String currentUsername;
  final String? authToken;
  final String? fcmToken;

  const PostComments({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.post,
    required this.currentUserId,
    required this.currentUsername,
    this.authToken,
    this.fcmToken,
  });

  @override
  State<PostComments> createState() => _PostCommentsState();
}

class _PostCommentsState extends State<PostComments> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commentFocusNode = FocusNode();

  bool _isSubmitting = false;
  bool _isLoading = false;
  String _error = '';
  bool _showError = false;
  bool _isDisposed = false;

  // ✅ Reply state
  Map<String, dynamic>? _replyingTo;
  bool _isReplying = false;

  final String _apiBaseUrl = 'https://clash-api-m5mr.onrender.com/api';
  final List<Map<String, dynamic>> _comments = [];

  @override
  void initState() {
    super.initState();
    print('🚀 PostComments initState - isOpen: ${widget.isOpen}');
    print(
        '👤 Current User: ${widget.currentUsername} (${widget.currentUserId})');
    print('📌 Post ID: ${widget.post.id}');

    _commentFocusNode.addListener(_handleFocusChange);

    if (widget.isOpen) {
      _loadComments();
    }
  }

  @override
  void didUpdateWidget(covariant PostComments oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      print('🔄 Modal opened, loading comments...');
      _loadComments();
    }
  }

  @override
  void dispose() {
    print('🧹 Disposing PostComments');
    _isDisposed = true;
    _commentController.dispose();
    _scrollController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_commentFocusNode.hasFocus) {
      print('🔍 Comment field focused');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json'};
    if (widget.authToken != null && widget.authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${widget.authToken}';
      print('🔑 Auth header added');
    } else {
      print('⚠️ No auth token available');
    }
    return headers;
  }

  Map<String, dynamic> _createCommentRequest(String comment,
      {String? parentCommentId}) {
    final Map<String, dynamic> request = {
      'user_id': widget.currentUserId,
      'user_name': widget.currentUsername,
      'comment': comment,
    };
    if (parentCommentId != null && parentCommentId.isNotEmpty) {
      request['parent_comment_id'] = parentCommentId;
    }
    return request;
  }

  // NOTE: the Rust API (CommentResponse) serializes fields as camelCase —
  // postId, userId, userName, likesCount, likedBy, parentCommentId,
  // replyCount, createdAt, updatedAt, lastModified — not snake_case. This
  // used to only check snake_case keys, so almost every field silently came
  // back as its default on a real response. Now checks camelCase first
  // (what the server actually sends) with snake_case as a fallback.
  Map<String, dynamic> _parseCommentFromJson(Map<String, dynamic> json) {
    return {
      'id': json['id']?.toString() ?? '',
      'post_id':
          json['postId']?.toString() ?? json['post_id']?.toString() ?? '',
      'user_id':
          json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      'user_name': json['userName']?.toString() ??
          json['user_name']?.toString() ??
          'Anonymous',
      'comment': json['comment']?.toString() ?? '',
      'likes_count': json['likesCount'] ?? json['likes_count'] ?? 0,
      'liked_by': List<String>.from(json['likedBy'] ?? json['liked_by'] ?? []),
      'parent_comment_id': json['parentCommentId']?.toString() ??
          json['parent_comment_id']?.toString(),
      'reply_count': json['replyCount'] ?? json['reply_count'] ?? 0,
      'replies': (json['replies'] as List?)
              ?.map((r) => _parseCommentFromJson(r))
              .toList() ??
          [],
      'created_at': json['createdAt']?.toString() ??
          json['created_at']?.toString() ??
          DateTime.now().toIso8601String(),
      'updated_at':
          json['updatedAt']?.toString() ?? json['updated_at']?.toString() ?? '',
      'last_modified': json['lastModified']?.toString() ??
          json['last_modified']?.toString() ??
          '',
      'timestamp': json['timestamp'] ?? 0,
    };
  }

  // ✅ Check if comment is a reply
  bool _isReply(Map<String, dynamic> comment) {
    return comment['parent_comment_id'] != null &&
        comment['parent_comment_id']!.toString().isNotEmpty;
  }

  // ✅ Get parent comment username
  String? _getParentUsername(String? parentId) {
    if (parentId == null) return null;
    for (var comment in _comments) {
      if (comment['id'] == parentId) {
        return comment['user_name']?.toString() ?? 'User';
      }
    }
    return null;
  }

  // ========== LOAD COMMENTS WITH CACHE ==========
  Future<void> _loadComments() async {
    if (!mounted || _isLoading) return;

    print('=' * 50);
    print('📥 LOADING COMMENTS');
    print('=' * 50);

    _safeSetState(() {
      _isLoading = true;
      _error = '';
      _showError = false;
    });

    try {
      // ✅ FIRST: Check cache
      final postId = widget.post.id ?? '';
      final cachedComments = AppCache.getCachedComments(postId);

      if (cachedComments != null && cachedComments.isNotEmpty) {
        print('📦 Loading ${cachedComments.length} comments from cache');
        _safeSetState(() {
          _comments.clear();
          _comments.addAll(cachedComments
              .map((c) => _parseCommentFromJson(c.toJson()))
              .toList());
        });

        // ✅ If cache is fresh (less than 30 seconds old), skip API
        final lastLoad = AppCache.getLastCommentLoad(postId);
        if (lastLoad != null &&
            DateTime.now().difference(lastLoad).inSeconds < 30) {
          print('✅ Cache is fresh, skipping API call');
          _safeSetState(() => _isLoading = false);
          return;
        }
      }

      // ✅ SECOND: Fetch from API
     final url = '$_apiBaseUrl/posts/${widget.post.id}/comments';
      final headers = _getHeaders();

      print('🌐 Fetching from API: $url');
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        final List<Map<String, dynamic>> newComments = [];

        if (jsonResponse.containsKey('success') &&
            jsonResponse['success'] == true) {
          final commentsList = jsonResponse['comments'] as List? ?? [];
          print('📋 Found ${commentsList.length} comments in response');

          for (var comment in commentsList) {
            if (comment is Map<String, dynamic>) {
              final parsedComment = _parseCommentFromJson(comment);
              newComments.add(parsedComment);
            }
          }
        }

        // ✅ Convert to Comment objects for caching
        final commentObjects =
            newComments.map((c) => Comment.fromJson(c)).toList();

        // ✅ Save to cache
        if (widget.post.id != null) {
          AppCache.cacheComments(widget.post.id!, commentObjects);
        }

        _safeSetState(() {
          _comments.clear();
          _comments.addAll(newComments);
        });

        print('✅ Successfully loaded ${newComments.length} comments');
      } else {
        print('❌ Failed to load comments. Status: ${response.statusCode}');
        // If we have cached data, keep it
        if (_comments.isNotEmpty) {
          print('📦 Using cached data since API failed');
          return;
        }
        throw Exception('Failed to load comments');
      }
    } catch (e) {
      print('❌ Error loading comments: $e');
      if (_comments.isEmpty) {
        _safeSetState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _showError = true;
        });
      }
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  // ========== SEND NOTIFICATION ==========
  Future<void> _sendPushNotification(Map<String, dynamic> comment,
      {String? parentCommentId}) async {
    try {
      final commentText = comment['comment'] as String? ?? '';

      // If this is a reply to someone, notify the parent comment author
      if (parentCommentId != null && parentCommentId.isNotEmpty) {
        final parentComment = _comments.firstWhere(
          (c) => c['id'] == parentCommentId,
          orElse: () => {},
        );
        final parentUserId = parentComment['user_id']?.toString();

        if (parentUserId != null &&
            parentUserId != widget.currentUserId &&
            parentUserId != widget.post.userId) {
          print(
              '📱 Sending reply notification to parent comment author: $parentUserId');
          final notificationData = {
            'post_id': widget.post.id ?? '',
            'comment_id': comment['id'] ?? '',
            'parent_comment_id': parentCommentId,
            'comment_preview': commentText.length > 50
                ? '${commentText.substring(0, 50)}...'
                : commentText,
            'commenter_id': widget.currentUserId,
            'commenter_name': widget.currentUsername,
            'parent_commenter_name': parentComment['user_name'] ?? 'User',
            'type': 'comment_reply',
            'timestamp': DateTime.now().toIso8601String(),
          };

          await NotificationService.sendNotification(
            userId: parentUserId,
            notificationType: 'comment_reply',
            title: '${widget.currentUsername} replied to your comment',
            body: commentText.length > 100
                ? '${commentText.substring(0, 100)}...'
                : commentText,
            data: notificationData,
          );
        }
      }

      // Also notify post owner if different from current user and parent author
      if (widget.post.userId != widget.currentUserId &&
          (parentCommentId == null ||
              (parentCommentId != null &&
                  _getParentUsername(parentCommentId) !=
                      widget.post.userName))) {
        print('📱 Sending notification to post owner: ${widget.post.userId}');
        final notificationData = {
          'post_id': widget.post.id ?? '',
          'post_caption': widget.post.caption ?? '',
          'comment_id': comment['id'] ?? '',
          'comment_preview': commentText.length > 50
              ? '${commentText.substring(0, 50)}...'
              : commentText,
          'commenter_id': widget.currentUserId,
          'commenter_name': widget.currentUsername,
          'post_owner_id': widget.post.userId ?? '',
          'is_reply': parentCommentId != null,
          'type': 'post_comment',
          'timestamp': DateTime.now().toIso8601String(),
        };

        await NotificationService.sendNotification(
          userId: widget.post.userId ?? '',
          notificationType: 'post_comment',
          title: '${widget.currentUsername} commented on your post',
          body: commentText.length > 100
              ? '${commentText.substring(0, 100)}...'
              : commentText,
          data: notificationData,
        );
      }
    } catch (e) {
      print('❌ Error sending notification: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Just now';

    try {
      final date = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m';
      if (difference.inHours < 24) return '${difference.inHours}h';
      if (difference.inDays < 7) return '${difference.inDays}d';
      if (difference.inDays < 30) return '${difference.inDays} days ago';
      if (difference.inDays < 365) {
        return '${(difference.inDays / 30).floor()}mo';
      }
      return '${date.month}/${date.year}';
    } catch (e) {
      print('Error parsing date: $e');
      return isoString;
    }
  }

  String _getInitials(String name) =>
      name.isNotEmpty ? name[0].toUpperCase() : 'U';

  // ✅ Build reply indicator in input bar
  Widget _buildReplyIndicator() {
    if (_replyingTo == null) return const SizedBox.shrink();

    final parentUsername = _replyingTo!['user_name']?.toString() ?? 'User';
    final parentText = _replyingTo!['comment']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: FanColors.primaryDim,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply_rounded,
            size: 14,
            color: FanColors.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to @$parentUsername',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: FanColors.primary,
                  ),
                ),
                Text(
                  parentText.length > 40
                      ? '${parentText.substring(0, 40)}...'
                      : parentText,
                  style: TextStyle(
                    fontSize: 9,
                    color: FanColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _cancelReply,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: FanColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                size: 12,
                color: FanColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _cancelReply() {
    _safeSetState(() {
      _replyingTo = null;
      _isReplying = false;
    });
  }

  void _setReplyTo(Map<String, dynamic> comment) {
    _safeSetState(() {
      _replyingTo = comment;
      _isReplying = true;
    });
    _commentFocusNode.requestFocus();
  }

  // ========== BUILD COMMENT BUBBLE ==========
  Widget _buildCommentItem(int index) {
    final comment = _comments[index];
    final username = comment['user_name']?.toString() ?? 'Anonymous';
    final userId = comment['user_id']?.toString() ?? '';
    final content = comment['comment']?.toString() ?? '';
    final timestamp = comment['created_at']?.toString() ?? '';
    final isMe = userId == widget.currentUserId;
    final isReply = _isReply(comment);
    final parentUsername =
        isReply ? _getParentUsername(comment['parent_comment_id']) : null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 14,
        left: isReply ? 40 : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Reply indicator for replies
          if (isReply && parentUsername != null)
            Padding(
              padding: const EdgeInsets.only(left: 44, bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.reply_rounded,
                    size: 10,
                    color: FanColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Reply to @$parentUsername',
                    style: TextStyle(
                      fontSize: 9,
                      color: FanColors.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                GestureDetector(
                  onLongPress: () => _setReplyTo(comment),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: FanColors.primaryDim,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: FanColors.primaryMuted,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(username),
                        style: FanTypography.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: FanColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: GestureDetector(
                  onLongPress: () => _setReplyTo(comment),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: 3, left: 4, right: 4),
                        child: Text(
                          isMe ? '' : username,
                          style: FanTypography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? FanColors.primaryDim
                              : FanColors.surfaceSunken,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 16),
                          ),
                          border: Border.all(
                            color: isMe
                                ? FanColors.primaryMuted
                                : FanColors.border,
                          ),
                        ),
                        child: Text(
                          content,
                          style: FanTypography.body.copyWith(fontSize: 13),
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 3, left: 6, right: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatDateTime(timestamp),
                              style: FanTypography.tag.copyWith(
                                color: FanColors.textTertiary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _setReplyTo(comment),
                              child: Text(
                                'Reply',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: FanColors.primary,
                                  fontWeight: FontWeight.w600,
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
              if (isMe) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onLongPress: () => _setReplyTo(comment),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: FanColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(widget.currentUsername),
                        style: FanTypography.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: FanColors.textInverse,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ========== DRAG HANDLE ==========
  Widget _buildHandle() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: FanColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );

  // ========== HEADER ==========
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: FanColors.border, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: FanColors.primaryDim,
                  borderRadius: FanRadius.lgAll,
                ),
                child: Center(
                  child: Icon(
                    Icons.comment,
                    size: 18,
                    color: FanColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comments',
                    style: FanTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '${_comments.length} responses',
                    style: FanTypography.caption.copyWith(
                      color: FanColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: FanColors.surfaceSunken,
                shape: BoxShape.circle,
                border: Border.all(color: FanColors.border),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 36,
            color: FanColors.border,
          ),
          const SizedBox(height: 10),
          Text(
            'No comments yet',
            style: FanTypography.caption,
          ),
          const SizedBox(height: 4),
          Text(
            'Be the first to comment!',
            style: FanTypography.tag.copyWith(
              color: FanColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ========== INPUT FIELD ==========
  Widget _buildInputField({required double bottomPadding}) {
    final hasText = _commentController.text.trim().isNotEmpty;

    return Column(
      children: [
        if (_replyingTo != null) _buildReplyIndicator(),
        Container(
          padding: EdgeInsets.fromLTRB(12, 10, 12, bottomPadding),
          decoration: BoxDecoration(
            color: FanColors.surface,
            border:
                Border(top: BorderSide(color: FanColors.border, width: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: FanColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _getInitials(widget.currentUsername),
                    style: FanTypography.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: FanColors.textInverse,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: 42, maxHeight: 120),
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    enabled: !_isSubmitting,
                    style: FanTypography.body.copyWith(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: _replyingTo != null
                          ? 'Reply to @${_replyingTo!['user_name']}...'
                          : 'Write a comment…',
                      hintStyle: FanTypography.caption.copyWith(
                        fontStyle: FontStyle.normal,
                        color: FanColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: FanColors.surfaceSunken,
                      border: OutlineInputBorder(
                        borderRadius: FanRadius.pillAll,
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: FanRadius.pillAll,
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: FanRadius.pillAll,
                        borderSide: BorderSide(
                          color: FanColors.primary,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      isDense: true,
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 36,
                                height: 36,
                                child: Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _commentController,
                                builder: (context, value, _) {
                                  final hasTextLocal =
                                      value.text.trim().isNotEmpty;
                                  return IconButton(
                                    icon: Icon(
                                      Icons.send_rounded,
                                      size: 20,
                                      color: hasTextLocal
                                          ? FanColors.primary
                                          : FanColors.border,
                                    ),
                                    onPressed:
                                        hasTextLocal ? _createComment : null,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    onChanged: (_) => _safeSetState(() {}),
                    onSubmitted: (_) => _createComment(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ========== CREATE COMMENT (WITHOUT DUPLICATE CHECK) ==========
  Future<void> _createComment() async {
    final content = _commentController.text.trim();

    print('=' * 50);
    print('📝 CREATE COMMENT ATTEMPT');
    print('=' * 50);
    print('📝 Content: "$content"');
    if (_replyingTo != null) {
      print(
          '📝 Replying to: ${_replyingTo!['user_name']} (${_replyingTo!['id']})');
    }

    if (content.isEmpty) {
      print('❌ Cannot submit empty comment');
      _safeSetState(() {
        _error = 'Comment cannot be empty';
        _showError = true;
      });
      Future.delayed(const Duration(seconds: 2), () {
        _safeSetState(() => _showError = false);
      });
      return;
    }

    if (_isSubmitting) return;

    _safeSetState(() {
      _isSubmitting = true;
      _error = '';
      _showError = false;
    });

    try {
   final url = '$_apiBaseUrl/posts/${widget.post.id}/comments';
      final headers = _getHeaders();

      final parentCommentId = _replyingTo?['id']?.toString();
      final requestBody =
          _createCommentRequest(content, parentCommentId: parentCommentId);

      print('📤 Request: $requestBody');
      final response = await http
          .post(Uri.parse(url), headers: headers, body: jsonEncode(requestBody))
          .timeout(const Duration(seconds: 10));

      print('📥 Response Status: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        print('✅ Comment created successfully');

        Map<String, dynamic> newCommentData = {};

        if (data is Map) {
          if (data['success'] == true && data['data'] != null) {
            newCommentData = data['data'] is Map ? Map.from(data['data']) : {};
          } else if (data['comment'] != null) {
            newCommentData =
                data['comment'] is Map ? Map.from(data['comment']) : {};
          } else {
            newCommentData = Map.from(data);
          }
        }

        final newComment = _parseCommentFromJson(newCommentData);

        // ✅ Save to cache
        final commentObject = Comment.fromJson(newComment);
        if (widget.post.id != null) {
          if (parentCommentId != null) {
            AppCache.addReplyToCache(
                widget.post.id!, commentObject, parentCommentId);
          } else {
            AppCache.addCommentToCache(widget.post.id!, commentObject);
          }
        }

        await _sendPushNotification(newComment,
            parentCommentId: parentCommentId);

        _safeSetState(() {
          if (parentCommentId != null) {
            // Add reply to parent comment
            final parentIndex =
                _comments.indexWhere((c) => c['id'] == parentCommentId);
            if (parentIndex != -1) {
              final parent = _comments[parentIndex];
              final replies =
                  List<Map<String, dynamic>>.from(parent['replies'] ?? []);
              replies.insert(0, newComment);
              _comments[parentIndex]['replies'] = replies;
              // NOTE: this used to write 'replyCount' (camelCase) while every
              // other place in this widget reads/writes 'reply_count'
              // (snake_case, set by _parseCommentFromJson). That meant the
              // real counter never updated. Fixed to use the same key.
              _comments[parentIndex]['reply_count'] =
                  (parent['reply_count'] ?? 0) + 1;
            } else {
              _comments.insert(0, newComment);
            }
          } else {
            _comments.insert(0, newComment);
          }
          _commentController.clear();
          _replyingTo = null;
          _isReplying = false;
        });

        _commentFocusNode.unfocus();
        _scrollToBottom();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              parentCommentId != null ? 'Reply posted!' : 'Comment posted!',
              style: FanTypography.caption.copyWith(
                color: FanColors.textInverse,
              ),
            ),
            backgroundColor: FanColors.primary,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: FanRadius.lgAll),
          ),
        );
      } else {
        String errorMsg = 'Failed to create comment';
        try {
          final errorData = jsonDecode(response.body);
          errorMsg = errorData['message'] ?? errorData['error'] ?? errorMsg;
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } on TimeoutException catch (e) {
      print('❌ Timeout: $e');
      _safeSetState(() {
        _error = 'Request timeout - try again';
        _showError = true;
      });
    } catch (e) {
      print('❌ Error creating comment: $e');
      _safeSetState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _showError = true;
      });
    } finally {
      _safeSetState(() => _isSubmitting = false);
    }
  }

  // ========== MAIN BUILD ==========
  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    final mq = MediaQuery.of(context);
    final keyboardH = mq.viewInsets.bottom;
    final bottomPad = mq.padding.bottom;

    return Stack(
      children: [
        // Backdrop
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              _commentFocusNode.unfocus();
              widget.onClose();
            },
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),
        ),

        // Sheet - With AnimatedPadding for keyboard
        AnimatedPadding(
          padding: EdgeInsets.only(bottom: keyboardH),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: mq.size.height * 0.88,
              decoration: BoxDecoration(
                color: FanColors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border.all(color: FanColors.border),
              ),
              child: Column(
                children: [
                  _buildHandle(),
                  _buildHeader(),
                  Expanded(
                    child: _isLoading
                        ? Center(
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
                                  'Loading comments...',
                                  style: FanTypography.caption,
                                ),
                              ],
                            ),
                          )
                        : _comments.isEmpty && !_isLoading
                            ? _buildEmptyState()
                            : ListView.builder(
                                controller: _scrollController,
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                itemCount: _comments.length,
                                itemBuilder: (context, index) =>
                                    _buildCommentItem(index),
                              ),
                  ),
                  _buildInputField(
                    bottomPadding: keyboardH > 0 ? 12 : bottomPad + 12,
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
