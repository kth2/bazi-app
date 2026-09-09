import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/chart_result.dart';
import '../../core/analysis/event_inference.dart';
import '../../core/timeline/event_catalog.dart';
import '../../core/timeline/life_span.dart';
import '../../core/timeline/timeline_event.dart';
import '../../providers/chart_provider.dart';
import '../../providers/timeline_provider.dart';
import '../../theme.dart';
import 'event_lanes.dart';
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
  String? _selectedEventId;

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

  void _handleTap(
    Offset local,
    LifeSpan span,
    TimelineRows rows,
    List<LifeEvent> events,
    EventLanes lanes,
  ) {
    final g = _geo;
    if (g == null) return;
    if (local.dy > rows.axisTop) return;

    // A tap inside the lane block means the user is pointing at a marker,
    // not at a year. Hit testing uses the painter's own bounds function, so
    // the tappable rectangle is exactly the one that was drawn.
    if (local.dy >= rows.lanesTop && local.dy < rows.yearTop) {
      final lane = ((local.dy - rows.lanesTop) / TimelineRows.laneHeight)
          .floor()
          .clamp(0, rows.laneCount == 0 ? 0 : rows.laneCount - 1);
      for (final e in events) {
        if (lanes[e.id] != lane) continue;
        final (left, right) = TimelinePainter.boundsFor(g, e);
        if (local.dx >= left - 3 && local.dx <= right + 3) {
          setState(() {
            _selectedEventId = _selectedEventId == e.id ? null : e.id;
            _selectedAge = e.anchor.startAge;
          });
          return;
        }
      }
    }

    final age = g.ageForX(local.dx);
    if (age < 1 || age > span.maxAge) return;
    setState(() {
      _selectedAge = age;
      _selectedEventId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(chartResultProvider);
    if (result == null) {
      return const Scaffold(body: Center(child: Text('尚未排盘')));
    }
    final span = LifeSpan.of(result);
    final todayAge = _todayAge(span);
    final events = ref.watch(suggestedEventsProvider);
    final lanes = EventLanes.pack(events);
    final rows = TimelineRows(laneCount: lanes.laneCount);
    final selectedEvent = _selectedEventId == null
        ? null
        : events.where((e) => e.id == _selectedEventId).firstOrNull;

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
                    setState(() {
                      _selectedAge = todayAge;
                      _selectedEventId = null;
                    });
                  },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildAxisCard(span, todayAge, rows, events, lanes),
          const SizedBox(height: 12),
          if (selectedEvent != null)
            _buildEventCard(selectedEvent, span)
          else
            _buildDetailCard(result, span),
          const SizedBox(height: 12),
          _buildLegend(span, events),
        ],
      ),
    );
  }

  Widget _buildAxisCard(
    LifeSpan span,
    double? todayAge,
    TimelineRows rows,
    List<LifeEvent> events,
    EventLanes lanes,
  ) {
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
                height: rows.height,
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
                    onTapUp: (d) =>
                        _handleTap(d.localPosition, span, rows, events, lanes),
                    child: CustomPaint(
                      painter: TimelinePainter(
                        span: span,
                        geometry: g,
                        rows: rows,
                        events: events,
                        lanes: lanes,
                        todayAge: todayAge,
                        selectedDecadeIndex: selectedDecade?.index,
                        selectedEventId: _selectedEventId,
                      ),
                      size: Size(constraints.maxWidth, rows.height),
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

  Widget _buildEventCard(LifeEvent e, LifeSpan span) {
    final base = kDomainColors[e.domain] ?? kInkBlack;
    final anchor = e.anchor;
    final ageText = anchor.isSpan
        ? '${anchor.startAge.toInt()}-${anchor.endAge.toInt()}岁'
        : '${anchor.startAge.toInt()}岁';
    final yearText = anchor.isSpan
        ? '${span.calendarYearAt(anchor.startAge)}-'
              '${span.calendarYearAt(anchor.endAge)}年'
        : '${span.calendarYearAt(anchor.startAge)}年';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${e.label} · $ageText',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _selectedEventId = null),
                ),
              ],
            ),
            Text(
              '$yearText · ${e.domain} · 强度${e.intensity.label}'
              '${e.polarity == null ? '' : ' · ${e.polarity!.label}'}',
              style: TextStyle(color: kInkBlack.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 2),
            Text(
              '${e.origin.label}'
              '${e.confidence == null ? '' : ' · 把握度 ${(e.confidence! * 100).round()}%'}',
              style: TextStyle(
                fontSize: 12,
                color: kInkBlack.withValues(alpha: 0.55),
              ),
            ),
            if (e.basis.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('推理链', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              for (var i = 0; i < e.basis.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${i + 1}. ${e.basis[i]}',
                    style: const TextStyle(fontSize: 12, height: 1.45),
                  ),
                ),
            ],
            const SizedBox(height: 10),
            Text(
              '标记为规则推演的结果，非既定事实；同一年可有多重可能，仅供参考。',
              style: TextStyle(
                fontSize: 11,
                color: kInkBlack.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(LifeSpan span, List<LifeEvent> events) {
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
            const Divider(height: 20),
            const Text('事件标记', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final d in EventDomain.all)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 10,
                        decoration: BoxDecoration(
                          color: kDomainColors[d],
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(d, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '共 ${events.length} 个推荐标记，按每步大运取最突出的几件；'
              '颜色分事件类别，深浅分强度，长条为持续区间。点击标记看推理链。',
              style: TextStyle(
                fontSize: 12,
                color: kInkBlack.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '为免造成不必要的担忧，「${EventCatalog.guarded.map((k) => k.label).join('、')}」'
              '等敏感类别默认不显示，将在后续版本提供开关与免责说明。',
              style: TextStyle(
                fontSize: 11,
                color: kInkBlack.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
