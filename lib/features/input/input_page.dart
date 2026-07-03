import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/birth_input.dart';
import '../../providers/birth_input_provider.dart';
import '../../theme.dart';
import '../chart/chart_page.dart';

/// Birth information input form: calendar type, date, time, gender, location.
class InputPage extends ConsumerStatefulWidget {
  const InputPage({super.key});

  @override
  ConsumerState<InputPage> createState() => _InputPageState();
}

class _InputPageState extends ConsumerState<InputPage> {
  CalendarType _calendarType = CalendarType.solar;
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

  @override
  void dispose() {
    _longitudeController.dispose();
    super.dispose();
  }

  int _daysInMonth(int year, int month) {
    if (_calendarType == CalendarType.lunar) return 30; // lunar months: 29/30, engine validates
    return DateTime(year, month + 1, 0).day;
  }

  void _submit() {
    final longitude = double.tryParse(_longitudeController.text);
    if (longitude == null || longitude < -180 || longitude > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的经度（-180 至 180）')),
      );
      return;
    }
    final input = BirthInput(
      calendarType: _calendarType,
      year: _year,
      month: _month,
      day: _day,
      isLeapMonth: _calendarType == CalendarType.lunar && _isLeapMonth,
      hour: _hour,
      minute: _minute,
      gender: _gender,
      location: _city.name,
      longitude: longitude,
    );
    ref.read(birthInputProvider.notifier).state = input;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChartPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final years = List.generate(150, (i) => 1900 + i);
    final months = List.generate(12, (i) => i + 1);
    final days = List.generate(_daysInMonth(_year, _month), (i) => i + 1);
    if (_day > days.length) _day = days.length;

    return Scaffold(
      appBar: AppBar(title: const Text('八字排盘')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionLabel('历法'),
            SegmentedButton<CalendarType>(
              segments: const [
                ButtonSegment(value: CalendarType.solar, label: Text('公历（阳历）')),
                ButtonSegment(value: CalendarType.lunar, label: Text('农历（阴历）')),
              ],
              selected: {_calendarType},
              onSelectionChanged: (s) => setState(() {
                _calendarType = s.first;
                if (_calendarType == CalendarType.solar) _isLeapMonth = false;
              }),
            ),
            const SizedBox(height: 20),
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
            if (_calendarType == CalendarType.lunar)
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
            const SizedBox(height: 20),
            _sectionLabel('性别'),
            SegmentedButton<Gender>(
              segments: const [
                ButtonSegment(value: Gender.male, label: Text('男')),
                ButtonSegment(value: Gender.female, label: Text('女')),
              ],
              selected: {_gender},
              onSelectionChanged: (s) => setState(() => _gender = s.first),
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
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _longitudeController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: '经度（东经为正）',
                helperText: '选择城市自动填入，也可手动修改',
              ),
            ),
            const SizedBox(height: 32),
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
