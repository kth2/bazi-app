import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/analysis/reasoning_report.dart';
import 'package:bazi_app/core/cases/case_record.dart';
import 'package:bazi_app/core/cases/case_statistics.dart';
import 'package:bazi_app/core/cases/choice_question.dart';
import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/models/chart_result.dart';
import 'package:bazi_app/core/rules/rule.dart';

/// Replays an exported case journal through the *current* engine and asks
/// one question: does the engine's 净评估 point at what actually happened?
///
///     BAZI_CASES_JSON=path/to/bazi_cases_….json \
///         flutter test test/case_replay_test.dart
///
/// Skipped when the variable is unset — the journal is the user's data and
/// is not checked in.
///
/// Why this exists: the prompt used to bind the AI's A/B answer to the
/// engine's net 吉凶 count. That binding is only as good as the count, and
/// nobody had checked the count against outcomes. Every engine change since
/// has been judged on a 240-chart grid for *balance* — which says nothing
/// about whether it is *right*. Run this before and after any change to
/// `lib/core/analysis`; a change that does not move these numbers the right
/// way has not been shown to help.
///
/// Read-only. This is a test, not engine code: `case_guardrail_test.dart`
/// still forbids the engine from importing the journal, and nothing here
/// feeds back into it.
void main() {
  final path = Platform.environment['BAZI_CASES_JSON'];

  test('current engine 净评估 against recorded A/B outcomes', () {
    final raw = jsonDecode(File(path!).readAsStringSync()) as Map;
    final records = [
      for (final c in raw['cases'] as List)
        CaseRecord.fromJson(c as Map<String, dynamic>),
    ];
    final rules = _seedRules();

    // topic → [agree, disagree, engineSilent]
    final byTopic = <String, List<int>>{};
    final lines = <String>[];

    for (final record in records) {
      final questions = [
        for (final c in record.claims)
          if (c.kind == ClaimKind.qa &&
              c.lean != OptionLean.none &&
              (c.verdict == ClaimVerdict.hit ||
                  c.verdict == ClaimVerdict.miss))
            c,
      ];
      if (questions.isEmpty) continue;

      final report = _rebuild(record, rules);
      if (report == null) continue;
      final net = report.assessment.net;

      for (final q in questions) {
        final truthBrighter =
            (q.lean == OptionLean.brighter) == (q.verdict == ClaimVerdict.hit);
        final topic = q.choice?.topic.label ?? '手动标注';
        final slot = byTopic.putIfAbsent(topic, () => [0, 0, 0]);
        final String mark;
        if (net == 0) {
          slot[2]++;
          mark = '　';
        } else if ((net > 0) == truthBrighter) {
          slot[0]++;
          mark = '✓';
        } else {
          slot[1]++;
          mark = '✗';
        }
        lines.add('$mark net=${net.toString().padLeft(3)} '
            '实为${truthBrighter ? '较好' : '较平'} '
            'v${record.engineVersion} ${record.baziString} '
            '${record.scopeLabel} | ${q.title.replaceAll(RegExp(r'\s+'), ' ')}');
      }
    }

    final out = StringBuffer()
      ..writeln('── 当前引擎净评估 vs 实际（v${_engineVersion()}）──');
    var agree = 0, disagree = 0, silent = 0;
    for (final e in byTopic.entries) {
      final [a, d, s] = e.value;
      agree += a;
      disagree += d;
      silent += s;
      out.writeln(_row(e.key, a, d, s));
    }
    out
      ..writeln(_row('合计', agree, disagree, silent))
      ..writeln('（「一致」= 净评估偏吉且实为较好一项，或偏凶且实为较平一项；'
          '无信息时约 50%。）')
      ..writeln()
      ..writeAll(lines, '\n');
    // ignore: avoid_print
    print(out);
  }, skip: path == null ? 'set BAZI_CASES_JSON to an exported journal' : false);
}

String _row(String label, int agree, int disagree, int silent) {
  final n = agree + disagree;
  final ci = wilson95(agree, n);
  final rate = n == 0 ? '—' : '${(agree * 100 / n).round()}%';
  final band = ci == null
      ? ''
      : '（95% ${(ci.$1 * 100).round()}–${(ci.$2 * 100).round()}%）';
  return '${label.padRight(6, '　')} 一致 $agree / $n = $rate$band'
      '，净评估为零 $silent';
}

int _engineVersion() {
  final src =
      File('lib/core/analysis/bazi_analysis_service.dart').readAsStringSync();
  return int.parse(RegExp(r'kEngineVersion = (\d+)').firstMatch(src)!.group(1)!);
}

List<Rule> _seedRules() {
  final json = jsonDecode(
      File('assets/rules/seed_rules.json').readAsStringSync()) as Map;
  return [
    for (final r in json['rules'] as List)
      Rule.fromJson(r as Map<String, dynamic>),
  ];
}

/// Rebuilds the scope a case was saved under. 流月/流日 cases are skipped —
/// A/B questions are asked at 命局, 大运 or 流年 depth.
ReasoningReport? _rebuild(CaseRecord record, List<Rule> rules) {
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
    return pre == null ? null : ReasoningReport.build(chart, rules, year: pre);
  }
  return null;
}
