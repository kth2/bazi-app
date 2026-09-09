import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/engine/chart_service.dart';
import '../../core/models/chart_result.dart';
import '../../providers/chart_provider.dart';
import '../../theme.dart';
import '../ai/ai_analysis_page.dart';
import '../analysis/analysis_page.dart';
import '../settings/settings_sheet.dart';
import '../timeline/timeline_page.dart';

/// Chart display: four pillars, 五行力量, interactions,
/// and the 大运 → 流年 → 流月 → 流日 drill-down.
class ChartPage extends ConsumerStatefulWidget {
  const ChartPage({super.key});

  @override
  ConsumerState<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends ConsumerState<ChartPage> {
  DecadeData? _selectedDecade;
  FlowYearData? _selectedYear;
  FlowMonthData? _selectedMonth;
  FlowDayData? _selectedDay;
  List<FlowYearData> _flowYears = [];
  List<FlowMonthData> _flowMonths = [];
  List<FlowDayData> _flowDays = [];

  void _selectDecade(ChartResult result, DecadeData d) {
    setState(() {
      _selectedDecade = d;
      _flowYears = ChartService.flowYearsOf(result, d);
      _selectedYear = null;
      _flowMonths = [];
      _selectedMonth = null;
      _flowDays = [];
      _selectedDay = null;
    });
  }

  void _selectYear(ChartResult result, FlowYearData y) {
    setState(() {
      _selectedYear = y;
      _flowMonths = ChartService.flowMonthsOf(result, y.year);
      _selectedMonth = null;
      _flowDays = [];
      _selectedDay = null;
    });
  }

  void _selectMonth(ChartResult result, FlowMonthData m) {
    setState(() {
      _selectedMonth = m;
      _flowDays = ChartService.flowDaysOf(result, m);
      _selectedDay = null;
    });
  }

  void _selectDay(FlowDayData d) {
    setState(() {
      _selectedDay = _selectedDay?.date == d.date ? null : d;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(chartResultProvider);
    if (result == null) {
      return const Scaffold(body: Center(child: Text('尚未排盘')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('命盘 · ${result.baziString}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'AI 设置',
            onPressed: () => showAiSettingsSheet(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildBirthInfoCard(result),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.auto_stories),
            label: const Text('命理分析'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AnalysisPage()),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.timeline),
            label: const Text('人生时间线（0-120 岁）'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TimelinePage()),
            ),
          ),
          const SizedBox(height: 12),
          _buildPillarsCard(result),
          const SizedBox(height: 12),
          _buildElementCard(result),
          if (result.interactions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInteractionsCard(result),
          ],
          const SizedBox(height: 12),
          _buildLuckCard(result),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBirthInfoCard(ChartResult r) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${r.input.gender.name == 'male' ? '男命' : '女命'} · ${r.input.location}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text('公历：${r.solarDate}'),
            Text('真太阳时：${r.trueSolarTime}'),
            Text(r.lunarDate),
            Text('${r.qiYunDescription}，大运${r.daYunForward ? "顺行" : "逆行"}'),
            Text('命宫 ${r.mingGong} · 身宫 ${r.shenGong} · 胎元 ${r.taiYuan} · '
                '空亡 ${r.kongWang.join("")}'),
          ],
        ),
      ),
    );
  }

  Widget _buildPillarsCard(ChartResult r) {
    Color elementColor(String wuXing) => kElementColors[wuXing] ?? kInkBlack;

    Widget cell(Widget child) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Center(child: child),
        );

