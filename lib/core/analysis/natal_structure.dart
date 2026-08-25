import '../models/chart_result.dart';
import 'pattern_detector.dart';

/// 格局成败.
enum GeJuStatus {
  /// 成格 — the 格 has what it needs and nothing is breaking it.
  cheng,

  /// 破而有救 — something breaks the 格, but a 救应 answers it.
  jiuYing,

  /// 破格 — broken with no rescue in the chart.
  po,

  /// 禄劫格 with nothing transparent to take as 用, or otherwise undecidable.
  unknown,
}

extension GeJuStatusX on GeJuStatus {
  String get label => switch (this) {
        GeJuStatus.cheng => '成格',
        GeJuStatus.jiuYing => '破而有救',
        GeJuStatus.po => '破格',
        GeJuStatus.unknown => '格局待定',
      };
}

/// How present a 十神 actually is — the distinction the audit called out as
/// missing: having a 十神 somewhere in the chart is not the same as that
/// 十神 being strong, and neither is the same as it being able to act.
class ShiShenPresence {
  final String name; // 十神 or group name

  /// Occurrences in 天干 (日主 excluded) — 透干.
  final int transparent;

  /// Occurrences anywhere, 藏干 included.
  final int total;

  /// 通根: the element appears in some branch's 藏干.
  final bool rooted;

  /// Share of total chart force held by this 十神's element, 0-100.
  final double strength;

  const ShiShenPresence({
    required this.name,
    required this.transparent,
    required this.total,
    required this.rooted,
    required this.strength,
  });

  bool get exists => total > 0;

  /// 有力: present, with a footing, and holding a real share of the chart.
  ///
  /// A 十神 that appears only as a 余气藏干 in one branch is *present* but
  /// cannot carry a life theme on its own.
  bool get isStrong =>
      exists && (rooted || transparent > 0) && strength >= 8;

  /// 能用: able to actually act on the chart.
  ///
  /// The classical test is 透干通根 — visible in the stems and rooted below.
  /// A 十神 buried in the branches can still act if it holds enough weight,
  /// but a rootless transparent stem cannot.
  bool get isOperative =>
      exists &&
      ((transparent > 0 && rooted) || (rooted && strength >= 18));

  String get level {
    if (!exists) return '无';
    if (isOperative) return '有力可用';
    if (isStrong) return '有气未成用';
    if (transparent > 0) return '透而无根';
    return '仅见其气';
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'transparent': transparent,
        'total': total,
        'rooted': rooted,
        'strength': double.parse(strength.toStringAsFixed(1)),
        'level': level,
      };
}

/// 调候 — the climatic correction, on the 寒暖燥湿 axis.
///
/// This is deliberately the 寒暖燥湿 principle rather than a full
/// 穷通宝鉴 lookup: the general rule (冬生调候用火、夏生调候用水…) is stated
/// plainly in the classics and safe to encode, whereas the 120-cell
/// per-日主-per-月 table is not something to reproduce from memory.
class TiaoHou {
  final String climate; // 寒 / 暖燥 / 平
  final List<String> needed; // 五行 wanted for balance
  final bool satisfied;
  final String note;

  const TiaoHou({
    required this.climate,
    required this.needed,
    required this.satisfied,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
        'climate': climate,
        'needed': needed,
        'satisfied': satisfied,
        'note': note,
      };
}

/// The full 子平真诠 reading of the natal chart:
/// 格局 → 成败 → 用神 → 相神 → 忌神 → 调候.
///
/// Replaces the previous one-line "月令某某为用神", which said nothing about
/// whether the 格 actually stands up.
class NatalStructure {
  final ChartPattern pattern;
  final GeJuStatus status;

  /// 成格因素 / 破格因素 / 救应因素.
  final List<String> chengFactors;
  final List<String> poFactors;
  final List<String> jiuFactors;

  /// 用神: what the 格 is built on.
  final String yongShen;

  /// 相神: what protects or completes the 格 (十神 group names).
  final List<String> xiangShen;

  /// 忌神: what breaks it.
  final List<String> jiShen;

  final TiaoHou tiaoHou;

  /// Presence/strength/operability of each 十神 group.
  final Map<String, ShiShenPresence> presence;

  const NatalStructure({
    required this.pattern,
    required this.status,
    required this.chengFactors,
    required this.poFactors,
    required this.jiuFactors,
    required this.yongShen,
    required this.xiangShen,
    required this.jiShen,
    required this.tiaoHou,
    required this.presence,
  });

