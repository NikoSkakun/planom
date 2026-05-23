import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../theme/app_theme.dart';
import 'selection_menu.dart';

/// Shows the reminder management UI and returns the updated list of offsets.
/// Returns null if the user cancelled (no change).
Future<List<int>?> showReminderPicker(
  BuildContext context,
  List<int> current,
) async {
  List<int> working = List.of(current);
  bool confirmed = false;

  await showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => _ReminderPickerSheet(
      initialOffsets: working,
      onConfirm: (offsets) {
        working = offsets;
        confirmed = true;
        Navigator.of(ctx).pop();
      },
      onCancel: () => Navigator.of(ctx).pop(),
    ),
  );

  return confirmed ? working : null;
}

class _ReminderPickerSheet extends StatefulWidget {
  const _ReminderPickerSheet({
    required this.initialOffsets,
    required this.onConfirm,
    required this.onCancel,
  });

  final List<int> initialOffsets;
  final ValueChanged<List<int>> onConfirm;
  final VoidCallback onCancel;

  @override
  State<_ReminderPickerSheet> createState() => _ReminderPickerSheetState();
}

class _ReminderPickerSheetState extends State<_ReminderPickerSheet> {
  late List<int> _offsets;

  @override
  void initState() {
    super.initState();
    _offsets = List.of(widget.initialOffsets);
  }

  void _toggle(int offset) {
    setState(() {
      if (_offsets.contains(offset)) {
        _offsets.remove(offset);
      } else {
        _offsets.add(offset);
        _offsets.sort();
      }
    });
  }

  Future<void> _addCustom(bool before) async {
    final minutes = await _showCustomMinutesPicker(context);
    if (minutes == null || minutes <= 0) return;
    final offset = before ? -minutes : minutes;
    setState(() {
      if (!_offsets.contains(offset)) {
        _offsets.add(offset);
        _offsets.sort();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final separator =
        CupertinoColors.separator.resolveFrom(context);

    final presets = _buildPresets(s);

    return Container(
      color: bg,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // header
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: separator, width: 0.5))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: widget.onCancel,
                    child: Text(s.cancel),
                  ),
                  Text(s.reminders,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                  CupertinoButton(
                    onPressed: () => widget.onConfirm(_offsets),
                    child: Text(s.done,
                        style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: presets.length,
                separatorBuilder: (_, __) => Container(
                    height: 0.5,
                    color: CupertinoColors.separator.resolveFrom(context)),
                itemBuilder: (ctx, i) {
                  final p = presets[i];
                  if (p.isSection) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(p.label,
                          style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                              fontWeight: FontWeight.w500)),
                    );
                  }
                  if (p.isCustomBefore) {
                    return _OptionRow(
                      label: s.reminderCustomBefore,
                      icon: CupertinoIcons.plus_circle,
                      onTap: () => _addCustom(true),
                    );
                  }
                  if (p.isCustomAfter) {
                    return _OptionRow(
                      label: s.reminderCustomAfter,
                      icon: CupertinoIcons.plus_circle,
                      onTap: () => _addCustom(false),
                    );
                  }
                  final checked = _offsets.contains(p.offset);
                  return _OptionRow(
                    label: p.label,
                    checked: checked,
                    onTap: () => _toggle(p.offset!),
                  );
                },
              ),
            ),
            if (_offsets.isNotEmpty) ...[
              Container(
                  height: 0.5,
                  color: CupertinoColors.separator.resolveFrom(context)),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Selected',
                        style: TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context)),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _offsets.map((o) {
                        return GestureDetector(
                          onTap: () => _toggle(o),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.accent.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_offsetLabel(o),
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.accent)),
                                const SizedBox(width: 4),
                                Icon(CupertinoIcons.xmark,
                                    size: 11, color: AppColors.accent),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_Preset> _buildPresets(S s) {
    return [
      _Preset.section('Before'),
      _Preset(offset: 0, label: s.reminderAtTime),
      _Preset(offset: -5, label: s.reminder5MinBefore),
      _Preset(offset: -10, label: s.reminder10MinBefore),
      _Preset(offset: -15, label: s.reminder15MinBefore),
      _Preset(offset: -30, label: s.reminder30MinBefore),
      _Preset(offset: -60, label: s.reminder1HBefore),
      _Preset(offset: -120, label: s.reminder2HBefore),
      _Preset(offset: -1440, label: s.reminder1DBefore),
      _Preset.customBefore(),
      _Preset.section('After'),
      _Preset(offset: 60, label: s.reminder1HAfter),
      _Preset(offset: 1440, label: s.reminder1DAfter),
      _Preset.customAfter(),
    ];
  }
}

class _Preset {
  final int? offset;
  final String label;
  final bool isSection;
  final bool isCustomBefore;
  final bool isCustomAfter;

  const _Preset({required this.offset, required this.label})
      : isSection = false,
        isCustomBefore = false,
        isCustomAfter = false;

  const _Preset.section(this.label)
      : offset = null,
        isSection = true,
        isCustomBefore = false,
        isCustomAfter = false;

  const _Preset.customBefore()
      : offset = null,
        label = '',
        isSection = false,
        isCustomBefore = true,
        isCustomAfter = false;

  const _Preset.customAfter()
      : offset = null,
        label = '',
        isSection = false,
        isCustomBefore = false,
        isCustomAfter = true;
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    this.checked,
    this.icon,
    required this.onTap,
  });

  final String label;
  final bool? checked;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 16)),
            ),
            if (icon != null)
              Icon(icon, size: 18,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context))
            else if (checked == true)
              Icon(CupertinoIcons.checkmark,
                  size: 18, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

// ── Custom minutes picker ─────────────────────────────────────────────────────

Future<int?> _showCustomMinutesPicker(BuildContext context) async {
  Duration selected = const Duration(minutes: 30);
  final confirmed = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (ctx) {
      final bg = CupertinoColors.systemBackground.resolveFrom(ctx);
      final sep = CupertinoColors.separator.resolveFrom(ctx);
      return Container(
        height: 320,
        color: bg,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: sep, width: 0.5))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(S.of(ctx).cancel),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(S.of(ctx).ok,
                        style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.hm,
                initialTimerDuration: selected,
                onTimerDurationChanged: (d) => selected = d,
              ),
            ),
          ],
        ),
      );
    },
  );
  if (confirmed != true) return null;
  return selected.inMinutes > 0 ? selected.inMinutes : null;
}

// ── Offset label helper ───────────────────────────────────────────────────────

String _offsetLabel(int offset) {
  if (offset == 0) return 'At time';
  if (offset < 0) {
    final abs = -offset;
    if (abs < 60) return '${abs}m before';
    if (abs < 1440) {
      final h = abs ~/ 60;
      final m = abs % 60;
      return m == 0 ? '${h}h before' : '${h}h ${m}m before';
    }
    final d = abs ~/ 1440;
    return '${d}d before';
  } else {
    if (offset < 60) return '${offset}m after';
    if (offset < 1440) {
      final h = offset ~/ 60;
      final m = offset % 60;
      return m == 0 ? '${h}h after' : '${h}h ${m}m after';
    }
    final d = offset ~/ 1440;
    return '${d}d after';
  }
}

/// Public helper to format a list of offsets as a summary string.
String formatReminderOffsets(List<int> offsets, S s) {
  if (offsets.isEmpty) return s.noReminders;
  if (offsets.length == 1) return _offsetLabel(offsets[0]);
  return '${offsets.length} reminders';
}
