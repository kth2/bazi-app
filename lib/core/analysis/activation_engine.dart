import 'natal_structure.dart';
import 'temporal_context.dart';

/// What a 岁运 pillar does to something in the natal chart.
enum ActivationEffect {
  /// 生扶/临位/成局 — feeds power in.
  strengthen,

  /// 冲开 — shakes a dormant party loose. Disruptive whether or not the
  /// target was wanted.
  release,

  /// 合绊 — binds; the target's function cannot express.
  bind,

  /// 刑害破 — damages.
  damage,

  /// 克 — suppresses.
  weaken,
}

extension ActivationEffectX on ActivationEffect {
  String get label => switch (this) {
        ActivationEffect.strengthen => '增强',
        ActivationEffect.release => '冲开引动',
        ActivationEffect.bind => '合绊',
        ActivationEffect.damage => '刑害损伤',
        ActivationEffect.weaken => '克制',
      };

  /// Whether the effect adds force to the target (+1) or disrupts it (-1).
  ///
  /// Combined with the chart's 喜忌 stance this decides favourability:
  /// feeding a 相神 is good, feeding a 忌神 is bad, and 冲去忌神 is good
  /// while 冲破用神 is bad.
  int get polarity => this == ActivationEffect.strengthen ? 1 : -1;
}

/// The palace each natal pillar governs, used when an interaction lands on a
/// position rather than on a 十神.
const Map<String, String> kPalaceMeaning = {
  '年柱': '祖上根基·少年',
  '月柱': '父母·事业提纲',
  '日柱': '夫妻宫·自身',
  '时柱': '子女·晚年',
};

/// One thing the 岁运 does to the chart.
class Activation {
  final TemporalLayer layer;

  /// 十神 group (比劫/食伤/财星/官杀/印星) or, for palace hits, the pillar.
  final String target;

  /// '十神' or '宫位' or '调候'.
  final String targetKind;

  final ActivationEffect effect;

  /// 0..1 — how forcefully this fires.
  final double intensity;

  /// The chart's 喜忌 for this activation: 1 喜 / -1 忌 / 0 中性.
  ///
  /// Three-way rather than a bool: a 十神 the 格局 has no stake in is stirred
  /// without that being either good or bad, and collapsing that into
  /// "not favourable" made every window read 偏凶.
  final int stance;

  /// Plain-language 干支 reason.
  final String mechanism;

  /// Which 干支 relationship produced this, when one did.
  ///
  /// [effect] deliberately collapses 刑 and 相绝 into `damage` — for most
  /// judgements how a thing was harmed matters less than that it was. But a
  /// few readings are specifically about 刑: 官杀逢刑 is 官非, not simply
  /// pressure. Rules that need that distinction ask for it here; everything
  /// else keeps working off [effect].
  final InteractionKind? via;

  const Activation({
    required this.layer,
    required this.target,
    required this.targetKind,
    required this.effect,
    required this.intensity,
    required this.stance,
    required this.mechanism,
    this.via,
  });

  bool get favourable => stance > 0;
  bool get unfavourable => stance < 0;
  bool get neutral => stance == 0;

  Map<String, dynamic> toJson() => {
        'layer': layer.label,
        'target': target,
        'targetKind': targetKind,
        'effect': effect.label,
        'intensity': double.parse(intensity.toStringAsFixed(2)),
        'stance': stance,
        if (via != null) 'via': via!.name,
        'mechanism': mechanism,
      };

  String get stanceLabel =>
      stance > 0 ? '喜' : (stance < 0 ? '忌' : '中性');

  String get description => '${layer.label}${effect.label}$target'
      '（$stanceLabel，力度${(intensity * 100).round()}%）：$mechanism';
}

/// Turns "what the chart is" plus "when we are" into "what is being acted on".
///
/// This is the step that was previously missing: the natal engine described
/// structures, the temporal data described 干支 relationships, and nothing
/// joined them — the model was left to work out which structures the year
/// actually touched.
class LuckActivationEngine {
  /// Relative force of each relationship type.
  /// Relative force of each relationship type.
  ///
  /// 应期 comes from 冲合刑害 and from a 十神 arriving transparently.
  /// 天干相克 is ambient — it holds between many pairs at once and bazi_core
  /// reports it as one node set spanning most of the chart, so giving it
  /// event weight buries the genuine 冲 under a pile of background noise.
  static const Map<InteractionKind, double> _kindWeight = {
    InteractionKind.clash: 1.0,
    InteractionKind.formation: 0.9,
    InteractionKind.punishment: 0.7,
    InteractionKind.combination: 0.65,
    InteractionKind.erosion: 0.4,
    InteractionKind.restraint: 0.15,
    InteractionKind.other: 0.1,
  };

  /// Kinds too diffuse to say a *palace* was stirred.
  static const Set<InteractionKind> _ambient = {
    InteractionKind.restraint,
    InteractionKind.other,
  };

  static const Map<String, List<String>> _groupOf = {
    '比肩': ['比劫'], '劫财': ['比劫'],
    '食神': ['食伤'], '伤官': ['食伤'],
    '正财': ['财星'], '偏财': ['财星'],
    '正官': ['官杀'], '七杀': ['官杀'],
    '正印': ['印星'], '偏印': ['印星'],
  };