    Widget headerCell(String text) => cell(Text(
          text,
          style: TextStyle(color: kInkBlack.withValues(alpha: 0.5), fontSize: 12),
        ));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Table(
          columnWidths: const {0: FixedColumnWidth(52)},
          children: [
            TableRow(children: [
              headerCell(''),
              for (final p in r.pillars) headerCell(p.position),
            ]),
            TableRow(children: [
              headerCell('十神'),
              for (final p in r.pillars)
                cell(Text(p.ganShiShen, style: const TextStyle(fontSize: 13))),
            ]),
            TableRow(children: [
              headerCell('天干'),
              for (final p in r.pillars)
                cell(Text(
                  p.gan,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: elementColor(p.ganWuXing),
                  ),
                )),
            ]),
            TableRow(children: [
              headerCell('地支'),
              for (final p in r.pillars)
                cell(Text(
                  '${p.zhi}${p.isKongWang ? "○" : ""}',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: elementColor(p.zhiWuXing),
                  ),
                )),
            ]),
            TableRow(children: [
              headerCell('藏干'),
              for (final p in r.pillars)
                cell(Column(
                  children: [
                    for (final c in p.cangGan)
                      Text(
                        '${c.gan} ${c.shiShen}',
                        style: TextStyle(
                          fontSize: 12,
                          color: elementColor(c.wuXing),
                        ),
                      ),
                  ],
                )),
            ]),
            TableRow(children: [
              headerCell('星运'),
              for (final p in r.pillars)
                cell(Text(p.lifeStage, style: const TextStyle(fontSize: 13))),
            ]),
            TableRow(children: [
              headerCell('纳音'),
              for (final p in r.pillars)
                cell(Text(p.naYin, style: const TextStyle(fontSize: 12))),
            ]),
            TableRow(children: [
              headerCell('神煞'),
              for (final p in r.pillars)
                cell(Column(
                  children: [
                    if (p.shenSha.isEmpty)
                      const Text('—', style: TextStyle(fontSize: 12))
                    else
                      for (final s in p.shenSha)
                        Text(s, style: const TextStyle(fontSize: 12)),
                  ],
                )),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildElementCard(ChartResult r) {
    final es = r.elementStrength;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('五行力量',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: kPrimaryRed, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final e in ['木', '火', '土', '金', '水'])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Text(e,
                        style: TextStyle(
                          color: kElementColors[e],
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (es.percent[e] ?? 0) / 100,
                          minHeight: 10,
                          backgroundColor: kInkBlack.withValues(alpha: 0.08),
                          valueColor:
                              AlwaysStoppedAnimation(kElementColors[e]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${es.percent[e]?.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '日主${r.dayMaster}${r.dayMasterWuXing}，月令${es.dayMasterSeasonState}，'
              '同党 ${es.supportPercent.toStringAsFixed(1)}% → ${es.verdict}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionsCard(ChartResult r) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('刑冲合害',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: kPrimaryRed, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final i in r.interactions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${i.type}：${i.parties.join("、")}'
                  '${i.combinedWuXing != null ? " → 化${i.combinedWuXing}" : ""}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLuckCard(ChartResult r) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('大运',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: kPrimaryRed, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 96,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final d in r.decades)
                    _luckChip(
                      selected: _selectedDecade?.index == d.index,
                      onTap: () => _selectDecade(r, d),
                      lines: [
                        '${d.startAge}-${d.endAge}岁',
                        d.ganZhi,
                        d.ganShiShen,
                      ],
                      big: 1,
                    ),
                ],
              ),
            ),
            if (_selectedDecade != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                    'AI 分析此大运（${_selectedDecade!.ganZhi} '
                    '${_selectedDecade!.startAge}-${_selectedDecade!.endAge}岁）'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AiAnalysisPage(decade: _selectedDecade),
                  ),
                ),
              ),
            ],
            if (_flowYears.isNotEmpty) ...[
              const Divider(),
              Text('流年（${_selectedDecade!.ganZhi}运）',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final y in _flowYears)
                      _luckChip(
                        selected: _selectedYear?.year == y.year,
                        onTap: () => _selectYear(r, y),
                        lines: ['${y.year}', y.ganZhi, '${y.age}岁 ${y.ganShiShen}'],
                        big: 1,
                      ),
                  ],
                ),
              ),
            ],
            if (_selectedYear != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                    'AI 分析此流年（${_selectedYear!.year} ${_selectedYear!.ganZhi}）'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AiAnalysisPage(
                      decade: _selectedDecade,
                      year: _selectedYear,
                    ),
                  ),
                ),
              ),
            ],
            if (_flowMonths.isNotEmpty) ...[
              const Divider(),
              Text('流月（${_selectedYear!.year}年）',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final m in _flowMonths)
                      _luckChip(
                        selected: _selectedMonth?.monthIndex == m.monthIndex,
                        onTap: () => _selectMonth(r, m),
                        lines: [
                          m.jieName,
                          m.ganZhi,
                          '${m.start.month}/${m.start.day}起',
                        ],
                        big: 1,
                      ),
                  ],
                ),
              ),
            ],
            if (_selectedMonth != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                    'AI 分析此流月（${_selectedMonth!.ganZhi}月 '
                    '${_selectedMonth!.jieName}起）'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AiAnalysisPage(
                      decade: _selectedDecade,
                      year: _selectedYear,
                      month: _selectedMonth,
                    ),
                  ),
                ),
              ),
            ],
            if (_flowDays.isNotEmpty) ...[
              const Divider(),
              Text('流日（${_selectedMonth!.ganZhi}月，点选可 AI 分析当日）',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in _flowDays) _dayChip(d),
                ],
              ),
            ],
            if (_selectedDay != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                    'AI 分析此流日（${_selectedDay!.date.month}/${_selectedDay!.date.day} '
                    '${_selectedDay!.ganZhi}）'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AiAnalysisPage(
                      decade: _selectedDecade,
                      year: _selectedYear,
                      month: _selectedMonth,
                      day: _selectedDay,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dayChip(FlowDayData d) {
    final selected = _selectedDay?.date == d.date;
    return GestureDetector(
      onTap: () => _selectDay(d),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? kPrimaryRed : Colors.white,
          border: Border.all(
            color: selected ? kPrimaryRed : kInkBlack.withValues(alpha: 0.15),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text('${d.date.month}/${d.date.day}',
                style: TextStyle(
                  fontSize: 11,
                  color: selected
                      ? kPaperCream.withValues(alpha: 0.8)
                      : kInkBlack.withValues(alpha: 0.5),
                )),
            Text(d.ganZhi,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? kPaperCream : kInkBlack,
                )),
          ],
        ),
      ),
    );
  }

  Widget _luckChip({
    required bool selected,
    required VoidCallback onTap,
    required List<String> lines,
    required int big, // index of the line to emphasize (ganzhi)
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kPrimaryRed : Colors.white,
          border: Border.all(
            color: selected ? kPrimaryRed : kInkBlack.withValues(alpha: 0.15),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < lines.length; i++)
              Text(
                lines[i],
                style: TextStyle(
                  fontSize: i == big ? 17 : 11,
                  fontWeight: i == big ? FontWeight.w700 : FontWeight.w400,
                  color: selected
                      ? kPaperCream
                      : (i == big
                          ? kInkBlack
                          : kInkBlack.withValues(alpha: 0.55)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
