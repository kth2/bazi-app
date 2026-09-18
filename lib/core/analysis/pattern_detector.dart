import 'dart:math' as math;

import '../models/chart_result.dart';
import 'shi_shen_presence.dart';

/// One 特殊场景, with how strong its weakest participant is.
///
/// The strength is the point. A scenario used to be a bare label, so
/// 「官印相生」 read the same whether 印 held 30% of the chart or 3.8% of it —
/// and the detector emitted it either way, because it only asked whether a
/// 印 existed *anywhere*, 藏干 included. One report could therefore say
/// 印星「仅见其气」(3.8%, not operative) and tag the chart 官印相生 in the
/// same breath, which is exactly the contradiction the narrative layer then
/// had to talk its way out of.
class ScenarioHit {
  final String name;

  /// Share of the chart held by the weakest 十神 group taking part, 0-100.
  final double strength;

  const ScenarioHit(this.name, this.strength);

  String get label => '$name（${strength.toStringAsFixed(0)}%）';

  Map<String, dynamic> toJson() =>
      {'name': name, 'strength': double.parse(strength.toStringAsFixed(1))};
}

/// 格局法 pattern analysis of a chart (子平真诠 method):
/// 用神专求月令 — the pattern comes from the month branch's main qi,
/// then success/failure is judged by what protects or breaks it.
class ChartPattern {
  final String geJu; // e.g. 偏印格 / 建禄格 / 阳刃格 / 从财格
  final String yongShen; // description of the chosen 用神
  /// 特殊场景, strongest first, each gated on its parties actually being
  /// able to act.
  final List<ScenarioHit> scenarios;

  final Set<String> tags; // feeds example matching

  /// 变格（从格）。When true, [geJu] is a 从格 and the whole 取用 logic is
  /// 顺势 rather than 中和 — the two are mutually exclusive readings, so
  /// nothing downstream may treat this chart as a 正格 as well.
  final bool isBianGe;

  /// Names only, strongest first — kept for callers that just want the list.
  List<String> get specialScenarios => [for (final s in scenarios) s.name];

  const ChartPattern({
    required this.geJu,
    required this.yongShen,
    required this.scenarios,
    required this.tags,
    this.isBianGe = false,
  });

  String get summary =>
      '格局：$geJu${isBianGe ? '（变格）' : ''}；用神：$yongShen'
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
    // 变格先判：从格一旦成立，格局本身就不是月令那一个了，用神也从「取中和」
    // 变为「顺其势」。两者互斥，所以这里是 if/else，而不是在正格之上再挂标签。
    final congGe = _detectCongGe(chart);

