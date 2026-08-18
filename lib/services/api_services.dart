import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:background_downloader/background_downloader.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://clash-api-m5mr.onrender.com',
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Accept': 'application/json'},
    ),
  );

  static void _init() {
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestBody: true,
        responseBody: true,
        error: true,
        logPrint: (object) => debugPrint(object.toString()),
      ),
    );
  }

  static void initialize() {
    _init();
  }

  // ==========================================================================
  // POST METHODS (Images & Videos)
  // ==========================================================================

  static Future<Map<String, dynamic>> createPost({
    required String userId,
    required String userName,
    String? caption,
    File? image,
    File? video,
    File? videoThumbnail,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      debugPrint('🟡 Starting post creation...');
      debugPrint('📱 User ID: $userId');
      debugPrint('👤 User Name: $userName');
      if (caption != null) debugPrint('📝 Caption: $caption');
      if (image != null) debugPrint('📁 Image path: ${image.path}');
      if (video != null) debugPrint('🎥 Video path: ${video.path}');
      if (videoThumbnail != null)
        debugPrint('🖼️ Thumbnail path: ${videoThumbnail.path}');

      if ((caption == null || caption.isEmpty) &&
          image == null &&
          video == null) {
        throw Exception('Please add a caption, image, or video');
      }

      Map<String, dynamic> formMap = {'userId': userId, 'userName': userName};

      if (caption != null && caption.isNotEmpty) {
        formMap['caption'] = caption;
      }

      FormData formData = FormData.fromMap(formMap);

      if (image != null) {
        if (!await image.exists()) {
          throw Exception('Image file does not exist');
        }

        int fileSize = await image.length();
        debugPrint('📏 Image size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

        if (fileSize > 10 * 1024 * 1024) {
          throw Exception('Image too large. Max size: 10MB');
        }

        String extension = image.path.split('.').last.toLowerCase();
        List<String> allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
        if (!allowedExtensions.contains(extension)) {
          throw Exception(
            'Invalid image format. Allowed: jpg, jpeg, png, gif, webp',
          );
        }

        formData.files.add(
          MapEntry(
            'image',
            await MultipartFile.fromFile(
              image.path,
              filename:
                  'post_${DateTime.now().millisecondsSinceEpoch}.$extension',
            ),
          ),
        );
      }

      if (video != null) {
        if (!await video.exists()) {
          throw Exception('Video file does not exist');
        }

        int fileSize = await video.length();
        debugPrint(
          '📏 Video size: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB',
        );

        if (fileSize > 50 * 1024 * 1024) {
          throw Exception('Video too large. Max size: 50MB');
        }

        String extension = video.path.split('.').last.toLowerCase();
        List<String> allowedExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
        if (!allowedExtensions.contains(extension)) {
          throw Exception(
            'Invalid video format. Allowed: mp4, mov, avi, mkv, webm',
          );
        }

        formData.files.add(
          MapEntry(
            'video',
            await MultipartFile.fromFile(
              video.path,
              filename:
                  'video_${DateTime.now().millisecondsSinceEpoch}.$extension',
              contentType: DioMediaType('video', extension),
            ),
          ),
        );
      }

      if (videoThumbnail != null) {
        if (!await videoThumbnail.exists()) {
          throw Exception('Video thumbnail file does not exist');
        }

        debugPrint('📤 Adding video thumbnail...');
        formData.files.add(
          MapEntry(
            'videoThumbnail',
            await MultipartFile.fromFile(
              videoThumbnail.path,
              filename:
                  'thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg',
              contentType: DioMediaType('image', 'jpeg'),
            ),
          ),
        );
      }

      debugPrint('🚀 Sending POST request to /api/posts');
      debugPrint('📋 Post type: ${_getPostType(caption, image, video)}');

      Response response = await _dio.post(
        '/api/posts',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          validateStatus: (status) => status! < 500,
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
        ),
        onSendProgress: onSendProgress,
      );

      debugPrint('📊 Response Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        Map<String, dynamic> data = response.data;
        if (data['success'] == true) {
          debugPrint('✅ Post created successfully!');
          return data;
        } else {
          throw Exception(data['message'] ?? 'Failed to create post');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('❌ Dio Error: ${e.type}');
      debugPrint('❌ Error Message: ${e.message}');

      if (e.response != null) {
        debugPrint('❌ Status: ${e.response!.statusCode}');
        debugPrint('❌ Response: ${e.response!.data}');

        try {
          if (e.response!.data is Map) {
            Map<String, dynamic> errorData = e.response!.data;
            String errorMsg = errorData['message'] ??
                errorData['error'] ??
                e.response!.statusMessage ??
                'Unknown error';
            throw Exception(errorMsg);
          }
        } catch (_) {}
      }

      throw Exception('Network error: ${e.message}');
    } catch (e) {
      debugPrint('❌ Error: $e');
      rethrow;
    }
  }

  static String _getPostType(String? caption, File? image, File? video) {
    final hasCaption = caption != null && caption.isNotEmpty;
    final hasImage = image != null;
    final hasVideo = video != null;

    if (hasCaption && hasVideo) return 'TEXT_AND_VIDEO';
    if (hasCaption && hasImage) return 'TEXT_AND_IMAGE';
    if (hasVideo) return 'VIDEO_ONLY';
    if (hasImage) return 'IMAGE_ONLY';
    if (hasCaption) return 'TEXT_ONLY';
    return 'UNKNOWN';
  }

// ==========================================================================
// BACKGROUND VIDEO UPLOAD (survives app backgrounding)
// ==========================================================================

  static Future<Map<String, dynamic>> createPostWithBackgroundVideo({
    required String userId,
    required String userName,
    String? caption,
    required File video,
    File? videoThumbnail,
    void Function(double progress)? onProgress,
  }) async {
    if (!await video.exists()) {
      throw Exception('Video file does not exist');
    }

    int fileSize = await video.length();
    if (fileSize > 50 * 1024 * 1024) {
      throw Exception('Video too large. Max size: 50MB');
    }

    String extension = video.path.split('.').last.toLowerCase();
    const allowed = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
    if (!allowed.contains(extension)) {
      throw Exception(
          'Invalid video format. Allowed: mp4, mov, avi, mkv, webm');
    }

    final fields = <String, String>{
      'userId': userId,
      'userName': userName,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
    };

    final files = <(String, String)>[
      ('video', video.path),
      if (videoThumbnail != null && await videoThumbnail.exists())
        ('videoThumbnail', videoThumbnail.path),
    ];

    final task = MultiUploadTask(
      taskId: 'post_video_${DateTime.now().millisecondsSinceEpoch}',
      url: 'https://clash-api-m5mr.onrender.com/api/posts',
      files: files,
      fields: fields,
      updates: Updates.statusAndProgress,
    );

    final result = await FileDownloader().upload(
      task,
      onProgress: (progress) => onProgress?.call(progress),
    );

    if (result.status != TaskStatus.complete) {
      throw Exception(
        'Video upload failed: ${result.status} '
        '${result.responseBody ?? ''}',
      );
    }

    final body = result.responseBody;
    if (body == null || body.isEmpty) {
      throw Exception('Empty response from server');
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to create post');
    }
    return data;
  }

  static Future<Map<String, String>?> uploadChatVideoWithThumbnailBackground({
    required File videoFile,
    required File thumbnailFile,
    required String userId,
    String? authToken,
    String? caption,
  }) async {
    if (!await videoFile.exists()) throw Exception('Video file does not exist');
    if (!await thumbnailFile.exists())
      throw Exception('Thumbnail file does not exist');

    int fileSize = await videoFile.length();
    if (fileSize > 50 * 1024 * 1024) {
      throw Exception('Video must be less than 50MB');
    }

    final fields = <String, String>{
      'userId': userId,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
    };

    final task = MultiUploadTask(
      taskId: 'chat_video_${DateTime.now().millisecondsSinceEpoch}',
      url: 'https://clash-api-m5mr.onrender.com/api/channels/media/upload',
      files: [
        ('file', videoFile.path),
        ('thumbnail', thumbnailFile.path),
      ],
      fields: fields,
      headers:
          authToken != null ? {'Authorization': 'Bearer $authToken'} : null,
      updates: Updates.statusAndProgress,
    );

    final result = await FileDownloader().upload(task);

    if (result.status != TaskStatus.complete || result.responseBody == null) {
      debugPrint('❌ Background chat video upload failed: ${result.status}');
      return null;
    }

    final data = jsonDecode(result.responseBody!) as Map<String, dynamic>;
    return {
      'url': data['url'] ?? '',
      'thumbnail_url': data['thumbnail_url'] ?? data['thumbnailUrl'] ?? '',
    };
  }

  // ==========================================================================
  // CHAT MEDIA UPLOAD METHODS
  // ==========================================================================

  /// ✅ Upload image for chat message
  static Future<String?> uploadChatImage({
    required File imageFile,
    required String userId,
    String? authToken,
    String? caption,
  }) async {
    try {
      debugPrint('📤 Uploading chat image...');

      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      int fileSize = await imageFile.length();
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('Image too large. Max size: 10MB');
      }

      String extension = imageFile.path.split('.').last.toLowerCase();
      String fileName =
          'chat_image_${DateTime.now().millisecondsSinceEpoch}.$extension';

      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
          contentType: DioMediaType(
            'image',
            extension == 'png' ? 'png' : 'jpeg',
          ),
        ),
        'userId': userId,
        if (caption != null && caption.isNotEmpty) 'caption': caption,
      });

      Response response = await _dio.post(
        '/api/channels/media/upload',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
            if (authToken != null) 'Authorization': 'Bearer $authToken',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      debugPrint('📊 Image upload status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final imageUrl = data['url'] ?? data['secure_url'];
        debugPrint('✅ Image uploaded: $imageUrl');
        return imageUrl;
      }

      debugPrint(
          '⚠️ Image upload failed: ${response.statusCode} - ${response.data}');
      return null;
    } on DioException catch (e) {
      debugPrint('❌ Image upload error');
      debugPrint('🔴 STATUS: ${e.response?.statusCode}');
      debugPrint('🔴 BODY: ${e.response?.data}');
      debugPrint('🔴 TYPE: ${e.type}');
      debugPrint('🔴 URL: ${e.requestOptions.uri}');
      return null;
    } catch (e) {
      debugPrint('❌ Image upload error: $e');
      return null;
    }
  }

  /// ✅ Upload video for chat message with thumbnail
  static Future<Map<String, String>?> uploadChatVideoWithThumbnail({
    required File videoFile,
    required File thumbnailFile,
    required String userId,
    String? authToken,
    String? caption,
  }) async {
    try {
      debugPrint('📤 Uploading chat video with thumbnail...');

      if (!await videoFile.exists()) {
        throw Exception('Video file does not exist');
      }
      if (!await thumbnailFile.exists()) {
        throw Exception('Thumbnail file does not exist');
      }

      int fileSize = await videoFile.length();
      if (fileSize > 50 * 1024 * 1024) {
        debugPrint(
          '⚠️ Video too large: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)}MB',
        );
        throw Exception('Video must be less than 50MB');
      }

      String extension = videoFile.path.split('.').last.toLowerCase();
      String fileName =
          'chat_video_${DateTime.now().millisecondsSinceEpoch}.$extension';

      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          videoFile.path,
          filename: fileName,
          contentType: DioMediaType('video', extension),
        ),
        'thumbnail': await MultipartFile.fromFile(
          thumbnailFile.path,
          filename: 'thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
        'userId': userId,
        if (caption != null && caption.isNotEmpty) 'caption': caption,
      });

      Response response = await _dio.post(
        '/api/channels/media/upload',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
            if (authToken != null) 'Authorization': 'Bearer $authToken',
          },
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        return {
          'url': data['url'] ?? '',
          'thumbnail_url': data['thumbnail_url'] ?? data['thumbnailUrl'] ?? '',
        };
      }
      return null;
    } on DioException catch (e) {
      debugPrint('❌ Video upload error: ${e.message}');
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception(
          'Upload timeout. Please try again with a smaller video.',
        );
      }
      return null;
    } catch (e) {
      debugPrint('❌ Video upload error: $e');
      return null;
    }
  }

  // ==========================================================================
  // CHAT MESSAGE METHODS
  // ==========================================================================

  /// ✅ Get chat messages from a channel
  static Future<List<Map<String, dynamic>>> getChannelMessages({
    required String channelId,
    String? fixtureId,
    int limit = 100,
    String? authToken,
  }) async {
    try {
      final String url;
      if (fixtureId != null && fixtureId.isNotEmpty) {
        url =
            '/api/channels/$channelId/messages?fixture_id=$fixtureId&limit=$limit';
      } else {
        url = '/api/channels/$channelId/messages?limit=$limit';
      }

      debugPrint('📤 Fetching messages from: $url');

      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'Accept': 'application/json',
            if (authToken != null && authToken.isNotEmpty)
              'Authorization': 'Bearer $authToken',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map) {
          final messages = data['messages'] ?? data['data'] ?? [];
          if (messages is List) {
            debugPrint('✅ Fetched ${messages.length} messages');
            return List<Map<String, dynamic>>.from(messages);
          }
        }
        return [];
      }
      return [];
    } on DioException catch (e) {
      debugPrint('❌ Error fetching messages: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return [];
    }
  }

  /// ✅ Send a chat message to a channel with tempId support
  static Future<bool> sendChannelMessage({
    required String channelId,
    required String userId,
    required String username,
    required String text,
    String? selection,
    String? fixtureId,
    String? imageUrl,
    String? videoUrl,
    String? videoThumbnailUrl,
    bool isImage = false,
    bool isVideo = false,
    String? caption,
    String? replyToMessageId,
    String? replyToText,
    String? replyToUsername,
    String? replyToSelection,
    String? authToken,
    String? tempId, // ✅ Add tempId for pending message tracking
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = authToken ?? prefs.getString('auth_token');

      // ✅ Build request body - all snake_case to match Rust
      final Map<String, dynamic> body = {
        'user_id': userId,
        'username': username,
        'text': text,
        'is_image': isImage,
        'is_video': isVideo,
      };

      // Optional fields - only include if not null/empty
      if (selection != null && selection.isNotEmpty) {
        body['selection'] = selection;
      }
      if (fixtureId != null && fixtureId.isNotEmpty) {
        body['fixture_id'] = fixtureId;
      }
      if (imageUrl != null && imageUrl.isNotEmpty) {
        body['image_url'] = imageUrl;
      }
      if (videoUrl != null && videoUrl.isNotEmpty) {
        body['video_url'] = videoUrl;
      }
      if (videoThumbnailUrl != null && videoThumbnailUrl.isNotEmpty) {
        body['video_thumbnail_url'] = videoThumbnailUrl;
      }
      if (caption != null && caption.isNotEmpty) {
        body['caption'] = caption;
      }
      if (tempId != null && tempId.isNotEmpty) {
        body['temp_id'] = tempId; // ✅ Send tempId to server
      }

      // ✅ Reply fields - flat structure (not nested)
      if (replyToMessageId != null && replyToMessageId.isNotEmpty) {
        body['reply_to_id'] = replyToMessageId;
        body['reply_to_text'] = replyToText ?? '';
        body['reply_to_username'] = replyToUsername ?? '';
        if (replyToSelection != null && replyToSelection.isNotEmpty) {
          body['reply_to_selection'] = replyToSelection;
        }
      }

      debugPrint('📤 Sending message to /api/channels/$channelId/messages');
      debugPrint('📋 Body: ${jsonEncode(body)}');

      final response = await _dio.post(
        '/api/channels/$channelId/messages',
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Message sent successfully');
        return true;
      } else {
        debugPrint('❌ Failed to send message: ${response.statusCode}');
        debugPrint('❌ Response: ${response.data}');
        return false;
      }
    } on DioException catch (e) {
      debugPrint('❌ Error sending message: ${e.message}');
      if (e.response != null) {
        debugPrint('❌ Response: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      return false;
    }
  }

  // ==========================================================================
  // EXISTING POST METHODS
  // ==========================================================================

  static Future<Map<String, dynamic>> getPosts({
    int page = 1,
    int limit = 20,
    String? userId,
  }) async {
    try {
      Map<String, dynamic> queryParams = {
        'page': page,
        'limit': limit,
        'userId': userId,
      };

      Response response = await _dio.get(
        '/api/posts',
        queryParameters: queryParams,
      );

      return {
        'posts': response.data['posts'] ?? [],
        'stats': response.data['stats'] ?? {},
        'pagination': response.data['pagination'] ?? {},
        'success': response.data['success'] ?? false,
      };
    } on DioException catch (e) {
      throw Exception('Error fetching posts: ${e.message}');
    }
  }

  static Future<Map<String, dynamic>> getPostById(String postId) async {
    try {
      Response response = await _dio.get('/api/posts/$postId');
      return response.data;
    } on DioException catch (e) {
      throw Exception('Error fetching post: ${e.message}');
    }
  }

  static Future<Map<String, dynamic>> getUserPosts(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      Response response = await _dio.get(
        '/api/posts/user/$userId',
        queryParameters: {'page': page, 'limit': limit},
      );
      return {
        'posts': response.data['posts'] ?? [],
        'stats': response.data['stats'] ?? {},
        'pagination': response.data['pagination'] ?? {},
        'success': response.data['success'] ?? false,
      };
    } on DioException catch (e) {
      throw Exception('Error fetching user posts: ${e.message}');
    }
  }

  static Future<bool> deletePost(String postId) async {
    try {
      Response response = await _dio.delete('/api/posts/$postId');
      return response.data['success'] == true;
    } on DioException catch (e) {
      debugPrint('Error deleting post: ${e.message}');
      return false;
    }
  }

  static Future<bool> updatePostCaption(
    String postId,
    String newCaption,
  ) async {
    try {
      Response response = await _dio.put(
        '/api/posts/$postId/caption',
        data: {'caption': newCaption},
      );
      return response.data['success'] == true;
    } on DioException catch (e) {
      debugPrint('Error updating caption: ${e.message}');
      return false;
    }
  }

  static Future<Map<String, dynamic>> getPostStats() async {
    try {
      Response response = await _dio.get('/api/posts/stats');
      return response.data;
    } on DioException catch (e) {
      throw Exception('Error fetching stats: ${e.message}');
    }
  }

  static Future<Map<String, dynamic>> getUserPostStats(String userId) async {
    try {
      Response response = await _dio.get('/api/posts/user/$userId/stats');
      return response.data;
    } on DioException catch (e) {
      throw Exception('Error fetching user stats: ${e.message}');
    }
  }

  static Future<Map<String, dynamic>> healthCheck() async {
    try {
      Response response = await _dio.get('/api/health');
      return response.data;
    } on DioException catch (e) {
      debugPrint('Health check failed: ${e.message}');
      return {'status': 'unhealthy', 'error': e.message};
    }
  }

  // ==========================================================================
  // FOLLOWERS / FOLLOWING METHODS
  // ==========================================================================

  static Future<List<Map<String, dynamic>>> getUserFollowers(
    String userId, {
    int page = 1,
    int limit = 50,
  }) async {
    try {
      debugPrint('📤 Fetching followers for user: $userId');

      final Response response = await _dio.get(
        '/api/users/$userId/followers',
        queryParameters: {'page': page, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data is Map) {
          if (data['success'] == true) {
            final followers = data['followers'] ?? data['data'] ?? [];
            if (followers is List) {
              debugPrint('✅ Found ${followers.length} followers');
              return List<Map<String, dynamic>>.from(followers);
            }
          } else if (data['followers'] is List) {
            debugPrint('✅ Found ${data['followers'].length} followers');
            return List<Map<String, dynamic>>.from(data['followers']);
          } else if (data['data'] is List) {
            debugPrint('✅ Found ${data['data'].length} followers');
            return List<Map<String, dynamic>>.from(data['data']);
          }
        } else if (data is List) {
          debugPrint('✅ Found ${data.length} followers');
          return List<Map<String, dynamic>>.from(data);
        }

        debugPrint('⚠️ Unexpected response format: $data');
        return [];
      } else if (response.statusCode == 404) {
        debugPrint('📭 No followers found for user $userId');
        return [];
      } else {
        debugPrint('⚠️ Failed to fetch followers: ${response.statusCode}');
        return [];
      }
    } on DioException catch (e) {
      debugPrint('❌ Error fetching followers: ${e.message}');
      if (e.response?.statusCode == 404) {
        return [];
      }
      return [];
    } catch (e) {
      debugPrint('❌ Unexpected error fetching followers: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getUserFollowing(
    String userId, {
    int page = 1,
    int limit = 50,
  }) async {
    try {
      debugPrint('📤 Fetching following for user: $userId');

      final Response response = await _dio.get(
        '/api/users/$userId/following',
        queryParameters: {'page': page, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data is Map) {
          if (data['success'] == true) {
            final following = data['following'] ?? data['data'] ?? [];
            if (following is List) {
              debugPrint('✅ Found ${following.length} following');
              return List<Map<String, dynamic>>.from(following);
            }
          } else if (data['following'] is List) {
            debugPrint('✅ Found ${data['following'].length} following');
            return List<Map<String, dynamic>>.from(data['following']);
          } else if (data['data'] is List) {
            debugPrint('✅ Found ${data['data'].length} following');
            return List<Map<String, dynamic>>.from(data['data']);
          }
        } else if (data is List) {
          debugPrint('✅ Found ${data.length} following');
          return List<Map<String, dynamic>>.from(data);
        }

        return [];
      } else if (response.statusCode == 404) {
        debugPrint('📭 No following found for user $userId');
        return [];
      } else {
        return [];
      }
    } on DioException catch (e) {
      debugPrint('❌ Error fetching following: ${e.message}');
      return [];
    }
  }

  static Future<bool> followUser({
    required String followerId,
    required String followingId,
    String? authToken,
  }) async {
    try {
      final response = await _dio.post(
        '/api/users/follow',
        data: {'follower_id': followerId, 'following_id': followingId},
        options: Options(headers: _getHeaders(authToken: authToken)),
      );

      return response.statusCode == 200 && response.data['success'] == true;
    } on DioException catch (e) {
      debugPrint('❌ Error following user: ${e.message}');
      return false;
    }
  }

  static Future<bool> unfollowUser({
    required String followerId,
    required String followingId,
    String? authToken,
  }) async {
    try {
      final response = await _dio.delete(
        '/api/users/follow',
        data: {'follower_id': followerId, 'following_id': followingId},
        options: Options(headers: _getHeaders(authToken: authToken)),
      );

      return response.statusCode == 200 && response.data['success'] == true;
    } on DioException catch (e) {
      debugPrint('❌ Error unfollowing user: ${e.message}');
      return false;
    }
  }

  static Future<bool> isFollowing({
    required String followerId,
    required String followingId,
    String? authToken,
  }) async {
    try {
      final response = await _dio.get(
        '/api/users/$followerId/is-following/$followingId',
        options: Options(headers: _getHeaders(authToken: authToken)),
      );

      return response.statusCode == 200 &&
          response.data['is_following'] == true;
    } on DioException catch (e) {
      debugPrint('❌ Error checking follow status: ${e.message}');
      return false;
    }
  }

  static Future<int> getFollowerCount(String userId) async {
    try {
      final followers = await getUserFollowers(userId, limit: 1);
      return followers.length;
    } catch (e) {
      debugPrint('❌ Error getting follower count: $e');
      return 0;
    }
  }

  // ==========================================================================
  // SUB-FIXTURE (PROP BETS) METHODS
  // ==========================================================================

  static Future<List<Map<String, dynamic>>?> getSubFixtures({
    required String parentFixtureId,
    String? fixtureType,
    bool? isActive,
    String? authToken,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'parent_fixture_id': parentFixtureId,
        'fixtureType': fixtureType,
        'isActive': isActive,
      };

      final response = await _dio.get(
        '/api/votes/sub-fixtures',
        queryParameters: queryParams,
        options: Options(headers: _getHeaders(authToken: authToken)),
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error fetching sub-fixtures: ${e.message}');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getSubFixtureById(
    String subFixtureId, {
    String? authToken,
  }) async {
    try {
      final response = await _dio.get(
        '/api/votes/sub-fixture/$subFixtureId',
        options: Options(headers: _getHeaders(authToken: authToken)),
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error fetching sub-fixture: ${e.message}');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getSubFixtureStats(
    String subFixtureId,
  ) async {
    try {
      final response = await _dio.get(
        '/api/votes/sub-fixture/$subFixtureId/stats',
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error fetching sub-fixture stats: ${e.message}');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> getSubFixtureVoters(
    String subFixtureId, {
    String? selection,
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'selection': selection,
        'limit': limit,
        'offset': offset,
      };

      final response = await _dio.get(
        '/api/votes/sub-fixture/$subFixtureId/voters',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error fetching sub-fixture voters: ${e.message}');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> submitSubFixtureVote({
    required String voterId,
    required String username,
    required String subFixtureId,
    required String parentFixtureId,
    required String selection,
    String? authToken,
    String? question,
    String? optionA,
    String? optionB,
    String? optionC,
    String? icon,
    String? fixtureType,
  }) async {
    try {
      final body = {
        'voter_id': voterId,
        'username': username,
        'sub_fixture_id': subFixtureId,
        'parent_fixture_id': parentFixtureId,
        'selection': selection,
        'question': question,
        'optionA': optionA,
        'optionB': optionB,
        'optionC': optionC,
        'icon': icon,
        'fixtureType': fixtureType,
      };

      final response = await _dio.post(
        '/api/votes/sub-fixture',
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            ..._getHeaders(authToken: authToken),
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Vote submitted successfully!');
        return response.data;
      }

      if (response.statusCode == 422) {
        throw Exception(
          'Validation error: ${response.data['message'] ?? 'Invalid data'}',
        );
      }

      return null;
    } on DioException catch (e) {
      debugPrint('❌ Error submitting sub-fixture vote: ${e.message}');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> checkUserSubFixtureVote(
    String subFixtureId,
    String userId,
  ) async {
    try {
      final response = await _dio.get(
        '/api/votes/sub-fixture/$subFixtureId/user/$userId',
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error checking user sub-fixture vote: ${e.message}');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> getUserSubFixtureVotes(
    String userId,
    String fixtureId,
  ) async {
    try {
      final response = await _dio.get(
        '/api/votes/user/$userId/fixture/$fixtureId/sub-votes',
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error fetching user sub-fixture votes: ${e.message}');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> getSubFixturesWithUserVotes(
    String fixtureId,
    String userId,
  ) async {
    try {
      final response = await _dio.get(
        '/api/votes/sub-fixtures/fixture/$fixtureId/user/$userId',
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error fetching sub-fixtures with user votes: ${e.message}');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getSubFixtureVoteCounts(
    String subFixtureId,
  ) async {
    try {
      final response = await _dio.get(
        '/api/votes/sub-fixture/$subFixtureId/counts',
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error fetching sub-fixture vote counts: ${e.message}');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> getAllSubFixtureVotes(
    String subFixtureId,
    String? authToken,
  ) async {
    try {
      final response = await _dio.get(
        '/api/votes/sub-fixture/$subFixtureId/all-votes',
        options: Options(headers: _getHeaders(authToken: authToken)),
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error fetching all sub-fixture votes: ${e.message}');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> getTrendingSubFixtures({
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get(
        '/api/votes/stats/sub-fixtures/trending',
        queryParameters: {'limit': limit},
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error fetching trending sub-fixtures: ${e.message}');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getBulkSubFixtureStats({
    required List<String> subFixtureIds,
    String? authToken,
  }) async {
    try {
      final response = await _dio.post(
        '/api/votes/stats/sub-fixtures/bulk',
        data: {'sub_fixture_ids': subFixtureIds},
        options: Options(headers: _getHeaders(authToken: authToken)),
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error fetching bulk sub-fixture stats: ${e.message}');
      return null;
    }
  }

  // ==========================================================================
  // HELPER METHODS
  // ==========================================================================

  static Map<String, String> _getHeaders({String? authToken}) {
    final headers = <String, String>{};
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }
}
