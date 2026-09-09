import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/timeline/event_catalog.dart';
import '../core/timeline/life_span.dart';
import '../core/timeline/timeline_event.dart';
import '../core/timeline/timeline_scanner.dart';
import 'chart_provider.dart';

/// The 0-120 axis for the current chart.
final lifeSpanProvider = Provider<LifeSpan?>((ref) {
  final chart = ref.watch(chartResultProvider);
  return chart == null ? null : LifeSpan.of(chart);
});

/// Suggested markers for the current chart.
///
/// A [Provider] rather than a call inside `build`: a full-life scan is around
/// 20-140 ms, which is fine once per chart and far too slow once per frame.
/// The result is cached until the chart itself changes.
final suggestedEventsProvider = Provider<List<LifeEvent>>((ref) {
  final span = ref.watch(lifeSpanProvider);
  if (span == null) return const [];
  return TimelineScanner.scan(
    span,
    enabledKindIds: EventCatalog.defaultEnabledIds,
  );
});
