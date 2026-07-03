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
}
