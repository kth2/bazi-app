import 'dart:convert';

import 'event_inference.dart';
import 'example_repository.dart';
import 'natal_structure.dart';
import 'reasoning_report.dart';
import 'temporal_context.dart';

/// Builds the AI prompt from a finished [ReasoningReport].
///
/// The division of labour changed here. The prompt used to hand over the raw
/// chart plus a flat list of rule titles and ask the model to work out the
/// 格局, how 岁运 interacted with it, what events that implied and when they
/// would land. All four of those are now computed, and the prompt's job is to
/// state them as settled and ask for explanation rather than derivation.
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

  /// Four-category analysis for the report's scope.
  static String build({
    required ReasoningReport report,
    required List<ExampleMatch> examples,
  }) {
    final buf = StringBuffer();
    _writeContext(buf, report: report, examples: examples);

    final depth = report.context.depth;
    buf.writeln();
    buf.writeln('【本次任务】');
    switch (depth) {
      case TemporalLayer.day:
        buf.writeln('依上述推演，解释此流日的具体人事，并给出当日宜忌。');
      case TemporalLayer.month:
        buf.writeln('依上述推演，解释此流月的具体人事，并说明本月内的轻重缓急。');
      case TemporalLayer.year:
        buf.writeln('依上述推演，解释此流年的具体人事，并说明全年节奏。');
      case TemporalLayer.decade:
        buf.writeln('依上述推演，解释此大运十年的主线，并说明运内起伏。');
      case TemporalLayer.natal:
        buf.writeln('依上述推演，解释此命局的终身格局与大运走势主线。');
    }
    buf.writeln();
    buf.writeln('按以下4个类别展开：');
    buf.writeln('1. 事业财富');
    buf.writeln('2. 婚姻感情');
    buf.writeln('3. 学习/发展');
    buf.writeln('4. 健康分析');
    buf.writeln();
    buf.writeln('要求：');
    buf.writeln('- 语言自然、专业，像真实命理师批八字一样，风格贴近上方案例');
    buf.writeln('- 每一类的论断都必须挂靠到上方【事件候选】或【岁运引动】中的某一条，'
        '并说明它如何落到具体人事；不得凭空另起一个命理依据');
    buf.writeln('- 【事件候选】给的是事件「类别」，你的工作是把它讲成这个人身上'
        '具体会发生什么、以何种方式发生、当事人该如何应对');
    if (depth == TemporalLayer.day) {
      buf.writeln('- 明确指出当日吉凶程度与最可能的事件类型（如签约、面试、口角、'
          '破财、身体不适），并给出宜忌建议');
      buf.writeln('- 流日只是引动应期：所断之事必须是流年流月已成之势的落地，'
          '不可在流日层凭空创造大事件');
    } else if (depth != TemporalLayer.natal) {
      buf.writeln('- 若某类在上方推演中并无引动，如实说明「此${depth.label}于该项无显著引动」，'
          '不要为凑满四段而虚构事件');
    }
    buf.writeln('- 输出格式：四个部分以「一、事业财富」「二、婚姻感情」「三、学习/发展」'
        '「四、健康分析」为标题，纯文本，不用markdown符号');

    return buf.toString();
  }

  /// Free-form Q&A against the same computed chain.
  static String buildCustom({
    required ReasoningReport report,
    required List<ExampleMatch> examples,
    required String question,
  }) {
    final buf = StringBuffer();
    _writeContext(buf, report: report, examples: examples);

    buf.writeln();
    buf.writeln('【用户问题】');
    buf.writeln(question.trim());
    buf.writeln();
    buf.writeln('请以命理师身份，专门针对上述问题作答：');
    buf.writeln('- 依上方已定的格局、用神忌神与岁运引动推演作答，给出明确判断，'
        '不要含糊两可');
    buf.writeln('- 若问题给出多个选项，必须先明确指出最可能的一项（如「答案：第X项」），'
        '再逐条说明各选项的可能性高低及命理依据');
    buf.writeln('- 若问题涉及时间，直接引用上方【应期】所排的窗口，'
        '不要另行推算或指定其他日期');
    buf.writeln('- 若上方推演不足以回答该问题，坦诚说明并给出倾向性判断，不可编造');
    buf.writeln('- 语言自然专业，纯文本，不用markdown符号');

    return buf.toString();
  }

  // ---------------------------------------------------------------------

  static void _writeContext(
    StringBuffer buf, {
    required ReasoningReport report,
    required List<ExampleMatch> examples,
  }) {
    final s = report.structure;

    buf.writeln('你是一位经验丰富的八字命理师，以《子平真诠》格局法论命：'
        '用神专求月令，先定格局，再看成败，忌以单纯身强身弱套论。');
    buf.writeln();
    _writeGuardrails(buf);
    buf.writeln();
    _writeExamples(buf, examples, report.pattern.tags);
    buf.writeln(kHuYimingNotes);

    buf.writeln('【原局】');
    buf.writeln(jsonEncode(report.chart.toJson()));
    buf.writeln();

    _writeStructure(buf, s);
    _writeEvidence(buf, report);
    _writeTemporal(buf, report);
    _writeActivations(buf, report);
    _writeEvents(buf, report);
    _writeYingQi(buf, report);
  }

  static void _writeGuardrails(StringBuffer buf) {
    buf.writeln('【重要——分工说明】');
    buf.writeln('以下推演已由命理引擎依古法逐层算定。你的任务是「解释并落到人事」，'
        '不是重新推导。具体地：');
    buf.writeln('- 格局、成败、用神、相神、忌神：已定，不得改判，也不要另立一套用神；');
    buf.writeln('- 岁运与原局的干支作用：已列全，不得增删或改换作用关系；');
    buf.writeln('- 应期（何时应事）：已由引擎按干支作用排定，'
        '你只能引用下方【应期】所列窗口，不得自行指定其他日期；');
    buf.writeln('- 事件候选：已给出事件类别与依据链，你负责讲成具体人事。');
    buf.writeln('若你确信某处推演有误，可在全文最后另起一节「存疑」简述理由，'
        '但正文仍须依上述推演展开。');
  }

  static void _writeExamples(
      StringBuffer buf, List<ExampleMatch> examples, Set<String> chartTags) {
    if (examples.isEmpty) return;
    final allFallback = examples.every((m) => m.isFallback);

    buf.writeln('【案例参考】');
    buf.writeln('案例的作用是示范「同类结构如何论证」与行文口吻，'
        '不是本命的预测依据。');
    buf.writeln('※ 严禁以案例的结局外推本命：案例中某人升职、发财、离婚，'
        '都不构成本命会发生同样事情的理由。'
        '本命应验与否，只由本命局的格局成败与岁运引动决定。');
    if (allFallback) {
      buf.writeln('※ 注意：本命局与语料库中各案例的格局结构并不相同，'
          '以下案例仅供行文与论证方式参考，其命理结论与本命无关，不可比附。');
    }
    buf.writeln();

    for (var i = 0; i < examples.length; i++) {
      final m = examples[i];
      final e = m.example;
      final shared = m.sharedWith(chartTags);
      buf.writeln('案例${i + 1}'
          '（${m.isFallback ? '文风参考·与本命结构无关' : '与本命相同处：${shared.join('、')}'}）');
      if (e.qianZao != null) {
        buf.writeln('命造：${e.qianZao}  大运：${e.daYun ?? ''}');
      }
      buf.writeln('分析原文：${_truncate(e.content, 900)}');
      if (e.feedback != null) {
        buf.writeln('该案例的实际反馈（仅说明该案例本身，'
            '不可作为本命的推断依据）：${e.feedback}');
      }
      buf.writeln();
    }
  }

  static void _writeStructure(StringBuffer buf, NatalStructure s) {
    buf.writeln('【格局推演——已定，不得改判】');
    buf.writeln('格局：${s.pattern.geJu}${s.pattern.isBianGe ? '（变格，用神顺势而非取中和）' : ''}');
    buf.writeln('成败：${s.status.label}');
    buf.writeln('用神：${s.yongShen}');
    if (s.xiangShen.isNotEmpty) buf.writeln('相神：${s.xiangShen.join('、')}');
    if (s.jiShen.isNotEmpty) buf.writeln('忌神：${s.jiShen.join('、')}');
    if (s.chengFactors.isNotEmpty) {
      buf.writeln('成格因素：${s.chengFactors.join('；')}');
    }
    if (s.poFactors.isNotEmpty) buf.writeln('破格因素：${s.poFactors.join('；')}');
    if (s.jiuFactors.isNotEmpty) buf.writeln('救应：${s.jiuFactors.join('；')}');
    buf.writeln('调候：${s.tiaoHou.note}'
        '（${s.tiaoHou.satisfied ? '已济' : '未济'}）');
    buf.writeln('十神力量：${[
      for (final g in NatalStructureResolver.kGroups)
        '$g ${s.presence[g]!.level}'
            '(${s.presence[g]!.strength.toStringAsFixed(0)}%)'
    ].join('｜')}');
    if (s.pattern.specialScenarios.isNotEmpty) {
      buf.writeln('特殊场景：${s.pattern.specialScenarios.join('、')}');
    }
    buf.writeln();
  }

  static void _writeEvidence(StringBuffer buf, ReasoningReport report) {
    final byTier = report.evidenceByTier;
    if (byTier.isEmpty) return;
    buf.writeln('【分层证据——命局里有什么，而非会发生什么】');
    for (final tier in [1, 2, 3, 4]) {
      final matches = byTier[tier];
      if (matches == null || matches.isEmpty) continue;
      final name = ReasoningReport.kTierNames[tier] ?? '第$tier层';
      buf.writeln('［$tier·$name］'
          '${matches.take(6).map((m) => '${m.rule.title}'
              '${m.matchRatio < 0.999 ? '(部分符合)' : ''}').join('、')}');
    }
    buf.writeln();
  }

  static void _writeTemporal(StringBuffer buf, ReasoningReport report) {
    final ctx = report.context;
    if (ctx.luckPillars.isEmpty) {
      buf.writeln('【时间范围】整体命局终身分析（不限定某一大运流年）');
      buf.writeln('大运列表：${report.chart.decades.map((d) => '${d.ganZhi}'
          '(${d.startAge}-${d.endAge}岁)').join('、')}，'
          '${report.chart.daYunForward ? '顺行' : '逆行'}，'
          '${report.chart.qiYunDescription}');
      buf.writeln();
      return;
    }
    buf.writeln('【时间范围】本次分析层级：${ctx.depth.label}');
    for (final p in ctx.luckPillars) {
      buf.writeln('- ${p.label}：天干${p.gan}(${p.ganShiShen})、'
          '地支${p.zhi}(本气${p.zhiMainShiShen})');
    }
    final onNatal = ctx.luckOnNatal;
    if (onNatal.isNotEmpty) {
      buf.writeln('岁运与原局的干支作用（已列全，不得增删）：');
      for (final i in onNatal.take(12)) {
        buf.writeln('- ${i.firingLayer.label}｜${i.kind.label}｜${i.description}');
      }
    }
    buf.writeln();
  }

  static void _writeActivations(StringBuffer buf, ReasoningReport report) {
    final acts = report.activationsAtDepth.isEmpty
        ? report.activations
        : report.activationsAtDepth;
    if (acts.isEmpty) return;
    buf.writeln('【岁运引动——此刻正在作用于命局的是什么】');
    for (final a in acts.take(10)) {
      buf.writeln('- ${a.description}');
    }
    buf.writeln();
  }

  static void _writeEvents(StringBuffer buf, ReasoningReport report) {
    if (report.events.isEmpty) {
      buf.writeln('【事件候选】本层级未见显著引动，'
          '如实说明即可，不要为凑满篇幅虚构事件。');
      buf.writeln();
      return;
    }
    buf.writeln('【事件候选——引擎已定的事件类别与依据链】');
    final bySection = EventInferenceEngine.bySection(report.events);
    for (final entry in bySection.entries) {
      buf.writeln('［${entry.key}］');
      for (final e in entry.value.take(4)) {
        buf.writeln('  · ${e.domain}·${e.subtype}｜${e.polarity.label}'
            '｜起于${e.layer.label}｜把握度${(e.confidence * 100).round()}%');
        buf.writeln('    依据：${e.basis.join(' → ')}');
      }
    }
    buf.writeln();
  }

  static void _writeYingQi(StringBuffer buf, ReasoningReport report) {
    final f = report.yingQi;
    if (f.isEmpty) return;
    buf.writeln('【应期——已由引擎排定，不得另行指定日期】');
    buf.writeln('排期依据：${f.basis}');
    for (var i = 0; i < f.top.length; i++) {
      final w = f.top[i];
      buf.writeln('${i + 1}. ${w.label}｜强度${(w.score * 100).round()}%'
          '｜${w.verdict}'
          '${w.themes.isEmpty ? '' : '｜所动：${w.themes.join('、')}'}');
      for (final t in w.triggers.take(3)) {
        buf.writeln('     - $t');
      }
    }
    if (f.granularity == TemporalLayer.day) {
      buf.writeln('注：流日只引动流年流月已成之势。'
          '本月可被引动的主题限于：${f.establishedThemes.join('、')}；'
          '此外的主题不可在流日层断为大事。');
    }
    buf.writeln();
  }

  static String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';
}
