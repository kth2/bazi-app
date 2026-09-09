import '../analysis/activation_engine.dart';
import '../analysis/event_inference.dart';
import '../analysis/natal_structure.dart';
import '../analysis/pattern_detector.dart';
import '../engine/chart_service.dart';
import '../models/chart_result.dart';
import 'event_catalog.dart';
import 'life_span.dart';
import 'timeline_event.dart';

/// One year's worth of raw engine output, before any selection.
class _YearHit {
  final int age;
  final EventCandidate candidate;
  const _YearHit(this.age, this.candidate);
}

/// A kind's best showing inside one step, with the score it is ranked by.
class _Pick {
  final (int, int) step;
  final String kindId;
  final double score;
  final List<_YearHit> hits;
  const _Pick({
    required this.step,
    required this.kindId,
    required this.score,
    required this.hits,
  });
}

/// Turns a chart into suggested timeline markers.
///
/// ## Why this is mostly a *selection* problem
///
/// Running the inference engine on all 120 years is cheap (~30 ms) but
/// produces roughly **seven candidates per year** — 700-950 over a life. That
/// is not a timeline, it is a wall. Worse, the raw output is nearly flat:
/// confidence sits between 0.45 and 0.80 for most years, so an absolute
/// threshold either keeps almost everything or almost nothing.
///
/// The flatness is not a bug. Whether 财星 is 用神 does not change from year
/// to year, so a 财 event is *available* in most years; what changes is
/// whether the year actually stirs it. So the scanner asks a relative
/// question instead of an absolute one:
///
///   **within each 大运, which few things stand out?**
///
/// That is also how the 大运 is read in practice — a step is the unit of life
/// narrative, and the question put to it is 「这步运里最该留意哪几件事」.
/// It bounds the output structurally: at most [kMaxPerDecade] per step, so a
/// life yields tens of markers rather than hundreds, without a magic global
/// cutoff.
///
/// ## What this does *not* do
///
/// Nothing here changes the theory. Every candidate, its polarity and its
/// 理由链 come from [EventInferenceEngine] unchanged; this class only decides
/// which of them are worth a pixel. No recorded outcome is read — see
/// `test/case_guardrail_test.dart`.
class TimelineScanner {
  const TimelineScanner._();

  /// Markers kept per 大运 step (and per 小运期).
  ///
  /// A calibration, not a classical figure: three is what fits legibly above
  /// a ten-year band on a phone, and it keeps a full life near 40 markers.
  static const int kMaxPerDecade = 3;

  /// Slots per step reserved for guarded kinds the user has switched on,
  /// over and above [kMaxPerDecade].
  static const int kMaxGuardedPerDecade = 1;

  /// How many steps one kind may claim across a whole life.
  ///
  /// Without this the ranking is stable enough that a single kind wins a slot
  /// in all twelve steps — measured, not hypothetical: the first cut produced
  /// 「职场是非×12」 out of 36 markers. A timeline that says the same thing in
  /// every decade has told the reader nothing.
  static const int kMaxPerKind = 4;

  /// A year must reach this much of its step's best showing to be part of
  /// the same event span.
  static const double kSpanTolerance = 0.85;

  /// Below this the engine's own confidence is too weak to draw at all,
  /// whatever it looks like relative to its neighbours.
  static const double kMinConfidence = 0.40;

  /// Weight of *distinctiveness* against raw strength when ranking a kind
  /// inside a step.
  ///
  /// Strength alone picks the same handful of kinds everywhere, because
  /// whether 财 is 用神 does not change year to year. So a kind is also
  /// judged on how much more often it fires inside this step than it does
  /// across the whole life — `密度差 = 本步命中率 − 全生命中率`. A kind that
  /// fires as often here as it does anywhere is not telling you about *this*
  /// step, however strong it looks.
  ///
  /// A display heuristic, stated plainly: it changes which candidates are
  /// drawn, never what the engine concluded about any of them.
  static const double kDistinctivenessFloor = 0.45;

