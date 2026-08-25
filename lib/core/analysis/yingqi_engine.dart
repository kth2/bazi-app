import '../engine/chart_service.dart';
import '../models/chart_result.dart';
import 'activation_engine.dart';
import 'natal_structure.dart';
import 'temporal_context.dart';

/// One candidate 应期 window with the reason it scored.
class YingQiWindow {
  final TemporalLayer layer;
  final String label; // 流月 庚寅（立春） / 2026-08-14 甲子
  final String ganZhi;
  final DateTime start;
  final DateTime end;

  /// 0..1, normalised against the strongest window in the same forecast.
  final double score;

  /// Un-normalised sum of activation intensities.
  final double rawScore;

  /// Net favourability: positive when 喜 outweighs 忌.
  final double net;

  /// 十神 themes this window puts in play.
  final Set<String> themes;

  /// Why it scored, strongest first.
  final List<String> triggers;

  /// Themes this window would have raised but may not, because nothing at
  /// 流年/流月 established them (流日不创事).
  final List<String> suppressed;

  const YingQiWindow({
    required this.layer,
    required this.label,
    required this.ganZhi,
    required this.start,
    required this.end,
    required this.score,
    required this.rawScore,
    required this.net,
    required this.themes,
    required this.triggers,
    required this.suppressed,
  });

  bool get favourable => net > 0;

  String get verdict => net.abs() < 0.15
      ? '吉凶参半'
      : net > 0
          ? '偏吉'
          : '偏凶';

  Map<String, dynamic> toJson() => {
        'layer': layer.label,
        'label': label,
        'ganZhi': ganZhi,
        'start': _fmt(start),
        'end': _fmt(end),
        'score': double.parse(score.toStringAsFixed(2)),
        'verdict': verdict,
        'themes': themes.toList(),
        'triggers': triggers,
        if (suppressed.isNotEmpty) 'suppressed': suppressed,
      };

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Ranked 应期 windows one layer finer than the analysis scope.
class YingQiForecast {
  final TemporalLayer granularity;

  /// What is being timed, in words.
  final String basis;

  /// All candidate windows, strongest first.
  final List<YingQiWindow> windows;

  /// Themes established at 流年/流月 that a 流日 is permitted to fire.
  final Set<String> establishedThemes;

  const YingQiForecast({
    required this.granularity,
    required this.basis,
    required this.windows,
    required this.establishedThemes,
  });

  List<YingQiWindow> get top =>
      windows.take(windows.length < 3 ? windows.length : 3).toList();

  bool get isEmpty => windows.isEmpty;

  Map<String, dynamic> toJson() => {
        'granularity': granularity.label,
        'basis': basis,
        'establishedThemes': establishedThemes.toList(),
        'windows': top.map((w) => w.toJson()).toList(),
      };
}

/// Computes 应期 deterministically.
///
/// Previously the prompt asked the model to name "最可能的应期日" from the
/// raw chart, which meant the date was invented rather than derived: the same
/// question could be answered differently twice, with no way to check the
/// reasoning or regression-test it. Here every candidate window is scored by
/// running the activation engine against that window's own 干支 and summing
/// what it actually stirs.
class YingQiEngine {
  /// A window whose theme is already live at a coarser layer counts for more:
  /// 流月引动流年之势 is a real 应期, an unrelated 流月 stirring something
  /// nothing else supports is noise.
  static const double _resonanceBonus = 1.5;

  static YingQiForecast resolve(
    ChartResult chart,
    NatalStructure structure,
    TemporalContext context,
  ) {
    switch (context.depth) {
      case TemporalLayer.natal:
        return _rankDecades(chart, structure);
      case TemporalLayer.decade:
        return _rankYears(chart, structure, context.decade!);
      case TemporalLayer.year:
        return _rankMonths(chart, structure, context.decade!, context.year!);
      case TemporalLayer.month:
        return _rankDays(
            chart, structure, context.decade!, context.year!, context.month!);
      case TemporalLayer.day:
        // Already at the finest layer: the window is the day itself.
        return _single(chart, structure, context);
    }
  }

