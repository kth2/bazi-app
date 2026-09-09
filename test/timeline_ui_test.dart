import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/models/birth_input.dart';
import 'package:bazi_app/core/models/chart_result.dart';
import 'package:bazi_app/core/timeline/life_span.dart';
import 'package:bazi_app/features/timeline/timeline_geometry.dart';
import 'package:bazi_app/features/timeline/timeline_page.dart';
import 'package:bazi_app/features/timeline/event_lanes.dart';
import 'package:bazi_app/features/timeline/timeline_painter.dart';
import 'package:bazi_app/core/timeline/event_catalog.dart';
import 'package:bazi_app/core/timeline/timeline_event.dart';
import 'package:bazi_app/core/timeline/timeline_settings.dart';
import 'package:bazi_app/core/timeline/timeline_store.dart';
import 'package:bazi_app/providers/timeline_provider.dart';
import 'package:bazi_app/providers/birth_input_provider.dart';
import 'package:bazi_app/providers/chart_provider.dart';

const _input = BirthInput(
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

final _chart = ChartService.compute(_input);

/// Widget tests inject an in-memory store: drift's connection does async work
/// that never completes inside testWidgets' fake-async zone, so a real
/// database deadlocks the pump. Storage itself is covered against a real
/// database in timeline_store_test.dart.
Widget wrap({ChartResult? chart, TimelineStore? store}) => ProviderScope(
  overrides: [
    birthInputProvider.overrideWith((ref) => _input),
    chartResultProvider.overrideWithValue(chart ?? _chart),
    timelineStoreProvider.overrideWithValue(store ?? InMemoryTimelineStore()),
    timelineSettingsProvider.overrideWith(
      (ref) => TimelineSettingsNotifier(const TimelineSettings()),
    ),
  ],
  child: const MaterialApp(home: TimelinePage()),
);

/// The axis canvas itself — `find.byType(CustomPaint)` would also match the
/// ink and decoration painters Material puts above it.
final _axisFinder = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is TimelinePainter,
);

