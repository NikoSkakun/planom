import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

import '../localization/strings.dart';
import '../theme/app_theme.dart';
import '../theme/appearance_prefs.dart';
import '../utils/color_picker.dart';

/// Editor for a [DynamicColorTimeline]: a day-long gradient preview plus a
/// list of color stops the user can add, retime, recolor, or remove. Colors
/// blend linearly between adjacent stops (wrapping across midnight), matching
/// how the timeline renders at runtime.
class DynamicColorEditor extends StatelessWidget {
  const DynamicColorEditor({
    super.key,
    required this.timeline,
    required this.onChanged,
  });

  final DynamicColorTimeline timeline;
  final ValueChanged<DynamicColorTimeline> onChanged;

  String _formatMinute(int minute) {
    final h = minute ~/ 60;
    final m = minute % 60;
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _emit(List<ColorStop> stops) =>
      onChanged(DynamicColorTimeline(stops));

  Future<void> _editColor(BuildContext context, int index) async {
    final stops = List<ColorStop>.of(timeline.stops);
    final picked = await showCustomColorPicker(
      context,
      initialColor: stops[index].color,
      title: S.of(context).customColor,
    );
    if (picked != null) {
      stops[index] = stops[index].copyWith(color: picked);
      _emit(stops);
    }
  }

  Future<void> _editTime(BuildContext context, int index) async {
    final picked = await _pickTime(context, timeline.stops[index].minute);
    if (picked != null) {
      final stops = List<ColorStop>.of(timeline.stops);
      stops[index] = stops[index].copyWith(minute: picked);
      _emit(stops);
    }
  }

  void _remove(int index) {
    if (timeline.stops.length <= 1) return;
    final stops = List<ColorStop>.of(timeline.stops)..removeAt(index);
    _emit(stops);
  }

  void _add() {
    final stops = List<ColorStop>.of(timeline.stops);
    // Place the new stop in the largest gap so it doesn't collide, defaulting
    // to noon when the timeline is empty.
    int newMinute = 12 * 60;
    if (stops.isNotEmpty) {
      final sorted = List<ColorStop>.of(stops)
        ..sort((a, b) => a.minute.compareTo(b.minute));
      var bestGap = -1;
      var bestMid = newMinute;
      for (var i = 0; i < sorted.length; i++) {
        final a = sorted[i].minute;
        final b = i + 1 < sorted.length ? sorted[i + 1].minute : sorted[0].minute + 1440;
        final gap = b - a;
        if (gap > bestGap) {
          bestGap = gap;
          bestMid = ((a + b) ~/ 2) % 1440;
        }
      }
      newMinute = bestMid;
    }
    stops.add(ColorStop(newMinute, timeline.colorAt(newMinute)));
    _emit(stops);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final stops = timeline.stops; // already sorted
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final canRemove = stops.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GradientPreview(timeline: timeline),
        const SizedBox(height: 14),
        for (var i = 0; i < stops.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _StopRow(
              time: _formatMinute(stops[i].minute),
              color: stops[i].color,
              canRemove: canRemove,
              onEditTime: () => _editTime(context, i),
              onEditColor: () => _editColor(context, i),
              onRemove: () => _remove(i),
            ),
          ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _add,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.add, size: 18, color: AppColors.accent),
                const SizedBox(width: 6),
                Text(
                  s.addColorStop,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            s.dynamicColorsHint,
            style: TextStyle(fontSize: 13, color: labelColor),
          ),
        ),
      ],
    );
  }
}

/// A day-long gradient strip with tick marks at 0/6/12/18/24h and a dot for
/// each color stop's position.
class _GradientPreview extends StatelessWidget {
  const _GradientPreview({required this.timeline});

  final DynamicColorTimeline timeline;

  @override
  Widget build(BuildContext context) {
    // Sample the timeline every 30 minutes for a smooth gradient that also
    // reflects the wrap-around behavior at the day boundaries.
    final samples = <Color>[];
    for (var m = 0; m <= 1440; m += 30) {
      samples.add(timeline.colorAt(m.clamp(0, 1439)));
    }
    final tickColor = CupertinoColors.tertiaryLabel.resolveFrom(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          return SizedBox(
            height: 44,
            width: w,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(colors: samples),
                    border: Border.all(
                      color: CupertinoColors.separator.resolveFrom(context),
                    ),
                  ),
                ),
                for (final stop in timeline.stops)
                  Positioned(
                    left: (stop.minute / 1440 * w - 6).clamp(0.0, w - 12),
                    top: 14,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: stop.color,
                        border:
                            Border.all(color: CupertinoColors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Color(0x40000000), blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final label in const ['00', '06', '12', '18', '24'])
              Text(label, style: TextStyle(fontSize: 10, color: tickColor)),
          ],
        ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.time,
    required this.color,
    required this.canRemove,
    required this.onEditTime,
    required this.onEditColor,
    required this.onRemove,
  });

  final String time;
  final Color color;
  final bool canRemove;
  final VoidCallback onEditTime;
  final VoidCallback onEditColor;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.tertiarySystemBackground.resolveFrom(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onEditColor,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onEditTime,
            child: Row(
              children: [
                Icon(CupertinoIcons.clock,
                    size: 16,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                const SizedBox(width: 5),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 17,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 32,
            onPressed: canRemove ? onRemove : null,
            child: Icon(
              CupertinoIcons.minus_circle,
              size: 22,
              color: canRemove
                  ? CupertinoColors.systemRed.resolveFrom(context)
                  : CupertinoColors.quaternaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a time-of-day picker (hour:minute) and returns the chosen minute of
/// the day, or null if cancelled.
Future<int?> _pickTime(BuildContext context, int initialMinute) {
  final s = S.of(context);
  var selected = initialMinute;
  final now = DateTime.now();
  var initial = DateTime(now.year, now.month, now.day,
      initialMinute ~/ 60, initialMinute % 60);
  return showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    backgroundColor: const Color(0x00000000),
    builder: (ctx) {
      final bg = CupertinoColors.systemBackground.resolveFrom(ctx);
      return Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(s.cancel),
                ),
                Text(s.timeLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                CupertinoButton(
                  onPressed: () => Navigator.of(ctx).pop(selected),
                  child: Text(s.done),
                ),
              ],
            ),
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: initial,
                onDateTimeChanged: (dt) {
                  selected = dt.hour * 60 + dt.minute;
                  initial = dt;
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
