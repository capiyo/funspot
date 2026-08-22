import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'api_services.dart';
import 'notification_service.dart';

enum UploadStatus { uploading, success, failed }

enum UploadType { post, chatImage, chatVideo }

class UploadTask {
  final String id;
  final String userId;
  final String userName;
  final String? caption;

  // Bytes-based media (works on web + mobile)
  final Uint8List? imageBytes;
  final String? imageName;
  final Uint8List? videoBytes;
  final String? videoName;
  final Uint8List? videoThumbnailBytes;
  final String? videoThumbnailName;

  final UploadType uploadType;
  final String? channelId;
  final String? fixtureId;
  final String? tempId;
  double progress;
  UploadStatus status;
  String? error;
  String? resultUrl;
  String? thumbnailUrl;

  UploadTask({
    required this.id,
    required this.userId,
    required this.userName,
    this.caption,
    this.imageBytes,
    this.imageName,
    this.videoBytes,
    this.videoName,
    this.videoThumbnailBytes,
    this.videoThumbnailName,
    this.uploadType = UploadType.post,
    this.channelId,
    this.fixtureId,
    this.tempId,
    this.progress = 0.0,
    this.status = UploadStatus.uploading,
    this.error,
    this.resultUrl,
    this.thumbnailUrl,
  });

  bool get isChatUpload => uploadType != UploadType.post;
  bool get hasMedia => imageBytes != null || videoBytes != null;
}

class UploadQueueService extends ChangeNotifier {
  UploadQueueService._internal();
  static final UploadQueueService _instance = UploadQueueService._internal();
  factory UploadQueueService() => _instance;

  final List<UploadTask> _tasks = [];
  List<UploadTask> get tasks => List.unmodifiable(_tasks);

  final List<VoidCallback> _onPostCreatedListeners = [];
  final List<void Function(String url, String? thumbnail)>
      _onChatMediaUploadedListeners = [];

  void addOnPostCreatedListener(VoidCallback cb) =>
      _onPostCreatedListeners.add(cb);
  void removeOnPostCreatedListener(VoidCallback cb) =>
      _onPostCreatedListeners.remove(cb);

  void addOnChatMediaUploadedListener(
          void Function(String url, String? thumbnail) cb) =>
      _onChatMediaUploadedListeners.add(cb);
  void removeOnChatMediaUploadedListener(
          void Function(String url, String? thumbnail) cb) =>
      _onChatMediaUploadedListeners.remove(cb);

  // ==========================================================================
  // POST UPLOAD
  // ==========================================================================

  String enqueuePost({
    required String userId,
    required String userName,
    String? caption,
    Uint8List? imageBytes,
    String? imageName,
    Uint8List? videoBytes,
    String? videoName,
    Uint8List? videoThumbnailBytes,
    String? videoThumbnailName,
  }) {
    final id = 'post_${DateTime.now().millisecondsSinceEpoch}_$userId';
    final task = UploadTask(
      id: id,
      userId: userId,
      userName: userName,
      caption: caption,
      imageBytes: imageBytes,
      imageName: imageName,
      videoBytes: videoBytes,
      videoName: videoName,
      videoThumbnailBytes: videoThumbnailBytes,
      videoThumbnailName: videoThumbnailName,
      uploadType: UploadType.post,
    );
    _tasks.add(task);
    notifyListeners();

    _runUpload(task);

    return id;
  }

  // ==========================================================================
  // CHAT MEDIA UPLOADS
  // ==========================================================================

  String enqueueChatImage({
    required String userId,
    required String userName,
    required Uint8List imageBytes,
    required String imageName,
    String? caption,
    String? channelId,
    String? fixtureId,
    String? tempId,
    String? authToken,
    required void Function(String url) onSuccess,
  }) {
    final id = 'chat_img_${DateTime.now().millisecondsSinceEpoch}_$userId';
    final task = UploadTask(
      id: id,
      userId: userId,
      userName: userName,
      imageBytes: imageBytes,
      imageName: imageName,
      caption: caption,
      uploadType: UploadType.chatImage,
      channelId: channelId,
      fixtureId: fixtureId,
      tempId: tempId,
    );
    _tasks.add(task);
    notifyListeners();

    _runChatImageUpload(task, authToken, onSuccess);

    return id;
  }

