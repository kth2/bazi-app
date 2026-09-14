import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cases/case_record.dart';
import '../../core/cases/case_statistics.dart';
import '../../providers/case_provider.dart';
import '../../theme.dart';

/// Observed 应验率 — the solid mark.
const Color kObservedColor = kPrimaryRed;

/// Stated confidence — the same hue, one step lighter.
///
/// A two-shade ramp rather than two hues, because the pair is one measure
/// compared against itself, not two identities. Validated against the cream
/// surface: contrast 3.1:1, CVD separation ΔE 17.9, normal-vision ΔE 19.0 —
/// and both ends are directly labelled, so nothing depends on colour alone.
const Color kStatedColor = Color(0xFFB06A6A);

/// 准确率统计 — what the journal says about how the readings have done.
///
/// Read-only by design. Nothing under `core/analysis` may import the case
/// store, so these numbers cannot flow back and adjust the engine; they exist
/// so a person can judge the theory.
class CaseStatsPage extends ConsumerWidget {
  const CaseStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(caseListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('准确率统计')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('读取失败：$e')),
        data: (cases) {
          final stats = CaseStatistics.of(cases);
          if (stats.overall.total == 0) {
            return const _Empty();
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _HeadlineCard(stats: stats),
              const SizedBox(height: 12),
              _CoverageCard(stats: stats),
              if (stats.hasCalibration) ...[
                const SizedBox(height: 12),
                _CalibrationCard(stats: stats),
              ],
              const SizedBox(height: 12),
              _BreakdownCard(
                title: '按条目类型',
                subtitle: '格局判定几乎总是「应验」——它描述的是命盘本身，'
                    '不是一件会发生的事。真正的检验在事件与应期上。',
                rows: [
                  for (final e in stats.byKind.entries)
                    (e.key.label, e.value),
                ],
              ),
              if (stats.byDomain.isNotEmpty) ...[
                const SizedBox(height: 12),
                _BreakdownCard(
                  title: '按事件领域',
                  rows: [
                    for (final e in stats.byDomain.entries) (e.key, e.value),
                  ],
                ),
              ],
              if (stats.byPolarity.isNotEmpty) ...[
                const SizedBox(height: 12),
                _BreakdownCard(
                  title: '按吉凶',
                  subtitle: '这一栏值得单看：若「凶」的命中率明显低于「吉」，'
                      '说明推断偏向往坏处说——本应用为此返工过一次。',
                  rows: [
                    for (final e in stats.byPolarity.entries) (e.key, e.value),
                  ],
                ),
              ],
              if (stats.byScope.length > 1) ...[
                const SizedBox(height: 12),
                _BreakdownCard(
                  title: '按推演范围',
                  rows: [
                    for (final e in stats.byScope.entries) (e.key, e.value),
                  ],
                ),
              ],
              if (stats.timing.dated > 0) ...[
                const SizedBox(height: 12),
                _TimingCard(timing: stats.timing),
              ],
              if (stats.versions.length > 1) ...[
                const SizedBox(height: 12),
                _VersionCard(stats: stats),
              ],
              const SizedBox(height: 12),
              const _CaveatCard(),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '还没有可统计的记录。\n'
            '保存分析后，等推演的时段过去，回到案例库把实际结果填上，'
            '这里就会出现准确率。',
            textAlign: TextAlign.center,
            style: TextStyle(
              height: 1.6,
              color: kInkBlack.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
}

/// The headline number, as a stat tile rather than a one-bar chart.
class _HeadlineCard extends StatelessWidget {
  final CaseStatistics stats;

  const _HeadlineCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final t = stats.overall;
    final enough = CaseStatistics.enough(t);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '总应验率',
              style: TextStyle(
                fontSize: 13,
                color: kInkBlack.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 6),
            if (!enough)
              Text(
                '${t.hit} 中 / ${t.scorable} 已判',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${(t.rate! * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: kObservedColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '严格 ${(t.strictRate! * 100).round()}%',
                    style: TextStyle(
                      fontSize: 15,
                      color: kInkBlack.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              enough
                  ? '应验 ${t.hit} · 部分 ${t.partial} · 未应验 ${t.miss}'
                      '（共 ${t.scorable} 条可判定）'
                  : '样本不足 ${CaseStatistics.kMinSample} 条，'
                      '先给条数而不是百分比——4 条里中 3 条说成 75%，'
                      '是把偶然说成了规律。',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: kInkBlack.withValues(alpha: 0.65),
              ),
            ),
            if (enough) ...[
              const SizedBox(height: 6),
              Text(
                '主数字把「部分应验」记半分；「严格」只算完全应验。两个都给，'
                '是因为半分是个宽松的约定。',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: kInkBlack.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Where the denominator came from — the honesty check on the whole number.
class _CoverageCard extends StatelessWidget {
  final CaseStatistics stats;

  const _CoverageCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final t = stats.overall;
    final unclearShare = t.unclearShare;
    final thin = unclearShare != null && unclearShare > 0.4;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('样本构成',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            _StackedShare(
              segments: [
                (t.scorable, '可判定', kObservedColor),
                (t.unclear, '无法判断', kStatedColor.withValues(alpha: 0.55)),
                (t.unverified, '待回填', kInkBlack.withValues(alpha: 0.18)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '案例 ${stats.cases} 个，其中 ${stats.reviewedCases} 个已全部回填'
              '${stats.dueCases > 0 ? '，${stats.dueCases} 个待回填' : ''}。',
              style: TextStyle(
                fontSize: 12,
                color: kInkBlack.withValues(alpha: 0.65),
              ),
            ),
            if (thin) ...[
              const SizedBox(height: 6),
              Text(
                '已回填的条目里有 ${(unclearShare * 100).round()}% 是「无法判断」。'
                '上面的准确率只算在剩下的那一小部分上，'
                '而「能判断的那些」本身就不是随机挑出来的。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: kPrimaryRed.withValues(alpha: 0.85),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Predicted vs observed per confidence band — a dumbbell per band.
class _CalibrationCard extends StatelessWidget {
  final CaseStatistics stats;

  const _CalibrationCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final bands = [
      for (final b in stats.calibration)
        if (b.tally.scorable > 0) b,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('置信度校准',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              '引擎说的把握度，和实际应验率对不对得上。'
              '这比总准确率更有用：一个 60% 准但排序正确的引擎，'
              '远好过一个 60% 准但纯属碰运气的。',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: kInkBlack.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 12),
            for (final b in bands) ...[
              _CalibrationRow(bucket: b),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                _Swatch(color: kStatedColor, label: '引擎把握度'),
                const SizedBox(width: 14),
                _Swatch(color: kObservedColor, label: '实际应验率'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CalibrationRow extends StatelessWidget {
  final CalibrationBucket bucket;

  const _CalibrationRow({required this.bucket});

  @override
  Widget build(BuildContext context) {
    final observed = bucket.tally.rate;
    final enough = CaseStatistics.enough(bucket.tally);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 74,
              child: Text(bucket.label,
                  style: const TextStyle(fontSize: 12)),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                final w = c.maxWidth;
                final statedX = bucket.meanConfidence.clamp(0.0, 1.0) * w;
                final observedX = (observed ?? 0).clamp(0.0, 1.0) * w;
                return SizedBox(
                  height: 18,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Hairline track — recessive, never dashed.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 8.5,
                        child: Container(
                          height: 1,
                          color: kInkBlack.withValues(alpha: 0.12),
                        ),
                      ),
                      if (observed != null)
                        Positioned(
                          left: statedX < observedX ? statedX : observedX,
                          width: (statedX - observedX).abs(),
                          top: 8,
                          child: Container(
                            height: 2,
                            color: kInkBlack.withValues(alpha: 0.25),
                          ),
                        ),
                      Positioned(
                        left: statedX - 5,
                        top: 4,
                        child: _Dot(color: kStatedColor),
                      ),
                      if (observed != null)
                        Positioned(
                          left: observedX - 5,
                          top: 4,
                          child: _Dot(color: kObservedColor),
                        ),
                    ],
                  ),
                );
              }),
            ),
            SizedBox(
              width: 96,
              child: Text(
                enough && observed != null
                    ? '${(bucket.meanConfidence * 100).round()}% → '
                        '${(observed * 100).round()}%'
                    : 'n=${bucket.tally.scorable}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        if (enough && bucket.gap != null)
          Padding(
            padding: const EdgeInsets.only(left: 74, top: 2),
            child: Text(
              bucket.gap! >= 0
                  ? '实际高于所言 ${(bucket.gap! * 100).round()} 个百分点'
                  : '实际低于所言 ${(-bucket.gap! * 100).round()} 个百分点',
              style: TextStyle(
                fontSize: 11,
                color: kInkBlack.withValues(alpha: 0.55),
              ),
            ),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          // 2px surface ring, so overlapping marks stay readable.
          border: Border.all(color: kPaperCream, width: 2),
        ),
      );
}

class _Swatch extends StatelessWidget {
  final Color color;
  final String label;
  const _Swatch({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: kInkBlack.withValues(alpha: 0.7))),
        ],
      );
}

/// A table with one inline bar per row — one hue for every bar, since these
/// categories have no natural order and a value-ramp would double-encode the
/// length as hue.
class _BreakdownCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<(String, Tally)> rows;

  const _BreakdownCard({
    required this.title,
    required this.rows,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...rows]
      ..sort((a, b) => b.$2.scorable.compareTo(a.$2.scorable));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: kInkBlack.withValues(alpha: 0.65),
                ),
              ),
            ],
            const SizedBox(height: 10),
            for (final (label, tally) in sorted) ...[
              _RateRow(label: label, tally: tally),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  final String label;
  final Tally tally;

  const _RateRow({required this.label, required this.tally});

  @override
  Widget build(BuildContext context) {
    final enough = CaseStatistics.enough(tally);
    final rate = tally.rate;

    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(label,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            return Container(
              height: 8,
              decoration: BoxDecoration(
                color: kInkBlack.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.centerLeft,
              child: rate == null
                  ? null
                  : Container(
                      width: c.maxWidth * rate,
                      height: 8,
                      decoration: BoxDecoration(
                        // One hue for every row; opacity carries "too few to
                        // trust", not the value itself.
                        color:
                            kObservedColor.withValues(alpha: enough ? 1 : 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
            );
          }),
        ),
        SizedBox(
          width: 92,
          child: Text(
            enough && rate != null
                ? '${(rate * 100).round()}%  n=${tally.scorable}'
                : tally.scorable == 0
                    ? '未判定'
                    : 'n=${tally.scorable}',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              color: kInkBlack.withValues(alpha: enough ? 0.85 : 0.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _StackedShare extends StatelessWidget {
  final List<(int, String, Color)> segments;

  const _StackedShare({required this.segments});

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<int>(0, (s, e) => s + e.$1);
    if (total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, c) {
          return SizedBox(
            height: 10,
            child: Row(
              children: [
                for (var i = 0; i < segments.length; i++)
                  if (segments[i].$1 > 0) ...[
                    // 2px surface gap between fills.
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      flex: segments[i].$1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: segments[i].$3,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            for (final s in segments)
              if (s.$1 > 0) _Swatch(color: s.$3, label: '${s.$2} ${s.$1}'),
          ],
        ),
      ],
    );
  }
}

class _TimingCard extends StatelessWidget {
  final TimingTally timing;

  const _TimingCard({required this.timing});

  @override
  Widget build(BuildContext context) {
    final rate = timing.rate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('应期落点',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              '「事情发生了」和「发生在预测的那个窗口里」是两件事，分开看才知道'
              '是哪一半在起作用。只统计填了实际日期的条目。',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: kInkBlack.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              rate == null
                  ? '尚无填了日期的应期条目'
                  : '落在窗口内 ${timing.inWindow} / ${timing.dated}'
                      '（${(rate * 100).round()}%）',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            if (timing.undated > 0) ...[
              const SizedBox(height: 4),
              Text(
                '另有 ${timing.undated} 条已判定但没填实际日期，无法计入。',
                style: TextStyle(
                  fontSize: 11,
                  color: kInkBlack.withValues(alpha: 0.55),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  final CaseStatistics stats;

  const _VersionCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return _BreakdownCard(
      title: '按引擎版本',
      subtitle: '推理引擎改过多次。第 4 版做出的判断，是关于第 4 版的证据；'
          '和第 ${stats.versions.first} 版平均在一起，等于把两个程序的成绩混着算。',
      rows: [
        for (final v in stats.versions)
          ('v$v', stats.byEngineVersion[v] ?? const Tally()),
      ],
    );
  }
}

class _CaveatCard extends StatelessWidget {
  const _CaveatCard();

  @override
  Widget build(BuildContext context) {
    const points = [
      '记录和评判都由你自己做。人倾向于把模糊的话记成说中了——'
          '这是这类统计最大的误差来源，没有办法从程序里修掉。',
      '只有「能判断」的条目进分母。「无法判断」被排除而不是记为错，'
          '这对准确率是有利的。',
      '没有基准率对照。「事业会有变动」这种话本身命中率就很高，'
          '高分未必来自推断有效。要判断这一点，得和一个随便说的对照组比。',
      '「部分应验」记半分，是个宽松约定。所以严格值也一并给出。',
      '这些数字不会回流到引擎里。理论固定，推演结构化；'
          '历史结果是拿来给人判断理论的，不是拿来让程序改自己的。',
    ];

    return Card(
      color: kInkBlack.withValues(alpha: 0.03),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('这些数字能说明什么，不能说明什么',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '· $p',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: kInkBlack.withValues(alpha: 0.7),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
