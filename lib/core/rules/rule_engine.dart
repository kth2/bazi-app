import '../models/birth_input.dart';
import '../models/chart_result.dart';
import 'rule.dart';

/// Evaluates weighted rules against a ChartResult.
///
/// Scoring: matchRatio = matched conditions / total conditions.
/// A rule fires when matchRatio >= rule.minMatchRatio AND every condition
/// marked `required` matches. Score = weight × matchRatio, so partially
/// matched rules surface with proportionally lower confidence.
class RuleEngine {
  /// 十神 groups usable anywhere a 十神 name is expected.
  static const Map<String, List<String>> _shiShenGroups = {
    '比劫': ['比肩', '劫财'],
    '印星': ['正印', '偏印'],
    '财星': ['正财', '偏财'],
    '官杀': ['正官', '七杀'],
    '食伤': ['食神', '伤官'],
  };

  static List<String> _expand(String value) =>
      _shiShenGroups[value] ?? [value];

  /// Evaluate all [rules]; returns fired matches sorted by score descending.
  static List<RuleMatch> evaluate(ChartResult chart, List<Rule> rules) {
    final matches = <RuleMatch>[];
    for (final rule in rules) {
      final matched = <RuleCondition>[];
      var requiredFailed = false;
      for (final c in rule.conditions) {
        if (_check(chart, c)) {
          matched.add(c);
        } else if (c.required) {
          requiredFailed = true;
          break;
        }
      }
      if (requiredFailed || rule.conditions.isEmpty) continue;
      final ratio = matched.length / rule.conditions.length;
      if (ratio >= rule.minMatchRatio) {
        matches.add(RuleMatch(
          rule: rule,
          matchRatio: ratio,
          score: rule.weight * ratio,
          matchedConditions: matched,
        ));
      }
    }
    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches;
  }

  /// Group fired matches by category, preserving score order.
  static Map<String, List<RuleMatch>> groupByCategory(List<RuleMatch> matches) {
    final grouped = <String, List<RuleMatch>>{};
    for (final m in matches) {
      grouped.putIfAbsent(m.rule.category, () => []).add(m);
    }
    return grouped;
  }

  // ---------------------------------------------------------------------
  // Condition checks
  // ---------------------------------------------------------------------

  static bool _check(ChartResult chart, RuleCondition c) {
    switch (c.type) {
      case 'gender':
        final g = chart.input.gender == Gender.male ? '男' : '女';
        return g == c.value;

      case 'verdict':
        return chart.elementStrength.verdict == c.value;

      case 'seasonState':
        return chart.elementStrength.dayMasterSeasonState == c.value;

      case 'dayMasterElement':
        return chart.dayMasterWuXing == c.value;

      case 'monthBranch':
        return chart.pillars[1].zhi == c.value;

      case 'branchAt':
        final p = _pillarAt(chart, c.position);
        return p != null && p.zhi == c.value;

      case 'stemAt':
        final p = _pillarAt(chart, c.position);
        return p != null && p.gan == c.value;

      case 'hasShiShen':
        return _countShiShen(chart, c) >= 1;

      case 'shiShenCount':
        return _countShiShen(chart, c) >= c.count;

      case 'lacksShiShen':
        return _countShiShen(chart, c) == 0;

      case 'hasShenSha':
        final pillars = c.position == null
            ? chart.pillars
            : chart.pillars.where((p) => p.position == c.position);
        return pillars
            .any((p) => p.shenSha.any((s) => s.contains(c.value ?? '')));

      case 'hasInteraction':
        return chart.interactions.any((i) {
          if (i.type != c.value) return false;
          if (c.position == null) return true;
          return i.parties.any((party) => party.startsWith(c.position!));
        });

      case 'interactionCount':
        final kinds = c.kinds.isEmpty ? const ['地支六冲', '相刑', '自刑', '三刑全', '地支六害'] : c.kinds;
        final n = chart.interactions.where((i) => kinds.contains(i.type)).length;
        return n >= c.count;

      case 'elementPercent':
        final pct = chart.elementStrength.percent[c.value] ?? 0;
        return c.op == '<=' ? pct <= c.threshold : pct >= c.threshold;

      case 'kongWang':
        final p = _pillarAt(chart, c.position);
        return p != null && p.isKongWang;

      default:
        return false;
    }
  }

  static PillarData? _pillarAt(ChartResult chart, String? position) {
    if (position == null) return null;
    for (final p in chart.pillars) {
      if (p.position == position) return p;
    }
    return null;
  }

  /// Count occurrences of a 十神 (or group) in the chart.
  ///
  /// scope: stem = 天干 only (excluding day master),
  ///        main = 天干 + 本气藏干,
  ///        any  = 天干 + 全部藏干.
  static int _countShiShen(ChartResult chart, RuleCondition c) {
    final targets = _expand(c.value ?? '');
    final pillars = c.position == null
        ? chart.pillars
        : chart.pillars.where((p) => p.position == c.position).toList();
    var n = 0;
    for (final p in pillars) {
      if (p.ganShiShen != '日主' && targets.contains(p.ganShiShen)) n++;
      if (c.scope == 'stem') continue;
      final hidden = c.scope == 'main'
          ? (p.cangGan.isEmpty ? p.cangGan : [p.cangGan.first])
          : p.cangGan;
      for (final h in hidden) {
        if (targets.contains(h.shiShen)) n++;
      }
    }
    return n;
  }
}
