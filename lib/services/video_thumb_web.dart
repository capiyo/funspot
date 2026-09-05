import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List?> generateVideoThumbnail({
  Uint8List? videoBytes,
  String? videoPath,
}) async {
  if (videoBytes == null) return null;
  html.Url? _; // no-op, keeps analyzer happy about unused import removal
  final blob = html.Blob([videoBytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);

  try {
    final video = html.VideoElement()
      ..src = url
      ..muted = true
      ..preload = 'auto';

    final loaded = Completer<void>();
    video.onLoadedMetadata.listen((_) {
      if (!loaded.isCompleted) loaded.complete();
    });
    video.onError.listen((_) {
      if (!loaded.isCompleted) loaded.completeError('load error');
    });
    await loaded.future.timeout(const Duration(seconds: 8));

    // Seek slightly into the video — the very first frame is often black.
    final duration = video.duration.isFinite ? video.duration : 1.0;
    final seekTo =
        (duration * 0.1).clamp(0.0, duration > 0.2 ? duration - 0.1 : 0.0);

    final seeked = Completer<void>();
    video.onSeeked.listen((_) {
      if (!seeked.isCompleted) seeked.complete();
    });
    video.currentTime = seekTo;
    await seeked.future.timeout(const Duration(seconds: 8));

    final width = video.videoWidth;
    final height = video.videoHeight;
    if (width == 0 || height == 0) return null;

    final canvas = html.CanvasElement(width: width, height: height);
    canvas.context2D.drawImage(video, 0, 0);

    final dataUrl = canvas.toDataUrl('image/jpeg', 0.75);
    final base64Str = dataUrl.split(',').last;
    return base64.decode(base64Str);
  } catch (e) {
    return null;
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
