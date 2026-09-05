export 'video_thumb_stub.dart'
    if (dart.library.html) 'video_thumb_web.dart'
    if (dart.library.io) 'video_thumb_io.dart';
