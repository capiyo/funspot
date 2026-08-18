// lib/models/chat_message.dart
import 'package:flutter/material.dart';

enum MessageStatus { sending, sent, delivered, read, failed }

class ReplyData {
  final String messageId;
  final String text;
  final String username;
  final String? selection;
  final bool isMe;

  ReplyData({
    required this.messageId,
    required this.text,
    required this.username,
    this.selection,
    this.isMe = false,
  });

  Map<String, dynamic> toJson() => {
        'messageId': messageId,
        'text': text,
        'username': username,
        'selection': selection,
        'isMe': isMe,
      };

  factory ReplyData.fromJson(Map<String, dynamic> json) {
    return ReplyData(
      messageId: json['messageId'] ?? '',
      text: json['text'] ?? '',
      username: json['username'] ?? '',
      selection: json['selection'],
      isMe: json['isMe'] ?? false,
    );
  }
}

class ChatMessage {
  // === CHAT SCREEN FIELDS ===
  final String id;
  final String userId;
  final String username;
  final String text;
  final String? selection;
  final DateTime timestamp;
  final MessageStatus status;
  final bool isSeen;
  final ReplyData? replyTo;
  final String? imageUrl;
  final String? videoUrl;
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
    required this.userId,
    required this.username,
    required this.text,
    this.selection,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.isSeen = false,
    this.replyTo,
    this.imageUrl,
    this.videoUrl,
    this.isImage = false,
    this.isVideo = false,
    this.isCommentary = false,
    this.commentaryType,
    this.seq = 0,
    // Private message fields
    this.postId,
    this.senderId,
    this.receiverId,
    this.senderName,
    this.receiverName,
    this.message,
    this.createdAt,
  });

  // === COMMENTARY FACTORY ===
  factory ChatMessage.commentary({
    required int minute,
    required String text,
    required String type,
    required DateTime createdAt,
    int seq = 0,
  }) {
    return ChatMessage(
      id: 'commentary_${createdAt.millisecondsSinceEpoch}_$minute',
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

  // === PRIVATE MESSAGE FACTORY ===
  factory ChatMessage.private({
    required String id,
    required String postId,
    required String senderId,
    required String receiverId,
    required String senderName,
    required String receiverName,
    required String message,
    required DateTime createdAt,
    bool seen = false,
  }) {
    return ChatMessage(
      id: id,
      userId: senderId,
      username: senderName,
      text: message,
      timestamp: createdAt,
      status: seen ? MessageStatus.read : MessageStatus.delivered,
      isSeen: seen,
      postId: postId,
      senderId: senderId,
      receiverId: receiverId,
      senderName: senderName,
      receiverName: receiverName,
      message: message,
      createdAt: createdAt,
    );
  }

  // === FROM JSON - Handles both formats ===
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Parse timestamp - handle multiple formats
    DateTime parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } else if (value is Map) {
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

    // Parse reply data
    ReplyData? replyTo;
    if (json['replyTo'] != null && json['replyTo'] is Map) {
      replyTo = ReplyData.fromJson(json['replyTo'] as Map<String, dynamic>);
    }

    // Check if this is a private message
    final isPrivateMessage = json.containsKey('sender_id') ||
        json.containsKey('receiver_id') ||
        json.containsKey('post_id');

    if (isPrivateMessage) {
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
      final messageText =
          json['message']?.toString() ?? json['text']?.toString() ?? '';
      final seen = json['seen'] is bool
          ? json['seen']
          : (json['seen']?.toString() == 'true');
      final createdAt = parseTimestamp(
          json['createdAt'] ?? json['created_at'] ?? json['timestamp']);

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
    } else {
      // Channel message format
      final id =
          json['id'] ?? json['message_id'] ?? json['_id']?.toString() ?? '';

      final userId =
          json['userId'] ?? json['sender_id'] ?? json['user_id'] ?? '';

      final username = json['username'] ??
          json['sender_name'] ??
          json['user_name'] ??
          'Anonymous';

      final text = json['text'] ?? json['message'] ?? '';

      final timestamp = parseTimestamp(
          json['timestamp'] ?? json['sent_at'] ?? json['createdAt']);

      final bool isCommentary = json['isCommentary'] == true ||
          json['is_commentary'] == true ||
          username.toString().contains('Commentary') ||
          (json['commentary_type'] != null);

      return ChatMessage(
        id: id,
        userId: userId,
        username: username,
        text: text,
        selection: json['selection'] ?? json['user_vote'],
        timestamp: timestamp,
        status: MessageStatus.values[json['status'] ?? 1],
        isSeen: json['isSeen'] ?? json['seen'] ?? false,
        isCommentary: isCommentary,
        commentaryType: json['commentaryType'] ?? json['commentary_type'],
        replyTo: replyTo,
        imageUrl: json['imageUrl'] ?? json['image_url'],
        videoUrl: json['videoUrl'] ?? json['video_url'],
        isImage: json['isImage'] ?? json['is_image'] ?? false,
        isVideo: json['isVideo'] ?? json['is_video'] ?? false,
        seq: json['seq'] ?? 0,
      );
    }
  }

  // === TO JSON ===
  Map<String, dynamic> toJson() {
    final base = {
      'id': id,
      'userId': userId,
      'username': username,
      'text': text,
      'selection': selection,
      'timestamp': timestamp.toIso8601String(),
      'status': status.index,
      'isSeen': isSeen,
      'isCommentary': isCommentary,
      'commentaryType': commentaryType,
      'replyTo': replyTo?.toJson(),
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
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

  // === HELPER METHODS ===

  bool isFromUser(String currentUserId) {
    return userId == currentUserId || senderId == currentUserId;
  }

  bool isForUser(String currentUserId) {
    return receiverId == currentUserId;
  }

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

  String get displayName {
    if (isCommentary) return username;
    return username.isNotEmpty ? username : (senderName ?? 'Unknown');
  }

  String get senderIdValue => senderId ?? userId;

  bool get isPrivateMessage => postId != null && postId!.isNotEmpty;

  String get messageText => text;
}
