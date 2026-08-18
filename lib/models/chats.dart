class ChatMessage {
  final int id;
  final int postId;
  final String username;
  final String message;
  final String time;
  final bool isYou;
  final int userId;
  final bool seen;
  final String? profileImage;

  ChatMessage({
    required this.id,
    required this.postId,
    required this.username,
    required this.message,
    required this.time,
    required this.isYou,
    required this.userId,
    required this.seen,
    this.profileImage,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final currentUserId = 1; // Replace with actual user ID from auth
    final messageUserId = json['sender_id'] ?? json['user_id'] ?? 0;

    return ChatMessage(
      id: json['id'] ?? 0,
      postId: json['post_id'] ?? 0,
      username: json['username'] ?? json['sender_username'] ?? 'Unknown',
      message: json['message'] ?? '',
      time:
          json['created_at'] ??
          json['time'] ??
          DateTime.now().toIso8601String(),
      isYou: messageUserId == currentUserId,
      userId: messageUserId,
      seen: json['seen'] ?? false,
      profileImage: json['profile_image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'message': message,
      'sender_id': userId,
      'created_at': time,
      'seen': seen,
    };
  }

  ChatMessage copyWith({
    int? id,
    int? postId,
    String? username,
    String? message,
    String? time,
    bool? isYou,
    int? userId,
    bool? seen,
    String? profileImage,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      username: username ?? this.username,
      message: message ?? this.message,
      time: time ?? this.time,
      isYou: isYou ?? this.isYou,
      userId: userId ?? this.userId,
      seen: seen ?? this.seen,
      profileImage: profileImage ?? this.profileImage,
    );
  }
}
