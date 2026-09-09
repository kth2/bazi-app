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

Widget wrap({ChartResult? chart}) => ProviderScope(
  overrides: [
    birthInputProvider.overrideWith((ref) => _input),
    chartResultProvider.overrideWithValue(chart ?? _chart),
  ],
  child: const MaterialApp(home: TimelinePage()),
);

/// The axis canvas itself — `find.byType(CustomPaint)` would also match the
/// ink and decoration painters Material puts above it.
final _axisFinder = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is TimelinePainter,
);

void main() {
  group('event markers', () {
    testWidgets('the axis carries suggested markers', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final painter = tester
          .widget<CustomPaint>(_axisFinder)
          .painter as TimelinePainter;
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
      final painter = tester
          .widget<CustomPaint>(_axisFinder)
          .painter as TimelinePainter;
      final target = painter.events.first;
      final (left, right) = TimelinePainter.boundsFor(painter.geometry, target);
      final lane = painter.lanes[target.id];
      await tester.tapAt(Offset(
        box.left + (left + right) / 2,
        box.top +
            painter.rows.laneTop(lane) +
            TimelineRows.laneHeight / 2,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining(target.label), findsWidgets);
      expect(find.text('推理链'), findsOneWidget);
      expect(find.textContaining('把握度'), findsOneWidget);
      // The card must not present a rule inference as an established fact.
      expect(find.textContaining('非既定事实'), findsOneWidget);
    });

    testWidgets('tapping empty axis space falls back to the year panel',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final box = tester.getRect(_axisFinder);
      final painter = tester
          .widget<CustomPaint>(_axisFinder)
          .painter as TimelinePainter;
      // The 大运 band row holds no markers.
      await tester.tapAt(Offset(
        box.left + painter.geometry.xForAge(60.5),
        box.top + TimelineRows.decadeTop + 10,
      ));
      await tester.pumpAndSettle();

      expect(find.text('推理链'), findsNothing);
      expect(find.textContaining('60岁'), findsWidgets);
    });

    testWidgets('sensitive categories are hidden and said to be hidden',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final painter = tester
          .widget<CustomPaint>(_axisFinder)
          .painter as TimelinePainter;
      for (final e in painter.events) {
        expect(e.kind!.isGuarded, isFalse);
      }
      expect(find.textContaining('默认不显示'), findsOneWidget);
    });

    testWidgets('an empty scan still renders the axis', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          birthInputProvider.overrideWith((ref) => _input),
          chartResultProvider.overrideWithValue(_chart),
          suggestedEventsProvider.overrideWithValue(const []),
        ],
        child: const MaterialApp(home: TimelinePage()),
      ));
      await tester.pumpAndSettle();

      final painter = tester
          .widget<CustomPaint>(_axisFinder)
          .painter as TimelinePainter;
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
