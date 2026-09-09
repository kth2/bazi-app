import '../../core/timeline/timeline_event.dart';

/// Which horizontal lane each event is drawn in.
///
/// Packed in **age space, not pixels**, so the number of lanes — and with it
/// the height of the whole widget — does not change as the user zooms. A
/// timeline that grew and shrank vertically under a pinch would be unusable.
class EventLanes {
  /// Event id → lane index, 0 = closest to the 大运 bands.
  final Map<String, int> laneOf;

  final int laneCount;

  const EventLanes._(this.laneOf, this.laneCount);

  static const EventLanes empty = EventLanes._({}, 0);

  /// Years of clearance required between two markers in the same lane.
  ///
  /// A display constant: at the whole-life zoom a year is about three pixels,
  /// so markers closer than this would touch. Point events are treated as
  /// occupying one year.
  static const double kGapYears = 4;

  /// Lanes beyond this share the last one and may overlap; four rows is
  /// already as much vertical space as the axis can spare on a phone.
  static const int kMaxLanes = 4;

  factory EventLanes.pack(List<LifeEvent> events) {
    if (events.isEmpty) return empty;

    // Earliest first, so lanes read left to right like text.
    final ordered = [...events]
      ..sort((a, b) {
        final byStart = a.anchor.startAge.compareTo(b.anchor.startAge);
        if (byStart != 0) return byStart;
        return a.id.compareTo(b.id);
      });

    final laneEnd = <double>[]; // age at which each lane becomes free again
    final laneOf = <String, int>{};

    for (final e in ordered) {
      var lane = -1;
      for (var i = 0; i < laneEnd.length; i++) {
        if (e.anchor.startAge >= laneEnd[i]) {
          lane = i;
          break;
        }
      }
      if (lane == -1) {
        if (laneEnd.length < kMaxLanes) {
          lane = laneEnd.length;
          laneEnd.add(0);
        } else {
          // Out of lanes: put it in whichever frees up soonest and accept
          // the overlap rather than dropping the marker.
          lane = 0;
          for (var i = 1; i < laneEnd.length; i++) {
            if (laneEnd[i] < laneEnd[lane]) lane = i;
          }
        }
      }
      laneOf[e.id] = lane;
      final end =
          (e.anchor.isSpan ? e.anchor.endAge : e.anchor.startAge + 1) +
          kGapYears;
      if (end > laneEnd[lane]) laneEnd[lane] = end;
    }

    return EventLanes._(laneOf, laneEnd.length);
  }

  int operator [](String id) => laneOf[id] ?? 0;
}
