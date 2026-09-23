import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/analysis/natal_structure.dart';
import 'package:bazi_app/core/analysis/reasoning_report.dart';
import 'package:bazi_app/core/cases/case_record.dart';
import 'package:bazi_app/core/cases/choice_question.dart';
import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/models/chart_result.dart';

/// Which of the engine's own judgements actually separate outcomes on 层次
/// questions?
///
///     BAZI_CASES_JSON=path/to/bazi_cases_….json \
///         flutter test test/feature_scan_test.dart
///
///     # only questions answered by engine v11 or later — the honest test
///     BAZI_CASES_JSON=… BAZI_MIN_VERSION=11 flutter test test/feature_scan_test.dart
///
/// Skipped when the variable is unset.
///
/// The goal of the app is for the rules to decide and the AI to explain. A
/// rule earns a place in that chain only if it tells charts apart: 「成格者
/// 层次高」 is worth encoding only if charts the engine calls 成格 actually
/// came out better. This scans candidate features — each one a judgement the
/// engine already makes — against the recorded answers to two-way 层次
/// questions and reports each with a two-sided Fisher exact p.
///
/// How to read it:
///
/// - With 25-odd features, one reaching p ≈ 0.05 is what chance alone
///   produces. A feature is a **candidate** at p < 0.05 and in the direction
///   the classics predict; it is **adopted** only after it holds on
///   questions asked *after* it was noticed (BAZI_MIN_VERSION set past the
///   version current when it was noticed).
/// - Nothing here edits the engine. A person reads the output and, if a
///   feature holds up, writes the rule and cites the source for it.
///
/// First run (2026-09-23, 34 层次 questions, engine v11): no feature below
/// p = 0.14. The leading one was 身强 (55% brighter vs 26%), in the
/// direction of 「身旺能任财官」 — a candidate to watch, not a rule.
void main() {
  final path = Platform.environment['BAZI_CASES_JSON'];
  final minVersion =
      int.tryParse(Platform.environment['BAZI_MIN_VERSION'] ?? '') ?? 0;

  test('natal features against 层次 outcomes', () {
    final raw = jsonDecode(File(path!).readAsStringSync()) as Map;
    final records = [
      for (final c in raw['cases'] as List)
        CaseRecord.fromJson(c as Map<String, dynamic>),
    ];

    final samples = <({NatalStructure s, ChartResult chart, bool brighter})>[];
    for (final r in records) {
      if (r.engineVersion < minVersion) continue;
      for (final q in r.claims) {
        if (q.kind != ClaimKind.qa || q.lean == OptionLean.none) continue;
        if (q.choice?.topic != QuestionTopic.level) continue;
        if (q.verdict != ClaimVerdict.hit && q.verdict != ClaimVerdict.miss) {
          continue;
        }
        final chart = ChartService.compute(r.input);
        samples.add((
          s: ReasoningReport.build(chart, const []).structure,
          chart: chart,
          brighter:
              (q.lean == OptionLean.brighter) == (q.verdict == ClaimVerdict.hit),
        ));
      }
    }

    final out = StringBuffer();
    final n = samples.length;
    final base = samples.where((x) => x.brighter).length;
    out.writeln('── 层次题特征扫描：$n 题，实际为较好一项 $base'
        '${minVersion > 0 ? '（仅 v$minVersion 及以后）' : ''} ──');

    final results = <(double, String)>[];
    for (final MapEntry(key: name, value: f) in _features.entries) {
      var a = 0, ny = 0, c = 0, nn = 0;
      for (final x in samples) {
        if (f(x.s, x.chart)) {
          ny++;
          if (x.brighter) a++;
        } else {
          nn++;
          if (x.brighter) c++;
        }
      }
      if (ny == 0 || nn == 0) continue;
      final p = fisherTwoSided(a, ny - a, c, nn - c);
      results.add((
        p,
        '${name.padRight(10, '　')} 有：$a/$ny=${_pct(a, ny)}'
            '  无：$c/$nn=${_pct(c, nn)}  p=${p.toStringAsFixed(2)}'
            '${p < 0.05 ? '  ← 候选' : ''}',
      ));
    }
    results.sort((x, y) => x.$1.compareTo(y.$1));
    for (final (_, line) in results) {
      out.writeln(line);
    }
    out.writeln('（测了 ${results.length} 个特征；只靠运气，'
        '约 ${(results.length * 0.05).toStringAsFixed(1)} 个会落到 p<0.05。）');
    // ignore: avoid_print
    print(out);
  }, skip: path == null ? 'set BAZI_CASES_JSON to an exported journal' : false);

  test('fisherTwoSided matches known values', () {
    // Tea-tasting table: 3 1 / 1 3 → 0.486.
    expect(fisherTwoSided(3, 1, 1, 3), closeTo(0.486, 0.001));
    expect(fisherTwoSided(5, 0, 0, 5), closeTo(0.0079, 0.0001));
    expect(fisherTwoSided(2, 2, 2, 2), closeTo(1.0, 1e-9));
  });
}

