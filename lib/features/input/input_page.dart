import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/engine/ganzhi_date_finder.dart';
import '../../core/models/birth_input.dart';
import '../../providers/birth_input_provider.dart';
import '../../providers/case_provider.dart';
import '../../theme.dart';
import '../cases/case_list_page.dart';
import '../chart/chart_page.dart';

/// How the birth moment is entered: by calendar date (default) or by the
/// four pillars directly (干支历), for users who already know their 八字.
enum _EntryMode { solar, lunar, ganZhi }

/// Birth information input form: calendar type, date, time, gender, location.
class InputPage extends ConsumerStatefulWidget {
  const InputPage({super.key});

  @override
  ConsumerState<InputPage> createState() => _InputPageState();
}

class _InputPageState extends ConsumerState<InputPage> {
  _EntryMode _mode = _EntryMode.solar;
  int _year = 1990;
  int _month = 1;
  int _day = 1;
  bool _isLeapMonth = false;
  int _hour = 12;
  int _minute = 0;
  Gender _gender = Gender.male;
  CityPreset _city = kCityPresets.first;
  final _longitudeController = TextEditingController(
    text: kCityPresets.first.longitude.toStringAsFixed(2),
  );

  // 干支 mode: selected pillars. Month/hour stored as an index into the 12
  // valid combos so the branch selection survives a year/day stem change.
  String _yearPillar = '甲子';
  int _monthPillarIndex = 0;
  String _dayPillar = '甲子';
  int _hourPillarIndex = 0;
  List<GanZhiCandidate>? _candidates; // null = not searched yet
  bool _searching = false;

  @override
  void dispose() {
    _longitudeController.dispose();
    super.dispose();
  }

  int _daysInMonth(int year, int month) {
    if (_mode == _EntryMode.lunar) return 30; // lunar months: 29/30, engine validates
    return DateTime(year, month + 1, 0).day;
  }

