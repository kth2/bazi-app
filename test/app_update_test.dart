import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/update/app_update.dart';
import 'package:bazi_app/features/update/update_banner.dart';

UpdateChecker checker(String local, String? remote, {bool throws = false}) =>
    UpdateChecker(
      localBuildId: local,
      fetchRemoteBuildId: () async {
        if (throws) throw Exception('network down');
        return remote;
      },
    );

void main() {
  group('UpdateChecker', () {
    test('a different deployed build id means an update is available',
        () async {
      expect(await checker('abc123', 'def456').hasUpdate(), isTrue);
    });

    test('the same build id means no update', () async {
      expect(await checker('abc123', 'abc123').hasUpdate(), isFalse);
    });

    test('unstamped local builds never check', () async {
      // A developer running `flutter run` has no published build.json to
      // compare against; prompting them would be noise.
      final c = checker(kDevBuildId, 'def456');
      expect(c.isEnabled, isFalse);
      expect(await c.hasUpdate(), isFalse);
      expect(UpdateChecker(localBuildId: '', fetchRemoteBuildId: () async => 'x')
          .isEnabled, isFalse);
    });

    test('a missing or empty remote id is treated as no update', () async {
      // Being offline must never surface a spurious update prompt.
      expect(await checker('abc123', null).hasUpdate(), isFalse);
      expect(await checker('abc123', '').hasUpdate(), isFalse);
    });

    test('the default build id is the dev sentinel outside CI', () {
      // No --dart-define in a test run, so this proves the default path.
      expect(kBuildId, kDevBuildId);
    });
  });

  group('UpdateWatcher', () {
    Widget wrap(UpdateChecker c, {Future<void> Function()? onApply}) =>
        MaterialApp(
          home: UpdateWatcher(
            checker: c,
            onApply: onApply,
            startupDelay: const Duration(milliseconds: 10),
            interval: const Duration(minutes: 30),
            child: const Scaffold(body: Text('内容')),
          ),
        );

    testWidgets('no banner when the build is current', (tester) async {
      await tester.pumpWidget(wrap(checker('abc', 'abc')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('有新版本可用'), findsNothing);
      expect(find.text('内容'), findsOneWidget);
    });

    testWidgets('banner appears when a newer build is deployed',
        (tester) async {
      await tester.pumpWidget(wrap(checker('abc', 'def')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('有新版本可用'), findsOneWidget);
      expect(find.text('立即更新'), findsOneWidget);
      // The app underneath stays usable — this is a prompt, not a takeover.
      expect(find.text('内容'), findsOneWidget);
    });

    testWidgets('update is applied only when the user asks', (tester) async {
      var applied = 0;
      await tester.pumpWidget(
          wrap(checker('abc', 'def'), onApply: () async => applied++));
      await tester.pump(const Duration(milliseconds: 50));

      // Detected, but nothing reloaded yet — unsaved form data is safe.
      expect(applied, 0);

      await tester.tap(find.text('立即更新'));
      await tester.pump();
      expect(applied, 1);
    });

    testWidgets('the prompt can be dismissed', (tester) async {
      await tester.pumpWidget(wrap(checker('abc', 'def')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('有新版本可用'), findsOneWidget);

      await tester.tap(find.byTooltip('稍后'));
      await tester.pump();
      expect(find.text('有新版本可用'), findsNothing);
    });

    testWidgets('a failing check is silent', (tester) async {
      await tester.pumpWidget(wrap(
        UpdateChecker(
          localBuildId: 'abc',
          fetchRemoteBuildId: () async => null,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('有新版本可用'), findsNothing);
    });

    testWidgets('an unstamped build starts no timers', (tester) async {
      // Guards against a dev build polling forever in the background.
      await tester.pumpWidget(wrap(checker(kDevBuildId, 'def')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('有新版本可用'), findsNothing);
      // No pending timers means the widget can be torn down cleanly.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
