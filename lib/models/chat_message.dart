// lib/models/chat_message.dart
//
// Matches the Rust structs in models.rs:
//   - Message / MessageResponse  (channel messages)
//   - ReplyToData
//   - CreateMessageRequest       (outgoing "send message" payload)
//
// IMPORTANT: Rust's ReplyToData only renames two fields to camelCase
// (`messageId`, `isMe`) via #[serde(rename = ...)]. Everything else on
// ReplyToData — image_url, video_url, is_image, is_video — serializes as
// snake_case because there is no rename attribute on those fields. This
// file mirrors that exactly. If you fix the casing on the Rust side later,
// update ReplyData.fromJson/toJson to match.

// ============================================================================
// ENUMS
// ============================================================================

import 'package:flutter/material.dart';

enum MessageStatus {
  pending, // ⏳ Sending (clock/loading)
  sent, // ✓ Single tick (server received)
  delivered, // ✓✓ Double tick (recipient received)
  read, // ✓✓ Blue (recipient read it)
  failed // ❌ Error icon
}

// ============================================================================
// REPLY DATA - mirrors Rust's ReplyToData
// ============================================================================

class ReplyData {
  final String messageId;
  final String text;
  final String username;
  final String? selection;
  final bool isMe;
  final String? imageUrl;
  final String? videoUrl;
  final bool isImage;
  final bool isVideo;

  ReplyData({
    required this.messageId,
    required this.text,
    required this.username,
    this.selection,
    this.isMe = false,
    this.imageUrl,
    this.videoUrl,
    this.isImage = false,
    this.isVideo = false,
  });

  /// Matches Rust's ReplyToData serde output exactly:
  ///   messageId (renamed), text, username, selection, isMe (renamed),
  ///   image_url, video_url, is_image, is_video  (NOT renamed on Rust side)
  Map<String, dynamic> toJson() => {
        'messageId': messageId,
        'text': text,
        'username': username,
        'selection': selection,
        'isMe': isMe,
        'image_url': imageUrl,
        'video_url': videoUrl,
        'is_image': isImage,
        'is_video': isVideo,
      };

  factory ReplyData.fromJson(Map<String, dynamic> json) {
    return ReplyData(
      // messageId / isMe are the only two Rust actually renames to camelCase.
      messageId: json['messageId'] ?? '',
      text: json['text'] ?? '',
      username: json['username'] ?? '',
      selection: json['selection'],
      isMe: json['isMe'] ?? false,
      // These four come across as snake_case from Rust — check that first,
      // fall back to camelCase in case this is ever fixed server-side or the
      // data came from local/cached storage that used toJson() above.
      imageUrl: json['image_url'] ?? json['imageUrl'],
      videoUrl: json['video_url'] ?? json['videoUrl'],
      isImage: json['is_image'] ?? json['isImage'] ?? false,
      isVideo: json['is_video'] ?? json['isVideo'] ?? false,
    );
  }
}

// ============================================================================
// CHAT MESSAGE - MASTER CLASS (Combines both definitions)
// ============================================================================

class ChatMessage {
  // === CHAT SCREEN FIELDS ===
  final String id;
  final String? tempId; // ✅ Temporary ID for pending messages
  final bool isPending; // ✅ True = showing loading state
  final String userId;
  final String username;
  final String text;
  final String? caption;
  final String? selection;
  final DateTime timestamp;
  final MessageStatus status;
  final bool isSeen;
  final ReplyData? replyTo;
  final String? imageUrl;
  final String? imagePublicId;
  final String? imageCaption;
  final String? videoUrl;
  final String? videoPublicId;
  final String? videoThumbnailUrl;
  final String? videoCaption;
  final int? videoDuration;
  final int? videoSize;
  final bool isImage;
  final bool isVideo;
  final bool isCommentary;
  final String? commentaryType;
  final int seq;

  // === PRIVATE MESSAGE FIELDS ===
  final String? postId;
  final String? senderId;
  final String? receiverId;
  final String? senderName;
  final String? receiverName;
  final String? message;
  final DateTime? createdAt;

