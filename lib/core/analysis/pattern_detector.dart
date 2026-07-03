import '../models/chart_result.dart';

/// 格局法 pattern analysis of a chart (子平真诠 method):
/// 用神专求月令 — the pattern comes from the month branch's main qi,
/// then success/failure is judged by what protects or breaks it.
class ChartPattern {
  final String geJu; // e.g. 偏印格 / 建禄格 / 阳刃格
  final String yongShen; // description of the chosen 用神
  final List<String> specialScenarios; // 财破印 / 伤官见官 / 比劫合官 ...
  final Set<String> tags; // feeds example matching

  const ChartPattern({
    required this.geJu,
    required this.yongShen,
    required this.specialScenarios,
    required this.tags,
  });

  String get summary =>
      '格局：$geJu；用神：$yongShen'
      '${specialScenarios.isEmpty ? '' : '；特殊场景：${specialScenarios.join('、')}'}';
}

class PatternDetector {
  static const _yangStems = {'甲', '丙', '戊', '庚', '壬'};

  static ChartPattern detect(ChartResult chart) {
    final monthPillar = chart.pillars[1];
    final monthMainShiShen =
        monthPillar.cangGan.isEmpty ? '' : monthPillar.cangGan.first.shiShen;
    final dayGanIsYang = _yangStems.contains(chart.dayMaster);

    // --- 定格局 ---
    String geJu;
    String yongShen;
    if (monthMainShiShen == '比肩') {
      geJu = '建禄格';
      yongShen = _luJieYongShen(chart);
    } else if (monthMainShiShen == '劫财') {
      geJu = dayGanIsYang ? '阳刃格' : '月劫格';
      yongShen = _luJieYongShen(chart);
    } else {
      geJu = '$monthMainShiShen格';
      final mainGan =
          monthPillar.cangGan.isEmpty ? '' : monthPillar.cangGan.first.gan;
      yongShen = '月令$mainGan$monthMainShiShen为用神';
    }

    // --- 特殊场景 ---
    final scenarios = <String>[];

    int countStem(Set<String> targets) => chart.pillars
        .where((p) => p.ganShiShen != '日主' && targets.contains(p.ganShiShen))
        .length;
    int countAny(Set<String> targets) {
      var n = 0;
      for (final p in chart.pillars) {
        if (p.ganShiShen != '日主' && targets.contains(p.ganShiShen)) n++;
        for (final c in p.cangGan) {
          if (targets.contains(c.shiShen)) n++;
        }
      }
      return n;
    }

    int countMain(Set<String> targets) {
      var n = 0;
      for (final p in chart.pillars) {
        if (p.ganShiShen != '日主' && targets.contains(p.ganShiShen)) n++;
        if (p.cangGan.isNotEmpty && targets.contains(p.cangGan.first.shiShen)) {
          n++;
        }
      }
      return n;
    }

    final hasYinGe = geJu == '正印格' || geJu == '偏印格';
    if (hasYinGe && countAny(const {'正财', '偏财'}) >= 1) {
      scenarios.add('财破印');
    }
    if (countStem(const {'伤官'}) >= 1 && countAny(const {'正官'}) >= 1) {
      scenarios.add('伤官见官');
    }
    if (countMain(const {'正官'}) >= 1 && countMain(const {'七杀'}) >= 1) {
      scenarios.add('官杀混杂');
    }
    if (countStem(const {'偏印'}) >= 1 && countStem(const {'食神'}) >= 1) {
      scenarios.add('枭神夺食');
    }
    if (countAny(const {'食神'}) >= 1 && countAny(const {'七杀'}) >= 1) {
      scenarios.add('食神制杀');
    }
    if (_hasBiJieHeGuan(chart)) {
      scenarios.add('比劫合官');
    }
    if (_hasSanQi(monthPillar)) {
      scenarios.add('三奇格');
    }
    if (countAny(const {'正财', '偏财'}) >= 3 &&
        chart.elementStrength.verdict == '身弱') {
      scenarios.add('财多身弱');
    }
    if ((geJu == '建禄格' || geJu == '阳刃格' || geJu == '月劫格') &&
        countStem(const {'正官'}) >= 1) {
      scenarios.add(geJu == '建禄格' ? '建禄用官' : '月劫用官');
    }
    if (countAny(const {'正官'}) >= 1 && countAny(const {'正印', '偏印'}) >= 1) {
      scenarios.add('官印相生');
    }
    if (countAny(const {'七杀'}) >= 1 && countAny(const {'正印', '偏印'}) >= 1) {
      scenarios.add('杀印相生');
    }
    if (countAny(const {'食神', '伤官'}) >= 1 &&
        countAny(const {'正财', '偏财'}) >= 1) {
      scenarios.add('食伤生财');
    }
    if (countStem(const {'比肩', '劫财'}) >= 1 &&
        countAny(const {'正财', '偏财'}) >= 1) {
      scenarios.add('比劫争财');
    }

    final tags = <String>{
      geJu,
      if (geJu == '正印格' || geJu == '偏印格') '印绶格',
      ...scenarios,
      chart.elementStrength.verdict == '身强'
          ? '身强'
          : chart.elementStrength.verdict == '身弱'
              ? '身弱'
              : '中和',
    };

    return ChartPattern(
      geJu: geJu,
      yongShen: yongShen,
      specialScenarios: scenarios,
      tags: tags,
    );
  }

  /// 禄劫格 can't use the month itself: 有煞先论煞，有官先论官，
  /// 无官煞再寻食伤财 — from transparent stems.
  static String _luJieYongShen(ChartResult chart) {
    String? findStem(String shiShen) {
      for (final p in chart.pillars) {
        if (p.ganShiShen == shiShen) return p.gan;
      }
      return null;
    }

    for (final s in const ['七杀', '正官', '食神', '伤官', '正财', '偏财']) {
      final gan = findStem(s);
      if (gan != null) return '月令同气难取用，透干取$gan$s为用';
    }
    return '月令同气难取用，干上无官杀食伤财透出，需于藏干中寻用';
  }

  /// 比劫争合官星: an official-star stem whose 五合 partner is the day
  /// master, while 比肩 also appears in the stems.
  static bool _hasBiJieHeGuan(ChartResult chart) {
    const combos = {'甲': '己', '己': '甲', '乙': '庚', '庚': '乙',
      '丙': '辛', '辛': '丙', '丁': '壬', '壬': '丁', '戊': '癸', '癸': '戊'};
    final hasGuanCombiningDay = chart.pillars.any((p) =>
        p.ganShiShen == '正官' && combos[p.gan] == chart.dayMaster);
    final hasBiJian =
        chart.pillars.any((p) => p.ganShiShen == '比肩');
    return hasGuanCombiningDay && hasBiJian;
  }

  /// 三奇格: month branch hidden stems span 财 + 官杀 + 印 all three.
  static bool _hasSanQi(PillarData monthPillar) {
    var cai = false, guan = false, yin = false;
    for (final c in monthPillar.cangGan) {
      if (c.shiShen == '正财' || c.shiShen == '偏财') cai = true;
      if (c.shiShen == '正官' || c.shiShen == '七杀') guan = true;
      if (c.shiShen == '正印' || c.shiShen == '偏印') yin = true;
    }
    return cai && guan && yin;
  }
}
