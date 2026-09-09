import 'package:shared_preferences/shared_preferences.dart';

import 'event_catalog.dart';

/// Which event categories the user has chosen to see.
///
/// Only guarded kinds are stored: ordinary ones are always on, so persisting
/// them would mean a future catalog addition silently arriving switched off.
class TimelineSettings {
  /// Guarded kind ids the user has switched on.
  final Set<String> enabledGuardedIds;

  /// True once the user has been shown the disclaimer and switched something
  /// on anyway. Reset when they switch everything back off.
  final bool acknowledgedDisclaimer;

  const TimelineSettings({
    this.enabledGuardedIds = const {},
    this.acknowledgedDisclaimer = false,
  });

  static const _kEnabledKey = 'timeline_guarded_enabled';
  static const _kAckKey = 'timeline_guarded_acknowledged';

  /// The full set the scanner should run with.
  Set<String> get enabledKindIds => {
    ...EventCatalog.defaultEnabledIds,
    ...enabledGuardedIds,
  };

  bool isOn(String kindId) => enabledGuardedIds.contains(kindId);

  TimelineSettings toggled(String kindId, bool on) {
    final next = {...enabledGuardedIds};
    if (on) {
      next.add(kindId);
    } else {
      next.remove(kindId);
    }
    return TimelineSettings(
      enabledGuardedIds: next,
      acknowledgedDisclaimer: next.isEmpty ? false : acknowledgedDisclaimer,
    );
  }

  TimelineSettings acknowledged() => TimelineSettings(
    enabledGuardedIds: enabledGuardedIds,
    acknowledgedDisclaimer: true,
  );

  static Future<TimelineSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_kEnabledKey) ?? const [];
    // Drop ids that no longer exist, so a renamed kind cannot leave a
    // sensitive category enabled under a name nothing shows.
    final valid = {
      for (final id in stored)
        if (EventCatalog.byId[id]?.isGuarded ?? false) id,
    };
    return TimelineSettings(
      enabledGuardedIds: valid,
      acknowledgedDisclaimer:
          valid.isNotEmpty && (prefs.getBool(_kAckKey) ?? false),
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kEnabledKey, enabledGuardedIds.toList()..sort());
    await prefs.setBool(_kAckKey, acknowledgedDisclaimer);
  }
}
