import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/timeline/life_span.dart';
import '../core/timeline/timeline_event.dart';
import '../core/timeline/timeline_scanner.dart';
import '../core/timeline/timeline_settings.dart';
import '../core/timeline/timeline_store.dart';
import 'chart_provider.dart';

/// The 0-120 axis for the current chart.
final lifeSpanProvider = Provider<LifeSpan?>((ref) {
  final chart = ref.watch(chartResultProvider);
  return chart == null ? null : LifeSpan.of(chart);
});

/// Identity the current chart's events are filed under.
final chartKeyProvider = Provider<String?>((ref) {
  final chart = ref.watch(chartResultProvider);
  return chart == null ? null : chartKeyOf(chart);
});

/// Which categories are switched on. Overridden in tests.
final timelineSettingsProvider =
    StateNotifierProvider<TimelineSettingsNotifier, TimelineSettings>(
      (ref) => TimelineSettingsNotifier(),
    );

class TimelineSettingsNotifier extends StateNotifier<TimelineSettings> {
  TimelineSettingsNotifier([TimelineSettings? initial])
    : super(initial ?? const TimelineSettings()) {
    if (initial == null) _restore();
  }

  Future<void> _restore() async {
    state = await TimelineSettings.load();
  }

  Future<void> toggle(String kindId, bool on) async {
    state = state.toggled(kindId, on);
    await state.save();
  }
}

/// Storage for user-placed events. Overridden in tests with an in-memory
/// implementation, because drift's open never completes under fake async.
final timelineStoreProvider = Provider<TimelineStore>((ref) {
  final db = TimelineDatabase();
  ref.onDispose(db.close);
  return TimelineRepository(db);
});

/// Suggested markers for the current chart.
///
/// A [Provider] rather than a call inside `build`: a full-life scan is around
/// 20-140 ms, which is fine once per chart and far too slow once per frame.
/// The result is cached until the chart or the enabled categories change.
final suggestedEventsProvider = Provider<List<LifeEvent>>((ref) {
  final span = ref.watch(lifeSpanProvider);
  if (span == null) return const [];
  final settings = ref.watch(timelineSettingsProvider);
  return TimelineScanner.scan(span, enabledKindIds: settings.enabledKindIds);
});

/// What the user has added, moved or dismissed on this chart.
final storedEventsProvider = StreamProvider<List<StoredEvent>>((ref) {
  final key = ref.watch(chartKeyProvider);
  if (key == null) return Stream.value(const []);
  return ref.watch(timelineStoreProvider).watch(key);
});

/// Suggestions and user edits, reconciled — what the timeline actually draws.
final timelineEventsProvider = Provider<List<LifeEvent>>((ref) {
  final suggested = ref.watch(suggestedEventsProvider);
  final stored = ref.watch(storedEventsProvider).value ?? const [];
  return mergeTimeline(suggested, stored);
});
