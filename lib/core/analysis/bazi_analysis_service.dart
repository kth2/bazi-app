import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/ai_service.dart';
import '../models/chart_result.dart';
import '../rules/rule.dart';
import 'analysis_prompt.dart';
import 'example_repository.dart';
import 'reasoning_report.dart';

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

/// Answer to a free-form user question about the chart.
class CustomAnswer {
  final String question;
  final String scope;
  final String answer;
  final String patternSummary;

  const CustomAnswer({
    required this.question,
    required this.scope,
    required this.answer,
    required this.patternSummary,
  });

  Map<String, dynamic> toJson() => {
        'question': question,
        'scope': scope,
        'answer': answer,
        'patternSummary': patternSummary,
      };

  factory CustomAnswer.fromJson(Map<String, dynamic> json) => CustomAnswer(
        question: json['question'] as String,
        scope: json['scope'] as String,
        answer: json['answer'] as String,
        patternSummary: json['patternSummary'] as String? ?? '',
      );
}

/// Orchestrates: rule scoring → pattern detection → example matching →
/// AI call → section parsing, with local caching to protect free-tier quota.
class BaziAnalysisService {
  /// Bumped whenever any deterministic reasoning layer (PatternDetector,
  /// NatalStructure, EvidenceEngine, activation/应期) changes shape.
  ///
  /// Cached AI text is the *output* of a specific engine version, so a bump
  /// must invalidate it — otherwise an engine improvement is invisible to
  /// anyone who already ran the analysis once.
  static const int kEngineVersion = 5;

  static String _cachePrefix(String kind) => 'ai_${kind}_v${kEngineVersion}_';

  /// Any key this class has ever written, across engine versions.
  static const List<String> _legacyPrefixes = ['ai_cache_', 'ai_qa_'];

  static bool _purgedStaleCaches = false;

  final ExampleRepository examples;
  final AiService ai;

  BaziAnalysisService({required this.examples, required this.ai});

  /// Drops entries written by a different engine version (including the
  /// original unversioned keys). Runs once per process.
  static Future<void> _purgeStaleCaches(SharedPreferences prefs) async {
    if (_purgedStaleCaches) return;
    _purgedStaleCaches = true;
    final current = [_cachePrefix('cache'), _cachePrefix('qa')];
    for (final k in prefs.getKeys().toList()) {
      final isOurs = _legacyPrefixes.any(k.startsWith);
      if (isOurs && !current.any(k.startsWith)) {
        await prefs.remove(k);
      }
    }
  }

  /// Runs the purge regardless of the once-per-process guard.
  @visibleForTesting
  static Future<void> purgeStaleCachesForTesting(SharedPreferences prefs) {
    _purgedStaleCaches = false;
    return _purgeStaleCaches(prefs);
  }

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

  /// 流月分析 (with its 大运/流年 context) — month-level event forecast.
  Future<ScopedAnalysis> analyzeLiuYue(ChartResult chart, List<Rule> rules,
          DecadeData decade, FlowYearData year, FlowMonthData month) =>
      _analyze(chart, rules, decade: decade, year: year, month: month);

  /// 流日分析 (with its 大运/流年/流月 context) — day-level event forecast.
  Future<ScopedAnalysis> analyzeLiuRi(ChartResult chart, List<Rule> rules,
          DecadeData decade, FlowYearData year, FlowMonthData month,
          FlowDayData day) =>
      _analyze(chart, rules, decade: decade, year: year, month: month,
          day: day);

  /// Human-readable scope label; also part of the cache key, so it must be
  /// deterministic for a given selection.
  static String scopeLabel({
    DecadeData? decade,
    FlowYearData? year,
    FlowMonthData? month,
    FlowDayData? day,
  }) {
    if (day != null) {
      final d = day.date;
      final ymd = '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      return '流日 $ymd ${day.ganZhi}';
    }
    if (month != null && year != null) {
      return '流月 ${year.year}年${month.ganZhi}月（${month.jieName}）';
    }
    if (year != null) return '流年 ${year.year} ${year.ganZhi}';
    if (decade != null) {
      return '大运 ${decade.ganZhi}（${decade.startAge}-${decade.endAge}岁）';
    }
    return '整体命局';
  }

  /// Free-form question answered against the chart + optional
  /// 大运/流年/流月/流日 scope.
  /// Cached per (chart + scope + question) so re-asking is free.
  Future<CustomAnswer> askQuestion(
    ChartResult chart,
    List<Rule> rules,
    String question, {
    DecadeData? decade,
    FlowYearData? year,
    FlowMonthData? month,
    FlowDayData? day,
  }) async {
    final scope = scopeLabel(decade: decade, year: year, month: month, day: day);

    final normalizedQ = question.trim();
    final cacheKey = '${_cachePrefix('qa')}${chart.baziString}_'
        '${chart.input.gender.name}_${scope}_${normalizedQ.hashCode}';
    final prefs = await SharedPreferences.getInstance();
    await _purgeStaleCaches(prefs);
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      return CustomAnswer.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }

    final report = ReasoningReport.build(chart, rules,
        decade: decade, year: year, month: month, day: day);
    final similar = await examples.findMatches(report.pattern.tags);

    final prompt = AnalysisPrompt.buildCustom(
      report: report,
      examples: similar,
      question: normalizedQ,
    );

    final settings = await AiSettings.load();
    final response = await ai.complete(prompt, settings);

    final result = CustomAnswer(
      question: normalizedQ,
      scope: scope,
      answer: response.trim(),
      patternSummary: report.structure.summary,
    );
    await prefs.setString(cacheKey, jsonEncode(result.toJson()));
    return result;
  }

  Future<ScopedAnalysis> _analyze(
    ChartResult chart,
    List<Rule> rules, {
    DecadeData? decade,
    FlowYearData? year,
    FlowMonthData? month,
    FlowDayData? day,
  }) async {
    final scope = scopeLabel(decade: decade, year: year, month: month, day: day);

    final cacheKey = '${_cachePrefix('cache')}${chart.baziString}_'
        '${chart.input.gender.name}_$scope';
    final prefs = await SharedPreferences.getInstance();
    await _purgeStaleCaches(prefs);
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      return ScopedAnalysis.fromJson(
          jsonDecode(cached) as Map<String, dynamic>);
    }

    final report = ReasoningReport.build(chart, rules,
        decade: decade, year: year, month: month, day: day);
    final similar = await examples.findMatches(report.pattern.tags);

    final prompt = AnalysisPrompt.build(
      report: report,
      examples: similar,
    );

    final settings = await AiSettings.load();
    final response = await ai.complete(prompt, settings);

    final result = _parse(
      response,
      scope: scope,
      citedIds: [for (final m in similar) m.example.id],
      patternSummary: report.structure.summary,
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

  /// Clears cached AI results (4-category analyses and Q&A) for this chart.
  static Future<void> clearCacheFor(ChartResult chart) async {
    final prefs = await SharedPreferences.getInstance();
    final bazi = chart.baziString;
    final prefixes = [
      '${_cachePrefix('cache')}${bazi}_',
      '${_cachePrefix('qa')}${bazi}_',
    ];
    for (final k in prefs
        .getKeys()
        .where((k) => prefixes.any(k.startsWith))
        .toList()) {
      await prefs.remove(k);
    }
  }
}
