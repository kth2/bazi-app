import 'package:bazi_core/bazi_core.dart' as bc;
import 'package:flutter/material.dart';

import '../../core/analysis/event_inference.dart';
import '../../core/engine/labels.dart';
import '../../core/timeline/life_span.dart';
import '../../core/timeline/timeline_event.dart';
import 'event_lanes.dart';
import '../../theme.dart';
import 'timeline_geometry.dart';

/// Vertical layout of the timeline.
///
/// The painter, the page's SizedBox and (from P4) the marker hit testing all
/// read these, so a marker can never be drawn one row away from where it can
/// be grabbed. Only the lane block varies, and it varies with the number of
/// event lanes rather than with zoom — see [EventLanes].
class TimelineRows {
  final int laneCount;

  const TimelineRows({this.laneCount = 0});

  static const double decadeTop = 12;
  static const double decadeHeight = 46;
  static const double decadeBottom = decadeTop + decadeHeight;

  static const double laneHeight = 17;
  static const double markerHeight = 12;
  static const double yearHeight = 26;
  static const double axisHeight = 26;

  double get lanesTop => decadeBottom + 6;
  double get lanesHeight => laneCount * laneHeight;

  double laneTop(int lane) => lanesTop + lane * laneHeight;

  double get yearTop => lanesTop + lanesHeight + (laneCount > 0 ? 4 : 2);
  double get yearBottom => yearTop + yearHeight;

  double get axisTop => yearBottom + 2;
  double get height => axisTop + axisHeight;
}

/// Marker colours, one per 事件域.
///
/// Deliberately muted and distinct in hue from [kElementColors]: the 大运
/// bands behind them are the five elements, and a marker that looked like a
/// pale 火 band would read as part of the band rather than as an event.
///
/// Polarity is *not* colour-coded. 吉凶 shown as green-vs-red across forty
/// markers turns a reference tool into a mood, and this app has already had
/// to correct for pessimistic framing once; the polarity is stated in words
/// on the marker's detail panel instead.
const Map<String, Color> kDomainColors = {
  EventDomain.career: Color(0xFF3F5169),
  EventDomain.wealth: Color(0xFF8A6B2F),
  EventDomain.marriage: Color(0xFF8C4A63),
  EventDomain.study: Color(0xFF3F6B63),
  EventDomain.health: Color(0xFF6B5B8A),
};

/// Draws the 0-120 axis: 小运期 + 大运 colour bands, 流年 ticks, age labels
/// and a "today" marker.
///
/// Read-only. Everything it draws comes from [span] (排盘 output) and [geometry]
/// (the current zoom/scroll); it computes nothing about the chart itself.
class TimelinePainter extends CustomPainter {
  final LifeSpan span;
  final TimelineGeometry geometry;
  final TimelineRows rows;

  /// Suggested and user-placed markers, already filtered by the enabled
  /// categories.
  final List<LifeEvent> events;
  final EventLanes lanes;

  /// 虚岁 of today, or null when the chart is not for a living-through age
  /// on this axis (未出生 or past 120).
  final double? todayAge;

  /// Highlighted 大运 index, if the user has tapped one.
  final int? selectedDecadeIndex;

  /// Id of the tapped marker.
  final String? selectedEventId;

