import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/birth_input.dart';
import 'case_record.dart';

part 'cases_db.g.dart';

/// Saved readings awaiting (or carrying) their real-world outcome.
class CaseRows extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get baziString => text()();
  TextColumn get inputJson => text()();
  TextColumn get scopeLabel => text()();
  IntColumn get engineVersion => integer()();
  TextColumn get structureSummary => text()();
  TextColumn get claimsJson => text()();
  TextColumn get aiText => text().withDefault(const Constant(''))();
  TextColumn get outcomeNote => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get reviewDueAt => dateTime().nullable()();
  DateTimeColumn get lastReviewedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Storage for the case journal.
///
/// Deliberately a *separate* database from [RulesDatabase]. The rules table is
/// a disposable cache of a bundled asset, and its migration drops and reseeds;
/// cases are user data that must never be dropped, so the two cannot share a
/// schema version or a migration path.
@DriftDatabase(tables: [CaseRows])
class CasesDatabase extends _$CasesDatabase {
  CasesDatabase() : super(_openConnection());

  CasesDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  /// Additive only. A future column must be added with `m.addColumn`; this
  /// table holds records a person entered by hand and cannot be regenerated.
  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'bazi_cases',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}

/// The case-journal operations the UI depends on.
///
/// An interface rather than the concrete repository so pages depend on the
/// behaviour, not on drift: a widget test can supply an in-memory store,
/// which a real database cannot be under testWidgets' fake-async zone.
abstract class CaseStore {
  Future<List<CaseRecord>> all();
  Stream<List<CaseRecord>> watchAll();
  Future<CaseRecord?> byId(String id);
  Future<void> save(CaseRecord record);
  Future<void> delete(String id);
  Future<CaseRecord?> findExisting({
    required String baziString,
    required Gender gender,
    required String scopeLabel,
  });
  Future<List<CaseRecord>> due([DateTime? now]);
  Future<String> exportJson();
}

/// Read/write access to the case journal, backed by SQLite.
class CaseRepository implements CaseStore {
  final CasesDatabase db;

  CaseRepository(this.db);

  static CaseRecord _toRecord(CaseRow r) => CaseRecord(
        id: r.id,
        title: r.title,
        input: BirthInput.fromJson(
            (jsonDecodeMap(r.inputJson)) as Map<String, dynamic>),
        baziString: r.baziString,
        scopeLabel: r.scopeLabel,
        engineVersion: r.engineVersion,
        structureSummary: r.structureSummary,
        claims: CaseRecord.decodeClaims(r.claimsJson),
        aiText: r.aiText,
        outcomeNote: r.outcomeNote,
        createdAt: r.createdAt,
        reviewDueAt: r.reviewDueAt,
        lastReviewedAt: r.lastReviewedAt,
      );

  static CaseRowsCompanion _toRow(CaseRecord c) => CaseRowsCompanion.insert(
        id: c.id,
        title: c.title,
        baziString: c.baziString,
        inputJson: jsonEncodeMap(c.input.toJson()),
        scopeLabel: c.scopeLabel,
        engineVersion: c.engineVersion,
        structureSummary: c.structureSummary,
        claimsJson: CaseRecord.encodeClaims(c.claims),
        aiText: Value(c.aiText),
        outcomeNote: Value(c.outcomeNote),
        createdAt: c.createdAt,
        reviewDueAt: Value(c.reviewDueAt),
        lastReviewedAt: Value(c.lastReviewedAt),
      );

  /// Newest first.
  @override
  Future<List<CaseRecord>> all() async {
    final rows = await (db.select(db.caseRows)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return [for (final r in rows) _toRecord(r)];
  }

  /// Live view of the journal, so the list updates as cases are saved.
  @override
  Stream<List<CaseRecord>> watchAll() => (db.select(db.caseRows)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch()
      .map((rows) => [for (final r in rows) _toRecord(r)]);

  @override
  Future<CaseRecord?> byId(String id) async {
    final row = await (db.select(db.caseRows)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toRecord(row);
  }

  /// Insert or update.
  @override
  Future<void> save(CaseRecord record) =>
      db.into(db.caseRows).insertOnConflictUpdate(_toRow(record));

  @override
  Future<void> delete(String id) =>
      (db.delete(db.caseRows)..where((t) => t.id.equals(id))).go();

  /// An existing case for the same chart, gender and scope, if there is one.
  ///
  /// Saving the same reading twice would either duplicate the entry or
  /// overwrite feedback the user already filled in, so callers look first and
  /// offer to open the existing case instead.
  @override
  Future<CaseRecord?> findExisting({
    required String baziString,
    required Gender gender,
    required String scopeLabel,
  }) async {
    for (final c in await all()) {
      if (c.baziString == baziString &&
          c.input.gender == gender &&
          c.scopeLabel == scopeLabel) {
        return c;
      }
    }
    return null;
  }

  /// Cases whose period has elapsed and which still need filling in.
  @override
  Future<List<CaseRecord>> due([DateTime? now]) async {
    final at = now ?? DateTime.now();
    return [
      for (final c in await all())
        if (c.status(at) == CaseStatus.awaitingReview ||
            c.status(at) == CaseStatus.partiallyReviewed)
          c,
    ];
  }

  /// Whole journal as JSON, for backup or offline study.
  ///
  /// Export exists so accumulated cases can be reviewed by a person — the
  /// engine never reads them back.
  @override
  Future<String> exportJson() async =>
      CaseRecord.encodeExport(await all());
}

Object jsonDecodeMap(String raw) => jsonDecode(raw);

String jsonEncodeMap(Map<String, dynamic> map) => jsonEncode(map);

