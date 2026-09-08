import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Reads the deployed build id from build.json, which CI writes next to
/// index.html with the commit sha it built from.
///
/// Fetched with cache: 'no-store' and a cache-busting query, since the whole
/// point is to see past whatever the browser and CDN have cached.
Future<String?> fetchRemoteBuildId() async {
  try {
    final url = 'build.json?t=${DateTime.now().millisecondsSinceEpoch}';
    final response = await web.window
        .fetch(url.toJS, web.RequestInit(cache: 'no-store'))
        .toDart;
    if (!response.ok) return null;
    final body = (await response.text().toDart).toDart;
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    final id = decoded['buildId'];
    return id is String && id.isNotEmpty ? id : null;
  } catch (_) {
    // Offline, blocked, or malformed — treated as "no update available".
    return null;
  }
}

Future<void> reloadApp() async => web.window.location.reload();
