import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/cases/case_record.dart';
import 'package:bazi_app/core/models/birth_input.dart';
import 'package:bazi_app/features/cases/case_list_page.dart';
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

PredictedClaim claim(String id, ClaimVerdict v) => PredictedClaim(
      id: id,
      kind: ClaimKind.qa,
      title: 'q',
      detail: '',
      verdict: v,
    );

CaseRecord record({
  required List<PredictedClaim> claims,
  DateTime? due,
  String scope = '流年 2026 丙午',
}) =>
    CaseRecord(
      id: 'c',
      title: '癸巳 戊午 癸巳 乙卯 · 整体命局与大运流年综合推演',
      input: _input,
      baziString: '癸巳 戊午 癸巳 乙卯',
      scopeLabel: scope,
      engineVersion: 9,
      structureSummary: '格局：偏财格；成败：成格；用神：月令丁偏财为用神',
      claims: claims,
      createdAt: DateTime(2026, 9, 21),
      reviewDueAt: due ?? DateTime(2027, 2, 4),
    );

Widget wrap(List<CaseRecord> cases) => ProviderScope(
      overrides: [
        caseListProvider.overrideWith((ref) => Stream.value(cases)),
      ],
      child: const MaterialApp(home: CaseListPage()),
    );

void main() {
  testWidgets('the card footer does not overflow on a narrow phone',
      (tester) async {
    // 320dp is the narrowest phone width still in use. The footer holds
    // 「记于 … · 可回填于 …」 on the left and the review count on the right,
    // and the left half had no Flexible — so the right half was pushed past
    // the card's edge.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap([
      record(claims: [claim('a', ClaimVerdict.hit), claim('b', ClaimVerdict.unverified)]),
    ]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('and survives a large accessibility text scale', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        caseListProvider.overrideWith((ref) => Stream.value([
              record(claims: [claim('a', ClaimVerdict.hit)]),
            ])),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: const CaseListPage(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
