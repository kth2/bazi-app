import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/analysis/temporal_context.dart';
import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/models/birth_input.dart';
import 'package:bazi_app/core/models/chart_result.dart';
import 'package:bazi_app/core/rules/rule.dart';
import 'package:bazi_app/core/rules/rule_engine.dart';

List<Rule> loadSeedRules() {
  final raw = File('assets/rules/seed_rules.json').readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return [
    for (final r in json['rules'] as List)
      Rule.fromJson(r as Map<String, dynamic>),
  ];
}

void main() {
  // 己巳 丙子 丙寅 甲午, 丙日主. 月支 子.
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

  group('structured interactions carry provenance', () {
    test('a 流年 clash on the natal month branch is fully attributed', () {
      // 午 clashes the natal 子 month branch.
      final ctx = ChartService.temporalContext(
        chart,
        decade: chart.decades.first,
        year: const FlowYearData(
            year: 2026, age: 37, ganZhi: '丙午', ganShiShen: '比肩'),
      );

      final clash = ctx.interactions.firstWhere(
        (i) =>
            i.type == '地支六冲' &&
            i.layers.contains(TemporalLayer.year) &&
            i.natalPositions.contains('月柱'),
      );

      expect(clash.kind, InteractionKind.clash);
      expect(clash.kind.activates, isTrue);
      expect(clash.involvesLuck, isTrue);
      expect(clash.touchesNatal, isTrue);
      expect(clash.firingLayer, TemporalLayer.year);
      // Every party knows its layer, its position and its 十神.
      final natal = clash.parties.firstWhere(
          (p) => p.layer == TemporalLayer.natal && p.position == '月柱');
      expect(natal.value, '子');
      expect(natal.shiShen, '正官'); // 子藏癸 = 丙的正官
      expect(natal.isStem, isFalse);
    });

    test('natal-only context yields no luck interactions', () {
      final ctx = ChartService.temporalContext(chart);
      expect(ctx.depth, TemporalLayer.natal);
      expect(ctx.luckPillars, isEmpty);
      expect(ctx.interactions.any((i) => i.involvesLuck), isFalse);
    });

    test('luck pillars are annotated like natal pillars', () {
      final ctx = ChartService.temporalContext(
        chart,
        decade: chart.decades.first,
        year: const FlowYearData(
            year: 2026, age: 37, ganZhi: '丙午', ganShiShen: '比肩'),
      );
      final y = ctx.pillarAt(TemporalLayer.year)!;
      expect(y.ganZhi, '丙午');
      expect(y.ganShiShen, '比肩'); // 丙见丙
      expect(y.zhiMainShiShen, '劫财'); // 午藏丁 = 丙的劫财
      expect(y.shiShenAt('stem'), ['比肩']);
      expect(y.shiShenAt('any'), containsAll(['比肩', '劫财']));
      expect(y.ganWuXing, '火');
    });

    test('depth and activeLayers track the selection', () {
      final ctx = ChartService.temporalContext(
        chart,
        decade: chart.decades.first,
        year: const FlowYearData(
            year: 2026, age: 37, ganZhi: '丙午', ganShiShen: '比肩'),
        month: FlowMonthData(
          monthIndex: 1,
          ganZhi: '庚寅',
          ganShiShen: '偏财',
          jieName: '立春',
          start: DateTime(2026, 2, 4),
          end: DateTime(2026, 3, 5),
        ),
      );
      expect(ctx.depth, TemporalLayer.month);
      expect(ctx.activeLayers, [
        TemporalLayer.natal,
        TemporalLayer.decade,
        TemporalLayer.year,
        TemporalLayer.month,
      ]);
      expect(ctx.has(TemporalLayer.day), isFalse);
    });
  });

  group('rules declare and respect their layer', () {
    final rules = loadSeedRules();

    test('seed set now contains 岁运 rules across tiers', () {
      expect(rules.where((r) => r.layer != TemporalLayer.natal), isNotEmpty);
      expect(rules.where((r) => r.tier == 4), isNotEmpty);
      // Every temporal rule must carry at least one temporal condition,
      // otherwise it is a natal rule wearing the wrong label.
      for (final r in rules.where((r) => r.layer != TemporalLayer.natal)) {
        expect(r.conditions.any((c) => c.isTemporal), isTrue, reason: r.id);
      }
      // And no 原局 rule may smuggle in a temporal condition.
      for (final r in rules.where((r) => r.layer == TemporalLayer.natal)) {
        expect(r.conditions.any((c) => c.isTemporal), isFalse, reason: r.id);
      }
    });

    test('temporal rules are out of scope without a context', () {
      final matches = RuleEngine.evaluate(chart, rules);
      expect(matches.every((m) => m.rule.layer == TemporalLayer.natal), isTrue);
    });

    test('temporal rules are out of scope for a shallower selection', () {
      // 大运 only: 流年 rules must not fire.
      final ctx = ChartService.temporalContext(chart,
          decade: chart.decades.first);
      final matches = RuleEngine.evaluate(chart, rules, context: ctx);
      expect(matches.any((m) => m.rule.layer == TemporalLayer.year), isFalse);
    });

    test('流年冲提纲 fires only when the 流年 actually clashes 月支', () {
      final clashing = ChartService.temporalContext(
        chart,
        decade: chart.decades.first,
        year: const FlowYearData(
            year: 2026, age: 37, ganZhi: '丙午', ganShiShen: '比肩'),
      );
      final quiet = ChartService.temporalContext(
        chart,
        decade: chart.decades.first,
        // 酉 does not clash 子.
        year: const FlowYearData(
            year: 2029, age: 40, ganZhi: '己酉', ganShiShen: '伤官'),
      );

      bool fired(TemporalContext ctx) => RuleEngine
          .evaluate(chart, rules, context: ctx)
          .any((m) => m.rule.id == 'luck_year_clash_month_branch');

      expect(fired(clashing), isTrue);
      expect(fired(quiet), isFalse);
    });

    test('the same chart yields different evidence at different scopes', () {
      // This is the defect the audit found: deterministic output used to be
      // identical for every scope.
      final natal = RuleEngine.evaluate(chart, rules);
      final withYear = RuleEngine.evaluate(
        chart,
        rules,
        context: ChartService.temporalContext(
          chart,
          decade: chart.decades.first,
          year: const FlowYearData(
              year: 2026, age: 37, ganZhi: '丙午', ganShiShen: '比肩'),
        ),
      );
      expect(withYear.length, greaterThan(natal.length));
      expect(
        withYear.map((m) => m.rule.id).toSet()
          ..removeAll(natal.map((m) => m.rule.id)),
        isNotEmpty,
      );
    });
  });
}