  String get summary {
    final buf = StringBuffer()
      ..write('格局：${pattern.geJu}${pattern.isBianGe ? '（变格）' : ''}')
      ..write('；成败：${status.label}')
      ..write('；用神：$yongShen');
    if (xiangShen.isNotEmpty) buf.write('；相神：${xiangShen.join('、')}');
    if (jiShen.isNotEmpty) buf.write('；忌神：${jiShen.join('、')}');
    if (poFactors.isNotEmpty) buf.write('；破格：${poFactors.join('、')}');
    if (jiuFactors.isNotEmpty) buf.write('；救应：${jiuFactors.join('、')}');
    if (tiaoHou.climate != '平') {
      buf.write('；调候：${tiaoHou.note}');
    }
    if (pattern.specialScenarios.isNotEmpty) {
      buf.write('；特殊场景：${pattern.specialScenarios.join('、')}');
    }
    return buf.toString();
  }

  Map<String, dynamic> toJson() => {
        'geJu': pattern.geJu,
        'isBianGe': pattern.isBianGe,
        'status': status.label,
        'yongShen': yongShen,
        'xiangShen': xiangShen,
        'jiShen': jiShen,
        'chengFactors': chengFactors,
        'poFactors': poFactors,
        'jiuFactors': jiuFactors,
        'tiaoHou': tiaoHou.toJson(),
        'shiShen': presence.map((k, v) => MapEntry(k, v.toJson())),
        'specialScenarios': pattern.specialScenarios,
      };
}

/// 顺用/逆用 specification for one 格局.
///
/// 子平真诠: 财官印食为四吉神，顺用之——生之护之；
/// 杀伤枭刃为四凶神，逆用之——制之化之。
class _GeJuSpec {
  final bool shunYong;

  /// 相神候选: 十神 groups that complete or protect the 格.
  final List<String> xiangShen;

  /// 破格之神 → the 救应 that answers it.
  final Map<String, List<String>> breakers;

  /// 相神 to look for when the 格神 itself is excessive.
  ///
  /// 太过与不及俱为病: a 印绶格 with 印 at 60% does not want more 官杀 生印,
  /// it wants 财 to 损印 or 食伤 to 泄秀. Without this the resolver declares
  /// such charts 格无所依 purely because the ordinary 相神 is absent.
  final List<String> xiangShenWhenExcessive;

  const _GeJuSpec({
    required this.shunYong,
    required this.xiangShen,
    required this.breakers,
    this.xiangShenWhenExcessive = const [],
  });
}

class NatalStructureResolver {
  /// Groups used throughout; the five parties relative to the day master.
  static const List<String> kGroups = ['比劫', '食伤', '财星', '官杀', '印星'];

  static const Map<String, List<String>> _groupMembers = {
    '比劫': ['比肩', '劫财'],
    '食伤': ['食神', '伤官'],
    '财星': ['正财', '偏财'],
    '官杀': ['正官', '七杀'],
    '印星': ['正印', '偏印'],
  };

  static const Map<String, String> _generates = {
    '木': '火', '火': '土', '土': '金', '金': '水', '水': '木',
  };
  static const Map<String, String> _controls = {
    '木': '土', '土': '水', '水': '火', '火': '金', '金': '木',
  };

  /// 顺用/逆用 table, keyed by 格局.
  ///
  /// 顺用 (财官印食): protect and feed the 格, never let it be attacked.
  /// 逆用 (杀伤枭刃): the 格 is a hostile force, so it must be controlled,
  /// transformed or drained — feeding it is what breaks the chart.
  static const Map<String, _GeJuSpec> _specs = {
    '正官格': _GeJuSpec(
      shunYong: true,
      xiangShen: ['财星', '印星'],
      breakers: {
        '伤官': ['印星'],
        '七杀': ['食伤'],
      },
      xiangShenWhenExcessive: ['印星', '食伤'],
    ),
    '正财格': _GeJuSpec(
      shunYong: true,
      xiangShen: ['食伤', '官杀'],
      breakers: {
        '比劫': ['食伤', '官杀'],
      },
      xiangShenWhenExcessive: ['比劫', '印星'],
    ),
    '偏财格': _GeJuSpec(
      shunYong: true,
      xiangShen: ['食伤', '官杀'],
      breakers: {
        '比劫': ['食伤', '官杀'],
      },
      xiangShenWhenExcessive: ['比劫', '印星'],
    ),
    '正印格': _GeJuSpec(
      shunYong: true,
      xiangShen: ['官杀'],
      breakers: {
        '财星': ['比劫'],
      },
      xiangShenWhenExcessive: ['财星', '食伤'],
    ),
    '偏印格': _GeJuSpec(
      shunYong: true,
      xiangShen: ['官杀'],
      breakers: {
        '财星': ['比劫'],
      },
      xiangShenWhenExcessive: ['财星', '食伤'],
    ),
    '食神格': _GeJuSpec(
      shunYong: true,
      xiangShen: ['财星'],
      breakers: {
        '偏印': ['财星'],
      },
      xiangShenWhenExcessive: ['印星'],
    ),
    '七杀格': _GeJuSpec(
      shunYong: false,
      xiangShen: ['食伤', '印星'],
      breakers: {
        '财星': ['食伤', '印星'],
      },
      xiangShenWhenExcessive: ['食伤', '印星'],
    ),
    '伤官格': _GeJuSpec(
      shunYong: false,
      xiangShen: ['印星', '财星'],
      breakers: {
        '正官': ['印星', '财星'],
      },
      xiangShenWhenExcessive: ['印星'],
    ),
    '阳刃格': _GeJuSpec(
      shunYong: false,
      xiangShen: ['官杀'],
      breakers: {},
    ),
    '建禄格': _GeJuSpec(
      shunYong: false,
      xiangShen: ['官杀', '食伤', '财星'],
      breakers: {},
    ),
    '月劫格': _GeJuSpec(
      shunYong: false,
      xiangShen: ['官杀', '食伤', '财星'],
      breakers: {},
    ),
  };

