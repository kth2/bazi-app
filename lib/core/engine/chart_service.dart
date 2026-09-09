import 'package:bazi_core/bazi_core.dart' as bc;
import 'package:sxwnl_spa_dart/sxwnl_spa_dart.dart';

import '../analysis/activation_engine.dart';
import '../analysis/temporal_context.dart';
import '../models/birth_input.dart';
import '../models/chart_result.dart';
import 'element_strength.dart';
import 'labels.dart';

/// Wraps bazi_core: BirthInput -> fully annotated ChartResult,
/// plus on-demand 流月/流日 timeline expansion.
class ChartService {
  static const double _timezone = 8.0;
  /// 12 steps of 大运, enough to reach 虚岁 120 (两甲子) on any chart: the
  /// earliest possible 起运 is age 1, which puts the twelfth decade at
  /// 111-120. The life timeline needs the full span; eight stopped at ~90.
  static const int _decadeCount = 12;

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
  /// Structured 干支 interactions for the given 岁运 selection.
  ///
  /// Includes natal-internal relationships as well as those the 大运/流年/
  /// 流月/流日 pillars form with the chart, each party tagged with the layer
  /// it came from and its 十神. The reasoning layers consume this; the string
  /// form below is display only.
  static List<LuckInteraction> structuredInteractions(
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

    final results = result.chart.getInteractionsWith(
      otherStems: otherStems,
      otherBranches: otherBranches,
    );
    final dayMaster = result.chart.bazi.day.gan;

    return [
      for (final r in results)
        LuckInteraction(
          type: kInteractionLabels[r.type] ?? r.type.name,
          kind: _interactionKind(r.type),
          combinedWuXing:
              r.combinedWuXing == null ? null : kWuXingLabels[r.combinedWuXing],
          parties: [
            for (final n in r.nodes) _party(n, dayMaster),
          ],
        ),
    ];
  }

  static InteractionParty _party(bc.InteractionNode n, TianGan dayMaster) {
    final layer = _layerOf(n.pillar);
    final position = kPillarTypeLabels[n.pillar] ?? n.pillar.name;
    final value = n.value;
    if (value is TianGan) {
      final isDayMasterStem =
          n.pillar == bc.PillarType.day && value == dayMaster;
      return InteractionParty(
        layer: layer,
        position: position,
        value: value.label,
        isStem: true,
        shiShen: isDayMasterStem
            ? null
            : kShiShenLabels[bc.Relationship.getShiShen(dayMaster, value)],
      );
    }
    if (value is DiZhi) {
      final cangGan = bc.BaziTable.getCangGan(value);
      return InteractionParty(
        layer: layer,
        position: position,
        value: value.label,
        isStem: false,
        shiShen: cangGan.isEmpty
            ? null
            : kShiShenLabels[
                bc.Relationship.getShiShen(dayMaster, cangGan.first)],
      );
    }
    return InteractionParty(
      layer: layer,
      position: position,
      value: value.toString(),
      isStem: false,
    );
  }

  static String _nodeLabel(dynamic value) {
    if (value is TianGan) return value.label;
    if (value is DiZhi) return value.label;
    return value.toString();
  }

  static TemporalLayer _layerOf(bc.PillarType type) => switch (type) {
        bc.PillarType.decade => TemporalLayer.decade,
        bc.PillarType.flowYear => TemporalLayer.year,
        bc.PillarType.flowMonth => TemporalLayer.month,
        bc.PillarType.flowDay || bc.PillarType.flowHour => TemporalLayer.day,
        _ => TemporalLayer.natal,
      };

  /// What the relationship *does*, as opposed to what it is called.
  static InteractionKind _interactionKind(bc.BaziInteraction type) =>
      switch (type) {
        bc.BaziInteraction.stemCombination ||
        bc.BaziInteraction.branchCombination =>
          InteractionKind.combination,
        bc.BaziInteraction.branchTripleCombination ||
        bc.BaziInteraction.branchTripleDirection ||
        bc.BaziInteraction.branchHalfCombination ||
        bc.BaziInteraction.branchArchingCombination =>
          InteractionKind.formation,
        bc.BaziInteraction.stemClash || bc.BaziInteraction.branchClash =>
          InteractionKind.clash,
        bc.BaziInteraction.branchTriplePunishment ||
        bc.BaziInteraction.branchPunishment ||
        bc.BaziInteraction.branchSelfPunishment =>
          InteractionKind.punishment,
        bc.BaziInteraction.branchHarm ||
        bc.BaziInteraction.branchDestruction =>
          InteractionKind.erosion,
        bc.BaziInteraction.stemRestraint => InteractionKind.restraint,
        bc.BaziInteraction.branchHiddenCombination ||
        bc.BaziInteraction.branchSeverance =>
          InteractionKind.other,
      };

