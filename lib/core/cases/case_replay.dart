import '../analysis/reasoning_report.dart';
import '../engine/chart_service.dart';
import '../models/chart_result.dart';
import '../rules/rule.dart';
import 'case_record.dart';

/// Rebuilds a saved case's reasoning with the engine as it is *now*.
///
/// A case stores what the engine said at the time; replaying it answers a
/// different question — what would today's engine (and today's 条例) say about
/// the same chart and scope. The rule backtest and `test/case_replay_test`
/// both need that.
class CaseReplay {
  CaseReplay._();

  /// The 大运/流年 a saved scope label points at, on [chart].
  ///
  /// `(decade: null, year: null)` for 整体命局. Null for 流月/流日 (not
  /// rebuilt here) and for a label the chart cannot place.
  static ({DecadeData? decade, FlowYearData? year})? scopeOf(
      ChartResult chart, String label) {
    if (label.startsWith('整体命局')) return (decade: null, year: null);

    final decadeMatch = RegExp(r'^大运\s*(\S{2})').firstMatch(label);
    if (decadeMatch != null) {
      final gz = decadeMatch.group(1)!;
      final decade = chart.decades.where((d) => d.ganZhi == gz).firstOrNull;
      return decade == null ? null : (decade: decade, year: null);
    }

    final yearMatch = RegExp(r'^流年\s*(\d{4})').firstMatch(label);
    if (yearMatch != null) {
      final y = int.parse(yearMatch.group(1)!);
      for (final decade in chart.decades) {
        final year = ChartService.flowYearsOf(chart, decade)
            .where((f) => f.year == y)
            .firstOrNull;
        if (year != null) return (decade: decade, year: year);
      }
      final pre = chart.preDaYunYears.where((f) => f.year == y).firstOrNull;
      return pre == null ? null : (decade: null, year: pre);
    }
    return null;
  }

  /// Null for 流月/流日 scopes, which A/B questions are not asked at, and for
  /// a scope label the current chart cannot place.
  static ReasoningReport? rebuild(CaseRecord record, List<Rule> rules) {
    final chart = ChartService.compute(record.input);
    final scope = scopeOf(chart, record.scopeLabel);
    if (scope == null) return null;
    return ReasoningReport.build(chart, rules,
        decade: scope.decade, year: scope.year);
  }
}
