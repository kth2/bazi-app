import '../analysis/event_inference.dart';

/// How heavy a claim a kind makes about someone's life.
enum EventSensitivity {
  /// Ordinary.
  normal,

  /// 离婚、手术、寿元、官司 — the readings a person is most likely to be
  /// upset by, and most likely to want anyway.
  ///
  /// **Shown by default.** These were hidden until the owner decided that
  /// withholding a reading is itself a judgement, and that the person asking
  /// is the one who gets to weigh whether they believe it. What survives that
  /// decision is the honesty rather than the gate: a sensitive kind carries a
  /// standing disclaimer, is worded as years to pay attention to rather than
  /// as a verdict, and can be switched off individually in settings.
  sensitive,
}

/// One kind of life event the timeline can display.
///
/// The catalog is a translation layer, not a second engine: every kind maps
/// onto a (domain, subtype) pair the [EventInferenceEngine] already produces.
/// Nothing here decides *whether* an event happens — only how it is named,
/// coloured and gated when it does.
class EventKind {
  /// Stable id, persisted with user-placed events. Never reuse or renumber:
  /// a saved event resolves its kind through this string.
  final String id;

  /// What the user sees.
  final String label;

  /// The engine's own domain (事业/财富/婚姻/学业发展/健康).
  final String domain;

  /// The engine's subtype within that domain.
  final String subtype;

  /// True for things that are naturally a stretch of time (财运高峰) rather
  /// than a moment (结婚).
  final bool defaultSpan;

  final EventSensitivity sensitivity;

  /// Required for [EventSensitivity.sensitive] kinds.
  final String? disclaimer;

  /// Ages (虚岁) outside which this kind is not *suggested*.
  ///
  /// The inference engine has no notion of age: 官杀 being stirred at 六岁
  /// scores exactly as it does at 三十六. Left alone the timeline offers a
  /// six-year-old 子女之事 and a hundred-year-old 升职晋升, which discredits
  /// the markers that are worth reading.
  ///
  /// [maxAge] bounds what a *marker* claims, and is emphatically not a
  /// statement about 寿元 — health kinds carry no upper bound at all, and no
  /// kind anywhere in this app marks an end of life.
  final int minAge;
  final int? maxAge;

  const EventKind({
    required this.id,
    required this.label,
    required this.domain,
    required this.subtype,
    this.defaultSpan = false,
    this.sensitivity = EventSensitivity.normal,
    this.disclaimer,
    this.minAge = 1,
    this.maxAge,
  });

  bool suits(int age) => age >= minAge && (maxAge == null || age <= maxAge!);

  bool get isSensitive => sensitivity == EventSensitivity.sensitive;

  /// The engine key this kind is fed by.
  String get engineKey => '$domain|$subtype';
}

/// The registry of event kinds.
///
/// Coverage note: every kind the requirements named now exists. The three
/// that needed conjunction 判据 — 出国留学 (驿马+印星), 买房搬家 (印星+财星 /
/// 驿马+印星受冲), 名气提升 (食伤+官星) — are built on criteria the owner
/// supplied; what each one can and cannot express is recorded in
/// `docs/life-timeline-design.md` §16 rather than papered over here.
class EventCatalog {
  const EventCatalog._();

  /// The disclaimer every sensitive kind carries.
  /// Extra wording for 寿元关注 — the one kind a reader could most easily
  /// take for something it is not.
  static const String kLongevityDisclaimer =
      '「寿元关注」标的是需要特别留意健康的年份区间，不是生命终点。'
      '命理无法预知生死，本应用不做也无法做寿命预测。如有健康疑虑请就医。';

  static const String kGuardedDisclaimer =
      '以下标记依传统命理规则推算，仅供参考，不构成医疗、法律或财务建议。'
      '命理无法预知具体事件，如有健康疑虑请就医。';

  /// Age floors and ceilings, in 虚岁. Coarse on purpose — they exist to keep
  /// obviously absurd markers off the axis, not to model a life.
  static const int _kSchoolAge = 5;
  static const int _kMarriageAge = 16;
  static const int _kWorkingAge = 16;
  static const int _kWealthAge = 14;
  static const int _kParentingAge = 20;

