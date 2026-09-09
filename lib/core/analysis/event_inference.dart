import '../models/birth_input.dart';
import '../models/chart_result.dart';
import 'activation_engine.dart';
import 'natal_structure.dart';
import 'temporal_context.dart';

/// Top-level life domains, and how they fold into the four sections the
/// analysis is presented in.
class EventDomain {
  static const career = '事业';
  static const wealth = '财富';
  static const marriage = '婚姻';
  static const study = '学业发展';
  static const health = '健康';

  static const all = [career, wealth, marriage, study, health];

  /// 事业 and 财富 share one output section; the rest map one to one.
  static const Map<String, String> section = {
    career: '事业财富',
    wealth: '事业财富',
    marriage: '婚姻感情',
    study: '学习/发展',
    health: '健康分析',
  };

  /// The sub-types each domain can produce, for reference and validation.
  static const Map<String, List<String>> subtypes = {
    career: [
      '职位晋升', '权责加重', '职务变动', '离职转换', '创业自立', '职场是非',
      '迁移变动', '压力解除', '摆脱束缚', '收束心性', '远行出行', '官非诉讼',
      '迁居搬家', '名声显扬',
    ],
    wealth: [
      '收入增益', '投资置产', '意外之财', '破财损耗', '因财劳碌', '资产变动',
      '卸下重负', '免于分夺', '置业安家',
    ],
    marriage: [
      '婚恋成合', '感情生变', '配偶宫动', '情感牵绊', '第三者之扰', '子女之事',
    ],
    study: [
      '文书学业', '考试资格', '技艺才华', '进修拓展', '学途受阻', '破印得用',
      '贵人相助', '负笈远游',
    ],
    health: [
      '劳神耗气', '旧患复发', '外伤意外', '情志郁结', '身心失调',
      '手术风险', '寿元关注',
    ],
  };
}

enum EventPolarity { favourable, adverse, mixed }

extension EventPolarityX on EventPolarity {
  String get label => switch (this) {
        EventPolarity.favourable => '吉',
        EventPolarity.adverse => '凶',
        EventPolarity.mixed => '吉凶参半',
      };
}

/// One inferred event, with the chain that produced it.
class EventCandidate {
  final String domain;
  final String subtype;

  /// The layer this event originates at.
  final TemporalLayer layer;

  final EventPolarity polarity;

  /// 0..1.
  final double confidence;

  /// The reasoning chain, coarse → fine.
  final List<String> basis;

  const EventCandidate({
    required this.domain,
    required this.subtype,
    required this.layer,
    required this.polarity,
    required this.confidence,
    required this.basis,
  });

  String get section => EventDomain.section[domain] ?? domain;

  Map<String, dynamic> toJson() => {
        'domain': domain,
        'subtype': subtype,
        'section': section,
        'layer': layer.label,
        'polarity': polarity.label,
        'confidence': double.parse(confidence.toStringAsFixed(2)),
        'basis': basis,
      };

  String get description => '[$domain·$subtype] ${polarity.label}'
      '（${layer.label}，把握度${(confidence * 100).round()}%）'
      '：${basis.join(' → ')}';
}

/// Maps an activation onto an event class.
class _EventRule {
  final String target; // 十神 group or palace
  final ActivationEffect effect;

  /// null matches any stance.
  final int? stance;
  final String domain;
  final String subtype;
  final EventPolarity polarity;

  /// Restrict to one gender (男命财为妻, 女命官为夫).
  final Gender? gender;

  /// Require the activation to have come from a particular 干支 relationship.
  ///
  /// Only for readings that genuinely turn on *how* something was hit —
  /// 官杀逢刑 is 官非, while 官杀逢冲 is a change of post. Everything else
  /// matches on [effect] and leaves this null.
  final InteractionKind? via;

  const _EventRule({
    required this.target,
    required this.effect,
    required this.domain,
    required this.subtype,
    required this.polarity,
    this.stance,
    this.gender,
    this.via,
  });
}

