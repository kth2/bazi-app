import 'dart:math' as math;

import 'case_record.dart';
import 'choice_question.dart';

/// Counts of how a set of claims turned out.
class Tally {
  final int hit;
  final int partial;
  final int miss;

  /// Reviewed, but nothing observable either way. Excluded from the rate
  /// rather than counted as a miss — "I could not tell" is not "wrong".
  final int unclear;

  /// Not yet reviewed at all.
  final int unverified;

  const Tally({
    this.hit = 0,
    this.partial = 0,
    this.miss = 0,
    this.unclear = 0,
    this.unverified = 0,
  });

  /// Claims that could actually be judged — the denominator of every rate
  /// here.
  int get scorable => hit + partial + miss;

  int get total => scorable + unclear + unverified;

  /// 应验率, counting 部分应验 as half.
  ///
  /// Null rather than zero when nothing is scorable: an unreviewed set has no
  /// accuracy, which is a different statement from an accuracy of nought.
  double? get rate =>
      scorable == 0 ? null : (hit + partial * 0.5) / scorable;

  /// 应验率 counting only outright hits.
  ///
  /// Reported alongside [rate] everywhere, because half credit for 部分应验
  /// is a generous convention and a single number built on it reads better
  /// than the evidence supports.
  double? get strictRate => scorable == 0 ? null : hit / scorable;

  /// Share of reviewed claims that turned out to be unjudgeable.
  ///
  /// The health check on the whole exercise: if most claims end up 无法判断,
  /// the rate is computed over a small and self-selected remainder.
  double? get unclearShare {
    final reviewed = scorable + unclear;
    return reviewed == 0 ? null : unclear / reviewed;
  }

  Tally plus(ClaimVerdict v) => Tally(
        hit: hit + (v == ClaimVerdict.hit ? 1 : 0),
        partial: partial + (v == ClaimVerdict.partial ? 1 : 0),
        miss: miss + (v == ClaimVerdict.miss ? 1 : 0),
        unclear: unclear + (v == ClaimVerdict.unclear ? 1 : 0),
        unverified: unverified + (v == ClaimVerdict.unverified ? 1 : 0),
      );

  Map<String, dynamic> toJson() => {
        'hit': hit,
        'partial': partial,
        'miss': miss,
        'unclear': unclear,
        'unverified': unverified,
        'scorable': scorable,
        if (rate != null) 'rate': double.parse(rate!.toStringAsFixed(3)),
        if (strictRate != null)
          'strictRate': double.parse(strictRate!.toStringAsFixed(3)),
      };
}

/// One confidence band, and what actually happened inside it.
///
/// This is the statistic worth having. A single 应验率 says how often the app
/// was right; a calibration curve says whether its *stated confidence means
/// anything* — whether claims it called 80% land more often than ones it
/// called 40%. An engine that is 60% accurate but correctly ordered is far
/// more useful than one that is 60% accurate at random, and only this view
/// tells them apart.
class CalibrationBucket {
  /// Inclusive lower, exclusive upper (the top bucket includes 1.0).
  final double from;
  final double to;

  /// Mean stated confidence of the claims that landed in this band.
  final double meanConfidence;

  final Tally tally;

  const CalibrationBucket({
    required this.from,
    required this.to,
    required this.meanConfidence,
    required this.tally,
  });

  String get label => '${(from * 100).round()}–${(to * 100).round()}%';

  /// observed − stated. Positive means the engine under-claimed.
  double? get gap {
    final observed = tally.rate;
    return observed == null ? null : observed - meanConfidence;
  }
}

/// How 应期 windows did on *timing*, separately from whether the event
/// happened at all.
///
/// A window can be right about the event and wrong about the month; lumping
/// the two together hides which half of the reasoning is working.
class TimingTally {
  final int inWindow;
  final int outOfWindow;

  /// Marked 应验 but with no date filled in, so timing cannot be judged.
  final int undated;

  const TimingTally({
    this.inWindow = 0,
    this.outOfWindow = 0,
    this.undated = 0,
  });

  int get dated => inWindow + outOfWindow;

  double? get rate => dated == 0 ? null : inWindow / dated;
}

/// 95% Wilson score interval for [hits] out of [n].
///
/// Used instead of the textbook ±1.96·√(p(1−p)/n) because that one is
/// nonsense at the sample sizes this journal has — it gives 2/7 an interval
/// dipping below zero. Null when n is 0.
(double, double)? wilson95(int hits, int n) {
  if (n == 0) return null;
  const z = 1.96;
  final p = hits / n;
  final denom = 1 + z * z / n;
  final centre = (p + z * z / (2 * n)) / denom;
  final half =
      z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / denom;
  return (math.max(0, centre - half), math.min(1, centre + half));
}

