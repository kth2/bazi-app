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
import 'package:bazi_app/core/analysis/reasoning_report.dart';
import 'package:bazi_app/core/models/chart_result.dart';
import 'package:bazi_app/core/rules/rule.dart';

List<Rule> loadSeedRules() {
  final raw = File('assets/rules/seed_rules.json').readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return [
    for (final r in json['rules'] as List)
      Rule.fromJson(r as Map<String, dynamic>),
  ];
}

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
    final repo = ExampleRepository()..seedForTesting(loadExamplesFromFile());
    final rules = loadSeedRules();

    Future<String> promptFor({
      DecadeData? decade,
      FlowYearData? year,
      FlowMonthData? month,
      FlowDayData? day,
    }) async {
      final report = ReasoningReport.build(chart1990, rules,
          decade: decade, year: year, month: month, day: day);
      return AnalysisPrompt.build(
        report: report,
        examples: await repo.findMatches(report.pattern.tags),
      );
    }

    test('dayun prompt contains all required blocks', () async {
      final decade = chart1990.decades.first;
      final year = ChartService.flowYearsOf(chart1990, decade).first;
      final prompt = await promptFor(decade: decade, year: year);

      expect(prompt, contains('【案例参考】'));
      expect(prompt, contains('【格局推演——已定，不得改判】'));
      expect(prompt, contains('格局：正官格'));
      expect(prompt, contains('大运 ${decade.ganZhi}'));
      expect(prompt, contains('流年 ${year.year}年'));
      expect(prompt, contains('一、事业财富'));
      expect(prompt, contains('四、健康分析'));
      expect(prompt, contains('【分层证据'));
      expect(prompt, contains(chart1990.baziString));
    });

    test('the prompt states the division of labour explicitly', () async {
      final prompt = await promptFor(decade: chart1990.decades.first);
      expect(prompt, contains('【重要——分工说明】'));
      expect(prompt, contains('不是重新推导'));
      expect(prompt, contains('不得改判'));
    });

    test('应期 is handed to the model, never asked of it', () async {
      final decade = chart1990.decades.first;
      final year = ChartService.flowYearsOf(chart1990, decade).first;
      final prompt = await promptFor(decade: decade, year: year);

      // The engine's ranked windows are present …
      expect(prompt, contains('【应期——已由引擎排定，不得另行指定日期】'));
      expect(prompt, contains('排期依据：'));
      // … and the old instruction asking the model to pick a date is gone.
      expect(prompt, isNot(contains('指出最可能的应期日')));
      expect(prompt, contains('不得自行指定其他日期'));
    });

    test('examples are framed as reasoning references, not evidence',
        () async {
      final prompt = await promptFor(decade: chart1990.decades.first);
      expect(prompt, contains('不是本命的预测依据'));
      expect(prompt, contains('严禁以案例的结局外推本命'));
      // 实际反馈 must carry its own disclaimer wherever it appears.
      if (prompt.contains('实际反馈')) {
        expect(prompt, contains('不可作为本命的推断依据'));
      }
    });

    test('a fallback example set is labelled as unrelated', () async {
      final matches = await repo.findMatches({'不存在的标签'});
      expect(matches.every((m) => m.isFallback), isTrue);
      final report = ReasoningReport.build(chart1990, rules);
      final prompt =
          AnalysisPrompt.build(report: report, examples: matches);
      expect(prompt, contains('其命理结论与本命无关，不可比附'));
      expect(prompt, contains('文风参考·与本命结构无关'));
    });

    test('life prompt lists all decades instead of a single one', () async {
      final prompt = await promptFor();
      expect(prompt, contains('整体命局终身分析'));
      expect(prompt, contains('大运列表'));
      expect(prompt, isNot(contains('本次分析层级：流年')));
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

    test('flow-month prompt carries 流月 context', () async {
      final decade = chart1990.decades.first;
      final year = ChartService.flowYearsOf(chart1990, decade).first;
      final month = ChartService.flowMonthsOf(chart1990, year.year).first;
      final prompt =
          await promptFor(decade: decade, year: year, month: month);

      expect(prompt, contains('本次分析层级：流月'));
      expect(prompt, contains('大运 ${decade.ganZhi}'));
      expect(prompt, contains('流年 ${year.year}年'));
      expect(prompt, contains('流月 ${month.ganZhi}月'));
      expect(prompt, contains(month.jieName));
      expect(prompt, contains('解释此流月的具体人事'));
      expect(prompt, contains('一、事业财富'));
      expect(prompt, isNot(contains('本次分析层级：流日')));
    });

    test('flow-day prompt carries 流日 context and the 不创事 constraint',
        () async {
      final decade = chart1990.decades.first;
      final year = ChartService.flowYearsOf(chart1990, decade).first;
      final month = ChartService.flowMonthsOf(chart1990, year.year).first;
      final day = ChartService.flowDaysOf(chart1990, month).first;
      final prompt = await promptFor(
          decade: decade, year: year, month: month, day: day);

      expect(prompt, contains('本次分析层级：流日'));
      expect(prompt, contains(day.ganZhi));
      expect(prompt, contains('解释此流日的具体人事'));
      expect(prompt, contains('宜忌'));
      expect(prompt, contains('不可在流日层凭空创造大事件'));
      expect(prompt, contains('一、事业财富'));
      expect(prompt, contains('四、健康分析'));
    });

    test('custom-question prompt at 流日 scope embeds the day pillar',
        () async {
      final decade = chart1990.decades.first;
      final year = ChartService.flowYearsOf(chart1990, decade).first;
      final month = ChartService.flowMonthsOf(chart1990, year.year).first;
      final day = ChartService.flowDaysOf(chart1990, month).first;
      final report = ReasoningReport.build(chart1990, rules,
          decade: decade, year: year, month: month, day: day);

      final prompt = AnalysisPrompt.buildCustom(
        report: report,
        examples: await repo.findMatches(report.pattern.tags),
        question: '今日适合签合同吗？',
      );

      expect(prompt, contains('本次分析层级：流日'));
      expect(prompt, contains(day.ganZhi));
      expect(prompt, contains('【用户问题】'));
      expect(prompt, contains('今日适合签合同吗？'));
    });

    test('Hu Yiming knowledge notes are embedded in every prompt', () async {
      final prompt = await promptFor();
      expect(prompt, contains('命理知识要点（胡一鸣法）'));
      expect(prompt, contains('庚大肠/痔疮')); // disease table present
      expect(prompt, contains('断应期')); // timing theory present
    });

    test('custom-question prompt carries full context + the user question',
        () async {
      final decade = chart1990.decades.first;
      final year = ChartService.flowYearsOf(chart1990, decade).first;
      const question =
          '甲辰年最可能发生哪件事？1读博毕业 2感情重挫 3官非牢狱 4双亲离世';
      final report = ReasoningReport.build(chart1990, rules,
          decade: decade, year: year);

      final prompt = AnalysisPrompt.buildCustom(
        report: report,
        examples: await repo.findMatches(report.pattern.tags),
        question: question,
      );

      expect(prompt, contains('【案例参考】'));
      expect(prompt, contains('命理知识要点（胡一鸣法）'));
      expect(prompt, contains('格局：正官格'));
      expect(prompt, contains('流年 ${year.year}年'));
      expect(prompt, contains('【用户问题】'));
      expect(prompt, contains(question));
      expect(prompt, contains('必须先明确指出最可能的一项'));
      // Timing must be quoted from the engine, not recomputed.
      expect(prompt, contains('不要另行推算或指定其他日期'));
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