  // === MAIN CONSTRUCTOR ===
  ChatMessage({
    required this.id,
    this.tempId,
    this.isPending = false,
    required this.userId,
    required this.username,
    required this.text,
    this.caption,
    this.selection,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.isSeen = false,
    this.replyTo,
    this.imageUrl,
    this.imagePublicId,
    this.imageCaption,
    this.videoUrl,
    this.videoPublicId,
    this.videoThumbnailUrl,
    this.videoCaption,
    this.videoDuration,
    this.videoSize,
    this.isImage = false,
    this.isVideo = false,
    this.isCommentary = false,
    this.commentaryType,
    this.seq = 0,
    // Private message fields (optional)
    this.postId,
    this.senderId,
    this.receiverId,
    this.senderName,
    this.receiverName,
    this.message,
    this.createdAt,
  });

  // === COMMENTARY FACTORY ===
  // === COMMENTARY FACTORY ===
  factory ChatMessage.commentary({
    required int minute,
    required String text,
    required String type,
    required DateTime createdAt,
    int seq = 0,
  }) {
    // ✅ Old id: 'commentary_${createdAt.millisecondsSinceEpoch}_$minute'
    // This collides whenever two commentary entries share the same
    // createdAt millisecond AND minute (e.g. a bulk/backfill push where
    // multiple entries get stamped with the same server timestamp, or a
    // minute that gets two distinct events). A collision means
    // `_messages.any((m) => m.id == entry.id)` in ChatScreen silently
    // drops the newer one, so it never renders while the chat screen is
    // open — it only shows up after a fresh HTTP refetch (e.g. leaving
    // and reopening the screen), which rebuilds the whole list from a
    // clean snapshot instead of relying on incremental WS inserts.
    //
    // Fix: fold `type` and a hash of `text` into the id too, so two
    // entries can only collide if they are identical in every field.
    final uniqueId =
        'commentary_${createdAt.millisecondsSinceEpoch}_${minute}_${type}_${text.hashCode}';

    return ChatMessage(
      id: uniqueId,
      userId: '__commentary__',
      username: "Live Commentary • $minute'",
      text: text,
      timestamp: createdAt,
      status: MessageStatus.delivered,
      isCommentary: true,
      commentaryType: type,
      seq: seq,
    );
  }

