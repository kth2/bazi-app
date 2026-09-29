import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cases/case_record.dart';
import '../../core/cases/case_replay.dart';
import '../../core/cases/rule_lab.dart';
import '../../core/rules/custom_rules.dart';
import '../../providers/ai_provider.dart';
import '../../providers/analysis_provider.dart';
import '../../providers/case_provider.dart';
import '../../providers/custom_rules_provider.dart';
import '../../services/ai_service.dart';
import '../../theme.dart';
import '../settings/settings_sheet.dart';

/// 条例修订 — AI 从答错的题反推条例，回测后由你决定采用。
///
/// See `core/cases/rule_lab.dart` for the loop and why the backtest excludes
/// the cases a 条例 came from.
class RuleLabPage extends ConsumerStatefulWidget {
  const RuleLabPage({super.key});

  @override
  ConsumerState<RuleLabPage> createState() => _RuleLabPageState();
}

class _Proposal {
  final CustomRule rule;
  final TextEditingController title;
  final TextEditingController text;
  final TextEditingController source;
  BacktestOutcome? outcome;
  (int, int)? progress;
  bool running = false;
  String? error;

  _Proposal(this.rule)
      : title = TextEditingController(text: rule.title),
        text = TextEditingController(text: rule.text),
        source = TextEditingController(text: rule.source);

  CustomRule get edited => rule.copyWith(
        title: title.text.trim(),
        text: text.text.trim(),
        source: source.text.trim(),
      );

  void dispose() {
    title.dispose();
    text.dispose();
    source.dispose();
  }
}

class _RuleLabPageState extends ConsumerState<RuleLabPage> {
  int _missCount = 8;
  int _testCount = 20;
  bool _inferring = false;
  String? _inferError;
  String? _analysis;
  bool _showAnalysis = false;
  final List<_Proposal> _proposals = [];
  bool _cancel = false;

  @override
  void dispose() {
    _cancel = true;
    for (final p in _proposals) {
      p.dispose();
    }
    super.dispose();
  }

  Future<AiSettings?> _settingsOrPrompt() async {
    final s = await AiSettings.load();
    if (s.isConfigured) return s;
    if (!mounted) return null;
    await showAiSettingsSheet(context);
    final again = await AiSettings.load();
    return again.isConfigured ? again : null;
  }

  Future<void> _infer(List<CaseRecord> cases, CustomRuleSet set) async {
    final settings = await _settingsOrPrompt();
    if (settings == null) return;
    setState(() {
      _inferring = true;
      _inferError = null;
    });
    try {
      final rules = await ref.read(rulesProvider.future);
      final misses = RuleLab.misses(cases).take(_missCount).toList();
      final structures = [
        for (final m in misses)
          CaseReplay.rebuild(m.record, rules)?.structure.summary ??
              m.record.structureSummary,
      ];
      final prompt = RuleLab.reversePrompt(misses, structures, set.promptLines);
      final answer =
          await ref.read(aiServiceProvider).complete(prompt, settings);
      final proposals = RuleLab.parseProposals(answer, misses);
      if (!mounted) return;
      setState(() {
        _analysis = answer;
        for (final p in _proposals) {
          p.dispose();
        }
        _proposals
          ..clear()
          ..addAll(proposals.map(_Proposal.new));
        if (proposals.isEmpty) {
          _inferError = 'AI 的回答里没有读到条例（JSON 格式不符）。'
              '可展开下方原文查看分析，或再试一次。';
        }
      });
    } on AiException catch (e) {
      if (mounted) setState(() => _inferError = e.message);
    } finally {
      if (mounted) setState(() => _inferring = false);
    }
  }

  Future<void> _backtest(
      _Proposal p, List<CaseRecord> cases, CustomRuleSet set) async {
    final settings = await _settingsOrPrompt();
    if (settings == null) return;
    final candidate = p.edited;
    final questions = Backtester.heldOut(
        RuleLab.scorable(cases), candidate,
        limit: _testCount);
    setState(() {
      p.running = true;
      p.error = null;
      p.outcome = null;
      p.progress = (0, questions.length);
    });
    try {
      final tester = Backtester(
        ai: ref.read(aiServiceProvider),
        settings: settings,
        examples: ref.read(exampleRepositoryProvider),
        rules: await ref.read(rulesProvider.future),
      );
      final outcome = await tester.run(
        questions: questions,
        baseline: set,
        candidate: candidate,
        onProgress: (d, t) {
          if (mounted) setState(() => p.progress = (d, t));
        },
        cancelled: () => _cancel,
      );
      if (mounted) setState(() => p.outcome = outcome);
    } on AiException catch (e) {
      if (mounted) setState(() => p.error = e.message);
    } finally {
      if (mounted) setState(() => p.running = false);
    }
  }