/// One activation a [_ConjunctionRule] requires to be present.
class _Need {
  final String target;
  final String targetKind;
  final Set<ActivationEffect> effects;

  /// Acceptable 喜忌 values; null matches any.
  ///
  /// A set rather than a single value because several of these readings turn
  /// on 「不是忌神」 rather than on 「是喜神」 — 伤官见官 is a problem when
  /// the 食伤 is 忌, and unremarkable when it is not.
  final Set<int>? stance;
  final Set<InteractionKind>? via;

  const _Need({
    required this.target,
    required this.effects,
    this.targetKind = '十神',
    this.stance,
    this.via,
  });

  bool matches(Activation a) =>
      a.target == target &&
      a.targetKind == targetKind &&
      effects.contains(a.effect) &&
      (stance == null || stance!.contains(a.stance)) &&
      (via == null || (a.via != null && via!.contains(a.via)));
}

/// An event that only exists when several things happen at once.
///
/// Single-target rules cannot say 「日主受克，同时日柱逢刑冲」 — and the
/// readings that most need saying carefully (手术、寿元关注) are exactly the
/// ones that classically require a convergence rather than one signal. A
/// conjunction is scored on its **weakest** member: a chain is no stronger
/// than its weakest link, and scoring on the strongest would let one loud
/// activation drag in a claim the rest of the chart does not support.
class _ConjunctionRule {
  final List<_Need> needs;
  final String domain;
  final String subtype;
  final EventPolarity polarity;

  /// Multiplies the weakest member's intensity. Conjunctions are rarer and
  /// their claims are heavier, so they are not automatically stronger than a
  /// plain rule — this is where that is tuned.
  final double weight;

  /// Require the 岁运 pillar of this layer to carry a 五行 in its branch.
  ///
  /// A property of the pillar rather than of an activation, so it cannot be
  /// expressed as a [_Need]. Exists for 置业安家: 土为田宅之基, which
  /// strengthens the reading without being required for it — hence a second,
  /// heavier rule variant rather than a condition on the first.
  final String? zhiWuXing;

  const _ConjunctionRule({
    required this.needs,
    required this.domain,
    required this.subtype,
    required this.polarity,
    this.weight = 1.0,
    this.zhiWuXing,
  });
}

