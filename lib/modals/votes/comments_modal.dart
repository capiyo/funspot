// comment_modal.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../pages/fan_Funzy_design.dart';

class CommentModal extends StatefulWidget {
  final String voteId;
  final String username;
  final String homeTeam;
  final String awayTeam;

  const CommentModal({
    super.key,
    required this.voteId,
    required this.username,
    required this.homeTeam,
    required this.awayTeam,
  });

  @override
  State<CommentModal> createState() => _CommentModalState();
}

class Comment {
  final String id;
  final String userId;
  final String username;
  final String content;
  final DateTime timestamp;
  final int likes;

  Comment({
    required this.id,
    required this.userId,
    required this.username,
    required this.content,
    required this.timestamp,
    required this.likes,
  });
}

class _CommentModalState extends State<CommentModal> {
  final TextEditingController _commentController = TextEditingController();
  final List<Comment> _comments = [];
  bool _isLoading = true;
  bool _postingComment = false;
  final String _apiBaseUrl = 'https://clash-api-m5mr.onrender.com/api';

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      // Try to fetch comments from API
      final url = Uri.parse('$_apiBaseUrl/comments/${widget.voteId}');
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json'
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['comments'] != null) {
          final List<dynamic> commentsData = data['comments'];
          final List<Comment> loadedComments = [];

          for (var commentData in commentsData) {
            try {
              loadedComments.add(
                Comment(
                  id: commentData['id'] ?? commentData['_id']?.toString() ?? '',
                  userId: commentData['user_id']?.toString() ?? '',
                  username: commentData['username']?.toString() ?? 'Anonymous',
                  content: commentData['content']?.toString() ?? '',
                  timestamp: DateTime.parse(
                    commentData['timestamp'] ??
                        commentData['created_at'] ??
                        DateTime.now().toString(),
                  ),
                  likes: commentData['likes'] ?? commentData['like_count'] ?? 0,
                ),
              );
            } catch (e) {}
          }

          setState(() {
            _comments.addAll(loadedComments);
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      // If API fails, show sample comments
      _loadSampleComments();
    }
  }

  void _loadSampleComments() {
    // Sample comments
    final sampleComments = [
      Comment(
        id: '1',
        userId: 'user1',
        username: 'FootballFan88',
        content: 'Great prediction! I agree with this analysis.',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        likes: 5,
      ),
      Comment(
        id: '2',
        userId: 'user2',
        username: 'SoccerExpert',
        content: 'The stats don\'t support this. Check the recent form.',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        likes: 3,
      ),
      Comment(
        id: '3',
        userId: 'user3',
        username: 'TeamSupporter',
        content: 'Let\'s go team! Hope they prove you right.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        likes: 8,
      ),
    ];

    setState(() {
      _comments.addAll(sampleComments);
      _isLoading = false;
    });
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty || _postingComment) return;

    final content = _commentController.text.trim();
    setState(() {
      _postingComment = true;
    });

    try {
      // Prepare comment data
      final newComment = Comment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: 'current_user', // In real app, get from shared preferences
        username: 'You',
        content: content,
        timestamp: DateTime.now(),
        likes: 0,
      );

      // Add to UI immediately for better UX
      setState(() {
        _comments.insert(0, newComment);
        _commentController.clear();
      });

      // Send to backend
      final url = Uri.parse('$_apiBaseUrl/comments');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'vote_id': widget.voteId,
              'content': content,
              'user_id': 'current_user', // In real app, get actual user ID
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['comment'] != null) {
          // Update with server data if needed
          final serverComment = data['comment'];
          setState(() {
            _comments[0] = Comment(
              id: serverComment['id'] ?? serverComment['_id'] ?? newComment.id,
              userId: serverComment['user_id'] ?? newComment.userId,
              username: serverComment['username'] ?? newComment.username,
              content: serverComment['content'] ?? newComment.content,
              timestamp: DateTime.parse(
                serverComment['timestamp'] ??
                    serverComment['created_at'] ??
                    newComment.timestamp.toString(),
              ),
              likes: serverComment['likes'] ?? newComment.likes,
            );
          });
        }
      }
    } catch (e) {
      // Keep the comment in UI even if API fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Comment posted locally'),
          backgroundColor: FanColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: FanRadius.lgAll),
        ),
      );
    } finally {
      setState(() {
        _postingComment = false;
      });
    }
  }

  Future<void> _likeComment(int index) async {
    if (index >= _comments.length) return;

    final comment = _comments[index];
    final originalLikes = comment.likes;

    setState(() {
      _comments[index] = Comment(
        id: comment.id,
        userId: comment.userId,
        username: comment.username,
        content: comment.content,
        timestamp: comment.timestamp,
        likes: comment.likes + 1,
      );
    });

    try {
      final url = Uri.parse('$_apiBaseUrl/comments/${comment.id}/like');
      await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'user_id': 'current_user'}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      // Revert on error
      setState(() {
        _comments[index] = Comment(
          id: comment.id,
          userId: comment.userId,
          username: comment.username,
          content: comment.content,
          timestamp: comment.timestamp,
          likes: originalLikes,
        );
      });
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(time);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: FanColors.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: FanColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Comments',
          style: FanTypography.body.copyWith(
            color: FanColors.textPrimary,
          ),
        ),
        elevation: 0,
      ),
      backgroundColor: FanColors.background,
      body: Column(
        children: [
          // Match info header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FanColors.surface,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: FanColors.border)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: FanColors.primaryDim,
                  child: Icon(
                    Icons.person,
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
                        widget.username,
                        style: FanTypography.caption.copyWith(
                          color: FanColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${widget.homeTeam} vs ${widget.awayTeam}',
                        style: FanTypography.tag.copyWith(
                          color: FanColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Comment input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FanColors.surface,
              border: Border(
                bottom: BorderSide(color: FanColors.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: FanColors.primary,
                  child: Icon(Icons.person,
                      size: 16, color: FanColors.textInverse),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: FanColors.surfaceSunken,
                      borderRadius: FanRadius.pillAll,
                    ),
                    child: TextField(
                      controller: _commentController,
                      style: FanTypography.caption.copyWith(
                        color: FanColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle: FanTypography.caption.copyWith(
                          color: FanColors.textTertiary,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        suffixIcon: _postingComment
                            ? Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: FanColors.primary,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: Icon(
                                  Icons.send,
                                  color: FanColors.primary,
                                  size: 20,
                                ),
                                onPressed: _postComment,
                              ),
                      ),
                      onSubmitted: (_) => _postComment(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Comments list
          Expanded(
            child: _isLoading
                ? Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: FanColors.primary,
                      ),
                    ),
                  )
                : _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.comment,
                              size: 48,
                              color: FanColors.textTertiary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No comments yet',
                              style: FanTypography.body.copyWith(
                                color: FanColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to comment',
                              style: FanTypography.caption.copyWith(
                                color: FanColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          final isOwnComment = comment.username == 'You';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: FanColors.surface,
                              borderRadius: FanRadius.lgAll,
                              border: Border.all(color: FanColors.border),
                              boxShadow: FanShadows.subtle,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: isOwnComment
                                              ? FanColors.primary
                                              : FanColors.primaryDim,
                                          child: Icon(
                                            Icons.person,
                                            size: 12,
                                            color: isOwnComment
                                                ? FanColors.textInverse
                                                : FanColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          comment.username,
                                          style: FanTypography.caption.copyWith(
                                            color: isOwnComment
                                                ? FanColors.primary
                                                : FanColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (isOwnComment) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: FanColors.primaryDim,
                                              borderRadius: FanRadius.smAll,
                                            ),
                                            child: Text(
                                              'You',
                                              style: FanTypography.tag.copyWith(
                                                color: FanColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      _formatTime(comment.timestamp),
                                      style: FanTypography.tag.copyWith(
                                        color: FanColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  comment.content,
                                  style: FanTypography.body.copyWith(
                                    color: FanColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _likeComment(index),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.thumb_up,
                                            size: 14,
                                            color: FanColors.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            comment.likes.toString(),
                                            style: FanTypography.tag.copyWith(
                                              color: FanColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