  Future<void> _adopt(_Proposal p, CustomRuleSet set) async {
    final outcome = p.outcome!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('采用这条条例？'),
        content: Text(
          '回测 ${outcome.n} 题：现行 ${outcome.baselineHits} 中，'
          '加入后 ${outcome.candidateHits} 中（改对 ${outcome.fixed}、'
          '改错 ${outcome.broken}）。\n\n'
          '采用后，所有新的分析与问答都会按此条例作答；'
          '统计页会把此后的题单独计分。随时可以在本页停用。',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('采用')),
        ],
      ),
    );
    if (ok != true) return;
    final next = set.adopt(p.edited, outcome.summary());
    await ref.read(customRuleStoreProvider).save(next);
    ref.invalidate(customRuleSetProvider);
    if (!mounted) return;
    setState(() {
      _proposals.remove(p);
      p.dispose();
    });
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已采用，条例现为第 ${next.revision} 版')));
  }

  Future<void> _toggle(CustomRule r, CustomRuleSet set) async {
    final next = set.setActive(r.id, !r.active);
    await ref.read(customRuleStoreProvider).save(next);
    ref.invalidate(customRuleSetProvider);
  }

  @override
  Widget build(BuildContext context) {
    final casesAsync = ref.watch(caseListProvider);
    final setAsync = ref.watch(customRuleSetProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('条例修订')),
      body: casesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('读取失败：$e')),
        data: (cases) => setAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('读取条例失败：$e')),
          data: (set) => _body(cases, set),
        ),
      ),
    );
  }

  Widget _body(List<CaseRecord> cases, CustomRuleSet set) {
    final misses = RuleLab.misses(cases);
    final scorable = RuleLab.scorable(cases);
    final muted = kInkBlack.withValues(alpha: 0.65);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          color: kInkBlack.withValues(alpha: 0.03),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              '流程：① AI 读答错且有反馈的题，找出推理错在哪，提出条例；'
              '② 用没参与反推的已判定选择题回测——同一批题各问两遍，'
              '一遍按现行条例，一遍加入新条例；③ 改对多于改错才能采用，'
              '且要你确认。条例进入 AI 的推理依据，不改引擎代码；'
              '格局取法这类确定性的修正，仍需在引擎里改。',
              style: TextStyle(fontSize: 12, height: 1.6, color: muted),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _currentRules(set, muted),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI 反推',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  '可用的答错题（附有反馈）${misses.length} 道；'
                  '可回测的已判定选择题 ${scorable.length} 道。',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('用最近', style: TextStyle(fontSize: 12, color: muted)),
                    for (final n in const [5, 8, 12])
                      ChoiceChip(
                        label: Text('$n 道',
                            style: const TextStyle(fontSize: 12)),
                        selected: _missCount == n,
                        onSelected: (_) => setState(() => _missCount = n),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _inferring || misses.isEmpty
                      ? null
                      : () => _infer(cases, set),
                  icon: _inferring
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.psychology_outlined),
                  label: Text(_inferring ? '反推中…' : '开始反推'),
                ),
                if (misses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('还没有「未应验」且写了反馈的问答。',
                        style: TextStyle(fontSize: 12, color: muted)),
                  ),
                if (_inferError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_inferError!,
                        style: const TextStyle(
                            fontSize: 12, color: kPrimaryRed)),
                  ),
                if (_analysis != null) ...[
                  TextButton(
                    onPressed: () =>
                        setState(() => _showAnalysis = !_showAnalysis),
                    child: Text(_showAnalysis ? '收起 AI 逐案分析' : '展开 AI 逐案分析',
                        style: const TextStyle(fontSize: 12)),
                  ),
                  if (_showAnalysis)
                    SelectableText(_analysis!,
                        style: const TextStyle(fontSize: 12, height: 1.6)),
                ],
              ],
            ),
          ),
        ),
        for (final p in _proposals) ...[
          const SizedBox(height: 12),
          _proposalCard(p, cases, set, scorable, muted),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _currentRules(CustomRuleSet set, Color muted) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              set.rules.isEmpty ? '现行条例：尚无' : '现行条例（第 ${set.revision} 版）',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            for (final r in set.rules) ...[
              const Divider(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(r.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: r.active ? kInkBlack : muted,
                          decoration:
                              r.active ? null : TextDecoration.lineThrough,
                        )),
                  ),
                  TextButton(
                    onPressed: () => _toggle(r, set),
                    child: Text(r.active ? '停用' : '恢复',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              Text(r.text, style: const TextStyle(fontSize: 12, height: 1.6)),
              if (r.source.isNotEmpty)
                Text('出处：${r.source}',
                    style: TextStyle(fontSize: 11, color: muted)),
              if (r.backtest != null)
                Text(
                  '采用时回测：${r.backtest!.n} 题，'
                  '${r.backtest!.baselineHits} → ${r.backtest!.candidateHits} 中'
                  '（改对 ${r.backtest!.fixed}、改错 ${r.backtest!.broken}）',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _proposalCard(_Proposal p, List<CaseRecord> cases, CustomRuleSet set,
      List<ScoredQuestion> scorable, Color muted) {
    final heldOut =
        Backtester.heldOut(scorable, p.edited, limit: _testCount).length;
    final o = p.outcome;
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('候选条例（可修改）',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            TextField(controller: p.title, decoration: deco('名称')),
            const SizedBox(height: 8),
            TextField(
                controller: p.text,
                maxLines: null,
                decoration: deco('条例（何时适用，如何断）')),
            const SizedBox(height: 8),
            TextField(controller: p.source, decoration: deco('出处')),
            if (p.rule.rationale.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('理由：${p.rule.rationale}',
                  style: TextStyle(fontSize: 12, height: 1.5, color: muted)),
            ],
            const SizedBox(height: 6),
            Text(
              '来自 ${p.rule.derivedFrom.length} 个案例，回测时排除；'
              '可回测 $heldOut 题，约需 ${heldOut * 2} 次 AI 调用'
              '（现行条例的答案会缓存）。',
              style: TextStyle(fontSize: 11, color: muted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('回测题数', style: TextStyle(fontSize: 12, color: muted)),
                for (final n in const [10, 20, 40])
                  ChoiceChip(
                    label: Text('$n', style: const TextStyle(fontSize: 12)),
                    selected: _testCount == n,
                    onSelected: p.running
                        ? null
                        : (_) => setState(() => _testCount = n),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: p.running ||
                          heldOut < BacktestOutcome.kMinQuestions
                      ? null
                      : () => _backtest(p, cases, set),
                  child: Text(p.running ? '回测中…' : '回测'),
                ),
                OutlinedButton(
                  onPressed: p.running
                      ? null
                      : () => setState(() {
                            _proposals.remove(p);
                            p.dispose();
                          }),
                  child: const Text('丢弃'),
                ),
              ],
            ),
            if (heldOut < BacktestOutcome.kMinQuestions)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    '可回测的题不足 ${BacktestOutcome.kMinQuestions} 道，'
                    '先多回填一些选择题。',
                    style: TextStyle(fontSize: 12, color: muted)),
              ),
            if (p.running && p.progress != null) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: p.progress!.$2 == 0
                    ? null
                    : p.progress!.$1 / p.progress!.$2,
              ),
              const SizedBox(height: 4),
              Text('${p.progress!.$1} / ${p.progress!.$2}',
                  style: TextStyle(fontSize: 11, color: muted)),
            ],
            if (p.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(p.error!,
                    style:
                        const TextStyle(fontSize: 12, color: kPrimaryRed)),
              ),
            if (o != null) ...[
              const Divider(height: 22),
              Text('回测结果：${o.verdict.label}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: o.adoptable ? const Color(0xFF2E7D32) : kPrimaryRed,
                  )),
              const SizedBox(height: 6),
              Text(
                '共 ${o.n} 题${o.skipped > 0 ? '（另有 ${o.skipped} 题无法重答）' : ''}\n'
                '现行条例：${o.baselineHits} 中；加入此条：${o.candidateHits} 中\n'
                '改对 ${o.fixed} 题，改错 ${o.broken} 题'
                '（p = ${o.p.toStringAsFixed(2)}）',
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 4),
              Text(
                o.adoptable
                    ? '改对多于改错，可以采用。p 越小越不像运气；'
                        '题少时即使有效，p 也常大于 0.05。'
                    : o.n < BacktestOutcome.kMinQuestions
                        ? '有效题数不足，不能据此采用。'
                        : '没有改对多于改错，不建议采用。可修改条例后再回测。',
                style: TextStyle(fontSize: 12, height: 1.5, color: muted),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: o.adoptable ? () => _adopt(p, set) : null,
                icon: const Icon(Icons.check),
                label: const Text('采用'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
