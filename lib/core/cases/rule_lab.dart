import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../../services/ai_service.dart';
import '../analysis/analysis_prompt.dart';
import '../analysis/bazi_analysis_service.dart';
import '../analysis/example_repository.dart';
import '../rules/custom_rules.dart';
import '../rules/rule.dart';
import 'case_record.dart';
import 'case_replay.dart';
import 'choice_question.dart';

/// 条例修订：AI 从答错的案例反推条例，回测后由人决定是否采用。
///
/// The loop, and where the guard sits in it:
///
///   1. [RuleLab.misses] — wrong answers that carry feedback.
///   2. [RuleLab.reversePrompt] — the AI reads them and proposes 条例 in a
///      fixed JSON shape ([RuleLab.parseProposals]).
///   3. [Backtester] — every judged two-way question *not* used in step 2 is
///      asked again, under the 条例 in force and with the proposal added.
///   4. [CustomRuleSet.adopt] — only with that result, and only when a person
///      taps 采用. [BacktestOutcome.adoptable] says whether the numbers allow
///      it at all.
///
/// Step 3 is what keeps this honest. A 条例 fitted to the cases it came
/// from will explain them — that is how it was made — so it is judged only
/// on the others.

/// One judged question with a known right answer.
class ScoredQuestion {
  final CaseRecord record;
  final PredictedClaim claim;

  /// The option letter that actually happened.
  final String truth;

  const ScoredQuestion(this.record, this.claim, this.truth);

  String get key => '${record.id}|${claim.id}';
}

/// A wrong answer the AI can learn from: it has to say what really happened.
class MissCase {
  final CaseRecord record;
  final PredictedClaim claim;

  const MissCase(this.record, this.claim);

  String get feedback => [
        if (claim.note.trim().isNotEmpty) claim.note.trim(),
        if (record.outcomeNote.trim().isNotEmpty) record.outcomeNote.trim(),
      ].join('\n');
}

class RuleLab {
  RuleLab._();

  /// Two-option questions answered 应验/未应验, newest first.
  static List<ScoredQuestion> scorable(List<CaseRecord> records) {
    final out = <ScoredQuestion>[];
    for (final r in records) {
      for (final c in r.claims) {
        if (c.kind != ClaimKind.qa) continue;
        if (c.verdict != ClaimVerdict.hit && c.verdict != ClaimVerdict.miss) {
          continue;
        }
        final reading = c.choice;
        if (reading == null) continue;
        final truth = c.verdict == ClaimVerdict.hit
            ? reading.picked
            : reading.options.firstWhere((o) => o.key != reading.picked).key;
        out.add(ScoredQuestion(r, c, truth));
      }
    }
    out.sort((a, b) => b.record.createdAt.compareTo(a.record.createdAt));
    return out;
  }

  /// 未应验 answers with feedback, newest first.
  static List<MissCase> misses(List<CaseRecord> records) {
    final out = <MissCase>[];
    for (final r in records) {
      for (final c in r.claims) {
        if (c.kind != ClaimKind.qa || c.verdict != ClaimVerdict.miss) continue;
        final m = MissCase(r, c);
        if (m.feedback.isEmpty) continue;
        out.add(m);
      }
    }
    out.sort((a, b) => b.record.createdAt.compareTo(a.record.createdAt));
    return out;
  }

  static String _clip(String s, int n) =>
      s.length <= n ? s : '${s.substring(0, n)}……';