/// How the two-way 选择题 went, split by which way the AI leaned.
///
/// The one comparison a bare 应验率 cannot make. On an A/B question a rate
/// means nothing until it is set against what a program that *never looked
/// at the chart* would score:
///
/// - [baseline] — always answering the plainer option. The questions people
///   set are mostly one grand outcome against one ordinary one, and ordinary
///   is what usually happened; this is the number to beat.
/// - [noSkillExpected] — picking the brighter option exactly as often as the
///   AI did, but at random. If the observed rate sits on this, the reading
///   is a coin with a bias, whatever the rate itself says.
///
/// And whether the pick carries information: [rateWhenBrighter] against
/// [rateWhenPlainer]. A reading with skill is right more often on both sides
/// than the share of that side among real outcomes.
///
/// Only 应验 / 未应验 count. 部分应验 on a two-way question does not say which
/// option was true.
class ChoiceBias {
  final int brighterHit;
  final int brighterMiss;
  final int plainerHit;
  final int plainerMiss;

  const ChoiceBias({
    this.brighterHit = 0,
    this.brighterMiss = 0,
    this.plainerHit = 0,
    this.plainerMiss = 0,
  });

  int get n => brighterHit + brighterMiss + plainerHit + plainerMiss;
  int get hits => brighterHit + plainerHit;
  int get pickedBrighter => brighterHit + brighterMiss;
  int get pickedPlainer => plainerHit + plainerMiss;

  /// Questions whose real answer was the brighter option.
  int get truthBrighter => brighterHit + plainerMiss;

  double? get rate => n == 0 ? null : hits / n;
  (double, double)? get interval => wilson95(hits, n);

  double? get brighterShare => n == 0 ? null : pickedBrighter / n;
  double? get truthBrighterShare => n == 0 ? null : truthBrighter / n;

  /// Always answering the plainer option.
  double? get baseline => n == 0 ? null : (n - truthBrighter) / n;

  /// The AI's own mix of picks, placed at random.
  double? get noSkillExpected {
    if (n == 0) return null;
    final pick = pickedBrighter / n;
    final truth = truthBrighter / n;
    return pick * truth + (1 - pick) * (1 - truth);
  }

  double? get rateWhenBrighter =>
      pickedBrighter == 0 ? null : brighterHit / pickedBrighter;
  double? get rateWhenPlainer =>
      pickedPlainer == 0 ? null : plainerHit / pickedPlainer;

  /// Wrong because it said better than it was.
  int get optimisticMisses => brighterMiss;

  /// Wrong because it said worse than it was.
  int get pessimisticMisses => plainerMiss;

  ChoiceBias plus(OptionLean lean, ClaimVerdict v) {
    if (v != ClaimVerdict.hit && v != ClaimVerdict.miss) return this;
    final hit = v == ClaimVerdict.hit;
    return switch (lean) {
      OptionLean.brighter => ChoiceBias(
          brighterHit: brighterHit + (hit ? 1 : 0),
          brighterMiss: brighterMiss + (hit ? 0 : 1),
          plainerHit: plainerHit,
          plainerMiss: plainerMiss,
        ),
      OptionLean.plainer => ChoiceBias(
          brighterHit: brighterHit,
          brighterMiss: brighterMiss,
          plainerHit: plainerHit + (hit ? 1 : 0),
          plainerMiss: plainerMiss + (hit ? 0 : 1),
        ),
      OptionLean.none => this,
    };
  }

  Map<String, dynamic> toJson() => {
        'brighterHit': brighterHit,
        'brighterMiss': brighterMiss,
        'plainerHit': plainerHit,
        'plainerMiss': plainerMiss,
        if (baseline != null)
          'baseline': double.parse(baseline!.toStringAsFixed(3)),
        if (noSkillExpected != null)
          'noSkillExpected': double.parse(noSkillExpected!.toStringAsFixed(3)),
      };
}

/// Aggregate accuracy across the case journal.
///
/// Read-only, and deliberately so. Nothing under `core/analysis`,
/// `core/rules`, `core/engine`, `core/models` or `core/timeline` may import
/// this — see `test/case_guardrail_test.dart`. These numbers exist so a person
/// can judge the theory, never so the program can adjust itself towards them.
class CaseStatistics {
  final int cases;
  final int reviewedCases;
  final int dueCases;

