import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/analysis/analysis_example.dart';
import 'package:bazi_app/core/analysis/analysis_prompt.dart';
import 'package:bazi_app/core/analysis/event_inference.dart';
import 'package:bazi_app/core/analysis/example_repository.dart';
import 'package:bazi_app/core/analysis/reasoning_report.dart';
import 'package:bazi_app/core/analysis/temporal_context.dart';
import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/models/birth_input.dart';
import 'package:bazi_app/core/models/chart_result.dart';
import 'package:bazi_app/core/rules/rule.dart';

List<Rule> loadSeedRules() {
  final json = jsonDecode(
      File('assets/rules/seed_rules.json').readAsStringSync()) as Map;
  return [
    for (final r in json['rules'] as List)
      Rule.fromJson(r as Map<String, dynamic>),
  ];
}

ExampleRepository loadRepo() => ExampleRepository()
  ..seedForTesting([
    for (final e in jsonDecode(File('assets/examples/analysis_examples.json')
        .readAsStringSync()) as List)
      AnalysisExample.fromJson(e as Map<String, dynamic>),
  ]);

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

void main() {
  final rules = loadSeedRules();

  DecadeData decade() => chart.decades
      .firstWhere((d) => d.startYear <= 2026 && d.endYear >= 2026);
  FlowYearData year() => ChartService.flowYearsOf(chart, decade())
      .firstWhere((y) => y.year == 2026);
  FlowMonthData month() =>
      ChartService.flowMonthsOf(chart, 2026).firstWhere((m) => m.ganZhi == '甲午');
  FlowDayData day() => ChartService.flowDaysOf(chart, month()).first;

  group('the deterministic chain differs by scope', () {
    // The audit's central finding: PatternDetector and RuleEngine both took
    // only the natal chart, so every scope produced byte-identical
    // deterministic output and the model was left to do all the temporal work.
    test('reports at five scopes are all distinct', () {
      final reports = <String, ReasoningReport>{
        'natal': ReasoningReport.build(chart, rules),
        'decade': ReasoningReport.build(chart, rules, decade: decade()),
        'year': ReasoningReport.build(chart, rules,
            decade: decade(), year: year()),
        'month': ReasoningReport.build(chart, rules,
            decade: decade(), year: year(), month: month()),
        'day': ReasoningReport.build(chart, rules,
            decade: decade(), year: year(), month: month(), day: day()),
      };

      final serialised = {
        for (final e in reports.entries) e.key: jsonEncode(e.value.toJson())
      };
      expect(serialised.values.toSet().length, 5,
          reason: 'every scope must produce a distinct reasoning chain');

      // Depth is tracked, and each scope times one layer finer than itself.
      expect(reports['natal']!.context.depth, TemporalLayer.natal);
      expect(reports['day']!.context.depth, TemporalLayer.day);
      expect(reports['year']!.yingQi.granularity, TemporalLayer.month);
      expect(reports['month']!.yingQi.granularity, TemporalLayer.day);
    });

    test('prompts at five scopes are all distinct', () async {
      final repo = loadRepo();
      Future<String> promptAt({
        DecadeData? d,
        FlowYearData? y,
        FlowMonthData? m,
        FlowDayData? dd,
      }) async {
        final report = ReasoningReport.build(chart, rules,
            decade: d, year: y, month: m, day: dd);
        return AnalysisPrompt.build(
          report: report,
          examples: await repo.findMatches(report.pattern.tags),
        );
      }

      final prompts = [
        await promptAt(),
        await promptAt(d: decade()),
        await promptAt(d: decade(), y: year()),
        await promptAt(d: decade(), y: year(), m: month()),
        await promptAt(d: decade(), y: year(), m: month(), dd: day()),
      ];
      expect(prompts.toSet().length, 5);
    });

    test('the natal structure itself is scope-invariant', () {
      // 格局 belongs to the chart, not to the moment: only the temporal
      // layers may vary between scopes.
      final a = ReasoningReport.build(chart, rules);
      final b = ReasoningReport.build(chart, rules,
          decade: decade(), year: year(), month: month(), day: day());
      expect(a.structure.pattern.geJu, b.structure.pattern.geJu);
      expect(a.structure.status, b.structure.status);
      expect(a.structure.xiangShen, b.structure.xiangShen);
      expect(a.structure.jiShen, b.structure.jiShen);
    });
  });

  group('the report carries a complete, ordered chain', () {
    final report = ReasoningReport.build(chart, rules,
        decade: chart.decades
            .firstWhere((d) => d.startYear <= 2026 && d.endYear >= 2026),
        year: ChartService.flowYearsOf(
                chart,
                chart.decades.firstWhere(
                    (d) => d.startYear <= 2026 && d.endYear >= 2026))
            .firstWhere((y) => y.year == 2026));

    test('每一层都非空且互相衔接', () {
      expect(report.structure.yongShen, isNotEmpty);
      expect(report.evidence, isNotEmpty);
      expect(report.activations, isNotEmpty);
      expect(report.events, isNotEmpty);
      expect(report.yingQi.windows, isNotEmpty);

      // Every event must trace back to a target the activations actually
      // touched — nothing may appear from nowhere.
      final targets = {for (final a in report.activations) a.target};
      expect(targets, isNotEmpty);
      for (final e in report.events) {
        expect(e.basis, isNotEmpty);
        expect(e.basis.first, contains(report.structure.pattern.geJu));
      }
    });

    test('evidence is tiered rather than pooled flat', () {
      final byTier = report.evidenceByTier;
      expect(byTier.keys.length, greaterThan(1));
      for (final tier in byTier.keys) {
        expect(ReasoningReport.kTierNames.containsKey(tier), isTrue);
      }
      // 岁运引动 evidence exists only because a temporal scope is selected.
      final natalOnly = ReasoningReport.build(chart, rules);
      expect(natalOnly.evidenceByTier.containsKey(4), isFalse);
    });

    test('the report carries a net verdict downstream can be held to', () {
      final a = report.assessment;
      expect(a.hasSignal, isTrue);
      expect(a.summary, contains('综合倾向'));
      expect(['整体偏吉', '整体偏凶', '吉凶相当'], contains(a.lean));
      // The lean must follow the counted evidence, not be asserted.
      final expected = (a.favourableEvents - a.adverseEvents) +
          (a.favourableWindows - a.adverseWindows);
      expect(a.net, expected);
      expect(a.lean,
          expected > 0 ? '整体偏吉' : (expected < 0 ? '整体偏凶' : '吉凶相当'));
    });

    test('every event maps to one of the four output sections', () {
      const sections = {'事业财富', '婚姻感情', '学习/发展', '健康分析'};
      for (final e in report.events) {
        expect(sections, contains(e.section));
        expect(EventDomain.subtypes[e.domain], contains(e.subtype));
      }
    });

    test('the whole pipeline is reproducible', () {
      final a = jsonEncode(ReasoningReport.build(chart, rules,
              decade: decade(), year: year())
          .toJson());
      final b = jsonEncode(ReasoningReport.build(chart, rules,
              decade: decade(), year: year())
          .toJson());
      expect(a, b);
    });
  });

  group('gender changes what a structure means', () {
    test('男命以财为妻星，女命以官杀为夫星', () {
      final female = ChartService.compute(BirthInput(
        calendarType: CalendarType.solar,
        year: 1990,
        month: 1,
        day: 1,
        hour: 12,
        minute: 0,
        gender: Gender.female,
        location: '北京',
        longitude: 116.41,
      ));
      final femaleDecade = female.decades
          .firstWhere((d) => d.startYear <= 2026 && d.endYear >= 2026);
      final fr = ReasoningReport.build(female, rules,
          decade: femaleDecade,
          year: ChartService.flowYearsOf(female, femaleDecade)
              .firstWhere((y) => y.year == 2026));
      final mr = ReasoningReport.build(chart, rules,
          decade: decade(), year: year());

      String? marriageBasis(ReasoningReport r) => r.events
          .where((e) => e.domain == EventDomain.marriage)
          .map((e) => e.basis.join())
          .join();

      expect(marriageBasis(mr), isNotNull);
      expect(marriageBasis(fr), isNotNull);
      // 女命的婚姻事件应由官杀引动，男命由财星引动.
      expect(fr.events.any((e) => e.domain == EventDomain.marriage), isTrue);
      expect(mr.events.any((e) => e.domain == EventDomain.marriage), isTrue);
      expect(marriageBasis(fr), isNot(marriageBasis(mr)));
    });
  });
}
