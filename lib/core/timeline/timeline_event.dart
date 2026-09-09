import '../analysis/event_inference.dart';
import 'event_catalog.dart';

/// Where an event sits on the axis, in 虚岁.
///
/// Ages, not indices: once a birth time is corrected — or the 大运 step count
/// changes, as it did from 8 to 12 in P1 — every stored index is wrong, while
/// an age interval simply re-resolves onto the new 大运/流年.
class TimelineAnchor {
  final double startAge;

  /// Inclusive end. Equal to [startAge] for a moment rather than a stretch.
  final double endAge;

  const TimelineAnchor(this.startAge, this.endAge);

  const TimelineAnchor.at(double age) : startAge = age, endAge = age;

  bool get isSpan => endAge > startAge;
  double get width => endAge - startAge;
  double get midAge => (startAge + endAge) / 2;

  bool contains(double age) => age >= startAge && age <= endAge;

  bool overlaps(TimelineAnchor other) =>
      startAge <= other.endAge && other.startAge <= endAge;

  Map<String, dynamic> toJson() => {'startAge': startAge, 'endAge': endAge};

  factory TimelineAnchor.fromJson(Map<String, dynamic> j) => TimelineAnchor(
    (j['startAge'] as num).toDouble(),
    (j['endAge'] as num).toDouble(),
  );
}

enum EventIntensity { low, medium, high }

extension EventIntensityX on EventIntensity {
  String get label => switch (this) {
    EventIntensity.low => '轻',
    EventIntensity.medium => '中',
    EventIntensity.high => '重',
  };

  /// Bucketed from the engine's confidence. The boundaries are a display
  /// choice, not a claim about the theory — three levels is what a person can
  /// read off a bar at a glance.
  static EventIntensity fromConfidence(double c) {
    if (c >= 0.62) return EventIntensity.high;
    if (c >= 0.45) return EventIntensity.medium;
    return EventIntensity.low;
  }
}

/// Where an event came from — which decides whether a rescan may replace it.
enum EventOrigin {
  /// Produced by the scanner. A rescan replaces these wholesale.
  suggested,

  /// Suggested, then dragged by the user. A rescan leaves it alone.
  userMoved,

  /// Added by hand. The engine never touches it.
  userAdded,
}

extension EventOriginX on EventOrigin {
  bool get isUsers => this != EventOrigin.suggested;

  String get label => switch (this) {
    EventOrigin.suggested => '引擎推荐',
    EventOrigin.userMoved => '推荐后经本人调整',
    EventOrigin.userAdded => '本人添加',
  };
}

/// One marker on the timeline.
class LifeEvent {
  final String id;

  /// [EventKind.id]. Resolved through [EventCatalog] at render time so a
  /// renamed label does not invalidate saved events.
  final String kindId;

  final TimelineAnchor anchor;
  final EventIntensity intensity;
  final EventOrigin origin;

  /// The engine's confidence, 0..1. Null for user-added events — the app has
  /// no opinion about something the user asserts.
  final double? confidence;

  final EventPolarity? polarity;

  /// The reasoning chain, coarse → fine. Empty for user-added events.
  final List<String> basis;

  final String note;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const LifeEvent({
    required this.id,
    required this.kindId,
    required this.anchor,
    required this.intensity,
    required this.origin,
    required this.createdAt,
    this.confidence,
    this.polarity,
    this.basis = const [],
    this.note = '',
    this.updatedAt,
  });

  EventKind? get kind => EventCatalog.byId[kindId];

  String get label => kind?.label ?? kindId;
  String get domain => kind?.domain ?? '';

  LifeEvent copyWith({
    TimelineAnchor? anchor,
    EventIntensity? intensity,
    EventOrigin? origin,
    String? note,
    DateTime? updatedAt,
  }) => LifeEvent(
    id: id,
    kindId: kindId,
    anchor: anchor ?? this.anchor,
    intensity: intensity ?? this.intensity,
    origin: origin ?? this.origin,
    createdAt: createdAt,
    confidence: confidence,
    polarity: polarity,
    basis: basis,
    note: note ?? this.note,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Re-attach the engine's chain to a user-edited copy.
  LifeEvent withBasis(
    List<String> basis,
    EventPolarity? polarity,
    double? confidence,
  ) => LifeEvent(
    id: id,
    kindId: kindId,
    anchor: anchor,
    intensity: intensity,
    origin: origin,
    createdAt: createdAt,
    confidence: confidence ?? this.confidence,
    polarity: polarity ?? this.polarity,
    basis: basis,
    note: note,
    updatedAt: updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kindId': kindId,
    'anchor': anchor.toJson(),
    'intensity': intensity.name,
    'origin': origin.name,
    if (confidence != null)
      'confidence': double.parse(confidence!.toStringAsFixed(2)),
    if (polarity != null) 'polarity': polarity!.name,
    if (basis.isNotEmpty) 'basis': basis,
    if (note.isNotEmpty) 'note': note,
    'createdAt': createdAt.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };
}
