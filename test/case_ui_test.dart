import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/cases/case_record.dart';
import 'package:bazi_app/core/cases/cases_db.dart';
import 'package:bazi_app/core/models/birth_input.dart';
import 'package:bazi_app/features/cases/case_detail_page.dart';
import 'package:bazi_app/features/cases/case_list_page.dart';
import 'package:bazi_app/providers/case_provider.dart';

/// Widget tests override [caseListProvider] rather than injecting a real
/// database: drift's connection does asynchronous work that never completes
/// inside testWidgets' fake-async zone, so a real DB deadlocks the pump.
/// Storage itself is covered against a real database in case_journal_test.dart.
Widget wrap(List<CaseRecord> cases) => ProviderScope(
      overrides: [
        caseListProvider.overrideWith((ref) => Stream.value(cases)),
      ],
      child: const MaterialApp(home: CaseListPage()),
    );

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

CaseRecord record({
  String id = 'c1',
  String title = '客户A · 2026 流年',
  List<PredictedClaim> claims = const [],
  DateTime? reviewDueAt,
}) =>
    CaseRecord(
      id: id,
      title: title,
      input: _input,
      baziString: '己巳 丙子 丙寅 甲午',
      scopeLabel: '流年 2026 丙午',
      engineVersion: 3,
      structureSummary: '格局：正官格；成败：破而有救；用神：月令癸正官为用神',
      claims: claims.isEmpty
          ? const [
              PredictedClaim(
                id: 'event_0',
                kind: ClaimKind.event,
                title: '事业·职务变动',
                detail: '流年冲提纲',
              ),
            ]
          : claims,
      createdAt: DateTime(2026, 3, 1),
      reviewDueAt: reviewDueAt ?? DateTime(2027, 2, 4),
    );

void main() {
  testWidgets('empty journal explains how to record a case', (tester) async {
    await tester.pumpWidget(wrap(const []));
    await tester.pump();

    expect(find.text('案例库'), findsOneWidget);
    expect(find.text('还没有保存的案例'), findsOneWidget);
    expect(find.textContaining('存为案例'), findsOneWidget);
  });

  testWidgets('a saved case shows its scope, structure and review state',
      (tester) async {
    await tester.pumpWidget(wrap([record()]));
    await tester.pump();

    expect(find.text('客户A · 2026 流年'), findsOneWidget);
    expect(find.textContaining('己巳 丙子 丙寅 甲午'), findsOneWidget);
    expect(find.textContaining('正官格'), findsOneWidget);
    expect(find.textContaining('0/1 已回填'), findsOneWidget);
  });

  testWidgets('a case whose period has passed reads 待回填', (tester) async {
    // reviewDueAt in the past → the user is invited back.
    await tester.pumpWidget(wrap([record(reviewDueAt: DateTime(2020, 1, 1))]));
    await tester.pump();
    expect(find.text('待回填'), findsOneWidget);
  });

  testWidgets('a fully reviewed case reports its 应验率', (tester) async {
    await tester.pumpWidget(wrap([
      record(claims: const [
        PredictedClaim(
          id: 'a',
          kind: ClaimKind.event,
          title: '事业·职务变动',
          detail: 'x',
          verdict: ClaimVerdict.hit,
        ),
        PredictedClaim(
          id: 'b',
          kind: ClaimKind.event,
          title: '财富·破财损耗',
          detail: 'y',
          verdict: ClaimVerdict.miss,
        ),
      ])
    ]));
    await tester.pump();

    expect(find.text('已回填'), findsOneWidget);
    expect(find.textContaining('应验率 50%'), findsOneWidget);
  });

  testWidgets('filters split the journal by review state', (tester) async {
    await tester.pumpWidget(wrap([record()]));
    await tester.pump();

    expect(find.textContaining('全部（1）'), findsOneWidget);
    expect(find.textContaining('已回填（0）'), findsOneWidget);

    await tester.tap(find.textContaining('已回填（0）'));
    await tester.pump();
    expect(find.text('此分类下暂无案例'), findsOneWidget);
  });

  group('detail page — filling in what actually happened', () {
    Widget wrapDetail(FakeCaseStore store) => ProviderScope(
          overrides: [caseRepositoryProvider.overrideWithValue(store)],
          child: const MaterialApp(home: CaseDetailPage(caseId: 'c1')),
        );

    testWidgets('claims are grouped, and the guardrail is stated to the user',
        (tester) async {
      final store = FakeCaseStore([
        record(claims: const [
          PredictedClaim(
            id: 'structure',
            kind: ClaimKind.structure,
            title: '正官格·破而有救',
            detail: '用神月令癸正官',
          ),
          PredictedClaim(
            id: 'event_0',
            kind: ClaimKind.event,
            title: '事业·职务变动',
            detail: '流年冲提纲',
          ),
        ])
      ]);
      await tester.pumpWidget(wrapDetail(store));
      await tester.pump();

      expect(find.text('格局判定'), findsOneWidget);
      expect(find.text('事件预测'), findsOneWidget);
      expect(find.text('正官格·破而有救'), findsOneWidget);
      expect(find.text('事业·职务变动'), findsOneWidget);
      // The engine-never-learns promise is shown, not only enforced in code.
      expect(find.textContaining('不会自动修改命理规则或权重'), findsOneWidget);
    });

    testWidgets('marking a verdict reveals save, and persists it',
        (tester) async {
      final store = FakeCaseStore([record()]);
      await tester.pumpWidget(wrapDetail(store));
      await tester.pump();

      // Nothing to save until something is changed.
      expect(find.text('保存回填'), findsNothing);

      await tester.tap(find.text('应验').first);
      await tester.pump();
      expect(find.text('保存回填'), findsOneWidget);

      // The FAB scales in, and is wrapped in an IgnorePointer until that
      // animation finishes — tapping before it settles hits nothing.
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存回填'));
      await tester.pump();
      await tester.pump();

      final saved = store.items['c1']!;
      expect(saved.claims.single.verdict, ClaimVerdict.hit);
      expect(saved.reviewedCount, 1);
      expect(saved.hitRate, 1.0);
      expect(saved.lastReviewedAt, isNotNull);
    });

    testWidgets('a missing case degrades gracefully', (tester) async {
      await tester.pumpWidget(wrapDetail(FakeCaseStore(const [])));
      await tester.pump();
      expect(find.text('案例不存在或已删除'), findsOneWidget);
    });
  });
}


/// In-memory [CaseStore] for widget tests.
class FakeCaseStore implements CaseStore {
  final Map<String, CaseRecord> items;

  FakeCaseStore(List<CaseRecord> seed)
      : items = {for (final c in seed) c.id: c};

  @override
  Future<List<CaseRecord>> all() async => items.values.toList();

  @override
  Stream<List<CaseRecord>> watchAll() => Stream.value(items.values.toList());

  @override
  Future<CaseRecord?> byId(String id) async => items[id];

  @override
  Future<void> save(CaseRecord record) async => items[record.id] = record;

  @override
  Future<void> delete(String id) async => items.remove(id);

  @override
  Future<CaseRecord?> findExisting({
    required String baziString,
    required Gender gender,
    required String scopeLabel,
  }) async =>
      items.values
          .where((c) =>
              c.baziString == baziString &&
              c.input.gender == gender &&
              c.scopeLabel == scopeLabel)
          .firstOrNull;

  @override
  Future<List<CaseRecord>> due([DateTime? now]) async => [
        for (final c in items.values)
          if (c.isDue(now)) c,
      ];

  @override
  Future<String> exportJson() async => '{}';
}
