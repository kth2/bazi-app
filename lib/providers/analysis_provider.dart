import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/rules/rule.dart';
import '../core/rules/rule_engine.dart';
import '../core/rules/rules_db.dart';
import 'chart_provider.dart';

final rulesDbProvider = Provider<RulesDatabase>((ref) {
  final db = RulesDatabase();
  ref.onDispose(db.close);
  return db;
});

final rulesProvider = FutureProvider<List<Rule>>((ref) {
  return ref.watch(rulesDbProvider).loadRules();
});

/// Rule matches for the current chart, grouped by category
/// (整体命局 / 婚姻 / 事业 / 健康), sorted by score within each group.
final analysisProvider =
    FutureProvider<Map<String, List<RuleMatch>>>((ref) async {
  final chart = ref.watch(chartResultProvider);
  if (chart == null) return const {};
  final rules = await ref.watch(rulesProvider.future);
  final matches = RuleEngine.evaluate(chart, rules);
  return RuleEngine.groupByCategory(matches);
});
