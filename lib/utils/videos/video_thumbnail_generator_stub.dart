import 'dart:typed_data';

/// No-op on non-web platforms — mobile uses the `video_thumbnail` package
/// instead. This stub only exists so the conditional export compiles.
Future<Uint8List?> generateWebVideoThumbnail(
  Uint8List videoBytes, {
  double seekToFraction = 0.1,
  int maxWidth = 400,
  double quality = 0.75,
}) async =>
    null;
