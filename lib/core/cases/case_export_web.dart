import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web build: hand the browser a Blob and click a synthetic download link.
///
/// The object URL is revoked afterwards; without that the whole JSON payload
/// stays pinned in memory for the life of the tab.
Future<String> saveJsonFile(String filename, String content) async {
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return '已下载 $filename';
}
