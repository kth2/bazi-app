import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/analysis/reasoning_report.dart';
import 'package:bazi_app/core/cases/case_export.dart';
import 'package:bazi_app/core/cases/case_record.dart';
import 'package:bazi_app/core/cases/cases_db.dart';
import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/models/birth_input.dart';
import 'package:bazi_app/core/rules/rule.dart';

List<Rule> loadSeedRules() {
  final json = jsonDecode(
      File('assets/rules/seed_rules.json').readAsStringSync()) as Map;
  return [
    for (final r in json['rules'] as List)
      Rule.fromJson(r as Map<String, dynamic>),
  ];
}

final chart = ChartService.compute(BirthInput(
  calendarType: CalendarType.solar,
  year: 1990,
  month: 1,
  day: 1,
  hour: 12,
  minute: 0,
  gender: Gender.male,
  location: '北京',
  longitude: 116.41,
));

void main() {
  _filenameTests();
  final rules = loadSeedRules();

  final decade = chart.decades
      .firstWhere((d) => d.startYear <= 2026 && d.endYear >= 2026);
  final year = ChartService.flowYearsOf(chart, decade)
      .firstWhere((y) => y.year == 2026);

  ReasoningReport yearReport() =>
      ReasoningReport.build(chart, rules, decade: decade, year: year);

  CaseRecord newCase({String id = 'c1', DateTime? createdAt}) {
    final report = yearReport();
    return CaseRecord.fromReport(
      report,
      id: id,
      title: '测试案例',
      scopeLabel: '流年 2026 丙午',
      engineVersion: 3,
      aiText: '批文正文',
      createdAt: createdAt ?? DateTime(2026, 3, 1),
      reviewDueAt: CaseRecord.scopeEndOf(report.context),
    );
  }

  group('a case snapshots checkable claims, not just prose', () {
    test('claims cover 格局, events and 应期 windows', () {
      final c = newCase();
      final kinds = {for (final k in c.claims) k.kind};
      expect(kinds, contains(ClaimKind.structure));
      expect(kinds, contains(ClaimKind.event));
      expect(kinds, contains(ClaimKind.yingQi));

      // Every claim is individually addressable and carries its basis.
      final ids = c.claims.map((k) => k.id).toList();
      expect(ids.length, ids.toSet().length);
      for (final k in c.claims) {
        expect(k.title, isNotEmpty);
        expect(k.detail, isNotEmpty);
      }
      // 应期 claims carry the concrete window they predicted.
      final window =
          c.claims.firstWhere((k) => k.kind == ClaimKind.yingQi);
      expect(window.windowStart, isNotNull);
      expect(window.windowEnd, isNotNull);
    });

    test('the engine version that made the claims is recorded', () {
      expect(newCase().engineVersion, 3);
    });

    test('review comes due at the end of the analysed period', () {
      final c = newCase();
      // 流年 2026 runs 立春 to 立春, so it is checkable from early 2027.
      expect(c.reviewDueAt!.year, 2027);
      expect(c.isDue(DateTime(2026, 6, 1)), isFalse);
      expect(c.isDue(DateTime(2027, 3, 1)), isTrue);
    });

    test('a whole-life reading never comes due', () {
      final report = ReasoningReport.build(chart, rules);
      expect(CaseRecord.scopeEndOf(report.context), isNull);
      final c = CaseRecord.fromReport(
        report,
        id: 'life',
        title: '终身',
        scopeLabel: '整体命局',
        engineVersion: 3,
        reviewDueAt: CaseRecord.scopeEndOf(report.context),
      );
      expect(c.isDue(DateTime(2099)), isFalse);
      expect(c.status(DateTime(2099)), CaseStatus.pending);
    });
  });

  group('the AI Q&A conversation is recorded as checkable claims', () {
    const q1 = '甲辰年最可能发生哪件事？1读博毕业 2感情重挫 3官非牢狱';
    const a1 = '答案：第1项。原局印星有力，流年引动文书之气…';
    const q2 = '今年适合换工作吗？';
    const a2 = '流年冲提纲，主职务变动，宜守不宜攻。';

    CaseRecord withQa() {
      final report = yearReport();
      return CaseRecord.fromReport(
        report,
        id: 'c1',
        title: '测试案例',
        scopeLabel: '流年 2026 丙午',
        engineVersion: 3,
        createdAt: DateTime(2026, 3, 1),
        reviewDueAt: CaseRecord.scopeEndOf(report.context),
        qa: const [(q1, a1), (q2, a2)],
      );
    }

    test('questions and answers are both stored, in order asked', () {
      final qa =
          withQa().claims.where((c) => c.kind == ClaimKind.qa).toList();
      expect(qa.length, 2);
      expect(qa[0].title, q1);
      expect(qa[0].detail, a1);
      expect(qa[1].title, q2);
      expect(qa[1].detail, a2);
    });

    test('each question is verifiable like any other claim', () {
      var c = withQa();
      final qaClaim = c.claims.firstWhere((k) => k.kind == ClaimKind.qa);
      expect(qaClaim.verdict, ClaimVerdict.unverified);

      c = c.copyWith(claims: [
        for (final k in c.claims)
          k.id == qaClaim.id
              ? k.copyWith(verdict: ClaimVerdict.hit, note: '确实毕业了')
              : k,
      ]);
      final saved = c.claims.firstWhere((k) => k.id == qaClaim.id);
      expect(saved.verdict, ClaimVerdict.hit);
      expect(saved.note, '确实毕业了');
      expect(c.hitRate, 1.0);
    });

    test('question ids are stable across processes', () {
      // Persisted, so they cannot depend on String.hashCode.
      expect(CaseRecord.qaIdFor(q1), CaseRecord.qaIdFor(q1));
      expect(CaseRecord.qaIdFor(q1), isNot(CaseRecord.qaIdFor(q2)));
      // Surrounding whitespace must not fork the identity.
      expect(CaseRecord.qaIdFor('  $q1  '), CaseRecord.qaIdFor(q1));
    });

    test('merging adds only genuinely new questions', () {
      final c = withQa();
      expect(c.newQaCount(const [(q1, a1), (q2, a2)]), 0);
      expect(c.newQaCount(const [(q1, a1), ('第三个问题？', '答')]), 1);

      final merged = c.withQa(const [(q1, a1), ('第三个问题？', '答')]);
      expect(merged.claims.length, c.claims.length + 1);
      expect(
        merged.claims.where((k) => k.kind == ClaimKind.qa).map((k) => k.title),
        containsAll([q1, q2, '第三个问题？']),
      );
    });

    test('merging never discards a verdict already filled in', () {
      // Questions get asked after a case is saved, so a repeat save merges.
      // That must not reset review work on the questions already there.
      var c = withQa();
      final first = c.claims.firstWhere((k) => k.kind == ClaimKind.qa);
      c = c.copyWith(claims: [
        for (final k in c.claims)
          k.id == first.id
              ? k.copyWith(verdict: ClaimVerdict.partial, note: '部分说中')
              : k,
      ]);

      final merged = c.withQa(const [(q1, '一个不同的答案'), ('新问题？', '新答案')]);
      final kept = merged.claims.firstWhere((k) => k.id == first.id);
      expect(kept.verdict, ClaimVerdict.partial);
      expect(kept.note, '部分说中');
      // The original answer is preserved rather than overwritten.
      expect(kept.detail, a1);
      expect(merged.claims.any((k) => k.title == '新问题？'), isTrue);
    });

    test('empty questions are ignored', () {
      final c = withQa();
      expect(c.withQa(const [('', 'x'), ('   ', 'y')]).claims.length,
          c.claims.length);
    });

    test('Q&A survives a database round-trip', () async {
      final db = CasesDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CaseRepository(db);
      await repo.save(withQa());

      final loaded = (await repo.byId('c1'))!;
      final qa =
          loaded.claims.where((k) => k.kind == ClaimKind.qa).toList();
      expect(qa.length, 2);
      expect(qa.first.title, q1);
      expect(qa.first.detail, a1);
    });
  });

  group('status tracks the review cycle', () {
    test('pending → awaiting → partial → reviewed', () {
      var c = newCase();
      expect(c.status(DateTime(2026, 6, 1)), CaseStatus.pending);
      expect(c.status(DateTime(2027, 3, 1)), CaseStatus.awaitingReview);

      c = c.copyWith(claims: [
        c.claims.first.copyWith(verdict: ClaimVerdict.hit),
        ...c.claims.skip(1),
      ]);
      expect(c.status(DateTime(2027, 3, 1)), CaseStatus.partiallyReviewed);

      c = c.copyWith(claims: [
        for (final k in c.claims) k.copyWith(verdict: ClaimVerdict.hit),
      ]);
      expect(c.status(DateTime(2027, 3, 1)), CaseStatus.reviewed);
    });

    test('hit rate is null until something scorable is filled in', () {
      var c = newCase();
      expect(c.hitRate, isNull);

      // 无法判断 is not a miss — it stays out of the denominator.
      c = c.copyWith(claims: [
        for (final k in c.claims) k.copyWith(verdict: ClaimVerdict.unclear),
      ]);
      expect(c.hitRate, isNull);

      c = c.copyWith(claims: [
        c.claims[0].copyWith(verdict: ClaimVerdict.hit),
        c.claims[1].copyWith(verdict: ClaimVerdict.miss),
        c.claims[2].copyWith(verdict: ClaimVerdict.partial),
        ...c.claims.skip(3).map((k) => k.copyWith(verdict: ClaimVerdict.unclear)),
      ]);
      // hit 1.0 + miss 0 + partial 0.5, over 3 scorable claims.
      expect(c.hitRate, closeTo(0.5, 1e-9));
    });
  });

  group('应期 accuracy is checked against the predicted window', () {
    test('an actual date inside/outside the window is reported', () {
      final c = newCase();
      final w = c.claims.firstWhere((k) => k.kind == ClaimKind.yingQi);
      expect(w.landedInWindow, isNull, reason: 'no actual date yet');

      final inside = w.copyWith(
          actualDate: w.windowStart!.add(const Duration(days: 1)));
      expect(inside.landedInWindow, isTrue);

      final outside = w.copyWith(
          actualDate: w.windowEnd!.add(const Duration(days: 40)));
      expect(outside.landedInWindow, isFalse);
    });

    test('window boundaries are inclusive by day', () {
      final c = newCase();
      final w = c.claims.firstWhere((k) => k.kind == ClaimKind.yingQi);
      expect(w.copyWith(actualDate: w.windowStart).landedInWindow, isTrue);
      expect(w.copyWith(actualDate: w.windowEnd).landedInWindow, isTrue);
    });
  });

  group('persistence', () {
    late CasesDatabase db;
    late CaseRepository repo;

    setUp(() {
      db = CasesDatabase.forTesting(NativeDatabase.memory());
      repo = CaseRepository(db);
    });

    tearDown(() => db.close());

    test('round-trips through the database intact', () async {
      final original = newCase().copyWith(
        claims: [
          newCase().claims.first.copyWith(
                verdict: ClaimVerdict.partial,
                note: '确有职务调整，但在四月',
                actualDate: DateTime(2026, 4, 12),
              ),
          ...newCase().claims.skip(1),
        ],
        outcomeNote: '整体尚可',
      );
      await repo.save(original);

      final loaded = (await repo.byId('c1'))!;
      expect(loaded.baziString, original.baziString);
      expect(loaded.scopeLabel, original.scopeLabel);
      expect(loaded.engineVersion, 3);
      expect(loaded.input.gender, Gender.male);
      expect(loaded.aiText, '批文正文');
      expect(loaded.outcomeNote, '整体尚可');
      expect(loaded.claims.length, original.claims.length);
      expect(loaded.claims.first.verdict, ClaimVerdict.partial);
      expect(loaded.claims.first.note, '确有职务调整，但在四月');
      expect(loaded.claims.first.actualDate, DateTime(2026, 4, 12));
      expect(loaded.reviewDueAt, original.reviewDueAt);
    });

    test('saving the same id updates rather than duplicating', () async {
      await repo.save(newCase());
      await repo.save(newCase().copyWith(outcomeNote: '改过了'));
      final all = await repo.all();
      expect(all.length, 1);
      expect(all.first.outcomeNote, '改过了');
    });

    test('findExisting matches on chart, gender and scope', () async {
      await repo.save(newCase());
      expect(
        await repo.findExisting(
            baziString: chart.baziString,
            gender: Gender.male,
            scopeLabel: '流年 2026 丙午'),
        isNotNull,
      );
      // Same chart, different scope → a separate case.
      expect(
        await repo.findExisting(
            baziString: chart.baziString,
            gender: Gender.male,
            scopeLabel: '流年 2027 丁未'),
        isNull,
      );
      // Same pillars, different gender → a different person.
      expect(
        await repo.findExisting(
            baziString: chart.baziString,
            gender: Gender.female,
            scopeLabel: '流年 2026 丙午'),
        isNull,
      );
    });

    test('due() returns only cases whose period has elapsed', () async {
      await repo.save(newCase(id: 'c1'));
      expect(await repo.due(DateTime(2026, 6, 1)), isEmpty);
      expect((await repo.due(DateTime(2027, 3, 1))).map((c) => c.id), ['c1']);
    });

    test('delete removes the case', () async {
      await repo.save(newCase());
      await repo.delete('c1');
      expect(await repo.all(), isEmpty);
    });

    test('a single case exports in the same envelope as the whole journal',
        () async {
      await repo.save(newCase(id: 'c1'));
      await repo.save(newCase(id: 'c2'));

      final whole =
          jsonDecode(await repo.exportJson()) as Map<String, dynamic>;
      final single = jsonDecode(
              CaseRecord.encodeExport([(await repo.byId('c1'))!]))
          as Map<String, dynamic>;

      // Same shape, so anything reading one can read the other.
      expect(single.keys.toSet(), whole.keys.toSet());
      expect(whole['format'], 'bazi-app.cases');
      expect(single['format'], 'bazi-app.cases');
      expect(whole['count'], 2);
      expect(single['count'], 1);
      expect(
        CaseRecord.fromJson(
                (single['cases'] as List).first as Map<String, dynamic>)
            .id,
        'c1',
      );
    });

    test('export writes an actual file that parses back', () async {
      await repo.save(newCase());
      final name = CaseExport.filenameFor(DateTime(2026, 8, 14, 15, 30));
      final message = await CaseExport.save(name, await repo.exportJson());

      // The non-web implementation reports where it wrote.
      expect(message, contains(name));
      final path = message.split(' ').last;
      final file = File(path);
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });
      expect(file.existsSync(), isTrue);

      final decoded =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(decoded['count'], 1);
      expect(
        CaseRecord.fromJson(
                (decoded['cases'] as List).first as Map<String, dynamic>)
            .baziString,
        chart.baziString,
      );
    });

    test('export produces re-importable JSON', () async {
      await repo.save(newCase());
      final raw = await repo.exportJson();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['count'], 1);
      final restored =
          CaseRecord.fromJson((decoded['cases'] as List).first as Map<String, dynamic>);
      expect(restored.id, 'c1');
      expect(restored.claims.length, newCase().claims.length);
      expect(restored.input.longitude, closeTo(116.41, 1e-9));
    });
  });
}

/// Filenames end up in a downloads folder and in shared messages, so they
/// need to be sortable and free of characters a filesystem will object to.
void _filenameTests() {
  group('export filenames', () {
    test('journal filename is sortable and timestamped', () {
      expect(
        CaseExport.filenameFor(DateTime(2026, 8, 14, 15, 30)),
        'bazi_cases_2026-08-14_1530.json',
      );
      // Zero-padded, so lexical order matches chronological order.
      expect(
        CaseExport.filenameFor(DateTime(2026, 1, 2, 3, 4)),
        'bazi_cases_2026-01-02_0304.json',
      );
    });

    test('single-case filename carries the 八字 without spaces', () {
      final name = CaseExport.filenameForCase(
          '己巳 丙子 丙寅 甲午', DateTime(2026, 8, 14));
      expect(name, 'bazi_case_己巳丙子丙寅甲午_2026-08-14.json');
      expect(name, isNot(contains(' ')));
    });
  });
}
