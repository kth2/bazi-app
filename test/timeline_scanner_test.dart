import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/analysis/activation_engine.dart';
import 'package:bazi_app/core/analysis/event_inference.dart';
import 'package:bazi_app/core/analysis/natal_structure.dart';
import 'package:bazi_app/core/analysis/pattern_detector.dart';
import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/models/birth_input.dart';
import 'package:bazi_app/core/models/chart_result.dart';
import 'package:bazi_app/core/timeline/event_catalog.dart';
import 'package:bazi_app/core/timeline/life_span.dart';
import 'package:bazi_app/core/timeline/timeline_event.dart';
import 'package:bazi_app/core/timeline/timeline_scanner.dart';

ChartResult chartOf(int y, int m, int d, int h, Gender g) =>
    ChartService.compute(BirthInput(
      calendarType: CalendarType.solar,
      year: y,
      month: m,
      day: d,
      hour: h,
      minute: 0,
      gender: g,
      location: '北京',
      longitude: 116.41,
    ));

final samples = <String, ChartResult>{
  '丙辰 壬辰 丁巳 (女)': chartOf(1976, 5, 5, 6, Gender.female),
  '己巳 丙子 丙寅 (男)': chartOf(1990, 1, 1, 12, Gender.male),
  '己丑 癸酉 甲子 (男)': chartOf(1949, 10, 1, 10, Gender.male),
  '辛酉 庚子 癸亥 (女)': chartOf(1981, 12, 11, 1, Gender.female),
};

List<LifeEvent> scanOf(ChartResult c, {Set<String>? kinds}) =>
    TimelineScanner.scan(
      LifeSpan.of(c),
      enabledKindIds: kinds ?? EventCatalog.defaultEnabledIds,
      now: DateTime(2026),
    );

