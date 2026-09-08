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

/// The engine's own net 吉凶 for a scope.
///
/// Exists so the narrative layer can be held to what the deterministic layer
/// actually found. Without it the model was free to answer 破财 on a chart
/// whose candidates were entirely 吉 — which is what it did.
class EngineAssessment {
  final int favourableEvents;
  final int adverseEvents;
  final int mixedEvents;
  final int favourableWindows;
  final int adverseWindows;

  const EngineAssessment({
    required this.favourableEvents,
    required this.adverseEvents,
    required this.mixedEvents,
    required this.favourableWindows,
    required this.adverseWindows,
  });

  int get net =>
      (favourableEvents - adverseEvents) + (favourableWindows - adverseWindows);

  /// 整体偏吉 / 整体偏凶 / 吉凶相当.
  String get lean =>
      net > 0 ? '整体偏吉' : (net < 0 ? '整体偏凶' : '吉凶相当');

  bool get hasSignal =>
      favourableEvents + adverseEvents + mixedEvents +
          favourableWindows + adverseWindows >
      0;

  String get summary => '事件候选：吉 $favourableEvents / 凶 $adverseEvents / '
      '吉凶参半 $mixedEvents；应期窗口：偏吉 $favourableWindows / '
      '偏凶 $adverseWindows；综合倾向：$lean';

  Map<String, dynamic> toJson() => {
        'favourableEvents': favourableEvents,
        'adverseEvents': adverseEvents,
        'mixedEvents': mixedEvents,
        'favourableWindows': favourableWindows,
        'adverseWindows': adverseWindows,
        'lean': lean,
      };
}

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

  /// What the deterministic layer concluded, on balance.
  EngineAssessment get assessment {
    var fav = 0, adv = 0, mix = 0;
    for (final e in events) {
      switch (e.polarity) {
        case EventPolarity.favourable:
          fav++;
        case EventPolarity.adverse:
          adv++;
        case EventPolarity.mixed:
          mix++;
      }
    }
    var favW = 0, advW = 0;
    for (final w in yingQi.top) {
      if (w.verdict == '偏吉') favW++;
      if (w.verdict == '偏凶') advW++;
    }
    return EngineAssessment(
      favourableEvents: fav,
      adverseEvents: adv,
      mixedEvents: mix,
      favourableWindows: favW,
      adverseWindows: advW,
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
        'assessment': assessment.toJson(),
        'structure': structure.toJson(),
        'temporal': context.toJson(),
        'activations': activations.take(12).map((a) => a.toJson()).toList(),
        'events': events.take(10).map((e) => e.toJson()).toList(),
        'yingQi': yingQi.toJson(),
      };
}
