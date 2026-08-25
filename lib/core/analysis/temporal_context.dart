import '../models/chart_result.dart';

/// The five layers a Bazi statement can live on.
///
/// Ordering is coarse → fine and carries real theory, not just presentation:
/// the natal chart *defines* what structures exist, 大运 shapes a decade,
/// 流年/流月 are where events actually form, and 流日 may only trigger a
/// theme that already exists above it — 流日只是引动应期，大事以流月流年为纲.
enum TemporalLayer { natal, decade, year, month, day }

/// Parses the `layer` field of a rule / condition. Accepts the Chinese label
/// or the enum name; anything unrecognised falls back to 原局, which is the
/// safe default since natal rules always evaluate.
TemporalLayer temporalLayerFromName(String? name) => switch (name) {
      '大运' || 'decade' => TemporalLayer.decade,
      '流年' || 'year' => TemporalLayer.year,
      '流月' || 'month' => TemporalLayer.month,
      '流日' || 'day' => TemporalLayer.day,
      _ => TemporalLayer.natal,
    };

extension TemporalLayerX on TemporalLayer {
  String get label => switch (this) {
        TemporalLayer.natal => '原局',
        TemporalLayer.decade => '大运',
        TemporalLayer.year => '流年',
        TemporalLayer.month => '流月',
        TemporalLayer.day => '流日',
      };

  /// Whether this layer may *introduce* a life theme of its own.
  ///
  /// 原局 defines the structure; 大运/流年/流月 can raise an event; 流日
  /// cannot — it only fires something already established above it.
  bool get canOriginateEvents => this != TemporalLayer.day;

  /// How much weight a statement made at this layer carries, used when
  /// combining evidence. 原局 outranks 大运 outranks 流年 …
  double get authority => switch (this) {
        TemporalLayer.natal => 1.0,
        TemporalLayer.decade => 0.8,
        TemporalLayer.year => 0.7,
        TemporalLayer.month => 0.5,
        TemporalLayer.day => 0.3,
      };

  bool isFinerThan(TemporalLayer other) => index > other.index;
}

/// What an interaction *does*, as distinct from what it is called.
///
/// The distinction matters downstream: 合 binds a stem so its function
/// cannot express (拘绊), 冲 shakes one loose (引动/冲开), and 刑害破克
/// damage it. An engine that only knows the Chinese name cannot tell those
/// apart.
enum InteractionKind {
  /// 六合/五合 — binds. The bound party's function is suspended until
  /// released (合就是拘绊，功能发挥不出).
  combination,

  /// 三合/三会/半合/拱合 — forms a局. Unlike 六合 this does not bind a party;
  /// it *manufactures* a strong element, so it feeds power in rather than
  /// switching a function off.
  formation,

  /// 冲 — shakes loose. Activates a dormant party, or breaks a fragile one.
  clash,

  /// 刑 — punishes. Damage, friction, legal/health flavour.
  punishment,

  /// 害/破 — erodes. Lesser damage.
  erosion,

  /// 克 — controls. Direct suppression.
  restraint,

  /// 暗合/相绝 and anything else with no clean activation semantics.
  other,
}

extension InteractionKindX on InteractionKind {
  String get label => switch (this) {
        InteractionKind.combination => '合绊',
        InteractionKind.formation => '成局',
        InteractionKind.clash => '冲动',
        InteractionKind.punishment => '刑伤',
        InteractionKind.erosion => '害破',
        InteractionKind.restraint => '克制',
        InteractionKind.other => '其他',
      };

  /// 冲/刑 shake a party loose; 三合成局 brings an element forcefully into
  /// play. Both are ways a dormant structure gets switched on.
  bool get activates =>
      this == InteractionKind.clash ||
      this == InteractionKind.punishment ||
      this == InteractionKind.formation;

  /// 合绊 and 克 switch a function off rather than on.
  bool get suppresses =>
      this == InteractionKind.combination || this == InteractionKind.restraint;

  /// Whether the interaction damages what it touches (as opposed to merely
  /// binding or strengthening it).
  bool get damages =>
      this == InteractionKind.clash ||
      this == InteractionKind.punishment ||
      this == InteractionKind.erosion ||
      this == InteractionKind.restraint;
}

/// One 干 or 支 taking part in an interaction, tagged with where it came from.
class InteractionParty {
  final TemporalLayer layer;

  /// 年柱/月柱/日柱/时柱 for natal parties; the layer label otherwise.
  final String position;

  /// The 干 or 支 character itself.
  final String value;

  final bool isStem;

  /// 十神 of this 干 (or of the branch's 本气) relative to the day master.
  /// Null for the day master's own stem.
  final String? shiShen;

  const InteractionParty({
    required this.layer,
    required this.position,
    required this.value,
    required this.isStem,
    this.shiShen,
  });

  String get label => '$position$value${shiShen == null ? '' : '($shiShen)'}';

  Map<String, dynamic> toJson() => {
        'layer': layer.label,
        'position': position,
        'value': value,
        'isStem': isStem,
        if (shiShen != null) 'shiShen': shiShen,
      };
}

/// A 干支 interaction with its participants' provenance preserved.
///
/// This is the structured replacement for the display strings that used to be
/// the *only* temporal information reaching the reasoning layers.
class LuckInteraction {
  final String type; // 地支六冲 / 天干五合 …
  final InteractionKind kind;
  final List<InteractionParty> parties;
  final String? combinedWuXing;

  const LuckInteraction({
    required this.type,
    required this.kind,
    required this.parties,
    this.combinedWuXing,
  });

  Set<TemporalLayer> get layers => {for (final p in parties) p.layer};

  /// True when at least one 岁运 pillar takes part — i.e. this is not a
  /// purely natal relationship.
  bool get involvesLuck => layers.any((l) => l != TemporalLayer.natal);