void main() {
  _shenShaTests();

  group('the catalog is a faithful translation of the engine', () {
    test('every kind maps onto a subtype the engine can actually produce', () {
      for (final k in EventCatalog.kinds) {
        final subtypes = EventDomain.subtypes[k.domain];
        expect(subtypes, isNotNull, reason: '${k.id}: unknown domain ${k.domain}');
        expect(subtypes, contains(k.subtype), reason: k.id);
      }
    });

    test('ids and engine keys are unique', () {
      expect(EventCatalog.byId.length, EventCatalog.kinds.length);
      expect(EventCatalog.byEngineKey.length, EventCatalog.kinds.length);
    });

    test('every guarded kind carries a disclaimer', () {
      expect(EventCatalog.guarded, isNotEmpty);
      for (final k in EventCatalog.guarded) {
        expect(k.disclaimer, isNotNull, reason: k.id);
        expect(k.disclaimer, isNotEmpty, reason: k.id);
      }
    });

    test('破财风险 is shown by default, per the confirmed 口径', () {
      final loss = EventCatalog.byId['wealth.loss']!;
      expect(loss.sensitivity, EventSensitivity.normal);
      expect(EventCatalog.defaultEnabledIds, contains('wealth.loss'));
    });

    test('no kind marks 寿元, and health carries no upper age bound', () {
      for (final k in EventCatalog.kinds) {
        expect(k.label, isNot(contains('寿')));
        if (k.domain == EventDomain.health) {
          expect(k.maxAge, isNull, reason: k.id);
        }
      }
    });
  });

  group('a scan is legible rather than exhaustive', () {
    test('a whole life yields tens of markers, not hundreds', () {
      for (final entry in samples.entries) {
        final events = scanOf(entry.value);
        expect(events.length, greaterThan(10), reason: entry.key);
        expect(events.length, lessThan(60), reason: entry.key);
      }
    });

    test('no single kind dominates the whole life', () {
      // The first cut of the ranking produced 「职场是非×12」 out of 36
      // markers — one kind claiming a slot in every decade says nothing.
      for (final entry in samples.entries) {
        final counts = <String, int>{};
        for (final e in scanOf(entry.value)) {
          counts[e.kindId] = (counts[e.kindId] ?? 0) + 1;
        }
        for (final c in counts.entries) {
          expect(c.value, lessThanOrEqualTo(TimelineScanner.kMaxPerKind),
              reason: '${entry.key}: ${c.key}');
        }
        expect(counts.length, greaterThanOrEqualTo(6),
            reason: '${entry.key}: only ${counts.length} distinct kinds');
      }
    });

    test('no 大运 step is crowded past its quota', () {
      for (final entry in samples.entries) {
        final span = LifeSpan.of(entry.value);
        for (final d in span.decades) {
          final (from, to) = span.boundsOf(d);
          final inStep = scanOf(entry.value)
              .where((e) =>
                  e.anchor.startAge >= from && e.anchor.startAge < to)
              .length;
          expect(inStep, lessThanOrEqualTo(TimelineScanner.kMaxPerDecade),
              reason: '${entry.key}: 大运 ${d.ganZhi} has $inStep markers');
        }
      }
    });
  });

  group('markers land at ages they could mean something at', () {
    test('nothing is suggested outside its kind\'s age bounds', () {
      for (final entry in samples.entries) {
        for (final e in scanOf(entry.value)) {
          final kind = e.kind!;
          expect(kind.suits(e.anchor.startAge.toInt()), isTrue,
              reason: '${entry.key}: ${kind.label} at ${e.anchor.startAge}');
        }
      }
    });

    test('no 婚恋 or 子女 marker in childhood', () {
      for (final entry in samples.entries) {
        for (final e in scanOf(entry.value)) {
          if (e.kindId == 'marriage.union') {
            expect(e.anchor.startAge, greaterThanOrEqualTo(16),
                reason: entry.key);
          }
          if (e.kindId == 'marriage.children') {
            expect(e.anchor.startAge, greaterThanOrEqualTo(20),
                reason: entry.key);
          }
        }
      }
    });
  });

  group('sensitive categories', () {
    test('are absent by default', () {
      for (final entry in samples.entries) {
        for (final e in scanOf(entry.value)) {
          expect(e.kind!.isGuarded, isFalse, reason: entry.key);
        }
      }
    });

    test('add markers when enabled rather than displacing others', () {
      // Sharing the ordinary quota would mean switching a category on and
      // seeing the same number of markers — or fewer of the ones you had.
      final all = {for (final k in EventCatalog.kinds) k.id};
      var everShown = 0;
      for (final entry in samples.entries) {
        final base = scanOf(entry.value);
        final opened = scanOf(entry.value, kinds: all);
        expect(opened.length, greaterThanOrEqualTo(base.length),
            reason: entry.key);
        final ordinary =
            opened.where((e) => !e.kind!.isGuarded).map((e) => e.id).toSet();
        expect(ordinary, containsAll(base.map((e) => e.id)),
            reason: '${entry.key}: an ordinary marker was pushed off');
        everShown += opened.where((e) => e.kind!.isGuarded).length;
      }
      expect(everShown, greaterThan(0),
          reason: 'guarded kinds never surfaced on any sample — '
              'the toggle would be dead');
    });
  });

  group('determinism and shape', () {
    test('two scans of the same chart are identical', () {
      final chart = samples.values.first;
      final a = scanOf(chart);
      final b = scanOf(chart);
      expect(a.map((e) => e.id).toList(), b.map((e) => e.id).toList());
    });

    test('events are ordered by age and anchored within the span', () {
      for (final entry in samples.entries) {
        final events = scanOf(entry.value);
        for (var i = 1; i < events.length; i++) {
          expect(events[i].anchor.startAge,
              greaterThanOrEqualTo(events[i - 1].anchor.startAge),
              reason: entry.key);
        }
        for (final e in events) {
          expect(e.anchor.startAge, greaterThanOrEqualTo(1), reason: entry.key);
          expect(e.anchor.endAge,
              lessThanOrEqualTo(LifeSpan.kMaxAge.toDouble()),
              reason: entry.key);
          expect(e.anchor.endAge, greaterThanOrEqualTo(e.anchor.startAge));
        }
      }
    });

    test('only span-shaped kinds produce spans', () {
      for (final entry in samples.entries) {
        for (final e in scanOf(entry.value)) {
          if (e.anchor.isSpan) {
            expect(e.kind!.defaultSpan, isTrue,
                reason: '${entry.key}: ${e.kind!.label} became a span');
          }
        }
      }
    });

    test('every suggested marker carries the chain that produced it', () {
      for (final entry in samples.entries) {
        for (final e in scanOf(entry.value)) {
          expect(e.origin, EventOrigin.suggested);
          expect(e.confidence, isNotNull, reason: entry.key);
          expect(e.confidence,
              greaterThanOrEqualTo(TimelineScanner.kMinConfidence));
          expect(e.basis, isNotEmpty, reason: entry.key);
          expect(e.polarity, isNotNull, reason: entry.key);
        }
      }
    });

    test('a full-life scan is fast enough to run on chart open', () {
      final sw = Stopwatch()..start();
      for (final c in samples.values) {
        scanOf(c);
      }
      sw.stop();
      // Budget is generous on purpose; the point is to catch a regression
      // that puts the 应期 engine back on the per-year path (7.5 ms/year,
      // ~900 ms per life).
      expect(sw.elapsedMilliseconds, lessThan(1500),
          reason: '${sw.elapsedMilliseconds}ms for ${samples.length} charts');
    });
  });
}

