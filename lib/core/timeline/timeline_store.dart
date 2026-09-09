import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../analysis/event_inference.dart';
import '../models/chart_result.dart';
import 'timeline_event.dart';

part 'timeline_store.g.dart';

/// Events the user placed, moved, or dismissed, keyed to one 命盘.
class TimelineEventRows extends Table {
  TextColumn get id => text()();

  /// 八字 + 性别. Events belong to a chart, not to a saved case: the same
  /// person re-entering the same birth data must find their timeline intact.
  TextColumn get chartKey => text()();

  TextColumn get kindId => text()();
  RealColumn get startAge => real()();
  RealColumn get endAge => real()();
  TextColumn get intensity => text()();
  TextColumn get origin => text()();

  /// True for a suggested event the user deleted. Kept as a tombstone: the
  /// scanner is deterministic, so without one the marker returns on the next
  /// rescan and the delete looks broken.
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

  RealColumn get confidence => real().nullable()();
  TextColumn get polarity => text().nullable()();
  TextColumn get basisJson => text().withDefault(const Constant('[]'))();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Storage for timeline events.
///
/// A third database, separate from both the rules cache and the case journal.
/// Not fastidiousness: `core/timeline` is forbidden from importing
/// `core/cases` (see `test/case_guardrail_test.dart`), so sharing the case
/// journal's schema would break the one-way dependency that keeps recorded
/// outcomes out of the reasoning path.
@DriftDatabase(tables: [TimelineEventRows])
class TimelineDatabase extends _$TimelineDatabase {
  TimelineDatabase() : super(_openConnection());

  TimelineDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  /// Additive only — these rows are things a person placed by hand and
  /// cannot be regenerated.
  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'bazi_timeline',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}

/// Identity of the 命盘 an event belongs to.
String chartKeyOf(ChartResult chart) =>
    '${chart.baziString}|${chart.input.gender.name}';

/// One stored override: an event plus whether it is a tombstone.
class StoredEvent {
  final LifeEvent event;
  final bool hidden;
  const StoredEvent(this.event, {this.hidden = false});
}

/// What the timeline UI needs from storage.
///
/// An interface rather than the concrete repository, for the same reason the
/// case journal has one: drift's asynchronous open never completes inside
/// `testWidgets`' fake-async zone, so widget tests inject an in-memory store.
abstract class TimelineStore {
  Stream<List<StoredEvent>> watch(String chartKey);
  Future<List<StoredEvent>> load(String chartKey);
  Future<void> put(String chartKey, StoredEvent stored);
  Future<void> remove(String id);
  Future<void> clearChart(String chartKey);
}

class TimelineRepository implements TimelineStore {
  final TimelineDatabase db;

  TimelineRepository(this.db);

  static StoredEvent _toStored(TimelineEventRow r) => StoredEvent(
    LifeEvent(
      id: r.id,
      kindId: r.kindId,
      anchor: TimelineAnchor(r.startAge, r.endAge),
      intensity: EventIntensity.values.byName(r.intensity),
      origin: EventOrigin.values.byName(r.origin),
      confidence: r.confidence,
      polarity: r.polarity == null
          ? null
          : EventPolarity.values.byName(r.polarity!),
      basis: [for (final b in jsonDecode(r.basisJson) as List) b as String],
      note: r.note,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    ),
    hidden: r.hidden,
  );

  static TimelineEventRowsCompanion _toRow(String chartKey, StoredEvent s) {
    final e = s.event;
    return TimelineEventRowsCompanion.insert(
      id: e.id,
      chartKey: chartKey,
      kindId: e.kindId,
      startAge: e.anchor.startAge,
      endAge: e.anchor.endAge,
      intensity: e.intensity.name,
      origin: e.origin.name,
      hidden: Value(s.hidden),
      confidence: Value(e.confidence),
      polarity: Value(e.polarity?.name),
      basisJson: Value(jsonEncode(e.basis)),
      note: Value(e.note),
      createdAt: e.createdAt,
      updatedAt: Value(e.updatedAt),
    );
  }

