import 'package:sxwnl_spa_dart/sxwnl_spa_dart.dart';

import '../models/birth_input.dart';
import 'chart_service.dart';

/// One solar birth date/time whose computed chart reproduces the four
/// pillars the user typed in.
class GanZhiCandidate {
  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final String baziString; // verified against ChartService.compute
  final String solarLabel; // e.g. 1990-01-01 12:00

  const GanZhiCandidate({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.baziString,
    required this.solarLabel,
  });
}

/// Reverse lookup: four pillars (干支历) → matching solar birth dates, so
/// users who already know their 八字 don't need to consult a calendar.
///
/// The hour pillar only pins the birth to a 时辰 (2-hour window); candidates
/// use the middle of that window as a representative clock time. Every
/// candidate is verified by running the real chart engine, so 节气
/// boundaries, true solar time and 早/晚子时 handling always agree with what
/// the app will actually chart.
class GanZhiDateFinder {
  static const String kGan = '甲乙丙丁戊己庚辛壬癸';
  static const String kZhi = '子丑寅卯辰巳午未申酉戌亥';

  /// All 60 甲子 in cycle order (甲子, 乙丑, … 癸亥).
  static List<String> sixtyJiaZi() => [
        for (var i = 0; i < 60; i++) '${kGan[i % 10]}${kZhi[i % 12]}',
      ];

  /// The 12 month pillars possible in a year whose stem is [yearGan]
  /// (五虎遁: 甲己之年丙作首…), 寅月 first.
  static List<String> monthPillarsFor(String yearGan) {
    final start = (kGan.indexOf(yearGan) % 5) * 2 + 2; // 寅月 stem
    return [
      for (var i = 0; i < 12; i++)
        '${kGan[(start + i) % 10]}${kZhi[(i + 2) % 12]}',
    ];
  }

  /// The 12 hour pillars possible on a day whose stem is [dayGan]
  /// (五鼠遁: 甲己还加甲…), 子时 first.
  static List<String> hourPillarsFor(String dayGan) {
    final start = (kGan.indexOf(dayGan) % 5) * 2; // 子时 stem
    return [
      for (var i = 0; i < 12; i++) '${kGan[(start + i) % 10]}${kZhi[i]}',
    ];
  }

  /// Search [fromYear]..[toYear] for solar dates matching the four pillars.
  /// Usually 0-3 hits: the year pillar repeats every 60 years and the day
  /// pillar rarely realigns with the same month window.
  static List<GanZhiCandidate> find({
    required String yearPillar,
    required String monthPillar,
    required String dayPillar,
    required String hourPillar,
    required Gender gender,
    required String location,
    required double longitude,
    int fromYear = 1900,
    int toYear = 2049,
  }) {
    final candidates = <GanZhiCandidate>[];
    final target = '$yearPillar $monthPillar $dayPillar $hourPillar';

    for (var y = fromYear; y <= toYear; y++) {
      if (yearGanZhi(y).toString() != yearPillar) continue;

      final window = _monthWindow(y, monthPillar);
      if (window == null) continue;

      // Days whose ganzhi matches. Both boundary days are included: a 节
      // falls at a clock time, not at midnight, so the day it lands on is
      // split between two months and a birth earlier that day still belongs
      // to this one. Excluding it dropped every match on a 节 day — the
      // reported case, 1976-05-05 06:14 丙辰 壬辰 丁巳 癸卯, sits on the
      // morning of 立夏. Times that really fall outside the window are
      // rejected below by charting them, so including the day is safe.
      final startIdx = (window.$1.toJulianDay() + 0.5).floor();
      final endIdx = (window.$2.toJulianDay() + 0.5).floor();
      for (var i = startIdx; i <= endIdx; i++) {
        final adt = AstroDateTime.fromJulianDay(i.toDouble());
        if (dayGanZhi(adt).toString() != dayPillar) continue;

        for (final clock in _clockTimesFor(
            DateTime(adt.year, adt.month, adt.day), hourPillar, longitude)) {
          final input = BirthInput(
            calendarType: CalendarType.solar,
            year: clock.year,
            month: clock.month,
            day: clock.day,
            hour: clock.hour,
            minute: clock.minute,
            gender: gender,
            location: location,
            longitude: longitude,
          );
          try {
            final chart = ChartService.compute(input);
            if (chart.baziString == target) {
              candidates.add(GanZhiCandidate(
                year: clock.year,
                month: clock.month,
                day: clock.day,
                hour: clock.hour,
                minute: clock.minute,
                baziString: chart.baziString,
                solarLabel: '${clock.year}-'
                    '${clock.month.toString().padLeft(2, '0')}-'
                    '${clock.day.toString().padLeft(2, '0')} '
                    '${clock.hour.toString().padLeft(2, '0')}:'
                    '${clock.minute.toString().padLeft(2, '0')}',
              ));
              // No break: for 子时 the two halves are different birth moments
              // on different calendar days (早子时 that morning, 晚子时 the
              // previous evening) and the user needs both. Every other 时辰
              // yields a single candidate time, so nothing else is affected.
            }
          } catch (_) {
            // Out-of-range dates for the astronomical engine: skip.
          }
        }
      }
    }
    return candidates;
  }

  /// [start, end) of the jieqi-bounded month with pillar [monthPillar] in
  /// ganzhi year [y] (立春 of y through 立春 of y+1; 子/丑月 spill into the
  /// next calendar year).
  static (AstroDateTime, AstroDateTime)? _monthWindow(
      int y, String monthPillar) {
    final monthGanZhi = getYearMonthGanZhi(yearGanZhi(y).gan);
    var index = -1;
    for (var i = 0; i < 12; i++) {
      if (monthGanZhi[i].toString() == monthPillar) {
        index = i;
        break;
      }
    }
    if (index < 0) return null;

    final liChunJd = getSpecificJieQi(y, 21);
    var boundary = AstroDateTime.fromJ2000(liChunJd);
    for (var i = 0; i < index; i++) {
      final next = getNextJie(boundary);
      if (next == null) return null;
      boundary = next.dateTime;
    }
    final end = getNextJie(boundary);
    if (end == null) return null;
    return (boundary, end.dateTime);
  }

  /// Candidate clock times whose *true solar time* lands mid-时辰 on [day],
  /// where [day] is the day carrying the target **day pillar**.
  ///
  /// Compensates the longitude offset so far-west/east locations still fall
  /// inside the window (equation of time ±16min < the 60min margin left).
  ///
  /// 子时 straddles midnight and needs both halves. 早子时 (00:00) sits on
  /// [day] itself, but 晚子时 belongs to the *next* day's pillar — so a birth
  /// carrying [day]'s pillar at 晚子时 happened at 23:30 the evening **before**
  /// [day], expressed here as −30 minutes. Offering 23:30 on [day] instead,
  /// as this did, produced a time that always charts as the following day's
  /// pillar and therefore never matched: every 晚子时 birth was unfindable.
  static Iterable<DateTime> _clockTimesFor(
      DateTime day, String hourPillar, double longitude) {
    final branch = kZhi.indexOf(hourPillar[1]);
    final lonOffsetMin = ((longitude - 120) * 4).round();
    final desired = branch == 0
        ? [0, -30] // 早子时 00:00 / 晚子时 23:30 the previous evening
        : [branch * 120]; // window midpoint, e.g. 丑 02:00
    return desired.map(
        (m) => day.add(Duration(minutes: m - lonOffsetMin)));
  }
}
