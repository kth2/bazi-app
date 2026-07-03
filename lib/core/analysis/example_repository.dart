import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'analysis_example.dart';

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

  /// Rank examples by weighted tag overlap with [chartTags].
  /// 格局 match ×3, special-scenario ×2, generic (身强/身弱) ×1.
  /// Returns the top [max] with score > 0; if none overlap, returns the
  /// [max] longest examples as pure style reference.
  Future<List<AnalysisExample>> findSimilar(
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

    final hits = scored.where((x) => x.$2 > 0).take(max).map((x) => x.$1);
    if (hits.isNotEmpty) return hits.toList();

    // No analogous case: fall back to the richest texts as style reference.
    final byLength = [...all]
      ..sort((a, b) => b.content.length.compareTo(a.content.length));
    return byLength.take(max).toList();
  }
}
