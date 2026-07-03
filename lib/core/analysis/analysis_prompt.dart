import 'dart:convert';

import '../engine/chart_service.dart';
import '../models/chart_result.dart';
import '../rules/rule.dart';
import 'analysis_example.dart';
import 'pattern_detector.dart';

/// Builds the AI prompt: chart + pattern + rule hits + analogous real
/// cases + the current 大运/流年 context.
class AnalysisPrompt {
  /// Distilled principles from 《胡一鸣八字命理》 — knowledge the rule
  /// engine can't express (timing theory, disease mapping, dynamics).
  static const String kHuYimingNotes = '''
【命理知识要点（胡一鸣法）】
- 判旺弱定格局：旺者有克泄、弱者有生扶为正格，取中庸之道；克泄/生扶皆无用则为变格（从格），顺势行舟——弱让它更弱、旺让它更旺，反之大凶。
- 有钱两条件：有来源（食伤）且守得住（财不被比劫克尽）。食伤生财为付出型赚钱：身旺轻松、身弱辛苦劳累；伤官生财敢想敢干放得开，食神生财含蓄有顾忌。官印相生为被动型赚钱，上班管理一流，创业多倒（食伤克官不善找财源）。财生官、官生印者，借官位地位职位赚钱；身旺食伤生财又财生官者为老板创业之命。
- 比劫分财：财来财去，到头一场空，男命于妻不利；身旺逢官运克去比劫，财复活为意外之财。身旺食伤受印克则郁闷，逢财运财破印、食伤复活为意外收获。身弱财破印（无食伤）主破财，要钱不要命。
- 婚恋：男看财星、以食伤为动力；女看官杀、以财为动力。有星无动力或有动力无星者，逢引动之运年发动。夫妻宫（日支）坐食伤者眼光高、所遇皆看不起。男食伤生财者旺妻待妻好；女财生官者旺夫；官克日主者其夫待她不佳。食伤合官杀者易怀孕、恋地位。
- 健康（干支受伤对应之病）：甲胆/骨折/秃头，乙肝/筋/风湿，丙小肠/眼疾，丁心脏/供血不足，戊胃/肌肉/妇科瘤，己脾/糖尿病，庚大肠/痔疮，辛肺/呼吸道/皮肤过敏，壬癸肾膀胱/血液/中风高血压/内分泌/耳鸣/子宫。命局关键「通关之神」受伤时连锁而病（如金伤则先痔疮后肾病）；身旺无泄者气机郁滞、情绪压抑成疾。天干地支同时受克，轻则意外官非，重则大凶。
- 断应期：某干支之气「走完、被克、被合」即为应期；合就是拘绊，功能发挥不出；流年流月由外到内切入，注意连锁反应（甲被合则乙出、乙被克则甲复出，吉凶随之翻转）。
''';

  /// [decade]/[year] null → whole-life analysis.
  static String build({
    required ChartResult chart,
    required ChartPattern pattern,
    required List<RuleMatch> ruleMatches,
    required List<AnalysisExample> examples,
    DecadeData? decade,
    FlowYearData? year,
  }) {
    final buf = StringBuffer();
    _writeContext(buf,
        chart: chart,
        pattern: pattern,
        ruleMatches: ruleMatches,
        examples: examples,
        decade: decade,
        year: year);

    buf.writeln();
    buf.writeln('按以下4个类别提供详细分析（使用古典原理，指出用神/忌神/格局变化，');
    buf.writeln('每类预测1-2个可能事件并给出触发依据，如某支被引动、某干争合）：');
    buf.writeln('1. 事业财富');
    buf.writeln('2. 婚姻感情');
    buf.writeln('3. 学习/发展');
    buf.writeln('4. 健康分析');
    buf.writeln();
    buf.writeln('要求：');
    buf.writeln('- 语言自然、专业，像真实命理师批八字一样，风格贴近上方案例');
    buf.writeln('- 先讲原局格局如何被此运/此年影响（成格增益或破格受损），再落到具体人事');
    buf.writeln('- 若命局有特殊场景（如印绶被财破、伤官见官、比劫合官），必须点明并');
    buf.writeln('  参照案例中同类格局的处理方式给出细腻论断');
    buf.writeln('- 输出格式：四个部分以「一、事业财富」「二、婚姻感情」「三、学习/发展」');
    buf.writeln('  「四、健康分析」为标题，纯文本，不用markdown符号');

    return buf.toString();
  }