  static String? groupOf(String? shiShen) =>
      shiShen == null ? null : _groupOf[shiShen]?.first;

  static List<Activation> evaluate(
    NatalStructure structure,
    TemporalContext context,
  ) {
    final out = <Activation>[];

    // --- A. 临位: the 岁运 pillar's own 十神 arrives ---
    for (final p in context.luckPillars) {
      void addFromShiShen(String? shiShen, bool isStem) {
        final group = groupOf(shiShen);
        if (group == null) return;
        // Judged on the specific 十神 (七杀 vs 正官), reported on the group.
        final stance = structure.stanceOf(shiShen!);
        final intensity = p.layer.authority * (isStem ? 1.0 : 0.8);
        out.add(Activation(
          layer: p.layer,
          target: group,
          targetKind: '十神',
          effect: ActivationEffect.strengthen,
          intensity: intensity,
          stance: stance,
          mechanism: '${p.layer.label}${isStem ? '天干' : '地支本气'}'
              '${isStem ? p.gan : p.zhi}为$shiShen，$group之气临位',
        ));
      }

      addFromShiShen(p.ganShiShen, true);
      addFromShiShen(p.zhiMainShiShen, false);

      // --- D. 神煞: the 岁运 pillar arriving as a 驿马 or 天乙贵人 ---
      //
      // 「岁运带驿马」 is the classical reading — this year's branch is the
      // 驿马 of the natal 年支/日支 — not 「原局带驿马」, which is either true
      // for a whole life or never and so names no year. ChartService resolves
      // it, because the 神煞 tables live in bazi_core.
      //
      // Only these two: every other 神煞 bazi_core computes colours the chart
      // rather than saying something happened.
      for (final marker in p.shenSha) {
        if (!kEventShenSha.contains(marker)) continue;
        out.add(Activation(
          layer: p.layer,
          target: marker,
          targetKind: '神煞',
          effect: ActivationEffect.strengthen,
          // Below a 十神 临位: a 神煞 qualifies an event, it does not by
          // itself establish one.
          intensity: p.layer.authority * 0.7,
          // 驿马 and 贵人 carry no 喜忌 of their own; whether movement or help
          // reads well depends on the 格局, not on the marker.
          stance: 0,
          mechanism: '${p.layer.label}${p.ganZhi}为原局之$marker',
        ));
      }

      // --- C. 调候: does this pillar bring what the climate needs? ---
      for (final entry in {p.ganWuXing: '天干', p.zhiWuXing: '地支'}.entries) {
        if (entry.key.isEmpty) continue;
        if (structure.needsForTiaoHou(entry.key)) {
          out.add(Activation(
            layer: p.layer,
            target: '调候',
            targetKind: '调候',
            effect: ActivationEffect.strengthen,
            intensity: p.layer.authority * 0.9,
            stance: 1,
            mechanism: '${p.layer.label}${entry.value}带${entry.key}，'
                '补原局调候之缺（${structure.tiaoHou.climate}）',
          ));
        }
      }
    }

    // --- B. 岁运与原局的作用 ---
    for (final i in context.interactions) {
      if (!i.involvesLuck || !i.touchesNatal) continue;
      final effect = _effectOf(i.kind);
      final weight = _kindWeight[i.kind] ?? 0.3;
      final intensity = (i.firingLayer.authority * weight).clamp(0.0, 1.0);

      // Which natal parties are hit, and what do they carry?
      for (final party in i.parties) {
        if (party.layer != TemporalLayer.natal) continue;

        final group = groupOf(party.shiShen);
        if (group != null) {
          final stance = structure.stanceOf(party.shiShen!);
          out.add(Activation(
            layer: i.firingLayer,
            target: group,
            targetKind: '十神',
            effect: effect,
            intensity: intensity,
            stance: effect.polarity * stance,
            via: i.kind,
            mechanism: '${i.description}'
                '——${party.position}之$group被${effect.label}',
          ));
        }

        // 原局的驿马柱被冲刑 —— 「冲动驿马」，与「岁运带驿马」是两条不同的
        // 动象，都算。前者是原局的马被摇动，后者是马运走到。
        //
        // 单独看，原局带不带驿马是一辈子的常量、说不出是哪一年（上一期实测
        // 过），所以这里只在**被冲刑合的那一年**才发一条。
        if (!_ambient.contains(i.kind)) {
          for (final marker in _natalShenShaAt(context, party.position)) {
            if (!kEventShenSha.contains(marker)) continue;
            out.add(Activation(
              layer: i.firingLayer,
              target: marker,
              targetKind: '神煞',
              effect: effect,
              intensity: intensity * 0.8,
              stance: 0,
              via: i.kind,
              mechanism: '${i.type}：${party.position}带$marker，被${effect.label}',
            ));
          }
        }

        // The palace itself is hit — 日支 being struck is a marriage event
        // regardless of which 十神 happens to sit there. Ambient kinds are
        // too diffuse to claim a palace was stirred.
        if (kPalaceMeaning.containsKey(party.position) &&
            !_ambient.contains(i.kind)) {
          out.add(Activation(
            layer: i.firingLayer,
            target: party.position,
            targetKind: '宫位',
            effect: effect,
            intensity: intensity * 0.9,
            // A palace has no 喜忌 of its own: 冲合 both stir it, and whether
            // that reads well depends on the event, not on the structure.
            stance: 0,
            via: i.kind,
            mechanism: '${i.type}：${party.position}'
                '（${kPalaceMeaning[party.position]}）被${effect.label}',
          ));
        }
      }
    }

    // One interaction can name several natal parties, and several routes can
    // reach the same target. Keep the strongest statement of each distinct
    // (layer, target, effect) so repetition cannot inflate a window's score.
    final best = <String, Activation>{};
    for (final a in out) {
      // 刑 is kept apart from the other `damage` sources, because 官非 turns
      // on it specifically and merging would silently drop it. Everything
      // else still collapses — the narrowest split that buys what the rule
      // needs. Measured on the 240-chart grid: this and a full
      // InteractionKind key land in the same place (吉:凶 1.14 vs 1.13,
      // against 1.27 before this change), so the narrower one wins on
      // changing less.
      final punished = a.via == InteractionKind.punishment;
      final key = '${a.layer.index}|${a.targetKind}|${a.target}'
          '|${a.effect.index}|$punished';
      final prior = best[key];
      if (prior == null || a.intensity > prior.intensity) best[key] = a;
    }
    final deduped = best.values.toList()
      ..sort((a, b) => b.intensity.compareTo(a.intensity));

    return _capInteractionsPerLayer(deduped);
  }

