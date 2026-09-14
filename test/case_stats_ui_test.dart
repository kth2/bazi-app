import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/cases/case_record.dart';
import 'package:bazi_app/core/models/birth_input.dart';
import 'package:bazi_app/features/cases/case_stats_page.dart';
import 'package:bazi_app/providers/case_provider.dart';

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

PredictedClaim claim(
  String id,
  ClaimVerdict verdict, {
  double confidence = 0.7,
  String? polarity,
  String title = '事业·职位晋升',
  ClaimKind kind = ClaimKind.event,
}) =>
    PredictedClaim(
      id: id,
      kind: kind,
      title: title,
      detail: '',
      polarity: polarity,
      confidence: confidence,
      verdict: verdict,
    );

CaseRecord record(List<PredictedClaim> claims, {String id = 'c'}) =>
    CaseRecord(
      id: id,
      title: 't',
      input: _input,
      baziString: '甲子 乙丑 丙寅 丁卯',
      scopeLabel: '流年 2026 丙午',
      engineVersion: 8,
      structureSummary: '',
      claims: claims,
      createdAt: DateTime(2026),
    );

Widget wrap(List<CaseRecord> cases) => ProviderScope(
      overrides: [
        caseListProvider.overrideWith((ref) => Stream.value(cases)),
      ],
      child: const MaterialApp(home: CaseStatsPage()),
    );

List<PredictedClaim> many(int n, ClaimVerdict v,
        {double confidence = 0.7, String? polarity}) =>
    [
      for (var i = 0; i < n; i++)
        claim('${v.name}_$i', v, confidence: confidence, polarity: polarity),
    ];

/// The page is a lazy ListView, so anything below the fold has to be scrolled
/// into existence before it can be found.
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty journal explains itself instead of showing 0%',
      (tester) async {
    await tester.pumpWidget(wrap([]));
    await tester.pumpAndSettle();

    expect(find.textContaining('还没有可统计的记录'), findsOneWidget);
    expect(find.textContaining('0%'), findsNothing);
  });

  testWidgets('a thin sample shows counts, not a percentage', (tester) async {
    await tester.pumpWidget(wrap([
      record([...many(3, ClaimVerdict.hit), ...many(1, ClaimVerdict.miss)]),
    ]));
    await tester.pumpAndSettle();

    // 3 of 4 correct is not "75%".
    expect(find.text('3 中 / 4 已判'), findsOneWidget);
    expect(find.textContaining('样本不足'), findsOneWidget);
  });

  testWidgets('a sufficient sample shows both the lenient and strict rate',
      (tester) async {
    await tester.pumpWidget(wrap([
      record([
        ...many(6, ClaimVerdict.hit),
        ...many(2, ClaimVerdict.partial),
        ...many(2, ClaimVerdict.miss),
      ]),
    ]));
    await tester.pumpAndSettle();

    // 6 hits + 2 half = 7 / 10 = 70%; strict 6 / 10 = 60%.
    expect(find.text('70%'), findsOneWidget);
    expect(find.text('严格 60%'), findsOneWidget);
  });

  testWidgets('a mostly-unjudgeable journal says so in the open',
      (tester) async {
    await tester.pumpWidget(wrap([
      record([
        ...many(2, ClaimVerdict.hit),
        ...many(8, ClaimVerdict.unclear),
      ]),
    ]));
    await tester.pumpAndSettle();

    expect(find.textContaining('80% 是「无法判断」'), findsOneWidget);
  });

  testWidgets('calibration appears once two bands have data', (tester) async {
    await tester.pumpWidget(wrap([
      record([
        ...many(4, ClaimVerdict.hit, confidence: 0.9),
        ...many(4, ClaimVerdict.miss, confidence: 0.3),
      ]),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('置信度校准'), findsOneWidget);
    expect(find.text('引擎把握度'), findsOneWidget);
    expect(find.text('实际应验率'), findsOneWidget);
  });

  testWidgets('the polarity breakdown is present when claims carry one',
      (tester) async {
    await tester.pumpWidget(wrap([
      record([
        ...many(4, ClaimVerdict.hit, polarity: '吉'),
        ...many(4, ClaimVerdict.miss, polarity: '凶'),
      ]),
    ]));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('按吉凶'));
    expect(find.text('按吉凶'), findsOneWidget);
    expect(find.textContaining('偏向往坏处说'), findsOneWidget);
  });

  testWidgets('the limits of the number are stated on the page itself',
      (tester) async {
    // The caveats are not an appendix — a bare accuracy percentage from
    // self-recorded, self-scored predictions invites more confidence than it
    // has earned, and the page has to say so where the number is.
    await tester.pumpWidget(wrap([
      record([...many(8, ClaimVerdict.hit), ...many(2, ClaimVerdict.miss)]),
    ]));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.textContaining('记录和评判都由你自己做'));
    expect(find.textContaining('记录和评判都由你自己做'), findsOneWidget);
    expect(find.textContaining('没有基准率对照'), findsOneWidget);
    expect(find.textContaining('不会回流到引擎里'), findsOneWidget);
  });

  testWidgets('renders without a crash at every sample size', (tester) async {
    for (final cases in <List<CaseRecord>>[
      [],
      [record([])],
      [record(many(1, ClaimVerdict.unverified))],
      [record(many(200, ClaimVerdict.hit))],
    ]) {
      await tester.pumpWidget(wrap(cases));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
