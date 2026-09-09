import 'dart:math' as math;

/// How much detail the axis can carry at the current zoom.
enum TimelineLod {
  /// Only 大运 bands are legible; years are sub-pixel.
  decade,

  /// 大运 bands plus a tick every five years.
  fiveYear,

  /// Every 流年 gets a tick and a label.
  year,
}

/// Maps between pixels and 虚岁 on the horizontal axis.
///
/// Immutable and free of Flutter types, so the mapping can be tested directly
/// — which matters because the painter, the hit testing and (in P4) the
/// drag-drop all resolve positions through this one object. A timeline whose
/// drawing and whose input disagree by a year is easy to write and hard to
/// spot by eye.
class TimelineGeometry {
  /// Pixels per year of life.
  final double pxPerYear;

  /// Pixels scrolled past age 0.
  final double offset;

  final double viewportWidth;
  final int maxAge;

  const TimelineGeometry({
    required this.pxPerYear,
    required this.offset,
    required this.viewportWidth,
    required this.maxAge,
  });

  /// Zoom limits: at 2 px/year the whole 120 years fits a phone; at 48 a
  /// single year is wide enough for a 干支 label.
  static const double kMinPxPerYear = 2;
  static const double kMaxPxPerYear = 48;

  /// A view showing the entire life, which is the sensible entry point —
  /// the feature exists to show two 甲子 at once.
  factory TimelineGeometry.wholeLife({
    required double viewportWidth,
    required int maxAge,
  }) {
    final px = (viewportWidth / maxAge).clamp(kMinPxPerYear, kMaxPxPerYear);
    return TimelineGeometry(
      pxPerYear: px,
      offset: 0,
      viewportWidth: viewportWidth,
      maxAge: maxAge,
    );
  }

  double get contentWidth => maxAge * pxPerYear;

  /// Scrolling stops when the end of life reaches the right edge; if the
  /// whole span already fits, there is nothing to scroll.
  double get maxOffset => math.max(0, contentWidth - viewportWidth);

  double clampOffset(double value) => value.clamp(0.0, maxOffset);

  double xForAge(double age) => age * pxPerYear - offset;

  double ageForX(double x) => (x + offset) / pxPerYear;

  /// Age range currently on screen, clamped to the span.
  (double, double) get visibleAges => (
    ageForX(0).clamp(0.0, maxAge.toDouble()),
    ageForX(viewportWidth).clamp(0.0, maxAge.toDouble()),
  );

  TimelineLod get lod {
    if (pxPerYear < 4) return TimelineLod.decade;
    if (pxPerYear < 16) return TimelineLod.fiveYear;
    return TimelineLod.year;
  }

  /// Year interval between tick marks at this zoom.
  int get tickEvery => switch (lod) {
    TimelineLod.decade => 10,
    TimelineLod.fiveYear => 5,
    TimelineLod.year => 1,
  };

  /// Every Nth tick is drawn tall, to give the eye something to count by.
  int get majorTickEvery => lod == TimelineLod.year ? 5 : 10;

  /// Year interval between age labels on the axis.
  ///
  /// Separate from [tickEvery] because ticks cost a pixel and labels cost
  /// about 44: at full zoom every year gets a tick, but labelling every year
  /// would overlap into an unreadable smear.
  int get axisLabelEvery {
    for (final step in const [1, 2, 5, 10, 20]) {
      if (step * pxPerYear >= 44) return step;
    }
    return 50;
  }

  TimelineGeometry copyWith({
    double? pxPerYear,
    double? offset,
    double? viewportWidth,
  }) {
    final next = TimelineGeometry(
      pxPerYear: pxPerYear ?? this.pxPerYear,
      offset: offset ?? this.offset,
      viewportWidth: viewportWidth ?? this.viewportWidth,
      maxAge: maxAge,
    );
    return next.copyOffset(next.offset);
  }

  TimelineGeometry copyOffset(double value) => TimelineGeometry(
    pxPerYear: pxPerYear,
    offset: clampOffsetFor(pxPerYear, value),
    viewportWidth: viewportWidth,
    maxAge: maxAge,
  );

  double clampOffsetFor(double px, double value) {
    final max = math.max(0.0, maxAge * px - viewportWidth);
    return value.clamp(0.0, max);
  }

  /// Pan by [dx] pixels of finger movement (drag left ⇒ move forward in life).
  TimelineGeometry panBy(double dx) => copyOffset(offset - dx);

  /// A view at [pxPerYear] with [age] sitting at [x].
  ///
  /// The primitive every gesture is expressed in: a pinch is "keep the age
  /// that was under the fingers under the fingers", and a live pinch-drag is
  /// the same statement with a moving [x]. Without it the content slides out
  /// from under the gesture, which reads as the timeline fighting you.
  TimelineGeometry anchoring(double age, double x, {double? pxPerYear}) {
    final px = (pxPerYear ?? this.pxPerYear)
        .clamp(kMinPxPerYear, kMaxPxPerYear)
        .toDouble();
    return TimelineGeometry(
      pxPerYear: px,
      offset: clampOffsetFor(px, age * px - x),
      viewportWidth: viewportWidth,
      maxAge: maxAge,
    );
  }

  /// Pinch about [focalX], keeping the age under the fingers pinned.
  TimelineGeometry zoomBy(double scale, double focalX) =>
      anchoring(ageForX(focalX), focalX, pxPerYear: pxPerYear * scale);

  /// Re-centre on an age, used when jumping to "today".
  TimelineGeometry centeredOn(double age) =>
      copyOffset(age * pxPerYear - viewportWidth / 2);
}
