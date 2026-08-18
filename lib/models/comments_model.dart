// models/comment_models.dart

import 'package:flutter/material.dart';

// ============================================================================
// COMMENT MODEL - Full featured with reply support
// ============================================================================

class Comment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String comment;
  final int likesCount;
  final List<String> likedBy;
  final String? parentCommentId;
  final int replyCount;
  final List<Comment>? replies;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastModified;
  final int timestamp;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.comment,
    this.likesCount = 0,
    this.likedBy = const [],
    this.parentCommentId,
    this.replyCount = 0,
    this.replies,
    required this.createdAt,
    this.updatedAt,
    this.lastModified,
    this.timestamp = 0,
  });

  // ==========================================================================
  // FROM JSON - Parse from API response
  // ==========================================================================

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      // NOTE: previously checked 'postId' twice (dead fallback). The Rust
      // API always sends camelCase `postId` in CommentResponse, but we keep
      // the snake_case fallback for safety/other callers.
      postId: json['postId']?.toString() ??
          json['post_id']?.toString() ??
          '',
      userId: json['userId']?.toString() ??
          json['user_id']?.toString() ??
          json['sender_id']?.toString() ??
          '',
      userName: json['userName']?.toString() ??
          json['user_name']?.toString() ??
          json['sender_name']?.toString() ??
          'Anonymous',
      comment: json['comment']?.toString() ??
          json['message']?.toString() ??
          json['text']?.toString() ??
          '',
      likesCount:
          json['likesCount'] ?? json['likes_count'] ?? json['likes'] ?? 0,
      likedBy: List<String>.from(
          json['likedBy'] ?? json['liked_by'] ?? json['likes_by'] ?? []),
      parentCommentId: json['parentCommentId']?.toString() ??
          json['parent_comment_id']?.toString() ??
          json['reply_to_id']?.toString(),
      replyCount: json['replyCount'] ??
          json['reply_count'] ??
          json['replies_count'] ??
          0,
      replies: (json['replies'] as List?)
          ?.map((r) => Comment.fromJson(r as Map<String, dynamic>))
          .toList(),
      createdAt: _parseDateTime(
          json['createdAt'] ?? json['created_at'] ?? json['timestamp']),
      updatedAt:
          _parseDateTimeNullable(json['updatedAt'] ?? json['updated_at']),
      lastModified:
          _parseDateTimeNullable(json['lastModified'] ?? json['last_modified']),
      timestamp: json['timestamp']?.toInt() ?? json['timeStamp']?.toInt() ?? 0,
    );
  }

  // ==========================================================================
  // TO JSON - Convert to JSON for API requests
  // ==========================================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'comment': comment,
      'likesCount': likesCount,
      'likedBy': likedBy,
      if (parentCommentId != null) 'parentCommentId': parentCommentId,
      'replyCount': replyCount,
      if (replies != null) 'replies': replies!.map((r) => r.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (lastModified != null) 'lastModified': lastModified!.toIso8601String(),
      'timestamp': timestamp,
    };
  }

  // ==========================================================================
  // TO CREATE REQUEST - For sending to API
  // ==========================================================================

  Map<String, dynamic> toCreateRequest() {
    return {
      'user_id': userId,
      'user_name': userName,
      'comment': comment,
      if (parentCommentId != null && parentCommentId!.isNotEmpty)
        'parent_comment_id': parentCommentId,
    };
  }

  // ==========================================================================
  // COPY WITH - Create updated copy
  // ==========================================================================

  Comment copyWith({
    String? id,
    String? postId,
    String? userId,
    String? userName,
    String? comment,
    int? likesCount,
    List<String>? likedBy,
    String? parentCommentId,
    int? replyCount,
    List<Comment>? replies,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastModified,
    int? timestamp,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      comment: comment ?? this.comment,
      likesCount: likesCount ?? this.likesCount,
      likedBy: likedBy ?? this.likedBy,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      replyCount: replyCount ?? this.replyCount,
      replies: replies ?? this.replies,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastModified: lastModified ?? this.lastModified,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  bool get isReply => parentCommentId != null && parentCommentId!.isNotEmpty;

  bool get hasReplies => replyCount > 0 && (replies?.isNotEmpty ?? false);

  bool get isLikedByMe => likedBy.contains(userId);

  String get formattedTime => _formatTimeAgo(createdAt);

  String get initials => userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

  // ==========================================================================
  // PRIVATE HELPERS
  // ==========================================================================

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  static DateTime? _parseDateTimeNullable(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String _formatTimeAgo(DateTime date) {
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
  }

  // ==========================================================================
  // EQUALITY & HASHCODE
  // ==========================================================================

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Comment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Comment(id: $id, user: $userName, comment: $comment, replies: $replyCount)';
  }
}

// ============================================================================
// CREATE COMMENT REQUEST
// ============================================================================

class CreateCommentRequest {
  final String userId;
  final String userName;
  final String comment;
  final String? parentCommentId;

  CreateCommentRequest({
    required this.userId,
    required this.userName,
    required this.comment,
    this.parentCommentId,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'comment': comment,
      if (parentCommentId != null && parentCommentId!.isNotEmpty)
        'parent_comment_id': parentCommentId,
    };
  }

  factory CreateCommentRequest.fromJson(Map<String, dynamic> json) {
    return CreateCommentRequest(
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? 'Anonymous',
      comment: json['comment']?.toString() ?? '',
      parentCommentId: json['parent_comment_id']?.toString(),
    );
  }
}

// ============================================================================
// UPDATE COMMENT REQUEST
// ============================================================================

class UpdateCommentRequest {
  final String comment;

  UpdateCommentRequest({required this.comment});

  Map<String, dynamic> toJson() {
    return {
      'comment': comment,
    };
  }
}

// ============================================================================
// LIKE COMMENT REQUEST
// ============================================================================

class LikeCommentRequest {
  final String userId;

  LikeCommentRequest({required this.userId});

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
    };
  }
}

