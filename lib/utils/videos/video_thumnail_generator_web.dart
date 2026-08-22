import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Loads [videoBytes] into a hidden <video> element, seeks to a frame,
/// draws it to a <canvas>, and returns real JPEG bytes. Runs entirely
/// client-side — no server round trip, no plugin — because video_thumbnail
/// has no web implementation and there's no real filesystem in a browser.
Future<Uint8List?> generateWebVideoThumbnail(
  Uint8List videoBytes, {
  double seekToFraction = 0.1, // 10% into the clip avoids black opening frames
  int maxWidth = 400,
  double quality = 0.75,
}) async {
  html.Blob? blob;
  String? objectUrl;
  html.VideoElement? video;

  try {
    blob = html.Blob([videoBytes], 'video/mp4');
    objectUrl = html.Url.createObjectUrlFromBlob(blob);

    video = html.VideoElement()
      ..src = objectUrl
      ..muted = true
      ..preload = 'auto';
    video.setAttribute('playsinline', 'true');
    // Off-screen but still in the DOM — some browsers refuse to decode
    // frames for elements with display:none.
    video.style
      ..position = 'fixed'
      ..top = '-9999px'
      ..left = '-9999px'
      ..width = '1px'
      ..height = '1px';
    html.document.body?.append(video);

    // ---- wait for metadata (gives us duration + dimensions) ----
    final metadataCompleter = Completer<void>();
    late StreamSubscription metaSub;
    metaSub = video.onLoadedMetadata.listen((_) {
      metaSub.cancel();
      if (!metadataCompleter.isCompleted) metadataCompleter.complete();
    });
    final errorSub = video.onError.listen((e) {
      if (!metadataCompleter.isCompleted) {
        metadataCompleter.completeError('Video failed to load: $e');
      }
    });

    await metadataCompleter.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Video metadata load timed out'),
    );
    errorSub.cancel();

    // ---- seek to target frame ----
    final duration = video.duration;
    final seekTime = (duration.isFinite && duration > 0)
        ? (duration * seekToFraction).clamp(0.0, duration)
        : 0.0;

    final seekedCompleter = Completer<void>();
    late StreamSubscription seekSub;
    seekSub = video.onSeeked.listen((_) {
      seekSub.cancel();
      if (!seekedCompleter.isCompleted) seekedCompleter.complete();
    });

    video.currentTime = seekTime;

    await seekedCompleter.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Video seek timed out'),
    );

    // Small settle delay — some browsers report `seeked` a frame before
    // the canvas is actually paintable.
    await Future.delayed(const Duration(milliseconds: 50));

    final videoWidth = video.videoWidth;
    final videoHeight = video.videoHeight;
    if (videoWidth == 0 || videoHeight == 0) {
      throw 'Video has no visual dimensions (videoWidth/videoHeight are 0)';
    }

    // ---- draw frame to canvas ----
    final scale = maxWidth / videoWidth;
    final targetWidth = scale < 1 ? maxWidth : videoWidth;
    final targetHeight =
        scale < 1 ? (videoHeight * scale).round() : videoHeight;

    final canvas = html.CanvasElement(width: targetWidth, height: targetHeight);
    final ctx = canvas.context2D;
    ctx.drawImageScaled(video, 0, 0, targetWidth, targetHeight);

    // ---- canvas -> JPEG bytes ----
    final canvasBlob = await canvas.toBlob('image/jpeg', quality);

    final reader = html.FileReader();
    final readCompleter = Completer<Uint8List>();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        readCompleter.complete(result.asUint8List());
      } else {
        readCompleter
            .completeError('Unexpected FileReader result type: $result');
      }
    });
    reader.onError.listen((e) {
      if (!readCompleter.isCompleted) readCompleter.completeError(e);
    });
    reader.readAsArrayBuffer(canvasBlob);

    return await readCompleter.future.timeout(const Duration(seconds: 10));
  } catch (e) {
    // Caller falls back to the placeholder thumbnail on null — this is
    // deliberately non-fatal so a thumbnail failure never blocks sending
    // the actual video.
    // ignore: avoid_print
    print('⚠️ generateWebVideoThumbnail failed: $e');
    return null;
  } finally {
    video?.remove();
    if (objectUrl != null) html.Url.revokeObjectUrl(objectUrl);
  }
}
