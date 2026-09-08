import 'case_export_io.dart'
    if (dart.library.js_interop) 'case_export_web.dart' as impl;

/// Hands the user a JSON file of their case journal.
///
/// On the web build this triggers a real browser download, which is the point:
/// a clipboard copy cannot be attached to an email or dropped in a chat. The
/// non-web build writes the file to disk and reports the path.
class CaseExport {
  /// A stable, sortable filename: bazi_cases_2026-08-14_1530.json
  static String filenameFor(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'bazi_cases_${at.year}-${two(at.month)}-${two(at.day)}'
        '_${two(at.hour)}${two(at.minute)}.json';
  }

  /// Filename for a single exported case, tagged with its 八字 so several
  /// exports remain distinguishable.
  static String filenameForCase(String baziString, DateTime at) {
    final slug = baziString.replaceAll(RegExp(r'\s+'), '');
    String two(int n) => n.toString().padLeft(2, '0');
    return 'bazi_case_${slug}_${at.year}-${two(at.month)}-${two(at.day)}.json';
  }

  /// Saves [content] as [filename]. Returns a message describing where it
  /// went, for display to the user.
  static Future<String> save(String filename, String content) =>
      impl.saveJsonFile(filename, content);
}
