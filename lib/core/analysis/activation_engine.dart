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
        ActivationEffect.damage => '刑伤',
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

  const Activation({
    required this.layer,
    required this.target,
    required this.targetKind,
    required this.effect,
    required this.intensity,
    required this.stance,
    required this.mechanism,
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
            mechanism: '${i.type} ${i.description}'
                '——${party.position}之$group被${effect.label}',
          ));
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
      final key = '${a.layer.index}|${a.targetKind}|${a.target}|${a.effect.index}';
      final prior = best[key];
      if (prior == null || a.intensity > prior.intensity) best[key] = a;
    }
    final deduped = best.values.toList()
      ..sort((a, b) => b.intensity.compareTo(a.intensity));
    return deduped;
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
