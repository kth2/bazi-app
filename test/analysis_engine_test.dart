import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/analysis/analysis_example.dart';
import 'package:bazi_app/core/analysis/analysis_prompt.dart';
import 'package:bazi_app/core/analysis/example_repository.dart';
import 'package:bazi_app/core/analysis/pattern_detector.dart';
import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/models/birth_input.dart';
import 'package:bazi_app/core/rules/rule.dart';
import 'package:bazi_app/core/rules/rule_engine.dart';

List<AnalysisExample> loadExamplesFromFile() {
  final raw =
      File('assets/examples/analysis_examples.json').readAsStringSync();
  final list = jsonDecode(raw) as List;
  return [
    for (final e in list) AnalysisExample.fromJson(e as Map<String, dynamic>),
  ];
}

void main() {
  // 1949-10-01 10:00 北京 男 → 己丑 癸酉 甲子 己巳 (甲日酉月 → 正官格).
  final chart1949 = ChartService.compute(BirthInput(
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

  // 1990-01-01 12:00 北京 男 → 己巳 丙子 丙寅 甲午 (丙日子月 → 正官格).
  final chart1990 = ChartService.compute(BirthInput(
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

  group('AnalysisExample tagging', () {
    final examples = loadExamplesFromFile();

    test('all 6 corpus examples parse', () {
      expect(examples.length, 6);
      for (final e in examples) {
        expect(e.content, isNotEmpty);
      }
    });

    test('pattern keywords extracted from corpus', () {
      final allTags = examples.expand((e) => e.tags).toSet();
      // Known content of the corpus:
      expect(allTags, contains('伤官见官')); // example 2
      expect(allTags, contains('建禄格')); // examples 3, 4
      expect(allTags, contains('三奇格')); // example 5
      expect(allTags, contains('财破印')); // example 1 (印绶被财破 normalized)
      // Example 6 (比劫合官) — appears in title.
      expect(allTags, contains('比劫合官'));
    });
  });

  group('PatternDetector', () {
    test('甲日酉月 is 正官格 with month-order yong shen', () {
      final p = PatternDetector.detect(chart1949);
      expect(p.geJu, '正官格');
      expect(p.yongShen, contains('正官'));
      expect(p.tags, contains('正官格'));
    });

    test('丙日子月 is 正官格; 伤官见官 detected when both transparent', () {
      final p = PatternDetector.detect(chart1990);
      // 子藏癸 = 正官 for 丙.
      expect(p.geJu, '正官格');
      // 己(年干伤官) + 癸(子中正官) → 伤官见官.
      expect(p.specialScenarios, contains('伤官见官'));
    });

    test('scenario detection is data-driven, not hardcoded', () {
      final p = PatternDetector.detect(chart1949);
      // 己丑 癸酉 甲子 己巳: 甲日主, 癸=正印 stem, 辛(酉/丑藏)=正官 → 官印相生.
      expect(p.specialScenarios, contains('官印相生'));
      // 巳藏庚=七杀 + 酉藏辛=正官 both in main/any → 官杀混杂 plausible;
      // at minimum the tags include the 格局 and verdict.
      expect(p.tags, contains(chart1949.elementStrength.verdict));
    });
  });

  group('ExampleRepository matching', () {
    test('伤官见官 chart pulls the 伤官见官 corpus example first', () async {
      final repo = ExampleRepository()..seedForTesting(loadExamplesFromFile());
      final pattern = PatternDetector.detect(chart1990);
      final similar = await repo.findSimilar(pattern.tags);
      expect(similar, isNotEmpty);
      expect(similar.length, lessThanOrEqualTo(2));
      // The top hit must share tags with the chart.
      expect(similar.first.tags.intersection(pattern.tags), isNotEmpty);
      // 正官格+伤官见官 corpus case is id 1000239885.
      expect(similar.map((e) => e.id), contains('1000239885'));
    });

    test('no overlap falls back to style reference, never empty', () async {
      final repo = ExampleRepository()..seedForTesting(loadExamplesFromFile());
      final similar = await repo.findSimilar({'不存在的标签'});
      expect(similar.length, 2);
    });
  });

  group('AnalysisPrompt', () {
    test('dayun prompt contains all required blocks', () async {
      final repo = ExampleRepository()..seedForTesting(loadExamplesFromFile());
      final pattern = PatternDetector.detect(chart1990);
      final examples = await repo.findSimilar(pattern.tags);
      final rules = [
        Rule(
          id: 'r',
          category: '整体命局',
          title: '测试规则',
          weight: 8,
          minMatchRatio: 1.0,
          conditions: const [RuleCondition(type: 'gender', value: '男')],
          interpretation: 'x',
          source: 't',
        ),
      ];
      final matches = RuleEngine.evaluate(chart1990, rules);
      final decade = chart1990.decades.first;
      final year = ChartService.flowYearsOf(chart1990, decade).first;

      final prompt = AnalysisPrompt.build(
        chart: chart1990,
        pattern: pattern,
        ruleMatches: matches,
        examples: examples,
        decade: decade,
        year: year,
      );

      expect(prompt, contains('【案例参考】'));
      expect(prompt, contains('格局判定: 格局：正官格'));
      expect(prompt, contains('当前大运: ${decade.ganZhi}'));
      expect(prompt, contains('当前流年: ${year.year}年'));
      expect(prompt, contains('一、事业财富'));
      expect(prompt, contains('四、健康分析'));
      expect(prompt, contains('规则引擎要点'));
      // Chart JSON embedded.
      expect(prompt, contains(chart1990.baziString));
    });

    test('life prompt lists all decades instead of a single one', () async {
      final repo = ExampleRepository()..seedForTesting(loadExamplesFromFile());
      final pattern = PatternDetector.detect(chart1990);
      final prompt = AnalysisPrompt.build(
        chart: chart1990,
        pattern: pattern,
        ruleMatches: const [],
        examples: await repo.findSimilar(pattern.tags),
      );
      expect(prompt, contains('整体命局终身分析'));
      expect(prompt, contains('大运列表'));
      expect(prompt, isNot(contains('当前大运')));
    });

    test('luck interactions computed between decade and natal chart', () {
      final withClash = ChartService.luckInteractions(
        chart1990,
        decadeGanZhi: '壬午', // 午 clashes natal 子 (month branch)
      );
      expect(withClash.any((s) => s.contains('大运')), isTrue);
    });
  });
}