    String geJu;
    String yongShen;
    if (congGe != null) {
      geJu = congGe.name;
      yongShen = congGe.yongShen;
    } else if (monthMainShiShen == '比肩') {
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
    //
    // Every scenario below names a *relationship* between two 十神, so both
    // parties have to be able to take part in one. The old checks asked only
    // whether a 十神 appeared anywhere in the chart, 藏干 included, with a
    // threshold of one — which tagged 66% of all charts 官印相生, 38% of them
    // with 印星 under 10% of the chart's force. A relationship nobody in it
    // can perform is not a feature of the chart.
    //
    // The gate is the engine's own [ShiShenPresence] test, the same one the
    // structure resolver reports as 「有力可用」, so a report can no longer
    // call a 十神 unusable and lean on it in the same breath.
    final scenarios = <ScenarioHit>[];
    final presence = ShiShenPresenceTable.of(chart);

    double force(String group) => presence[group]?.strength ?? 0;

    /// 能用: 透干通根, or buried but holding real weight.
    bool usable(String group) => presence[group]?.isOperative ?? false;

    /// 有气: enough to be acted upon, even if it cannot act itself.
    bool present(String group) => presence[group]?.isStrong ?? false;

    /// Records a scenario at the strength of its weakest participant.
    void hit(String name, List<String> parties) {
      scenarios.add(ScenarioHit(
        name,
        parties.map(force).reduce(math.min),
      ));
    }

    int countStem(Set<String> targets) => chart.pillars
        .where((p) => p.ganShiShen != '日主' && targets.contains(p.ganShiShen))
        .length;

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
    // 财破印: the 财 has to be able to do the breaking.
    if (hasYinGe && usable('财星')) {
      hit('财破印', ['财星', '印星']);
    }
    // 伤官见官: 伤官 must be 透干 (it already was) and the 官 must be there
    // to be seen.
    if (countStem(const {'伤官'}) >= 1 && present('官杀')) {
      hit('伤官见官', ['食伤', '官杀']);
    }
    // 官杀混杂: both must reach 本气 or 透干 — already a real gate — and the
    // pair together has to amount to something.
    if (countMain(const {'正官'}) >= 1 &&
        countMain(const {'七杀'}) >= 1 &&
        present('官杀')) {
      hit('官杀混杂', ['官杀']);
    }
    // 枭神夺食: both 透干 already.
    if (countStem(const {'偏印'}) >= 1 && countStem(const {'食神'}) >= 1) {
      hit('枭神夺食', ['印星', '食伤']);
    }
    // 食神制杀: the 食神 does the controlling, so it must be usable.
    if (usable('食伤') && present('官杀') &&
        (presence['食神']?.exists ?? false) &&
        (presence['七杀']?.exists ?? false)) {
      hit('食神制杀', ['食伤', '官杀']);
    }
    if (_hasBiJieHeGuan(chart)) {
      hit('比劫合官', ['比劫', '官杀']);
    }
    if (_hasSanQi(monthPillar)) {
      hit('三奇格', ['官杀']);
    }
    if (countMain(const {'正财', '偏财'}) >= 2 &&
        chart.elementStrength.verdict == '身弱' &&
        usable('财星')) {
      hit('财多身弱', ['财星']);
    }
    if ((geJu == '建禄格' || geJu == '阳刃格' || geJu == '月劫格') &&
        countStem(const {'正官'}) >= 1 &&
        present('官杀')) {
      hit(geJu == '建禄格' ? '建禄用官' : '月劫用官', ['比劫', '官杀']);
    }
    // 官印相生 / 杀印相生: the whole claim is that 官 flows into 印 and 印
    // into the day master. A 印 that cannot act carries nothing.
    if (usable('官杀') && usable('印星')) {
      if (presence['正官']?.exists ?? false) {
        hit('官印相生', ['官杀', '印星']);
      }
      if (presence['七杀']?.exists ?? false) {
        hit('杀印相生', ['官杀', '印星']);
      }
    }
    if (usable('食伤') && usable('财星')) {
      hit('食伤生财', ['食伤', '财星']);
    }
    // 比劫争财: there has to be something worth taking.
    if (countStem(const {'比肩', '劫财'}) >= 1 && usable('财星')) {
      hit('比劫争财', ['比劫', '财星']);
    }
    // 争合（妒合）: two stems reaching for the same partner at once.
    //
    // The chart data already records all three parties of such a 合, but
    // nothing named it, so a three-way contest could be retold as a clean
    // two-way 合 — which reverses its meaning: 官星合日主 is 贵气所系,
    // 官星被比劫争合 is 贵气有人争。
    for (final contested in _contestedCombos(chart)) {
      hit('争合·${contested.$1}（两重相合，其应不专）', [contested.$2]);
    }

    // Force imbalance that did NOT clear the structural 从格 test is 假从:
    // worth telling the reader about, but it stays a note on a 正格 chart —
    // it must not turn into a 变格 tag or a second, contradictory 格局.
    final support = chart.elementStrength.supportPercent;
    if (congGe == null) {
      if (support <= _jiaCongRuoMaxSupport) {
        scenarios.add(ScenarioHit('身弱已极（日主尚有根或有印，假从，仍以正格论）', force('比劫')));
      } else if (support >= _jiaCongWangMinSupport) {
        scenarios.add(ScenarioHit('身旺已极（官杀尚有根，假从，仍以正格论）', force('比劫')));
      }
    }

    // 身旺无泄: strong day master with no 食伤 outlet — pent-up qi
    // (胡一鸣: 郁闷之象, health/mood risk).
    if (chart.elementStrength.verdict == '身强' && !presence['食伤']!.exists) {
      scenarios.add(ScenarioHit('身旺无泄', force('比劫')));
    }

    // Strongest first. The reader — and the model — should meet the scenario
    // that actually characterises the chart before the incidental ones.
    scenarios.sort((a, b) => b.strength.compareTo(a.strength));

    final tags = <String>{
      if (congGe != null)
        ...congGe.tags
      else ...[
        geJu,
        if (geJu == '正印格' || geJu == '偏印格') '印绶格',
      ],
      // 假从 notes are prose for the reader, not matchable structure —
      // keeping them out of the tag set stops them polluting example lookup.
      // 假从 notes and 争合 are prose for the reader, not matchable
      // structure — a 争合 label names this chart's own stems and could
      // never match a corpus tag anyway.
      for (final s in scenarios)
        if (!s.name.contains('假从') && !s.name.startsWith('争合')) s.name,
      chart.elementStrength.verdict == '身强'
          ? '身强'
          : chart.elementStrength.verdict == '身弱'
              ? '身弱'
              : '中和',
    };

    return ChartPattern(
      geJu: geJu,
      yongShen: yongShen,
      scenarios: scenarios,
      tags: tags,
      isBianGe: congGe != null,
    );
  }

  // ---------------------------------------------------------------------
  // 变格（从格）
  // ---------------------------------------------------------------------

  /// 生: key generates value (木生火 …).
  static const Map<String, String> _generates = {
    '木': '火', '火': '土', '土': '金', '金': '水', '水': '木',
  };

  /// 克: key controls value (木克土 …).
  static const Map<String, String> _controls = {
    '木': '土', '土': '水', '水': '火', '火': '金', '金': '木',
  };

  /// 生我者为印.
  static String _resourceOf(String element) =>
      _generates.entries.firstWhere((e) => e.value == element).key;

  /// 克我者为官杀.
  static String _restrainerOf(String element) =>
      _controls.entries.firstWhere((e) => e.value == element).key;