  final Tally overall;
  final Map<ClaimKind, Tally> byKind;

  /// 事业 / 财富 / 婚姻 / 学业发展 / 健康, taken from an event claim's
  /// `域·子类型` title.
  final Map<String, Tally> byDomain;

  /// 吉 / 凶 / 吉凶参半.
  ///
  /// Worth its own breakdown because this app has already had to correct a
  /// systematic pessimism once: if 凶 claims land far less often than 吉 ones,
  /// that is the same bias showing up in the real world rather than in a
  /// 240-chart grid.
  final Map<String, Tally> byPolarity;

  /// 整体命局 / 大运 / 流年 / 流月 / 流日, from the case's scope label.
  final Map<String, Tally> byScope;

  /// Claims are only evidence about the engine version that made them.
  final Map<int, Tally> byEngineVersion;

  final List<CalibrationBucket> calibration;
  final TimingTally timing;

  /// Two-way 选择题, all versions together.
  final ChoiceBias choice;

  /// The same per engine version — the lean is a property of the version
  /// that answered, and it has swung from one side to the other before.
  final Map<int, ChoiceBias> choiceByVersion;

  /// The same per question kind.
  final Map<QuestionTopic, ChoiceBias> choiceByTopic;

  const CaseStatistics({
    required this.cases,
    required this.reviewedCases,
    required this.dueCases,
    required this.overall,
    required this.byKind,
    required this.byDomain,
    required this.byPolarity,
    required this.byScope,
    required this.byEngineVersion,
    required this.calibration,
    required this.timing,
    this.choice = const ChoiceBias(),
    this.choiceByVersion = const {},
    this.choiceByTopic = const {},
  });

  /// Below this a percentage is noise dressed as a measurement, and the UI
  /// shows the raw counts instead.
  ///
  /// Eight is not a statistical threshold — no small number is — but it is
  /// where "3 of 4 correct = 75%" stops being the most misleading way to say
  /// "three out of four".
  static const int kMinSample = 8;

  static bool enough(Tally t) => t.scorable >= kMinSample;

  static const List<(double, double)> kBands = [
    (0.0, 0.4),
    (0.4, 0.6),
    (0.6, 0.8),
    (0.8, 1.0),
  ];

  static CaseStatistics of(List<CaseRecord> records, {DateTime? now}) {
    final at = now ?? DateTime.now();

    var overall = const Tally();
    final byKind = <ClaimKind, Tally>{};
    final byDomain = <String, Tally>{};
    final byPolarity = <String, Tally>{};
    final byScope = <String, Tally>{};
    final byVersion = <int, Tally>{};
    final confidences = <int, List<double>>{};
    final bandTally = <int, Tally>{};
    var timing = const TimingTally();
    var choice = const ChoiceBias();
    final choiceByVersion = <int, ChoiceBias>{};
    final choiceByTopic = <QuestionTopic, ChoiceBias>{};

    var reviewedCases = 0;
    var dueCases = 0;

    for (final record in records) {
      final status = record.status(at);
      if (status == CaseStatus.reviewed) reviewedCases++;
      if (status == CaseStatus.awaitingReview ||
          status == CaseStatus.partiallyReviewed) {
        dueCases++;
      }
      final scope = scopeGroupOf(record.scopeLabel);

      for (final claim in record.claims) {
        final v = claim.verdict;
        overall = overall.plus(v);
        byKind[claim.kind] = (byKind[claim.kind] ?? const Tally()).plus(v);
        byScope[scope] = (byScope[scope] ?? const Tally()).plus(v);
        byVersion[record.engineVersion] =
            (byVersion[record.engineVersion] ?? const Tally()).plus(v);

        if (claim.kind == ClaimKind.event) {
          final domain = domainOf(claim.title);
          if (domain != null) {
            byDomain[domain] = (byDomain[domain] ?? const Tally()).plus(v);
          }
        }

        final polarity = claim.polarity;
        if (polarity != null && polarity.isNotEmpty) {
          byPolarity[polarity] =
              (byPolarity[polarity] ?? const Tally()).plus(v);
        }

        // Calibration only makes sense where the engine actually stated a
        // confidence, and only over claims that could be judged. 问答 claims
        // carry no confidence and are excluded rather than counted as 0.
        if (v.isScorable && claim.confidence > 0) {
          final band = _bandOf(claim.confidence);
          if (band != null) {
            bandTally[band] = (bandTally[band] ?? const Tally()).plus(v);
            (confidences[band] ??= []).add(claim.confidence);
          }
        }

        if (claim.kind == ClaimKind.qa) {
          final lean = claim.lean;
          if (lean != OptionLean.none) {
            choice = choice.plus(lean, v);
            final version = record.engineVersion;
            choiceByVersion[version] =
                (choiceByVersion[version] ?? const ChoiceBias()).plus(lean, v);
            final topic = claim.choice?.topic;
            if (topic != null) {
              choiceByTopic[topic] =
                  (choiceByTopic[topic] ?? const ChoiceBias()).plus(lean, v);
            }
          }
        }

        if (claim.kind == ClaimKind.yingQi && v.isScorable) {
          final landed = claim.landedInWindow;
          timing = TimingTally(
            inWindow: timing.inWindow + (landed == true ? 1 : 0),
            outOfWindow: timing.outOfWindow + (landed == false ? 1 : 0),
            undated: timing.undated +
                (landed == null && v != ClaimVerdict.miss ? 1 : 0),
          );
        }
      }
    }

    final calibration = <CalibrationBucket>[];
    for (var i = 0; i < kBands.length; i++) {
      final tally = bandTally[i] ?? const Tally();
      final values = confidences[i] ?? const <double>[];
      calibration.add(CalibrationBucket(
        from: kBands[i].$1,
        to: kBands[i].$2,
        meanConfidence: values.isEmpty
            ? (kBands[i].$1 + kBands[i].$2) / 2
            : values.reduce((a, b) => a + b) / values.length,
        tally: tally,
      ));
    }

    return CaseStatistics(
      cases: records.length,
      reviewedCases: reviewedCases,
      dueCases: dueCases,
      overall: overall,
      byKind: byKind,
      byDomain: byDomain,
      byPolarity: byPolarity,
      byScope: byScope,
      byEngineVersion: byVersion,
      calibration: calibration,
      timing: timing,
      choice: choice,
      choiceByVersion: choiceByVersion,
      choiceByTopic: choiceByTopic,
    );
  }

