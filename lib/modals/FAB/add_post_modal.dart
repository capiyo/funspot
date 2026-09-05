import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../services/video_thumb.dart'; // adjust path to wherever you put it, e.g. '../../services/video_thumb.dart'
import 'package:path_provider/path_provider.dart';
import '../../services/api_services.dart';
import '../../services/notification_service.dart';
import '../../services/upload_queue.dart';
import '../../pages/fan_Funzy_design.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AddPostModal extends StatelessWidget {
  final VoidCallback? onPostCreated;
  final String? userId;
  final String? username;

  const AddPostModal({
    super.key,
    this.onPostCreated,
    this.userId,
    this.username,
  });

  @override
  Widget build(BuildContext context) {
    return _AddPostModalContent(
      onPostCreated: onPostCreated,
      userId: userId,
      username: username,
    );
  }
}

class _AddPostModalContent extends StatefulWidget {
  final VoidCallback? onPostCreated;
  final String? userId;
  final String? username;

  const _AddPostModalContent({this.onPostCreated, this.userId, this.username});

  @override
  State<_AddPostModalContent> createState() => __AddPostModalContentState();
}

class __AddPostModalContentState extends State<_AddPostModalContent> {
  // ==========================================================================
  // STATE — bytes-based, works on web + mobile
  // ==========================================================================
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  Uint8List? _selectedVideoBytes;
  String? _selectedVideoName;

  Uint8List? _videoThumbnailBytes;
  String? _videoThumbnailName;

  bool _isPosting = false;
  final TextEditingController _captionController = TextEditingController();
  String _message = "";
  bool _isVideoSelected = false;
  bool _isImageSelected = false;
  bool _isGeneratingThumbnail = false;

  final ImagePicker _picker = ImagePicker();

