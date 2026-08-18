class Post {
  final String? id;
  final String? userId;
  final String? userName;

  // ✅ CAPTION FIELDS
  final String? caption; // Main caption/text content
  final String? imageCaption; // Caption specifically for image
  final String? videoCaption; // Caption specifically for video

  // Image fields (Cloudinary)
  final String? imageUrl;
  final String? cloudinaryPublicId;
  final String? imageFormat;

  // ✅ Firebase Image fields (for backup/storage)
  final String? firebaseImageUrl;
  final String? firebaseImagePublicId;

  // ✅ Video fields (Firebase Storage)
  final String? videoUrl;
  final String? videoThumbnailUrl;
  final int? videoDuration;
  final int? videoSize;
  final String? firebasePublicId;

  // Post metadata
  final String? postType;
  final int? likesCount;
  final int? commentsCount;
  final int? sharesCount;
  final List<dynamic>? likedBy;
  final bool? isSaved;
  final int? timestamp;
  final String? createdAt;
  final String? updatedAt;
  final String? lastModified;

  Post({
    this.id,
    this.userId,
    this.userName,
    // ✅ Caption fields
    this.caption,
    this.imageCaption,
    this.videoCaption,
    // Image fields
    this.imageUrl,
    this.cloudinaryPublicId,
    this.imageFormat,
    // ✅ Firebase Image fields
    this.firebaseImageUrl,
    this.firebaseImagePublicId,
    // ✅ Video fields
    this.videoUrl,
    this.videoThumbnailUrl,
    this.videoDuration,
    this.videoSize,
    this.firebasePublicId,
    this.postType,
    this.likesCount,
    this.commentsCount,
    this.sharesCount,
    this.likedBy,
    this.isSaved,
    this.timestamp,
    this.createdAt,
    this.updatedAt,
    this.lastModified,
  });

  // ✅ Helper methods
  bool hasVideo() => videoUrl != null && videoUrl!.isNotEmpty;
  bool hasImage() => imageUrl != null && imageUrl!.isNotEmpty;
  bool hasCaption() => caption != null && caption!.isNotEmpty;
  // ✅ Add this helper method
  bool hasVideoThumbnail() =>
      videoThumbnailUrl != null && videoThumbnailUrl!.isNotEmpty;
  bool hasImageCaption() => imageCaption != null && imageCaption!.isNotEmpty;
  bool hasVideoCaption() => videoCaption != null && videoCaption!.isNotEmpty;
  bool hasFirebaseImage() =>
      firebaseImageUrl != null && firebaseImageUrl!.isNotEmpty;

  // ✅ Get the best available caption
  String get displayCaption {
    if (caption != null && caption!.isNotEmpty) return caption!;
    if (imageCaption != null && imageCaption!.isNotEmpty) return imageCaption!;
    if (videoCaption != null && videoCaption!.isNotEmpty) return videoCaption!;
    return '';
  }

  // ✅ Get caption based on media type
  String? getCaptionForMedia({bool isImage = false, bool isVideo = false}) {
    if (isImage && imageCaption != null && imageCaption!.isNotEmpty) {
      return imageCaption;
    }
    if (isVideo && videoCaption != null && videoCaption!.isNotEmpty) {
      return videoCaption;
    }
    return caption;
  }

  // ✅ Get the best available image URL (prefer Cloudinary, fallback to Firebase)
  String? get bestImageUrl => imageUrl ?? firebaseImageUrl;

  // ✅ Get the best available video URL
  String? get bestVideoUrl => videoUrl;

  // ✅ Get post type display name
  String get postTypeDisplay {
    switch (postType?.toLowerCase()) {
      case 'text':
        return '📝 Text';
      case 'image':
        return '🖼️ Image';
      case 'video':
        return '🎬 Video';
      case 'text_and_image':
        return '📝🖼️ Text & Image';
      case 'text_and_video':
        return '📝🎬 Text & Video';
      default:
        return '📝 Post';
    }
  }

  bool isLikedBy(String userId) {
    if (likedBy == null) return false;
    return likedBy!.any((element) => element == userId);
  }

  String get formattedDate {
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt!);
        final now = DateTime.now();
        final diff = now.difference(date);

        if (diff.inDays > 7) {
          return '${diff.inDays ~/ 7}w ago';
        } else if (diff.inDays > 0) {
          return '${diff.inDays}d ago';
        } else if (diff.inHours > 0) {
          return '${diff.inHours}h ago';
        } else if (diff.inMinutes > 0) {
          return '${diff.inMinutes}m ago';
        } else {
          return 'Just now';
        }
      } catch (_) {
        return '';
      }
    }
    return '';
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      userId: json['user_id']?.toString(),
      userName: json['user_name']?.toString(),

      // ✅ Caption fields
      caption: json['caption']?.toString(),
      imageCaption: json['image_caption']?.toString(),
      videoCaption: json['video_caption']?.toString(),

      // Image fields
      imageUrl: json['image_url']?.toString(),
      cloudinaryPublicId: json['cloudinary_public_id']?.toString(),
      imageFormat: json['image_format']?.toString(),

      // ✅ Firebase Image fields
      firebaseImageUrl: json['firebase_image_url']?.toString(),
      firebaseImagePublicId: json['firebase_image_public_id']?.toString(),

      // ✅ Video fields
      videoUrl: json['video_url']?.toString(),
      videoThumbnailUrl: json['video_thumbnail_url']?.toString(),
      videoDuration: json['video_duration'] is int
          ? json['video_duration']
          : json['video_duration']?.toInt(),
      videoSize: json['video_size'] is int
          ? json['video_size']
          : json['video_size']?.toInt(),
      firebasePublicId: json['firebase_public_id']?.toString(),

      postType: json['post_type']?.toString(),
      likesCount: json['likes_count'] is int
          ? json['likes_count']
          : json['likes_count']?.toInt(),
      commentsCount: json['comments_count'] is int
          ? json['comments_count']
          : json['comments_count']?.toInt(),
      sharesCount: json['shares_count'] is int
          ? json['shares_count']
          : json['shares_count']?.toInt(),
      likedBy: json['liked_by'] as List?,
      isSaved: json['is_saved'] == true,
      timestamp: json['timestamp'] is int
          ? json['timestamp']
          : json['timestamp']?.toInt(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      lastModified: json['last_modified']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,

      // ✅ Caption fields
      'caption': caption,
      'image_caption': imageCaption,
      'video_caption': videoCaption,

      // Image fields
      'image_url': imageUrl,
      'cloudinary_public_id': cloudinaryPublicId,
      'image_format': imageFormat,

      // ✅ Firebase Image fields
      'firebase_image_url': firebaseImageUrl,
      'firebase_image_public_id': firebaseImagePublicId,

      // ✅ Video fields
      'video_url': videoUrl,
      'video_thumbnail_url': videoThumbnailUrl,
      'video_duration': videoDuration,
      'video_size': videoSize,
      'firebase_public_id': firebasePublicId,

      'post_type': postType,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'shares_count': sharesCount,
      'liked_by': likedBy,
      'is_saved': isSaved,
      'timestamp': timestamp,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_modified': lastModified,
    };
  }

  // ✅ Create a copy with updated fields
  Post copyWith({
    String? id,
    String? userId,
    String? userName,
    String? caption,
    String? imageCaption,
    String? videoCaption,
    String? imageUrl,
    String? cloudinaryPublicId,
    String? imageFormat,
    String? firebaseImageUrl,
    String? firebaseImagePublicId,
    String? videoUrl,
    String? videoThumbnailUrl,
    int? videoDuration,
    int? videoSize,
    String? firebasePublicId,
    String? postType,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    List<dynamic>? likedBy,
    bool? isSaved,
    int? timestamp,
    String? createdAt,
    String? updatedAt,
    String? lastModified,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      caption: caption ?? this.caption,
      imageCaption: imageCaption ?? this.imageCaption,
      videoCaption: videoCaption ?? this.videoCaption,
      imageUrl: imageUrl ?? this.imageUrl,
      cloudinaryPublicId: cloudinaryPublicId ?? this.cloudinaryPublicId,
      imageFormat: imageFormat ?? this.imageFormat,
      firebaseImageUrl: firebaseImageUrl ?? this.firebaseImageUrl,
      firebaseImagePublicId:
          firebaseImagePublicId ?? this.firebaseImagePublicId,
      videoUrl: videoUrl ?? this.videoUrl,
      videoThumbnailUrl: videoThumbnailUrl ?? this.videoThumbnailUrl,
      videoDuration: videoDuration ?? this.videoDuration,
      videoSize: videoSize ?? this.videoSize,
      firebasePublicId: firebasePublicId ?? this.firebasePublicId,
      postType: postType ?? this.postType,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      likedBy: likedBy ?? this.likedBy,
      isSaved: isSaved ?? this.isSaved,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}