  const TimelinePainter({
    required this.span,
    required this.geometry,
    required this.rows,
    this.events = const [],
    this.lanes = EventLanes.empty,
    this.todayAge,
    this.selectedDecadeIndex,
    this.selectedEventId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintDecades(canvas, size);
    _paintEvents(canvas, size);
    _paintYearTicks(canvas, size);
    _paintAxis(canvas, size);
    _paintToday(canvas, size);
  }

  // -------------------------------------------------------------- 事件标记

  /// Pixel span a marker occupies, including the minimum width a point event
  /// needs to stay tappable. Shared with the page's hit testing, so what is
  /// drawn and what can be tapped are the same rectangle.
  static (double, double) boundsFor(TimelineGeometry g, LifeEvent e) {
    final left = g.xForAge(e.anchor.startAge);
    final right = g.xForAge(
      e.anchor.isSpan ? e.anchor.endAge + 1 : e.anchor.startAge + 1,
    );
    const minWidth = 14.0;
    if (right - left >= minWidth) return (left, right);
    final centre = (left + right) / 2;
    return (centre - minWidth / 2, centre + minWidth / 2);
  }

  (double, double) markerBounds(LifeEvent e) => boundsFor(geometry, e);

  void _paintEvents(Canvas canvas, Size size) {
    if (events.isEmpty) return;
    final labelled = geometry.lod != TimelineLod.decade;

    for (final e in events) {
      final (left, right) = markerBounds(e);
      if (right < -80 || left > size.width + 8) continue;

      final kind = e.kind;
      final base = kDomainColors[e.domain] ?? kInkBlack;
      final selected = e.id == selectedEventId;
      // Intensity reads as weight, not as alarm: a 轻 marker is quieter, a
      // 重 one is solid. Nothing here says 吉 or 凶.
      final alpha = switch (e.intensity) {
        EventIntensity.high => 0.95,
        EventIntensity.medium => 0.72,
        EventIntensity.low => 0.48,
      };

      final top =
          rows.laneTop(lanes[e.id]) +
          (TimelineRows.laneHeight - TimelineRows.markerHeight) / 2;
      final rect = Rect.fromLTRB(
        left,
        top,
        right,
        top + TimelineRows.markerHeight,
      );
      final rrect = RRect.fromRectAndRadius(
        rect,
        const Radius.circular(TimelineRows.markerHeight / 2),
      );

      canvas.drawRRect(rrect, Paint()..color = base.withValues(alpha: alpha));
      if (selected) {
        canvas.drawRRect(
          rrect.inflate(2.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = kPrimaryRed,
        );
      }
      // A user-placed marker is marked as such on the axis, not only in the
      // detail panel: the two must never be mistaken for each other.
      if (e.origin.isUsers) {
        canvas.drawCircle(
          Offset(rect.left + 4, rect.center.dy),
          2,
          Paint()..color = kPaperCream,
        );
      }

      if (!labelled || kind == null) continue;
      final tp = _text(kind.label, 11, base, FontWeight.w600);
      final labelX = rect.right + 4;
      if (labelX + tp.width > size.width) continue;
      tp.paint(canvas, Offset(labelX, rect.center.dy - tp.height / 2));
    }
  }

  // ---------------------------------------------------------------- 大运

  void _paintDecades(Canvas canvas, Size size) {
    final (visibleFrom, visibleTo) = geometry.visibleAges;

    // 小运期: the years before 起运, which belong to no 大运 but are still
    // lived. Drawn flat grey so it reads as "no 大运 here" rather than as a
    // step someone might mistake for one.
    final preEnd = span.firstDecadeAge.toDouble();
    if (preEnd > 1) {
      _band(
        canvas,
        from: 0,
        to: preEnd,
        fill: kInkBlack.withValues(alpha: 0.06),
        stroke: kInkBlack.withValues(alpha: 0.18),
        label: '小运',
        sublabel: '1-${span.firstDecadeAge - 1}岁',
        labelColor: kInkBlack.withValues(alpha: 0.55),
      );
    }

    for (final d in span.decades) {
      final (from, to) = span.boundsOf(d);
      if (to < visibleFrom - 1 || from > visibleTo + 1) continue;

      final gan = bc.TianGan.fromName(d.ganZhi[0]);
      final element = kWuXingLabels[bc.BaziTable.getWuXingOfGan(gan)] ?? '';
      final base = kElementColors[element] ?? kInkBlack;
      // 阳干 sit deeper than 阴干, so two adjacent same-element steps
      // (甲 then 乙) stay distinguishable without a legend.
      final isYang = bc.BaziTable.getYinYangOfGan(gan) == bc.YinYang.yang;
      final selected = d.index == selectedDecadeIndex;

      _band(
        canvas,
        from: from,
        to: to,
        fill: base.withValues(alpha: isYang ? 0.30 : 0.16),
        stroke: selected ? base : base.withValues(alpha: 0.55),
        strokeWidth: selected ? 2.4 : 1,
        label: d.ganZhi,
        sublabel: '${d.startAge}-${d.endAge}岁',
        labelColor: base.withValues(alpha: 0.95),
      );
    }
  }

  void _band(
    Canvas canvas, {
    required double from,
    required double to,
    required Color fill,
    required Color stroke,
    double strokeWidth = 1,
    required String label,
    required String sublabel,
    required Color labelColor,
  }) {
    final left = geometry.xForAge(from);
    final right = geometry.xForAge(to);
    // A hairline gap keeps neighbouring bands from fusing into one block.
    final rect = Rect.fromLTRB(
      left + 0.5,
      TimelineRows.decadeTop,
      right - 0.5,
      TimelineRows.decadeBottom,
    );
    if (rect.width <= 0) return;

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect, Paint()..color = fill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = stroke,
    );

    if (rect.width < 26) return;
    final tp = _text(label, 15, labelColor, FontWeight.w700);
    if (tp.width > rect.width - 4) return;
    final showSub = rect.width >= 58;
    final subTp = showSub
        ? _text(
            sublabel,
            10,
            labelColor.withValues(alpha: 0.75),
            FontWeight.w400,
          )
        : null;
    final blockHeight = tp.height + (subTp == null ? 0 : subTp.height + 1);
    var y = rect.top + (rect.height - blockHeight) / 2;
    tp.paint(canvas, Offset(rect.center.dx - tp.width / 2, y));
    if (subTp != null && subTp.width <= rect.width - 4) {
      y += tp.height + 1;
      subTp.paint(canvas, Offset(rect.center.dx - subTp.width / 2, y));
    }
  }

  // ---------------------------------------------------------------- 流年

  void _paintYearTicks(Canvas canvas, Size size) {
    final (visibleFrom, visibleTo) = geometry.visibleAges;
    final step = geometry.tickEvery;
    final major = geometry.majorTickEvery;
    final showGanZhi =
        geometry.lod == TimelineLod.year && geometry.pxPerYear >= 30;

    final minor = Paint()
      ..color = kInkBlack.withValues(alpha: 0.22)
      ..strokeWidth = 1;
    final strong = Paint()
      ..color = kInkBlack.withValues(alpha: 0.45)
      ..strokeWidth = 1.4;

    final first = (visibleFrom.floor() ~/ step) * step;
    for (
      var age = first < 1 ? 1 : first;
      age <= visibleTo.ceil() && age <= span.maxAge;
      age += step
    ) {
      // Ticks sit on the year's start edge, matching where the 流年 band
      // begins — age 30's tick is the boundary into age 30, not its middle.
      final x = geometry.xForAge(age.toDouble());
      final isMajor = age % major == 0;
      final top = rows.yearTop;
      final bottom = isMajor
          ? rows.yearBottom
          : rows.yearTop + TimelineRows.yearHeight * 0.5;
      canvas.drawLine(
        Offset(x, top),
        Offset(x, bottom),
        isMajor ? strong : minor,
      );

      if (showGanZhi) {
        final y = span.yearAt(age.toDouble());
        if (y != null) {
          final tp = _text(
            y.ganZhi,
            11,
            kInkBlack.withValues(alpha: 0.7),
            FontWeight.w500,
          );
          if (tp.width <= geometry.pxPerYear - 3) {
            tp.paint(
              canvas,
              Offset(x + (geometry.pxPerYear - tp.width) / 2, rows.yearTop + 4),
            );
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------- 轴

  void _paintAxis(Canvas canvas, Size size) {
    final y = rows.axisTop;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = kInkBlack.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );

    final (visibleFrom, visibleTo) = geometry.visibleAges;
    final step = geometry.axisLabelEvery;
    final first = (visibleFrom.floor() ~/ step) * step;
    final perYear = geometry.axisLabelEvery == 1;

    for (
      var age = first < step ? step : first;
      age <= visibleTo.ceil() && age <= span.maxAge;
      age += step
    ) {
      final x = geometry.xForAge(age.toDouble());
      final tp = _text(
        '$age岁',
        11,
        kInkBlack.withValues(alpha: 0.75),
        FontWeight.w500,
      );
      // At per-year labels the number belongs inside its own year band;
      // at coarser steps it straddles the tick it names.
      final dx = perYear
          ? x + (geometry.pxPerYear - tp.width) / 2
          : x - tp.width / 2;
      tp.paint(canvas, Offset(dx, y + 3));

      if (geometry.pxPerYear * step >= 64) {
        final cal = _text(
          '${span.calendarYearAt(age.toDouble())}',
          9,
          kInkBlack.withValues(alpha: 0.45),
          FontWeight.w400,
        );
        final cdx = perYear
            ? x + (geometry.pxPerYear - cal.width) / 2
            : x - cal.width / 2;
        cal.paint(canvas, Offset(cdx, y + 3 + tp.height));
      }
    }
  }

  void _paintToday(Canvas canvas, Size size) {
    final age = todayAge;
    if (age == null || age < 0 || age > span.maxAge) return;
    final x = geometry.xForAge(age);
    if (x < -4 || x > size.width + 4) return;

    canvas.drawLine(
      Offset(x, TimelineRows.decadeTop - 6),
      Offset(x, rows.axisTop),
      Paint()
        ..color = kPrimaryRed
        ..strokeWidth = 1.6,
    );
    canvas.drawCircle(
      Offset(x, TimelineRows.decadeTop - 6),
      3.5,
      Paint()..color = kPrimaryRed,
    );
  }

  TextPainter _text(String s, double size, Color color, FontWeight weight) {
    return TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, color: color, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
  }

  @override
  bool shouldRepaint(TimelinePainter old) =>
      old.span != span ||
      old.events != events ||
      old.lanes != lanes ||
      old.rows.laneCount != rows.laneCount ||
      old.selectedEventId != selectedEventId ||
      old.geometry.pxPerYear != geometry.pxPerYear ||
      old.geometry.offset != geometry.offset ||
      old.geometry.viewportWidth != geometry.viewportWidth ||
      old.todayAge != todayAge ||
      old.selectedDecadeIndex != selectedDecadeIndex;
}
