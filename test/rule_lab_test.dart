import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bazi_app/core/analysis/analysis_example.dart';
import 'package:bazi_app/core/analysis/analysis_prompt.dart';
import 'package:bazi_app/core/analysis/example_repository.dart';
import 'package:bazi_app/core/analysis/reasoning_report.dart';
import 'package:bazi_app/core/cases/case_record.dart';
import 'package:bazi_app/core/cases/rule_lab.dart';
import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/models/birth_input.dart';
import 'package:bazi_app/core/rules/custom_rules.dart';
import 'package:bazi_app/features/cases/rule_lab_page.dart';
import 'package:bazi_app/providers/ai_provider.dart';
import 'package:bazi_app/providers/analysis_provider.dart';
import 'package:bazi_app/providers/case_provider.dart';
import 'package:bazi_app/services/ai_service.dart';

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

CaseRecord caseWith(String id, List<PredictedClaim> claims,
        {String outcome = '', int minutes = 0}) =>
    CaseRecord(
      id: id,
      title: id,
      input: _input,
      baziString: '己巳 丙子 丙寅 甲午',
      scopeLabel: '整体命局',
      engineVersion: 12,
      structureSummary: '格局：正官格',
      claims: claims,
      outcomeNote: outcome,
      createdAt: DateTime(2026, 9, 1).add(Duration(minutes: minutes)),
    );

PredictedClaim ab(String q, String pick, ClaimVerdict v, {String note = ''}) =>
    PredictedClaim(
      id: CaseRecord.qaIdFor(q),
      kind: ClaimKind.qa,
      title: q,
      detail: '答案：$pick',
      verdict: v,
      note: note,
    );

/// Answers A unless the prompt carries a custom 条例 mentioning 「选B」.
class FakeAi extends AiService {
  int calls = 0;
  final String Function(String prompt) reply;
  FakeAi(this.reply);

  @override
  Future<String> complete(String prompt, AiSettings settings,
      {double? temperature}) async {
    calls++;
    return reply(prompt);
  }
}

