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
      '迁移变动',
    ],
    wealth: ['收入增益', '投资置产', '意外之财', '破财损耗', '因财劳碌', '资产变动'],
    marriage: [
      '婚恋成合', '感情生变', '配偶宫动', '情感牵绊', '第三者之扰', '子女之事',
    ],
    study: ['文书学业', '考试资格', '技艺才华', '进修拓展', '学途受阻'],
    health: ['劳神耗气', '旧患复发', '外伤意外', '情志郁结', '身心失调'],
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

  const _EventRule({
    required this.target,
    required this.effect,
    required this.domain,
    required this.subtype,
    required this.polarity,
    this.stance,
    this.gender,
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
    _EventRule(
      target: '财星', effect: ActivationEffect.weaken,
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
    _EventRule(
      target: '印星', effect: ActivationEffect.weaken,
      domain: EventDomain.health, subtype: '情志郁结',
      polarity: EventPolarity.adverse,
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
  static const double _minConfidence = 0.12;

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

      for (final r in _rules) {
        if (r.target != a.target) continue;
        if (r.effect != a.effect) continue;
        if (r.stance != null && r.stance != a.stance) continue;
        if (r.gender != null && r.gender != gender) continue;

        // Structural support: an event resting on a 十神 that is not even
        // operative in the natal chart is weaker than one that is.
        final support = a.targetKind == '十神'
            ? (structure.presence[a.target]?.isOperative ?? false ? 1.0 : 0.6)
            : 0.85;
        final confidence = (a.intensity * support).clamp(0.0, 1.0);
        if (confidence < _minConfidence) continue;

        final key = '${r.domain}|${r.subtype}';
        final basis = <String>[
          '原局：${structure.pattern.geJu}·${structure.status.label}'
              '（用神${structure.xiangShen.isEmpty ? structure.pattern.geJu : structure.xiangShen.join('、')}）',
          if (a.targetKind == '十神')
            '${a.target}在原局${structure.presence[a.target]?.level ?? '未详'}',
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

    final list = out.values.toList()
      ..sort((a, b) {
        final byConfidence = b.confidence.compareTo(a.confidence);
        if (byConfidence != 0) return byConfidence;
        // Stable ordering for equal confidence.
        return ('${a.domain}${a.subtype}').compareTo('${b.domain}${b.subtype}');
      });
    return list;
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