String _pct(int a, int n) => '${(a * 100 / n).round()}%';

typedef _Feature = bool Function(NatalStructure s, ChartResult chart);

bool _op(NatalStructure s, String g) => s.presence[g]?.isOperative ?? false;
bool _shown(NatalStructure s, String g) => (s.presence[g]?.transparent ?? 0) > 0;
double _share(NatalStructure s, String g) => s.presence[g]?.strength ?? 0;
bool _scene(NatalStructure s, String name) =>
    s.pattern.scenarios.any((x) => x.name == name);

/// Each one a judgement the engine already makes. Adding a feature here is
/// free; adopting one as a rule is not — see the header.
final Map<String, _Feature> _features = {
  '成格': (s, _) => s.status == GeJuStatus.cheng,
  '破而有救': (s, _) => s.status == GeJuStatus.jiuYing,
  '破格': (s, _) => s.status == GeJuStatus.po,
  '身强': (_, c) => c.elementStrength.verdict == '身强',
  '身弱': (_, c) => c.elementStrength.verdict == '身弱',
  '调候得济': (s, _) => s.tiaoHou.satisfied,
  '变格': (s, _) => s.pattern.isBianGe,
  '财星透干': (s, _) => _shown(s, '财星'),
  '财星有力': (s, _) => _op(s, '财星'),
  '财星≥25%': (s, _) => _share(s, '财星') >= 25,
  '食伤透干': (s, _) => _shown(s, '食伤'),
  '食伤有力': (s, _) => _op(s, '食伤'),
  '官杀透干': (s, _) => _shown(s, '官杀'),
  '官杀有力': (s, _) => _op(s, '官杀'),
  '印星有力': (s, _) => _op(s, '印星'),
  '比劫透干': (s, _) => _shown(s, '比劫'),
  '比劫≥30%': (s, _) => _share(s, '比劫') >= 30,
  '财官双透': (s, _) => _shown(s, '财星') && _shown(s, '官杀'),
  '身强财有力': (s, c) =>
      c.elementStrength.verdict == '身强' && _op(s, '财星'),
  '食伤财皆有力': (s, _) => _op(s, '食伤') && _op(s, '财星'),
  '食伤生财': (s, _) => _scene(s, '食伤生财'),
  '官印相生': (s, _) => _scene(s, '官印相生'),
  '比劫争财': (s, _) => _scene(s, '比劫争财'),
  '财多身弱': (s, _) => _scene(s, '财多身弱'),
  '食神制杀': (s, _) => _scene(s, '食神制杀'),
  '官杀混杂': (s, _) => _scene(s, '官杀混杂'),
};

/// Two-sided Fisher exact test on the table [a b / c d]: the probability,
/// with margins fixed, of a table at least as unlikely as this one.
///
/// Exact rather than χ² because the cells here are single digits.
double fisherTwoSided(int a, int b, int c, int d) {
  final r1 = a + b, r2 = c + d, c1 = a + c, n = r1 + r2;
  double logChoose(int n, int k) =>
      _logFact(n) - _logFact(k) - _logFact(n - k);
  double prob(int x) => math.exp(
      logChoose(r1, x) + logChoose(r2, c1 - x) - logChoose(n, c1));
  final observed = prob(a);
  var p = 0.0;
  for (var x = math.max(0, c1 - r2); x <= math.min(c1, r1); x++) {
    final px = prob(x);
    if (px <= observed * (1 + 1e-9)) p += px;
  }
  return math.min(1, p);
}

double _logFact(int n) {
  var s = 0.0;
  for (var i = 2; i <= n; i++) {
    s += math.log(i);
  }
  return s;
}