  /// The 反推 prompt. [structures] is today's engine summary per case, in
  /// the same order as [cases] — what the rule has to correct is the current
  /// reasoning, not whatever version answered at the time.
  static String reversePrompt(
    List<MissCase> cases,
    List<String> structures,
    List<String> activeRules,
  ) {
    final buf = StringBuffer()
      ..writeln('你是子平格局法的审校者。下面是一个八字应用答错的案例：'
          '每例给出命造、引擎当前的格局推演、当时的问题与回答，以及实际结果。')
      ..writeln('应用的规则是：引擎按《子平真诠》格局法定格局、成败、用神、相神、'
          '忌神，AI 依此解释并作答。')
      ..writeln();
    if (activeRules.isNotEmpty) {
      buf.writeln('【现行自定义条例】');
      for (var i = 0; i < activeRules.length; i++) {
        buf.writeln('${i + 1}. ${activeRules[i]}');
      }
      buf.writeln();
    }
    for (var i = 0; i < cases.length; i++) {
      final m = cases[i];
      final r = m.record;
      buf
        ..writeln('【案例${i + 1}】命造：${r.baziString}'
            '（${r.input.gender.name == 'male' ? '男' : '女'}，${r.input.year}年生）'
            '，分析范围：${r.scopeLabel}')
        ..writeln('引擎推演：${structures[i]}')
        ..writeln('问题：${m.claim.title.trim()}')
        ..writeln('当时的回答（节选）：${_clip(m.claim.detail.trim(), 500)}')
        ..writeln('实际结果与反馈：${_clip(m.feedback, 900)}')
        ..writeln();
    }
    buf
      ..writeln('请完成：')
      ..writeln('1. 逐案指出推理错在哪一步：取格、成败、相神/忌神判定、'
          '岁运喜忌，还是把格局高低与财富多少混为一谈。')
      ..writeln('2. 反馈里若附有正解推理，优先采纳，并核对其所引古籍。')
      ..writeln('3. 归纳最多 3 条可通用的条例。每条必须：'
          '(a) 用干支、十神、格局写明何时适用；(b) 写明适用后的结论；'
          '(c) 注明出处（《子平真诠》《滴天髓》《三命通会》《神峰通考》《渊海子平》等），'
          '无出处写「经验」；(d) 不提任何具体命造或人名；'
          '(e) 不得是「多选平常一项」「多选破财」之类的统计偏好；'
          '(f) 与现行条例重复者不提。')
      ..writeln('4. 只解释一个案例的条例，在 rationale 里写明「仅一例」。')
      ..writeln()
      ..writeln('先简要逐案分析，最后单独输出一个 JSON 代码块，格式严格如下：')
      ..writeln('```json')
      ..writeln('[{"title": "条例名", "text": "何时适用，适用后如何断", '
          '"source": "出处", "rationale": "为何提出，解释了哪些案例", '
          '"explains": [1, 3]}]')
      ..writeln('```');
    return buf.toString();
  }

  /// Reads the JSON block at the end of a 反推 answer. Lenient about fences
  /// and stray text; an unreadable answer yields no proposals rather than an
  /// error, and the page shows the prose so nothing is lost.
  static List<CustomRule> parseProposals(
    String answer,
    List<MissCase> cases, {
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    String? body;
    final fenced =
        RegExp(r'```(?:json)?\s*(\[[\s\S]*?\])\s*```').allMatches(answer);
    if (fenced.isNotEmpty) {
      body = fenced.last.group(1);
    } else {
      final a = answer.indexOf('['), b = answer.lastIndexOf(']');
      if (a >= 0 && b > a) body = answer.substring(a, b + 1);
    }
    if (body == null) return const [];
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return const [];
    }
    if (decoded is! List) return const [];

    final out = <CustomRule>[];
    for (var i = 0; i < decoded.length; i++) {
      final item = decoded[i];
      if (item is! Map) continue;
      final title = '${item['title'] ?? ''}'.trim();
      final text = '${item['text'] ?? ''}'.trim();
      if (title.isEmpty || text.isEmpty) continue;
      final explains = [
        for (final e in (item['explains'] as List? ?? const []))
          if (e is num && e >= 1 && e <= cases.length) e.toInt(),
      ];
      // The cases a rule came from are held out of its backtest. When the
      // AI does not say which it explains, all of them are held out.
      final from = explains.isEmpty
          ? [for (final c in cases) c.record.id]
          : [for (final e in explains) cases[e - 1].record.id];
      out.add(CustomRule(
        id: 'rule_${at.microsecondsSinceEpoch}_$i',
        title: title,
        text: text,
        source: '${item['source'] ?? ''}'.trim(),
        rationale: '${item['rationale'] ?? ''}'.trim(),
        derivedFrom: {...from}.toList(),
        active: false,
        createdAt: at,
      ));
    }
    return out;
  }
}

/// Two-sided exact McNemar test on the discordant pairs.
///
/// Only the questions that changed answer say anything about the 条例:
/// [fixed] went wrong→right, [broken] right→wrong. Under "the 条例 makes no
/// difference" each change is a coin toss.
double mcNemarExact(int fixed, int broken) {
  final n = fixed + broken;
  if (n == 0) return 1;
  final k = math.min(fixed, broken);
  var tail = 0.0;
  var logC = 0.0; // log C(n, 0)
  for (var i = 0; i <= k; i++) {
    if (i > 0) logC += math.log(n - i + 1) - math.log(i);
    tail += math.exp(logC - n * math.ln2);
  }
  return math.min(1, 2 * tail);
}

enum BacktestVerdict { worse, same, better, significant }

extension BacktestVerdictX on BacktestVerdict {
  String get label => switch (this) {
        BacktestVerdict.worse => '变差',
        BacktestVerdict.same => '无变化',
        BacktestVerdict.better => '有改善，但尚不显著',
        BacktestVerdict.significant => '显著改善',
      };
}

/// One question in a backtest, both ways.
class BacktestItem {
  final ScoredQuestion question;
  final String? baselinePick;
  final String? candidatePick;

  const BacktestItem(this.question, this.baselinePick, this.candidatePick);

  bool get baselineRight => baselinePick == question.truth;
  bool get candidateRight => candidatePick == question.truth;
}

class BacktestOutcome {
  final List<BacktestItem> items;