  /// Career, wealth, marriage and study markers stop being suggested here.
  /// Health markers have no ceiling, and nothing in the app marks 寿元.
  static const int _kWorkingMaxAge = 85;

  static const List<EventKind> kinds = [
    // ---------------------------------------------------------- 事业
    EventKind(
      id: 'career.promotion',
      label: '升职晋升',
      domain: EventDomain.career,
      subtype: '职位晋升',
      minAge: _kWorkingAge,
      maxAge: _kWorkingMaxAge,
    ),
    EventKind(
      id: 'career.responsibility',
      label: '权责加重',
      domain: EventDomain.career,
      subtype: '权责加重',
      defaultSpan: true,
      minAge: _kWorkingAge,
      maxAge: _kWorkingMaxAge,
    ),
    EventKind(
      id: 'career.change',
      label: '职务变动',
      domain: EventDomain.career,
      subtype: '职务变动',
      minAge: _kWorkingAge,
      maxAge: _kWorkingMaxAge,
    ),
    EventKind(
      id: 'career.resign',
      label: '离职转换',
      domain: EventDomain.career,
      subtype: '离职转换',
      minAge: _kWorkingAge,
      maxAge: _kWorkingMaxAge,
    ),
    EventKind(
      id: 'career.venture',
      label: '创业自立',
      domain: EventDomain.career,
      subtype: '创业自立',
      minAge: _kWorkingAge,
      maxAge: _kWorkingMaxAge,
    ),
    EventKind(
      id: 'career.dispute',
      label: '职场是非',
      domain: EventDomain.career,
      subtype: '职场是非',
      minAge: _kWorkingAge,
      maxAge: _kWorkingMaxAge,
    ),
    EventKind(
      id: 'career.relocation',
      label: '迁移变动',
      domain: EventDomain.career,
      subtype: '迁移变动',
      maxAge: _kWorkingMaxAge,
    ),
    EventKind(
      id: 'career.relief',
      label: '压力解除',
      domain: EventDomain.career,
      subtype: '压力解除',
      defaultSpan: true,
      minAge: _kWorkingAge,
      maxAge: _kWorkingMaxAge,
    ),
    EventKind(
      id: 'career.freedom',
      label: '摆脱束缚',
      domain: EventDomain.career,
      subtype: '摆脱束缚',
      minAge: _kWorkingAge,
      maxAge: _kWorkingMaxAge,
    ),
    EventKind(
      id: 'career.restraint',
      label: '收束心性',
      domain: EventDomain.career,
      subtype: '收束心性',
      defaultSpan: true,
      minAge: _kWorkingAge,
      maxAge: _kWorkingMaxAge,
    ),

    // 驿马被冲动 —— 出行、外派、搬迁。留学/移民需「驿马 + 印星」这类
    // 组合判据，引擎目前只支持单目标规则，故不在此伪造。
    EventKind(
      id: 'career.travel',
      label: '远行出行',
      domain: EventDomain.career,
      subtype: '远行出行',
      maxAge: _kWorkingMaxAge,
    ),

    // ---------------------------------------------------------- 财富
    EventKind(
      id: 'wealth.income',
      label: '财运高峰',
      domain: EventDomain.wealth,
      subtype: '收入增益',
      defaultSpan: true,
      minAge: _kWealthAge,
      maxAge: _kWorkingMaxAge,
    ),
    EventKind(
      id: 'wealth.invest',
      label: '投资置产',
      domain: EventDomain.wealth,
      subtype: '投资置产',
      minAge: _kWealthAge,
      maxAge: _kWorkingMaxAge,
    ),
    EventKind(
      id: 'wealth.windfall',
      label: '意外之财',
      domain: EventDomain.wealth,
      subtype: '意外之财',
      minAge: _kWealthAge,
      maxAge: _kWorkingMaxAge,
    ),
    // 用户已明确：破财风险不默认关闭。
    EventKind(
      id: 'wealth.loss',
      label: '破财风险',
      domain: EventDomain.wealth,
      subtype: '破财损耗',
      minAge: _kWealthAge,
      maxAge: _kWorkingMaxAge,
    ),
    EventKind(
      id: 'wealth.toil',
      label: '因财劳碌',
      domain: EventDomain.wealth,
      subtype: '因财劳碌',
      defaultSpan: true,
      minAge: _kWealthAge,
      maxAge: _kWorkingMaxAge,
    ),
    EventKind(
      id: 'wealth.assets',
      label: '资产变动',
      domain: EventDomain.wealth,
      subtype: '资产变动',
      minAge: _kWealthAge,
      maxAge: _kWorkingMaxAge,
    ),
    EventKind(
      id: 'wealth.unburden',
      label: '卸下重负',
      domain: EventDomain.wealth,
      subtype: '卸下重负',
      minAge: _kWealthAge,
      maxAge: _kWorkingMaxAge,
    ),
    EventKind(
      id: 'wealth.kept',
      label: '免于分夺',
      domain: EventDomain.wealth,
      subtype: '免于分夺',
      minAge: _kWealthAge,
      maxAge: _kWorkingMaxAge,
    ),

    // 印星（屋宅）+ 财星（购买力）同时被引动。
    EventKind(
      id: 'wealth.home',
      label: '置业安家',
      domain: EventDomain.wealth,
      subtype: '置业安家',
      minAge: _kWorkingAge,
      maxAge: _kWorkingMaxAge,
    ),

    // ---------------------------------------------------------- 婚姻
    EventKind(
      id: 'marriage.union',
      label: '婚恋成合',
      domain: EventDomain.marriage,
      subtype: '婚恋成合',
      minAge: _kMarriageAge,
      maxAge: _kWorkingMaxAge,
    ),
    // 需求点名的「离婚风险」，落在引擎已有的这两个子类型上。默认显示。
    EventKind(
      id: 'marriage.rupture',
      label: '感情生变',
      domain: EventDomain.marriage,
      subtype: '感情生变',
      sensitivity: EventSensitivity.sensitive,
      disclaimer: kGuardedDisclaimer,
      minAge: _kMarriageAge,
      maxAge: _kWorkingMaxAge,
    ),
    EventKind(
      id: 'marriage.palace',
      label: '配偶宫动',
      domain: EventDomain.marriage,
      subtype: '配偶宫动',
      sensitivity: EventSensitivity.sensitive,
      disclaimer: kGuardedDisclaimer,
      minAge: _kMarriageAge,
      maxAge: _kWorkingMaxAge,
    ),
    EventKind(
      id: 'marriage.bond',
      label: '情感牵绊',
      domain: EventDomain.marriage,
      subtype: '情感牵绊',
      defaultSpan: true,
      minAge: _kMarriageAge,
      maxAge: _kWorkingMaxAge,
    ),
    EventKind(
      id: 'marriage.third',
      label: '第三者之扰',
      domain: EventDomain.marriage,
      subtype: '第三者之扰',
      minAge: _kMarriageAge,
      maxAge: _kWorkingMaxAge,
    ),
    EventKind(
      id: 'marriage.children',
      label: '子女之事',
      domain: EventDomain.marriage,
      subtype: '子女之事',
      minAge: _kParentingAge,
      maxAge: _kWorkingMaxAge,
    ),

    // 驿马动 + 印星（居所）被冲合刑。
    EventKind(
      id: 'career.moving',
      label: '迁居搬家',
      domain: EventDomain.career,
      subtype: '迁居搬家',
    ),

    // 食伤（才华）+ 官星（名位），且食伤非忌 —— 伤官见官无制主是非不主名。
    EventKind(
      id: 'career.fame',
      label: '名声显扬',
      domain: EventDomain.career,
      subtype: '名声显扬',
      minAge: _kWorkingAge,
      maxAge: _kWorkingMaxAge,
    ),

    // 官杀逢刑。刑与冲在 effect 层面同为 damage，故规则用 via 指名要刑。
    EventKind(
      id: 'career.lawsuit',
      label: '官非诉讼',
      domain: EventDomain.career,
      subtype: '官非诉讼',
      minAge: _kWorkingAge,
      maxAge: _kWorkingMaxAge,
      sensitivity: EventSensitivity.sensitive,
      disclaimer: kGuardedDisclaimer,
    ),

    // ---------------------------------------------------------- 学业发展
    EventKind(
      id: 'study.document',
      label: '文书学业',
      domain: EventDomain.study,
      subtype: '文书学业',
      minAge: _kSchoolAge,
    ),
    EventKind(
      id: 'study.exam',
      label: '考试资格',
      domain: EventDomain.study,
      subtype: '考试资格',
      minAge: _kSchoolAge,
    ),
    EventKind(
      id: 'study.craft',
      label: '技艺才华',
      domain: EventDomain.study,
      subtype: '技艺才华',
      defaultSpan: true,
      minAge: _kSchoolAge,
    ),
    EventKind(
      id: 'study.further',
      label: '进修拓展',
      domain: EventDomain.study,
      subtype: '进修拓展',
      defaultSpan: true,
      minAge: _kSchoolAge,
    ),
    EventKind(
      id: 'study.blocked',
      label: '学途受阻',
      domain: EventDomain.study,
      subtype: '学途受阻',
      minAge: _kSchoolAge,
    ),
    EventKind(
      id: 'study.freed',
      label: '破印得用',
      domain: EventDomain.study,
      subtype: '破印得用',
      minAge: _kSchoolAge,
    ),

    // 天乙贵人被引动。
    EventKind(
      id: 'study.patron',
      label: '贵人相助',
      domain: EventDomain.study,
      subtype: '贵人相助',
      minAge: _kSchoolAge,
    ),

    // 驿马（动）+ 印星（学）。出国留学的映射。
    EventKind(
      id: 'study.abroad',
      label: '负笈远游',
      domain: EventDomain.study,
      subtype: '负笈远游',
      minAge: _kSchoolAge,
      maxAge: _kWorkingMaxAge,
    ),

    // ---------------------------------------------------------- 健康
    EventKind(
      id: 'health.fatigue',
      label: '劳神耗气',
      domain: EventDomain.health,
      subtype: '劳神耗气',
      defaultSpan: true,
    ),
    EventKind(
      id: 'health.relapse',
      label: '旧患复发',
      domain: EventDomain.health,
      subtype: '旧患复发',
    ),
    EventKind(
      id: 'health.injury',
      label: '外伤意外',
      domain: EventDomain.health,
      subtype: '外伤意外',
    ),
    EventKind(
      id: 'health.mood',
      label: '情志郁结',
      domain: EventDomain.health,
      subtype: '情志郁结',
      defaultSpan: true,
    ),
    EventKind(
      id: 'health.imbalance',
      label: '身心失调',
      domain: EventDomain.health,
      subtype: '身心失调',
      defaultSpan: true,
    ),

    // 杀攻身为忌 + 日柱（自身宫）逢冲或刑，同一层同时成立。
    EventKind(
      id: 'health.surgery',
      label: '手术风险',
      domain: EventDomain.health,
      subtype: '手术风险',
      sensitivity: EventSensitivity.sensitive,
      disclaimer: kGuardedDisclaimer,
    ),

    // 在手术风险的两条之上再加「印星受冲刑」。
    //
    // 标的是**区间**，措辞是「需特别留意健康的年份」。引擎里没有任何一条
    // 规则会输出生命终点，这一条也不会——它只把几条同时成立的年份连成一段。
    EventKind(
      id: 'health.longevity',
      label: '寿元关注',
      domain: EventDomain.health,
      subtype: '寿元关注',
      defaultSpan: true,
      sensitivity: EventSensitivity.sensitive,
      disclaimer: kLongevityDisclaimer,
    ),
  ];

  static final Map<String, EventKind> byId = {for (final k in kinds) k.id: k};

  /// Engine `域|子类型` → kind.
  static final Map<String, EventKind> byEngineKey = {
    for (final k in kinds) k.engineKey: k,
  };

  static EventKind? forCandidate(EventCandidate c) =>
      byEngineKey['${c.domain}|${c.subtype}'];

  static List<EventKind> get sensitive => [
    for (final k in kinds)
      if (k.isSensitive) k,
  ];

  /// Ids shown when the user has changed nothing.
  /// Everything: nothing is hidden by default any more.
  static Set<String> get defaultEnabledIds => allIds;

  static Set<String> get allIds => {for (final k in kinds) k.id};
}
