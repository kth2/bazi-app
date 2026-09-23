import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/cases/case_record.dart';
import 'package:bazi_app/core/cases/case_statistics.dart';
import 'package:bazi_app/core/cases/choice_question.dart';
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

PredictedClaim qa(
  String question,
  String answer, {
  ClaimVerdict verdict = ClaimVerdict.unverified,
  OptionLean? lean,
  String? id,
}) =>
    PredictedClaim(
      id: id ?? CaseRecord.qaIdFor(question),
      kind: ClaimKind.qa,
      title: question,
      detail: answer,
      verdict: verdict,
      leanOverride: lean,
    );

CaseRecord record(List<PredictedClaim> claims,
        {int engineVersion = 11, String id = 'c'}) =>
    CaseRecord(
      id: id,
      title: 't',
      input: _input,
      baziString: '甲子 乙丑 丙寅 丁卯',
      scopeLabel: '整体命局',
      engineVersion: engineVersion,
      structureSummary: '',
      claims: claims,
      createdAt: DateTime(2026),
    );

/// A two-way 层次 question answered one way or the other.
PredictedClaim levelQ(int i, {required bool brighter, required bool hit}) =>
    qa(
      '看看此造层次如何 #$i\nA 年薪百万\nB 月薪4000元',
      brighter ? '答案：A 年薪百万' : '答案：第B项',
      verdict: hit ? ClaimVerdict.hit : ClaimVerdict.miss,
    );

