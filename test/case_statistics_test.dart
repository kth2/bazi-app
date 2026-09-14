import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/cases/case_record.dart';
import 'package:bazi_app/core/cases/case_statistics.dart';
import 'package:bazi_app/core/models/birth_input.dart';

const _input = BirthInput(
  calendarType: CalendarType.solar,
  year: 1990,
  month: 1,
  day: 1,
  hour: 12,
  minute: 0,
  gender: Gender.male,
  location: '北京',
  longitude: 116.41,
);

PredictedClaim claim({
  String id = 'c',
  ClaimKind kind = ClaimKind.event,
  String title = '事业·职位晋升',
  String? polarity,
  double confidence = 0.7,
  ClaimVerdict verdict = ClaimVerdict.unverified,
  DateTime? windowStart,
  DateTime? windowEnd,
  DateTime? actualDate,
}) =>
    PredictedClaim(
      id: id,
      kind: kind,
      title: title,
      detail: '',
      polarity: polarity,
      confidence: confidence,
      verdict: verdict,
      windowStart: windowStart,
      windowEnd: windowEnd,
      actualDate: actualDate,
    );

CaseRecord record(
  List<PredictedClaim> claims, {
  String id = 'case',
  String scopeLabel = '流年 2026 丙午',
  int engineVersion = 8,
  DateTime? reviewDueAt,
}) =>
    CaseRecord(
      id: id,
      title: 't',
      input: _input,
      baziString: '甲子 乙丑 丙寅 丁卯',
      scopeLabel: scopeLabel,
      engineVersion: engineVersion,
      structureSummary: '',
      claims: claims,
      createdAt: DateTime(2026),
      reviewDueAt: reviewDueAt,
    );

/// n verdicts of one kind, with distinct ids.
List<PredictedClaim> many(
  int n,
  ClaimVerdict verdict, {
  double confidence = 0.7,
  String? polarity,
  String title = '事业·职位晋升',
  ClaimKind kind = ClaimKind.event,
}) =>
    [
      for (var i = 0; i < n; i++)
        claim(
          id: '${verdict.name}_$i',
          verdict: verdict,
          confidence: confidence,
          polarity: polarity,
          title: title,
          kind: kind,
        ),
    ];