/// Turns activations into typed event candidates.
///
/// Previously the jump from "官星被引动" to "a promotion in March" was made
/// entirely inside the prompt. Here structures map to event *classes* with a
/// stated basis, and the model is left to narrate them rather than to invent
/// which life area a 十神 belongs to.
class EventInferenceEngine {
  static const List<_EventRule> _rules = [
    // ---------------- 官杀 ----------------
    _EventRule(
      target: '官杀', effect: ActivationEffect.strengthen, stance: 1,
      domain: EventDomain.career, subtype: '职位晋升',
      polarity: EventPolarity.favourable,
    ),
    _EventRule(
      target: '官杀', effect: ActivationEffect.strengthen, stance: -1,
      domain: EventDomain.career, subtype: '职场是非',
      polarity: EventPolarity.adverse,
    ),
    _EventRule(
      target: '官杀', effect: ActivationEffect.strengthen, stance: -1,
      domain: EventDomain.health, subtype: '劳神耗气',
      polarity: EventPolarity.adverse,
    ),
    _EventRule(
      target: '官杀', effect: ActivationEffect.release,
      domain: EventDomain.career, subtype: '职务变动',
      polarity: EventPolarity.mixed,
    ),
    _EventRule(
      target: '官杀', effect: ActivationEffect.bind,
      domain: EventDomain.career, subtype: '权责加重',
      polarity: EventPolarity.mixed,
    ),
    _EventRule(
      target: '官杀', effect: ActivationEffect.damage,
      domain: EventDomain.career, subtype: '离职转换',
      polarity: EventPolarity.adverse,
    ),
    // 女命以官杀为夫星.
    _EventRule(
      target: '官杀', effect: ActivationEffect.strengthen,
      domain: EventDomain.marriage, subtype: '婚恋成合',
      polarity: EventPolarity.mixed, gender: Gender.female,
    ),
    _EventRule(
      target: '官杀', effect: ActivationEffect.release,
      domain: EventDomain.marriage, subtype: '感情生变',
      polarity: EventPolarity.mixed, gender: Gender.female,
    ),

    // 官杀逢刑 —— 官非。刑与冲同为 damage/release，effect 层面分不开，
    // 故这两条用 via 指名要 刑。官杀为喜时逢刑仍是是非（已有「职场是非」），
    // 为忌或中性时才断官非。
    _EventRule(
      target: '官杀', effect: ActivationEffect.damage, stance: -1,
      via: InteractionKind.punishment,
      domain: EventDomain.career, subtype: '官非诉讼',
      polarity: EventPolarity.adverse,
    ),
    _EventRule(
      target: '官杀', effect: ActivationEffect.damage, stance: 0,
      via: InteractionKind.punishment,
      domain: EventDomain.career, subtype: '官非诉讼',
      polarity: EventPolarity.adverse,
    ),

    // ---------------- 神煞 ----------------
    // 驿马 and 天乙贵人 are the only two 神煞 fed in as event targets (see
    // LuckActivationEngine._eventShenSha). They carry no 喜忌 of their own,
    // so these rules are stance-agnostic and the polarity is 参半 or 吉 by
    // the nature of the 神煞 itself, never by the structure.
    _EventRule(
      target: '驿马', effect: ActivationEffect.release,
      domain: EventDomain.career, subtype: '远行出行',
      polarity: EventPolarity.mixed,
    ),
    _EventRule(
      target: '驿马', effect: ActivationEffect.strengthen,
      domain: EventDomain.career, subtype: '远行出行',
      polarity: EventPolarity.mixed,
    ),

    // ---------------- 财星 ----------------
    _EventRule(
      target: '财星', effect: ActivationEffect.strengthen, stance: 1,
      domain: EventDomain.wealth, subtype: '收入增益',
      polarity: EventPolarity.favourable,
    ),
    _EventRule(
      target: '财星', effect: ActivationEffect.strengthen, stance: -1,
      domain: EventDomain.wealth, subtype: '因财劳碌',
      polarity: EventPolarity.adverse,
    ),
    _EventRule(
      target: '财星', effect: ActivationEffect.release,
      domain: EventDomain.wealth, subtype: '资产变动',
      polarity: EventPolarity.mixed,
    ),
    _EventRule(
      target: '财星', effect: ActivationEffect.damage,
      domain: EventDomain.wealth, subtype: '破财损耗',
      polarity: EventPolarity.adverse,
    ),
    // 男命以财为妻星.
    _EventRule(
      target: '财星', effect: ActivationEffect.strengthen,
      domain: EventDomain.marriage, subtype: '婚恋成合',
      polarity: EventPolarity.mixed, gender: Gender.male,
    ),
    _EventRule(
      target: '财星', effect: ActivationEffect.release,
      domain: EventDomain.marriage, subtype: '感情生变',
      polarity: EventPolarity.mixed, gender: Gender.male,
    ),

    // ---------------- 印星 ----------------
    _EventRule(
      target: '印星', effect: ActivationEffect.strengthen, stance: 1,
      domain: EventDomain.study, subtype: '文书学业',
      polarity: EventPolarity.favourable,
    ),
    _EventRule(
      target: '印星', effect: ActivationEffect.damage,
      domain: EventDomain.study, subtype: '学途受阻',
      polarity: EventPolarity.adverse,
    ),
    _EventRule(
      target: '印星', effect: ActivationEffect.release,
      domain: EventDomain.study, subtype: '进修拓展',
      polarity: EventPolarity.mixed,
    ),

    // ---------------- 食伤 ----------------
    _EventRule(
      target: '食伤', effect: ActivationEffect.strengthen, stance: 1,
      domain: EventDomain.study, subtype: '技艺才华',
      polarity: EventPolarity.favourable,
    ),
    _EventRule(
      target: '食伤', effect: ActivationEffect.strengthen, stance: -1,
      domain: EventDomain.health, subtype: '劳神耗气',
      polarity: EventPolarity.adverse,
    ),
    _EventRule(
      target: '食伤', effect: ActivationEffect.strengthen,
      domain: EventDomain.career, subtype: '创业自立',
      polarity: EventPolarity.mixed,
    ),
    _EventRule(
      target: '食伤', effect: ActivationEffect.release,
      domain: EventDomain.career, subtype: '离职转换',
      polarity: EventPolarity.mixed,
    ),

    // ---------------- 比劫 ----------------
    _EventRule(
      target: '比劫', effect: ActivationEffect.strengthen, stance: -1,
      domain: EventDomain.wealth, subtype: '破财损耗',
      polarity: EventPolarity.adverse,
    ),
    _EventRule(
      target: '比劫', effect: ActivationEffect.strengthen, stance: 1,
      domain: EventDomain.career, subtype: '创业自立',
      polarity: EventPolarity.favourable,
    ),

    // ------- 去忌神则吉 -------
    //
    // These are the counterpart the table was missing entirely. An Activation's
    // stance is already effect-polarity × the chart's 喜忌, so stance == 1 on a
    // disruptive effect means the 岁运 removed something the 格局 did not want.
    // 冲去忌神、合去忌神、制其忌神 are all classically favourable; with every
    // release/damage/bind/weaken rule left stance-agnostic, the engine could
    // only ever report them as change or loss.
    _EventRule(
      target: '官杀', effect: ActivationEffect.release, stance: 1,
      domain: EventDomain.career, subtype: '压力解除',
      polarity: EventPolarity.favourable,
    ),
    _EventRule(
      target: '官杀', effect: ActivationEffect.bind, stance: 1,
      domain: EventDomain.career, subtype: '压力解除',
      polarity: EventPolarity.favourable,
    ),
    _EventRule(
      target: '官杀', effect: ActivationEffect.damage, stance: 1,
      domain: EventDomain.career, subtype: '摆脱束缚',
      polarity: EventPolarity.favourable,
    ),
    _EventRule(
      target: '财星', effect: ActivationEffect.damage, stance: 1,
      domain: EventDomain.wealth, subtype: '卸下重负',
      polarity: EventPolarity.favourable,
    ),
    _EventRule(
      target: '印星', effect: ActivationEffect.damage, stance: 1,
      domain: EventDomain.study, subtype: '破印得用',
      polarity: EventPolarity.favourable,
    ),
    _EventRule(
      target: '食伤', effect: ActivationEffect.damage, stance: 1,
      domain: EventDomain.career, subtype: '收束心性',
      polarity: EventPolarity.favourable,
    ),
    _EventRule(
      target: '比劫', effect: ActivationEffect.damage, stance: 1,
      domain: EventDomain.wealth, subtype: '免于分夺',
      polarity: EventPolarity.favourable,
    ),
    _EventRule(
      target: '比劫', effect: ActivationEffect.release, stance: 1,
      domain: EventDomain.wealth, subtype: '免于分夺',
      polarity: EventPolarity.favourable,
    ),

    // ---------------- 宫位 ----------------
    _EventRule(
      target: '日柱', effect: ActivationEffect.release,
      domain: EventDomain.marriage, subtype: '配偶宫动',
      polarity: EventPolarity.mixed,
    ),
    _EventRule(
      target: '日柱', effect: ActivationEffect.bind,
      domain: EventDomain.marriage, subtype: '情感牵绊',
      polarity: EventPolarity.mixed,
    ),
    _EventRule(
      target: '日柱', effect: ActivationEffect.damage,
      domain: EventDomain.health, subtype: '身心失调',
      polarity: EventPolarity.adverse,
    ),
    _EventRule(
      target: '月柱', effect: ActivationEffect.release,
      domain: EventDomain.career, subtype: '职务变动',
      polarity: EventPolarity.mixed,
    ),
    // 时柱为子女宫、主晚年 — not the 配偶宫, so a clash here is a 子女
    // matter, not a marriage one.
    _EventRule(
      target: '时柱', effect: ActivationEffect.release,
      domain: EventDomain.marriage, subtype: '子女之事',
      polarity: EventPolarity.mixed,
    ),
    _EventRule(
      target: '时柱', effect: ActivationEffect.damage,
      domain: EventDomain.health, subtype: '身心失调',
      polarity: EventPolarity.adverse,
    ),
    // 年柱冲主离祖迁移，而非职务本身的升降.
    _EventRule(
      target: '年柱', effect: ActivationEffect.release,
      domain: EventDomain.career, subtype: '迁移变动',
      polarity: EventPolarity.mixed,
    ),
  ];

