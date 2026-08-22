import 'dart:typed_data';

/// Stand-in for dart:io's File on web, where dart:io doesn't exist.
/// Only referenced behind `if (!kIsWeb)` branches at runtime, so this
/// never actually executes — it just needs to type-check.
class File {
  File(String path);

  Future<Uint8List> readAsBytes() async =>
      throw UnsupportedError('dart:io File is not available on web.');
}