void main() {
  group('the denominator is only what could be judged', () {
    test('无法判断 is excluded, not counted as wrong', () {
      // Scoring "I could not tell" as a miss would understate accuracy as
      // badly as scoring it as a hit would overstate it.
      final s = CaseStatistics.of([
        record([
          ...many(3, ClaimVerdict.hit),
          ...many(1, ClaimVerdict.miss),
          ...many(4, ClaimVerdict.unclear),
        ]),
      ]);
      expect(s.overall.scorable, 4);
      expect(s.overall.rate, 0.75);
      expect(s.overall.unclear, 4);
    });

    test('待回填 never enters any rate', () {
      final s = CaseStatistics.of([
        record([
          ...many(2, ClaimVerdict.hit),
          ...many(10, ClaimVerdict.unverified),
        ]),
      ]);
      expect(s.overall.scorable, 2);
      expect(s.overall.unverified, 10);
      expect(s.overall.rate, 1.0);
    });

    test('nothing reviewed yields null, not zero', () {
      // An unreviewed journal has no accuracy. Reporting 0% would read as
      // "the app is always wrong".
      final s = CaseStatistics.of([record(many(5, ClaimVerdict.unverified))]);
      expect(s.overall.rate, isNull);
      expect(s.overall.strictRate, isNull);
    });

    test('unclearShare flags a rate computed on a thin remainder', () {
      final s = CaseStatistics.of([
        record([
          ...many(2, ClaimVerdict.hit),
          ...many(8, ClaimVerdict.unclear),
        ]),
      ]);
      expect(s.overall.unclearShare, 0.8);
    });
  });

  group('both rates are reported, and they differ', () {
    test('部分应验 is half credit in the main rate and none in the strict one',
        () {
      final s = CaseStatistics.of([
        record([
          ...many(2, ClaimVerdict.hit),
          ...many(2, ClaimVerdict.partial),
        ]),
      ]);
      expect(s.overall.rate, 0.75);
      expect(s.overall.strictRate, 0.5);
    });
  });

  group('calibration', () {
    test('bands a claim by its stated confidence', () {
      final s = CaseStatistics.of([
        record([
          claim(id: 'a', confidence: 0.3, verdict: ClaimVerdict.miss),
          claim(id: 'b', confidence: 0.5, verdict: ClaimVerdict.hit),
          claim(id: 'c', confidence: 0.7, verdict: ClaimVerdict.hit),
          claim(id: 'd', confidence: 0.9, verdict: ClaimVerdict.hit),
        ]),
      ]);
      expect(s.calibration, hasLength(CaseStatistics.kBands.length));
      for (final b in s.calibration) {
        expect(b.tally.scorable, 1, reason: b.label);
      }
    });

    test('1.0 lands in the top band rather than falling off the end', () {
      final s = CaseStatistics.of([
        record([claim(confidence: 1.0, verdict: ClaimVerdict.hit)]),
      ]);
      expect(s.calibration.last.tally.scorable, 1);
    });

    test('gap is observed minus stated, signed', () {
      // Stated 0.9, observed 0.5 — the engine over-claimed by 40 points.
      final s = CaseStatistics.of([
        record([
          ...many(2, ClaimVerdict.hit, confidence: 0.9),
          ...many(2, ClaimVerdict.miss, confidence: 0.9),
        ]),
      ]);
      final top = s.calibration.last;
      expect(top.meanConfidence, closeTo(0.9, 1e-9));
      expect(top.tally.rate, 0.5);
      expect(top.gap, closeTo(-0.4, 1e-9));
    });

    test('claims with no stated confidence are excluded, not treated as 0', () {
      // 问答 claims carry no engine confidence; banding them at zero would
      // invent a bottom-band population that never existed.
      final s = CaseStatistics.of([
        record([
          claim(
              id: 'q',
              kind: ClaimKind.qa,
              confidence: 0,
              verdict: ClaimVerdict.hit),
        ]),
      ]);
      expect(s.calibration.fold<int>(0, (n, b) => n + b.tally.scorable), 0);
      expect(s.byKind[ClaimKind.qa]!.scorable, 1,
          reason: 'still counted in the overall rate');
    });

    test('is not offered until at least two bands have data', () {
      final one = CaseStatistics.of([
        record(many(5, ClaimVerdict.hit, confidence: 0.7)),
      ]);
      expect(one.hasCalibration, isFalse);

      final two = CaseStatistics.of([
        record([
          ...many(3, ClaimVerdict.hit, confidence: 0.7),
          ...many(3, ClaimVerdict.miss, confidence: 0.3),
        ]),
      ]);
      expect(two.hasCalibration, isTrue);
    });
  });

  group('breakdowns', () {
    test('domain comes from the event title, and only from event claims', () {
      final s = CaseStatistics.of([
        record([
          claim(
              id: 'a', title: '事业·职位晋升', verdict: ClaimVerdict.hit),
          claim(
              id: 'b', title: '健康·劳神耗气', verdict: ClaimVerdict.miss),
          claim(
              id: 'c',
              kind: ClaimKind.structure,
              title: '正官格·成格',
              verdict: ClaimVerdict.hit),
        ]),
      ]);
      expect(s.byDomain.keys, unorderedEquals(['事业', '健康']));
      expect(s.byDomain['事业']!.hit, 1);
      expect(s.byKind[ClaimKind.structure]!.hit, 1);
    });

    test('polarity is tallied separately, so a one-sided engine shows up', () {
      // The reason this breakdown exists: if 凶 lands far less often than 吉,
      // the reading leans pessimistic in the real world too.
      final s = CaseStatistics.of([
        record([
          ...many(4, ClaimVerdict.hit, polarity: '吉'),
          ...many(4, ClaimVerdict.miss, polarity: '凶'),
        ]),
      ]);
      expect(s.byPolarity['吉']!.rate, 1.0);
      expect(s.byPolarity['凶']!.rate, 0.0);
    });

    test('scope labels collapse to their family', () {
      expect(CaseStatistics.scopeGroupOf('大运 癸酉（29-38岁）'), '大运');
      expect(CaseStatistics.scopeGroupOf('流年 2026 丙午'), '流年');
      expect(CaseStatistics.scopeGroupOf('整体命局'), '整体命局');
      expect(CaseStatistics.scopeGroupOf(''), '未分类');
    });

    test('engine versions are kept apart', () {
      // A verdict against v4 is evidence about v4. Averaging it into v8
      // silently mixes two different programs.
      final s = CaseStatistics.of([
        record(many(2, ClaimVerdict.hit), id: 'old', engineVersion: 4),
        record(many(2, ClaimVerdict.miss), id: 'new', engineVersion: 8),
      ]);
      expect(s.byEngineVersion[4]!.rate, 1.0);
      expect(s.byEngineVersion[8]!.rate, 0.0);
      expect(s.versions, [8, 4]);
    });
  });

  group('应期 timing is judged separately from whether it happened', () {
    test('counts only dated claims, in and out of window', () {
      final s = CaseStatistics.of([
        record([
          claim(
            id: 'w1',
            kind: ClaimKind.yingQi,
            verdict: ClaimVerdict.hit,
            windowStart: DateTime(2026, 3, 1),
            windowEnd: DateTime(2026, 4, 1),
            actualDate: DateTime(2026, 3, 15),
          ),
          claim(
            id: 'w2',
            kind: ClaimKind.yingQi,
            verdict: ClaimVerdict.hit,
            windowStart: DateTime(2026, 3, 1),
            windowEnd: DateTime(2026, 4, 1),
            actualDate: DateTime(2026, 8, 1),
          ),
          claim(
            id: 'w3',
            kind: ClaimKind.yingQi,
            verdict: ClaimVerdict.hit,
            windowStart: DateTime(2026, 3, 1),
            windowEnd: DateTime(2026, 4, 1),
          ),
        ]),
      ]);
      expect(s.timing.inWindow, 1);
      expect(s.timing.outOfWindow, 1);
      expect(s.timing.undated, 1);
      expect(s.timing.rate, 0.5);
      // An event can happen and still miss its window — the two numbers must
      // be able to disagree.
      expect(s.byKind[ClaimKind.yingQi]!.rate, 1.0);
    });
  });

  group('small samples are not dressed up as measurements', () {
    test('enough() gates on the scorable count', () {
      expect(CaseStatistics.enough(const Tally(hit: 3, miss: 1)), isFalse);
      expect(
          CaseStatistics.enough(
              Tally(hit: CaseStatistics.kMinSample, miss: 0)),
          isTrue);
      // Unverified claims do not help a thin sample look thick.
      expect(CaseStatistics.enough(const Tally(hit: 2, unverified: 50)),
          isFalse);
    });
  });

  group('case-level counts', () {
    test('reviewed and due cases are counted from status', () {
      final past = DateTime(2025);
      final s = CaseStatistics.of([
        record(many(2, ClaimVerdict.hit), id: 'done', reviewDueAt: past),
        record(many(2, ClaimVerdict.unverified),
            id: 'due', reviewDueAt: past),
        record(many(2, ClaimVerdict.unverified),
            id: 'pending', reviewDueAt: DateTime(2030)),
      ], now: DateTime(2026));
      expect(s.cases, 3);
      expect(s.reviewedCases, 1);
      expect(s.dueCases, 1);
    });

    test('an empty journal produces an empty, non-crashing summary', () {
      final s = CaseStatistics.of([]);
      expect(s.cases, 0);
      expect(s.overall.total, 0);
      expect(s.overall.rate, isNull);
      expect(s.hasCalibration, isFalse);
      expect(s.toJson()['cases'], 0);
    });
  });
}
