import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../services/ai_service.dart';
import '../models/chart_result.dart';
import '../rules/rule.dart';
import '../rules/rule_engine.dart';
import 'analysis_prompt.dart';
import 'example_repository.dart';
import 'pattern_detector.dart';

/// One AI analysis result, split into the 4 life categories.
class ScopedAnalysis {
  final String scope; // 整体命局 / 大运 乙亥 (9-18岁) / 流年 2027 丁未
  final String careerWealth; // 事业财富
  final String marriage; // 婚姻感情
  final String studyGrowth; // 学习/发展
  final String health; // 健康分析
  final String rawText;
  final List<String> citedExampleIds;
  final String patternSummary;

  const ScopedAnalysis({
    required this.scope,
    required this.careerWealth,
    required this.marriage,
    required this.studyGrowth,
    required this.health,
    required this.rawText,
    required this.citedExampleIds,
    required this.patternSummary,
  });

  Map<String, dynamic> toJson() => {
        'scope': scope,
        'careerWealth': careerWealth,
        'marriage': marriage,
        'studyGrowth': studyGrowth,
        'health': health,
        'rawText': rawText,
        'citedExampleIds': citedExampleIds,
        'patternSummary': patternSummary,
      };

  factory ScopedAnalysis.fromJson(Map<String, dynamic> json) => ScopedAnalysis(
        scope: json['scope'] as String,
        careerWealth: json['careerWealth'] as String,
        marriage: json['marriage'] as String,
        studyGrowth: json['studyGrowth'] as String,
        health: json['health'] as String,
        rawText: json['rawText'] as String,
        citedExampleIds:
            (json['citedExampleIds'] as List?)?.cast<String>() ?? const [],
        patternSummary: json['patternSummary'] as String? ?? '',
      );
}

/// Orchestrates: rule scoring → pattern detection → example matching →
/// AI call → section parsing, with local caching to protect free-tier quota.
class BaziAnalysisService {
  final ExampleRepository examples;
  final AiService ai;

  BaziAnalysisService({required this.examples, required this.ai});

  /// 整体命局 whole-life analysis.
  Future<ScopedAnalysis> analyzeLife(ChartResult chart, List<Rule> rules) =>
      _analyze(chart, rules, decade: null, year: null);

  /// 十年大运分析.
  Future<ScopedAnalysis> analyzeDaYun(
          ChartResult chart, List<Rule> rules, DecadeData decade) =>
      _analyze(chart, rules, decade: decade, year: null);

  /// 流年分析 (with its 大运 context).
  Future<ScopedAnalysis> analyzeLiuNian(ChartResult chart, List<Rule> rules,
          DecadeData decade, FlowYearData year) =>
      _analyze(chart, rules, decade: decade, year: year);

  Future<ScopedAnalysis> _analyze(
    ChartResult chart,
    List<Rule> rules, {
    DecadeData? decade,
    FlowYearData? year,
  }) async {
    final scope = year != null
        ? '流年 ${year.year} ${year.ganZhi}'
        : decade != null
            ? '大运 ${decade.ganZhi}（${decade.startAge}-${decade.endAge}岁）'
            : '整体命局';

    final cacheKey = 'ai_cache_${chart.baziString}_'
        '${chart.input.gender.name}_$scope';
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      return ScopedAnalysis.fromJson(
          jsonDecode(cached) as Map<String, dynamic>);
    }

    final pattern = PatternDetector.detect(chart);
    final ruleMatches = RuleEngine.evaluate(chart, rules);
    final similar = await examples.findSimilar(pattern.tags);

    final prompt = AnalysisPrompt.build(
      chart: chart,
      pattern: pattern,
      ruleMatches: ruleMatches,
      examples: similar,
      decade: decade,
      year: year,
    );

    final settings = await AiSettings.load();
    final response = await ai.complete(prompt, settings);

    final result = _parse(
      response,
      scope: scope,
      citedIds: similar.map((e) => e.id).toList(),
      patternSummary: pattern.summary,
    );
    await prefs.setString(cacheKey, jsonEncode(result.toJson()));
    return result;
  }

  /// Split the plain-text response on 「一、事业财富」…「四、健康分析」 headers.
  /// Tolerant of formatting drift; falls back to raw text in section 1.
  static ScopedAnalysis _parse(
    String text, {
    required String scope,
    required List<String> citedIds,
    required String patternSummary,
  }) {
    String section(int index, String title, String? nextTitle) {
      final startPattern = RegExp('[「【]?[一二三四]\\s*、\\s*$title[」】]?');
      final start = startPattern.firstMatch(text);
      if (start == null) return '';
      var body = text.substring(start.end);
      if (nextTitle != null) {
        final next =
            RegExp('[「【]?[一二三四]\\s*、\\s*$nextTitle[」】]?').firstMatch(body);
        if (next != null) body = body.substring(0, next.start);
      }
      return body.trim();
    }

    final career = section(1, '事业财富', '婚姻感情');
    final marriage = section(2, '婚姻感情', '学习/发展|学习发展|学习／发展');
    final study = section(3, '学习/发展|学习发展|学习／发展', '健康分析|健康');
    final health = section(4, '健康分析|健康', null);

    final parsed = career.isNotEmpty ||
        marriage.isNotEmpty ||
        study.isNotEmpty ||
        health.isNotEmpty;

    return ScopedAnalysis(
      scope: scope,
      careerWealth: parsed ? career : text.trim(),
      marriage: marriage,
      studyGrowth: study,
      health: health,
      rawText: text,
      citedExampleIds: citedIds,
      patternSummary: patternSummary,
    );
  }

  /// Clears cached AI results (e.g. after re-analysis request).
  static Future<void> clearCacheFor(ChartResult chart) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'ai_cache_${chart.baziString}_';
    for (final k in prefs.getKeys().where((k) => k.startsWith(prefix)).toList()) {
      await prefs.remove(k);
    }
  }
}
