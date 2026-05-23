import 'package:flutter/cupertino.dart';

import '../models/event.dart';
import '../localization/strings.dart';
import '../tasks/calendar_date_picker.dart';
import '../theme/app_theme.dart';
import '../utils/duration_picker.dart';
import '../utils/reminder_picker.dart';
import 'event_controller.dart';

class EventDetailView extends StatefulWidget {
  const EventDetailView({
    super.key,
    required this.event,
    required this.controller,
  });

  final Event event;
  final EventController controller;

  @override
  State<EventDetailView> createState() => _EventDetailViewState();
}

class _EventDetailViewState extends State<EventDetailView> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late DateTime _date;
  late int? _doTime;
  late int? _duration;
  late List<int> _reminderOffsets;
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.event.title);
    _note = TextEditingController(text: widget.event.note ?? '');
    _date = widget.event.date;
    _doTime = widget.event.doTime;
    _duration = widget.event.duration;
    _reminderOffsets = List.of(widget.event.reminderOffsets);
  }

  @override
  void dispose() {
    if (!_deleted) {
      final title = _title.text.trim();
      if (title.isNotEmpty) {
        widget.controller.updateEvent(widget.event.copyWith(
          title: title,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          clearNote: _note.text.trim().isEmpty,
          date: _date,
          doTime: _doTime,
          clearDoTime: _doTime == null,
          duration: _duration,
          clearDuration: _duration == null,
          reminderOffsets: _reminderOffsets,
        ));
      }
    }
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
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
        content: Text(s.deleteEventBody),
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
    _deleted = true;
    await widget.controller.deleteEvent(widget.event.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _delete,
          child: const Icon(CupertinoIcons.trash,
              size: 22, color: CupertinoColors.destructiveRed),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            CupertinoTextField(
              controller: _title,
              placeholder: s.eventName,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600),
              decoration: const BoxDecoration(),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _note,
              placeholder: s.note,
              style: const TextStyle(fontSize: 15),
              decoration: const BoxDecoration(),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            _SectionCard(
              onTap: _pickDate,
              child: Row(
                children: [
                  Icon(CupertinoIcons.calendar,
                      size: 18, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Text(
                    formatTaskDate(context, _date, doTime: _doTime),
                    style: TextStyle(
                        fontSize: 15, color: AppColors.accent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              onTap: _pickDuration,
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.timer,
                    size: 18,
                    color:
                        _duration != null ? AppColors.accent : secondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _duration != null
                        ? formatDuration(_duration!)
                        : s.noDuration,
                    style: TextStyle(
                      fontSize: 15,
                      color:
                          _duration != null ? AppColors.accent : secondary,
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
          ],
        ),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      ),
    );
  }
}
