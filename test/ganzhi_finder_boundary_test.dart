import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/engine/ganzhi_date_finder.dart';
import 'package:bazi_app/core/models/birth_input.dart';

List<GanZhiCandidate> find(
  String yp,
  String mp,
  String dp,
  String hp, {
  Gender gender = Gender.female,
  int fromYear = 1900,
  int toYear = 2049,
}) =>
    GanZhiDateFinder.find(
      yearPillar: yp,
      monthPillar: mp,
      dayPillar: dp,
      hourPillar: hp,
      gender: gender,
      location: '北京',
      longitude: 116.41,
      fromYear: fromYear,
      toYear: toYear,
    );

void main() {
  group('matches on a 节 day are not dropped', () {
    test('丙辰 壬辰 丁巳 癸卯 returns 1976 as well as 2036', () {
      // Reported case. The 辰月 window is [清明, 立夏) and 1976's 立夏 falls on
      // 05-05, so the whole boundary day was skipped — losing a real match at
      // 06:14 that morning, which is still 辰月.
      final labels = find('丙辰', '壬辰', '丁巳', '癸卯')
          .map((c) => c.solarLabel)
          .toList();
      expect(labels, contains('1976-05-05 06:14'));
      expect(labels, contains('2036-04-20 06:14'));
    });

    test('the recovered date really does chart to those pillars', () {
      final chart = ChartService.compute(BirthInput(
        calendarType: CalendarType.solar,
        year: 1976,
        month: 5,
        day: 5,
        hour: 6,
        minute: 14,
        gender: Gender.female,
        location: '北京',
        longitude: 116.41,
      ));
      expect(chart.baziString, '丙辰 壬辰 丁巳 癸卯');
    });
  });

  group('晚子时 births are findable', () {
    test('both halves of 子时 are returned, on their own calendar days', () {
      // 晚子时 carries the *next* day's pillar, so a birth with day pillar 戊子
      // at 晚子时 happened the previous evening. The finder offered 23:30 on
      // the 戊子 day itself, which always charts as the following day and so
      // could never match; and it stopped at the first hit, which was always
      // 早子时.
      final labels = find('庚申', '甲申', '戊子', '壬子',
              gender: Gender.male, fromYear: 2000, toYear: 2049)
          .map((c) => c.solarLabel)
          .toList();
      expect(labels, contains('2040-08-27 23:44')); // 晚子时
      expect(labels, contains('2040-08-28 00:14')); // 早子时
    });

    test('a 晚子时 candidate charts to the pillars it was offered for', () {
      final chart = ChartService.compute(BirthInput(
        calendarType: CalendarType.solar,
        year: 2040,
        month: 8,
        day: 27,
        hour: 23,
        minute: 44,
        gender: Gender.male,
        location: '北京',
        longitude: 116.41,
      ));
      expect(chart.baziString, '庚申 甲申 戊子 壬子');
    });
  });

  group('every candidate is self-consistent', () {
    // Cheap invariant that would have caught a wrong clock time: whatever the
    // finder hands back must chart to exactly what was asked for.
    const cases = [
      ('丙辰', '壬辰', '丁巳', '癸卯'),
      ('乙丑', '己丑', '甲寅', '丙寅'),
      ('庚申', '甲申', '戊子', '壬子'),
      ('壬戌', '辛亥', '己卯', '丁卯'),
    ];

    for (final (yp, mp, dp, hp) in cases) {
      test('$yp $mp $dp $hp', () {
        final results = find(yp, mp, dp, hp, fromYear: 1940, toYear: 2049);
        expect(results, isNotEmpty, reason: 'no candidate found at all');
        for (final c in results) {
          expect(c.baziString, '$yp $mp $dp $hp');
          final chart = ChartService.compute(BirthInput(
            calendarType: CalendarType.solar,
            year: c.year,
            month: c.month,
            day: c.day,
            hour: c.hour,
            minute: c.minute,
            gender: Gender.female,
            location: '北京',
            longitude: 116.41,
          ));
          expect(chart.baziString, '$yp $mp $dp $hp',
              reason: 'candidate ${c.solarLabel} does not chart back');
        }
        // Candidates must be distinct moments.
        final labels = results.map((c) => c.solarLabel).toList();
        expect(labels.length, labels.toSet().length);
      });
    }
  });

  test('a 60-year cycle yields more than one era where the day realigns', () {
    // Guards the general shape of the fix: the year pillar repeats every 60
    // years, so a reachable combination should not collapse to a single hit
    // purely because of a boundary condition.
    final results = find('丙辰', '壬辰', '丁巳', '癸卯');
    expect(results.length, greaterThanOrEqualTo(2));
    final years = results.map((c) => c.year).toSet();
    expect(years, containsAll([1976, 2036]));
  });
}
