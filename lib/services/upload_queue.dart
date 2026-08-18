import 'dart:io';
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
  final File? image;
  final File? video;
  final File? videoThumbnail;
  final UploadType uploadType;
  final String? channelId;
  final String? fixtureId;
  final String? tempId; // ✅ For pending message tracking
  double progress;
  UploadStatus status;
  String? error;
  String? resultUrl; // ✅ Store uploaded URL
  String? thumbnailUrl; // ✅ Store thumbnail URL

  UploadTask({
    required this.id,
    required this.userId,
    required this.userName,
    this.caption,
    this.image,
    this.video,
    this.videoThumbnail,
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

  // ✅ Helper to check if this is a chat upload
  bool get isChatUpload => uploadType != UploadType.post;

  // ✅ Helper to check if this is a media upload
  bool get hasMedia => image != null || video != null;
}

/// Runs uploads independent of any page/widget lifecycle.
/// Enqueue an upload and it keeps uploading even if the modal that
/// created it is popped or the user navigates elsewhere.
///
/// NOTE: Any upload that includes a video is routed through
/// background_downloader (see ApiService.createPostWithBackgroundVideo /
/// ApiService.uploadChatVideoWithThumbnailBackground). Those run in a
/// native background session (NSURLSession / WorkManager) that survives
/// the app being backgrounded, unlike a plain Dio request. Image/text-only
/// uploads stay on the existing Dio path since they complete quickly.
class UploadQueueService extends ChangeNotifier {
  UploadQueueService._internal();
  static final UploadQueueService _instance = UploadQueueService._internal();
  factory UploadQueueService() => _instance;

  final List<UploadTask> _tasks = [];
  List<UploadTask> get tasks => List.unmodifiable(_tasks);

  final List<VoidCallback> _onPostCreatedListeners = [];
  final List<void Function(String url, String? thumbnail)>
      _onChatMediaUploadedListeners = [];

  /// Register a callback to run whenever any queued post finishes
  /// successfully (e.g. to refresh a posts feed). Safe to call from
  /// initState of a page that may or may not still be mounted later —
  /// always pair with removeOnPostCreatedListener in dispose().
  void addOnPostCreatedListener(VoidCallback cb) {
    _onPostCreatedListeners.add(cb);
  }

  void removeOnPostCreatedListener(VoidCallback cb) {
    _onPostCreatedListeners.remove(cb);
  }

  /// ✅ Register a callback for chat media upload completions
  void addOnChatMediaUploadedListener(
      void Function(String url, String? thumbnail) cb) {
    _onChatMediaUploadedListeners.add(cb);
  }

  void removeOnChatMediaUploadedListener(
      void Function(String url, String? thumbnail) cb) {
    _onChatMediaUploadedListeners.remove(cb);
  }

  // ==========================================================================
  // POST UPLOAD
  // ==========================================================================

  String enqueuePost({
    required String userId,
    required String userName,
    String? caption,
    File? image,
    File? video,
    File? videoThumbnail,
  }) {
    final id = 'post_${DateTime.now().millisecondsSinceEpoch}_$userId';
    final task = UploadTask(
      id: id,
      userId: userId,
      userName: userName,
      caption: caption,
      image: image,
      video: video,
      videoThumbnail: videoThumbnail,
      uploadType: UploadType.post,
    );
    _tasks.add(task);
    notifyListeners();

    _runUpload(task);

    return id;
  }

  // ==========================================================================
  // CHAT MEDIA UPLOADS - BACKGROUND
  // ==========================================================================

  /// ✅ Enqueue chat image upload - runs in background
  String enqueueChatImage({
    required String userId,
    required String userName,
    required File imageFile,
    String? caption,
    String? channelId,
    String? fixtureId,
    String? tempId,
    String? authToken,
    required void Function(String url)
        onSuccess, // ✅ Callback for when upload completes
  }) {
    final id = 'chat_img_${DateTime.now().millisecondsSinceEpoch}_$userId';
    final task = UploadTask(
      id: id,
      userId: userId,
      userName: userName,
      image: imageFile,
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

  /// ✅ Enqueue chat video upload - runs in background
  String enqueueChatVideo({
    required String userId,
    required String userName,
    required File videoFile,
    required File thumbnailFile,
    String? caption,
    String? channelId,
    String? fixtureId,
    String? tempId,
    String? authToken,
    required void Function(String url, String thumbnail)
        onSuccess, // ✅ Callback for when upload completes
  }) {
    final id = 'chat_vid_${DateTime.now().millisecondsSinceEpoch}_$userId';
    final task = UploadTask(
      id: id,
      userId: userId,
      userName: userName,
      video: videoFile,
      videoThumbnail: thumbnailFile,
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

      if (task.video != null) {
        // ✅ Video posts go through background_downloader so the upload
        // survives the app being backgrounded (native OS upload session).
        postData = await ApiService.createPostWithBackgroundVideo(
          userId: task.userId,
          userName: task.userName,
          caption: task.caption,
          video: task.video!,
          videoThumbnail: task.videoThumbnail,
          onProgress: (progress) {
            task.progress = progress;
            notifyListeners();
          },
        );
      } else {
        // Image/text-only posts stay on the fast Dio path.
        postData = await ApiService.createPost(
          userId: task.userId,
          userName: task.userName,
          caption: task.caption,
          image: task.image,
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
          hasImage: task.image != null,
          hasVideo: task.video != null,
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

  /// ✅ Background chat image upload
  Future<void> _runChatImageUpload(
    UploadTask task,
    String? authToken,
    void Function(String url) onSuccess,
  ) async {
    try {
      final imageUrl = await ApiService.uploadChatImage(
        imageFile: task.image!,
        userId: task.userId,
        authToken: authToken,
        caption: task.caption,
      );

      if (imageUrl != null) {
        task.status = UploadStatus.success;
        task.progress = 1.0;
        task.resultUrl = imageUrl;
        notifyListeners();

        // ✅ Notify listeners
        for (final cb in _onChatMediaUploadedListeners) {
          cb(imageUrl, null);
        }

        // ✅ Call the success callback
        onSuccess(imageUrl);

        // ✅ Clean up after delay
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

  /// ✅ Background chat video upload
  /// Routed through background_downloader (native OS upload session) so it
  /// survives the app being backgrounded mid-upload — this is what fixes
  /// the "Failed to read video data: Error parsing multipart/form-data
  /// request" errors that happened when the video upload was interrupted
  /// by the app going into the background.
  Future<void> _runChatVideoUpload(
    UploadTask task,
    String? authToken,
    void Function(String url, String thumbnail) onSuccess,
  ) async {
    try {
      final result = await ApiService.uploadChatVideoWithThumbnailBackground(
        videoFile: task.video!,
        thumbnailFile: task.videoThumbnail!,
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

        // ✅ Notify listeners
        for (final cb in _onChatMediaUploadedListeners) {
          cb(videoUrl, thumbnailUrl);
        }

        // ✅ Call the success callback
        onSuccess(videoUrl, thumbnailUrl);

        // ✅ Clean up after delay
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
      image: old.image,
      video: old.video,
      videoThumbnail: old.videoThumbnail,
      uploadType: old.uploadType,
      channelId: old.channelId,
      fixtureId: old.fixtureId,
      tempId: old.tempId,
    );
    _tasks.add(retry);
    notifyListeners();

    // ✅ Retry based on type
    if (retry.uploadType == UploadType.chatImage) {
      _runChatImageUpload(retry, null, (_) {});
    } else if (retry.uploadType == UploadType.chatVideo) {
      _runChatVideoUpload(retry, null, (_, __) {});
    } else {
      _runUpload(retry);
    }
  }

  // ==========================================================================
  // NOTIFICATIONS
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
