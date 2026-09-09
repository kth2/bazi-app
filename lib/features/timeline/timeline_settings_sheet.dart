import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/timeline/event_catalog.dart';
import '../../providers/timeline_provider.dart';
import '../../theme.dart';

/// Switches for the categories that make the heaviest claims.
///
/// All four — 离婚、手术、寿元、官非 — are **shown by default**. The sheet
/// exists so a person can switch off a reading they would rather not carry
/// around, not so they have to ask permission to see one.
Future<void> showTimelineSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _TimelineSettingsSheet(),
  );
}

class _TimelineSettingsSheet extends ConsumerWidget {
  const _TimelineSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(timelineSettingsProvider);
    final notifier = ref.read(timelineSettingsProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '敏感类别',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '这几类默认**显示**，信或不信由你判断。'
              '若不想在时间线上看到某一类，在这里关掉即可。',
              style: TextStyle(
                fontSize: 12,
                color: kInkBlack.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 8),
            for (final k in EventCatalog.sensitive)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${k.domain} · ${k.label}'),
                subtitle: k.id == 'health.longevity'
                    ? Text(
                        '标的是需留意健康的年份区间，不是生命终点',
                        style: TextStyle(
                          fontSize: 11,
                          color: kInkBlack.withValues(alpha: 0.6),
                        ),
                      )
                    : null,
                value: settings.isOn(k.id),
                onChanged: (on) => notifier.toggle(k.id, on),
              ),
            const SizedBox(height: 8),
            _note(EventCatalog.kGuardedDisclaimer),
            const SizedBox(height: 8),
            _note(EventCatalog.kLongevityDisclaimer),
          ],
        ),
      ),
    );
  }

  Widget _note(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kInkBlack.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: kInkBlack.withValues(alpha: 0.75),
          ),
        ),
      );
}