  String enqueueChatVideo({
    required String userId,
    required String userName,
    required Uint8List videoBytes,
    required String videoName,
    required Uint8List thumbnailBytes,
    required String thumbnailName,
    String? caption,
    String? channelId,
    String? fixtureId,
    String? tempId,
    String? authToken,
    required void Function(String url, String thumbnail) onSuccess,
  }) {
    final id = 'chat_vid_${DateTime.now().millisecondsSinceEpoch}_$userId';
    final task = UploadTask(
      id: id,
      userId: userId,
      userName: userName,
      videoBytes: videoBytes,
      videoName: videoName,
      videoThumbnailBytes: thumbnailBytes,
      videoThumbnailName: thumbnailName,
      caption: caption,
      uploadType: UploadType.chatVideo,
      channelId: channelId,
      fixtureId: fixtureId,
      tempId: tempId,
    );
    _tasks.add(task);
    notifyListeners();

    _runChatVideoUpload(task, authToken, onSuccess);

    return id;
  }

  // ==========================================================================
  // BACKGROUND UPLOAD EXECUTION
  // ==========================================================================

  Future<void> _runUpload(UploadTask task) async {
    try {
      final Map<String, dynamic> postData;

      if (task.videoBytes != null) {
        // NOTE: background_downloader (native OS upload session) has no
        // web equivalent — browsers don't expose that concept. Route web
        // through the same bytes-based Dio path used for images; keep the
        // native background path for mobile so long uploads survive
        // backgrounding there.
        if (kIsWeb) {
          postData = await ApiService.createPostWithVideoBytes(
            userId: task.userId,
            userName: task.userName,
            caption: task.caption,
            videoBytes: task.videoBytes!,
            videoName: task.videoName ?? 'video.mp4',
            videoThumbnailBytes: task.videoThumbnailBytes,
            videoThumbnailName: task.videoThumbnailName,
            onSendProgress: (sent, total) {
              if (total > 0) {
                task.progress = sent / total;
                notifyListeners();
              }
            },
          );
        } else {
          postData = await ApiService.createPostWithBackgroundVideo(
            userId: task.userId,
            userName: task.userName,
            caption: task.caption,
            videoBytes: task.videoBytes!,
            videoName: task.videoName ?? 'video.mp4',
            videoThumbnailBytes: task.videoThumbnailBytes,
            videoThumbnailName: task.videoThumbnailName,
            onProgress: (progress) {
              task.progress = progress;
              notifyListeners();
            },
          );
        }
      } else {
        postData = await ApiService.createPost(
          userId: task.userId,
          userName: task.userName,
          caption: task.caption,
          imageBytes: task.imageBytes,
          imageName: task.imageName,
          onSendProgress: (sent, total) {
            if (total > 0) {
              task.progress = sent / total;
              notifyListeners();
            }
          },
        );
      }

      task.status = UploadStatus.success;
      task.progress = 1.0;
      notifyListeners();

      for (final cb in List<VoidCallback>.from(_onPostCreatedListeners)) {
        cb();
      }

      final String? postId = postData['post_id']?.toString() ??
          postData['id']?.toString() ??
          postData['_id']?.toString();

      if (postId != null && postId.isNotEmpty) {
        _sendNewPostNotification(
          postId: postId,
          userId: task.userId,
          userName: task.userName,
          caption: task.caption ?? '',
          hasImage: task.imageBytes != null,
          hasVideo: task.videoBytes != null,
        );
      }

      Future.delayed(const Duration(seconds: 3), () {
        _tasks.removeWhere((t) => t.id == task.id);
        notifyListeners();
      });
    } catch (e) {
      task.status = UploadStatus.failed;
      task.error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      debugPrint('❌ Background post upload failed: ${task.error}');
    }
  }

  Future<void> _runChatImageUpload(
    UploadTask task,
    String? authToken,
    void Function(String url) onSuccess,
  ) async {
    try {
      final imageUrl = await ApiService.uploadChatImage(
        imageBytes: task.imageBytes!,
        imageName: task.imageName ?? 'image.jpg',
        userId: task.userId,
        authToken: authToken,
        caption: task.caption,
      );

      if (imageUrl != null) {
        task.status = UploadStatus.success;
        task.progress = 1.0;
        task.resultUrl = imageUrl;
        notifyListeners();

        for (final cb in _onChatMediaUploadedListeners) {
          cb(imageUrl, null);
        }

        onSuccess(imageUrl);

        Future.delayed(const Duration(seconds: 3), () {
          _tasks.removeWhere((t) => t.id == task.id);
          notifyListeners();
        });
      } else {
        task.status = UploadStatus.failed;
        task.error = 'Failed to upload image';
        notifyListeners();
        debugPrint('❌ Background chat image upload failed');
      }
    } catch (e) {
      task.status = UploadStatus.failed;
      task.error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      debugPrint('❌ Background chat image upload error: ${task.error}');
    }
  }