  /// True when a natal pillar takes part, so the luck actually reaches the
  /// chart rather than only interacting with other luck pillars.
  bool get touchesNatal => layers.contains(TemporalLayer.natal);

  /// The finest layer involved — the layer at which this interaction fires.
  TemporalLayer get firingLayer =>
      layers.reduce((a, b) => a.index >= b.index ? a : b);

  /// Natal positions this interaction reaches (年柱/月柱/日柱/时柱).
  Set<String> get natalPositions => {
        for (final p in parties)
          if (p.layer == TemporalLayer.natal) p.position,
      };

  /// 十神 touched by this interaction, from either side.
  Set<String> get shiShenTouched => {
        for (final p in parties)
          if (p.shiShen != null) p.shiShen!,
      };

  String get description =>
      '$type: ${parties.map((p) => p.label).join('、')}'
      '${combinedWuXing == null ? '' : '（化$combinedWuXing）'}';

  Map<String, dynamic> toJson() => {
        'type': type,
        'kind': kind.label,
        'firingLayer': firingLayer.label,
        'parties': parties.map((p) => p.toJson()).toList(),
        if (combinedWuXing != null) 'combinedWuXing': combinedWuXing,
      };
}

/// One 岁运 pillar in play, annotated the same way a natal pillar is.
class TemporalPillar {
  final TemporalLayer layer;
  final String ganZhi;

  /// 十神 of the pillar's 天干 relative to the day master.
  final String ganShiShen;

  /// 十神 of the branch's 本气藏干.
  final String zhiMainShiShen;

  /// 十神 of every 藏干 in the branch, 本气 first.
  final List<String> zhiHiddenShiShen;

  /// 五行 of the 天干 and of the branch's 本气.
  final String ganWuXing;
  final String zhiWuXing;

  final String label; // 大运 乙亥（9-18岁）

  const TemporalPillar({
    required this.layer,
    required this.ganZhi,
    required this.ganShiShen,
    required this.zhiMainShiShen,
    required this.label,
    this.zhiHiddenShiShen = const [],
    this.ganWuXing = '',
    this.zhiWuXing = '',
  });

  String get gan => ganZhi.isEmpty ? '' : ganZhi[0];
  String get zhi => ganZhi.length < 2 ? '' : ganZhi[1];

  /// Every 十神 this pillar carries, at the requested depth.
  ///
  /// scope: stem = 天干 only, main = 天干 + 本气, any = 天干 + 全部藏干.
  List<String> shiShenAt(String scope) => [
        if (ganShiShen.isNotEmpty) ganShiShen,
        if (scope != 'stem')
          ...(scope == 'main'
              ? [if (zhiMainShiShen.isNotEmpty) zhiMainShiShen]
              : zhiHiddenShiShen),
      ];

  Map<String, dynamic> toJson() => {
        'layer': layer.label,
        'ganZhi': ganZhi,
        'ganShiShen': ganShiShen,
        'zhiMainShiShen': zhiMainShiShen,
        if (zhiHiddenShiShen.isNotEmpty) 'zhiHiddenShiShen': zhiHiddenShiShen,
        'label': label,
      };
}

/// Everything the reasoning layers need to know about *when*.
///
/// Before this existed the deterministic engines only ever saw [chart], which
/// is why their output was byte-identical whether the user asked about their
/// whole life or a single day.
class TemporalContext {
  final ChartResult chart;
  final DecadeData? decade;
  final FlowYearData? year;
  final FlowMonthData? month;
  final FlowDayData? day;

  /// Every interaction in play, natal-internal ones included.
  final List<LuckInteraction> interactions;

  /// The 岁运 pillars in play, coarse → fine. Built by ChartService, which
  /// is where the 十神/五行 annotation can be computed.
  final List<TemporalPillar> luckPillars;

  const TemporalContext({
    required this.chart,
    required this.interactions,
    this.luckPillars = const [],
    this.decade,
    this.year,
    this.month,
    this.day,
  });

  /// Whole-life context: natal only, no 岁运.
  TemporalContext.natal(this.chart, {this.interactions = const []})
      : luckPillars = const [],
        decade = null,
        year = null,
        month = null,
        day = null;

  /// The finest layer the user actually selected.
  TemporalLayer get depth {
    if (day != null) return TemporalLayer.day;
    if (month != null) return TemporalLayer.month;
    if (year != null) return TemporalLayer.year;
    if (decade != null) return TemporalLayer.decade;
    return TemporalLayer.natal;
  }

  bool has(TemporalLayer layer) => switch (layer) {
        TemporalLayer.natal => true,
        TemporalLayer.decade => decade != null,
        TemporalLayer.year => year != null,
        TemporalLayer.month => month != null,
        TemporalLayer.day => day != null,
      };

  /// Active layers, coarse → fine.
  List<TemporalLayer> get activeLayers =>
      [for (final l in TemporalLayer.values) if (has(l)) l];

  TemporalPillar? pillarAt(TemporalLayer layer) {
    for (final p in luckPillars) {
      if (p.layer == layer) return p;
    }
    return null;
  }

  /// Interactions that fire at [layer].
  List<LuckInteraction> interactionsAt(TemporalLayer layer) =>
      [for (final i in interactions) if (i.firingLayer == layer) i];

  /// Interactions where 岁运 actually reaches a natal pillar.
  List<LuckInteraction> get luckOnNatal =>
      [for (final i in interactions) if (i.involvesLuck && i.touchesNatal) i];

  Map<String, dynamic> toJson() => {
        'depth': depth.label,
        'luckPillars': luckPillars.map((p) => p.toJson()).toList(),
        'interactions': interactions.map((i) => i.toJson()).toList(),
      };
}