  /// Below this an event candidate is not worth reporting.
  ///
  /// An event needs a substantial relationship behind it — a 大运/流年 level
  /// 冲合刑 or a 十神 arriving transparently — not a 六破 between two hidden
  /// traces. The floor was low enough that faint relations became life events.
  /// Events that require a convergence rather than one signal.
  ///
  /// Both of these are heavy claims, so both are deliberately hard to trigger.
  /// Neither names an outcome: 手术风险 marks a year where the classical
  /// 「杀攻身而日柱受刑冲」 pattern converges, and 寿元关注 marks a *range* to
  /// watch one's health in. Nothing here marks an end of life, and nothing
  /// here can — the engine has no rule that outputs one.
  static const List<_ConjunctionRule> _conjunctions = [
    // 手术风险：七杀/官杀攻身为忌，同时日柱（自身宫）逢冲或刑。
    _ConjunctionRule(
      needs: [
        _Need(
          target: '官杀',
          effects: {ActivationEffect.strengthen},
          stance: {-1},
        ),
        _Need(
          target: '日柱',
          targetKind: '宫位',
          effects: {ActivationEffect.release, ActivationEffect.damage},
          via: {InteractionKind.clash, InteractionKind.punishment},
        ),
      ],
      domain: EventDomain.health,
      subtype: '手术风险',
      polarity: EventPolarity.adverse,
      weight: 0.95,
    ),

    // ---- 贵人相助：天乙贵人 + 一个落地的渠道 ------------------------------
    //
    // 上一版把「岁运带天乙贵人」直接断为贵人相助，实测它成了全 App 最大的
    // 吉性事件类（240 盘一年里 142 次，比收入增益 86 与职位晋升 73 都多）。
    // 那不是一个能站住的读法：天乙贵人临是常见的修饰，不是一年的主事。
    //
    // 贵人要落到实处得有渠道 —— 印（师长、文书、提携）或官（位置、机会）。
    // 两条分写，因为 _Need 只匹配单一目标。
    _ConjunctionRule(
      needs: [
        _Need(target: '天乙贵人', targetKind: '神煞', effects: {
          ActivationEffect.strengthen,
          ActivationEffect.bind,
          ActivationEffect.release,
        }),
        _Need(
          target: '印星',
          effects: {ActivationEffect.strengthen},
          stance: {1, 0},
        ),
      ],
      domain: EventDomain.study,
      subtype: '贵人相助',
      polarity: EventPolarity.favourable,
      weight: 0.95,
    ),
    _ConjunctionRule(
      needs: [
        _Need(target: '天乙贵人', targetKind: '神煞', effects: {
          ActivationEffect.strengthen,
          ActivationEffect.bind,
          ActivationEffect.release,
        }),
        _Need(
          target: '官杀',
          effects: {ActivationEffect.strengthen},
          stance: {1},
        ),
      ],
      domain: EventDomain.study,
      subtype: '贵人相助',
      polarity: EventPolarity.favourable,
      weight: 0.95,
    ),

    // ---- 出国留学：驿马主动 + 印星主学业 --------------------------------
    //
    // 「驿马临印，因学奔波」。必要条件是岁运带驿马（动象），加强条件是同层
    // 印星被引动（求学象）。分两条：印星为喜用时把握度更高，中性时仍成立但
    // 弱一档；印星为忌则不出——那是奔波而非求学。
    _ConjunctionRule(
      needs: [
        _Need(target: '驿马', targetKind: '神煞', effects: {
          ActivationEffect.strengthen,
          ActivationEffect.release,
        }),
        _Need(
          target: '印星',
          effects: {ActivationEffect.strengthen},
          stance: {1},
        ),
      ],
      domain: EventDomain.study,
      subtype: '负笈远游',
      // 出国是一件**发生**的事，不是一份收益 —— 与「婚恋成合」「进修拓展」
      // 同类，故 mixed。把人生大事标成吉，会让整台引擎系统性偏乐观：实测
      // 这一批规则曾把 240 盘的吉:凶 从 1.14 推到 1.60。
      polarity: EventPolarity.mixed,
      weight: 1.0,
    ),
    _ConjunctionRule(
      needs: [
        _Need(target: '驿马', targetKind: '神煞', effects: {
          ActivationEffect.strengthen,
          ActivationEffect.release,
        }),
        _Need(
          target: '印星',
          effects: {ActivationEffect.strengthen},
          stance: {0},
        ),
      ],
      domain: EventDomain.study,
      subtype: '负笈远游',
      polarity: EventPolarity.mixed,
      weight: 0.8,
    ),

    // ---- 买房：印主屋宅 + 财主购买力 ------------------------------------
    //
    // 印星是「有房象」，财星是「买得起」。两者缺一都不成事：印动而无财是
    // 想住不是能买，财动而无印是有钱不是置产。
    _ConjunctionRule(
      needs: [
        _Need(
          target: '财星',
          effects: {ActivationEffect.strengthen},
          stance: {1},
        ),
        _Need(target: '印星', effects: {ActivationEffect.strengthen}),
      ],
      domain: EventDomain.wealth,
      subtype: '置业安家',
      // 置产是承担，不是进项：同年既是资产也是负债。mixed。
      polarity: EventPolarity.mixed,
      weight: 0.95,
    ),

    // 土为田宅之基。财印同现而岁运地支属土（尤其辰戌丑未财库），置产之象更
    // 实，故单列一条更重的，而不是把土设成必要条件。
    _ConjunctionRule(
      needs: [
        _Need(
          target: '财星',
          effects: {ActivationEffect.strengthen},
          stance: {1},
        ),
        _Need(target: '印星', effects: {ActivationEffect.strengthen}),
      ],
      zhiWuXing: '土',
      domain: EventDomain.wealth,
      subtype: '置业安家',
      polarity: EventPolarity.mixed,
      weight: 1.05,
    ),

    // ---- 搬家：驿马动 + 居所（印星）被冲合刑 ------------------------------
    //
    // 与买房同源而异象：动的是居所本身而不是购买力，所以印星这里要的是被
    // **冲/合/刑**，不是被生扶。
    _ConjunctionRule(
      needs: [
        _Need(target: '驿马', targetKind: '神煞', effects: {
          ActivationEffect.strengthen,
          ActivationEffect.release,
        }),
        _Need(target: '印星', effects: {
          ActivationEffect.release,
          ActivationEffect.bind,
          ActivationEffect.damage,
        }),
      ],
      domain: EventDomain.career,
      subtype: '迁居搬家',
      polarity: EventPolarity.mixed,
      weight: 0.9,
    ),

    // ---- 名气提升：食伤主才华 + 官星主名位 -------------------------------
    //
    // 食伤是名声的来源，官星是社会的认可，两者同现才是「才华被认可」。
    // 关键是那条例外：**伤官见官而无制**主是非不主名气，所以食伤为忌时
    // 这条不出——stance 限定在喜与中性。
    _ConjunctionRule(
      needs: [
        _Need(
          target: '食伤',
          effects: {ActivationEffect.strengthen},
          stance: {1},
        ),
        _Need(target: '官杀', effects: {ActivationEffect.strengthen}),
      ],
      domain: EventDomain.career,
      subtype: '名声显扬',
      polarity: EventPolarity.favourable,
      weight: 0.9,
    ),

    // 寿元关注：在手术风险之上再加一条 —— 印星或比劫（身之根）同时被冲刑。
    // 三条同年齐备本就罕见，这正是意图：区间提示，不是断点。
    _ConjunctionRule(
      needs: [
        _Need(
          target: '官杀',
          effects: {ActivationEffect.strengthen},
          stance: {-1},
        ),
        _Need(
          target: '日柱',
          targetKind: '宫位',
          effects: {ActivationEffect.release, ActivationEffect.damage},
          via: {InteractionKind.clash, InteractionKind.punishment},
        ),
        _Need(
          target: '印星',
          effects: {ActivationEffect.release, ActivationEffect.damage},
        ),
      ],
      domain: EventDomain.health,
      subtype: '寿元关注',
      polarity: EventPolarity.adverse,
      weight: 0.9,
    ),
  ];