  Future<void> _runChatVideoUpload(
    UploadTask task,
    String? authToken,
    void Function(String url, String thumbnail) onSuccess,
  ) async {
    try {
      final result = kIsWeb
          ? await ApiService.uploadChatVideoWithThumbnailBytes(
              videoBytes: task.videoBytes!,
              videoName: task.videoName ?? 'video.mp4',
              thumbnailBytes: task.videoThumbnailBytes!,
              thumbnailName: task.videoThumbnailName ?? 'thumb.jpg',
              userId: task.userId,
              authToken: authToken,
              caption: task.caption,
            )
          : await ApiService.uploadChatVideoWithThumbnailBackground(
              videoBytes: task.videoBytes!,
              videoName: task.videoName ?? 'video.mp4',
              thumbnailBytes: task.videoThumbnailBytes!,
              thumbnailName: task.videoThumbnailName ?? 'thumb.jpg',
              userId: task.userId,
              authToken: authToken,
              caption: task.caption,
            );

      if (result != null) {
        final videoUrl = result['url']!;
        final thumbnailUrl = result['thumbnail_url']!;

        task.status = UploadStatus.success;
        task.progress = 1.0;
        task.resultUrl = videoUrl;
        task.thumbnailUrl = thumbnailUrl;
        notifyListeners();

        for (final cb in _onChatMediaUploadedListeners) {
          cb(videoUrl, thumbnailUrl);
        }

        onSuccess(videoUrl, thumbnailUrl);

        Future.delayed(const Duration(seconds: 3), () {
          _tasks.removeWhere((t) => t.id == task.id);
          notifyListeners();
        });
      } else {
        task.status = UploadStatus.failed;
        task.error = 'Failed to upload video';
        notifyListeners();
        debugPrint('❌ Background chat video upload failed');
      }
    } catch (e) {
      task.status = UploadStatus.failed;
      task.error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      debugPrint('❌ Background chat video upload error: ${task.error}');
    }
  }

  // ==========================================================================
  // TASK MANAGEMENT
  // ==========================================================================

  void dismissTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void retryTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final old = _tasks[index];
    _tasks.removeAt(index);

    final retry = UploadTask(
      id: '${DateTime.now().millisecondsSinceEpoch}_${old.userId}',
      userId: old.userId,
      userName: old.userName,
      caption: old.caption,
      imageBytes: old.imageBytes,
      imageName: old.imageName,
      videoBytes: old.videoBytes,
      videoName: old.videoName,
      videoThumbnailBytes: old.videoThumbnailBytes,
      videoThumbnailName: old.videoThumbnailName,
      uploadType: old.uploadType,
      channelId: old.channelId,
      fixtureId: old.fixtureId,
      tempId: old.tempId,
    );
    _tasks.add(retry);
    notifyListeners();

    if (retry.uploadType == UploadType.chatImage) {
      _runChatImageUpload(retry, null, (_) {});
    } else if (retry.uploadType == UploadType.chatVideo) {
      _runChatVideoUpload(retry, null, (_, __) {});
    } else {
      _runUpload(retry);
    }
  }

  // ==========================================================================
  // NOTIFICATIONS (unchanged)
  // ==========================================================================

  Future<void> _sendNewPostNotification({
    required String postId,
    required String userId,
    required String userName,
    required String caption,
    required bool hasImage,
    required bool hasVideo,
  }) async {
    try {
      final followers = await ApiService.getUserFollowers(userId);
      if (followers.isEmpty) return;

      String postPreview;
      if (caption.isNotEmpty) {
        postPreview =
            caption.length > 60 ? '${caption.substring(0, 60)}...' : caption;
      } else if (hasVideo) {
        postPreview = '🎥 Shared a video';
      } else if (hasImage) {
        postPreview = '📷 Shared a photo';
      } else {
        postPreview = 'Shared a new post';
      }

      String postType = 'post';
      if (hasVideo && caption.isNotEmpty) {
        postType = 'video and caption';
      } else if (hasVideo) {
        postType = 'video';
      } else if (hasImage && caption.isNotEmpty) {
        postType = 'photo and caption';
      } else if (hasImage) {
        postType = 'photo';
      } else if (caption.isNotEmpty) {
        postType = 'update';
      }

      for (var follower in followers) {
        final followerId =
            follower['user_id']?.toString() ?? follower['id']?.toString();
        if (followerId == null || followerId == userId) continue;

        try {
          await NotificationService.sendNotification(
            userId: followerId,
            notificationType: 'new_post',
            title: '📱 New Post from @$userName',
            body: '@$userName shared a new $postType: $postPreview',
            data: {
              'post_id': postId,
              'post_author_id': userId,
              'post_author_name': userName,
              'post_caption': caption,
              'has_image': hasImage,
              'has_video': hasVideo,
              'type': 'new_post',
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
          await Future.delayed(const Duration(milliseconds: 50));
        } catch (e) {
          debugPrint('❌ Failed to notify $followerId: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error sending new post notifications: $e');
    }
  }
}