List<AnalysisExample> _examples() => [
      for (final e in jsonDecode(
              File('assets/examples/analysis_examples.json').readAsStringSync())
          as List)
        AnalysisExample.fromJson(e as Map<String, dynamic>),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RuleLab.scorable / misses', () {
    test('truth is the pick when right, the other option when wrong', () {
      final cases = [
        caseWith('a', [ab('A 庚寅年破财\nB 庚寅年发财', 'A', ClaimVerdict.hit)]),
        caseWith('b', [ab('A 年薪百万\nB 月薪4000元', 'A', ClaimVerdict.miss)],
            minutes: 1),
      ];
      final s = RuleLab.scorable(cases);
      expect(s.map((q) => q.truth), ['B', 'A']); // newest first
    });

    test('only wrong answers that carry feedback can be learned from', () {
      final cases = [
        caseWith('a', [ab('A 吉\nB 凶', 'A', ClaimVerdict.miss)]),
        caseWith('b', [ab('A 吉\nB 凶', 'A', ClaimVerdict.miss, note: '答案是B')]),
        caseWith('c', [ab('A 吉\nB 凶', 'A', ClaimVerdict.miss)],
            outcome: '当年破产'),
        caseWith('d', [ab('A 吉\nB 凶', 'A', ClaimVerdict.hit, note: '准')]),
      ];
      expect(RuleLab.misses(cases).map((m) => m.record.id).toSet(),
          {'b', 'c'});
    });
  });

  group('反推 prompt and proposals', () {
    final misses = [
      MissCase(
          caseWith('x', [], outcome: '戊午运败落'),
          ab('看看此造戊午运如何\nA 发达\nB 败落', 'A', ClaimVerdict.miss,
              note: '反馈：财印不宜相并')),
      MissCase(caseWith('y', []),
          ab('A 厅级\nB 常人', 'B', ClaimVerdict.miss, note: '答案是A')),
    ];

    test('the prompt carries the case, today\'s structure and the feedback',
        () {
      final p = RuleLab.reversePrompt(
          misses, ['格局：正财格；成败：破格', '格局：偏印格'], ['旧条例：……']);
      expect(p, contains('【案例1】命造：己巳 丙子 丙寅 甲午'));
      expect(p, contains('引擎推演：格局：正财格；成败：破格'));
      expect(p, contains('财印不宜相并'));
      expect(p, contains('【现行自定义条例】'));
      // The guard against a statistical 条例.
      expect(p, contains('不得是「多选平常一项」'));
      expect(p, contains('```json'));
    });

    test('a fenced JSON block becomes proposals holding out their cases', () {
      const answer = '逐案分析……\n```json\n[{"title": "财印相并", '
          '"text": "财格佩印而财印紧贴则破格", "source": "《子平真诠》", '
          '"rationale": "解释案例1", "explains": [1]}]\n```';
      final rules = RuleLab.parseProposals(answer, misses);
      expect(rules, hasLength(1));
      expect(rules.single.title, '财印相并');
      expect(rules.single.source, '《子平真诠》');
      expect(rules.single.derivedFrom, ['x']);
      expect(rules.single.active, isFalse);
    });

    test('without explains, every case used is held out', () {
      const answer = '[{"title": "t", "text": "x"}]';
      expect(RuleLab.parseProposals(answer, misses).single.derivedFrom,
          ['x', 'y']);
    });

    test('garbage yields no proposals, not an exception', () {
      expect(RuleLab.parseProposals('没有条例', misses), isEmpty);
      expect(RuleLab.parseProposals('```json\n[{oops\n```', misses), isEmpty);
      expect(RuleLab.parseProposals('[{"title": ""}]', misses), isEmpty);
    });
  });

  group('McNemar', () {
    test('matches the binomial tail', () {
      expect(mcNemarExact(0, 0), 1);
      expect(mcNemarExact(5, 0), closeTo(0.0625, 1e-9));
      expect(mcNemarExact(6, 0), closeTo(0.03125, 1e-9));
      expect(mcNemarExact(3, 1), closeTo(0.625, 1e-9));
    });
  });

  group('CustomRuleSet', () {
    final rule = CustomRule(
        id: 'r1', title: 't', text: 'x', createdAt: DateTime(2026));
    final result = BacktestSummary(
        n: 10,
        baselineHits: 5,
        candidateHits: 7,
        fixed: 3,
        broken: 1,
        at: DateTime(2026));

    test('adopting needs a result and moves the revision', () {
      final set = CustomRuleSet.empty.adopt(rule, result);
      expect(set.revision, 1);
      expect(set.active.single.backtest!.candidateHits, 7);
      final off = set.setActive('r1', false);
      expect(off.revision, 2);
      expect(off.active, isEmpty);
      expect(off.rules, hasLength(1)); // kept, not deleted
    });

    test('a candidate is added only for the comparison', () {
      final set = CustomRuleSet.empty.withCandidate(rule);
      expect(set.promptLines.single, contains('t：x'));
      expect(CustomRuleSet.empty.rules, isEmpty);
    });

    test('round-trips through JSON', () {
      final set = CustomRuleSet.empty.adopt(rule, result);
      final back = CustomRuleSet.fromJson(
          jsonDecode(jsonEncode(set.toJson())) as Map<String, dynamic>);
      expect(back.revision, 1);
      expect(back.active.single.backtest!.fixed, 3);
    });
  });

  test('adopted 条例 reach the prompt, and may override the chain by name',
      () {
    final chart = ChartService.compute(_input);
    final report = ReasoningReport.build(chart, const []);
    final prompt = AnalysisPrompt.buildCustom(
      report: report,
      examples: const [],
      question: 'A 吉\nB 凶',
      customRules: ['财印相并：财格佩印而财印紧贴则破格（出处：《子平真诠》）'],
    );
    expect(prompt, contains('【自定义条例'));
    expect(prompt, contains('1. 财印相并'));
    expect(prompt, contains('依自定义条例第N条'));
    final plain = AnalysisPrompt.buildCustom(
        report: report, examples: const [], question: 'A 吉\nB 凶');
    expect(plain, isNot(contains('【自定义条例')));
  });

  group('Backtester', () {
    late ExampleRepository repo;
    setUp(() {
      SharedPreferences.setMockInitialValues({'ai_key_gemini': 'k'});
      repo = ExampleRepository()..seedForTesting(_examples());
    });

    List<CaseRecord> journal() => [
          for (var i = 0; i < 10; i++)
            caseWith('c$i', [
              // Truth is B for all ten.
              ab('A 年薪百万 #$i\nB 月薪4000元', 'A', ClaimVerdict.miss),
            ], minutes: i),
        ];

    test('scores both arms, counts fixes, and caches the baseline', () async {
      final ai = FakeAi((p) => p.contains('选B') ? '答案：B' : '答案：A');
      final settings = await AiSettings.load();
      final tester = Backtester(
        ai: ai,
        settings: settings,
        examples: repo,
        rules: const [],
        pause: Duration.zero,
      );
      final candidate = CustomRule(
          id: 'c', title: '平常', text: '选B', createdAt: DateTime(2026));
      final qs = RuleLab.scorable(journal());

      final o = await tester.run(
          questions: qs, baseline: CustomRuleSet.empty, candidate: candidate);
      expect(o.n, 10);
      expect(o.baselineHits, 0);
      expect(o.candidateHits, 10);
      expect(o.fixed, 10);
      expect(o.verdict, BacktestVerdict.significant);
      expect(o.adoptable, isTrue);
      expect(ai.calls, 20);

      // Same rule set again: the baseline answers come from the cache.
      await tester.run(
          questions: qs, baseline: CustomRuleSet.empty, candidate: candidate);
      expect(ai.calls, 30);
    });

    test('the cases a 条例 came from are held out', () {
      final all = RuleLab.scorable(journal());
      final candidate = CustomRule(
          id: 'c',
          title: 't',
          text: 'x',
          derivedFrom: const ['c0', 'c1'],
          createdAt: DateTime(2026));
      final held = Backtester.heldOut(all, candidate);
      expect(held.map((q) => q.record.id), isNot(contains('c0')));
      expect(held, hasLength(8));
    });

    test('a 条例 that fixes no more than it breaks cannot be adopted', () {
      final qs = RuleLab.scorable(journal());
      final o = BacktestOutcome(items: [
        for (final q in qs) BacktestItem(q, 'B', 'B'),
      ]);
      expect(o.verdict, BacktestVerdict.same);
      expect(o.adoptable, isFalse);
    });
  });

  group('RuleLabPage', () {
    testWidgets('proposes, backtests and adopts, end to end', (tester) async {
      SharedPreferences.setMockInitialValues({'ai_key_gemini': 'k'});
      tester.view.physicalSize = const Size(360 * 3, 2400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final journal = [
        for (var i = 0; i < 10; i++)
          caseWith('c$i', [
            ab('A 年薪百万 #$i\nB 月薪4000元', 'A', ClaimVerdict.miss,
                note: '答案是B'),
          ], minutes: i),
      ];
      final ai = FakeAi((p) {
        if (p.contains('审校者')) {
          return '分析……\n```json\n[{"title": "层次从严", "text": "选B", '
              '"source": "经验", "rationale": "仅一例", "explains": [1]}]\n```';
        }
        return p.contains('选B') ? '答案：B' : '答案：A';
      });
      final repo = ExampleRepository()..seedForTesting(_examples());

      await tester.pumpWidget(ProviderScope(
        overrides: [
          caseListProvider.overrideWith((ref) => Stream.value(journal)),
          aiServiceProvider.overrideWithValue(ai),
          exampleRepositoryProvider.overrideWithValue(repo),
          rulesProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: RuleLabPage()),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('可用的答错题（附有反馈）10 道'), findsOneWidget);
      await tester.tap(find.text('开始反推'));
      await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(find.text('候选条例（可修改）'), findsOneWidget);
      expect(find.text('层次从严'), findsOneWidget);

      await tester.tap(find.text('回测'));
      // Two-second pauses between calls; step through them.
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(seconds: 3));
      }
      await tester.pumpAndSettle();
      expect(find.textContaining('回测结果：显著改善'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(FilledButton, '采用'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '采用').last);
      await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      final saved = await CustomRuleStore().load();
      expect(saved.revision, 1);
      expect(saved.active.single.title, '层次从严');
      expect(find.text('现行条例（第 1 版）'), findsOneWidget);
    });
  });
}

