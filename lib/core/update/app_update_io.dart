/// Non-web builds are not served from a web server and have no build.json to
/// poll, so update checking is inert here.
Future<String?> fetchRemoteBuildId() async => null;

Future<void> reloadApp() async {}
