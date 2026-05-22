import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

import '../localization/strings.dart';
import '../models/event.dart';
import '../tasks/calendar_date_picker.dart';
import '../theme/app_theme.dart';
import '../utils/selection_menu.dart';
import 'event_controller.dart';

void showEventCreationSheet(
  BuildContext context,
  EventController controller, {
  required DateTime initialDate,
}) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => EventCreationSheet(
      controller: controller,
      initialDate: initialDate,
    ),
  );
}

class EventCreationSheet extends StatefulWidget {
  const EventCreationSheet({
    super.key,
    required this.controller,
    required this.initialDate,
  });

  final EventController controller;
  final DateTime initialDate;

  @override
  State<EventCreationSheet> createState() => _EventCreationSheetState();
}

class _EventCreationSheetState extends State<EventCreationSheet> {
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _titleFocus = FocusNode();
  final _noteFocus = FocusNode();
  FocusNode? _activeFocus;
  late DateTime _date;
  int? _doTime;
  int? _duration; // minutes
  bool _titleEmpty = true;

  @override
  void initState() {
    super.initState();
    _date = DateTime(
        widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
    _titleCtrl.addListener(() {
      final empty = _titleCtrl.text.trim().isEmpty;
      if (empty != _titleEmpty) setState(() => _titleEmpty = empty);
    });
    _titleFocus.addListener(_onFocusChange);
    _noteFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_titleFocus.hasFocus) _activeFocus = _titleFocus;
    if (_noteFocus.hasFocus) _activeFocus = _noteFocus;
  }

  @override
  void dispose() {
    _titleFocus.removeListener(_onFocusChange);
    _noteFocus.removeListener(_onFocusChange);
    _titleFocus.dispose();
    _noteFocus.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    await widget.controller.addEvent(Event(
      title: title,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      date: _date,
      doTime: _doTime,
      duration: _duration,
    ));
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
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
    final saved = _activeFocus;
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await _showDurationPicker(context, _duration);
    if (!mounted) return;
    setState(() => _duration = result);
    saved?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: CupertinoColors.separator.resolveFrom(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          CupertinoTextField(
            controller: _titleCtrl,
            focusNode: _titleFocus,
            placeholder: s.eventName,
            autofocus: true,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            style:
                const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            decoration: const BoxDecoration(),
          ),
          Container(
              height: 0.5,
              color: CupertinoColors.separator.resolveFrom(context)),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _noteCtrl,
            focusNode: _noteFocus,
            placeholder: s.note,
            style: const TextStyle(fontSize: 15),
            decoration: const BoxDecoration(),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: _pickDate,
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.calendar,
                            size: 16, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Text(
                          formatTaskDate(context, _date, doTime: _doTime),
                          style: TextStyle(
                              fontSize: 14, color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: _pickDuration,
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.timer,
                          size: 16,
                          color:
                              _duration != null ? AppColors.accent : secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _duration != null
                              ? _formatDuration(_duration!)
                              : s.duration,
                          style: TextStyle(
                            fontSize: 14,
                            color: _duration != null
                                ? AppColors.accent
                                : secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
                color: _titleEmpty
                    ? CupertinoColors.tertiarySystemFill.resolveFrom(context)
                    : AppColors.accent,
                borderRadius: BorderRadius.circular(22),
                onPressed: _titleEmpty ? null : _submit,
                child: Text(
                  s.add,
                  style: TextStyle(
                    color: _titleEmpty
                        ? CupertinoColors.tertiaryLabel.resolveFrom(context)
                        : CupertinoColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDuration(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

Future<int?> _showDurationPicker(BuildContext context, int? current) async {
  const presets = [15, 30, 45, 60, 90, 120, 180, 240];
  final s = S.of(context);
  final result = await showSelectionMenu<int>(
    context: context,
    title: s.duration,
    current: current,
    options: [
      for (final m in presets)
        SelectionMenuOption(value: m, label: _formatDuration(m)),
      if (current != null)
        SelectionMenuOption(value: -1, label: s.clear, isDestructive: true),
    ],
  );
  if (result == null) return current;
  if (result == -1) return null;
  return result;
}
