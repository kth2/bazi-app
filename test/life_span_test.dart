import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/models/birth_input.dart';
import 'package:bazi_app/core/models/chart_result.dart';
import 'package:bazi_app/core/timeline/life_span.dart';

ChartResult chartOf(int y, int m, int d, int h, int min, Gender g) =>
    ChartService.compute(BirthInput(
      calendarType: CalendarType.solar,
      year: y,
      month: m,
      day: d,
      hour: h,
      minute: min,
      gender: g,
      location: '北京',
      longitude: 116.41,
    ));

/// A spread of 起运 ages and both directions, since 起运 is what decides
/// where the 小运期 ends and whether 12 steps really reach 120.
final samples = <String, ChartResult>{
  '丙辰 壬辰 丁巳 癸卯 (女, 起运10.1)': chartOf(1976, 5, 5, 6, 14, Gender.female),
  '己巳 丙子 丙寅 甲午 (男, 起运8.3)': chartOf(1990, 1, 1, 12, 0, Gender.male),
  '己丑 癸酉 甲子 己巳 (男)': chartOf(1949, 10, 1, 10, 0, Gender.male),
  '辛酉 庚子 癸亥 壬子 (女)': chartOf(1981, 12, 11, 1, 0, Gender.female),
};

void main() {
  group('the axis covers a full 两甲子', () {
    test('12 decades reach age 120 on every sample', () {
      for (final entry in samples.entries) {
        final span = LifeSpan.of(entry.value);
        expect(span.decades, isNotEmpty, reason: entry.key);
        expect(span.decades.last.endAge, greaterThanOrEqualTo(LifeSpan.kMaxAge),
            reason: '${entry.key}: last decade ends at '
                '${span.decades.last.endAge}, short of 120');
      }
    });

    test('every age 1..120 has exactly one 流年, with no gaps', () {
      for (final entry in samples.entries) {
        final span = LifeSpan.of(entry.value);
        expect(span.isContiguous, isTrue,
            reason: '${entry.key}: ${span.years.length} years, '
                'first=${span.years.first.age} last=${span.years.last.age}');
        expect(span.years.length, 120, reason: entry.key);
      }
    });

    test('nothing on the axis runs past 120', () {
      for (final entry in samples.entries) {
        final span = LifeSpan.of(entry.value);
        expect(span.years.last.age, LifeSpan.kMaxAge, reason: entry.key);
        for (final d in span.decades) {
          final (start, end) = span.boundsOf(d);
          expect(end, lessThanOrEqualTo(120.0), reason: entry.key);
          expect(start, greaterThanOrEqualTo(0.0), reason: entry.key);
        }
      }
    });
  });

  group('虚岁 ↔ 公历年', () {
    test('age 1 is the birth year', () {
      final span = LifeSpan.of(samples.values.first);
      expect(span.birthYear, 1976);
      expect(span.calendarYearAt(1), 1976);
      expect(span.calendarYearAt(11), 1986);
      expect(span.ageInCalendarYear(1976), 1);
      expect(span.ageInCalendarYear(2026), 51);
    });

    test('the two conversions are inverses across the whole span', () {
      for (final chart in samples.values) {
        final span = LifeSpan.of(chart);
        for (var age = 1; age <= 120; age++) {
          expect(span.ageInCalendarYear(span.calendarYearAt(age.toDouble())), age);
        }
      }
    });

    test('the 流年 at an age carries that age and calendar year', () {
      for (final chart in samples.values) {
        final span = LifeSpan.of(chart);
        for (var age = 1; age <= 120; age += 7) {
          final y = span.yearAt(age.toDouble())!;
          expect(y.age, age);
          expect(y.year, span.calendarYearAt(age.toDouble()));
        }
      }
    });
  });

  group('大运 lookup', () {
    test('小运期 has no 大运, and ends exactly at 起运', () {
      final span = LifeSpan.of(samples.values.first); // 起运 age 11
      expect(span.firstDecadeAge, 11);
      expect(span.isPreDaYun(10), isTrue);
      expect(span.decadeAt(10), isNull);
      expect(span.isPreDaYun(11), isFalse);
      expect(span.decadeAt(11), isNotNull);
      expect(span.decadeAt(11)!.startAge, 11);
    });

    test('endAge is inclusive — the decade owns its final year', () {
      final span = LifeSpan.of(samples.values.first);
      final first = span.decades.first; // 11-20
      expect(span.decadeAt(20.0)!.index, first.index);
      expect(span.decadeAt(20.9)!.index, first.index);
      expect(span.decadeAt(21.0)!.index, first.index + 1);
    });

    test('decades tile the axis without overlap or holes after 起运', () {
      for (final entry in samples.entries) {
        final span = LifeSpan.of(entry.value);
        for (var age = span.firstDecadeAge; age <= 120; age++) {
          final d = span.decadeAt(age.toDouble());
          expect(d, isNotNull, reason: '${entry.key}: no decade at age $age');
        }
        // Adjacent decades must abut exactly.
        for (var i = 1; i < span.decades.length; i++) {
          expect(span.decades[i].startAge, span.decades[i - 1].endAge + 1,
              reason: entry.key);
        }
      }
    });

    test('a decade and its 流年 agree on which ages they cover', () {
      // The commonest off-by-one in this kind of code.
      final span = LifeSpan.of(samples.values.first);
      for (final d in span.decades) {
        for (var age = d.startAge; age <= d.endAge && age <= 120; age++) {
          expect(span.decadeAt(age.toDouble())!.index, d.index);
          expect(span.yearAt(age.toDouble())!.age, age);
        }
      }
    });
  });

  test('a shorter span can be requested without breaking invariants', () {
    final span = LifeSpan.of(samples.values.first, maxAge: 60);
    expect(span.years.length, 60);
    expect(span.isContiguous, isTrue);
    expect(span.years.last.age, 60);
    for (final d in span.decades) {
      expect(span.boundsOf(d).$2, lessThanOrEqualTo(60.0));
    }
  });
}