  /// Scan a whole life.
  ///
  /// [enabledKindIds] gates guarded kinds; pass
  /// [EventCatalog.defaultEnabledIds] for the default view.
  static List<LifeEvent> scan(
    LifeSpan span, {
    required Set<String> enabledKindIds,
    DateTime? now,
  }) {
    final chart = span.chart;
    final pattern = PatternDetector.detect(chart);
    final structure = NatalStructureResolver.resolve(chart, pattern);
    final createdAt = now ?? DateTime.now();

    // ---- 1. raw per-year candidates -------------------------------------
    final hitsByKind = <String, List<_YearHit>>{};
    for (final y in span.years) {
      final decade = span.decadeAt(y.age.toDouble());
      final context = ChartService.temporalContext(
        chart,
        decade: decade,
        year: y,
      );
      final activations = LuckActivationEngine.evaluate(structure, context);
      final candidates = EventInferenceEngine.infer(
        chart: chart,
        structure: structure,
        context: context,
        activations: activations,
      );
      for (final c in candidates) {
        if (c.confidence < kMinConfidence) continue;
        final kind = EventCatalog.forCandidate(c);
        if (kind == null) continue;
        if (!enabledKindIds.contains(kind.id)) continue;
        // 升职晋升 at 七岁 and 子女之事 at 六岁 both score well; neither is
        // worth drawing. See EventKind.minAge.
        if (!kind.suits(y.age)) continue;
        hitsByKind.putIfAbsent(kind.id, () => []).add(_YearHit(y.age, c));
      }
    }
    if (hitsByKind.isEmpty) return const [];

    // ---- 2. each kind's life-wide hit rate, as the baseline to beat ------
    final totalYears = span.years.length;
    final lifeDensity = <String, double>{
      for (final e in hitsByKind.entries) e.key: e.value.length / totalYears,
    };

    // ---- 3. score every (step, kind), then fill slots globally -----------
    final scored = <_Pick>[];
    for (final step in _steps(span)) {
      scored.addAll(_scoreWithin(step, hitsByKind, lifeDensity));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      // Stable, and deterministic across runs.
      final byStep = a.step.$1.compareTo(b.step.$1);
      if (byStep != 0) return byStep;
      return a.kindId.compareTo(b.kindId);
    });

    // Greedy fill: best pick first, subject to both caps. Doing this across
    // all steps at once rather than step by step is what lets a weaker step
    // keep a kind that a stronger step has already used up its quota on.
    //
    // Guarded kinds are filled in a second pass with their own allowance.
    // Sharing the first pass's slots would mean that switching a sensitive
    // category on silently pushes an ordinary marker off the axis — the user
    // asked to see more, and would have seen the same count.
    final perStep = <(int, int), int>{};
    final perKind = <String, int>{};
    final out = <LifeEvent>[];

    void fill(bool guarded, int stepQuota) {
      final quota = <(int, int), int>{};
      for (final pick in scored) {
        final kind = EventCatalog.byId[pick.kindId];
        if (kind == null || kind.isGuarded != guarded) continue;
        if ((quota[pick.step] ?? 0) >= stepQuota) continue;
        if ((perKind[pick.kindId] ?? 0) >= kMaxPerKind) continue;
        final event = _eventFrom(pick.kindId, pick.hits, createdAt);
        if (event == null) continue;
        quota[pick.step] = (quota[pick.step] ?? 0) + 1;
        perStep[pick.step] = (perStep[pick.step] ?? 0) + 1;
        perKind[pick.kindId] = (perKind[pick.kindId] ?? 0) + 1;
        out.add(event);
      }
    }