/// The two 神煞 that name an event when they arrive (P5).
void _shenShaTests() {
  group('岁运带驿马 / 天乙贵人', () {
    test('the reading is 岁运带, not 原局带', () {
      // 原局带驿马 is either true for a whole life or never, and so names no
      // year. The activation must come from the 岁运 pillar arriving as the
      // 驿马 of the natal chart.
      final chart = samples.values.first;
      final span = LifeSpan.of(chart);
      final withMarker = <int>[];
      for (final y in span.years) {
        final ctx = ChartService.temporalContext(
          chart,
          decade: span.decadeAt(y.age.toDouble()),
          year: y,
        );
        final marked = ctx.luckPillars.any((p) => p.shenSha.isNotEmpty);
        if (marked) withMarker.add(y.age);
      }
      expect(withMarker, isNotEmpty,
          reason: 'no year carries either 神煞 — the lookup is not running');
      expect(withMarker.length, lessThan(span.years.length),
          reason: 'every year carries one — this is 原局带, not 岁运带');
    });

    test('only the two event-bearing 神煞 reach the engine', () {
      final chart = samples.values.first;
      final span = LifeSpan.of(chart);
      for (final y in span.years) {
        final ctx = ChartService.temporalContext(
          chart,
          decade: span.decadeAt(y.age.toDouble()),
          year: y,
        );
        for (final p in ctx.luckPillars) {
          for (final s in p.shenSha) {
            expect(LuckActivationEngine.kEventShenSha, contains(s));
          }
        }
      }
    });

    test('both new kinds actually surface across a spread of charts', () {
      // A rule that never fires is a rule that does not exist.
      final seen = <String>{};
      for (final chart in samples.values) {
        for (final e in scanOf(chart)) {
          seen.add(e.kindId);
        }
      }
      expect(seen, contains('study.patron'));
      expect(seen, contains('career.travel'));
    });

    test('a 神煞 marker carries no 吉凶 of its own in the structure', () {
      // 驿马 and 贵人 are stance-0: whether movement or help reads well
      // depends on the 格局, not on the marker.
      final chart = samples.values.first;
      final span = LifeSpan.of(chart);
      final structure = NatalStructureResolver.resolve(
          chart, PatternDetector.detect(chart));
      for (final y in span.years) {
        final ctx = ChartService.temporalContext(
          chart,
          decade: span.decadeAt(y.age.toDouble()),
          year: y,
        );
        for (final a in LuckActivationEngine.evaluate(structure, ctx)) {
          if (a.targetKind == '神煞') expect(a.stance, 0);
        }
      }
    });
  });
}
