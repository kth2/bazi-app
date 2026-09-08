import '../engine/chart_service.dart';
import '../models/chart_result.dart';
import '../rules/rule.dart';
import '../rules/rule_engine.dart';
import 'activation_engine.dart';
import 'event_inference.dart';
import 'natal_structure.dart';
import 'pattern_detector.dart';
import 'temporal_context.dart';
import 'yingqi_engine.dart';

/// The complete deterministic reasoning chain for one scope.
///
///     原局 → 格局 → 成败 → 用神/相神/忌神 → 调候
///          → 证据(分层规则) → 岁运引动 → 事件候选 → 应期
///
/// Everything above is computed. The model's job begins after this object is
/// built: it explains the chain, it does not derive it.
class ReasoningReport {
  final ChartResult chart;
  final ChartPattern pattern;
  final NatalStructure structure;
  final TemporalContext context;
  final List<RuleMatch> evidence;
  final List<Activation> activations;
  final List<EventCandidate> events;
  final YingQiForecast yingQi;

  const ReasoningReport({
    required this.chart,
    required this.pattern,
    required this.structure,
    required this.context,
    required this.evidence,
    required this.activations,
    required this.events,
    required this.yingQi,
  });

  static ReasoningReport build(
    ChartResult chart,
    List<Rule> rules, {
    DecadeData? decade,
    FlowYearData? year,
    FlowMonthData? month,
    FlowDayData? day,
  }) {
    final context = ChartService.temporalContext(chart,
        decade: decade, year: year, month: month, day: day);
    final pattern = PatternDetector.detect(chart);
    final structure = NatalStructureResolver.resolve(chart, pattern);
    final evidence = RuleEngine.evaluate(chart, rules, context: context);
    final activations = LuckActivationEngine.evaluate(structure, context);
    final yingQi = YingQiEngine.resolve(chart, structure, context);
    final events = EventInferenceEngine.infer(
      chart: chart,
      structure: structure,
      context: context,
      activations: activations,
      establishedThemes: yingQi.establishedThemes,
    );

    return ReasoningReport(
      chart: chart,
      pattern: pattern,
      structure: structure,
      context: context,
      evidence: evidence,
      activations: activations,
      events: events,
      yingQi: yingQi,
    );
  }

  /// Evidence grouped by reasoning tier, coarse → fine.
  Map<int, List<RuleMatch>> get evidenceByTier {
    final out = <int, List<RuleMatch>>{};
    for (final m in evidence) {
      out.putIfAbsent(m.rule.tier, () => []).add(m);
    }
    return out;
  }

  static const Map<int, String> kTierNames = {
    1: '基础事实',
    2: '命局结构',
    3: '格局成败',
    4: '岁运引动',
  };

  /// Only activations that fire at the scope's own depth — what makes *this*
  /// moment different from the chart in general.
  List<Activation> get activationsAtDepth =>
      [for (final a in activations) if (a.layer == context.depth) a];

  Map<String, dynamic> toJson() => {
        'structure': structure.toJson(),
        'temporal': context.toJson(),
        'activations': activations.take(12).map((a) => a.toJson()).toList(),
        'events': events.take(10).map((e) => e.toJson()).toList(),
        'yingQi': yingQi.toJson(),
      };
}
