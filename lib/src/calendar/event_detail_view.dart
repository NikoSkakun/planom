import 'package:flutter/cupertino.dart';

import '../models/event.dart';
import '../tasks/calendar_date_picker.dart';
import '../theme/app_theme.dart';
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
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.event.title);
    _note = TextEditingController(text: widget.event.note ?? '');
    _date = widget.event.date;
    _doTime = widget.event.doTime;
    _duration = widget.event.duration;
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
    final result = await showCupertinoModalPopup<int?>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Duration'),
        actions: [
          for (final m in const [15, 30, 45, 60, 90, 120, 180, 240])
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(m),
              child: Text(_dur(m)),
            ),
          if (_duration != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(ctx).pop(-1),
              child: const Text('Clear'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _duration = result == -1 ? null : result);
  }

  Future<void> _delete() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Event?'),
        content: const Text('This event will be permanently removed.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
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
              placeholder: 'Event name',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600),
              decoration: const BoxDecoration(),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _note,
              placeholder: 'Note',
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
                  const Icon(CupertinoIcons.calendar,
                      size: 18, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Text(
                    formatTaskDate(_date, doTime: _doTime),
                    style: const TextStyle(
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
                    _duration != null ? _dur(_duration!) : 'No duration',
                    style: TextStyle(
                      fontSize: 15,
                      color:
                          _duration != null ? AppColors.accent : secondary,
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

String _dur(int m) {
  if (m < 60) return '${m}m';
  final h = m ~/ 60;
  final r = m % 60;
  if (r == 0) return '${h}h';
  return '${h}h ${r}m';
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