  static const double _minConfidence = 0.25;

  /// Effects that describe a standing relation rather than something
  /// happening.
  ///
  /// 克 is continuous — it holds all year, every year — and bazi_core reports
  /// 天干相克 across most of the chart at once, which is why the activation
  /// engine already weights it as ambient. Letting it also emit events meant
  /// every reading picked up background 破财/情志郁结 that no 冲合刑害 had
  /// actually triggered, and since a chart has more 喜 parties than 忌 ones,
  /// that background skewed adverse.
  static const Set<ActivationEffect> _nonEventEffects = {
    ActivationEffect.weaken,
  };

  static List<EventCandidate> infer({
    required ChartResult chart,
    required NatalStructure structure,
    required TemporalContext context,
    required List<Activation> activations,
    Set<String> establishedThemes = const {},
  }) {
    final gender = chart.input.gender;
    final out = <String, EventCandidate>{};

    for (final a in activations) {
      // 流日不创事, enforced here as well as in the 应期 ranking: an event
      // may not originate at a layer that is only allowed to trigger.
      if (!a.layer.canOriginateEvents &&
          a.targetKind == '十神' &&
          establishedThemes.isNotEmpty &&
          !establishedThemes.contains(a.target)) {
        continue;
      }

      if (_nonEventEffects.contains(a.effect)) continue;

      for (final r in _rules) {
        if (r.target != a.target) continue;
        if (r.effect != a.effect) continue;
        if (r.stance != null && r.stance != a.stance) continue;
        if (r.gender != null && r.gender != gender) continue;
        if (r.via != null && r.via != a.via) continue;

        // Structural support: an event resting on a 十神 that is not even
        // operative in the natal chart is weaker than one that is.
        final support = switch (a.targetKind) {
          '十神' =>
            (structure.presence[a.target]?.isOperative ?? false) ? 1.0 : 0.6,
          // Like a 宫位: neither a 神煞 nor a palace has 通根 to test, so
          // neither can be scored on structural presence. The ordering that
          // does matter — 天干临位 > 地支本气 > 神煞 — is already carried by
          // the activation's intensity.
          '神煞' => 0.85,
          _ => 0.85,
        };
        final confidence = (a.intensity * support).clamp(0.0, 1.0);
        if (confidence < _minConfidence) continue;

        final key = '${r.domain}|${r.subtype}';
        final basis = <String>[
          '原局：${structure.pattern.geJu}·${structure.status.label}'
              '（用神${structure.xiangShen.isEmpty ? structure.pattern.geJu : structure.xiangShen.join('、')}）',
          if (a.targetKind == '十神')
            '${a.target}在原局${structure.presence[a.target]?.level ?? '未详'}'
          else if (a.targetKind == '神煞')
            '原局带${a.target}',
          '${a.layer.label}：${a.mechanism}',
          '断为${r.domain}·${r.subtype}（${r.polarity.label}）',
        ];

        final prior = out[key];
        if (prior == null || confidence > prior.confidence) {
          out[key] = EventCandidate(
            domain: r.domain,
            subtype: r.subtype,
            layer: a.layer,
            polarity: r.polarity,
            confidence: confidence,
            basis: basis,
          );
        }
      }
    }

    _inferConjunctions(structure, context, activations, out);

    final list = out.values.toList()
      ..sort((a, b) {
        final byConfidence = b.confidence.compareTo(a.confidence);
        if (byConfidence != 0) return byConfidence;
        // Stable ordering for equal confidence.
        return ('${a.domain}${a.subtype}').compareTo('${b.domain}${b.subtype}');
      });
    return list;
  }

