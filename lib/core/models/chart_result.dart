import 'package:bazi_core/bazi_core.dart' as bc;

import '../engine/element_strength.dart';
import 'birth_input.dart';

/// One hidden stem (藏干) entry inside a branch.
class CangGanInfo {
  final String gan;
  final String wuXing;
  final String shiShen;

  const CangGanInfo({
    required this.gan,
    required this.wuXing,
    required this.shiShen,
  });

  Map<String, dynamic> toJson() =>
      {'gan': gan, 'wuXing': wuXing, 'shiShen': shiShen};
}

/// One of the four pillars, fully annotated.
class PillarData {
  final String position; // 年柱/月柱/日柱/时柱
  final String gan;
  final String zhi;
  final String ganWuXing;
  final String zhiWuXing;
  final String ganShiShen; // '日主' for the day pillar
  final List<CangGanInfo> cangGan;
  final String naYin;
  final String lifeStage; // 日主 twelve life stage at this branch
  final bool isKongWang; // branch falls in day pillar's 空亡
  final List<String> shenSha;

  const PillarData({
    required this.position,
    required this.gan,
    required this.zhi,
    required this.ganWuXing,
    required this.zhiWuXing,
    required this.ganShiShen,
    required this.cangGan,
    required this.naYin,
    required this.lifeStage,
    required this.isKongWang,
    required this.shenSha,
  });

  Map<String, dynamic> toJson() => {
        'position': position,
        'gan': gan,
        'zhi': zhi,
        'ganWuXing': ganWuXing,
        'zhiWuXing': zhiWuXing,
        'ganShiShen': ganShiShen,
        'cangGan': cangGan.map((c) => c.toJson()).toList(),
        'naYin': naYin,
        'lifeStage': lifeStage,
        'isKongWang': isKongWang,
        'shenSha': shenSha,
      };
}

/// A stem/branch relationship found in the chart (合/冲/刑/害...).
class InteractionData {
  final String type;
  final List<String> parties; // e.g. ['年支 子', '月支 丑']
  final String? combinedWuXing;

  const InteractionData({
    required this.type,
    required this.parties,
    this.combinedWuXing,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'parties': parties,
        if (combinedWuXing != null) 'combinedWuXing': combinedWuXing,
      };
}

/// One 大运 decade.
class DecadeData {
  final int index;
  final String ganZhi;
  final String ganShiShen;
  final String zhiMainShiShen; // 本气十神
  final int startAge; // 虚岁
  final int endAge;
  final int startYear;
  final int endYear;

  const DecadeData({
    required this.index,
    required this.ganZhi,
    required this.ganShiShen,
    required this.zhiMainShiShen,
    required this.startAge,
    required this.endAge,
    required this.startYear,
    required this.endYear,
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'ganZhi': ganZhi,
        'ganShiShen': ganShiShen,
        'zhiMainShiShen': zhiMainShiShen,
        'startAge': startAge,
        'endAge': endAge,
        'startYear': startYear,
        'endYear': endYear,
      };
}

/// One 流年.
class FlowYearData {
  final int year;
  final int age; // 虚岁
  final String ganZhi;
  final String ganShiShen;

  const FlowYearData({
    required this.year,
    required this.age,
    required this.ganZhi,
    required this.ganShiShen,
  });

  Map<String, dynamic> toJson() =>
      {'year': year, 'age': age, 'ganZhi': ganZhi, 'ganShiShen': ganShiShen};
}

/// One 流月 (jieqi-bounded month). Computed on demand per selected year.
class FlowMonthData {
  final int monthIndex; // 1-12 (寅月 = 1)
  final String ganZhi;
  final String ganShiShen;
  final String jieName; // starting 节 (立春, 惊蛰, ...)
  final DateTime start;
  final DateTime end;

  const FlowMonthData({
    required this.monthIndex,
    required this.ganZhi,
    required this.ganShiShen,
    required this.jieName,
    required this.start,
    required this.end,
  });

  Map<String, dynamic> toJson() => {
        'monthIndex': monthIndex,
        'ganZhi': ganZhi,
        'ganShiShen': ganShiShen,
        'jieName': jieName,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      };
}

/// One 流日. Computed on demand per selected month.
class FlowDayData {
  final DateTime date;
  final String ganZhi;
  final String ganShiShen;

  const FlowDayData({
    required this.date,
    required this.ganZhi,
    required this.ganShiShen,
  });

  Map<String, dynamic> toJson() => {
        'date':
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'ganZhi': ganZhi,
        'ganShiShen': ganShiShen,
      };
}

/// Complete calculation result: the single object the UI, the rule engine
/// and the AI prompt all consume.
class ChartResult {
  final BirthInput input;
  final String solarDate; // clock time as entered / converted
  final String trueSolarTime;
  final String lunarDate;
  final String dayMaster; // e.g. 甲
  final String dayMasterWuXing;
  final List<PillarData> pillars; // 年月日时
  final String mingGong;
  final String shenGong;
  final String taiYuan;
  final List<String> kongWang; // day pillar 空亡 branches
  final List<InteractionData> interactions;
  final ElementStrengthResult elementStrength;
  final String qiYunDescription; // 出生后X年X个月...交运
  final double qiYunAge;
  final bool daYunForward; // 顺行/逆行
  final List<DecadeData> decades;
  final List<FlowYearData> preDaYunYears; // years before first decade (小运期)

  /// Live bazi_core objects for on-demand computation (not serialized).
  final bc.BaziChart chart;
  final bc.Fortune fortune;

  const ChartResult({
    required this.input,
    required this.solarDate,
    required this.trueSolarTime,
    required this.lunarDate,
    required this.dayMaster,
    required this.dayMasterWuXing,
    required this.pillars,
    required this.mingGong,
    required this.shenGong,
    required this.taiYuan,
    required this.kongWang,
    required this.interactions,
    required this.elementStrength,
    required this.qiYunDescription,
    required this.qiYunAge,
    required this.daYunForward,
    required this.decades,
    required this.preDaYunYears,
    required this.chart,
    required this.fortune,
  });

  String get baziString => pillars.map((p) => '${p.gan}${p.zhi}').join(' ');

  Map<String, dynamic> toJson() => {
        'input': input.toJson(),
        'solarDate': solarDate,
        'trueSolarTime': trueSolarTime,
        'lunarDate': lunarDate,
        'bazi': baziString,
        'dayMaster': dayMaster,
        'dayMasterWuXing': dayMasterWuXing,
        'gender': input.gender == Gender.male ? '男' : '女',
        'pillars': pillars.map((p) => p.toJson()).toList(),
        'mingGong': mingGong,
        'shenGong': shenGong,
        'taiYuan': taiYuan,
        'kongWang': kongWang,
        'interactions': interactions.map((i) => i.toJson()).toList(),
        'elementStrength': elementStrength.toJson(),
        'qiYun': {
          'description': qiYunDescription,
          'age': double.parse(qiYunAge.toStringAsFixed(1)),
          'direction': daYunForward ? '顺行' : '逆行',
        },
        'daYun': decades.map((d) => d.toJson()).toList(),
      };
}