  /// 同党力量低于此值才考虑从弱，高于 [_congWangMinSupport] 才考虑从旺。
  /// 数值只是入场券，真正的判据是下面的「无根无印」结构检查。
  static const double _congRuoMaxSupport = 25;
  static const double _congWangMinSupport = 80;

  /// 只有逼近从格却因结构不合而落空的命造，才值得标注「假从」。
  /// 门槛比从格本身更严，否则每五个命造就有一个挂上这条注记。
  static const double _jiaCongRuoMaxSupport = 20;
  static const double _jiaCongWangMinSupport = 85;

  /// 某五行是否在地支中通根（藏干见之）.
  static bool _hasBranchRoot(ChartResult chart, String element) {
    for (final p in chart.pillars) {
      for (final c in p.cangGan) {
        if (c.wuXing == element) return true;
      }
    }
    return false;
  }

  /// 某五行是否出现于天干或藏干任一处（日主本身不计）.
  static bool _hasAnywhere(ChartResult chart, String element) {
    for (final p in chart.pillars) {
      if (p.ganShiShen != '日主' && p.ganWuXing == element) return true;
      for (final c in p.cangGan) {
        if (c.wuXing == element) return true;
      }
    }
    return false;
  }

  /// 从格判定 — 成立则**取代**正格，不与正格并存。
  ///
  /// 只看力量占比会把约八分之一的命造判成「变格倾向」，那太宽了。
  /// 古法的门槛是结构性的：日主必须**无根**（地支无同气藏干）且**无印**
  /// （干支不见生我之气），才谈得上弃命相从；但凡有一点根气或印绶，
  /// 就是假从，仍以正格论。从旺同理，要求官杀无根、无物可克。
  static _CongGe? _detectCongGe(ChartResult chart) {
    final es = chart.elementStrength;
    final day = chart.dayMasterWuXing;
    final yin = _resourceOf(day);
    final guanSha = _restrainerOf(day);
    final cai = _controls[day]!;
    final shiShang = _generates[day]!;
    final support = es.supportPercent;

    if (support <= _congRuoMaxSupport &&
        !_hasBranchRoot(chart, day) &&
        !_hasAnywhere(chart, yin)) {
      // 弃命相从：从谁，看财/官杀/食伤哪一党最旺。
      const targets = {'从财格': '财星', '从杀格': '官杀', '从儿格': '食伤'};
      final shares = <String, double>{
        '从财格': es.percent[cai] ?? 0,
        '从杀格': es.percent[guanSha] ?? 0,
        '从儿格': es.percent[shiShang] ?? 0,
      };
      final winner =
          shares.entries.reduce((a, b) => b.value > a.value ? b : a).key;
      final target = targets[winner]!;
      return _CongGe(
        name: winner,
        yongShen: '日主无根无印，弃命相从：以$target为用，'
            '喜行$target及生$target之地，最忌印比帮身逆其势',
        tags: {'变格', '从格', '从弱格', '从势格', winner},
      );
    }

    if (support >= _congWangMinSupport && !_hasBranchRoot(chart, guanSha)) {
      // 印比旺极而官杀无根，无物可克，只能顺其旺势。
      final yinLed = (es.percent[yin] ?? 0) > (es.percent[day] ?? 0);
      return _CongGe(
        name: yinLed ? '从强格' : '从旺格',
        yongShen: '印比旺极、官杀无根，宜顺不宜逆：'
            '喜行${yinLed ? '印绶' : '比劫'}与食伤流通之地，忌财官逆其旺势',
        tags: {'变格', '从格', '从旺格', if (yinLed) '从强格'},
      );
    }

    return null;
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

  /// Stems that two others are simultaneously 合-ing, with the 十神 group of
  /// the contested stem.
  ///
  /// bazi_core reports such a 合 as a single interaction with three parties,
  /// so the contested stem is simply the one that appears once.
  static List<(String, String)> _contestedCombos(ChartResult chart) {
    final out = <(String, String)>[];
    for (final i in chart.interactions) {
      if (!i.type.contains('五合') || i.parties.length < 3) continue;
      final stems = <String, int>{};
      for (final p in i.parties) {
        final stem = p.trim().split(RegExp(r'\s+')).last;
        stems[stem] = (stems[stem] ?? 0) + 1;
      }
      final singles = [
        for (final e in stems.entries)
          if (e.value == 1) e.key,
      ];
      if (singles.length != 1) continue;
      final stem = singles.first;
      final pillar = chart.pillars.firstWhere(
        (p) => p.gan == stem && p.ganShiShen != '日主',
        orElse: () => chart.pillars.first,
      );
      final group = ShiShenPresenceTable.groupOf(pillar.ganShiShen);
      if (group == null) continue;
      out.add(('${pillar.ganShiShen}$stem', group));
    }
    return out;
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

/// Internal result of the 从格 test.
class _CongGe {
  final String name; // 从财格 / 从杀格 / 从儿格 / 从旺格 / 从强格
  final String yongShen;
  final Set<String> tags;

  const _CongGe({
    required this.name,
    required this.yongShen,
    required this.tags,
  });
}
