import '../models/chart_result.dart';

/// How much of a 十神 (or 十神 group) a chart actually holds.
///
/// Extracted so that both the pattern detector and the structure resolver can
/// ask the same question. They used to answer it differently: the resolver
/// tested 透干通根, while the detector counted raw occurrences including
/// 藏干 — which let one report say 印星 is 「仅见其气」(3.8%, not operative)
/// and simultaneously tag the chart 「官印相生」.
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

/// Builds [ShiShenPresence] for the five groups and the ten 十神.
class ShiShenPresenceTable {
  const ShiShenPresenceTable._();

  static const List<String> kGroups = ['比劫', '食伤', '财星', '官杀', '印星'];

  static const Map<String, List<String>> kGroupMembers = {
    '比劫': ['比肩', '劫财'],
    '食伤': ['食神', '伤官'],
    '财星': ['正财', '偏财'],
    '官杀': ['正官', '七杀'],
    '印星': ['正印', '偏印'],
  };

  static const Map<String, String> kGenerates = {
    '木': '火', '火': '土', '土': '金', '金': '水', '水': '木',
  };
  static const Map<String, String> kControls = {
    '木': '土', '土': '水', '水': '火', '火': '金', '金': '木',
  };

  /// The group a specific 十神 belongs to, or null if unknown.
  static String? groupOf(String shiShen) {
    for (final e in kGroupMembers.entries) {
      if (e.value.contains(shiShen)) return e.key;
    }
    return null;
  }

  static Map<String, ShiShenPresence> of(ChartResult chart) {
    final es = chart.elementStrength;
    final day = chart.dayMasterWuXing;
    final groupElement = {
      '比劫': day,
      '食伤': kGenerates[day]!,
      '财星': kControls[day]!,
      '官杀': kControls.entries.firstWhere((e) => e.value == day).key,
      '印星': kGenerates.entries.firstWhere((e) => e.value == day).key,
    };

    final out = <String, ShiShenPresence>{};

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
      final (transparent, total, rooted) = tally(kGroupMembers[g]!);
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
      for (final member in kGroupMembers[g]!) {
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
}
