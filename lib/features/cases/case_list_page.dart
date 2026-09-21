import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cases/case_export.dart';
import '../../core/cases/case_record.dart';
import '../../providers/case_provider.dart';
import '../../theme.dart';
import 'case_detail_page.dart';
import 'case_stats_page.dart';

/// 案例库 — every saved reading, and whether its outcome has been filled in.
class CaseListPage extends ConsumerStatefulWidget {
  const CaseListPage({super.key});

  @override
  ConsumerState<CaseListPage> createState() => _CaseListPageState();
}

enum _Filter { all, needsReview, reviewed }

class _CaseListPageState extends ConsumerState<CaseListPage> {
  _Filter _filter = _Filter.all;

  bool _matches(CaseRecord c, DateTime now) => switch (_filter) {
        _Filter.all => true,
        _Filter.needsReview => c.status(now) == CaseStatus.awaitingReview ||
            c.status(now) == CaseStatus.partiallyReviewed,
        _Filter.reviewed => c.status(now) == CaseStatus.reviewed,
      };

  Future<void> _downloadFile() async {
    final json = await ref.read(caseRepositoryProvider).exportJson();
    try {
      final message =
          await CaseExport.save(CaseExport.filenameFor(DateTime.now()), json);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }

  Future<void> _copyToClipboard() async {
    final json = await ref.read(caseRepositoryProvider).exportJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('案例库 JSON 已复制到剪贴板')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(caseListProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('案例库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: '准确率统计',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CaseStatsPage()),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.ios_share),
            tooltip: '导出案例库',
            onSelected: (v) =>
                v == 'file' ? _downloadFile() : _copyToClipboard(),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'file',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.download),
                  title: Text('下载 JSON 文件'),
                  subtitle: Text('可保存、转发、备份'),
                ),
              ),
              PopupMenuItem(
                value: 'clipboard',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.copy),
                  title: Text('复制到剪贴板'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('读取案例库失败：$e')),
        data: (cases) {
          if (cases.isEmpty) return const _EmptyState();
          final shown = [
            for (final c in cases)
              if (_matches(c, now)) c
          ];
          return Column(
            children: [
              _FilterBar(
                filter: _filter,
                counts: {
                  _Filter.all: cases.length,
                  _Filter.needsReview: cases
                      .where((c) =>
                          c.status(now) == CaseStatus.awaitingReview ||
                          c.status(now) == CaseStatus.partiallyReviewed)
                      .length,
                  _Filter.reviewed: cases
                      .where((c) => c.status(now) == CaseStatus.reviewed)
                      .length,
                },
                onChanged: (f) => setState(() => _filter = f),
              ),
              Expanded(
                child: shown.isEmpty
                    ? const Center(child: Text('此分类下暂无案例'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: shown.length,
                        itemBuilder: (_, i) => _CaseCard(record: shown[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 48, color: kGoldAccent),
              SizedBox(height: 16),
              Text('还没有保存的案例',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text(
                '在任意 AI 分析页点右上角「存为案例」，\n'
                '待该运/年/月/日过去后回来回填实际结果，\n'
                '即可逐条核对推演是否应验。',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.6),
              ),
            ],
          ),
        ),
      );
}

class _FilterBar extends StatelessWidget {
  final _Filter filter;
  final Map<_Filter, int> counts;
  final ValueChanged<_Filter> onChanged;

  const _FilterBar({
    required this.filter,
    required this.counts,
    required this.onChanged,
  });

  static const _labels = {
    _Filter.all: '全部',
    _Filter.needsReview: '待回填',
    _Filter.reviewed: '已回填',
  };

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        // Wrap, not Row: three chips carrying counts run about 90px past a
        // 320dp screen, and the one pushed off the edge was 「已回填」 — the
        // filter you need most once cases start coming due. Wrapping keeps
        // every chip reachable instead of hiding the last one.
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final f in _Filter.values)
              ChoiceChip(
                label: Text('${_labels[f]}（${counts[f] ?? 0}）'),
                selected: filter == f,
                onSelected: (_) => onChanged(f),
              ),
          ],
        ),
      );
}

class _CaseCard extends StatelessWidget {
  final CaseRecord record;

  const _CaseCard({required this.record});

  static const _statusColors = {
    CaseStatus.pending: Colors.blueGrey,
    CaseStatus.awaitingReview: kPrimaryRed,
    CaseStatus.partiallyReviewed: kGoldAccent,
    CaseStatus.reviewed: Color(0xFF2E7D32),
  };

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = record.status(now);
    final color = _statusColors[status]!;
    final rate = record.hitRate;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CaseDetailPage(caseId: record.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      record.title.isEmpty ? record.scopeLabel : record.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(label: status.label, color: color),
                ],
              ),
              const SizedBox(height: 6),
              Text('${record.baziString} · ${record.scopeLabel}',
                  style: const TextStyle(fontSize: 13, color: kInkBlack)),
              const SizedBox(height: 4),
              Text(
                record.structureSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              // Both halves are free text of unbounded length, and the
              // right-hand one carried the review count — so on a narrow
              // phone it was pushed clean off the card. Neither may be
              // rigid: the dates give way first, the count second.
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      '记于 ${_fmt(record.createdAt)}'
                      '${record.reviewDueAt == null ? '' : ' · 可回填于 ${_fmt(record.reviewDueAt!)}'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.black45),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      rate == null
                          ? '已判定 ${record.scoredCount}/${record.claims.length}'
                          : '应验率 ${(rate * 100).round()}%'
                              '（判定 ${record.scoredCount}/${record.claims.length}）',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// The 已回填 / 待回填 pill.
///
/// Its own widget so the label cannot be squeezed out of its own background:
/// a tight vertical padding clips CJK glyphs once the system text scale grows,
/// and an unbounded label eats the title's room. The scale is capped here and
/// nowhere else — the rest of the card scales normally.
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  /// Past this the pill stops growing; the text beside it keeps scaling.
  static const double _maxScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        textScaler: TextScaler.linear(scale > _maxScale ? _maxScale : scale),
        style: TextStyle(
          fontSize: 12,
          // CJK glyphs overshoot a 4px vertical padding without this.
          height: 1.3,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
