import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cases/case_record.dart';
import '../../providers/case_provider.dart';
import '../../theme.dart';

/// One saved case: what the engine claimed, and room to record what happened.
class CaseDetailPage extends ConsumerStatefulWidget {
  final String caseId;

  const CaseDetailPage({super.key, required this.caseId});

  @override
  ConsumerState<CaseDetailPage> createState() => _CaseDetailPageState();
}

class _CaseDetailPageState extends ConsumerState<CaseDetailPage> {
  CaseRecord? _record;
  late TextEditingController _outcome;
  late TextEditingController _title;
  final Map<String, TextEditingController> _notes = {};
  bool _dirty = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _outcome = TextEditingController();
    _title = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _outcome.dispose();
    _title.dispose();
    for (final c in _notes.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final r = await ref.read(caseRepositoryProvider).byId(widget.caseId);
    if (!mounted) return;
    setState(() {
      _record = r;
      _loading = false;
      if (r != null) {
        _outcome.text = r.outcomeNote;
        _title.text = r.title;
        for (final c in r.claims) {
          _notes[c.id] = TextEditingController(text: c.note);
        }
      }
    });
  }

  void _setVerdict(PredictedClaim claim, ClaimVerdict v) {
    final r = _record!;
    setState(() {
      _record = r.copyWith(
        claims: [
          for (final c in r.claims)
            c.id == claim.id ? c.copyWith(verdict: v) : c,
        ],
      );
      _dirty = true;
    });
  }

  Future<void> _pickActualDate(PredictedClaim claim) async {
    final r = _record!;
    final initial = claim.actualDate ?? claim.windowStart ?? r.createdAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(r.createdAt.year - 100),
      lastDate: DateTime(DateTime.now().year + 100),
      helpText: '实际发生日期',
    );
    if (picked == null) return;
    setState(() {
      _record = r.copyWith(
        claims: [
          for (final c in r.claims)
            c.id == claim.id ? c.copyWith(actualDate: picked) : c,
        ],
      );
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final r = _record;
    if (r == null) return;
    final updated = r.copyWith(
      title: _title.text.trim(),
      outcomeNote: _outcome.text.trim(),
      claims: [
        for (final c in r.claims)
          c.copyWith(note: _notes[c.id]?.text.trim() ?? c.note),
      ],
      lastReviewedAt: DateTime.now(),
    );
    await ref.read(caseRepositoryProvider).save(updated);
    if (!mounted) return;
    setState(() {
      _record = updated;
      _dirty = false;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已保存回填结果')));
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除此案例？'),
        content: const Text('回填的实际结果也会一并删除，且无法恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kPrimaryRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(caseRepositoryProvider).delete(widget.caseId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    final r = _record;
    if (r == null) {
      return const Scaffold(body: Center(child: Text('案例不存在或已删除')));
    }

    final byKind = <ClaimKind, List<PredictedClaim>>{};
    for (final c in r.claims) {
      byKind.putIfAbsent(c.kind, () => []).add(c);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(r.title.isEmpty ? '案例回填' : r.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除案例',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      floatingActionButton: _dirty
          ? FloatingActionButton.extended(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('保存回填'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        children: [
          _header(r),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: '案例名称',
              hintText: '例：客户A · 2026 流年',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() => _dirty = true),
          ),
          const SizedBox(height: 16),
          for (final kind in ClaimKind.values)
            if (byKind[kind] != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(kind.label,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kPrimaryRed)),
              ),
              for (final claim in byKind[kind]!) _claimCard(claim),
            ],
          const SizedBox(height: 16),
          const Text('本期实际情况总述',
              style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _outcome,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '这段时间实际发生了什么？与推演相符或不符之处，'
                  '越具体越便于日后复盘。',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _dirty = true),
          ),
          if (r.aiText.isNotEmpty) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('当时的 AI 批文',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(r.aiText,
                      style: const TextStyle(fontSize: 13, height: 1.7)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _header(CaseRecord r) {
    final rate = r.hitRate;
    return Card(
      color: kPrimaryRed.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.baziString} · ${r.scopeLabel}',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(r.structureSummary,
                style: const TextStyle(fontSize: 12, height: 1.6)),
            const SizedBox(height: 8),
            Text(
              '记录于 ${_fmt(r.createdAt)}｜推演引擎 v${r.engineVersion}'
              '${rate == null ? '' : '｜应验率 ${(rate * 100).round()}%'}',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            if (r.engineVersion != 0) ...[
              const SizedBox(height: 4),
              const Text(
                '回填结果只作复盘之用，不会自动修改命理规则或权重。',
                style: TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _claimCard(PredictedClaim claim) {
    final inWindow = claim.landedInWindow;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(claim.title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                if (claim.polarity != null)
                  Text(claim.polarity!,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54)),
                if (claim.confidence > 0) ...[
                  const SizedBox(width: 8),
                  Text('${(claim.confidence * 100).round()}%',
                      style: const TextStyle(
                          fontSize: 12, color: kGoldAccent)),
                ],
              ],
            ),
            if (claim.windowStart != null && claim.windowEnd != null) ...[
              const SizedBox(height: 4),
              Text('预测窗口：${_fmt(claim.windowStart!)} ~ ${_fmt(claim.windowEnd!)}',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
            if (claim.detail.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(claim.detail,
                  style: const TextStyle(
                      fontSize: 11, height: 1.6, color: Colors.black54)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                for (final v in const [
                  ClaimVerdict.hit,
                  ClaimVerdict.partial,
                  ClaimVerdict.miss,
                  ClaimVerdict.unclear,
                ])
                  ChoiceChip(
                    label: Text(v.label, style: const TextStyle(fontSize: 12)),
                    selected: claim.verdict == v,
                    onSelected: (sel) => _setVerdict(
                        claim, sel ? v : ClaimVerdict.unverified),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _pickActualDate(claim),
                  icon: const Icon(Icons.event, size: 16),
                  label: Text(
                    claim.actualDate == null
                        ? '标记实际发生日期'
                        : '实际：${_fmt(claim.actualDate!)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (inWindow != null)
                  Text(
                    inWindow ? '落在窗口内' : '落在窗口外',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: inWindow ? const Color(0xFF2E7D32) : kPrimaryRed,
                    ),
                  ),
              ],
            ),
            TextField(
              controller: _notes[claim.id],
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: '实际发生了什么？',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() => _dirty = true),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
