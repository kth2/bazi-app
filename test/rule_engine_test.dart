import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/models/birth_input.dart';
import 'package:bazi_app/core/rules/rule.dart';
import 'package:bazi_app/core/rules/rule_engine.dart';

List<Rule> loadSeedRules() {
  final raw = File('assets/rules/seed_rules.json').readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return [
    for (final r in json['rules'] as List) Rule.fromJson(r as Map<String, dynamic>),
  ];
}

void main() {
  // 1949-10-01 10:00 北京 男 → 己丑 癸酉 甲子 己巳, 日主甲木.
  final chart = ChartService.compute(BirthInput(
    calendarType: CalendarType.solar,
    year: 1949,
    month: 10,
    day: 1,
    hour: 10,
    minute: 0,
    gender: Gender.male,
    location: '北京',
    longitude: 116.41,
  ));

  group('seed rules', () {
    final rules = loadSeedRules();

    test('all rules parse with valid categories and conditions', () {
      expect(rules.length, greaterThanOrEqualTo(40));
      const categories = {'整体命局', '财富', '事业', '学历', '婚姻', '健康'};
      for (final r in rules) {
        expect(categories, contains(r.category), reason: r.id);
        expect(r.conditions, isNotEmpty, reason: r.id);
        expect(r.weight, greaterThan(0), reason: r.id);
        expect(r.minMatchRatio, inInclusiveRange(0, 1), reason: r.id);
      }
      // Unique ids.
      expect(rules.map((r) => r.id).toSet().length, rules.length);
    });

    test('every category has rules', () {
      final byCat = <String, int>{};
      for (final r in rules) {
        byCat[r.category] = (byCat[r.category] ?? 0) + 1;
      }
      expect(byCat.keys.length, 6);
      for (final n in byCat.values) {
        expect(n, greaterThanOrEqualTo(5));
      }
    });

    test('evaluation on real chart fires rules in multiple categories', () {
      final matches = RuleEngine.evaluate(chart, rules);
      expect(matches, isNotEmpty);
      final grouped = RuleEngine.groupByCategory(matches);
      // 甲日主, 己正财 stems ×2, 男命 → 男命正财为妻 must fire.
      expect(matches.map((m) => m.rule.id), contains('marriage_male_zheng_cai'));
      // Sorted by score descending within evaluate output.
      for (var i = 0; i < matches.length - 1; i++) {
        expect(matches[i].score, greaterThanOrEqualTo(matches[i + 1].score));
      }
      expect(grouped.keys.length, greaterThanOrEqualTo(2));
    });
  });

  group('scoring mechanics', () {
    test('partial match scores weight × ratio', () {
      final rule = Rule(
        id: 't1',
        category: '整体命局',
        title: 'partial',
        weight: 9,
        minMatchRatio: 0.6,
        conditions: const [
          RuleCondition(type: 'gender', value: '男'), // matches
          RuleCondition(type: 'verdict', value: '身强'), // may not match
          RuleCondition(type: 'hasShiShen', value: '正财'), // matches (己 ×2)
        ],
        interpretation: 'x',
        source: 't',
      );
      final matches = RuleEngine.evaluate(chart, [rule]);
      expect(matches, hasLength(1));
      final m = matches.first;
      expect(m.matchRatio, anyOf(closeTo(2 / 3, 0.001), closeTo(1.0, 0.001)));
      expect(m.score, closeTo(9 * m.matchRatio, 0.001));
    });

    test('failed required condition kills the rule even at high ratio', () {
      final rule = Rule(
        id: 't2',
        category: '整体命局',
        title: 'required-fail',
        weight: 9,
        minMatchRatio: 0.1,
        conditions: const [
          RuleCondition(type: 'gender', value: '女', required: true), // fails
          RuleCondition(type: 'hasShiShen', value: '正财'),
          RuleCondition(type: 'hasShiShen', value: '正印'),
        ],
        interpretation: 'x',
        source: 't',
      );
      expect(RuleEngine.evaluate(chart, [rule]), isEmpty);
    });

    test('below minMatchRatio does not fire', () {
      final rule = Rule(
        id: 't3',
        category: '整体命局',
        title: 'low-ratio',
        weight: 9,
        minMatchRatio: 0.9,
        conditions: const [
          RuleCondition(type: 'gender', value: '男'), // matches
          RuleCondition(type: 'gender', value: '女'), // fails
        ],
        interpretation: 'x',
        source: 't',
      );
      expect(RuleEngine.evaluate(chart, [rule]), isEmpty);
    });

    test('shi shen group and scope counting', () {
      // 己丑 癸酉 甲子 己巳: stems 己(正财) 癸(正印) 己(正财).
      final stemCai = Rule(
        id: 't4',
        category: '事业',
        title: 'count',
        weight: 5,
        minMatchRatio: 1.0,
        conditions: const [
          RuleCondition(
              type: 'shiShenCount', value: '财星', scope: 'stem', count: 2),
        ],
        interpretation: 'x',
        source: 't',
      );
      expect(RuleEngine.evaluate(chart, [stemCai]), hasLength(1));

      final tooMany = Rule(
        id: 't5',
        category: '事业',
        title: 'count-fail',
        weight: 5,
        minMatchRatio: 1.0,
        conditions: const [
          RuleCondition(
              type: 'shiShenCount', value: '财星', scope: 'stem', count: 5),
        ],
        interpretation: 'x',
        source: 't',
      );
      expect(RuleEngine.evaluate(chart, [tooMany]), isEmpty);
    });

    test('element percent condition', () {
      // Metal is strong in 酉 month for this chart.
      final rule = Rule(
        id: 't6',
        category: '健康',
        title: 'metal-strong',
        weight: 5,
        minMatchRatio: 1.0,
        conditions: const [
          RuleCondition(
              type: 'elementPercent', value: '金', op: '>=', threshold: 15),
        ],
        interpretation: 'x',
        source: 't',
      );
      expect(RuleEngine.evaluate(chart, [rule]), hasLength(1));
    });
  });
}
