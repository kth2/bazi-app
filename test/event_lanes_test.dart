import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/timeline/timeline_event.dart';
import 'package:bazi_app/features/timeline/event_lanes.dart';

LifeEvent ev(String id, double start, [double? end]) => LifeEvent(
      id: id,
      kindId: 'career.promotion',
      anchor: TimelineAnchor(start, end ?? start),
      intensity: EventIntensity.medium,
      origin: EventOrigin.suggested,
      createdAt: DateTime(2026),
    );

void main() {
  test('an empty list needs no lanes', () {
    expect(EventLanes.pack([]).laneCount, 0);
  });

  test('well-separated events all share lane 0', () {
    final lanes = EventLanes.pack([ev('a', 10), ev('b', 40), ev('c', 80)]);
    expect(lanes.laneCount, 1);
    expect([lanes['a'], lanes['b'], lanes['c']], [0, 0, 0]);
  });

  test('events closer than the gap are stacked', () {
    final lanes = EventLanes.pack([ev('a', 30), ev('b', 31), ev('c', 32)]);
    expect(lanes.laneCount, 3);
    expect({lanes['a'], lanes['b'], lanes['c']}, {0, 1, 2});
  });

  test('a lane is reused once its occupant is far enough behind', () {
    final lanes = EventLanes.pack([ev('a', 30), ev('b', 31), ev('c', 60)]);
    expect(lanes['c'], 0);
    expect(lanes.laneCount, 2);
  });

  test('a span holds its lane for its whole length', () {
    final lanes = EventLanes.pack([ev('long', 30, 50), ev('mid', 40)]);
    expect(lanes['mid'], isNot(0));
  });

  test('packing is independent of input order', () {
    final forward = EventLanes.pack([ev('a', 30), ev('b', 31), ev('c', 60)]);
    final reversed = EventLanes.pack([ev('c', 60), ev('b', 31), ev('a', 30)]);
    expect(reversed.laneOf, forward.laneOf);
  });

  test('never exceeds the lane cap, and drops no event', () {
    // Ten markers on the same year cannot each get a lane; they must still
    // all be placed, because a dropped marker is invisible and untappable.
    final crowd = [for (var i = 0; i < 10; i++) ev('e$i', 40)];
    final lanes = EventLanes.pack(crowd);
    expect(lanes.laneCount, EventLanes.kMaxLanes);
    expect(lanes.laneOf.length, 10);
    for (final e in crowd) {
      expect(lanes[e.id], lessThan(EventLanes.kMaxLanes));
    }
  });
}
