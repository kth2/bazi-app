import 'package:bazi_core/bazi_core.dart' as bc;
import 'package:sxwnl_spa_dart/sxwnl_spa_dart.dart';

import '../models/birth_input.dart';
import '../models/chart_result.dart';
import 'element_strength.dart';
import 'labels.dart';

/// Wraps bazi_core: BirthInput -> fully annotated ChartResult,
/// plus on-demand 流月/流日 timeline expansion.
class ChartService {
  static const double _timezone = 8.0;
  static const int _decadeCount = 8;

  static const List<String> _lunarMonthNames = [
    '正', '二', '三', '四', '五', '六', '七', '八', '九', '十', '冬', '腊',
  ];

  static ChartResult compute(BirthInput input) {
    final location = Location(input.longitude, 30);

    final bc.BaziChart chart;
    if (input.calendarType == CalendarType.lunar) {
      chart = bc.BaziChart.createByLunarDate(
        year: input.year,
        monthName: _lunarMonthNames[input.month - 1],
        day: input.day,
        hour: input.hour,
        minute: input.minute,
        isleap: input.isLeapMonth,
        location: location,
        timeZone: _timezone,
        gender: input.gender == Gender.male ? bc.Gender.male : bc.Gender.female,
      );
    } else {
      chart = bc.BaziChart.createBySolarDate(
        clockTime: AstroDateTime(
          input.year,
          input.month,
          input.day,
          input.hour,
          input.minute,
        ),
        location: location,
        timeZone: _timezone,
        gender: input.gender == Gender.male ? bc.Gender.male : bc.Gender.female,
      );
    }

    final fortune = bc.Fortune.createByBaziChart(chart);
    final shenSha = bc.ShenShaHelper.analyze(chart);
    final dayGan = chart.bazi.day.gan;
    final kongWangBranches = chart.bazi.day.getKongWang();

    PillarData buildPillar(
      GanZhi gz,
      bc.PillarType type,
      List<String> pillarShenSha,
    ) {
      final cangGan = bc.BaziTable.getCangGan(gz.zhi);
      return PillarData(
        position: kPillarTypeLabels[type]!,
        gan: gz.gan.label,
        zhi: gz.zhi.label,
        ganWuXing: kWuXingLabels[bc.BaziTable.getWuXingOfGan(gz.gan)]!,
        zhiWuXing: kWuXingLabels[bc.BaziTable.getWuXingOfZhi(gz.zhi)]!,
        ganShiShen: type == bc.PillarType.day
            ? '日主'
            : kShiShenLabels[bc.Relationship.getShiShen(dayGan, gz.gan)]!,
        cangGan: [
          for (final g in cangGan)
            CangGanInfo(
              gan: g.label,
              wuXing: kWuXingLabels[bc.BaziTable.getWuXingOfGan(g)]!,
              shiShen: kShiShenLabels[bc.Relationship.getShiShen(dayGan, g)]!,
            ),
        ],
        naYin: gz.naYin,
        lifeStage: kLifeStageLabels[bc.BaziTable.getLifeStage(dayGan, gz.zhi)]!,
        isKongWang: kongWangBranches.contains(gz.zhi),
        shenSha: pillarShenSha,
      );
    }

    final pillars = [
      buildPillar(chart.bazi.year, bc.PillarType.year, shenSha.yearShenSha),
      buildPillar(chart.bazi.month, bc.PillarType.month, shenSha.monthShenSha),
      buildPillar(chart.bazi.day, bc.PillarType.day, shenSha.dayShenSha),
      buildPillar(chart.bazi.time, bc.PillarType.hour, shenSha.hourShenSha),
    ];

    final interactions = [
      for (final r in chart.getAllInteractions())
        InteractionData(
          type: kInteractionLabels[r.type] ?? r.type.name,
          parties: [
            for (final n in r.nodes)
              '${kPillarTypeLabels[n.pillar] ?? n.pillar.name} ${_nodeLabel(n.value)}',
          ],
          combinedWuXing:
              r.combinedWuXing == null ? null : kWuXingLabels[r.combinedWuXing],
        ),
    ];

    // 大运 decades with their flow years.
    final decades = <DecadeData>[];
    for (var i = 1; i <= _decadeCount; i++) {
      final d = fortune.getDecadeByIndex(i);
      decades.add(
        DecadeData(
          index: d.index,
          ganZhi: d.ganZhi.toString(),
          ganShiShen:
              kShiShenLabels[bc.Relationship.getShiShen(dayGan, d.ganZhi.gan)]!,
          zhiMainShiShen: kShiShenLabels[bc.Relationship.getShiShen(
            dayGan,
            bc.BaziTable.getCangGan(d.ganZhi.zhi).first,
          )]!,
          startAge: d.startAge,
          endAge: d.endAge,
          startYear: d.startTime.year,
          endYear: d.endTime.year,
        ),
      );
    }

    // Years before the first decade starts (小运期), so every age is covered.
    final firstDecade = fortune.getDecadeByIndex(1);
    final preYears = <FlowYearData>[];
    final birthYear = fortune.birthday.year;
    for (var age = 1; age < firstDecade.startAge; age++) {
      final y = birthYear + age - 1;
      final gz = yearGanZhi(y);
      preYears.add(
        FlowYearData(
          year: y,
          age: age,
          ganZhi: gz.toString(),
          ganShiShen:
              kShiShenLabels[bc.Relationship.getShiShen(dayGan, gz.gan)]!,
        ),
      );
    }

    final st = chart.time.solarTime.trueSolarTime;
    final ld = chart.lunarDate;

    return ChartResult(
      input: input,
      solarDate: _fmt(chart.time.clockTime),
      trueSolarTime: _fmt(st),
      lunarDate:
          '农历${ld.lunarYear}年${ld.isLeap ? "闰" : ""}${ld.monthNameStr}月${_dayToCn(ld.day)}',
      dayMaster: dayGan.label,
      dayMasterWuXing: kWuXingLabels[bc.BaziTable.getWuXingOfGan(dayGan)]!,
      pillars: pillars,
      mingGong: chart.mingGong.toString(),
      shenGong: chart.shenGong.toString(),
      taiYuan: chart.taiYuan.toString(),
      kongWang: kongWangBranches.map((z) => z.label).toList(),
      interactions: interactions,
      elementStrength: ElementStrength.compute(chart.bazi),
      qiYunDescription: fortune.qiYunDt.toString(),
      qiYunAge: fortune.startAge,
      daYunForward: fortune.direction == 1,
      decades: decades,
      preDaYunYears: preYears,
      chart: chart,
      fortune: fortune,
    );
  }

