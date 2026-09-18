import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/analysis/natal_structure.dart';
import 'package:bazi_app/core/analysis/pattern_detector.dart';
import 'package:bazi_app/core/analysis/shi_shen_presence.dart';
import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/models/birth_input.dart';
import 'package:bazi_app/core/models/chart_result.dart';

ChartResult chartOf(int y, int m, int d, int h, int min, Gender g) =>
    ChartService.compute(BirthInput(
      calendarType: CalendarType.solar,
      year: y,
      month: m,
      day: d,
      hour: h,
      minute: min,
      gender: g,
      location: '北京',
      longitude: 116.41,
    ));

/// The chart that exposed the bug: 癸巳 戊午 癸巳 乙卯, 男.
final reported = chartOf(1953, 6, 11, 6, 14, Gender.male);

final grid = <ChartResult>[
  for (var y = 1970; y <= 1998; y += 2)
    for (final m in [2, 5, 8, 11])
      for (final d in [7, 21])
        for (final g in Gender.values) chartOf(y, m, d, 10, 0, g),
];

void main() {
  group('a scenario may not contradict the report it ships in', () {
    test('印-based scenarios need a 印 the engine calls usable', () {
      // The defect: 官印相生 was emitted whenever a 印 appeared anywhere,
      // 藏干 included. One report could then say 印星「仅见其气」 and tag the
      // chart 官印相生 at the same time.
      var checked = 0;
      for (final c in grid) {
        final p = PatternDetector.detect(c);
        final presence = ShiShenPresenceTable.of(c);
        for (final name in ['官印相生', '杀印相生']) {
          if (!p.specialScenarios.contains(name)) continue;
          checked++;
          expect(presence['印星']!.isOperative, isTrue,
              reason: '${c.baziString}: $name with '
                  '印星 ${presence['印星']!.strength.toStringAsFixed(1)}% '
                  '(${presence['印星']!.level})');
          expect(presence['官杀']!.isOperative, isTrue,
              reason: '${c.baziString}: $name');
        }
      }
      expect(checked, greaterThan(0), reason: 'no chart tested the gate');
    });

    test('食伤生财 needs both halves to be able to act', () {
      for (final c in grid) {
        final p = PatternDetector.detect(c);
        if (!p.specialScenarios.contains('食伤生财')) continue;
        final presence = ShiShenPresenceTable.of(c);
        expect(presence['食伤']!.isOperative, isTrue, reason: c.baziString);
        expect(presence['财星']!.isOperative, isTrue, reason: c.baziString);
      }
    });

    test('no scenario rests on a 十神 the chart does not even have', () {
      for (final c in grid) {
        final p = PatternDetector.detect(c);
        final presence = ShiShenPresenceTable.of(c);
        for (final s in p.scenarios) {
          expect(s.strength, greaterThan(0),
              reason: '${c.baziString}: ${s.name} rests on nothing');
        }
        // Every scenario's strength must be one a group actually holds.
        for (final s in p.scenarios) {
          final holders = ShiShenPresenceTable.kGroups
              .map((g) => presence[g]!.strength)
              .toList();
          expect(holders.any((h) => (h - s.strength).abs() < 0.05), isTrue,
              reason: '${c.baziString}: ${s.name} strength ${s.strength} '
                  'matches no group');
        }
      }
    });
  });

  group('the reported chart, 癸巳 戊午 癸巳 乙卯', () {
    late ChartPattern pattern;
    late NatalStructure structure;

    setUp(() {
      pattern = PatternDetector.detect(reported);
      structure = NatalStructureResolver.resolve(reported, pattern);
    });

    test('is the chart in question', () {
      expect(reported.baziString, '癸巳 戊午 癸巳 乙卯');
      expect(structure.presence['印星']!.strength, lessThan(5));
      expect(structure.presence['印星']!.isOperative, isFalse);
    });

    test('no longer claims 官印相生 or 杀印相生', () {
      expect(pattern.specialScenarios, isNot(contains('官印相生')));
      expect(pattern.specialScenarios, isNot(contains('杀印相生')));
    });

    test('names the 争合 that the narrative kept flattening', () {
      // 年干癸 and 日干癸 both reach for 月干戊. Told as a plain two-party
      // 合 it reads 「官星合日主，贵气所系」; it is in fact contested.
      final zhengHe =
          pattern.specialScenarios.where((s) => s.startsWith('争合')).toList();
      expect(zhengHe, hasLength(1));
      expect(zhengHe.single, contains('正官戊'));
      expect(zhengHe.single, contains('其应不专'));
    });

    test('still reports 比劫合官, which was correct all along', () {
      expect(pattern.specialScenarios, contains('比劫合官'));
    });
  });

  group('scenarios are ordered and quantified', () {
    test('strongest first', () {
      for (final c in grid) {
        final s = PatternDetector.detect(c).scenarios;
        for (var i = 1; i < s.length; i++) {
          expect(s[i - 1].strength, greaterThanOrEqualTo(s[i].strength),
              reason: c.baziString);
        }
      }
    });

    test('each carries its weakest party\'s share', () {
      final p = PatternDetector.detect(reported);
      for (final s in p.scenarios) {
        expect(s.label, contains('%'));
      }
    });

    test('a chart is no longer tagged with everything at once', () {
      // Measured before the gate: mean 4.4 scenarios per chart, up to 9,
      // with 食伤生财 on 95% of charts — a label that applies to almost
      // everyone carries no information.
      final counts = [for (final c in grid) PatternDetector.detect(c).scenarios.length];
      final mean = counts.reduce((a, b) => a + b) / counts.length;
      expect(mean, lessThan(3.5), reason: 'mean $mean');
      expect(counts.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(7));

      final freq = <String, int>{};
      for (final c in grid) {
        for (final s in PatternDetector.detect(c).specialScenarios) {
          freq[s] = (freq[s] ?? 0) + 1;
        }
      }
      for (final e in freq.entries) {
        if (e.key.startsWith('争合')) continue;
        expect(e.value / grid.length, lessThan(0.5),
            reason: '${e.key} fires on '
                '${(e.value / grid.length * 100).round()}% of charts');
      }
    });
  });

  group('争合 detection', () {
    test('needs three parties to one 合, not two', () {
      for (final c in grid) {
        final p = PatternDetector.detect(c);
        final hasZhengHe =
            p.specialScenarios.any((s) => s.startsWith('争合'));
        final threeWay = c.interactions.any(
            (i) => i.type.contains('五合') && i.parties.length >= 3);
        if (hasZhengHe) {
          expect(threeWay, isTrue, reason: '${c.baziString}: 争合 without a '
              'three-party 合');
        }
      }
    });

    test('stays out of the example-matching tags', () {
      // A 争合 label names this chart's own stems; it could never match a
      // corpus tag, and would only dilute the lookup.
      for (final c in grid) {
        final p = PatternDetector.detect(c);
        expect(p.tags.any((t) => t.startsWith('争合')), isFalse,
            reason: c.baziString);
      }
    });
  });
}
