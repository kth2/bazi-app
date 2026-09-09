import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/models/birth_input.dart';

void main() {
  group('ChartService.compute (solar)', () {
    // 1949-10-01 10:00 Beijing — known chart: 己丑年 癸酉月 甲子日 己巳时.
    final input = BirthInput(
      calendarType: CalendarType.solar,
      year: 1949,
      month: 10,
      day: 1,
      hour: 10,
      minute: 0,
      gender: Gender.male,
      location: '北京',
      longitude: 116.41,
    );
    final result = ChartService.compute(input);

    test('four pillars match known chart', () {
      expect(result.baziString, '己丑 癸酉 甲子 己巳');
    });

    test('day master and ten gods', () {
      expect(result.dayMaster, '甲');
      expect(result.dayMasterWuXing, '木');
      expect(result.pillars[0].ganShiShen, '正财'); // 己 vs 甲
      expect(result.pillars[1].ganShiShen, '正印'); // 癸 vs 甲
      expect(result.pillars[2].ganShiShen, '日主');
      expect(result.pillars[3].ganShiShen, '正财'); // 己 vs 甲
    });

    test('hidden stems of 酉 month branch', () {
      final monthCangGan = result.pillars[1].cangGan;
      expect(monthCangGan.length, 1);
      expect(monthCangGan.first.gan, '辛');
      expect(monthCangGan.first.shiShen, '正官'); // 辛 vs 甲
    });

    test('da yun runs backward for yin-year male, first decade 壬申', () {
      expect(result.daYunForward, false);
      expect(result.decades.first.ganZhi, '壬申');
      // Enough steps to reach 虚岁 120 for the life timeline; the exact
      // count follows from 起运, so assert the coverage rather than a number.
      expect(result.decades.last.endAge, greaterThanOrEqualTo(120));
      // Consecutive decades are consecutive ganzhi steps backward: 壬申, 辛未...
      expect(result.decades[1].ganZhi, '辛未');
      // Ages are contiguous.
      expect(result.decades[1].startAge, result.decades[0].endAge + 1);
    });

    test('element strength sums to 100% and has a verdict', () {
      final total =
          result.elementStrength.percent.values.fold(0.0, (a, b) => a + b);
      expect(total, closeTo(100.0, 0.01));
      expect(['身强', '身弱', '中和'],
          contains(result.elementStrength.verdict));
    });

    test('kong wang of 甲子 day is 戌亥', () {
      expect(result.kongWang, ['戌', '亥']);
    });

    test('toJson is fully serializable', () {
      final jsonStr = jsonEncode(result.toJson());
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded['bazi'], '己丑 癸酉 甲子 己巳');
      final daYun = decoded['daYun'] as List;
      expect(daYun, isNotEmpty);
      expect((daYun.last as Map)['endAge'], greaterThanOrEqualTo(120));
      expect(decoded['elementStrength']['verdict'], isNotEmpty);
    });
  });

  group('ChartService.compute (lunar)', () {
    test('lunar 1990 正月初一 equals solar 1990-01-27', () {
      final lunar = ChartService.compute(BirthInput(
        calendarType: CalendarType.lunar,
        year: 1990,
        month: 1,
        day: 1,
        hour: 12,
        minute: 0,
        gender: Gender.female,
        location: '上海',
        longitude: 121.47,
      ));
      final solar = ChartService.compute(BirthInput(
        calendarType: CalendarType.solar,
        year: 1990,
        month: 1,
        day: 27,
        hour: 12,
        minute: 0,
        gender: Gender.female,
        location: '上海',
        longitude: 121.47,
      ));
      expect(lunar.baziString, solar.baziString);
      expect(lunar.lunarDate, contains('正月'));
    });
  });

  group('flow timeline', () {
    final result = ChartService.compute(BirthInput(
      calendarType: CalendarType.solar,
      year: 1990,
      month: 6,
      day: 15,
      hour: 8,
      minute: 30,
      gender: Gender.male,
      location: '广州',
      longitude: 113.26,
    ));

    test('flow years cover the decade', () {
      final years = ChartService.flowYearsOf(result, result.decades.first);
      expect(years.length, 10);
      expect(years.first.year, result.decades.first.startYear);
      // 虚岁 consistent with birth year.
      expect(years.first.age, years.first.year - 1990 + 1);
    });

    test('flow months of 2026 are 12 jieqi-bounded months starting 立春', () {
      final months = ChartService.flowMonthsOf(result, 2026);
      expect(months.length, 12);
      expect(months.first.jieName, '立春');
      // 2026 is 丙午 year; 五虎遁 gives 庚寅 first month.
      expect(months.first.ganZhi, '庚寅');
      // Months are contiguous.
      for (var i = 0; i < 11; i++) {
        expect(months[i].end, months[i + 1].start);
      }
    });

    test('flow days fill the month with consecutive ganzhi', () {
      final months = ChartService.flowMonthsOf(result, 2026);
      final days = ChartService.flowDaysOf(result, months.first);
      expect(days.length, inInclusiveRange(28, 31));
      // Consecutive dates.
      expect(
        days[1].date.difference(days[0].date).inDays,
        1,
      );
    });
  });
}
