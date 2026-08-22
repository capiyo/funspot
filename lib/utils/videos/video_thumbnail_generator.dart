// Conditional export: picks the real web implementation when compiling
// for web (dart.library.html is only available there), and a no-op stub
// otherwise so mobile builds don't choke on `import 'dart:html'`.
export 'video_thumbnail_generator_stub.dart'
    if (dart.library.html) 'video_thumbnail_generator_web.dart';