  /// Free-form Q&A: same chart/pattern/luck context, but the AI answers the
  /// user's specific [question] (e.g. "甲辰年会发生什么大事？选项1234…哪一件？").
  static String buildCustom({
    required ChartResult chart,
    required ChartPattern pattern,
    required List<RuleMatch> ruleMatches,
    required List<AnalysisExample> examples,
    required String question,
    DecadeData? decade,
    FlowYearData? year,
  }) {
    final buf = StringBuffer();
    _writeContext(buf,
        chart: chart,
        pattern: pattern,
        ruleMatches: ruleMatches,
        examples: examples,
        decade: decade,
        year: year);

    buf.writeln();
    buf.writeln('【用户问题】');
    buf.writeln(question.trim());
    buf.writeln();
    buf.writeln('请以命理师身份，专门针对上述问题作答：');
    buf.writeln('- 先据原局格局、用神忌神与此运/此年的干支作用（合冲刑害、引动、争合、'
        '某气走完）推演，给出明确判断，不要含糊两可');
    buf.writeln('- 若问题给出多个选项，必须先明确指出最可能的一项（如「答案：第X项」），'
        '再逐条说明各选项的可能性高低及命理依据');
    buf.writeln('- 若问题涉及具体年份/流月，指出应期（何时最易触发）及触发的干支原理');
    buf.writeln('- 若命理信息不足以断定，坦诚说明并给出倾向性判断，不可编造');
    buf.writeln('- 语言自然专业，纯文本，不用markdown符号');

    return buf.toString();
  }

  /// Shared context block: persona + examples + Hu Yiming notes + chart +
  /// pattern + rule hits + 大运/流年 luck interactions.
  static void _writeContext(
    StringBuffer buf, {
    required ChartResult chart,
    required ChartPattern pattern,
    required List<RuleMatch> ruleMatches,
    required List<AnalysisExample> examples,
    DecadeData? decade,
    FlowYearData? year,
  }) {
    buf.writeln('你是一位经验丰富的八字命理师，以《子平真诠》格局法论命：用神专求月令，');
    buf.writeln('先定格局，再看成败，忌以单纯身强身弱套论。参考以下真实案例的分析风格和逻辑：');
    buf.writeln();
    buf.writeln('【案例参考】');
    for (var i = 0; i < examples.length; i++) {
      final e = examples[i];
      buf.writeln('案例${i + 1}（格局标签：${e.tags.join('、')}）');
      if (e.qianZao != null) buf.writeln('命造：${e.qianZao}  大运：${e.daYun ?? ''}');
      buf.writeln('分析原文：${_truncate(e.content, 900)}');
      if (e.feedback != null) buf.writeln('实际反馈：${e.feedback}');
      buf.writeln();
    }

    buf.writeln(kHuYimingNotes);
    buf.writeln('现在分析以下命局：');
    buf.writeln();
    buf.writeln('原局: ${jsonEncode(chart.toJson())}');
    buf.writeln();
    buf.writeln('格局判定: ${pattern.summary}');
    if (ruleMatches.isNotEmpty) {
      buf.writeln('规则引擎要点: ${ruleMatches.take(8).map((m) => '${m.rule.title}(${m.score.toStringAsFixed(1)}分)').join('、')}');
    }

    if (decade != null) {
      final inter = ChartService.luckInteractions(
        chart,
        decadeGanZhi: _ganZhiOnly(decade.ganZhi),
        liuNianGanZhi: year == null ? null : _ganZhiOnly(year.ganZhi),
      );
      buf.writeln();
      buf.writeln('当前大运: ${decade.ganZhi}（${decade.startAge}-${decade.endAge}岁，'
          '${decade.startYear}-${decade.endYear}年，天干${decade.ganShiShen}，'
          '支本气${decade.zhiMainShiShen}）');
      if (year != null) {
        buf.writeln('当前流年: ${year.year}年 ${year.ganZhi}（${year.age}岁，'
            '天干${year.ganShiShen}）');
      }
      if (inter.isNotEmpty) {
        buf.writeln('此运/年与原局的干支作用: ${inter.join('；')}');
      }
    } else {
      buf.writeln();
      buf.writeln('本次为整体命局终身分析（不限定某一大运流年，可结合大运走势概述）。');
      buf.writeln('大运列表: ${chart.decades.map((d) => '${d.ganZhi}(${d.startAge}-${d.endAge}岁)').join('、')}，'
          '${chart.daYunForward ? '顺行' : '逆行'}，${chart.qiYunDescription}');
    }
  }

  static String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

  /// '乙亥' from strings that may carry extra text.
  static String _ganZhiOnly(String s) => s.length >= 2 ? s.substring(0, 2) : s;
}