// ============================================================================
// COMMENT RESPONSE (API Wrapper)
// ============================================================================

class CommentsResponse {
  final bool success;
  final List<Comment> comments;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;
  final String? message;

  CommentsResponse({
    required this.success,
    this.comments = const [],
    this.total = 0,
    this.page = 1,
    this.limit = 10,
    this.totalPages = 0,
    this.hasNext = false,
    this.hasPrevious = false,
    this.message,
  });

  factory CommentsResponse.fromJson(Map<String, dynamic> json) {
    final commentsList = json['comments'] as List? ?? [];

    // The Rust handlers (get_comments / get_comment_replies /
    // get_user_comments) nest all paging info under a "pagination" object:
    //   { "success": ..., "comments": [...], "pagination": { "page": ...,
    //     "limit": ..., "total_count": ..., "total_pages": ...,
    //     "has_next": ..., "has_previous": ... } }
    // The old version read page/limit/total/totalPages off the top level,
    // so it silently fell back to defaults on every real response and
    // `hasMore` never worked past page 1. Read from "pagination" first,
    // falling back to top-level keys for any other/older response shape.
    final pagination = json['pagination'] as Map<String, dynamic>?;
    final pageSource = pagination ?? json;

    return CommentsResponse(
      success: json['success'] ?? false,
      comments: commentsList
          .map((c) => Comment.fromJson(c as Map<String, dynamic>))
          .toList(),
      total: pageSource['total_count']?.toInt() ??
          pageSource['total']?.toInt() ??
          commentsList.length,
      page: pageSource['page']?.toInt() ?? 1,
      limit: pageSource['limit']?.toInt() ?? 10,
      totalPages: pageSource['total_pages']?.toInt() ??
          pageSource['totalPages']?.toInt() ??
          0,
      hasNext: pageSource['has_next'] ?? false,
      hasPrevious: pageSource['has_previous'] ?? false,
      message: json['message']?.toString(),
    );
  }

  bool get hasMore => hasNext;
  int get count => comments.length;
}

// ============================================================================
// SINGLE COMMENT RESPONSE
// ============================================================================

class CommentResponse {
  final bool success;
  final Comment? comment;
  final String? message;

  CommentResponse({
    required this.success,
    this.comment,
    this.message,
  });

  factory CommentResponse.fromJson(Map<String, dynamic> json) {
    final commentData = json['data'] ?? json['comment'];
    return CommentResponse(
      success: json['success'] ?? false,
      comment: commentData != null
          ? Comment.fromJson(commentData as Map<String, dynamic>)
          : null,
      message: json['message']?.toString(),
    );
  }
}

// ============================================================================
// COMMENT COUNT RESPONSE
// ============================================================================

class CommentCountResponse {
  final String postId;
  final int count;

  CommentCountResponse({
    required this.postId,
    required this.count,
  });

  factory CommentCountResponse.fromJson(Map<String, dynamic> json) {
    return CommentCountResponse(
      postId: json['postId']?.toString() ??
          json['post_id']?.toString() ??
          json['id']?.toString() ??
          '',
      count: json['count']?.toInt() ?? json['total']?.toInt() ?? 0,
    );
  }
}

// ============================================================================
// COMMENT SORT OPTIONS
// ============================================================================

enum CommentSortOption {
  newest('Newest'),
  oldest('Oldest'),
  mostLiked('Most Liked'),
  mostReplies('Most Replies');

  final String label;
  const CommentSortOption(this.label);

  String get apiValue {
    switch (this) {
      case CommentSortOption.newest:
        return 'newest';
      case CommentSortOption.oldest:
        return 'oldest';
      case CommentSortOption.mostLiked:
        return 'likes';
      case CommentSortOption.mostReplies:
        return 'replies';
    }
  }

  static CommentSortOption fromApiValue(String value) {
    switch (value) {
      case 'newest':
        return CommentSortOption.newest;
      case 'oldest':
        return CommentSortOption.oldest;
      case 'likes':
        return CommentSortOption.mostLiked;
      case 'replies':
        return CommentSortOption.mostReplies;
      default:
        return CommentSortOption.newest;
    }
  }
}

// ============================================================================
// COMMENT FILTER OPTIONS
// ============================================================================

class CommentFilterOptions {
  final bool showReplies;
  final bool showOnlyFromUser;
  final String? userId;
  final CommentSortOption sortBy;
  final int limit;
  final int page;

  const CommentFilterOptions({
    this.showReplies = true,
    this.showOnlyFromUser = false,
    this.userId,
    this.sortBy = CommentSortOption.newest,
    this.limit = 20,
    this.page = 1,
  });

  CommentFilterOptions copyWith({
    bool? showReplies,
    bool? showOnlyFromUser,
    String? userId,
    CommentSortOption? sortBy,
    int? limit,
    int? page,
  }) {
    return CommentFilterOptions(
      showReplies: showReplies ?? this.showReplies,
      showOnlyFromUser: showOnlyFromUser ?? this.showOnlyFromUser,
      userId: userId ?? this.userId,
      sortBy: sortBy ?? this.sortBy,
      limit: limit ?? this.limit,
      page: page ?? this.page,
    );
  }

  Map<String, String> toQueryParams() {
    final params = <String, String>{
      'sort': sortBy.apiValue,
      'limit': limit.toString(),
      'page': page.toString(),
    };
    if (!showReplies) {
      params['exclude_replies'] = 'true';
    }
    if (showOnlyFromUser && userId != null) {
      params['user_id'] = userId!;
    }
    return params;
  }
}