void main() {
  _editingTests();

  group('event markers', () {
    testWidgets('the axis carries suggested markers', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final painter =
          tester.widget<CustomPaint>(_axisFinder).painter as TimelinePainter;
      expect(painter.events, isNotEmpty);
      expect(painter.rows.laneCount, greaterThan(0));
      // Every marker must have a lane, or it is drawn where nothing can be
      // tapped.
      for (final e in painter.events) {
        expect(painter.lanes.laneOf, contains(e.id));
      }
    });

    testWidgets('tapping a marker shows its reasoning chain', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final box = tester.getRect(_axisFinder);
      final painter =
          tester.widget<CustomPaint>(_axisFinder).painter as TimelinePainter;
      final target = painter.events.first;
      final (left, right) = TimelinePainter.boundsFor(painter.geometry, target);
      final lane = painter.lanes[target.id];
      await tester.tapAt(
        Offset(
          box.left + (left + right) / 2,
          box.top + painter.rows.laneTop(lane) + TimelineRows.laneHeight / 2,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining(target.label), findsWidgets);
      expect(find.text('推理链'), findsOneWidget);
      expect(find.textContaining('把握度'), findsOneWidget);
      // The card must not present a rule inference as an established fact.
      expect(find.textContaining('非既定事实'), findsOneWidget);
    });

    testWidgets('tapping empty axis space falls back to the year panel', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final box = tester.getRect(_axisFinder);
      final painter =
          tester.widget<CustomPaint>(_axisFinder).painter as TimelinePainter;
      // The 大运 band row holds no markers.
      await tester.tapAt(
        Offset(
          box.left + painter.geometry.xForAge(60.5),
          box.top + TimelineRows.decadeTop + 10,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('推理链'), findsNothing);
      expect(find.textContaining('60岁'), findsWidgets);
    });

    testWidgets('sensitive markers are drawn, with the caveat beside them', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final painter =
          tester.widget<CustomPaint>(_axisFinder).painter as TimelinePainter;
      expect(
        painter.events.any((e) => e.kind!.isSensitive),
        isTrue,
        reason: 'the sample chart produces sensitive markers; they must be on '
            'the axis without the reader having to ask for them',
      );
      // Shown by default means the caveat is shown by default too — it can no
      // longer live behind the switch that used to gate the markers.
      expect(find.textContaining('不构成医疗、法律或财务建议'), findsOneWidget);
      expect(find.textContaining('信或不信由你判断'), findsOneWidget);
    });

    testWidgets('tapping a sensitive marker shows its own disclaimer', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final painter =
          tester.widget<CustomPaint>(_axisFinder).painter as TimelinePainter;
      final target = painter.events.firstWhere((e) => e.kind!.isSensitive);
      final box = tester.getRect(_axisFinder);
      final (left, right) = TimelinePainter.boundsFor(painter.geometry, target);
      await tester.tapAt(
        Offset(
          box.left + (left + right) / 2,
          box.top +
              painter.rows.laneTop(painter.lanes[target.id]) +
              TimelineRows.laneHeight / 2,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining(target.kind!.disclaimer!), findsWidgets);
    });

    testWidgets('an empty scan still renders the axis', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            birthInputProvider.overrideWith((ref) => _input),
            chartResultProvider.overrideWithValue(_chart),
            suggestedEventsProvider.overrideWithValue(const []),
          ],
          child: const MaterialApp(home: TimelinePage()),
        ),
      );
      await tester.pumpAndSettle();

      final painter =
          tester.widget<CustomPaint>(_axisFinder).painter as TimelinePainter;
      expect(painter.rows.laneCount, 0);
      expect(painter.lanes.laneCount, EventLanes.empty.laneCount);
      expect(find.textContaining('0-120岁'), findsOneWidget);
    });
  });

  testWidgets('renders the whole span and says so', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('人生时间线'), findsOneWidget);
    // The default view is the entire two 甲子, not a window into it.
    expect(find.textContaining('0-120岁'), findsOneWidget);
  });

  testWidgets('nothing is selected until the axis is tapped', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.textContaining('点击时间线'), findsOneWidget);
  });

  testWidgets('tapping the axis reports that age\'s 大运 and 流年', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final box = tester.getRect(_axisFinder);
    // Work out where age 60 is rather than guessing a pixel: the assertion is
    // about the axis agreeing with LifeSpan, not about a magic coordinate.
    final geo = TimelineGeometry.wholeLife(
      viewportWidth: box.width,
      maxAge: LifeSpan.kMaxAge,
    );
    final span = LifeSpan.of(_chart);
    await tester.tapAt(Offset(box.left + geo.xForAge(60.5), box.top + 30));
    await tester.pumpAndSettle();

    expect(find.textContaining('60岁'), findsWidgets);
    final decade = span.decadeAt(60.5)!;
    expect(find.textContaining(decade.ganZhi), findsWidgets);
    final year = span.yearAt(60.5)!;
    expect(find.textContaining('${year.year}年'), findsWidgets);
  });

  testWidgets('the 小运期 is labelled, not left blank', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final span = LifeSpan.of(_chart);
    expect(
      span.firstDecadeAge,
      greaterThan(1),
      reason: 'sample chart must have a 小运期 for this test to mean anything',
    );

    final box = tester.getRect(_axisFinder);
    final geo = TimelineGeometry.wholeLife(
      viewportWidth: box.width,
      maxAge: LifeSpan.kMaxAge,
    );
    await tester.tapAt(Offset(box.left + geo.xForAge(1.5), box.top + 30));
    await tester.pumpAndSettle();

    // The legend also mentions 小运期; the detail line is the one that must
    // name the 起运 point.
    expect(find.textContaining('小运期（'), findsOneWidget);
  });

  testWidgets('zoom buttons narrow the visible range', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('放大'));
    await tester.pumpAndSettle();
    expect(find.textContaining('0-120岁'), findsNothing);

    await tester.tap(find.byTooltip('全览 0-120 岁'));
    await tester.pumpAndSettle();
    expect(find.textContaining('0-120岁'), findsOneWidget);
  });

  testWidgets('shows a placeholder instead of crashing with no chart', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chartResultProvider.overrideWithValue(null)],
        child: const MaterialApp(home: TimelinePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('尚未排盘'), findsOneWidget);
  });
}

