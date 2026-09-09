import 'package:bazi_core/bazi_core.dart' as bc;
import 'package:flutter/material.dart';

import '../../core/engine/labels.dart';
import '../../core/timeline/life_span.dart';
import '../../theme.dart';
import 'timeline_geometry.dart';

/// Vertical layout of the timeline.
///
/// The painter and (from P4) the marker hit testing both read these, so a
/// marker can never be drawn one row away from where it can be grabbed.
class TimelineRows {
  const TimelineRows._();

  static const double decadeTop = 12;
  static const double decadeHeight = 46;
  static const double decadeBottom = decadeTop + decadeHeight;

  static const double yearTop = decadeBottom + 8;
  static const double yearHeight = 26;
  static const double yearBottom = yearTop + yearHeight;

  static const double axisTop = yearBottom + 2;
  static const double axisHeight = 26;

  static const double height = axisTop + axisHeight;
}

/// Draws the 0-120 axis: 小运期 + 大运 colour bands, 流年 ticks, age labels
/// and a "today" marker.
///
/// Read-only. Everything it draws comes from [span] (排盘 output) and [geometry]
/// (the current zoom/scroll); it computes nothing about the chart itself.
class TimelinePainter extends CustomPainter {
  final LifeSpan span;
  final TimelineGeometry geometry;

  /// 虚岁 of today, or null when the chart is not for a living-through age
  /// on this axis (未出生 or past 120).
  final double? todayAge;

  /// Highlighted 大运 index, if the user has tapped one.
  final int? selectedDecadeIndex;

  const TimelinePainter({
    required this.span,
    required this.geometry,
    this.todayAge,
    this.selectedDecadeIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintDecades(canvas, size);
    _paintYearTicks(canvas, size);
    _paintAxis(canvas, size);
    _paintToday(canvas, size);
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
      final top = TimelineRows.yearTop;
      final bottom = isMajor
          ? TimelineRows.yearBottom
          : TimelineRows.yearTop + TimelineRows.yearHeight * 0.5;
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
              Offset(
                x + (geometry.pxPerYear - tp.width) / 2,
                TimelineRows.yearTop + 4,
              ),
            );
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------- 轴

  void _paintAxis(Canvas canvas, Size size) {
    final y = TimelineRows.axisTop;
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
      Offset(x, TimelineRows.axisTop),
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
      old.geometry.pxPerYear != geometry.pxPerYear ||
      old.geometry.offset != geometry.offset ||
      old.geometry.viewportWidth != geometry.viewportWidth ||
      old.todayAge != todayAge ||
      old.selectedDecadeIndex != selectedDecadeIndex;
}
