import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/analysis/analysis_example.dart';
import 'package:bazi_app/core/analysis/analysis_prompt.dart';
import 'package:bazi_app/core/analysis/bazi_analysis_service.dart';
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

    test('all 13 corpus examples parse (6 weibo + 7 Hu Yiming book cases)',
        () {
      expect(examples.length, 13);
      for (final e in examples) {
        expect(e.content, isNotEmpty);
      }
    });

    test('Hu Yiming book cases carry method-specific tags', () {
      final byId = {for (final e in examples) e.id: e};
      // 翻砂厂老板: 身旺正格 + 通关 + 食伤生财.
      final boss = byId['book_hu_001']!;
      expect(boss.tags, containsAll(['通关', '食伤生财', '正格']));
      expect(boss.tags, contains('身强')); // 身旺 normalized to 身强
      // 从势格 case normalizes to 变格 + 身弱.
      final congShi = byId['book_hu_003']!;
      expect(congShi.tags, containsAll(['从势格', '变格', '身弱']));
      // 身旺无泄 suicide case.
      expect(byId['book_hu_005']!.tags, contains('身旺无泄'));
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

    test('luck interactions include 流月 and 流日 pillars', () {
      final inter = ChartService.luckInteractions(
        chart1990,
        liuYueGanZhi: '丙午', // 午 clashes natal 子 (month branch)
        liuRiGanZhi: '甲申', // 申 clashes natal 寅 (day branch)
      );
      expect(inter.any((s) => s.contains('流月')), isTrue);
      expect(inter.any((s) => s.contains('流日')), isTrue);
    });

    test('flow-month prompt carries 流月 context and monthly event asks',
        () async {
      final repo = ExampleRepository()..seedForTesting(loadExamplesFromFile());
      final pattern = PatternDetector.detect(chart1990);
      final decade = chart1990.decades.first;
      final year = ChartService.flowYearsOf(chart1990, decade).first;
      final month = ChartService.flowMonthsOf(chart1990, year.year).first;

      final prompt = AnalysisPrompt.build(
        chart: chart1990,
        pattern: pattern,
        ruleMatches: const [],
        examples: await repo.findSimilar(pattern.tags),
        decade: decade,
        year: year,
        month: month,
      );

      expect(prompt, contains('当前大运: ${decade.ganZhi}'));
      expect(prompt, contains('当前流年: ${year.year}年'));
      expect(prompt, contains('当前流月: ${month.ganZhi}月'));
      expect(prompt, contains(month.jieName));
      expect(prompt, contains('分析此流月'));
      expect(prompt, contains('本月内可能发生的具体事件'));
      expect(prompt, contains('应期日'));
      expect(prompt, contains('一、事业财富'));
      expect(prompt, contains('四、健康分析'));
      expect(prompt, isNot(contains('当前流日')));
    });

    test('flow-day prompt carries 流日 context and daily do/avoid asks',
        () async {
      final repo = ExampleRepository()..seedForTesting(loadExamplesFromFile());
      final pattern = PatternDetector.detect(chart1990);
      final decade = chart1990.decades.first;
      final year = ChartService.flowYearsOf(chart1990, decade).first;
      final month = ChartService.flowMonthsOf(chart1990, year.year).first;
      final day = ChartService.flowDaysOf(chart1990, month).first;

      final prompt = AnalysisPrompt.build(
        chart: chart1990,
        pattern: pattern,
        ruleMatches: const [],
        examples: await repo.findSimilar(pattern.tags),
        decade: decade,
        year: year,
        month: month,
        day: day,
      );

      expect(prompt, contains('当前流月: ${month.ganZhi}月'));
      expect(prompt, contains('当前流日:'));
      expect(prompt, contains('${day.ganZhi}日'));
      expect(prompt, contains('分析此流日'));
      expect(prompt, contains('宜忌建议'));
      expect(prompt, contains('一、事业财富'));
      expect(prompt, contains('四、健康分析'));
    });

    test('custom-question prompt at 流日 scope embeds the day pillar',
        () async {
      final repo = ExampleRepository()..seedForTesting(loadExamplesFromFile());
      final pattern = PatternDetector.detect(chart1990);
      final decade = chart1990.decades.first;
      final year = ChartService.flowYearsOf(chart1990, decade).first;
      final month = ChartService.flowMonthsOf(chart1990, year.year).first;
      final day = ChartService.flowDaysOf(chart1990, month).first;

      final prompt = AnalysisPrompt.buildCustom(
        chart: chart1990,
        pattern: pattern,
        ruleMatches: const [],
        examples: await repo.findSimilar(pattern.tags),
        question: '今日适合签合同吗？',
        decade: decade,
        year: year,
        month: month,
        day: day,
      );

      expect(prompt, contains('当前流日:'));
      expect(prompt, contains('${day.ganZhi}日'));
      expect(prompt, contains('【用户问题】'));
      expect(prompt, contains('今日适合签合同吗？'));
    });

    test('Hu Yiming knowledge notes are embedded in every prompt', () async {
      final repo = ExampleRepository()..seedForTesting(loadExamplesFromFile());
      final pattern = PatternDetector.detect(chart1990);
      final prompt = AnalysisPrompt.build(
        chart: chart1990,
        pattern: pattern,
        ruleMatches: const [],
        examples: await repo.findSimilar(pattern.tags),
      );
      expect(prompt, contains('命理知识要点（胡一鸣法）'));
      expect(prompt, contains('庚大肠/痔疮')); // disease table present
      expect(prompt, contains('断应期')); // timing theory present
    });

    test('custom-question prompt carries full context + the user question',
        () async {
      final repo = ExampleRepository()..seedForTesting(loadExamplesFromFile());
      final pattern = PatternDetector.detect(chart1990);
      final decade = chart1990.decades.first;
      final year = ChartService.flowYearsOf(chart1990, decade).first;
      const question =
          '甲辰年最可能发生哪件事？1读博毕业 2感情重挫 3官非牢狱 4双亲离世';

      final prompt = AnalysisPrompt.buildCustom(
        chart: chart1990,
        pattern: pattern,
        ruleMatches: const [],
        examples: await repo.findSimilar(pattern.tags),
        question: question,
        decade: decade,
        year: year,
      );

      // Shared context still present.
      expect(prompt, contains('【案例参考】'));
      expect(prompt, contains('命理知识要点（胡一鸣法）'));
      expect(prompt, contains('格局判定: 格局：正官格'));
      expect(prompt, contains('当前流年: ${year.year}年'));
      // Question and answer-format instructions.
      expect(prompt, contains('【用户问题】'));
      expect(prompt, contains(question));
      expect(prompt, contains('必须先明确指出最可能的一项'));
      // Not the 4-category format.
      expect(prompt, isNot(contains('四、健康分析')));
    });
  });

  group('BaziAnalysisService.scopeLabel', () {
    test('labels every scope level deterministically', () {
      final decade = chart1990.decades.first;
      final year = ChartService.flowYearsOf(chart1990, decade).first;
      final month = ChartService.flowMonthsOf(chart1990, year.year).first;
      final day = ChartService.flowDaysOf(chart1990, month).first;

      expect(BaziAnalysisService.scopeLabel(), '整体命局');
      expect(BaziAnalysisService.scopeLabel(decade: decade),
          '大运 ${decade.ganZhi}（${decade.startAge}-${decade.endAge}岁）');
      expect(BaziAnalysisService.scopeLabel(decade: decade, year: year),
          '流年 ${year.year} ${year.ganZhi}');
      expect(
          BaziAnalysisService.scopeLabel(
              decade: decade, year: year, month: month),
          '流月 ${year.year}年${month.ganZhi}月（${month.jieName}）');
      final label = BaziAnalysisService.scopeLabel(
          decade: decade, year: year, month: month, day: day);
      expect(label, startsWith('流日 '));
      expect(label, contains(day.ganZhi));
      // ISO-style date so cache keys stay unique across months/years.
      expect(label, contains('${day.date.year}-'));
    });
  });
}