/// P4: the marker a user places or edits, and what happens to it.
void _editingTests() {
  TimelinePainter painterOf(WidgetTester tester) =>
      tester.widget<CustomPaint>(_axisFinder).painter as TimelinePainter;

  Future<void> tapMarker(WidgetTester tester, LifeEvent target) async {
    final box = tester.getRect(_axisFinder);
    final p = painterOf(tester);
    final (left, right) = TimelinePainter.boundsFor(p.geometry, target);
    await tester.tapAt(
      Offset(
        box.left + (left + right) / 2,
        box.top +
            p.rows.laneTop(p.lanes[target.id]) +
            TimelineRows.laneHeight / 2,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('editing markers', () {
    testWidgets('a suggested marker can be deleted and stays deleted', (
      tester,
    ) async {
      final store = InMemoryTimelineStore();
      await tester.pumpWidget(wrap(store: store));
      await tester.pumpAndSettle();

      final target = painterOf(tester).events.first;
      await tapMarker(tester, target);
      expect(find.text('推理链'), findsOneWidget);

      await tester.tap(find.byTooltip('删除'));
      await tester.pumpAndSettle();

      // A tombstone, not a row deletion: the scanner is deterministic, so
      // without one the marker returns on the next rescan.
      final stored = await store.load(chartKeyOf(_chart));
      expect(stored.single.event.id, target.id);
      expect(stored.single.hidden, isTrue);
      expect(mergeTimeline([target], stored), isEmpty);
    });

    testWidgets('a marker can be added by hand and is marked as the user\'s', (
      tester,
    ) async {
      final store = InMemoryTimelineStore();
      await tester.pumpWidget(wrap(store: store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('添加事件'));
      await tester.pumpAndSettle();
      expect(find.text('添加事件'), findsWidgets);

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final stored = await store.load(chartKeyOf(_chart));
      expect(stored, hasLength(1));
      expect(stored.single.event.origin, EventOrigin.userAdded);
      expect(stored.single.hidden, isFalse);
    });

    testWidgets('editing a suggested marker makes it the user\'s', (
      tester,
    ) async {
      final store = InMemoryTimelineStore();
      await tester.pumpWidget(wrap(store: store));
      await tester.pumpAndSettle();

      final target = painterOf(tester).events.first;
      await tapMarker(tester, target);
      await tester.tap(find.byTooltip('编辑'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('开始加一年'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final stored = (await store.load(chartKeyOf(_chart))).single;
      expect(stored.event.id, target.id, reason: 'the edit must stay attached');
      expect(stored.event.origin, EventOrigin.userMoved);
      expect(stored.event.anchor.startAge, target.anchor.startAge + 1);
      // The engine's chain survives the edit.
      expect(stored.event.basis, isNotEmpty);
    });

    testWidgets('a user-placed marker is drawn even with no suggestions', (
      tester,
    ) async {
      final store = InMemoryTimelineStore();
      final mine = LifeEvent(
        id: 'user:1',
        kindId: 'marriage.union',
        anchor: const TimelineAnchor.at(28),
        intensity: EventIntensity.high,
        origin: EventOrigin.userAdded,
        note: '结婚',
        createdAt: DateTime(2026),
      );
      await store.put(chartKeyOf(_chart), StoredEvent(mine));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            birthInputProvider.overrideWith((ref) => _input),
            chartResultProvider.overrideWithValue(_chart),
            timelineStoreProvider.overrideWithValue(store),
            suggestedEventsProvider.overrideWithValue(const []),
          ],
          child: const MaterialApp(home: TimelinePage()),
        ),
      );
      await tester.pumpAndSettle();

      final events = painterOf(tester).events;
      expect(events.map((e) => e.id), ['user:1']);
    });
  });

  group('sensitive categories', () {
    testWidgets('the settings sheet offers to switch them off, not on', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('敏感类别设置'));
      await tester.pumpAndSettle();

      expect(find.text('敏感类别'), findsOneWidget);
      for (final k in EventCatalog.sensitive) {
        expect(find.textContaining(k.label), findsWidgets);
      }
      // Every switch starts on: the four categories ship visible.
      for (final sw in tester.widgetList<Switch>(find.byType(Switch))) {
        expect(sw.value, isTrue);
      }
      expect(find.textContaining('不构成医疗、法律或财务建议'), findsWidgets);
      expect(find.textContaining('不是生命终点'), findsWidgets);
    });

    testWidgets('switching one off hides it with no confirmation dialog', (
      tester,
    ) async {
      // Turning a reading *off* is nobody's business but the reader's; the
      // acknowledgement gate belonged to the old opt-in flow and is gone.
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('敏感类别设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
    });
  });
}
