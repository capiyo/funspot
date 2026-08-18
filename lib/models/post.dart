// lib/models/post.dart
class Post {
  final String id;
  final String caption;
  final String userName;
  final String userAvatar;
  final DateTime createdAt;
  final double betAmount;
  final String betOutcome;
  final double odds;
  final String imageUrl;

  Post({
    required this.id,
    required this.caption,
    required this.userName,
    required this.userAvatar,
    required this.createdAt,
    required this.betAmount,
    required this.betOutcome,
    required this.odds,
    required this.imageUrl,
  });
}