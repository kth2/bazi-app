import 'dart:convert';

import '../engine/chart_service.dart';
import '../models/chart_result.dart';
import '../rules/rule.dart';
import 'analysis_example.dart';
import 'pattern_detector.dart';

/// Builds the AI prompt: chart + pattern + rule hits + analogous real
/// cases + the current 大运/流年 context.
class AnalysisPrompt {
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

  static String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

  /// '乙亥' from strings that may carry extra text.
  static String _ganZhiOnly(String s) => s.length >= 2 ? s.substring(0, 2) : s;
}
