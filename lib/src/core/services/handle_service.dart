import 'dart:math';

class HandleService {
  HandleService([dynamic _]);

  /// Generates a unique handle based on the provided [baseName].
  Future<String> generateUniqueHandle(String baseName) async {
    String handle = baseName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '')
        .trim();

    if (handle.isEmpty) {
      handle = 'user';
    }

    final random = Random();
    final suffix = (1000 + random.nextInt(9000)).toString();
    return '$handle$suffix';
  }
}
