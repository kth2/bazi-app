import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/chart_result.dart';
import '../../core/timeline/life_span.dart';
import '../../providers/chart_provider.dart';
import '../../theme.dart';
import 'timeline_geometry.dart';
import 'timeline_painter.dart';

/// 人生时间线 — the whole 两甲子 (0-120 虚岁) on one zoomable axis.
///
/// Read-only in this phase: 大运 colour bands, 流年 ticks, a "today" marker,
/// and a detail panel for whatever the user taps. Event markers arrive later;
/// the geometry and row layout are already shared with them so the two can
/// never disagree about where an age is.
class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  TimelineGeometry? _geo;

  /// Captured at gesture start: the pinch maths must run against the view as
  /// it was when the fingers went down, not against the last frame, or the
  /// scale factor compounds.
  TimelineGeometry? _gestureStart;
  double _gestureAnchorAge = 0;

  double? _selectedAge;

  void _fit(double width, LifeSpan span) {
    final existing = _geo;
    if (existing == null) {
      _geo = TimelineGeometry.wholeLife(
        viewportWidth: width,
        maxAge: span.maxAge,
      );
    } else if (existing.viewportWidth != width) {
      // A rotation or window resize must not throw away the zoom level.
      _geo = existing.copyWith(viewportWidth: width);
    }
  }

  void _apply(TimelineGeometry next) => setState(() => _geo = next);

  void _zoomAboutCentre(double factor) {
    final g = _geo;
    if (g == null) return;
    _apply(g.zoomBy(factor, g.viewportWidth / 2));
  }

  /// 虚岁 of today: 公历年 - 出生年 + 1, plus the fraction of the year run so
  /// far so the marker creeps rather than jumping every January.
  ///
  /// Display only. The 流年 boundary is 立春, not 1 月 1 日, so this line can
  /// sit a few weeks off around the turn of the year; nothing is computed
  /// from it.
  double? _todayAge(LifeSpan span) {
    final now = DateTime.now();
    final start = DateTime(now.year);
    final end = DateTime(now.year + 1);
    final fraction =
        now.difference(start).inSeconds / end.difference(start).inSeconds;
    final age = span.ageInCalendarYear(now.year) + fraction;
    if (age < 0 || age > span.maxAge) return null;
    return age;
  }

  void _handleTap(Offset local, LifeSpan span) {
    final g = _geo;
    if (g == null) return;
    if (local.dy > TimelineRows.axisTop) return;
    final age = g.ageForX(local.dx);
    if (age < 1 || age > span.maxAge) return;
    setState(() => _selectedAge = age);
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(chartResultProvider);
    if (result == null) {
      return const Scaffold(body: Center(child: Text('尚未排盘')));
    }
    final span = LifeSpan.of(result);
    final todayAge = _todayAge(span);

    return Scaffold(
      appBar: AppBar(
        title: const Text('人生时间线'),
        actions: [
          IconButton(
            tooltip: '回到今天',
            icon: const Icon(Icons.today_outlined),
            onPressed: todayAge == null
                ? null
                : () {
                    final g = _geo;
                    if (g == null) return;
                    _apply(g.copyWith(pxPerYear: 12).centeredOn(todayAge));
                    setState(() => _selectedAge = todayAge);
                  },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildAxisCard(span, todayAge),
          const SizedBox(height: 12),
          _buildDetailCard(result, span),
          const SizedBox(height: 12),
          _buildLegend(span),
        ],
      ),
    );
  }

  Widget _buildAxisCard(LifeSpan span, double? todayAge) {
    // One LayoutBuilder around the card's whole contents. It has to be inside
    // the Card: measured outside, the geometry's viewport would be a card
    // margin wider than the canvas it is drawn into, and every tap would land
    // on the wrong year. It has to cover the readout too, which would
    // otherwise lag the axis by a frame on first paint.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _fit(constraints.maxWidth, span);
          final g = _geo!;
          final selectedDecade = _selectedAge == null
              ? null
              : span.decadeAt(_selectedAge!);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: TimelineRows.height,
                child: Listener(
                  // Desktop and web: wheel scrolls the axis, ⌘/Ctrl+wheel zooms.
                  onPointerSignal: (signal) {
                    if (signal is! PointerScrollEvent) return;
                    final keys = HardwareKeyboard.instance;
                    if (keys.isControlPressed || keys.isMetaPressed) {
                      _apply(
                        g.zoomBy(
                          signal.scrollDelta.dy > 0 ? 0.9 : 1.1,
                          signal.localPosition.dx,
                        ),
                      );
                    } else {
                      final dy = signal.scrollDelta.dy;
                      final dx = signal.scrollDelta.dx;
                      _apply(g.panBy(-(dx.abs() > dy.abs() ? dx : dy)));
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // One recogniser for both drag and pinch: a Scrollable
                    // would claim the horizontal drag (two-finger included)
                    // and the pinch would never reach a scale recogniser.
                    onScaleStart: (d) {
                      _gestureStart = g;
                      _gestureAnchorAge = g.ageForX(d.localFocalPoint.dx);
                    },
                    onScaleUpdate: (d) {
                      final start = _gestureStart;
                      if (start == null) return;
                      _apply(
                        start.anchoring(
                          _gestureAnchorAge,
                          d.localFocalPoint.dx,
                          pxPerYear: start.pxPerYear * d.scale,
                        ),
                      );
                    },
                    onScaleEnd: (_) => _gestureStart = null,
                    onTapUp: (d) => _handleTap(d.localPosition, span),
                    child: CustomPaint(
                      painter: TimelinePainter(
                        span: span,
                        geometry: g,
                        todayAge: todayAge,
                        selectedDecadeIndex: selectedDecade?.index,
                      ),
                      size: Size(constraints.maxWidth, TimelineRows.height),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _zoomHint(),
                        style: TextStyle(
                          fontSize: 11,
                          color: kInkBlack.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '缩小',
                      icon: const Icon(Icons.zoom_out),
                      onPressed: () => _zoomAboutCentre(1 / 1.6),
                    ),
                    IconButton(
                      tooltip: '放大',
                      icon: const Icon(Icons.zoom_in),
                      onPressed: () => _zoomAboutCentre(1.6),
                    ),
                    IconButton(
                      tooltip: '全览 0-120 岁',
                      icon: const Icon(Icons.fit_screen_outlined),
                      onPressed: () {
                        final g = _geo;
                        if (g == null) return;
                        _apply(
                          TimelineGeometry.wholeLife(
                            viewportWidth: g.viewportWidth,
                            maxAge: g.maxAge,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _zoomHint() {
    final g = _geo;
    if (g == null) return '';
    final (from, to) = g.visibleAges;
    return '${from.floor()}-${to.ceil()}岁 · 双指缩放，拖动平移';
  }

  Widget _buildDetailCard(ChartResult result, LifeSpan span) {
    final age = _selectedAge;
    if (age == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '点击时间线上的任意一年，查看该年的大运与流年。',
            style: TextStyle(color: kInkBlack.withValues(alpha: 0.6)),
          ),
        ),
      );
    }

    final whole = age.floor();
    final decade = span.decadeAt(age);
    final year = span.yearAt(age);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$whole岁 · ${span.calendarYearAt(age)}年',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (decade == null)
              Text(
                '小运期（${result.qiYunDescription}前）',
                style: TextStyle(color: kInkBlack.withValues(alpha: 0.7)),
              )
            else
              Text(
                '大运 ${decade.ganZhi}　${decade.ganShiShen}/'
                '${decade.zhiMainShiShen}　'
                '${decade.startAge}-${decade.endAge}岁',
              ),
            const SizedBox(height: 4),
            if (year != null)
              Text('流年 ${year.ganZhi}　${year.ganShiShen}　${year.year}年'),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(LifeSpan span) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('图例', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final e in kElementColors.entries)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: e.value.withValues(alpha: 0.30),
                          border: Border.all(
                            color: e.value.withValues(alpha: 0.55),
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('${e.key}运', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '色块为大运，深浅区分阳干与阴干；红线为今天。'
              '${span.firstDecadeAge > 1 ? "起运前的 1-${span.firstDecadeAge - 1} 岁为小运期。" : ""}',
              style: TextStyle(
                fontSize: 12,
                color: kInkBlack.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