  /// Assemble the full temporal context for a scope selection.
  static TemporalContext temporalContext(
    ChartResult result, {
    DecadeData? decade,
    FlowYearData? year,
    FlowMonthData? month,
    FlowDayData? day,
  }) {
    String? gz(String? s) =>
        s == null ? null : (s.length >= 2 ? s.substring(0, 2) : s);
    return TemporalContext(
      chart: result,
      decade: decade,
      year: year,
      month: month,
      day: day,
      luckPillars: [
        if (decade != null)
          _temporalPillar(result, TemporalLayer.decade, gz(decade.ganZhi)!,
              '大运 ${decade.ganZhi}（${decade.startAge}-${decade.endAge}岁）'),
        if (year != null)
          _temporalPillar(result, TemporalLayer.year, gz(year.ganZhi)!,
              '流年 ${year.year}年 ${year.ganZhi}'),
        if (month != null)
          _temporalPillar(result, TemporalLayer.month, gz(month.ganZhi)!,
              '流月 ${month.ganZhi}月（${month.jieName}）'),
        if (day != null)
          _temporalPillar(result, TemporalLayer.day, gz(day.ganZhi)!,
              '流日 ${_fmt2(day.date)} ${day.ganZhi}'),
      ],
      interactions: structuredInteractions(
        result,
        decadeGanZhi: gz(decade?.ganZhi),
        liuNianGanZhi: gz(year?.ganZhi),
        liuYueGanZhi: gz(month?.ganZhi),
        liuRiGanZhi: gz(day?.ganZhi),
      ),
    );
  }

  /// Annotates a 岁运 ganzhi with the same 十神/五行 detail a natal pillar
  /// carries, so downstream layers can treat both alike.
  static TemporalPillar _temporalPillar(
    ChartResult result,
    TemporalLayer layer,
    String ganZhi,
    String label,
  ) {
    final dayMaster = result.chart.bazi.day.gan;
    final gan = TianGan.fromName(ganZhi[0]);
    final zhi = DiZhi.fromName(ganZhi[1]);
    final hidden = bc.BaziTable.getCangGan(zhi);
    String ss(TianGan g) =>
        kShiShenLabels[bc.Relationship.getShiShen(dayMaster, g)] ?? '';
    return TemporalPillar(
      layer: layer,
      ganZhi: ganZhi,
      ganShiShen: ss(gan),
      zhiMainShiShen: hidden.isEmpty ? '' : ss(hidden.first),
      zhiHiddenShiShen: [for (final h in hidden) ss(h)],
      ganWuXing: kWuXingLabels[bc.BaziTable.getWuXingOfGan(gan)] ?? '',
      zhiWuXing: kWuXingLabels[bc.BaziTable.getWuXingOfZhi(zhi)] ?? '',
      shenSha: _luckShenSha(result, gan, zhi, layer),
      label: label,
    );
  }

  /// Which of the event-bearing 神煞 this 岁运 pillar is, relative to the
  /// natal chart — 「今年走驿马」, not 「原局带驿马」.
  ///
  /// Restricted to the two the activation engine treats as events; the tables
  /// are bazi_core's, so this stays one lookup rather than a second copy of
  /// the 口诀.
  static List<String> _luckShenSha(
    ChartResult result,
    TianGan gan,
    DiZhi zhi,
    TemporalLayer layer,
  ) {
    final gz = bc.GanZhi(gan, zhi);
    final type = switch (layer) {
      TemporalLayer.decade => bc.PillarType.decade,
      TemporalLayer.year => bc.PillarType.flowYear,
      TemporalLayer.month => bc.PillarType.flowMonth,
      TemporalLayer.day => bc.PillarType.flowDay,
      TemporalLayer.natal => bc.PillarType.day,
    };
    return [
      for (final s in bc.shenShaRegistry)
        if (LuckActivationEngine.kEventShenSha.contains(s.name) &&
            s.check(result.chart, gz, type))
          s.name,
    ];
  }

  static String _fmt2(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Display-only string form of the 岁运 interactions (natal-internal ones
  /// excluded, since the chart already lists those).
  static List<String> luckInteractions(
    ChartResult result, {
    String? decadeGanZhi,
    String? liuNianGanZhi,
    String? liuYueGanZhi,
    String? liuRiGanZhi,
  }) {
    if (decadeGanZhi == null &&
        liuNianGanZhi == null &&
        liuYueGanZhi == null &&
        liuRiGanZhi == null) {
      return const [];
    }
    return [
      for (final i in structuredInteractions(
        result,
        decadeGanZhi: decadeGanZhi,
        liuNianGanZhi: liuNianGanZhi,
        liuYueGanZhi: liuYueGanZhi,
        liuRiGanZhi: liuRiGanZhi,
      ))
        if (i.involvesLuck)
          '${i.type}: '
              '${i.parties.map((p) => '${p.position} ${p.value}').join('、')}'
              '${i.combinedWuXing != null ? '（化${i.combinedWuXing}）' : ''}',
    ];
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