  /// Add the events that need several activations at once.
  ///
  /// Evaluated per layer: a 大运 condition and a 流年 condition are not the
  /// same year converging, they are two different statements, and treating
  /// them as one would make the heaviest claims the easiest to trigger.
  static void _inferConjunctions(
    NatalStructure structure,
    TemporalContext context,
    List<Activation> activations,
    Map<String, EventCandidate> out,
  ) {
    final byLayer = <TemporalLayer, List<Activation>>{};
    for (final a in activations) {
      byLayer.putIfAbsent(a.layer, () => []).add(a);
    }

    for (final entry in byLayer.entries) {
      final layer = entry.key;
      if (!layer.canOriginateEvents) continue;

      for (final rule in _conjunctions) {
        if (rule.zhiWuXing != null &&
            !context.luckPillars.any((p) =>
                p.layer == layer && p.zhiWuXing == rule.zhiWuXing)) {
          continue;
        }

        final matched = <Activation>[];
        for (final need in rule.needs) {
          Activation? best;
          for (final a in entry.value) {
            if (!need.matches(a)) continue;
            if (best == null || a.intensity > best.intensity) best = a;
          }
          if (best == null) break;
          matched.add(best);
        }
        if (matched.length != rule.needs.length) continue;

        // As strong as the weakest link.
        final weakest = matched
            .map((a) => a.intensity)
            .reduce((a, b) => a < b ? a : b);
        final confidence = (weakest * rule.weight).clamp(0.0, 1.0);
        if (confidence < _minConfidence) continue;

        final key = '${rule.domain}|${rule.subtype}';
        final prior = out[key];
        if (prior != null && prior.confidence >= confidence) continue;

        out[key] = EventCandidate(
          domain: rule.domain,
          subtype: rule.subtype,
          layer: layer,
          polarity: rule.polarity,
          confidence: confidence,
          basis: [
            '原局：${structure.pattern.geJu}·${structure.status.label}',
            for (final a in matched) '${a.layer.label}：${a.mechanism}',
            if (rule.zhiWuXing != null)
              '${layer.label}地支属${rule.zhiWuXing}',
            '数条同时成立，断为${rule.domain}·${rule.subtype}'
                '（${rule.polarity.label}）',
          ],
        );
      }
    }
  }

  /// Candidates grouped by the output section they belong to.
  static Map<String, List<EventCandidate>> bySection(
      List<EventCandidate> candidates) {
    final out = <String, List<EventCandidate>>{};
    for (final c in candidates) {
      out.putIfAbsent(c.section, () => []).add(c);
    }
    return out;
  }
}