  /// Questions that could not be asked (scope not rebuildable, AI error).
  final int skipped;

  const BacktestOutcome({required this.items, this.skipped = 0});

  int get n => items.length;
  int get baselineHits => items.where((i) => i.baselineRight).length;
  int get candidateHits => items.where((i) => i.candidateRight).length;
  int get fixed =>
      items.where((i) => !i.baselineRight && i.candidateRight).length;
  int get broken =>
      items.where((i) => i.baselineRight && !i.candidateRight).length;
  double get p => mcNemarExact(fixed, broken);

  BacktestVerdict get verdict {
    if (fixed < broken) return BacktestVerdict.worse;
    if (fixed == broken) return BacktestVerdict.same;
    return p < 0.05 ? BacktestVerdict.significant : BacktestVerdict.better;
  }

  /// A 条例 that fixes no more than it breaks has shown nothing, and one
  /// scored on fewer than [kMinQuestions] has not been tested.
  bool get adoptable => fixed > broken && n >= kMinQuestions;

  static const int kMinQuestions = 8;

  BacktestSummary summary([DateTime? at]) => BacktestSummary(
        n: n,
        baselineHits: baselineHits,
        candidateHits: candidateHits,
        fixed: fixed,
        broken: broken,
        at: at ?? DateTime.now(),
      );
}

/// Asks held-out questions again, with and without a candidate 条例.
class Backtester {
  final AiService ai;
  final AiSettings settings;
  final ExampleRepository examples;
  final List<Rule> rules;

  /// Pause between calls, to stay under free-tier rate limits.
  final Duration pause;

  /// How long to wait after a 429 before the one retry.
  final Duration rateLimitWait;

  Backtester({
    required this.ai,
    required this.settings,
    required this.examples,
    required this.rules,
    this.pause = const Duration(seconds: 2),
    this.rateLimitWait = const Duration(seconds: 30),
  });

  /// Low, not zero: some providers treat 0 as "unset".
  static const double kTemperature = 0.1;

  /// Questions the candidate was not derived from, newest first, at most
  /// [limit].
  static List<ScoredQuestion> heldOut(
    List<ScoredQuestion> all,
    CustomRule candidate, {
    int limit = 20,
  }) =>
      [
        for (final q in all)
          if (!candidate.derivedFrom.contains(q.record.id)) q,
      ].take(limit).toList();

  Future<String?> _pick(ScoredQuestion q, CustomRuleSet set) async {
    final report = CaseReplay.rebuild(q.record, rules);
    if (report == null) return null;
    final similar = await examples.findMatches(report.pattern.tags);
    final prompt = AnalysisPrompt.buildCustom(
      report: report,
      examples: similar,
      question: q.claim.title,
      customRules: set.promptLines,
    );
    String answer;
    try {
      answer = await ai.complete(prompt, settings, temperature: kTemperature);
    } on AiException catch (e) {
      if (!e.message.contains('429')) rethrow;
      await Future<void>.delayed(rateLimitWait);
      answer = await ai.complete(prompt, settings, temperature: kTemperature);
    }
    return ChoiceQuestion.pickOf(answer) ?? '';
  }

  static String _cacheKey(ScoredQuestion q, int revision) =>
      'lab_base_v${BaziAnalysisService.kEngineVersion}_r${revision}_${q.key}';

  /// Runs both arms. Baseline answers are cached per engine version and
  /// 条例 revision, so a second proposal against the same set costs half.
  Future<BacktestOutcome> run({
    required List<ScoredQuestion> questions,
    required CustomRuleSet baseline,
    required CustomRule candidate,
    void Function(int done, int total)? onProgress,
    bool Function()? cancelled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final withCandidate = baseline.withCandidate(candidate);
    final items = <BacktestItem>[];
    var skipped = 0;
    var failures = 0;

    for (var i = 0; i < questions.length; i++) {
      if (cancelled?.call() ?? false) break;
      final q = questions[i];
      onProgress?.call(i, questions.length);
      try {
        final key = _cacheKey(q, baseline.revision);
        var base = prefs.getString(key);
        if (base == null) {
          base = await _pick(q, baseline);
          if (base == null) {
            skipped++;
            continue;
          }
          await prefs.setString(key, base);
          await Future<void>.delayed(pause);
        }
        final cand = await _pick(q, withCandidate);
        await Future<void>.delayed(pause);
        if (cand == null) {
          skipped++;
          continue;
        }
        items.add(BacktestItem(q, base.isEmpty ? null : base,
            cand.isEmpty ? null : cand));
        failures = 0;
      } on AiException {
        skipped++;
        // Three in a row means the key, quota or model is gone, not a blip.
        if (++failures >= 3) rethrow;
      }
    }
    onProgress?.call(questions.length, questions.length);
    return BacktestOutcome(items: items, skipped: skipped);
  }
}
