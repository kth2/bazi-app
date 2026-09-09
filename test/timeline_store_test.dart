import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/analysis/event_inference.dart';
import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/models/birth_input.dart';
import 'package:bazi_app/core/timeline/timeline_event.dart';
import 'package:bazi_app/core/timeline/timeline_scanner.dart';
import 'package:bazi_app/core/timeline/timeline_store.dart';

LifeEvent suggested(String kindId, double start, [double? end]) {
  final anchor = TimelineAnchor(start, end ?? start);
  return LifeEvent(
    id: TimelineScanner.suggestedIdFor(kindId, anchor),
    kindId: kindId,
    anchor: anchor,
    intensity: EventIntensity.high,
    origin: EventOrigin.suggested,
    confidence: 0.7,
    polarity: EventPolarity.favourable,
    basis: const ['原局：正官格·成格', '流年：官星得地'],
    createdAt: DateTime(2026),
  );
}

LifeEvent userEvent(String id, String kindId, double age) => LifeEvent(
  id: id,
  kindId: kindId,
  anchor: TimelineAnchor.at(age),
  intensity: EventIntensity.medium,
  origin: EventOrigin.userAdded,
  note: '结婚',
  createdAt: DateTime(2026),
);

void main() {
  group('merging suggestions with what the user did to them', () {
    test('an untouched suggestion is shown as-is', () {
      final s = suggested('career.promotion', 30);
      expect(mergeTimeline([s], []).single.id, s.id);
    });

    test('a stored override replaces the suggestion it matches', () {
      final s = suggested('career.promotion', 30);
      final moved = s.copyWith(
        anchor: TimelineAnchor.at(34),
        origin: EventOrigin.userMoved,
      );
      final merged = mergeTimeline([s], [StoredEvent(moved)]);
      expect(merged, hasLength(1));
      expect(merged.single.anchor.startAge, 34);
      expect(merged.single.origin, EventOrigin.userMoved);
    });

    test('a moved marker keeps the chain that produced it', () {
      // The reasoning is why the marker was offered in the first place, and
      // stays worth reading after the user nudges the year.
      final s = suggested('career.promotion', 30);
      final stripped = LifeEvent(
        id: s.id,
        kindId: s.kindId,
        anchor: TimelineAnchor.at(34),
        intensity: s.intensity,
        origin: EventOrigin.userMoved,
        createdAt: s.createdAt,
      );
      final merged = mergeTimeline([s], [StoredEvent(stripped)]);
      expect(merged.single.basis, s.basis);
      expect(merged.single.polarity, s.polarity);
    });

    test('a tombstone removes the suggestion for good', () {
      final s = suggested('career.promotion', 30);
      expect(mergeTimeline([s], [StoredEvent(s, hidden: true)]), isEmpty);
    });

    test('a stale tombstone for a vanished suggestion is ignored', () {
      final gone = suggested('career.promotion', 30);
      final merged = mergeTimeline([], [StoredEvent(gone, hidden: true)]);
      expect(merged, isEmpty);
    });

    test('user additions survive alongside suggestions, in age order', () {
      final s = suggested('career.promotion', 40);
      final mine = userEvent('user:1', 'marriage.union', 28);
      final merged = mergeTimeline([s], [StoredEvent(mine)]);
      expect(merged.map((e) => e.anchor.startAge), [28, 40]);
    });

    test('a rescan of an unchanged chart keeps edits attached', () {
      // Ids are derived from (kind, ages) rather than generated precisely so
      // this holds: rescanning must not orphan the user's edits.
      final s = suggested('career.promotion', 30);
      final moved = s.copyWith(
        anchor: TimelineAnchor.at(31),
        origin: EventOrigin.userMoved,
      );
      final rescan = suggested('career.promotion', 30);
      final merged = mergeTimeline([rescan], [StoredEvent(moved)]);
      expect(merged.single.anchor.startAge, 31);
    });
  });

  group('the database round-trips an event', () {
    late TimelineDatabase db;
    late TimelineRepository repo;

    setUp(() {
      db = TimelineDatabase.forTesting(NativeDatabase.memory());
      repo = TimelineRepository(db);
    });

    tearDown(() => db.close());

    test('saves and reads back every field', () async {
      final e = suggested('wealth.income', 40, 44);
      await repo.put('chartA', StoredEvent(e));
      final back = (await repo.load('chartA')).single;
      expect(back.event.id, e.id);
      expect(back.event.kindId, e.kindId);
      expect(back.event.anchor.startAge, 40);
      expect(back.event.anchor.endAge, 44);
      expect(back.event.intensity, e.intensity);
      expect(back.event.origin, e.origin);
      expect(back.event.confidence, e.confidence);
      expect(back.event.polarity, e.polarity);
      expect(back.event.basis, e.basis);
      expect(back.hidden, isFalse);
    });

    test('a tombstone round-trips as hidden', () async {
      final e = suggested('career.promotion', 30);
      await repo.put('chartA', StoredEvent(e, hidden: true));
      expect((await repo.load('chartA')).single.hidden, isTrue);
    });

    test('saving twice updates rather than duplicating', () async {
      final e = suggested('career.promotion', 30);
      await repo.put('chartA', StoredEvent(e));
      await repo.put(
        'chartA',
        StoredEvent(e.copyWith(note: 'changed', updatedAt: DateTime(2027))),
      );
      final all = await repo.load('chartA');
      expect(all, hasLength(1));
      expect(all.single.event.note, 'changed');
    });

    test('charts do not see each other\'s events', () async {
      await repo.put(
        'chartA',
        StoredEvent(userEvent('u1', 'marriage.union', 28)),
      );
      await repo.put(
        'chartB',
        StoredEvent(userEvent('u2', 'marriage.union', 30)),
      );
      expect(await repo.load('chartA'), hasLength(1));
      expect((await repo.load('chartB')).single.event.id, 'u2');
    });

    test('deleting removes only the named row', () async {
      await repo.put(
        'chartA',
        StoredEvent(userEvent('u1', 'marriage.union', 28)),
      );
      await repo.put(
        'chartA',
        StoredEvent(userEvent('u2', 'career.venture', 33)),
      );
      await repo.remove('u1');
      expect((await repo.load('chartA')).single.event.id, 'u2');
    });
  });

  group('chart identity', () {
    test('is 八字 plus gender, so the same birth data finds its timeline', () {
      const input = BirthInput(
        calendarType: CalendarType.solar,
        year: 1976,
        month: 5,
        day: 5,
        hour: 6,
        minute: 14,
        gender: Gender.female,
        location: '北京',
        longitude: 116.41,
      );
      final a = ChartService.compute(input);
      final b = ChartService.compute(input);
      expect(chartKeyOf(a), chartKeyOf(b));
      expect(chartKeyOf(a), contains('female'));
    });

    test('differs between the two genders of one 八字', () {
      ChartResultKey of(Gender g) => ChartResultKey(
        chartKeyOf(
          ChartService.compute(
            BirthInput(
              calendarType: CalendarType.solar,
              year: 1976,
              month: 5,
              day: 5,
              hour: 6,
              minute: 14,
              gender: g,
              location: '北京',
              longitude: 116.41,
            ),
          ),
        ),
      );
      // 大运 runs the other way, so the two must not share stored events.
      expect(of(Gender.male).key, isNot(of(Gender.female).key));
    });
  });
}

class ChartResultKey {
  final String key;
  const ChartResultKey(this.key);
}
