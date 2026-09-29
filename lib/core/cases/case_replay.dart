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

  /// Null for 流月/流日 scopes, which A/B questions are not asked at, and for
  /// a scope label the current chart cannot place.
  static ReasoningReport? rebuild(CaseRecord record, List<Rule> rules) {
    final chart = ChartService.compute(record.input);
    final label = record.scopeLabel;

    if (label.startsWith('整体命局')) {
      return ReasoningReport.build(chart, rules);
    }

    final decadeMatch = RegExp(r'^大运\s*(\S{2})').firstMatch(label);
    if (decadeMatch != null) {
      final gz = decadeMatch.group(1)!;
      final decade = chart.decades.where((d) => d.ganZhi == gz).firstOrNull;
      return decade == null
          ? null
          : ReasoningReport.build(chart, rules, decade: decade);
    }

    final yearMatch = RegExp(r'^流年\s*(\d{4})').firstMatch(label);
    if (yearMatch != null) {
      final y = int.parse(yearMatch.group(1)!);
      for (final decade in chart.decades) {
        final year = ChartService.flowYearsOf(chart, decade)
            .where((f) => f.year == y)
            .firstOrNull;
        if (year != null) {
          return ReasoningReport.build(chart, rules,
              decade: decade, year: year);
        }
      }
      final FlowYearData? pre =
          chart.preDaYunYears.where((f) => f.year == y).firstOrNull;
      return pre == null
          ? null
          : ReasoningReport.build(chart, rules, year: pre);
    }
    return null;
  }
}