    fill(false, kMaxPerDecade);
    fill(true, kMaxGuardedPerDecade);
    out.sort((a, b) {
      final byAge = a.anchor.startAge.compareTo(b.anchor.startAge);
      if (byAge != 0) return byAge;
      return a.kindId.compareTo(b.kindId);
    });
    return out;
  }

  /// The 大运 steps, with the 小运期 prepended as a step of its own so the
  /// early years are not silently unrepresented.
  static List<(int, int)> _steps(LifeSpan span) {
    final steps = <(int, int)>[];
    if (span.firstDecadeAge > 1) {
      steps.add((1, span.firstDecadeAge - 1));
    }
    for (final d in span.decades) {
      final (from, to) = span.boundsOf(d);
      final lo = from.ceil().clamp(1, span.maxAge);
      final hi = (to.ceil() - 1).clamp(1, span.maxAge);
      if (hi >= lo) steps.add((lo, hi));
    }
    return steps;
  }

  static List<_Pick> _scoreWithin(
    (int, int) step,
    Map<String, List<_YearHit>> hitsByKind,
    Map<String, double> lifeDensity,
  ) {
    final (lo, hi) = step;
    final stepYears = hi - lo + 1;
    if (stepYears <= 0) return const [];

    final out = <_Pick>[];
    for (final entry in hitsByKind.entries) {
      final inStep = [
        for (final h in entry.value)
          if (h.age >= lo && h.age <= hi) h,
      ];
      if (inStep.isEmpty) continue;

      final peak = inStep
          .map((h) => h.candidate.confidence)
          .reduce((a, b) => a > b ? a : b);

      // −1..1: how much more of this step this kind occupies than it occupies
      // of the life as a whole.
      final lift = inStep.length / stepYears - (lifeDensity[entry.key] ?? 0);
      final distinctiveness =
          kDistinctivenessFloor +
          (1 - kDistinctivenessFloor) * ((lift + 1) / 2);

      out.add(
        _Pick(
          step: step,
          kindId: entry.key,
          score: peak * distinctiveness,
          hits: inStep,
        ),
      );
    }
    return out;
  }

  /// Collapse a kind's hits inside one step into a single marker: the run of
  /// years around the peak that are nearly as strong.
  static LifeEvent? _eventFrom(
    String kindId,
    List<_YearHit> hits,
    DateTime createdAt,
  ) {
    final kind = EventCatalog.byId[kindId];
    if (kind == null) return null;

    final sorted = [...hits]..sort((a, b) => a.age.compareTo(b.age));
    var peakIndex = 0;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].candidate.confidence >
          sorted[peakIndex].candidate.confidence) {
        peakIndex = i;
      }
    }
    final peak = sorted[peakIndex];
    final floor = peak.candidate.confidence * kSpanTolerance;

    var startAge = peak.age;
    var endAge = peak.age;
    if (kind.defaultSpan) {
      // Grow outward only through years that are both contiguous and nearly
      // as strong; a gap ends the span rather than being papered over.
      for (var i = peakIndex - 1; i >= 0; i--) {
        if (sorted[i].age != startAge - 1) break;
        if (sorted[i].candidate.confidence < floor) break;
        startAge = sorted[i].age;
      }
      for (var i = peakIndex + 1; i < sorted.length; i++) {
        if (sorted[i].age != endAge + 1) break;
        if (sorted[i].candidate.confidence < floor) break;
        endAge = sorted[i].age;
      }
    }

    final anchor = TimelineAnchor(startAge.toDouble(), endAge.toDouble());
    return LifeEvent(
      id: suggestedIdFor(kindId, anchor),
      kindId: kindId,
      anchor: anchor,
      intensity: EventIntensityX.fromConfidence(peak.candidate.confidence),
      origin: EventOrigin.suggested,
      confidence: peak.candidate.confidence,
      polarity: peak.candidate.polarity,
      basis: peak.candidate.basis,
      createdAt: createdAt,
    );
  }

  /// Deterministic id for a suggested event, so a rescan of an unchanged
  /// chart yields the same ids and P4 can tell a moved event from a new one.
  static String suggestedIdFor(String kindId, TimelineAnchor anchor) =>
      'auto:$kindId@${anchor.startAge.toStringAsFixed(0)}'
      '-${anchor.endAge.toStringAsFixed(0)}';
}

/// Convenience wrapper so callers do not repeat the pattern/structure setup.
extension TimelineScanOf on ChartResult {
  List<LifeEvent> scanTimeline({Set<String>? enabledKindIds}) =>
      TimelineScanner.scan(
        LifeSpan.of(this),
        enabledKindIds: enabledKindIds ?? EventCatalog.defaultEnabledIds,
      );
}
