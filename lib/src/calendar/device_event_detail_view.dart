import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show listEquals;

import '../integrations/apple/device_calendar_controller.dart';
import '../integrations/apple/device_event.dart';
import '../localization/strings.dart';
import '../tasks/calendar_date_picker.dart';
import '../theme/app_theme.dart';
import '../utils/duration_picker.dart';
import '../utils/reminder_picker.dart';

/// Detail / edit screen for a single Apple Calendar (EventKit) event. Edits are
/// pushed to the device calendar immediately on save; the event never lands in
/// Planom's local `events` table. Mirrors `RemoteEventDetailView`.
class DeviceEventDetailView extends StatefulWidget {
  const DeviceEventDetailView({
    super.key,
    required this.event,
    required this.controller,
  });

  final DeviceEvent event;
  final DeviceCalendarController controller;

  @override
  State<DeviceEventDetailView> createState() => _DeviceEventDetailViewState();
}

class _DeviceEventDetailViewState extends State<DeviceEventDetailView> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late DateTime _date;
  late int? _doTime;
  late int? _duration;
  late List<int> _reminderOffsets;
  late final List<int> _initialReminders;
  bool _saving = false;
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.event.title);
    _note = TextEditingController(text: widget.event.note ?? '');
    _date = widget.event.date;
    _doTime = widget.event.doTime;
    _duration = widget.event.duration;
    _initialReminders = widget.controller.remindersForEvent(widget.event);
    _reminderOffsets = List.of(_initialReminders);
  }

  @override
  void dispose() {
    if (!_deleted) {
      // Push edits to the device calendar (writable events only) — fire and
      // forget, save on pop.
      if (!widget.event.isReadOnly) {
        final title = _title.text.trim();
        if (title.isNotEmpty && _hasChanges(title)) {
          widget.controller.updateEvent(widget.event.copyWith(
            title: title,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            clearNote: _note.text.trim().isEmpty,
            date: _date,
            doTime: _doTime,
            clearDoTime: _doTime == null,
            duration: _duration,
            clearDuration: _duration == null,
          ));
        }
      }
      // Planom-only reminders apply even to read-only calendars — they live on
      // the device, never in EventKit's own alarms.
      if (!listEquals(_reminderOffsets, _initialReminders)) {
        widget.controller.setEventReminders(
          widget.event.copyWith(
            date: _date,
            doTime: _doTime,
            clearDoTime: _doTime == null,
          ),
          _reminderOffsets,
        );
      }
    }
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  bool _hasChanges(String title) {
    final e = widget.event;
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    return title != e.title ||
        note != e.note ||
        _date != e.date ||
        _doTime != e.doTime ||
        _duration != e.duration;
  }

  Future<void> _pickDate() async {
    if (widget.event.isReadOnly) return;
    final result = await showCalendarDatePicker(
      context,
      initial: _date,
      initialDoTime: _doTime,
    );
    if (!mounted || result == null) return;
    setState(() {
      _date = result.$1 ?? _date;
      _doTime = result.$2;
    });
  }

  Future<void> _pickDuration() async {
    if (widget.event.isReadOnly) return;
    final result = await showDurationPicker(context, _duration);
    if (!mounted) return;
    setState(() => _duration = result);
  }

  Future<void> _pickReminders() async {
    final result = await showReminderPicker(context, _reminderOffsets);
    if (!mounted || result == null) return;
    setState(() => _reminderOffsets = result);
  }

  Future<void> _delete() async {
    final s = S.of(context);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.deleteEventQuestion),
        content: Text(s.deviceCalendarDeleteBody),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.delete),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    final ok = await widget.controller.deleteEvent(widget.event);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _deleted = ok;
    });
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final ev = widget.event;
    final readOnly = ev.isReadOnly;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!readOnly)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _saving ? null : _delete,
                child: const Icon(CupertinoIcons.trash,
                    size: 22, color: CupertinoColors.destructiveRed),
              ),
          ],
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            _SourceChip(
              color: Color(ev.calendarColor),
              text: '${s.appleCalendar} · ${ev.calendarName}'
                  '${readOnly ? ' · ${s.appleCalendarReadOnly}' : ''}',
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _title,
              placeholder: s.eventName,
              readOnly: readOnly,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              decoration: const BoxDecoration(),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _note,
              placeholder: s.note,
              readOnly: readOnly,
              style: const TextStyle(fontSize: 15),
              decoration: const BoxDecoration(),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            _SectionCard(
              onTap: readOnly ? null : _pickDate,
              child: Row(
                children: [
                  Icon(CupertinoIcons.calendar,
                      size: 18,
                      color: readOnly ? secondary : AppColors.accent),
                  const SizedBox(width: 10),
                  Text(
                    formatTaskDate(context, _date, doTime: _doTime),
                    style: TextStyle(
                        fontSize: 15,
                        color: readOnly ? secondary : AppColors.accent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              onTap: readOnly ? null : _pickDuration,
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.timer,
                    size: 18,
                    color: _duration != null && !readOnly
                        ? AppColors.accent
                        : secondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _duration != null
                        ? formatDuration(_duration!)
                        : s.noDuration,
                    style: TextStyle(
                      fontSize: 15,
                      color: _duration != null && !readOnly
                          ? AppColors.accent
                          : secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              onTap: _pickReminders,
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.bell,
                    size: 18,
                    color: _reminderOffsets.isNotEmpty
                        ? AppColors.accent
                        : secondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    formatReminderOffsets(_reminderOffsets, s),
                    style: TextStyle(
                      fontSize: 15,
                      color: _reminderOffsets.isNotEmpty
                          ? AppColors.accent
                          : secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                s.deviceCalendarReminderHint,
                style: TextStyle(fontSize: 13, color: secondary),
              ),
            ),
            if (readOnly) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  s.appleCalendarReadOnlyHint,
                  style: TextStyle(fontSize: 13, color: secondary),
                ),
              ),
            ],
            if (_saving) ...[
              const SizedBox(height: 16),
              const Center(child: CupertinoActivityIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      ),
    );
  }
}
