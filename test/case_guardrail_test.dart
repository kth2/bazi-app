import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app's stated principle is 理论固定，推演结构化，AI负责解释 — history is
/// kept so a person can judge the theory, never so the program can quietly
/// rewrite it.
///
/// The case journal makes real-world outcomes available in the app for the
/// first time, which is exactly the substrate an "adjust the weights from
/// feedback" change would reach for. This test makes the dependency direction
/// one-way and enforceable: the engine cannot import the case store, so
/// feedback cannot reach 格局 detection, rule weights or 应期 scoring without
/// someone deliberately deleting this test.
void main() {
  /// Layers that decide what the chart *means*. None may read user outcomes.
  ///
  /// `core/timeline` is in the list because the life timeline is where
  /// recorded outcomes and predicted events sit side by side on one axis —
  /// the most tempting place in the app to let what happened adjust what the
  /// rules say will happen. It may read the chart; it may not read the
  /// journal.
  const engineDirs = [
    'lib/core/analysis',
    'lib/core/rules',
    'lib/core/engine',
    'lib/core/models',
    'lib/core/timeline',
  ];

  List<File> dartFilesIn(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  group('feedback never flows back into the theory', () {
    test('no engine file imports the case store', () {
      final offenders = <String>[];
      for (final dir in engineDirs) {
        for (final file in dartFilesIn(dir)) {
          final source = file.readAsStringSync();
          for (final line in source.split('\n')) {
            final trimmed = line.trim();
            if (!trimmed.startsWith('import ') &&
                !trimmed.startsWith('export ') &&
                !trimmed.startsWith('part ')) {
              continue;
            }
            if (trimmed.contains('cases/') ||
                trimmed.contains('case_record') ||
                trimmed.contains('cases_db') ||
                trimmed.contains('case_provider')) {
              offenders.add('${file.path}: $trimmed');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'The reasoning engine must not read recorded outcomes.\n'
            'If feedback is ever meant to inform the theory, that has to be a '
            'deliberate, reviewed decision — not an import.\n'
            'Offending lines:\n${offenders.join('\n')}',
      );
    });

    test('the engine directories exist and were actually scanned', () {
      // Guards against the test silently passing because a path was renamed.
      for (final dir in engineDirs) {
        expect(Directory(dir).existsSync(), isTrue, reason: dir);
        expect(dartFilesIn(dir), isNotEmpty, reason: dir);
      }
      expect(dartFilesIn('lib/core/cases'), isNotEmpty);
    });

    test('the case store may depend on the engine, but not the reverse', () {
      // One-way is the point: cases snapshot what the engine produced.
      final caseSources = [
        for (final f in dartFilesIn('lib/core/cases')) f.readAsStringSync(),
      ].join('\n');
      expect(caseSources, contains('analysis/reasoning_report.dart'));
    });

    test('no rule weight or seed asset is written at runtime', () {
      // Rule weights live in the bundled asset and the read-only rules cache.
      // Nothing outside the seeding path may write them.
      final offenders = <String>[];
      for (final dir in [...engineDirs, 'lib/core/cases', 'lib/features']) {
        for (final file in dartFilesIn(dir)) {
          final source = file.readAsStringSync();
          if (source.contains('seed_rules.json') &&
              (source.contains('writeAsString') ||
                  source.contains('File(') && source.contains('write'))) {
            offenders.add(file.path);
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'seed_rules.json is authored, not learned');
    });
  });
}