  /// 流年 list for one decade.
  static List<FlowYearData> flowYearsOf(ChartResult result, DecadeData decade) {
    final dayGan = result.chart.bazi.day.gan;
    final birthYear = result.fortune.birthday.year;
    final d = result.fortune.getDecadeByIndex(decade.index);
    return [
      for (final yi in d.flowYears)
        FlowYearData(
          year: yi.year,
          age: yi.year - birthYear + 1,
          ganZhi: yi.ganZhi.toString(),
          ganShiShen:
              kShiShenLabels[bc.Relationship.getShiShen(dayGan, yi.ganZhi.gan)]!,
        ),
    ];
  }

  /// 流月 list (jieqi-bounded) for one calendar year. Computed on demand:
  /// each call does ~13 astronomical solves, too costly to precompute for
  /// all 80 years.
  static List<FlowMonthData> flowMonthsOf(ChartResult result, int year) {
    final dayGan = result.chart.bazi.day.gan;
    final monthGanZhi = getYearMonthGanZhi(yearGanZhi(year).gan);

    // Jie boundaries: 立春 plus the following 12 节.
    final liChunJd = getSpecificJieQi(year, 21);
    var current = JieQiResult(
      index: 2,
      name: '立春',
      jd: liChunJd,
      dateTime: AstroDateTime.fromJ2000(liChunJd),
    );
    final boundaries = <JieQiResult>[current];
    for (var i = 0; i < 12; i++) {
      final next = getNextJie(current.dateTime);
      if (next == null) break;
      boundaries.add(next);
      current = next;
    }

    return [
      for (var i = 0; i < 12 && i < boundaries.length - 1; i++)
        FlowMonthData(
          monthIndex: i + 1,
          ganZhi: monthGanZhi[i].toString(),
          ganShiShen: kShiShenLabels[bc.Relationship.getShiShen(
            dayGan,
            monthGanZhi[i].gan,
          )]!,
          jieName: boundaries[i].name,
          start: _toDateTime(boundaries[i].dateTime),
          end: _toDateTime(boundaries[i + 1].dateTime),
        ),
    ];
  }

