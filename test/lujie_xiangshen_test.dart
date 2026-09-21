import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/analysis/natal_structure.dart';
import 'package:bazi_app/core/analysis/pattern_detector.dart';
import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/models/birth_input.dart';
import 'package:bazi_app/core/models/chart_result.dart';

final grid = <ChartResult>[
  for (var y = 1960; y <= 2000; y += 2)
    for (final m in [2, 5, 8, 11])
      for (final d in [7, 21])
        for (final g in Gender.values)
          ChartService.compute(BirthInput(
            calendarType: CalendarType.solar,
            year: y,
            month: m,
            day: d,
            hour: 10,
            minute: 0,
            gender: g,
            location: '北京',
            longitude: 116.41,
          )),
];

/// 建禄 / 月劫 / 阳刃 — the 格 whose 月令 is 比劫 and so cannot be its own 用.
Iterable<(ChartResult, ChartPattern, NatalStructure)> luJieCharts() sync* {
  for (final c in grid) {
    final p = PatternDetector.detect(c);
    if (p.luJieYong == null) continue;
    yield (c, p, NatalStructureResolver.resolve(c, p));
  }
}

void main() {
  test('the grid actually contains 禄劫刃 charts to test', () {
    expect(luJieCharts().length, greaterThan(20));
  });

  group('相神 completes the 用神; it is never the 用神 itself', () {
    test('no 禄劫刃 chart takes its own 用神 group as 相神', () {
      // The defect: the spec's list for these 格 is the *用神 candidate* set
      // (官杀/食伤/财星), and it was being consumed as the 相神 set. Whichever
      // group the 用神 came from therefore stayed in and became its own
      // 相神 — 13 of 16 real charts came out 「用神 甲正官，相神 官杀」.
      for (final (c, p, s) in luJieCharts()) {
        final own = NatalStructureResolver.groupOfShiShen(p.luJieYong!);
        expect(s.xiangShen, isNot(contains(own)),
            reason: '${c.baziString} ${p.geJu}: 用神 ${p.luJieYong} '
                '相神 ${s.xiangShen}');
      }
    });

    test('每一条相神都出自《子平真诠》禄劫取用之后的配置', () {
      const expected = {
        '正官': {'财星', '印星'},
        '七杀': {'食伤', '财星'},
        '正财': {'食伤'},
        '偏财': {'食伤'},
        '食神': {'财星'},
        '伤官': {'财星'},
      };
      for (final (c, p, s) in luJieCharts()) {
        final allowed = expected[p.luJieYong!]!;
        for (final x in s.xiangShen) {
          expect(allowed, contains(x),
              reason: '${c.baziString} ${p.geJu}: 用神 ${p.luJieYong} '
                  '得相神 $x');
        }
      }
    });

    test('阳刃用官杀取财为相神，不取食伤', () {
      // 刃是凶神逆用，官杀是制刃之具；食伤制杀反而卸掉了制刃的力量，
      // 所以禄劫「用杀须食伤制之」那一条不适用于阳刃。
      var checked = 0;
      for (final (c, p, s) in luJieCharts()) {
        if (p.geJu != '阳刃格') continue;
        if (p.luJieYong != '正官' && p.luJieYong != '七杀') continue;
        checked++;
        expect(s.xiangShen, isNot(contains('食伤')), reason: c.baziString);
      }
      expect(checked, greaterThan(0), reason: '没有阳刃用官杀的盘可测');
    });
  });

  group('the consequence is a real 成败 judgement, not a rubber stamp', () {
    test('禄劫刃 charts are no longer almost all 成格', () {
      // With the 用神 acting as its own 相神, the 相神 was present by
      // construction and these charts came out 成格 nearly every time. A
      // 禄劫 chart that takes 食伤 for 用 and has no 财 to give it an outlet
      // is 破格 in the classics, and should read that way here.
      final statuses = [for (final (_, _, s) in luJieCharts()) s.status];
      final cheng =
          statuses.where((s) => s == GeJuStatus.cheng).length / statuses.length;
      expect(cheng, lessThan(0.85),
          reason: '${(cheng * 100).round()}% 成格 — 相神 still free');
      expect(cheng, greaterThan(0.15),
          reason: '${(cheng * 100).round()}% 成格 — now too harsh');
    });

    test('a 相神 that is named is a 相神 that can act', () {
      for (final (c, _, s) in luJieCharts()) {
        for (final x in s.xiangShen) {
          expect(s.presence[x]!.isOperative, isTrue,
              reason: '${c.baziString}: 相神 $x 却不可用');
        }
      }
    });
  });

  group('禄劫 取用 order is unchanged', () {
    test('有杀先论杀，有官次之，无官杀再寻食伤财', () {
      const order = ['七杀', '正官', '食神', '伤官', '正财', '偏财'];
      for (final (c, p, _) in luJieCharts()) {
        final picked = p.luJieYong!;
        final rank = order.indexOf(picked);
        expect(rank, isNot(-1), reason: '$picked not in the order');
        // Nothing earlier in the order may be transparent in the stems.
        for (var i = 0; i < rank; i++) {
          final earlier = order[i];
          final transparent = c.pillars
              .any((x) => x.ganShiShen == earlier);
          expect(transparent, isFalse,
              reason: '${c.baziString}: picked $picked but $earlier 透干');
        }
      }
    });
  });
}
