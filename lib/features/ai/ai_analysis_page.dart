import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analysis/bazi_analysis_service.dart';
import '../../core/models/chart_result.dart';
import '../../providers/ai_provider.dart';
import '../../providers/analysis_provider.dart';
import '../../providers/chart_provider.dart';
import '../../services/ai_service.dart';
import '../../theme.dart';
import '../settings/settings_sheet.dart';

/// AI deep analysis for 整体命局 / 大运 / 流年 — 4 life categories.
class AiAnalysisPage extends ConsumerStatefulWidget {
  final DecadeData? decade;
  final FlowYearData? year;

  const AiAnalysisPage({super.key, this.decade, this.year});

  @override
  ConsumerState<AiAnalysisPage> createState() => _AiAnalysisPageState();
}

class _AiAnalysisPageState extends ConsumerState<AiAnalysisPage> {
  Future<ScopedAnalysis>? _future;

  final _questionController = TextEditingController();
  final List<CustomAnswer> _answers = [];
  bool _asking = false;
  String? _qaError;

  String get _scopeTitle => widget.year != null
      ? '流年 ${widget.year!.year} ${widget.year!.ganZhi}'
      : widget.decade != null
          ? '大运 ${widget.decade!.ganZhi}'
          : '整体命局';

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final q = _questionController.text.trim();
    if (q.isEmpty || _asking) return;
    final chart = ref.read(chartResultProvider);
    if (chart == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _asking = true;
      _qaError = null;
    });
    final service = ref.read(baziAnalysisServiceProvider);
    try {
      final rules = await ref.read(rulesProvider.future);
      final ans = await service.askQuestion(
        chart,
        rules,
        q,
        decade: widget.decade,
        year: widget.year,
      );
      if (!mounted) return;
      setState(() {
        _answers.insert(0, ans);
        _questionController.clear();
        _asking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _qaError = '$e';
        _asking = false;
      });
    }
  }

  void _start() {
    final chart = ref.read(chartResultProvider);
    if (chart == null) return;
    final service = ref.read(baziAnalysisServiceProvider);
    setState(() {
      _future = () async {
        final rules = await ref.read(rulesProvider.future);
        if (widget.year != null) {
          return service.analyzeLiuNian(
              chart, rules, widget.decade!, widget.year!);
        }
        if (widget.decade != null) {
          return service.analyzeDaYun(chart, rules, widget.decade!);
        }
        return service.analyzeLife(chart, rules);
      }();
    });
  }

  Future<void> _refresh() async {
    final chart = ref.read(chartResultProvider);
    if (chart != null) await BaziAnalysisService.clearCacheFor(chart);
    _start();
  }

  @override
  Widget build(BuildContext context) {
    final chart = ref.watch(chartResultProvider);
    if (chart == null || _future == null) {
      return const Scaffold(body: Center(child: Text('尚未排盘')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('AI 深度分析 · $_scopeTitle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新分析',
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<ScopedAnalysis>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('命理师批算中，请稍候…'),
                ],
              ),
            );
          }
          if (snap.hasError) {
            final err = snap.error;
            final needsKey =
                err is AiException && err.message.contains('API Key');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$err', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    if (needsKey)
                      FilledButton(
                        onPressed: () async {
                          await showAiSettingsSheet(context);
                          _start();
                        },
                        child: const Text('前往设置 API Key'),
                      )
                    else
                      FilledButton(onPressed: _start, child: const Text('重试')),
                  ],
                ),
              ),
            );
          }
          final a = snap.data!;
          final sections = <(String, String)>[
            ('一、事业财富', a.careerWealth),
            ('二、婚姻感情', a.marriage),
            ('三、学习/发展', a.studyGrowth),
            ('四、健康分析', a.health),
          ];
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (a.patternSummary.isNotEmpty)
                Card(
                  color: kPrimaryRed.withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(a.patternSummary,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              _buildQaSection(),
              for (final (title, body) in sections)
                if (body.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.only(top: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: kPrimaryRed)),
                          const SizedBox(height: 8),
                          SelectableText(body,
                              style:
                                  const TextStyle(fontSize: 14, height: 1.7)),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '本分析由 AI 参考古典命理与真实案例生成，仅供参考。',
                  style: TextStyle(
                      fontSize: 11, color: kInkBlack.withValues(alpha: 0.4)),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Free-form question input + accumulated answers.
  Widget _buildQaSection() {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      color: kGoldAccent.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology_alt, size: 20, color: kPrimaryRed),
                const SizedBox(width: 6),
                Text('向 AI 提问（针对本$_scopeTitle）',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kPrimaryRed)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '可问具体事件、择日、多选判断等。例如：'
              '「甲辰年最可能发生哪件事？1读博毕业 2感情重挫 3官非牢狱 4双亲离世」',
              style: TextStyle(
                  fontSize: 12, color: kInkBlack.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _questionController,
              minLines: 2,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: '输入你的问题…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: _asking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: kPaperCream))
                    : const Icon(Icons.send),
                label: Text(_asking ? '命理师推演中…' : '提问'),
                onPressed: _asking ? null : _ask,
              ),
            ),
            if (_qaError != null) ...[
              const SizedBox(height: 10),
              Text(_qaError!,
                  style: const TextStyle(fontSize: 13, color: kPrimaryRed)),
            ],
            for (final ans in _answers) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: kInkBlack.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.help_outline,
                            size: 16, color: kGoldAccent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(ans.question,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    SelectableText(ans.answer,
                        style: const TextStyle(fontSize: 14, height: 1.7)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
