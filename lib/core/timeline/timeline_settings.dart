import 'package:shared_preferences/shared_preferences.dart';

import 'event_catalog.dart';

/// Which event categories the user has chosen to hide.
///
/// Stores what is switched **off**, not what is switched on. Every kind ships
/// visible — including the four sensitive ones — so an opt-out list is both
/// smaller and future-proof: a category added later arrives visible rather
/// than silently absent because it was not in an old opt-in list.
class TimelineSettings {
  final Set<String> hiddenKindIds;

  const TimelineSettings({this.hiddenKindIds = const {}});

  static const _kHiddenKey = 'timeline_hidden_kinds';

  /// What the scanner should run with.
  Set<String> get enabledKindIds =>
      {for (final id in EventCatalog.allIds) if (!hiddenKindIds.contains(id)) id};

  bool isOn(String kindId) => !hiddenKindIds.contains(kindId);

  /// True while every sensitive category is still visible.
  bool get allSensitiveShown =>
      EventCatalog.sensitive.every((k) => isOn(k.id));

  TimelineSettings toggled(String kindId, bool on) {
    final next = {...hiddenKindIds};
    if (on) {
      next.remove(kindId);
    } else {
      next.add(kindId);
    }
    return TimelineSettings(hiddenKindIds: next);
  }

  static Future<TimelineSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_kHiddenKey) ?? const [];
    // Drop ids that no longer exist, so a renamed kind cannot leave a
    // category hidden under a name nothing shows.
    return TimelineSettings(
      hiddenKindIds: {
        for (final id in stored)
          if (EventCatalog.byId.containsKey(id)) id,
      },
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kHiddenKey, hiddenKindIds.toList()..sort());
  }
}