  // ==========================================================================
  // PICK IMAGE
  // ==========================================================================
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      final bool isValid = _validateByteSize(bytes, 10);
      if (!isValid) return;

      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = image.name;
        _isImageSelected = true;
        _isVideoSelected = false;
        _selectedVideoBytes = null;
        _selectedVideoName = null;
        _videoThumbnailBytes = null;
        _videoThumbnailName = null;
        _message = "";
      });
    } catch (e) {
      setState(() => _message = "Error picking image");
    }
  }

  // ==========================================================================
  // PICK VIDEO
  // ==========================================================================
 Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;

      final bytes = await video.readAsBytes();
      final bool isValid = _validateByteSize(bytes, 50);
      if (!isValid) return;

      // Show the preview immediately with the fallback icon; upgrade it
      // with a real snapshot once generation finishes below.
      setState(() {
        _selectedVideoBytes = bytes;
        _selectedVideoName = video.name;
        _videoThumbnailBytes = null;
        _videoThumbnailName = null;
        _isVideoSelected = true;
        _isImageSelected = false;
        _selectedImageBytes = null;
        _selectedImageName = null;
        _isGeneratingThumbnail = true;
        _message = "";
      });

      final thumbBytes = await generateVideoThumbnail(
        videoBytes: bytes, // used on web
        videoPath: video.path, // used on mobile
      );

      if (!mounted || _selectedVideoBytes != bytes) return;

      setState(() {
        _videoThumbnailBytes = thumbBytes;
        _videoThumbnailName = thumbBytes != null ? 'thumb.jpg' : null;
        _isGeneratingThumbnail = false;
      });
    } catch (e) {
      setState(() {
        _message = "Error picking video";
        _isGeneratingThumbnail = false;
      });
    }
  }

  // ==========================================================================
  // VALIDATE FILE SIZE (bytes-based, no dart:io dependency)
  // ==========================================================================
  bool _validateByteSize(Uint8List bytes, int maxSizeMB) {
    final sizeInMB = bytes.lengthInBytes / (1024 * 1024);
    if (sizeInMB > maxSizeMB) {
      setState(() => _message = "File too large (max ${maxSizeMB}MB)");
      return false;
    }
    return true;
  }

  // ==========================================================================
  // SEND NOTIFICATIONS (unchanged — no File dependency here)
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
      if (followers.isEmpty) {
        debugPrint('📭 No followers to notify about new post');
        return;
      }

      String postPreview;
      if (caption.isNotEmpty) {
        postPreview = caption.length > 60 ? '${caption.substring(0, 60)}...' : caption;
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

      int successCount = 0;
      for (var follower in followers) {
        final followerId = follower['user_id']?.toString() ?? follower['id']?.toString();
        if (followerId != null && followerId != userId) {
          try {
            final success = await NotificationService.sendNotification(
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
            if (success) successCount++;
            await Future.delayed(const Duration(milliseconds: 50));
          } catch (e) {
            debugPrint('❌ Failed to send notification to $followerId: $e');
          }
        }
      }

      debugPrint('✅ Sent new post notifications to $successCount/${followers.length} followers');
    } catch (e) {
      debugPrint('❌ Error sending new post notifications: $e');
    }
  }

  // ==========================================================================
  // SUBMIT POST — enqueues upload in background, closes modal immediately
  // ==========================================================================
  void _submitPost() {
    if (widget.userId == null || widget.userId!.isEmpty) {
      setState(() => _message = "Please login first");
      return;
    }

    final caption = _captionController.text.trim();

    if (caption.isEmpty && _selectedImageBytes == null && _selectedVideoBytes == null) {
      setState(() => _message = "Please add a caption, image, or video");
      return;
    }

    final bool hasImage = _selectedImageBytes != null;
    final bool hasVideo = _selectedVideoBytes != null;

    UploadQueueService().enqueuePost(
      userId: widget.userId!,
      userName: widget.username ?? 'User',
      caption: caption.isNotEmpty ? caption : null,
      imageBytes: _selectedImageBytes,
      imageName: _selectedImageName,
      videoBytes: _selectedVideoBytes,
      videoName: _selectedVideoName,
      videoThumbnailBytes: _videoThumbnailBytes,
      videoThumbnailName: _videoThumbnailName,
    );

    if (widget.onPostCreated != null) {
      UploadQueueService().addOnPostCreatedListener(widget.onPostCreated!);
    }

    String toastMsg;
    if (hasVideo) {
      toastMsg = "🎥 Posting video in background...";
    } else if (hasImage) {
      toastMsg = "📷 Posting image in background...";
    } else {
      toastMsg = "📝 Posting...";
    }

    Fluttertoast.showToast(
      msg: toastMsg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );

    Navigator.pop(context);
  }

  // ==========================================================================
  // CLEAR FORM
  // ==========================================================================
  void _clearForm() {
    _captionController.clear();
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
      _selectedVideoBytes = null;
      _selectedVideoName = null;
      _videoThumbnailBytes = null;
      _videoThumbnailName = null;
      _isImageSelected = false;
      _isVideoSelected = false;
      _message = "";
    });
  }

  // ==========================================================================
  // GETTERS
  // ==========================================================================
  bool get _isPostButtonEnabled {
    final bool hasCaption = _captionController.text.trim().isNotEmpty;
    final bool hasMedia = _selectedImageBytes != null || _selectedVideoBytes != null;
    return !_isPosting && (hasCaption || hasMedia);
  }

  String _getPostButtonText() {
    final bool hasCaption = _captionController.text.trim().isNotEmpty;
    final bool hasVideo = _selectedVideoBytes != null;
    final bool hasImage = _selectedImageBytes != null;

    if (hasCaption && hasVideo) return "Post Video";
    if (hasCaption && hasImage) return "Post Image";
    if (hasVideo) return "Post Video";
    if (hasImage) return "Post Image";
    return "Post";
  }

  IconData _getPostButtonIcon() {
    final bool hasVideo = _selectedVideoBytes != null;
    final bool hasImage = _selectedImageBytes != null;

    if (hasVideo) return Icons.videocam_rounded;
    if (hasImage) return Icons.image_rounded;
    return Icons.send_rounded;
  }

  String _getPostTypeText() {
    final bool hasCaption = _captionController.text.trim().isNotEmpty;
    final bool hasVideo = _selectedVideoBytes != null;
    final bool hasImage = _selectedImageBytes != null;

    if (hasCaption && hasVideo) return "📹 Video with caption";
    if (hasCaption && hasImage) return "🖼️ Image with caption";
    if (hasVideo) return "🎬 Video post";
    if (hasImage) return "📸 Image post";
    if (hasCaption) return "📝 Text post";
    return "";
  }

  String _getFileSize() {
    if (_selectedVideoBytes != null) {
      final size = _selectedVideoBytes!.lengthInBytes;
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (_selectedImageBytes != null) {
      final size = _selectedImageBytes!.lengthInBytes;
      return '${(size / 1024).toStringAsFixed(0)} KB';
    }
    return '';
  }

  // ==========================================================================
  // BUILD MEDIA PREVIEW
  // ==========================================================================
  Widget _buildMediaPreview() {
    if (_selectedVideoBytes != null) {
      return Container(
        height: 160,
        decoration: FanDecorations.card(isActive: true),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: FanRadius.lgAll,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_videoThumbnailBytes != null)
                    Image.memory(
                      _videoThumbnailBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  else
                    Container(
                      color: Colors.black,
                      child: const Center(
                        child: Icon(Icons.play_circle_filled, color: Colors.white, size: 48),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.4),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.videocam, color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          const Text('VIDEO', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ],
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Center(
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 56),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(6)),
                      child: Text(_getFileSize(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedVideoBytes = null;
                  _selectedVideoName = null;
                  _videoThumbnailBytes = null;
                  _videoThumbnailName = null;
                  _isVideoSelected = false;
                  _message = "";
                }),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_selectedImageBytes != null) {
      return Container(
        height: 160,
        decoration: FanDecorations.card(isActive: true),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: FanRadius.lgAll,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    _selectedImageBytes!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.2),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.2),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.image, color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          const Text('IMAGE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(6)),
                      child: Text(_getFileSize(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedImageBytes = null;
                  _selectedImageName = null;
                  _isImageSelected = false;
                  _message = "";
                }),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasCaption = _captionController.text.trim().isNotEmpty;
    final bool hasVideo = _selectedVideoBytes != null;
    final bool hasImage = _selectedImageBytes != null;
    final bool hasMedia = hasVideo || hasImage;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: FanColors.surface,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        border: Border.all(color: FanColors.border),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: FanColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: FanColors.primary, shape: BoxShape.circle),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: FanColors.background, shape: BoxShape.circle),
                      child: Center(
                        child: Icon(
                          hasVideo ? Icons.videocam : hasImage ? Icons.image : Icons.add_a_photo,
                          color: FanColors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hasVideo ? "Create Video Post" : "Create Post", style: FanTypography.headline),
                      const SizedBox(height: 4),
                      Text(
                        widget.username?.isNotEmpty == true ? "@${widget.username}" : "Share your moment",
                        style: FanTypography.caption.copyWith(color: FanColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: FanColors.surfaceSunken, shape: BoxShape.circle, border: Border.all(color: FanColors.border)),
                    child: Icon(Icons.close, color: FanColors.textPrimary, size: 18),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: FanColors.surfaceSunken,
                      borderRadius: FanRadius.lgAll,
                      border: hasCaption ? Border.all(color: FanColors.primary, width: 1.5) : null,
                    ),
                    child: TextField(
                      controller: _captionController,
                      maxLines: 4,
                      style: FanTypography.body.copyWith(fontSize: 15, height: 1.4),
                      decoration: InputDecoration(
                        hintText: "What's on your mind? (Optional)",
                        hintStyle: FanTypography.body.copyWith(color: FanColors.textTertiary),
                        contentPadding: const EdgeInsets.all(16),
                        border: InputBorder.none,
                        filled: true,
                        fillColor: Colors.transparent,
                        suffixIcon: hasCaption
                            ? Padding(
                                padding: const EdgeInsets.all(12),
                                child: Icon(Icons.text_fields, color: FanColors.primary, size: 20),
                              )
                            : null,
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: FanColors.surfaceSunken,
                      borderRadius: FanRadius.lgAll,
                      border: hasMedia
                          ? Border.all(color: FanColors.primaryMuted, width: 1.5)
                          : Border.all(color: FanColors.draw.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Column(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: hasImage ? FanColors.primaryDim : FanColors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: hasImage ? FanColors.primary : FanColors.border, width: hasImage ? 2 : 1.5),
                                  boxShadow: hasImage ? [BoxShadow(color: FanColors.primary.withValues(alpha: 0.2), blurRadius: 8)] : null,
                                ),
                                child: Icon(Icons.photo_library, color: hasImage ? FanColors.primary : FanColors.textSecondary, size: 24),
                              ),
                              const SizedBox(height: 4),
                              Text("Photo", style: TextStyle(fontSize: 10, color: hasImage ? FanColors.primary : FanColors.textSecondary, fontWeight: hasImage ? FontWeight.w700 : FontWeight.normal)),
                              if (hasImage)
                                Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 2), decoration: BoxDecoration(color: FanColors.primary, shape: BoxShape.circle)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _pickVideo,
                          child: Column(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: hasVideo ? FanColors.primaryDim : FanColors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: hasVideo ? FanColors.primary : FanColors.border, width: hasVideo ? 2 : 1.5),
                                  boxShadow: hasVideo ? [BoxShadow(color: FanColors.primary.withValues(alpha: 0.2), blurRadius: 8)] : null,
                                ),
                                child: Icon(Icons.videocam, color: hasVideo ? FanColors.primary : FanColors.textSecondary, size: 24),
                              ),
                              const SizedBox(height: 4),
                              Text("Video", style: TextStyle(fontSize: 10, color: hasVideo ? FanColors.primary : FanColors.textSecondary, fontWeight: hasVideo ? FontWeight.w700 : FontWeight.normal)),
                              if (hasVideo)
                                Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 2), decoration: BoxDecoration(color: FanColors.primary, shape: BoxShape.circle)),
                            ],
                          ),
                        ),
                        if (hasMedia)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedImageBytes = null;
                                _selectedImageName = null;
                                _selectedVideoBytes = null;
                                _selectedVideoName = null;
                                _videoThumbnailBytes = null;
                                _videoThumbnailName = null;
                                _isImageSelected = false;
                                _isVideoSelected = false;
                                _message = "";
                              });
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(color: FanColors.awayDim, shape: BoxShape.circle, border: Border.all(color: FanColors.away, width: 1.5)),
                                  child: Icon(Icons.clear, color: FanColors.away, size: 24),
                                ),
                                const SizedBox(height: 4),
                                Text("Clear", style: TextStyle(fontSize: 10, color: FanColors.away, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (hasMedia) ...[
                    _buildMediaPreview(),
                    const SizedBox(height: 8),
                  ],
                  if (hasCaption || hasMedia) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: FanColors.primaryDim, borderRadius: FanRadius.pillAll, border: Border.all(color: FanColors.primaryMuted, width: 1)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(hasVideo ? Icons.videocam : hasImage ? Icons.image : Icons.text_fields, color: FanColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Text(_getPostTypeText(), style: FanTypography.body.copyWith(color: FanColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_message.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _message.contains("successfully") || _message.contains("created") ? FanColors.primaryDim : FanColors.awayDim,
                        borderRadius: FanRadius.lgAll,
                        border: Border.all(color: _message.contains("successfully") || _message.contains("created") ? FanColors.primaryMuted : FanColors.away.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _message.contains("successfully") || _message.contains("created") ? Icons.check_circle_outline : Icons.error_outline,
                            color: _message.contains("successfully") || _message.contains("created") ? FanColors.primary : FanColors.away,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _message,
                              style: FanTypography.body.copyWith(
                                color: _message.contains("successfully") || _message.contains("created") ? FanColors.primary : FanColors.away,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _clearForm,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(color: FanColors.surfaceSunken, borderRadius: FanRadius.pillAll, border: Border.all(color: FanColors.border)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.refresh, color: FanColors.textSecondary, size: 18),
                                const SizedBox(width: 8),
                                Text("Clear", style: FanTypography.body.copyWith(fontWeight: FontWeight.w600, color: FanColors.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: _isPostButtonEnabled ? _submitPost : null,
                          child: Container(
                            height: 48,
                            decoration: _isPostButtonEnabled
                                ? FanDecorations.primaryButton
                                : BoxDecoration(color: FanColors.surfaceSunken, borderRadius: FanRadius.pillAll, border: Border.all(color: FanColors.border)),
                            child: _isPosting
                                ? Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _isPostButtonEnabled ? FanColors.textInverse : FanColors.textTertiary,
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(_getPostButtonIcon(), color: _isPostButtonEnabled ? FanColors.textInverse : FanColors.textTertiary, size: 18),
                                      const SizedBox(width: 10),
                                      Text(
                                        _getPostButtonText(),
                                        style: FanTypography.button.copyWith(
                                          color: _isPostButtonEnabled ? FanColors.textInverse : FanColors.textTertiary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}