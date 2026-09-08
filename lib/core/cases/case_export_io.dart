import 'dart:io';

/// Non-web fallback: write the export beside the system temp directory and
/// report the path. Used by tests and any desktop/mobile build.
Future<String> saveJsonFile(String filename, String content) async {
  final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}'
      '$filename');
  await file.writeAsString(content);
  return '已导出到 ${file.path}';
}