  double? _validLongitude() {
    final longitude = double.tryParse(_longitudeController.text);
    if (longitude == null || longitude < -180 || longitude > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的经度（-180 至 180）')),
      );
      return null;
    }
    return longitude;
  }

  void _submit() {
    final longitude = _validLongitude();
    if (longitude == null) return;
    final input = BirthInput(
      calendarType:
          _mode == _EntryMode.lunar ? CalendarType.lunar : CalendarType.solar,
      year: _year,
      month: _month,
      day: _day,
      isLeapMonth: _mode == _EntryMode.lunar && _isLeapMonth,
      hour: _hour,
      minute: _minute,
      gender: _gender,
      location: _city.name,
      longitude: longitude,
    );
    _openChart(input);
  }

  void _openChart(BirthInput input) {
    ref.read(birthInputProvider.notifier).state = input;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChartPage()),
    );
  }

  Future<void> _searchGanZhi() async {
    final longitude = _validLongitude();
    if (longitude == null) return;
    setState(() {
      _searching = true;
      _candidates = null;
    });
    // Let the spinner paint before the synchronous search.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final found = GanZhiDateFinder.find(
      yearPillar: _yearPillar,
      monthPillar: GanZhiDateFinder.monthPillarsFor(
          _yearPillar[0])[_monthPillarIndex],
      dayPillar: _dayPillar,
      hourPillar:
          GanZhiDateFinder.hourPillarsFor(_dayPillar[0])[_hourPillarIndex],
      gender: _gender,
      location: _city.name,
      longitude: longitude,
    );
    if (!mounted) return;
    setState(() {
      _candidates = found;
      _searching = false;
    });
  }

  void _useCandidate(GanZhiCandidate c) {
    final longitude = _validLongitude();
    if (longitude == null) return;
    _openChart(BirthInput(
      calendarType: CalendarType.solar,
      year: c.year,
      month: c.month,
      day: c.day,
      hour: c.hour,
      minute: c.minute,
      gender: _gender,
      location: _city.name,
      longitude: longitude,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('八字排盘'),
        actions: [
          Consumer(builder: (context, ref, _) {
            final due = ref.watch(dueCaseCountProvider);
            return IconButton(
              tooltip: due > 0 ? '案例库（$due 条待回填）' : '案例库',
              icon: Badge(
                isLabelVisible: due > 0,
                label: Text('$due'),
                child: const Icon(Icons.inventory_2_outlined),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CaseListPage()),
              ),
            );
          }),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionLabel('历法'),
            SegmentedButton<_EntryMode>(
              segments: const [
                ButtonSegment(value: _EntryMode.solar, label: Text('公历')),
                ButtonSegment(value: _EntryMode.lunar, label: Text('农历')),
                ButtonSegment(value: _EntryMode.ganZhi, label: Text('干支')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() {
                _mode = s.first;
                if (_mode != _EntryMode.lunar) _isLeapMonth = false;
              }),
            ),
            const SizedBox(height: 20),
            if (_mode == _EntryMode.ganZhi)
              ..._buildGanZhiFields()
            else
              ..._buildDateFields(),
            const SizedBox(height: 20),
            _sectionLabel('性别'),
            SegmentedButton<Gender>(
              segments: const [
                ButtonSegment(value: Gender.male, label: Text('男')),
                ButtonSegment(value: Gender.female, label: Text('女')),
              ],
              selected: {_gender},
              onSelectionChanged: (s) => setState(() {
                _gender = s.first;
                _candidates = null;
              }),
            ),
            const SizedBox(height: 20),
            _sectionLabel('出生地点（用于真太阳时）'),
            _dropdown<CityPreset>(
              label: '城市',
              value: _city,
              items: kCityPresets,
              display: (c) => c.name,
              onChanged: (v) => setState(() {
                _city = v;
                _longitudeController.text = v.longitude.toStringAsFixed(2);
                _candidates = null;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _longitudeController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
              onChanged: (_) {
                if (_candidates != null) setState(() => _candidates = null);
              },
              decoration: const InputDecoration(
                labelText: '经度（东经为正）',
                helperText: '选择城市自动填入，也可手动修改',
              ),
            ),
            const SizedBox(height: 32),
            if (_mode == _EntryMode.ganZhi) ...[
              FilledButton.icon(
                icon: _searching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: kPaperCream))
                    : const Icon(Icons.search),
                label: Text(_searching ? '查找中…' : '查找匹配日期'),
                onPressed: _searching ? null : _searchGanZhi,
              ),
              if (_candidates != null) ...[
                const SizedBox(height: 16),
                ..._buildCandidateList(),
              ],
            ] else
              FilledButton(
                onPressed: _submit,
                child: const Text('排 盘'),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDateFields() {
    final years = List.generate(150, (i) => 1900 + i);
    final months = List.generate(12, (i) => i + 1);
    final days = List.generate(_daysInMonth(_year, _month), (i) => i + 1);
    if (_day > days.length) _day = days.length;

    return [
      _sectionLabel('出生日期'),
      Row(
        children: [
          Expanded(
            flex: 3,
            child: _dropdown<int>(
              label: '年',
              value: _year,
              items: years,
              display: (y) => '$y',
              onChanged: (v) => setState(() => _year = v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _dropdown<int>(
              label: '月',
              value: _month,
              items: months,
              display: (m) => '$m',
              onChanged: (v) => setState(() => _month = v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _dropdown<int>(
              label: '日',
              value: _day,
              items: days,
              display: (d) => '$d',
              onChanged: (v) => setState(() => _day = v),
            ),
          ),
        ],
      ),
      if (_mode == _EntryMode.lunar)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('闰月'),
          value: _isLeapMonth,
          onChanged: (v) => setState(() => _isLeapMonth = v),
        ),
      const SizedBox(height: 20),
      _sectionLabel('出生时间'),
      Row(
        children: [
          Expanded(
            child: _dropdown<int>(
              label: '时',
              value: _hour,
              items: List.generate(24, (i) => i),
              display: (h) => h.toString().padLeft(2, '0'),
              onChanged: (v) => setState(() => _hour = v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _dropdown<int>(
              label: '分',
              value: _minute,
              items: List.generate(60, (i) => i),
              display: (m) => m.toString().padLeft(2, '0'),
              onChanged: (v) => setState(() => _minute = v),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildGanZhiFields() {
    final monthPillars = GanZhiDateFinder.monthPillarsFor(_yearPillar[0]);
    final hourPillars = GanZhiDateFinder.hourPillarsFor(_dayPillar[0]);
    final jiaZi = GanZhiDateFinder.sixtyJiaZi();

    return [
      _sectionLabel('四柱干支'),
      Text(
        '直接输入已知的八字四柱，无需查干支历。月柱/时柱选项随年干/日干自动遁出，'
        '查找会列出 1900-2049 年间所有符合的公历日期。',
        style: TextStyle(
            fontSize: 12, color: kInkBlack.withValues(alpha: 0.55)),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _dropdown<String>(
              label: '年柱',
              value: _yearPillar,
              items: jiaZi,
              display: (g) => g,
              onChanged: (v) => setState(() {
                _yearPillar = v;
                _candidates = null;
              }),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _dropdown<int>(
              label: '月柱',
              value: _monthPillarIndex,
              items: List.generate(12, (i) => i),
              display: (i) => monthPillars[i],
              onChanged: (v) => setState(() {
                _monthPillarIndex = v;
                _candidates = null;
              }),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _dropdown<String>(
              label: '日柱',
              value: _dayPillar,
              items: jiaZi,
              display: (g) => g,
              onChanged: (v) => setState(() {
                _dayPillar = v;
                _candidates = null;
              }),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _dropdown<int>(
              label: '时柱',
              value: _hourPillarIndex,
              items: List.generate(12, (i) => i),
              display: (i) => hourPillars[i],
              onChanged: (v) => setState(() {
                _hourPillarIndex = v;
                _candidates = null;
              }),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildCandidateList() {
    final cs = _candidates!;
    if (cs.isEmpty) {
      return [
        Text(
          '1900-2049 年间未找到符合这四柱的日期，请核对干支组合。',
          style: const TextStyle(fontSize: 13, color: kPrimaryRed),
          textAlign: TextAlign.center,
        ),
      ];
    }
    return [
      _sectionLabel('匹配日期（点选排盘）'),
      Text(
        '时辰内的具体时刻按时辰正中推算，如已知准确时间可改用公历输入。',
        style:
            TextStyle(fontSize: 12, color: kInkBlack.withValues(alpha: 0.55)),
      ),
      const SizedBox(height: 8),
      for (final c in cs)
        Card(
          child: ListTile(
            leading: const Icon(Icons.event_available, color: kPrimaryRed),
            title: Text('公历 ${c.solarLabel}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(c.baziString),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _useCandidate(c),
          ),
        ),
    ];
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: kPrimaryRed,
                fontWeight: FontWeight.w600,
              ),
        ),
      );

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) display,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final item in items)
          DropdownMenuItem(value: item, child: Text(display(item))),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
