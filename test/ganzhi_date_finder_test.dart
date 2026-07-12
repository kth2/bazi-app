import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/engine/ganzhi_date_finder.dart';
import 'package:bazi_app/core/models/birth_input.dart';

void main() {
  group('pillar option helpers', () {
    test('sixty jiazi cycle is complete and ordered', () {
      final jiaZi = GanZhiDateFinder.sixtyJiaZi();
      expect(jiaZi.length, 60);
      expect(jiaZi.toSet().length, 60);
      expect(jiaZi.first, '甲子');
      expect(jiaZi[1], '乙丑');
      expect(jiaZi.last, '癸亥');
    });

    test('五虎遁: month stems follow the year stem', () {
      // 甲己之年丙作首 → 甲年寅月 = 丙寅.
      expect(GanZhiDateFinder.monthPillarsFor('甲').first, '丙寅');
      expect(GanZhiDateFinder.monthPillarsFor('己').first, '丙寅');
      // 乙庚之岁戊为头.
      expect(GanZhiDateFinder.monthPillarsFor('庚').first, '戊寅');
      // 己巳年 (1989/1990 chart) 十一月 = 丙子.
      expect(GanZhiDateFinder.monthPillarsFor('己')[10], '丙子');
      // Branches run 寅..丑.
      final months = GanZhiDateFinder.monthPillarsFor('癸');
      expect(months.map((m) => m[1]).join(), '寅卯辰巳午未申酉戌亥子丑');
    });

    test('五鼠遁: hour stems follow the day stem', () {
      // 甲己还加甲 → 甲日子时 = 甲子.
      expect(GanZhiDateFinder.hourPillarsFor('甲').first, '甲子');
      expect(GanZhiDateFinder.hourPillarsFor('己').first, '甲子');
      // 丙寅日午时 = 甲午 (matches the 1990-01-01 chart).
      expect(GanZhiDateFinder.hourPillarsFor('丙')[6], '甲午');
      // 甲子日巳时 = 己巳 (matches the 1949-10-01 chart).
      expect(GanZhiDateFinder.hourPillarsFor('甲')[5], '己巳');
    });
  });

  group('GanZhiDateFinder.find', () {
    test('recovers 1990-01-01 12:00 from 己巳 丙子 丙寅 甲午', () {
      final found = GanZhiDateFinder.find(
        yearPillar: '己巳',
        monthPillar: '丙子',
        dayPillar: '丙寅',
        hourPillar: '甲午',
        gender: Gender.male,
        location: '北京',
        longitude: 116.41,
      );

      expect(found, isNotEmpty);
      final hit = found.where((c) =>
          c.year == 1990 && c.month == 1 && c.day == 1);
      expect(hit, hasLength(1),
          reason: 'expected the known 1990-01-01 chart among ${found.map((c) => c.solarLabel)}');
      // 午时 midpoint.
      expect(hit.first.hour, 12);
      expect(hit.first.baziString, '己巳 丙子 丙寅 甲午');
    });

    test('recovers 1949-10-01 (巳时) from 己丑 癸酉 甲子 己巳', () {
      final found = GanZhiDateFinder.find(
        yearPillar: '己丑',
        monthPillar: '癸酉',
        dayPillar: '甲子',
        hourPillar: '己巳',
        gender: Gender.male,
        location: '北京',
        longitude: 116.41,
      );

      final hit = found.where(
          (c) => c.year == 1949 && c.month == 10 && c.day == 1);
      expect(hit, hasLength(1));
      expect(hit.first.hour, 10);
      expect(hit.first.baziString, '己丑 癸酉 甲子 己巳');
    });

    test('every candidate round-trips through the chart engine', () {
      final found = GanZhiDateFinder.find(
        yearPillar: '己巳',
        monthPillar: '丙子',
        dayPillar: '丙寅',
        hourPillar: '甲午',
        gender: Gender.female,
        location: '乌鲁木齐', // extreme longitude: true-solar shift ≈ -130min
        longitude: 87.62,
      );
      for (final c in found) {
        final chart = ChartService.compute(BirthInput(
          calendarType: CalendarType.solar,
          year: c.year,
          month: c.month,
          day: c.day,
          hour: c.hour,
          minute: c.minute,
          gender: Gender.female,
          location: '乌鲁木齐',
          longitude: 87.62,
        ));
        expect(chart.baziString, '己巳 丙子 丙寅 甲午');
      }
      // The same combination must still be found despite the western longitude.
      expect(found.any((c) => c.year == 1990 && c.month == 1), isTrue);
    });

    test('impossible combination yields no candidates in a narrow range', () {
      // 甲子年 does not occur between 1985 and 2040 except 2044 — out of range;
      // also 甲子月 cannot follow 甲子年 (甲年子月 is 丙子), so force via valid
      // pillars but a range without the year: 己巳 years are 1929/1989 only.
      final found = GanZhiDateFinder.find(
        yearPillar: '己巳',
        monthPillar: '丙子',
        dayPillar: '丙寅',
        hourPillar: '甲午',
        gender: Gender.male,
        location: '北京',
        longitude: 116.41,
        fromYear: 2000,
        toYear: 2040,
      );
      expect(found, isEmpty);
    });

    test('子时 pillar is matched via 早/晚子时 probing', () {
      // 1990-01-02 00:30 北京 → 己巳 丙子 丁卯 庚子 (early 子时).
      final chart = ChartService.compute(BirthInput(
        calendarType: CalendarType.solar,
        year: 1990,
        month: 1,
        day: 2,
        hour: 0,
        minute: 30,
        gender: Gender.male,
        location: '北京',
        longitude: 116.41,
      ));
      final pillars = chart.baziString.split(' ');
      expect(pillars[3][1], '子', reason: 'sanity: hour branch is 子');

      final found = GanZhiDateFinder.find(
        yearPillar: pillars[0],
        monthPillar: pillars[1],
        dayPillar: pillars[2],
        hourPillar: pillars[3],
        gender: Gender.male,
        location: '北京',
        longitude: 116.41,
      );
      expect(found.any((c) => c.baziString == chart.baziString), isTrue);
    });
  });
}
