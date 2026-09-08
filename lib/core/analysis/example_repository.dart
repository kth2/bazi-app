import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'analysis_example.dart';

/// One retrieved example plus how it was retrieved.
///
/// The distinction matters: an example that shares no structure with the
/// chart is style reference only, and presenting it the same way as a genuine
/// structural analogue invites the reader — and the model — to treat an
/// unrelated case's outcome as evidence.
class ExampleMatch {
  final AnalysisExample example;

  /// Weighted tag-overlap score; 0 for fallback picks.
  final int score;

  /// True when nothing overlapped and this was chosen purely for its prose.
  final bool isFallback;

  const ExampleMatch({
    required this.example,
    required this.score,
    required this.isFallback,
  });

  /// Which 格局 tags this case actually shares with the chart.
  Set<String> sharedWith(Set<String> chartTags) =>
      example.tags.intersection(chartTags);
}

/// Loads the bundled analysis examples and finds the most similar ones
/// for a given chart pattern.
class ExampleRepository {
  List<AnalysisExample>? _cache;

  Future<List<AnalysisExample>> loadAll() async {
    if (_cache != null) return _cache!;
    final raw =
        await rootBundle.loadString('assets/examples/analysis_examples.json');
    final list = jsonDecode(raw) as List;
    _cache = [
      for (final e in list) AnalysisExample.fromJson(e as Map<String, dynamic>),
    ];
    return _cache!;
  }

  /// For tests: inject examples directly.
  void seedForTesting(List<AnalysisExample> examples) => _cache = examples;

  /// Rank examples by weighted tag overlap with [chartTags], reporting
  /// whether each result is a genuine structural match or a fallback.
  Future<List<ExampleMatch>> findMatches(
    Set<String> chartTags, {
    int max = 2,
  }) async {
    final all = await loadAll();
    const geJuTags = {
      '正官格', '七杀格', '偏印格', '印绶格', '正印格', '食神格', '伤官格',
      '正财格', '偏财格', '建禄格', '阳刃格', '月劫格', '三奇格',
    };
    const genericTags = {'身强', '身弱'};

    int score(AnalysisExample e) {
      var s = 0;
      for (final t in e.tags.intersection(chartTags)) {
        if (geJuTags.contains(t)) {
          s += 3;
        } else if (genericTags.contains(t)) {
          s += 1;
        } else {
          s += 2;
        }
      }
      return s;
    }

    final scored = [for (final e in all) (e, score(e))]
      ..sort((a, b) => b.$2.compareTo(a.$2));

    final hits = scored.where((x) => x.$2 > 0).take(max);
    if (hits.isNotEmpty) {
      return [
        for (final h in hits)
          ExampleMatch(example: h.$1, score: h.$2, isFallback: false),
      ];
    }

    // No analogous case: fall back to the richest texts as style reference.
    // Flagged so the prompt can say so rather than presenting an unrelated
    // 命造 under the same heading as a real structural parallel.
    final byLength = [...all]
      ..sort((a, b) => b.content.length.compareTo(a.content.length));
    return [
      for (final e in byLength.take(max))
        ExampleMatch(example: e, score: 0, isFallback: true),
    ];
  }

  /// Convenience wrapper for callers that only need the examples.
  Future<List<AnalysisExample>> findSimilar(
    Set<String> chartTags, {
    int max = 2,
  }) async =>
      [for (final m in await findMatches(chartTags, max: max)) m.example];
}