  /// 流日 list for one flow month.
  static List<FlowDayData> flowDaysOf(ChartResult result, FlowMonthData month) {
    final dayGan = result.chart.bazi.day.gan;
    final startAdt = AstroDateTime(
      month.start.year,
      month.start.month,
      month.start.day,
      month.start.hour,
      month.start.minute,
    );
    final endAdt = AstroDateTime(
      month.end.year,
      month.end.month,
      month.end.day,
      month.end.hour,
      month.end.minute,
    );
    final startIdx = (startAdt.toJulianDay() + 0.5).floor();
    final endIdx = (endAdt.toJulianDay() + 0.5).floor();

    return [
      for (var i = startIdx; i < endIdx; i++)
        _flowDay(AstroDateTime.fromJulianDay(i.toDouble()), dayGan),
    ];
  }

  static FlowDayData _flowDay(AstroDateTime dt, TianGan dayGan) {
    final gz = dayGanZhi(dt);
    return FlowDayData(
      date: DateTime(dt.year, dt.month, dt.day),
      ganZhi: gz.toString(),
      ganShiShen: kShiShenLabels[bc.Relationship.getShiShen(dayGan, gz.gan)]!,
    );
  }

  /// Interactions between luck pillars (大运/流年/流月/流日) and the natal
  /// chart. Returns labels like "地支六冲: 大运 巳、日柱 亥".
  static List<String> luckInteractions(
    ChartResult result, {
    String? decadeGanZhi,
    String? liuNianGanZhi,
    String? liuYueGanZhi,
    String? liuRiGanZhi,
  }) {
    final otherStems = <bc.InteractionNode<TianGan>>[];
    final otherBranches = <bc.InteractionNode<DiZhi>>[];
    void addPillar(bc.PillarType type, String? ganZhi) {
      if (ganZhi == null || ganZhi.length < 2) return;
      otherStems.add(bc.InteractionNode(type, TianGan.fromName(ganZhi[0])));
      otherBranches.add(bc.InteractionNode(type, DiZhi.fromName(ganZhi[1])));
    }

    addPillar(bc.PillarType.decade, decadeGanZhi);
    addPillar(bc.PillarType.flowYear, liuNianGanZhi);
    addPillar(bc.PillarType.flowMonth, liuYueGanZhi);
    addPillar(bc.PillarType.flowDay, liuRiGanZhi);
    if (otherStems.isEmpty && otherBranches.isEmpty) return const [];

    final results = result.chart.getInteractionsWith(
      otherStems: otherStems,
      otherBranches: otherBranches,
    );
    const luckTypes = {
      bc.PillarType.decade,
      bc.PillarType.flowYear,
      bc.PillarType.flowMonth,
      bc.PillarType.flowDay,
    };
    return [
      for (final r in results)
        if (r.nodes.any((n) => luckTypes.contains(n.pillar)))
          '${kInteractionLabels[r.type] ?? r.type.name}: '
              '${r.nodes.map((n) => '${kPillarTypeLabels[n.pillar] ?? n.pillar.name} ${_nodeLabel(n.value)}').join('、')}'
              '${r.combinedWuXing != null ? '（化${kWuXingLabels[r.combinedWuXing]}）' : ''}',
    ];
  }

  static String _nodeLabel(dynamic value) {
    if (value is TianGan) return value.label;
    if (value is DiZhi) return value.label;
    return value.toString();
  }

  static DateTime _toDateTime(AstroDateTime adt) =>
      DateTime(adt.year, adt.month, adt.day, adt.hour, adt.minute);

  static String _fmt(AstroDateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _dayToCn(int day) {
    const tens = ['初', '十', '廿', '三'];
    const digits = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
    if (day == 10) return '初十';
    if (day == 20) return '二十';
    if (day == 30) return '三十';
    return '${tens[(day - 1) ~/ 10]}${digits[(day - 1) % 10]}';
  }
}