  // ---------------------------------------------------------------------

  static YingQiForecast _rankDecades(
      ChartResult chart, NatalStructure structure) {
    final candidates = [
      for (final d in chart.decades)
        _Candidate(
          layer: TemporalLayer.decade,
          label: '大运 ${d.ganZhi}（${d.startAge}-${d.endAge}岁，'
              '${d.startYear}-${d.endYear}）',
          ganZhi: d.ganZhi,
          start: DateTime(d.startYear),
          end: DateTime(d.endYear, 12, 31),
          context: ChartService.temporalContext(chart, decade: d),
        ),
    ];
    return _score(
      chart,
      structure,
      candidates,
      TemporalLayer.decade,
      '以原局格局（${structure.pattern.geJu}·${structure.status.label}）'
          '衡量八步大运的引动强弱',
      const {},
    );
  }

  static YingQiForecast _rankYears(
      ChartResult chart, NatalStructure structure, DecadeData decade) {
    final established = _themesOf(
        chart, structure, ChartService.temporalContext(chart, decade: decade),
        upTo: TemporalLayer.decade);
    final candidates = [
      for (final y in ChartService.flowYearsOf(chart, decade))
        _Candidate(
          layer: TemporalLayer.year,
          label: '流年 ${y.year} ${y.ganZhi}（${y.age}岁）',
          ganZhi: y.ganZhi,
          start: DateTime(y.year, 2, 4),
          end: DateTime(y.year + 1, 2, 3),
          context: ChartService.temporalContext(chart,
              decade: decade, year: y),
        ),
    ];
    return _score(chart, structure, candidates, TemporalLayer.year,
        '在${decade.ganZhi}大运内衡量十个流年的引动强弱', established);
  }

  static YingQiForecast _rankMonths(ChartResult chart, NatalStructure structure,
      DecadeData decade, FlowYearData year) {
    final base =
        ChartService.temporalContext(chart, decade: decade, year: year);
    final established =
        _themesOf(chart, structure, base, upTo: TemporalLayer.year);
    final candidates = [
      for (final m in ChartService.flowMonthsOf(chart, year.year))
        _Candidate(
          layer: TemporalLayer.month,
          label: '流月 ${m.ganZhi}月（${m.jieName}起）',
          ganZhi: m.ganZhi,
          start: m.start,
          end: m.end,
          context: ChartService.temporalContext(chart,
              decade: decade, year: year, month: m),
        ),
    ];
    return _score(chart, structure, candidates, TemporalLayer.month,
        '在${year.year}年${year.ganZhi}流年内衡量十二流月的引动强弱', established);
  }

  static YingQiForecast _rankDays(ChartResult chart, NatalStructure structure,
      DecadeData decade, FlowYearData year, FlowMonthData month) {
    final base = ChartService.temporalContext(chart,
        decade: decade, year: year, month: month);
    final established =
        _themesOf(chart, structure, base, upTo: TemporalLayer.month);
    final candidates = [
      for (final d in ChartService.flowDaysOf(chart, month))
        _Candidate(
          layer: TemporalLayer.day,
          label: '${YingQiWindow._fmt(d.date)} ${d.ganZhi}日',
          ganZhi: d.ganZhi,
          start: d.date,
          end: d.date,
          context: ChartService.temporalContext(chart,
              decade: decade, year: year, month: month, day: d),
        ),
    ];
    return _score(
        chart,
        structure,
        candidates,
        TemporalLayer.day,
        '在${year.year}年${month.ganZhi}月内定应期之日'
            '（流日只引动流年流月已成之势）',
        established);
  }