  static NatalStructure resolve(ChartResult chart, ChartPattern pattern) {
    final presence = _presenceMap(chart);
    final tiaoHou = _tiaoHou(chart);

    if (pattern.isBianGe) {
      return _resolveBianGe(chart, pattern, presence, tiaoHou);
    }

    final spec = _specs[pattern.geJu];
    if (spec == null) {
      return NatalStructure(
        pattern: pattern,
        status: GeJuStatus.unknown,
        chengFactors: const [],
        poFactors: const [],
        jiuFactors: const [],
        yongShen: pattern.yongShen,
        xiangShen: const [],
        jiShen: const [],
        tiaoHou: tiaoHou,
        presence: presence,
      );
    }

    final cheng = <String>[];
    final po = <String>[];
    final jiu = <String>[];
    final xiangShen = <String>[];
    final jiShen = <String>[];

    // 太过与不及俱为病: when the 格神 itself is overgrown, the chart no
    // longer wants it fed — it wants it drained or checked.
    final geShen = _geShenGroup(pattern.geJu);
    final geShenStrength = geShen == null ? 0.0 : presence[geShen]!.strength;
    final excessive = geShenStrength >= _excessiveStrength;
    final candidates = [
      ...spec.xiangShen,
      if (excessive) ...spec.xiangShenWhenExcessive,
    ];
    if (excessive) {
      cheng.add('$geShen太旺（${geShenStrength.toStringAsFixed(0)}%），'
          '宜泄宜制，不宜再生');
    }

    // --- 相神: does anything actually complete the 格? ---
    for (final g in candidates) {
      if (xiangShen.contains(g)) continue;
      final p = presence[g]!;
      if (p.isOperative) {
        xiangShen.add(g);
        cheng.add(spec.shunYong
            ? '$g有力${p.transparent > 0 ? '透干' : '得根'}，护持格局'
            : '$g有力${p.transparent > 0 ? '透干' : '得根'}，制化得宜');
      } else if (p.isStrong) {
        cheng.add('$g有气而未成用，护格之力有限');
      }
    }

    // --- 破格: is a breaker present *and able to act*? ---
    spec.breakers.forEach((breaker, rescues) {
      final bp = presence[breaker] ?? _lookup(presence, breaker);
      if (bp == null || !bp.isOperative) {
        // Present but powerless is not a 破格 — this is exactly the
        // presence-vs-operability distinction the flat detector collapsed.
        if (bp != null && bp.exists) {
          cheng.add('虽见$breaker，然${bp.level}，不足以破格');
        }
        return;
      }
      po.add('$breaker${bp.transparent > 0 ? '透干' : '得根'}，'
          '${spec.shunYong ? '克破格神' : '助长凶神'}');
      jiShen.add(breaker);
      for (final r in rescues) {
        final rp = presence[r]!;
        if (rp.isOperative) {
          jiu.add('$r有力，可${_rescueVerb(breaker, r)}，破而有救');
          if (!xiangShen.contains(r)) xiangShen.add(r);
        }
      }
    });

    // --- 无制无化则格败 ---
    if (xiangShen.isEmpty && geShen != null) {
      if (!spec.shunYong && (presence[geShen]?.isStrong ?? false)) {
        po.add('${pattern.geJu}凶神当令而无制无化，格局失守');
      } else if (excessive) {
        // 母慈灭子 and its cousins: the 格神 floods the chart with nothing
        // to drain it.
        po.add('$geShen太旺而无制无泄，一气独盛，反成其病');
      }
    }

    final status = po.isEmpty
        ? (xiangShen.isEmpty ? GeJuStatus.unknown : GeJuStatus.cheng)
        : (jiu.isEmpty ? GeJuStatus.po : GeJuStatus.jiuYing);

    return NatalStructure(
      pattern: pattern,
      status: status,
      chengFactors: cheng,
      poFactors: po,
      jiuFactors: jiu,
      yongShen: _yongShenText(pattern, spec, xiangShen, status),
      xiangShen: xiangShen,
      jiShen: jiShen,
      tiaoHou: tiaoHou,
      presence: presence,
    );
  }

