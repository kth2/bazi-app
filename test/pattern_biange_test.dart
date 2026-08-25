import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/analysis/pattern_detector.dart';
import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/models/birth_input.dart';
import 'package:bazi_app/core/models/chart_result.dart';

ChartResult _chart(int y, int m, int d, int h) =>
    ChartService.compute(BirthInput(
      calendarType: CalendarType.solar,
      year: y,
      month: m,
      day: d,
      hour: h,
      minute: 0,
      gender: Gender.male,
      location: '北京',
      longitude: 116.41,
    ));

ChartPattern _pattern(int y, int m, int d, int h) =>
    PatternDetector.detect(_chart(y, m, d, h));

/// Every 正格 name the detector can emit from the month order.
const _zhengGeNames = {
  '正官格', '七杀格', '正印格', '偏印格', '食神格', '伤官格',
  '正财格', '偏财格', '建禄格', '阳刃格', '月劫格',
};

void main() {
  group('变格 replaces 正格 instead of coexisting with it', () {
    test('辛酉 庚子 癸亥 壬子 — 金水旺极、官杀无根 → 从旺格', () {
      final c = _chart(1981, 12, 11, 1);
      expect(c.baziString, '辛酉 庚子 癸亥 壬子');
      final p = PatternDetector.detect(c);

      expect(p.isBianGe, isTrue);
      expect(p.geJu, '从旺格');
      expect(p.tags, containsAll(['变格', '从格', '从旺格']));
      // The whole point: no 正格 label survives alongside the 变格.
      expect(p.tags.intersection(_zhengGeNames), isEmpty);
      expect(p.geJu, isNot(anyOf(_zhengGeNames.map(equals))));
      // 用神 must be 顺势, not 取中和.
      expect(p.yongShen, contains('顺'));
      expect(p.summary, contains('变格'));
    });

    test('辛酉 辛卯 戊子 乙卯 — 戊土无根无火印、卯木官杀当令 → 从杀格', () {
      final c = _chart(1981, 3, 11, 7);
      expect(c.baziString, '辛酉 辛卯 戊子 乙卯');
      final p = PatternDetector.detect(c);

      expect(p.isBianGe, isTrue);
      expect(p.geJu, '从杀格');
      expect(p.tags, containsAll(['变格', '从格', '从弱格']));
      expect(p.tags.intersection(_zhengGeNames), isEmpty);
    });

    test('从财格 named from the dominant party, not the month order', () {
      final p = _pattern(1981, 1, 19, 1);
      expect(p.geJu, '从财格');
      expect(p.isBianGe, isTrue);
      expect(p.yongShen, contains('财星'));
    });
  });

  group('正格 charts stay 正格', () {
    test('己丑 癸酉 甲子 己巳 — 身弱但印重，绝非从格', () {
      final p = _pattern(1949, 10, 1, 10);
      expect(p.isBianGe, isFalse);
      expect(p.geJu, '正官格');
      expect(p.tags, isNot(contains('变格')));
      expect(p.tags, isNot(contains('从格')));
    });

    test('丙日子月 stays 正官格 with no 变格 leakage', () {
      final p = _pattern(1990, 1, 1, 12);
      expect(p.isBianGe, isFalse);
      expect(p.geJu, '正官格');
      expect(p.tags, isNot(contains('变格')));
    });
  });

  group('假从 is a note on a 正格, never a second 格局', () {
    test('身弱已极却有根/有印 → 正格 + 假从注记，且不产生变格标签', () {
      // Scan a small grid for a chart that trips the note.
      ChartPattern? noted;
      for (var m = 1; m <= 12 && noted == null; m++) {
        for (final d in [3, 11, 19, 27]) {
          final p = _pattern(1985, m, d, 13);
          if (p.specialScenarios.any((s) => s.contains('假从'))) {
            noted = p;
            break;
          }
        }
      }
      expect(noted, isNotNull, reason: '1985 grid should contain a 假从 chart');
      expect(noted!.isBianGe, isFalse);
      expect(noted.tags, isNot(contains('变格')));
      // The prose note must not leak into the matchable tag set.
      expect(noted.tags.any((t) => t.contains('假从')), isFalse);
    });
  });
}