  static int? _bandOf(double confidence) {
    for (var i = 0; i < kBands.length; i++) {
      final (lo, hi) = kBands[i];
      if (confidence >= lo && (confidence < hi || (i == kBands.length - 1))) {
        return i;
      }
    }
    return null;
  }

  /// 事业·职务变动 → 事业.
  static String? domainOf(String title) {
    final i = title.indexOf('·');
    if (i <= 0) return null;
    return title.substring(0, i);
  }

  /// 大运 癸酉（29-38岁） → 大运.
  static String scopeGroupOf(String scopeLabel) {
    for (final prefix in ['整体命局', '大运', '流年', '流月', '流日']) {
      if (scopeLabel.startsWith(prefix)) return prefix;
    }
    return scopeLabel.isEmpty ? '未分类' : scopeLabel;
  }

  /// Whether the calibration curve is even worth drawing yet.
  bool get hasCalibration =>
      calibration.where((b) => b.tally.scorable > 0).length >= 2;

  /// Engine versions represented, newest first.
  ///
  /// Shown because the engine has changed repeatedly: a verdict recorded
  /// against version 4 is evidence about version 4, and averaging it with
  /// version 8 quietly mixes two different programs.
  List<int> get versions =>
      byEngineVersion.keys.toList()..sort((a, b) => b.compareTo(a));

  Map<String, dynamic> toJson() => {
        'cases': cases,
        'reviewedCases': reviewedCases,
        'overall': overall.toJson(),
        'byKind': {
          for (final e in byKind.entries) e.key.name: e.value.toJson(),
        },
        'byDomain': {
          for (final e in byDomain.entries) e.key: e.value.toJson(),
        },
        'byPolarity': {
          for (final e in byPolarity.entries) e.key: e.value.toJson(),
        },
        'byScope': {
          for (final e in byScope.entries) e.key: e.value.toJson(),
        },
        'byEngineVersion': {
          for (final e in byEngineVersion.entries)
            e.key.toString(): e.value.toJson(),
        },
        'calibration': [
          for (final b in calibration)
            {
              'band': b.label,
              'meanConfidence':
                  double.parse(b.meanConfidence.toStringAsFixed(3)),
              'tally': b.tally.toJson(),
            },
        ],
        'timing': {
          'inWindow': timing.inWindow,
          'outOfWindow': timing.outOfWindow,
          'undated': timing.undated,
        },
        'choice': choice.toJson(),
        'choiceByVersion': {
          for (final e in choiceByVersion.entries)
            e.key.toString(): e.value.toJson(),
        },
      };
}