  static YingQiForecast _single(
      ChartResult chart, NatalStructure structure, TemporalContext context) {
    final established = _themesOf(
      chart,
      structure,
      ChartService.temporalContext(chart,
          decade: context.decade, year: context.year, month: context.month),
      upTo: TemporalLayer.month,
    );
    final d = context.day!;
    return _score(
      chart,
      structure,
      [
        _Candidate(
          layer: TemporalLayer.day,
          label: '${YingQiWindow._fmt(d.date)} ${d.ganZhi}日',
          ganZhi: d.ganZhi,
          start: d.date,
          end: d.date,
          context: context,
        ),
      ],
      TemporalLayer.day,
      '所选流日的引动强弱',
      established,
    );
  }

  // ---------------------------------------------------------------------

  /// 十神 themes already in play at [upTo] or coarser.
  static Set<String> _themesOf(
    ChartResult chart,
    NatalStructure structure,
    TemporalContext context, {
    required TemporalLayer upTo,
  }) {
    final acts = LuckActivationEngine.evaluate(structure, context);
    return LuckActivationEngine.themesAt(acts, upTo);
  }

  static YingQiForecast _score(
    ChartResult chart,
    NatalStructure structure,
    List<_Candidate> candidates,
    TemporalLayer granularity,
    String basis,
    Set<String> established,
  ) {
    final scored = <YingQiWindow>[];

    for (final c in candidates) {
      final acts = LuckActivationEngine.evaluate(structure, c.context);
      var raw = 0.0;
      var net = 0.0;
      final themes = <String>{};
      final triggers = <(double, String)>[];
      final suppressed = <String>[];

      // Only what this window itself contributes; coarser layers are the same
      // for every candidate and would just add a constant.
      for (final a in acts.where((a) => a.layer == granularity)) {
        // 流日不创事: a layer that may not originate events can only fire a
        // theme something coarser already established.
        if (!granularity.canOriginateEvents &&
            a.targetKind == '十神' &&
            established.isNotEmpty &&
            !established.contains(a.target)) {
          if (!suppressed.contains(a.target)) suppressed.add(a.target);
          continue;
        }

        final resonates =
            a.targetKind == '十神' && established.contains(a.target);
        final weight = a.intensity * (resonates ? _resonanceBonus : 1.0);
        raw += weight;
        // Neutral targets make a window eventful without making it good or
        // bad; only 喜忌 move the verdict.
        net += a.neutral ? 0.0 : (a.favourable ? weight : -weight);
        if (a.targetKind == '十神') themes.add(a.target);
        triggers.add((weight, a.description));
      }

      triggers.sort((a, b) => b.$1.compareTo(a.$1));
      scored.add(YingQiWindow(
        layer: granularity,
        label: c.label,
        ganZhi: c.ganZhi,
        start: c.start,
        end: c.end,
        score: 0, // filled in below
        rawScore: raw,
        net: net,
        themes: themes,
        triggers: [for (final t in triggers.take(6)) t.$2],
        suppressed: suppressed,
      ));
    }

    final maxRaw =
        scored.fold<double>(0, (m, w) => w.rawScore > m ? w.rawScore : m);
    final normalised = [
      for (final w in scored)
        YingQiWindow(
          layer: w.layer,
          label: w.label,
          ganZhi: w.ganZhi,
          start: w.start,
          end: w.end,
          score: maxRaw == 0 ? 0 : w.rawScore / maxRaw,
          rawScore: w.rawScore,
          net: w.net,
          themes: w.themes,
          triggers: w.triggers,
          suppressed: w.suppressed,
        ),
    ]..sort((a, b) {
        final byScore = b.rawScore.compareTo(a.rawScore);
        // Ties broken by date so the ordering is stable and reproducible.
        return byScore != 0 ? byScore : a.start.compareTo(b.start);
      });

    return YingQiForecast(
      granularity: granularity,
      basis: basis,
      windows: normalised,
      establishedThemes: established,
    );
  }
}

class _Candidate {
  final TemporalLayer layer;
  final String label;
  final String ganZhi;
  final DateTime start;
  final DateTime end;
  final TemporalContext context;

  const _Candidate({
    required this.layer,
    required this.label,
    required this.ganZhi,
    required this.start,
    required this.end,
    required this.context,
  });
}
