import 'package:flutter/material.dart';

import '../../core/timeline/event_catalog.dart';
import '../../core/timeline/life_span.dart';
import '../../core/timeline/timeline_event.dart';
import '../../theme.dart';
import 'timeline_painter.dart';

/// What the editor sheet was closed with.
sealed class EventEditResult {
  const EventEditResult();
}

class EventSaved extends EventEditResult {
  final LifeEvent event;
  const EventSaved(this.event);
}

class EventDeleted extends EventEditResult {
  const EventDeleted();
}

/// Add or edit one marker.
///
/// Ages are edited numerically here rather than only by dragging: a drag is
/// good for "about there" and hopeless for "the year I turned 33".
Future<EventEditResult?> showEventEditor(
  BuildContext context, {
  required LifeSpan span,
  LifeEvent? existing,
  double? initialAge,
}) {
  return showModalBottomSheet<EventEditResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _EventEditor(
        span: span,
        existing: existing,
        initialAge: initialAge,
      ),
    ),
  );
}

class _EventEditor extends StatefulWidget {
  final LifeSpan span;
  final LifeEvent? existing;
  final double? initialAge;

  const _EventEditor({required this.span, this.existing, this.initialAge});

  @override
  State<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<_EventEditor> {
  late String _kindId;
  late double _startAge;
  late double _endAge;
  late EventIntensity _intensity;
  late TextEditingController _note;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _kindId = e?.kindId ?? EventCatalog.kinds.first.id;
    final start =
        e?.anchor.startAge ?? (widget.initialAge?.floorToDouble() ?? 30);
    _startAge = start.clamp(1, widget.span.maxAge.toDouble());
    _endAge = (e?.anchor.endAge ?? start).clamp(
      1,
      widget.span.maxAge.toDouble(),
    );
    _intensity = e?.intensity ?? EventIntensity.medium;
    _note = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _shift(bool isStart, int by) {
    setState(() {
      if (isStart) {
        _startAge = (_startAge + by).clamp(1, widget.span.maxAge.toDouble());
        if (_endAge < _startAge) _endAge = _startAge;
      } else {
        _endAge = (_endAge + by).clamp(1, widget.span.maxAge.toDouble());
        if (_endAge < _startAge) _startAge = _endAge;
      }
    });
  }

  void _save() {
    final now = DateTime.now();
    final existing = widget.existing;
    final anchor = TimelineAnchor(_startAge, _endAge);
    final event = existing == null
        ? LifeEvent(
            id: 'user:${now.microsecondsSinceEpoch}',
            kindId: _kindId,
            anchor: anchor,
            intensity: _intensity,
            origin: EventOrigin.userAdded,
            note: _note.text.trim(),
            createdAt: now,
          )
        : LifeEvent(
            id: existing.id,
            kindId: _kindId,
            anchor: anchor,
            intensity: _intensity,
            // A suggested event the user has edited stops being replaceable
            // by the next rescan; one they added stays theirs.
            origin: existing.origin == EventOrigin.userAdded
                ? EventOrigin.userAdded
                : EventOrigin.userMoved,
            confidence: existing.confidence,
            polarity: existing.polarity,
            basis: existing.basis,
            note: _note.text.trim(),
            createdAt: existing.createdAt,
            updatedAt: now,
          );
    Navigator.of(context).pop(EventSaved(event));
  }

  @override
  Widget build(BuildContext context) {
    final span = widget.span;
    final kind = EventCatalog.byId[_kindId]!;
    final color = kDomainColors[kind.domain] ?? kInkBlack;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _isNew ? '添加事件' : '编辑事件',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (!_isNew)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('删除'),
                    onPressed: () =>
                        Navigator.of(context).pop(const EventDeleted()),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('类别', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _kindId,
              isExpanded: true,
              items: [
                for (final k in EventCatalog.kinds)
                  DropdownMenuItem(
                    value: k.id,
                    child: Text(
                      '${k.domain} · ${k.label}'
                      '${k.isSensitive ? '（敏感）' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _kindId = v ?? _kindId),
            ),
            const SizedBox(height: 14),
            _ageRow('开始', _startAge, true, span),
            const SizedBox(height: 6),
            _ageRow('结束', _endAge, false, span),
            if (_endAge > _startAge)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '区间事件，共 ${(_endAge - _startAge + 1).toInt()} 年',
                  style: TextStyle(
                    fontSize: 12,
                    color: kInkBlack.withValues(alpha: 0.6),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            const Text('强度', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SegmentedButton<EventIntensity>(
              segments: [
                for (final i in EventIntensity.values)
                  ButtonSegment(value: i, label: Text(i.label)),
              ],
              selected: {_intensity},
              onSelectionChanged: (s) => setState(() => _intensity = s.first),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                hintText: '例如：实际发生的事，或想留意的事',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Text(
              '本人添加或调整过的事件不会被重新推演覆盖，'
              '也不会反过来影响命理推断。',
              style: TextStyle(
                fontSize: 11,
                color: kInkBlack.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              icon: Icon(Icons.check, color: color),
              label: const Text('保存'),
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _ageRow(String label, double age, bool isStart, LifeSpan span) {
    final year = span.calendarYearAt(age);
    return Row(
      children: [
        SizedBox(width: 44, child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          tooltip: '$label减一年',
          onPressed: () => _shift(isStart, -1),
        ),
        SizedBox(
          width: 96,
          child: Text(
            '${age.toInt()}岁 · $year',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: '$label加一年',
          onPressed: () => _shift(isStart, 1),
        ),
      ],
    );
  }
}