  // === FROM JSON - Handles both channel (Rust MessageResponse) and private formats ===
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Parse timestamp - handle multiple formats.
    //
    // NOTE: Rust's `sent_at: msg.sent_at.to_string()` on bson::DateTime is
    // NOT guaranteed to produce a strict RFC3339 string that DateTime.tryParse
    // accepts on every bson-rust version. If messages are silently showing
    // "now" as their timestamp, verify what sent_at actually looks like on
    // the wire and switch the Rust side to an explicit
    // `.try_to_rfc3339_string()` (or `.to_chrono().to_rfc3339()`) call.
    DateTime parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } else if (value is Map) {
        // Handle MongoDB extended-JSON date format
        final dateObj = value['\$date'];
        if (dateObj is Map && dateObj['\$numberLong'] != null) {
          final milliseconds = int.parse(dateObj['\$numberLong'].toString());
          return DateTime.fromMillisecondsSinceEpoch(milliseconds);
        }
        if (dateObj is String) {
          return DateTime.tryParse(dateObj) ?? DateTime.now();
        }
      }
      return DateTime.now();
    }

    // Parse reply data.
    // Rust does NOT rename `reply_to` -> `replyTo`; it serializes as
    // "reply_to". Check that first; keep "replyTo" as a fallback for any
    // locally-cached data written by this file's own toJson().
    ReplyData? replyTo;
    final rawReply = json['reply_to'] ?? json['replyTo'];
    if (rawReply != null && rawReply is Map) {
      replyTo = ReplyData.fromJson(rawReply as Map<String, dynamic>);
    }

    // Determine if this is a channel message or private message
    final isChannelMessage = json.containsKey('userId') ||
        json.containsKey('username') ||
        json.containsKey('sender_name') ||
        json.containsKey('channel_id');

    if (isChannelMessage) {
      // Channel message format (Rust MessageResponse is all snake_case
      // except _id -> id, and reply_to/reply_to_id).
      final id =
          json['id'] ?? json['message_id'] ?? json['_id']?.toString() ?? '';

      final userId =
          json['userId'] ?? json['sender_id'] ?? json['user_id'] ?? '';

      final username = json['username'] ??
          json['sender_name'] ??
          json['user_name'] ??
          'Anonymous';

      final text = json['text'] ?? json['message'] ?? '';

      final timestamp = parseTimestamp(json['sent_at'] ??
          json['timestamp'] ??
          json['sent_at'] ??
          json['createdAt']);

      final bool isCommentary = json['isCommentary'] == true ||
          json['is_commentary'] == true ||
          username.toString().contains('Commentary') ||
          (json['commentaryType'] != null) ||
          (json['commentary_type'] != null);

      // ✅ Parse tempId from server response
      final tempId = json['temp_id'] ?? json['tempId'];

      // ✅ Parse isPending from server (or default to false for confirmed messages)
      final isPending = json['isPending'] ?? false;

      return ChatMessage(
        id: id,
        tempId: tempId,
        isPending: isPending,
        userId: userId,
        username: username,
        text: text,
        caption: json['caption'],
        selection: json['selection'] ?? json['user_vote'],
        timestamp: timestamp,
        status: json['status'] != null
            ? MessageStatus.values[json['status']]
            : MessageStatus.sent,
        isSeen: json['isSeen'] ?? json['seen'] ?? false,
        isCommentary: isCommentary,
        commentaryType: json['commentaryType'] ?? json['commentary_type'],
        replyTo: replyTo,
        imageUrl: json['imageUrl'] ?? json['image_url'],
        imagePublicId: json['imagePublicId'] ?? json['image_public_id'],
        imageCaption: json['imageCaption'] ?? json['image_caption'],
        videoUrl: json['videoUrl'] ?? json['video_url'],
        videoPublicId: json['videoPublicId'] ?? json['video_public_id'],
        videoThumbnailUrl:
            json['videoThumbnailUrl'] ?? json['video_thumbnail_url'],
        videoCaption: json['videoCaption'] ?? json['video_caption'],
        videoDuration: json['videoDuration'] ?? json['video_duration'],
        videoSize: json['videoSize'] ?? json['video_size'],
        isImage: json['isImage'] ?? json['is_image'] ?? false,
        isVideo: json['isVideo'] ?? json['is_video'] ?? false,
        seq: json['seq'] ?? 0,
        // Private message fields
        postId: json['postId'] ?? json['post_id'],
        senderId: json['senderId'] ?? json['sender_id'],
        receiverId: json['receiverId'] ?? json['receiver_id'],
        senderName: json['senderName'] ?? json['sender_name'],
        receiverName: json['receiverName'] ?? json['receiver_name'],
        message: text,
        createdAt: timestamp,
      );
    } else {
      // Private message format
      final id = json['id']?.toString() ?? json['_id']?.toString() ?? '';
      final postId =
          json['postId']?.toString() ?? json['post_id']?.toString() ?? '';
      final senderId =
          json['senderId']?.toString() ?? json['sender_id']?.toString() ?? '';
      final receiverId = json['receiverId']?.toString() ??
          json['receiver_id']?.toString() ??
          '';
      final senderName = json['senderName']?.toString() ??
          json['sender_name']?.toString() ??
          'Unknown';
      final receiverName = json['receiverName']?.toString() ??
          json['receiver_name']?.toString() ??
          'Unknown';
      final messageText = json['message']?.toString() ?? '';
      final seen = json['seen'] is bool
          ? json['seen']
          : (json['seen']?.toString() == 'true');
      final createdAt = parseTimestamp(json['createdAt'] ?? json['created_at']);

      return ChatMessage(
        id: id,
        userId: senderId,
        username: senderName,
        text: messageText,
        timestamp: createdAt,
        status: seen ? MessageStatus.read : MessageStatus.delivered,
        isSeen: seen,
        postId: postId,
        senderId: senderId,
        receiverId: receiverId,
        senderName: senderName,
        receiverName: receiverName,
        message: messageText,
        createdAt: createdAt,
      );
    }
  }

  // === TO JSON (local/display representation — camelCase) ===
  //
  // This is NOT the shape the Rust API expects for sending a new message.
  // Use toCreateRequestJson() for that (see below), which matches
  // CreateMessageRequest field-for-field.
  Map<String, dynamic> toJson() {
    final base = {
      'id': id,
      'tempId': tempId,
      'isPending': isPending,
      'userId': userId,
      'username': username,
      'text': text,
      'caption': caption,
      'selection': selection,
      'timestamp': timestamp.toIso8601String(),
      'status': status.index,
      'isSeen': isSeen,
      'isCommentary': isCommentary,
      'commentaryType': commentaryType,
      'replyTo': replyTo?.toJson(),
      'imageUrl': imageUrl,
      'imagePublicId': imagePublicId,
      'imageCaption': imageCaption,
      'videoUrl': videoUrl,
      'videoPublicId': videoPublicId,
      'videoThumbnailUrl': videoThumbnailUrl,
      'videoCaption': videoCaption,
      'videoDuration': videoDuration,
      'videoSize': videoSize,
      'isImage': isImage,
      'isVideo': isVideo,
      'seq': seq,
    };

    // Add private message fields if they exist
    if (postId != null) base['postId'] = postId;
    if (senderId != null) base['senderId'] = senderId;
    if (receiverId != null) base['receiverId'] = receiverId;
    if (senderName != null) base['senderName'] = senderName;
    if (receiverName != null) base['receiverName'] = receiverName;
    if (message != null) base['message'] = message;
    if (createdAt != null) base['createdAt'] = createdAt!.toIso8601String();

    return base;
  }

  /// Builds the exact JSON shape Rust's `CreateMessageRequest` expects
  /// (all snake_case) for sending a new message to the channel endpoint.
  ///
  /// [fixtureId] and reply fields are optional passthroughs since ChatMessage
  /// itself doesn't always carry a fixture_id.
  Map<String, dynamic> toCreateRequestJson({String? fixtureId}) {
    final map = <String, dynamic>{
      'user_id': userId,
      'username': username,
      'text': text,
    };
    if (fixtureId != null) map['fixture_id'] = fixtureId;
    if (selection != null) map['selection'] = selection;
    if (caption != null) map['caption'] = caption;
    if (imageUrl != null) map['image_url'] = imageUrl;
    if (imagePublicId != null) map['image_public_id'] = imagePublicId;
    if (imageCaption != null) map['image_caption'] = imageCaption;
    map['is_image'] = isImage;
    if (videoUrl != null) map['video_url'] = videoUrl;
    if (videoPublicId != null) map['video_public_id'] = videoPublicId;
    if (videoThumbnailUrl != null) {
      map['video_thumbnail_url'] = videoThumbnailUrl;
    }
    if (videoCaption != null) map['video_caption'] = videoCaption;
    if (videoDuration != null) map['video_duration'] = videoDuration;
    if (videoSize != null) map['video_size'] = videoSize;
    map['is_video'] = isVideo;

    // ✅ Include temp_id for pending message tracking
    if (tempId != null && tempId!.isNotEmpty) {
      map['temp_id'] = tempId;
    }

    if (replyTo != null) {
      map['reply_to_id'] = replyTo!.messageId;
      map['reply_to_text'] = replyTo!.text;
      map['reply_to_username'] = replyTo!.username;
      if (replyTo!.selection != null) {
        map['reply_to_selection'] = replyTo!.selection;
      }
    }
    return map;
  }

  // === HELPER METHODS ===

  /// Check if message is from current user
  bool isFromUser(String currentUserId) {
    return userId == currentUserId || senderId == currentUserId;
  }

  /// Check if message is for current user
  bool isForUser(String currentUserId) {
    return receiverId == currentUserId;
  }

  /// Check if it's a commentary message
  bool isCommentaryMessage() => isCommentary;

  /// Check if it's an image message
  bool isImageMessage() => isImage;

  /// Check if it's a video message
  bool isVideoMessage() => isVideo;

  /// Check if it has any media (image or video)
  bool hasMedia() => isImage || isVideo;

  /// Check if it has a video thumbnail
  bool hasVideoThumbnail() =>
      isVideo && videoThumbnailUrl != null && videoThumbnailUrl!.isNotEmpty;

  /// ✅ Get status icon for display
  String get statusIcon {
    if (isPending) return '⏳';
    switch (status) {
      case MessageStatus.pending:
        return '⏳';
      case MessageStatus.sent:
        return '✓';
      case MessageStatus.delivered:
        return '✓✓';
      case MessageStatus.read:
        return '✓✓';
      case MessageStatus.failed:
        return '❌';
    }
  }

  /// ✅ Get status color for display
  Color? get statusColor {
    if (isPending) return Colors.orange;
    switch (status) {
      case MessageStatus.pending:
        return Colors.orange;
      case MessageStatus.sent:
        return Colors.grey;
      case MessageStatus.delivered:
        return Colors.grey;
      case MessageStatus.read:
        return Colors.blue;
      case MessageStatus.failed:
        return Colors.red;
    }
  }

  /// Format time for display
  String get formattedTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    if (messageDate.isAtSameMomentAs(today)) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Get display name
  String get displayName {
    if (isCommentary) return username;
    return username.isNotEmpty ? username : (senderName ?? 'Unknown');
  }

  /// Get sender ID
  String get senderIdValue => senderId ?? userId;

  /// Check if it's a private message
  bool get isPrivateMessage => postId != null && postId!.isNotEmpty;

  /// Get message text (alias)
  String get messageText => text;

  /// ✅ Copy with updates - includes tempId and isPending
  ChatMessage copyWith({
    String? id,
    String? tempId,
    bool? isPending,
    MessageStatus? status,
    String? userId,
    String? username,
    String? text,
    String? selection,
    DateTime? timestamp,
    bool? isSeen,
    bool? isCommentary,
    String? commentaryType,
    ReplyData? replyTo,
    String? imageUrl,
    String? videoUrl,
    String? videoThumbnailUrl,
    bool? isImage,
    bool? isVideo,
    int? seq,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      tempId: tempId ?? this.tempId,
      isPending: isPending ?? this.isPending,
      status: status ?? this.status,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      text: text ?? this.text,
      selection: selection ?? this.selection,
      timestamp: timestamp ?? this.timestamp,
      isSeen: isSeen ?? this.isSeen,
      isCommentary: isCommentary ?? this.isCommentary,
      commentaryType: commentaryType ?? this.commentaryType,
      replyTo: replyTo ?? this.replyTo,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      videoThumbnailUrl: videoThumbnailUrl ?? this.videoThumbnailUrl,
      isImage: isImage ?? this.isImage,
      isVideo: isVideo ?? this.isVideo,
      seq: seq ?? this.seq,
    );
  }

  /// ✅ Create a pending message with tempId
  factory ChatMessage.pending({
    required String tempId,
    required String userId,
    required String username,
    required String text,
    String? selection,
    String? imageUrl,
    String? videoUrl,
    String? videoThumbnailUrl,
    bool isImage = false,
    bool isVideo = false,
    ReplyData? replyTo,
    DateTime? timestamp,
    String? caption,
  }) {
    return ChatMessage(
      id: tempId,
      tempId: tempId,
      isPending: true,
      userId: userId,
      username: username,
      text: text,
      caption: caption,
      selection: selection,
      timestamp: timestamp ?? DateTime.now(),
      status: MessageStatus.pending,
      replyTo: replyTo,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      videoThumbnailUrl: videoThumbnailUrl,
      isImage: isImage,
      isVideo: isVideo,
    );
  }
}
