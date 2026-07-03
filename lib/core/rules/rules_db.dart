import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'rule.dart';

part 'rules_db.g.dart';

/// Stored interpretation rules.
class RuleRows extends Table {
  TextColumn get id => text()();
  TextColumn get category => text()();
  TextColumn get title => text()();
  RealColumn get weight => real()();
  RealColumn get minMatchRatio => real()();
  TextColumn get conditionsJson => text()();
  TextColumn get interpretation => text()();
  TextColumn get source => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Simple key-value store (tracks the seeded rules version).
class MetaRows extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [RuleRows, MetaRows])
class RulesDatabase extends _$RulesDatabase {
  RulesDatabase() : super(_openConnection());

  RulesDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'bazi_rules',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }

  /// Loads all rules, seeding/reseeding from the bundled asset when the
  /// stored seed version differs from the asset's version.
  Future<List<Rule>> loadRules() async {
    final assetRaw = await rootBundle.loadString('assets/rules/seed_rules.json');
    final assetJson = jsonDecode(assetRaw) as Map<String, dynamic>;
    final assetVersion = '${assetJson['version']}';

    final storedVersion = await (select(metaRows)
          ..where((m) => m.key.equals('seedVersion')))
        .getSingleOrNull();

    if (storedVersion?.value != assetVersion) {
      await _reseed(assetJson, assetVersion);
    }

    final rows = await select(ruleRows).get();
    return [
      for (final r in rows)
        Rule(
          id: r.id,
          category: r.category,
          title: r.title,
          weight: r.weight,
          minMatchRatio: r.minMatchRatio,
          conditions: [
            for (final c in jsonDecode(r.conditionsJson) as List)
              RuleCondition.fromJson(c as Map<String, dynamic>),
          ],
          interpretation: r.interpretation,
          source: r.source,
        ),
    ];
  }

  Future<void> _reseed(Map<String, dynamic> assetJson, String version) async {
    final rules = [
      for (final r in assetJson['rules'] as List)
        Rule.fromJson(r as Map<String, dynamic>),
    ];
    await transaction(() async {
      await delete(ruleRows).go();
      await batch((b) {
        b.insertAll(ruleRows, [
          for (final rule in rules)
            RuleRowsCompanion.insert(
              id: rule.id,
              category: rule.category,
              title: rule.title,
              weight: rule.weight,
              minMatchRatio: rule.minMatchRatio,
              conditionsJson:
                  jsonEncode(rule.conditions.map((c) => c.toJson()).toList()),
              interpretation: rule.interpretation,
              source: rule.source,
            ),
        ]);
      });
      await into(metaRows).insertOnConflictUpdate(
        MetaRowsCompanion.insert(key: 'seedVersion', value: version),
      );
    });
  }
}
