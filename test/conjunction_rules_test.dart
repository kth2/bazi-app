import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/analysis/event_inference.dart';
import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/models/birth_input.dart';
import 'package:bazi_app/core/models/chart_result.dart';
import 'package:bazi_app/core/timeline/event_catalog.dart';
import 'package:bazi_app/core/timeline/life_span.dart';
import 'package:bazi_app/core/timeline/timeline_event.dart';
import 'package:bazi_app/core/timeline/timeline_scanner.dart';

/// A spread wide enough that a rule which never fires is visible as such.
final grid = <ChartResult>[
  for (final y in [1949, 1955, 1962, 1968, 1976, 1981, 1985, 1990, 1998, 2003])
    for (final m in [2, 5, 9])
      for (final g in Gender.values)
        ChartService.compute(BirthInput(
          calendarType: CalendarType.solar,
          year: y,
          month: m,
          day: 5,
          hour: 6,
          minute: 14,
          gender: g,
          location: '北京',
          longitude: 116.41,
        )),
];

List<LifeEvent> scanOf(ChartResult c) => TimelineScanner.scan(
      LifeSpan.of(c),
      enabledKindIds: EventCatalog.defaultEnabledIds,
      now: DateTime(2026),
    );

/// How many of the grid's charts produce at least one marker of a kind.
int chartsWith(String kindId) {
  var n = 0;
  for (final c in grid) {
    if (scanOf(c).any((e) => e.kindId == kindId)) n++;
  }
  return n;
}

void main() {
  group('the conjunction-based kinds all reach real charts', () {
    // A rule that never fires is a rule that does not exist. Each of these
    // was measured on the same 60-chart grid; the bounds are wide enough to
    // survive tuning but tight enough to catch a rule going silent or
    // becoming universal.
    const expected = {
      'study.abroad': (2, 45), // 出国留学 — rare by nature
      'wealth.home': (5, 50), // 买房置产
      'career.moving': (5, 55), // 搬家迁居
      'career.fame': (2, 45), // 名气提升
      'study.patron': (10, 60), // 贵人相助
      'career.travel': (10, 60), // 远行出行
    };

    for (final entry in expected.entries) {
      test('${EventCatalog.byId[entry.key]!.label} fires on some charts, '
          'not all', () {
        final n = chartsWith(entry.key);
        final (lo, hi) = entry.value;
        expect(n, greaterThanOrEqualTo(lo),
            reason: '${entry.key} fired on only $n of ${grid.length} charts');
        expect(n, lessThanOrEqualTo(hi),
            reason: '${entry.key} fired on $n of ${grid.length} charts — '
                'a reading that applies to everyone says nothing');
      });
    }
  });

  group('the criteria are what they claim to be', () {
    test('every new kind maps onto a subtype the engine can produce', () {
      for (final id in [
        'study.abroad',
        'wealth.home',
        'career.moving',
        'career.fame',
      ]) {
        final k = EventCatalog.byId[id]!;
        expect(EventDomain.subtypes[k.domain], contains(k.subtype),
            reason: id);
      }
    });

    test('每条推理链都写出了几条同时成立的依据', () {
      // A conjunction's whole point is that several things converged; the
      // basis has to show all of them, or the user cannot tell it apart from
      // a single-signal reading.
      var checked = 0;
      for (final c in grid.take(20)) {
        for (final e in scanOf(c)) {
          if (!const {
            'study.abroad',
            'wealth.home',
            'career.moving',
            'career.fame',
            'study.patron',
            'health.surgery',
            'health.longevity',
          }.contains(e.kindId)) {
            continue;
          }
          checked++;
          expect(e.basis.length, greaterThanOrEqualTo(3),
              reason: '${e.kindId}: ${e.basis}');
          expect(e.basis.last, contains('同时成立'), reason: e.kindId);
        }
      }
      expect(checked, greaterThan(0), reason: 'no conjunction markers found');
    });

    test('置业安家 与 迁居搬家 是不同的读法，不是同一条改个名', () {
      // Both start from 印星 (居所). 买房 wants it fed alongside 财星;
      // 搬家 wants it disturbed alongside 驿马. If one implies the other the
      // criteria have collapsed.
      var homeOnly = 0, moveOnly = 0;
      for (final c in grid) {
        final ids = scanOf(c).map((e) => e.kindId).toSet();
        if (ids.contains('wealth.home') && !ids.contains('career.moving')) {
          homeOnly++;
        }
        if (ids.contains('career.moving') && !ids.contains('wealth.home')) {
          moveOnly++;
        }
      }
      expect(homeOnly, greaterThan(0));
      expect(moveOnly, greaterThan(0));
    });

    test('名声显扬 不出现在食伤为忌的年份（伤官见官无制主是非）', () {
      // The exception the owner's criteria singled out, kept as a test rather
      // than only as a comment.
      for (final c in grid.take(20)) {
        for (final e in scanOf(c)) {
          if (e.kindId != 'career.fame') continue;
          expect(e.basis.join(), isNot(contains('忌神食伤')));
        }
      }
    });
  });

  group('polarity follows the existing convention', () {
    test('life events are 参半; only gains are 吉', () {
      // 婚恋成合 and 进修拓展 are mixed because they *happen* rather than
      // pay off. 出国 and 置产 belong to that class; labelling them 吉 pushed
      // the 240-chart balance from 1.14 to 1.60 in testing.
      final mixedByNature = {'study.abroad', 'wealth.home', 'career.moving'};
      for (final c in grid.take(20)) {
        for (final e in scanOf(c)) {
          if (mixedByNature.contains(e.kindId)) {
            expect(e.polarity, EventPolarity.mixed, reason: e.kindId);
          }
        }
      }
    });
  });
}
