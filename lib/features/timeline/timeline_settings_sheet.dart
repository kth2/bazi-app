import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/timeline/event_catalog.dart';
import '../../providers/timeline_provider.dart';
import '../../theme.dart';

/// Switches for the categories that are off by default.
///
/// The four named as sensitive — 离婚、大病/手术、寿元、官司 — stay off until
/// someone asks for them, and asking requires reading the disclaimer once.
/// 破财风险 is deliberately *not* in this list.
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
    final guarded = EventCatalog.guarded;

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
              '以下类别默认不显示。开启后会在时间线上多出对应标记，'
              '不会挤掉原有的标记。',
              style: TextStyle(
                fontSize: 12,
                color: kInkBlack.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 8),
            for (final k in guarded)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${k.domain} · ${k.label}'),
                value: settings.isOn(k.id),
                onChanged: (on) async {
                  if (on && !settings.acknowledgedDisclaimer) {
                    final ok = await _confirm(context);
                    if (!ok) return;
                    await notifier.acknowledge();
                  }
                  await notifier.toggle(k.id, on);
                },
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kInkBlack.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                EventCatalog.kGuardedDisclaimer,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: kInkBlack.withValues(alpha: 0.75),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '本应用不预测寿元，也不会把任何一年标为生命终点；'
              '健康类标记只是提示需要留意的年份。',
              style: TextStyle(
                fontSize: 11,
                color: kInkBlack.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirm(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('开启敏感类别'),
        content: Text(
          '${EventCatalog.kGuardedDisclaimer}\n\n'
          '这些标记是规则推演的可能性，不是既定事实。确定开启吗？',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('我已阅读，开启'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}
