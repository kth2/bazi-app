import 'app_update_io.dart'
    if (dart.library.js_interop) 'app_update_web.dart' as impl;

/// Build identity, injected at compile time by CI:
///   `flutter build web --dart-define=APP_BUILD_ID=<commit sha>`
///
/// Local and ad-hoc builds leave it as [kDevBuildId], which disables update
/// checking — there is no published build.json to compare against.
const String kBuildId =
    String.fromEnvironment('APP_BUILD_ID', defaultValue: kDevBuildId);

const String kDevBuildId = 'dev';

/// Decides whether the running app is out of date.
///
/// Flutter 3.44 ships a service worker that unregisters itself on activate, so
/// there is no cache layer to hook a PWA update into. Instead the deployed
/// build writes its commit sha to build.json and the running app compares that
/// against the id compiled into it.
class UpdateChecker {
  final String localBuildId;
  final Future<String?> Function() fetchRemoteBuildId;

  const UpdateChecker({
    required this.localBuildId,
    required this.fetchRemoteBuildId,
  });

  UpdateChecker.forApp()
      : localBuildId = kBuildId,
        fetchRemoteBuildId = impl.fetchRemoteBuildId;

  /// Checking only makes sense for a build that CI stamped.
  bool get isEnabled => localBuildId != kDevBuildId && localBuildId.isNotEmpty;

  /// True when the server is serving a different build than this one.
  ///
  /// Any failure — offline, 404, malformed json — is treated as "no update".
  /// A background check must never interrupt someone mid-reading because the
  /// network blipped.
  Future<bool> hasUpdate() async {
    if (!isEnabled) return false;
    final remote = await fetchRemoteBuildId();
    if (remote == null || remote.isEmpty) return false;
    return remote != localBuildId;
  }
}

/// Reloads the page so the new build is picked up. No-op off the web.
Future<void> applyUpdate() => impl.reloadApp();