  // ---------------------------------------------------------------------

  static NatalStructure _resolveBianGe(
    ChartResult chart,
    ChartPattern pattern,
    Map<String, ShiShenPresence> presence,
    TiaoHou tiaoHou,
  ) {
    // 从格: the 用神 is the party being followed; 忌神 is anything that
    // fights it. 成败 turns on whether the followed party is clean.
    const followed = {
      '从财格': '财星',
      '从杀格': '官杀',
      '从儿格': '食伤',
      '从旺格': '比劫',
      '从强格': '印星',
    };
    final target = followed[pattern.geJu];
    final cheng = <String>[];
    final po = <String>[];

    if (target != null) {
      final tp = presence[target]!;
      if (tp.isOperative) {
        cheng.add('$target当权有力，从之有依');
      } else {
        po.add('所从之$target力有未逮，从而不真');
      }
    }
    // 从弱格 most fears 印比 reviving the day master; 从旺格 fears 财官.
    final enemies = pattern.tags.contains('从旺格')
        ? const ['财星', '官杀']
        : const ['印星', '比劫'];
    for (final e in enemies) {
      final ep = presence[e]!;
      if (ep.isOperative) {
        po.add('$e${ep.transparent > 0 ? '透干' : '得根'}，逆其从势');
      }
    }

    return NatalStructure(
      pattern: pattern,
      status: po.isEmpty ? GeJuStatus.cheng : GeJuStatus.po,
      chengFactors: cheng,
      poFactors: po,
      jiuFactors: const [],
      yongShen: pattern.yongShen,
      xiangShen: target == null ? const [] : [target],
      jiShen: enemies,
      tiaoHou: tiaoHou,
      presence: presence,
    );
  }

  static String _yongShenText(
    ChartPattern pattern,
    _GeJuSpec spec,
    List<String> xiangShen,
    GeJuStatus status,
  ) {
    final base = pattern.yongShen;
    if (xiangShen.isEmpty) {
      return '$base（相神未见，格局${status.label}）';
    }
    return spec.shunYong
        ? '$base，以${xiangShen.join('、')}为相神生护'
        : '$base，以${xiangShen.join('、')}为相神制化';
  }

  static String _rescueVerb(String breaker, String rescue) {
    if (breaker == '财星' && rescue == '比劫') return '比劫制财护印';
    if (breaker == '财星' && rescue == '印星') return '印绶化杀';
    if (breaker == '财星' && rescue == '食伤') return '食神制杀';
    if (breaker == '伤官' && rescue == '印星') return '配印制伤';
    if (breaker == '七杀' && rescue == '食伤') return '食神制杀';
    if (breaker == '比劫' && rescue == '食伤') return '通关化劫生财';
    if (breaker == '比劫' && rescue == '官杀') return '官星制劫护财';
    if (breaker == '偏印' && rescue == '财星') return '财星制枭护食';
    if (breaker == '正官' && rescue == '印星') return '印绶通关';
    return '制其$breaker';
  }

  /// The 十神 group the 格 itself is made of.
  static String? _geShenGroup(String geJu) => switch (geJu) {
        '正官格' || '七杀格' => '官杀',
        '正财格' || '偏财格' => '财星',
        '正印格' || '偏印格' => '印星',
        '食神格' || '伤官格' => '食伤',
        '建禄格' || '月劫格' || '阳刃格' => '比劫',
        _ => null,
      };

  /// 格神太旺 — past this share the 格 needs draining or checking, not feeding.
  static const double _excessiveStrength = 40;

  static ShiShenPresence? _lookup(
      Map<String, ShiShenPresence> presence, String name) {
    if (presence.containsKey(name)) return presence[name];
    for (final entry in _groupMembers.entries) {
      if (entry.value.contains(name)) return presence[entry.key];
    }
    return null;
  }