void main() {
  group('reading the question', () {
    // Formats taken from questions actually put to the app.
    final cases = <(String, String, OptionLean, QuestionTopic)>[
      ('A 庚寅年破财\nB 庚寅年发财', '答案：A 庚寅年破财  一、命局根基…',
          OptionLean.plainer, QuestionTopic.yearFortune),
      ('A戊戌年破财\nB戊戌年发财', '答案：B戊戌年发财', OptionLean.brighter,
          QuestionTopic.yearFortune),
      ('A 壬辰年凶\t\nB 壬辰年吉', '答案：A 壬辰年凶', OptionLean.plainer,
          QuestionTopic.yearFortune),
      ('看看此造层次如何\nA 富有一个亿\nB 小康生活', '答案：第B项（小康生活）',
          OptionLean.plainer, QuestionTopic.level),
      ('以下哪个选项更符合实际情况:\nA、普通人 B、顶级富豪', '答案：第A项（普通人）',
          OptionLean.plainer, QuestionTopic.level),
      ('以下哪个选项更符合实际情况:\nA、4S店经理\nB、身家过亿',
          '答案：选项A（4S店经理）更符合实际情况。', OptionLean.plainer,
          QuestionTopic.level),
      ('以下哪个选项更符合实际情况:\nA、2020年网络直播发财\nB、2020年老婆出轨',
          '**答案：B项更符合实际情况**', OptionLean.plainer, QuestionTopic.event),
      ('以下哪个选项更符合实际情况:\nA、2025年彩票中奖一百万\nB,2025年车祸砸到头',
          '答案：B', OptionLean.plainer, QuestionTopic.level),
      ('A丙午运，嫁富二代\nB丙午运，没嫁成富二代', '答案：B丙午运，没嫁成富二代。',
          OptionLean.plainer, QuestionTopic.level),
      ('A、犯罪分子\nB、风流少爷', '**答案：第B项（风流少爷）**',
          OptionLean.brighter, QuestionTopic.event),
      ('A 甲辰年，升职\nB 甲辰年，降职', '答案：A 甲辰年，升职',
          OptionLean.brighter, QuestionTopic.event),
      ('A 富有5000多W\nB 常人层次', '答案：B 常人层次', OptionLean.plainer,
          QuestionTopic.level),
      ('A 年薪百万\nB 工作不稳定', '**答案：第A项**', OptionLean.brighter,
          QuestionTopic.level),
    ];

    for (final (q, a, lean, topic) in cases) {
      test(q.replaceAll(RegExp(r'\s+'), ' '), () {
        final r = ChoiceQuestion.read(q, a);
        expect(r, isNotNull);
        expect(r!.lean, lean);
        expect(r.topic, topic);
      });
    }

    test('negations are read before the word they negate', () {
      expect(ChoiceQuestion.scoreOf('工作不稳定'), lessThan(0));
      expect(ChoiceQuestion.scoreOf('没嫁成富二代'),
          lessThan(ChoiceQuestion.scoreOf('嫁富二代')));
    });

    test('options that do not differ in fortune have no lean', () {
      final r = ChoiceQuestion.read(
          'A、中学教师，一婚稳定\nB、经商过亿，有小三小四', '**答案：第B项更符合实际。**');
      expect(r!.lean, OptionLean.none);
    });

    test('no reading without exactly two options and one committed pick', () {
      // Open question.
      expect(ChoiceQuestion.read('乙未年破财还是发财？', '答案：破财可能性更高'), isNull);
      // Three options.
      expect(
          ChoiceQuestion.read('A、赌博负债百万\nB、小学英语教师\nC、开厂千万身价',
              '**答案：第B项**'),
          isNull);
      // Two questions in one, so letters repeat.
      expect(
          ChoiceQuestion.read(
              '1.职业？\nA. 教师 B. 老板\n2. 2026年？\nA.吉 B. 凶', '答案：第A项'),
          isNull);
      // Hedged answer with no letter after 答案.
      expect(
          ChoiceQuestion.read('A 庚寅运，嫁贵夫。\nB庚寅运，判处死刑。',
              '答案：两项皆不成立，但若必须二选一，B选项稍近命局之势'),
          isNull);
      // Two different letters committed to.
      expect(ChoiceQuestion.read('A 吉\nB 凶', '答案：A …… 答案：B'), isNull);
    });
  });

  group('lean on a claim', () {
    test('is read from the text when not set, and the setting wins', () {
      final c = qa('A 己亥年破财\nB 己亥年发财', '答案：A 己亥年破财');
      expect(c.lean, OptionLean.plainer);
      expect(c.leanIsInferred, isTrue);

      final set = c.copyWith(leanOverride: OptionLean.brighter);
      expect(set.lean, OptionLean.brighter);
      expect(set.leanIsInferred, isFalse);
      expect(set.copyWith(clearLeanOverride: true).lean, OptionLean.plainer);
    });

    test('survives a JSON round trip, and old records read as unset', () {
      final c = qa('看这八字咋样？', '……', lean: OptionLean.plainer);
      final back = PredictedClaim.fromJson(c.toJson());
      expect(back.leanOverride, OptionLean.plainer);

      final old = c.toJson()..remove('lean');
      expect(PredictedClaim.fromJson(old).leanOverride, isNull);
      // An unknown name from a future build is ignored, not a crash.
      expect(
          PredictedClaim.fromJson({...c.toJson(), 'lean': 'sideways'})
              .leanOverride,
          isNull);
    });

    test('never applies to engine claims', () {
      const c = PredictedClaim(
          id: 'e', kind: ClaimKind.event, title: 'A 破财 B 发财', detail: '答案：A');
      expect(c.lean, OptionLean.none);
    });
  });

  group('ChoiceBias', () {
    test('a pessimistic reader looks accurate on pessimistic questions', () {
      // The shape of the journal before the pessimism fix: plainer almost
      // every time, 58% hit, and still below always-plainer.
      final claims = [
        for (var i = 0; i < 18; i++) levelQ(i, brighter: false, hit: true),
        for (var i = 18; i < 29; i++) levelQ(i, brighter: false, hit: false),
        for (var i = 29; i < 31; i++) levelQ(i, brighter: true, hit: false),
      ];
      final c = CaseStatistics.of([record(claims)]).choice;

      expect(c.n, 31);
      expect(c.hits, 18);
      expect(c.pickedBrighter, 2);
      expect(c.truthBrighter, 11);
      expect(c.baseline, closeTo(20 / 31, 1e-9));
      expect(c.rate!, lessThan(c.baseline!));
      expect(c.optimisticMisses, 2);
      expect(c.pessimisticMisses, 11);
    });

    test('an optimistic reader scores exactly its no-skill expectation', () {
      final claims = [
        levelQ(0, brighter: true, hit: true),
        for (var i = 1; i < 6; i++) levelQ(i, brighter: true, hit: false),
      ];
      final c = CaseStatistics.of([record(claims, engineVersion: 10)]).choice;
      expect(c.rate, closeTo(1 / 6, 1e-9));
      expect(c.noSkillExpected, closeTo(1 / 6, 1e-9));
      expect(c.baseline, closeTo(5 / 6, 1e-9));
    });

    test('partial and unclear verdicts are left out', () {
      final claims = [
        levelQ(0, brighter: true, hit: true),
        qa('A 年薪百万\nB 月薪4000元', '答案：第B项',
            verdict: ClaimVerdict.partial, id: 'p'),
        qa('A 年薪百万\nB 月薪4000元', '答案：第B项',
            verdict: ClaimVerdict.unclear, id: 'u'),
      ];
      expect(CaseStatistics.of([record(claims)]).choice.n, 1);
    });

    test('is kept per engine version and per topic', () {
      final stats = CaseStatistics.of([
        record([levelQ(0, brighter: true, hit: false)],
            engineVersion: 10, id: 'a'),
        record([
          levelQ(1, brighter: false, hit: true),
          qa('A 壬寅年凶\nB 壬寅年吉', '答案：A 壬寅年凶', verdict: ClaimVerdict.miss),
        ], engineVersion: 11, id: 'b'),
      ]);
      expect(stats.choiceByVersion[10]!.pickedBrighter, 1);
      expect(stats.choiceByVersion[11]!.n, 2);
      expect(stats.choiceByTopic[QuestionTopic.level]!.n, 2);
      expect(stats.choiceByTopic[QuestionTopic.yearFortune]!.pessimisticMisses,
          1);
    });

    test('Wilson interval stays inside 0..1 on small samples', () {
      final (lo, hi) = wilson95(2, 7)!;
      expect(lo, greaterThan(0));
      expect(hi, lessThan(1));
      expect(lo, closeTo(0.082, 0.01));
      expect(hi, closeTo(0.641, 0.01));
      expect(wilson95(0, 0), isNull);
    });
  });

  group('stats page', () {
    Widget wrap(List<CaseRecord> cases) => ProviderScope(
          overrides: [
            caseListProvider.overrideWith((ref) => Stream.value(cases)),
          ],
          child: const MaterialApp(home: CaseStatsPage()),
        );

    testWidgets('sets the A/B rate beside the never-look baseline',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 2400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap([
        record([
          for (var i = 0; i < 6; i++) levelQ(i, brighter: false, hit: true),
          for (var i = 6; i < 10; i++) levelQ(i, brighter: false, hit: false),
        ]),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('选择题：和不看命盘比'), findsOneWidget);
      expect(find.textContaining('6/10 = 60%'), findsOneWidget);
      expect(find.text('对照：永远选较平一项'), findsOneWidget);
      // 6 of 10 real outcomes were plainer: 60% is not a win.
      expect(find.textContaining('还没有跑赢'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is absent when no question reads as a two-way choice',
        (tester) async {
      await tester.pumpWidget(wrap([
        record([
          qa('看这八字咋样？', '……', verdict: ClaimVerdict.hit),
        ]),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('选择题：和不看命盘比'), findsNothing);
    });
  });
}
