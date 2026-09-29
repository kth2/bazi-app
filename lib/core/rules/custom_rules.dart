import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A 条例 the user adopted after the AI proposed it from failed cases and a
/// backtest measured it.
///
/// These live beside the engine rather than inside it. The engine's own
/// logic — 格局, 成败, 相神 — is code, changed by a person reading the
/// classics; a custom 条例 is text the AI is told to apply on top of that
/// chain. What the two share is the bar for getting in: no 条例 becomes
/// active without a measured result and a person's explicit 「采用」.
class CustomRule {
  final String id;

  /// 财格佩印，财印不宜相并
  final String title;

  /// The rule as the AI should apply it: when it applies, and what follows.
  final String text;

  /// Classical source, or 「经验」 when there is none.
  final String source;

  /// Why it was proposed — the AI's reading of the failures it came from.
  final String rationale;

  /// Cases the rule was inferred from. Kept so a backtest can hold them out.
  final List<String> derivedFrom;

  /// Whether the AI applies it now. A retired rule stays on the list so it
  /// can be restored and so the history of what was tried is not lost.
  final bool active;

  final DateTime createdAt;

  /// The measurement that justified adopting it.
  final BacktestSummary? backtest;

  const CustomRule({
    required this.id,
    required this.title,
    required this.text,
    this.source = '',
    this.rationale = '',
    this.derivedFrom = const [],
    this.active = true,
    required this.createdAt,
    this.backtest,
  });

  CustomRule copyWith({
    String? title,
    String? text,
    String? source,
    bool? active,
    BacktestSummary? backtest,
  }) =>
      CustomRule(
        id: id,
        title: title ?? this.title,
        text: text ?? this.text,
        source: source ?? this.source,
        rationale: rationale,
        derivedFrom: derivedFrom,
        active: active ?? this.active,
        createdAt: createdAt,
        backtest: backtest ?? this.backtest,
      );

  /// One line for the prompt.
  String get promptLine =>
      '$title：$text${source.isEmpty ? '' : '（出处：$source）'}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'text': text,
        'source': source,
        'rationale': rationale,
        'derivedFrom': derivedFrom,
        'active': active,
        'createdAt': createdAt.toIso8601String(),
        if (backtest != null) 'backtest': backtest!.toJson(),
      };

  factory CustomRule.fromJson(Map<String, dynamic> j) => CustomRule(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        text: j['text'] as String? ?? '',
        source: j['source'] as String? ?? '',
        rationale: j['rationale'] as String? ?? '',
        derivedFrom: [
          for (final x in (j['derivedFrom'] as List? ?? const [])) x as String,
        ],
        active: j['active'] as bool? ?? true,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        backtest: j['backtest'] is Map<String, dynamic>
            ? BacktestSummary.fromJson(j['backtest'] as Map<String, dynamic>)
            : null,
      );
}

/// The numbers a 条例 was adopted on, kept with it.
class BacktestSummary {
  /// Questions scored.
  final int n;

  /// Right under the rule set in force at the time.
  final int baselineHits;

  /// Right with this 条例 added.
  final int candidateHits;

  /// Wrong before, right after.
  final int fixed;

  /// Right before, wrong after.
  final int broken;

  final DateTime at;

  const BacktestSummary({
    required this.n,
    required this.baselineHits,
    required this.candidateHits,
    required this.fixed,
    required this.broken,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'n': n,
        'baselineHits': baselineHits,
        'candidateHits': candidateHits,
        'fixed': fixed,
        'broken': broken,
        'at': at.toIso8601String(),
      };

  factory BacktestSummary.fromJson(Map<String, dynamic> j) => BacktestSummary(
        n: j['n'] as int? ?? 0,
        baselineHits: j['baselineHits'] as int? ?? 0,
        candidateHits: j['candidateHits'] as int? ?? 0,
        fixed: j['fixed'] as int? ?? 0,
        broken: j['broken'] as int? ?? 0,
        at: DateTime.tryParse(j['at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// All 条例, and a revision number that moves whenever the active set does.
///
/// The revision is what cached AI text and saved cases are keyed by: an
/// answer given under revision 3 is evidence about revision 3.
class CustomRuleSet {
  final int revision;
  final List<CustomRule> rules;

  const CustomRuleSet({this.revision = 0, this.rules = const []});

  static const empty = CustomRuleSet();

  List<CustomRule> get active => [for (final r in rules) if (r.active) r];

  List<String> get promptLines => [for (final r in active) r.promptLine];

  /// The active set with [candidate] added — what a backtest compares
  /// against the set as it stands. Not persisted.
  CustomRuleSet withCandidate(CustomRule candidate) => CustomRuleSet(
        revision: revision,
        rules: [...rules, candidate.copyWith(active: true)],
      );

  /// Adopting takes a backtest result by construction: there is no path to
  /// an active 条例 that skips the measurement.
  CustomRuleSet adopt(CustomRule rule, BacktestSummary result) =>
      CustomRuleSet(
        revision: revision + 1,
        rules: [
          for (final r in rules)
            if (r.id != rule.id) r,
          rule.copyWith(active: true, backtest: result),
        ],
      );

  CustomRuleSet setActive(String id, bool active) => CustomRuleSet(
        revision: revision + 1,
        rules: [
          for (final r in rules)
            r.id == id ? r.copyWith(active: active) : r,
        ],
      );

  Map<String, dynamic> toJson() => {
        'revision': revision,
        'rules': [for (final r in rules) r.toJson()],
      };

  factory CustomRuleSet.fromJson(Map<String, dynamic> j) => CustomRuleSet(
        revision: j['revision'] as int? ?? 0,
        rules: [
          for (final r in (j['rules'] as List? ?? const []))
            CustomRule.fromJson(r as Map<String, dynamic>),
        ],
      );
}

/// Persists the 条例 set on the device.
class CustomRuleStore {
  static const _key = 'custom_rules_v1';

  Future<CustomRuleSet> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return CustomRuleSet.empty;
    try {
      return CustomRuleSet.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return CustomRuleSet.empty;
    }
  }

  Future<void> save(CustomRuleSet set) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(set.toJson()));
  }
}
