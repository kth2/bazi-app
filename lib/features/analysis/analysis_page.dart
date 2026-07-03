import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rules/rule.dart';
import '../../providers/analysis_provider.dart';
import '../../providers/chart_provider.dart';
import '../../theme.dart';
import '../ai/ai_analysis_page.dart';

const List<String> kAnalysisCategories = [
  '整体命局',
  '财富',
  '事业',
  '学历',
  '婚姻',
  '健康',
];

/// Rule-based analysis, one tab per life aspect.
class AnalysisPage extends ConsumerWidget {
  const AnalysisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chart = ref.watch(chartResultProvider);
    final analysis = ref.watch(analysisProvider);

    if (chart == null) {
      return const Scaffold(body: Center(child: Text('尚未排盘')));
    }

    return DefaultTabController(
      length: kAnalysisCategories.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text('命理分析 · ${chart.baziString}'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            indicatorColor: kPaperCream,
            labelColor: kPaperCream,
            unselectedLabelColor: kPaperCream.withValues(alpha: 0.6),
            tabs: [for (final c in kAnalysisCategories) Tab(text: c)],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: FilledButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text('AI 深度分析（整体命局）'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AiAnalysisPage()),
                ),
              ),
            ),
            Expanded(
              child: analysis.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('规则加载失败：$e')),
                data: (grouped) => TabBarView(
                  children: [
                    for (final category in kAnalysisCategories)
                      _CategoryList(matches: grouped[category] ?? const []),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  final List<RuleMatch> matches;

  const _CategoryList({required this.matches});

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const Center(child: Text('此方面暂无明显命理特征'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: matches.length,
      itemBuilder: (context, i) => _MatchCard(match: matches[i]),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final RuleMatch match;

  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final fullMatch = match.matchRatio >= 0.999;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    match.rule.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: kPrimaryRed,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: fullMatch
                        ? kPrimaryRed
                        : kGoldAccent.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    fullMatch
                        ? '权重 ${match.score.toStringAsFixed(0)}'
                        : '部分符合 ${(match.matchRatio * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 11,
                      color: kPaperCream,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final c in match.matchedConditions)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: kPrimaryRed.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: kPrimaryRed.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      c.label,
                      style: const TextStyle(fontSize: 11, color: kPrimaryRed),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              match.rule.interpretation,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 8),
            Text(
              '出处：${match.rule.source}',
              style: TextStyle(
                fontSize: 11,
                color: kInkBlack.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