  // ---------------------------------------------------------------------

  /// Builds presence/strength for both the five groups and the ten 十神.
  static Map<String, ShiShenPresence> _presenceMap(ChartResult chart) {
    final es = chart.elementStrength;
    final day = chart.dayMasterWuXing;
    final groupElement = {
      '比劫': day,
      '食伤': _generates[day]!,
      '财星': _controls[day]!,
      '官杀': _controls.entries.firstWhere((e) => e.value == day).key,
      '印星': _generates.entries.firstWhere((e) => e.value == day).key,
    };

    final out = <String, ShiShenPresence>{};

    /// Raw occurrence counts for a set of 十神 names.
    (int, int, bool) tally(List<String> members) {
      var transparent = 0, total = 0;
      var rooted = false;
      for (final p in chart.pillars) {
        if (p.ganShiShen != '日主' && members.contains(p.ganShiShen)) {
          transparent++;
          total++;
        }
        for (final c in p.cangGan) {
          if (members.contains(c.shiShen)) {
            total++;
            rooted = true;
          }
        }
      }
      return (transparent, total, rooted);
    }

    for (final g in kGroups) {
      final (transparent, total, rooted) = tally(_groupMembers[g]!);
      final groupStrength = es.percent[groupElement[g]!] ?? 0;
      out[g] = ShiShenPresence(
        name: g,
        transparent: transparent,
        total: total,
        rooted: rooted,
        strength: groupStrength,
      );

      // Split the group's force between its two members by how much of the
      // group each actually accounts for. Giving 七杀 the whole 官杀 force
      // would make a single hidden 七杀 look strong enough to break a
      // 正官格 built on three transparent 正官.
      for (final member in _groupMembers[g]!) {
        final (mTransparent, mTotal, mRooted) = tally([member]);
        out[member] = ShiShenPresence(
          name: member,
          transparent: mTransparent,
          total: mTotal,
          rooted: mRooted,
          strength: total == 0 ? 0 : groupStrength * mTotal / total,
        );
      }
    }
    return out;
  }

  /// 调候 on the 寒暖燥湿 axis.
  static TiaoHou _tiaoHou(ChartResult chart) {
    final monthZhi = chart.pillars[1].zhi;
    final pct = chart.elementStrength.percent;
    const winter = ['亥', '子', '丑'];
    const summer = ['巳', '午', '未'];
    const spring = ['寅', '卯', '辰'];
    const autumn = ['申', '酉', '戌'];

    if (winter.contains(monthZhi)) {
      final fire = pct['火'] ?? 0;
      final water = pct['水'] ?? 0;
      final needs = <String>['火', if (water >= 40) '土'];
      return TiaoHou(
        climate: '寒',
        needed: needs,
        satisfied: fire >= 12,
        note: fire >= 12
            ? '冬生天寒，喜火暖局；局中火气尚可（${fire.toStringAsFixed(0)}%），调候得济'
            : '冬生天寒，非火不暖；局中火气仅${fire.toStringAsFixed(0)}%，'
                '${water >= 40 ? '且水旺成势，须戊土制水、丙火解冻' : '调候不足，行火运方能舒展'}',
      );
    }
    if (summer.contains(monthZhi)) {
      final water = pct['水'] ?? 0;
      final fire = pct['火'] ?? 0;
      return TiaoHou(
        climate: '暖燥',
        needed: const ['水'],
        satisfied: water >= 12,
        note: water >= 12
            ? '夏生火炎，喜水润局；局中水气尚可（${water.toStringAsFixed(0)}%），调候得济'
            : '夏生火炎土燥，非水不润；局中水气仅${water.toStringAsFixed(0)}%'
                '${fire >= 35 ? '，而火势${fire.toStringAsFixed(0)}%，燥烈尤甚' : ''}，'
                '须行金水之地',
      );
    }
    if (spring.contains(monthZhi)) {
      final fire = pct['火'] ?? 0;
      return TiaoHou(
        climate: '平',
        needed: const ['火'],
        satisfied: fire >= 10,
        note: '春生木旺，寒气未尽，喜丙火暖局、庚金修剪，调候非当务之急',
      );
    }
    if (autumn.contains(monthZhi)) {
      return const TiaoHou(
        climate: '平',
        needed: ['火', '水'],
        satisfied: true,
        note: '秋生金旺，喜丁火炼金、壬水淘洗，调候非当务之急',
      );
    }
    return const TiaoHou(
      climate: '平',
      needed: [],
      satisfied: true,
      note: '气候平和，以格局取用为主',
    );
  }
}