  @override
  Stream<List<StoredEvent>> watch(String chartKey) =>
      (db.select(db.timelineEventRows)
            ..where((t) => t.chartKey.equals(chartKey))
            ..orderBy([(t) => OrderingTerm(expression: t.startAge)]))
          .watch()
          .map((rows) => rows.map(_toStored).toList());

  @override
  Future<List<StoredEvent>> load(String chartKey) async {
    final rows =
        await (db.select(db.timelineEventRows)
              ..where((t) => t.chartKey.equals(chartKey))
              ..orderBy([(t) => OrderingTerm(expression: t.startAge)]))
            .get();
    return rows.map(_toStored).toList();
  }

  @override
  Future<void> put(String chartKey, StoredEvent stored) => db
      .into(db.timelineEventRows)
      .insertOnConflictUpdate(_toRow(chartKey, stored));

  @override
  Future<void> remove(String id) =>
      (db.delete(db.timelineEventRows)..where((t) => t.id.equals(id))).go();

  @override
  Future<void> clearChart(String chartKey) => (db.delete(
    db.timelineEventRows,
  )..where((t) => t.chartKey.equals(chartKey))).go();
}

/// An in-memory store, for widget tests and for the first frame before the
/// database has opened.
class InMemoryTimelineStore implements TimelineStore {
  final Map<String, Map<String, StoredEvent>> _byChart = {};

  @override
  Future<List<StoredEvent>> load(String chartKey) async =>
      (_byChart[chartKey]?.values.toList() ?? [])..sort(
        (a, b) => a.event.anchor.startAge.compareTo(b.event.anchor.startAge),
      );

  @override
  Stream<List<StoredEvent>> watch(String chartKey) async* {
    yield await load(chartKey);
  }

  @override
  Future<void> put(String chartKey, StoredEvent stored) async {
    _byChart.putIfAbsent(chartKey, () => {})[stored.event.id] = stored;
  }

  @override
  Future<void> remove(String id) async {
    for (final m in _byChart.values) {
      m.remove(id);
    }
  }

  @override
  Future<void> clearChart(String chartKey) async => _byChart.remove(chartKey);
}

/// Combine the scanner's suggestions with what the user has done to them.
///
/// The rules, in order:
/// - a stored row whose id matches a suggestion **replaces** it (the user
///   moved or re-rated it);
/// - a stored row marked hidden **removes** it;
/// - stored rows with no matching suggestion are the user's own additions;
/// - everything else is shown as suggested.
///
/// This is the whole reason ids are derived from (kind, ages) rather than
/// generated: a rescan of an unchanged chart reproduces the same ids, so the
/// user's edits keep landing on the events they were made against.
List<LifeEvent> mergeTimeline(
  List<LifeEvent> suggested,
  List<StoredEvent> stored,
) {
  final overrides = {for (final s in stored) s.event.id: s};
  final out = <LifeEvent>[];

  for (final s in suggested) {
    final override = overrides.remove(s.id);
    if (override == null) {
      out.add(s);
    } else if (!override.hidden) {
      // Keep the engine's chain even when the user has moved the marker:
      // the reasoning is why it was offered, and stays worth reading.
      out.add(
        override.event.basis.isEmpty && s.basis.isNotEmpty
            ? override.event.withBasis(s.basis, s.polarity, s.confidence)
            : override.event,
      );
    }
  }

  for (final leftover in overrides.values) {
    // A tombstone for a suggestion that no longer exists is simply stale.
    if (leftover.hidden) continue;
    out.add(leftover.event);
  }

  out.sort((a, b) {
    final byAge = a.anchor.startAge.compareTo(b.anchor.startAge);
    if (byAge != 0) return byAge;
    return a.id.compareTo(b.id);
  });
  return out;
}
