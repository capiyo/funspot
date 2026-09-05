import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

Future<Uint8List?> generateVideoThumbnail({
  Uint8List? videoBytes,
  String? videoPath,
}) async {
  if (videoPath == null) return null;
  try {
    final tempDir = await getTemporaryDirectory();
    final String? thumbnailPath = await VideoThumbnail.thumbnailFile(
      video: videoPath,
      thumbnailPath: tempDir.path,
      imageFormat: ImageFormat.JPEG,
      quality: 75,
    );
    if (thumbnailPath == null) return null;
    return await File(thumbnailPath).readAsBytes();
  } catch (e) {
    return null;
  }
}