  /// How many interaction-driven activations a single layer may contribute.
  ///
  /// 先看流年干支是喜是忌，再看有无冲合刑害: what the 岁运 *brings* (临位) is the
  /// primary judgement and the relationships modify it. But a 临位 and a single
  /// 冲 carry the same intensity here, and bazi_core enumerates every pairing
  /// it can find — 六破, 暗合, 相绝, multi-node groupings — so left uncapped the
  /// relationships collectively outvote 临位 several times over. Because a
  /// chart has more 喜 parties than 忌 ones (相神 average ~1.2 per chart against
  /// ~0.4 忌神), that surplus lands disproportionately on things the 格局
  /// wanted, and every year reads 偏凶. A practitioner weighs the dominant
  /// relationships, not all of them.
  ///
  /// The principle — relationships modify, they do not outvote — is classical.
  /// The specific number is not: it was calibrated on a 240-chart grid to the
  /// point where the engine stops leaning systematically either way (吉:凶 of
  /// 1.03 at 5, against 0.78 uncapped and 1.22 at 3). Over many charts and one
  /// year, neither outcome should dominate; a 2:1 skew in either direction is
  /// a modelling artefact rather than insight. Re-measure with
  /// test/engine_calibration_test.dart if the weights or rules change.
  static const int _maxInteractionsPerLayer = 5;

  /// 神煞 that name an event when they arrive. Everything else bazi_core
  /// computes describes a flavour of the chart, not something that happens.
  static const Set<String> kEventShenSha = {'驿马', '天乙贵人'};

  static List<String> _natalShenShaAt(TemporalContext context, String position) {
    for (final p in context.chart.pillars) {
      if (p.position == position) return p.shenSha;
    }
    return const [];
  }


  static List<Activation> _capInteractionsPerLayer(List<Activation> sorted) {
    final kept = <Activation>[];
    final countByLayer = <TemporalLayer, int>{};
    for (final a in sorted) {
      // 临位 and 调候 describe what the pillar itself is, and are never capped.
      if (a.effect == ActivationEffect.strengthen || a.targetKind == '调候') {
        kept.add(a);
        continue;
      }
      final n = countByLayer[a.layer] ?? 0;
      if (n >= _maxInteractionsPerLayer) continue;
      countByLayer[a.layer] = n + 1;
      kept.add(a);
    }
    return kept;
  }

  static ActivationEffect _effectOf(InteractionKind kind) => switch (kind) {
        InteractionKind.clash => ActivationEffect.release,
        InteractionKind.formation => ActivationEffect.strengthen,
        InteractionKind.combination => ActivationEffect.bind,
        InteractionKind.punishment ||
        InteractionKind.erosion =>
          ActivationEffect.damage,
        InteractionKind.restraint => ActivationEffect.weaken,
        InteractionKind.other => ActivationEffect.strengthen,
      };

  /// Below this an activation is a ripple, not a theme. Without the floor
  /// almost every 十神 gets nominally touched at some layer, and the
  /// 流日不创事 gate it feeds never actually holds anything back.
  static const double kThemeFloor = 0.35;

  /// The 十神 groups meaningfully in play at [finestAllowed] or coarser.
  /// Used to enforce 流日不创事.
  static Set<String> themesAt(
    List<Activation> activations,
    TemporalLayer finestAllowed,
  ) =>
      {
        for (final a in activations)
          if (a.targetKind == '十神' &&
              a.layer.index <= finestAllowed.index &&
              a.intensity >= kThemeFloor)
            a.target,
      };
}
