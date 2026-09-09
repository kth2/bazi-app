import '../engine/chart_service.dart';
import '../models/chart_result.dart';

/// The 0-120 axis a life timeline is drawn on, and every conversion between
/// 年龄 / 公历年 / 大运 / 流年 that the timeline needs.
///
/// Ages are 虚岁 throughout, matching [FlowYearData.age] and
/// [DecadeData.startAge]: age 1 is the birth year, so
/// `公历年 = 出生年 + 虚岁 - 1`.
///
/// This is the single place those conversions live. The painter, the hit
/// testing and the drag-drop all read from here, because a timeline whose
/// drawing and whose input disagree by one year is both very easy to write
/// and very hard to notice.
class LifeSpan {
  /// 两甲子.
  static const int kMaxAge = 120;

  final ChartResult chart;
  final int maxAge;

  /// 大运 covering this span, clamped so none starts past [maxAge].
  final List<DecadeData> decades;

  /// Every 虚岁 from 1 to [maxAge], contiguous and in order — the 小运期
  /// before 起运 included, so no age on the axis is missing.
  final List<FlowYearData> years;

  LifeSpan._({
    required this.chart,
    required this.maxAge,
    required this.decades,
    required this.years,
  });

  factory LifeSpan.of(ChartResult chart, {int maxAge = kMaxAge}) {
    final decades = [
      for (final d in chart.decades)
        if (d.startAge <= maxAge) d,
    ];

    // 小运期 first, then each decade's 流年, so the axis is gapless.
    final years = <FlowYearData>[
      ...chart.preDaYunYears,
      for (final d in decades) ...ChartService.flowYearsOf(chart, d),
    ]..sort((a, b) => a.age.compareTo(b.age));

    return LifeSpan._(
      chart: chart,
      maxAge: maxAge,
      decades: decades,
      years: [
        for (final y in years)
          if (y.age >= 1 && y.age <= maxAge) y,
      ],
    );
  }

  int get birthYear => chart.fortune.birthday.year;

  /// 起运年龄 (含小数). Ages below this are 小运期.
  double get qiYunAge => chart.qiYunAge;

  /// The age at which the first 大运 takes over, in whole 虚岁.
  int get firstDecadeAge =>
      decades.isEmpty ? 1 : decades.first.startAge;

  bool isPreDaYun(double age) => age < firstDecadeAge;

  /// 虚岁 → 公历年.
  int calendarYearAt(double age) => birthYear + age.floor() - 1;

  /// 公历年 → 虚岁.
  int ageInCalendarYear(int year) => year - birthYear + 1;

  /// The 大运 containing [age], or null during 小运期 / past the last step.
  ///
  /// [DecadeData.endAge] is inclusive (11-20 is ten years), so a decade owns
  /// the continuous interval `[startAge, endAge + 1)`.
  DecadeData? decadeAt(double age) {
    for (final d in decades) {
      if (age >= d.startAge && age < d.endAge + 1) return d;
    }
    return null;
  }

  /// The 流年 containing [age].
  FlowYearData? yearAt(double age) {
    final whole = age.floor();
    for (final y in years) {
      if (y.age == whole) return y;
    }
    return null;
  }

  /// Continuous age interval a decade occupies on the axis, clamped to the
  /// span — the last step usually runs past 120 and must not draw past it.
  (double, double) boundsOf(DecadeData d) => (
        d.startAge.toDouble().clamp(0, maxAge.toDouble()),
        (d.endAge + 1).toDouble().clamp(0, maxAge.toDouble()),
      );

  /// True when the axis has a 流年 for every age from 1 to [maxAge].
  ///
  /// Cheap invariant worth asserting in tests: a hole would silently shift
  /// every marker drawn after it.
  bool get isContiguous {
    if (years.length != maxAge) return false;
    for (var i = 0; i < years.length; i++) {
      if (years[i].age != i + 1) return false;
    }
    return true;
  }
}
