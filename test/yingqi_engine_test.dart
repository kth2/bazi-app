import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/analysis/activation_engine.dart';
import 'package:bazi_app/core/analysis/natal_structure.dart';
import 'package:bazi_app/core/analysis/pattern_detector.dart';
import 'package:bazi_app/core/analysis/temporal_context.dart';
import 'package:bazi_app/core/analysis/yingqi_engine.dart';
import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/models/birth_input.dart';
import 'package:bazi_app/core/models/chart_result.dart';

// 己巳 丙子 丙寅 甲午 — 正官格（月令子中癸水正官），破而有救.
final chart = ChartService.compute(BirthInput(
  calendarType: CalendarType.solar,
  year: 1990,
  month: 1,
  day: 1,
  hour: 12,
  minute: 0,
  gender: Gender.male,
  location: '北京',
  longitude: 116.41,
));

final structure =
    NatalStructureResolver.resolve(chart, PatternDetector.detect(chart));

DecadeData get decade =>
    chart.decades.firstWhere((d) => d.startYear <= 2026 && d.endYear >= 2026);

FlowYearData yearOf(int y) =>
    ChartService.flowYearsOf(chart, decade).firstWhere((f) => f.year == y);

void main() {
  group('LuckActivationEngine joins structure to time', () {
    test('流年午冲月支子 → 官杀被冲开，且因冲破用神而为忌', () {
      final ctx = ChartService.temporalContext(chart,
          decade: decade, year: yearOf(2026));
      final acts = LuckActivationEngine.evaluate(structure, ctx);

      final hit = acts.firstWhere((a) =>
          a.target == '官杀' &&
          a.effect == ActivationEffect.release &&
          a.layer == TemporalLayer.year);
      expect(hit.stance, -1); // 官杀 is the 格神; 冲之则破
      expect(hit.unfavourable, isTrue);
      expect(hit.mechanism, contains('地支六冲'));
      expect(hit.intensity, greaterThan(0.5));
    });

    test('夫妻宫被冲是宫位事件，喜忌中性', () {
      final ctx = ChartService.temporalContext(chart,
          decade: decade, year: yearOf(2020)); // 庚子, 子 in 月柱
      final acts = LuckActivationEngine.evaluate(structure, ctx);
      final palace =
          acts.where((a) => a.targetKind == '宫位').toList();
      expect(palace, isNotEmpty);
      for (final p in palace) {
        expect(p.stance, 0, reason: 'a palace has no 喜忌 of its own');
        expect(p.neutral, isTrue);
      }
    });

    test('岁运带来破格之神即为忌，纵使原局本无此神', () {
      // 正官格 is broken by 七杀混杂. The natal chart has no operative 七杀,
      // but a 流年七杀 still reads 忌.
      expect(structure.geJuBreakers, contains('七杀'));
      expect(structure.stanceOf('七杀'), -1);
      expect(structure.stanceOf('正官'), 1); // 格神本身，顺用宜旺
    });

    test('与格局无涉的十神为中性，不作凶断', () {
      // 比劫 is neither 相神 nor 忌神 nor 格神 here.
      expect(structure.stanceOf('比肩'), 0);
      final ctx = ChartService.temporalContext(chart,
          decade: decade, year: yearOf(2026)); // 丙 = 比肩
      final acts = LuckActivationEngine.evaluate(structure, ctx);
      final biJie = acts.firstWhere(
          (a) => a.target == '比劫' && a.effect == ActivationEffect.strengthen);
      expect(biJie.neutral, isTrue);
    });

    test('activations are deduplicated per (layer, target, effect)', () {
      final ctx = ChartService.temporalContext(chart,
          decade: decade, year: yearOf(2026));
      final acts = LuckActivationEngine.evaluate(structure, ctx);
      final keys = [
        for (final a in acts) '${a.layer}|${a.targetKind}|${a.target}|${a.effect}'
      ];
      expect(keys.length, keys.toSet().length);
    });
  });

  group('YingQiEngine picks the date, not the model', () {
    test('granularity is one layer finer than the scope', () {
      expect(
        YingQiEngine.resolve(chart, structure,
                ChartService.temporalContext(chart))
            .granularity,
        TemporalLayer.decade,
      );
      expect(
        YingQiEngine.resolve(chart, structure,
                ChartService.temporalContext(chart, decade: decade))
            .granularity,
        TemporalLayer.year,
      );
      expect(
        YingQiEngine.resolve(
                chart,
                structure,
                ChartService.temporalContext(chart,
                    decade: decade, year: yearOf(2026)))
            .granularity,
        TemporalLayer.month,
      );
    });

    test('a year is ranked into its twelve 流月, strongest first', () {
      final f = YingQiEngine.resolve(
        chart,
        structure,
        ChartService.temporalContext(chart,
            decade: decade, year: yearOf(2026)),
      );
      expect(f.windows.length, 12);
      expect(f.windows.first.score, 1.0);
      for (var i = 1; i < f.windows.length; i++) {
        expect(f.windows[i].rawScore,
            lessThanOrEqualTo(f.windows[i - 1].rawScore));
      }
      expect(f.top.length, 3);
      expect(f.top.first.triggers, isNotEmpty);
    });

    test('a month is ranked into its days, each with a concrete date', () {
      final month = ChartService.flowMonthsOf(chart, 2026)
          .firstWhere((m) => m.ganZhi == '甲午');
      final f = YingQiEngine.resolve(
        chart,
        structure,
        ChartService.temporalContext(chart,
            decade: decade, year: yearOf(2026), month: month),
      );
      expect(f.granularity, TemporalLayer.day);
      expect(f.windows.length, ChartService.flowDaysOf(chart, month).length);
      final best = f.windows.first;
      expect(best.start.isAfter(month.start.subtract(const Duration(days: 1))),
          isTrue);
      expect(best.start.isBefore(month.end), isTrue);
      expect(best.ganZhi.length, 2);
      expect(best.label, contains('日'));
    });

    test('the ranking is deterministic across runs', () {
      List<String> run() => YingQiEngine.resolve(
            chart,
            structure,
            ChartService.temporalContext(chart,
                decade: decade, year: yearOf(2026)),
          ).windows.map((w) => '${w.label}:${w.rawScore}').toList();
      expect(run(), run());
    });

    test('流日不创事: a day may not raise a theme 流年/流月 never established',
        () {
      final month = ChartService.flowMonthsOf(chart, 2026)
          .firstWhere((m) => m.ganZhi == '甲午');
      final f = YingQiEngine.resolve(
        chart,
        structure,
        ChartService.temporalContext(chart,
            decade: decade, year: yearOf(2026), month: month),
      );
      expect(f.establishedThemes, isNotEmpty);
      // Some days genuinely carry 十神 the year never put in play.
      final gated = f.windows.where((w) => w.suppressed.isNotEmpty);
      expect(gated, isNotEmpty,
          reason: 'the 流日 gate should actually hold something back');
      for (final w in f.windows) {
        // Whatever a day is credited with must be established above it.
        expect(w.themes.difference(f.establishedThemes), isEmpty);
        for (final s in w.suppressed) {
          expect(f.establishedThemes, isNot(contains(s)));
        }
      }
    });

    test('coarser scopes impose no such gate', () {
      // 大运 and 流年 may originate events of their own.
      expect(TemporalLayer.year.canOriginateEvents, isTrue);
      expect(TemporalLayer.month.canOriginateEvents, isTrue);
      expect(TemporalLayer.day.canOriginateEvents, isFalse);

      final f = YingQiEngine.resolve(chart, structure,
          ChartService.temporalContext(chart, decade: decade));
      expect(f.windows.every((w) => w.suppressed.isEmpty), isTrue);
    });

    test('a selected 流日 reports itself as the single window', () {
      final month = ChartService.flowMonthsOf(chart, 2026)
          .firstWhere((m) => m.ganZhi == '甲午');
      final day = ChartService.flowDaysOf(chart, month).first;
      final f = YingQiEngine.resolve(
        chart,
        structure,
        ChartService.temporalContext(chart,
            decade: decade, year: yearOf(2026), month: month, day: day),
      );
      expect(f.granularity, TemporalLayer.day);
      expect(f.windows.length, 1);
      expect(f.windows.first.ganZhi, day.ganZhi);
    });

    test('verdict reflects net 喜忌, not mere eventfulness', () {
      final f = YingQiEngine.resolve(
        chart,
        structure,
        ChartService.temporalContext(chart,
            decade: decade, year: yearOf(2026)),
      );
      for (final w in f.windows) {
        if (w.net > 0.15) {
          expect(w.verdict, '偏吉');
        } else if (w.net < -0.15) {
          expect(w.verdict, '偏凶');
        } else {
          expect(w.verdict, '吉凶参半');
        }
      }
    });
  });
}
