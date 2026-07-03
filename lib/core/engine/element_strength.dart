import 'package:bazi_core/bazi_core.dart' as bc;
import 'package:sxwnl_spa_dart/sxwnl_spa_dart.dart';

import 'labels.dart';

/// 五行力量 weighted scorer.
///
/// Scoring model:
/// - Each heavenly stem contributes weight 1.0 to its element.
/// - Each branch contributes through its hidden stems (藏干), split by
///   本气/中气/余气 proportions, with the month branch (月令) weighted higher.
/// - Every contribution is multiplied by the seasonal state 旺相休囚死
///   relative to the month branch element.
class ElementStrengthResult {
  final Map<String, double> raw; // 木火土金水 -> weighted score
  final Map<String, double> percent; // 木火土金水 -> 0-100
  final String dayMasterElement;
  final String dayMasterSeasonState; // 旺/相/休/囚/死
  final double supportPercent; // 同党 (比劫+印) share, 0-100
  final String verdict; // 身强 / 身弱 / 中和

  const ElementStrengthResult({
    required this.raw,
    required this.percent,
    required this.dayMasterElement,
    required this.dayMasterSeasonState,
    required this.supportPercent,
    required this.verdict,
  });

  Map<String, dynamic> toJson() => {
        'scores': raw.map((k, v) => MapEntry(k, double.parse(v.toStringAsFixed(2)))),
        'percent':
            percent.map((k, v) => MapEntry(k, double.parse(v.toStringAsFixed(1)))),
        'dayMasterElement': dayMasterElement,
        'dayMasterSeasonState': dayMasterSeasonState,
        'supportPercent': double.parse(supportPercent.toStringAsFixed(1)),
        'verdict': verdict,
      };
}

class ElementStrength {
  /// 生: key generates value
  static const Map<bc.WuXing, bc.WuXing> _generates = {
    bc.WuXing.wood: bc.WuXing.fire,
    bc.WuXing.fire: bc.WuXing.earth,
    bc.WuXing.earth: bc.WuXing.metal,
    bc.WuXing.metal: bc.WuXing.water,
    bc.WuXing.water: bc.WuXing.wood,
  };

  /// 克: key controls value
  static const Map<bc.WuXing, bc.WuXing> _controls = {
    bc.WuXing.wood: bc.WuXing.earth,
    bc.WuXing.earth: bc.WuXing.water,
    bc.WuXing.water: bc.WuXing.fire,
    bc.WuXing.fire: bc.WuXing.metal,
    bc.WuXing.metal: bc.WuXing.wood,
  };

  /// 旺相休囚死 multiplier for [element] in the month governed by [monthElement].
  static double seasonMultiplier(bc.WuXing element, bc.WuXing monthElement) {
    if (element == monthElement) return 1.4; // 旺 (当令)
    if (_generates[monthElement] == element) return 1.2; // 相 (令所生)
    if (_generates[element] == monthElement) return 1.0; // 休 (生令)
    if (_controls[element] == monthElement) return 0.8; // 囚 (克令)
    return 0.6; // 死 (令所克)
  }

  static String seasonStateName(bc.WuXing element, bc.WuXing monthElement) {
    if (element == monthElement) return '旺';
    if (_generates[monthElement] == element) return '相';
    if (_generates[element] == monthElement) return '休';
    if (_controls[element] == monthElement) return '囚';
    return '死';
  }

  /// Hidden stem proportions by count: 本气 / 中气 / 余气.
  static List<double> _cangGanProportions(int count) {
    switch (count) {
      case 1:
        return const [1.0];
      case 2:
        return const [0.7, 0.3];
      default:
        return const [0.6, 0.3, 0.1];
    }
  }

  static ElementStrengthResult compute(bc.BaZi bazi) {
    final monthElement = bc.BaziTable.getWuXingOfZhi(bazi.month.zhi);
    final scores = {for (final w in bc.WuXing.values) w: 0.0};

    void addStem(TianGan gan, double weight) {
      final w = bc.BaziTable.getWuXingOfGan(gan);
      scores[w] = scores[w]! + weight * seasonMultiplier(w, monthElement);
    }

    void addBranch(DiZhi zhi, double positionWeight) {
      final cangGan = bc.BaziTable.getCangGan(zhi);
      final proportions = _cangGanProportions(cangGan.length);
      for (var i = 0; i < cangGan.length; i++) {
        final w = bc.BaziTable.getWuXingOfGan(cangGan[i]);
        scores[w] = scores[w]! +
            positionWeight * proportions[i] * seasonMultiplier(w, monthElement);
      }
    }

    // Stems: equal weight.
    for (final pillar in [bazi.year, bazi.month, bazi.day, bazi.time]) {
      addStem(pillar.gan, 1.0);
    }
    // Branches: 月令 dominates.
    addBranch(bazi.year.zhi, 1.0);
    addBranch(bazi.month.zhi, 1.8);
    addBranch(bazi.day.zhi, 1.0);
    addBranch(bazi.time.zhi, 1.0);

    final total = scores.values.fold(0.0, (a, b) => a + b);
    final percent = scores.map(
      (k, v) => MapEntry(kWuXingLabels[k]!, total == 0 ? 0.0 : v / total * 100),
    );

    // 日主强弱: 同党 = 比劫 (same element) + 印 (element generating day master).
    final dayElement = bc.BaziTable.getWuXingOfGan(bazi.day.gan);
    final resourceElement =
        _generates.entries.firstWhere((e) => e.value == dayElement).key;
    final supportPercent = (scores[dayElement]! + scores[resourceElement]!) /
        (total == 0 ? 1 : total) *
        100;

    final String verdict;
    if (supportPercent >= 55) {
      verdict = '身强';
    } else if (supportPercent <= 42) {
      verdict = '身弱';
    } else {
      verdict = '中和';
    }

    return ElementStrengthResult(
      raw: scores.map((k, v) => MapEntry(kWuXingLabels[k]!, v)),
      percent: percent,
      dayMasterElement: kWuXingLabels[dayElement]!,
      dayMasterSeasonState: seasonStateName(dayElement, monthElement),
      supportPercent: supportPercent,
      verdict: verdict,
    );
  }
}
