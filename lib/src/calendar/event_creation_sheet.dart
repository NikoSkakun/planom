import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

import '../integrations/google/google_calendar_controller.dart';
import '../integrations/google/remote_event.dart';
import '../localization/strings.dart';
import '../models/event.dart';
import '../tasks/calendar_date_picker.dart';
import '../theme/app_theme.dart';
import '../utils/duration_picker.dart';
import '../utils/selection_menu.dart';
import 'event_controller.dart';

/// Sentinel calendar id used by the creation sheet to mean "save as a local
/// Planom event" (i.e. not a Google calendar).
const String kLocalCalendarId = '__planom_local__';

void showEventCreationSheet(
  BuildContext context,
  EventController controller, {
  required DateTime initialDate,
  GoogleCalendarController? googleCalendarController,
}) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => EventCreationSheet(
      controller: controller,
      initialDate: initialDate,
      googleCalendarController: googleCalendarController,
    ),
  );
}

class EventCreationSheet extends StatefulWidget {
  const EventCreationSheet({
    super.key,
    required this.controller,
    required this.initialDate,
    this.googleCalendarController,
  });

  final EventController controller;
  final DateTime initialDate;
  final GoogleCalendarController? googleCalendarController;

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

  /// The Google calendar new events go to; null means save as a local Planom
  /// event.
  GoogleCalendarMeta? _targetCal;

  @override
  void initState() {
    super.initState();
    _date = DateTime(
        widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
    // Default to the user's chosen Google default calendar when they're
    // connected and it's writable + selected; otherwise create locally.
    final gc = widget.googleCalendarController;
    if (gc != null && gc.isConnected) {
      final def = gc.defaultCalendar;
      if (def != null &&
          gc.writableSelectedCalendars.any((c) => c.key == def.key)) {
        _targetCal = def;
      }
    }
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
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();

    final target = _targetCal;
    if (target == null || widget.googleCalendarController == null) {
      await widget.controller.addEvent(Event(
        title: title,
        note: note,
        date: _date,
        doTime: _doTime,
        duration: _duration,
      ));
    } else {
      // Goes directly to Google. No local Event is created — source of truth
      // lives in Google and the calendar view picks it up from the next
      // controller refresh (which createEvent triggers in-memory immediately).
      await widget.googleCalendarController!.createEvent(
        RemoteEventDraft(
          title: title,
          note: note,
          date: _date,
          doTime: _doTime,
          duration: _duration,
        ),
        accountId: target.accountId,
        calendarId: target.id,
      );
    }
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _pickCalendar() async {
    final s = S.of(context);
    final gc = widget.googleCalendarController;
    final writable =
        (gc != null && gc.isConnected) ? gc.writableSelectedCalendars : const [];
    final options = <SelectionMenuOption<String>>[
      SelectionMenuOption(value: kLocalCalendarId, label: s.planomLocal),
      for (final cal in writable)
        SelectionMenuOption(value: cal.key, label: _calLabel(gc!, cal)),
    ];
    if (options.length == 1) return;
    final saved = _activeFocus;
    FocusManager.instance.primaryFocus?.unfocus();
    final pick = await showSelectionMenu<String>(
      context: context,
      title: s.eventCalendar,
      current: _targetCal?.key ?? kLocalCalendarId,
      options: options,
    );
    if (!mounted) return;
    if (pick != null) {
      final matches =
          gc == null ? const <GoogleCalendarMeta>[] : gc.writableSelectedCalendars
              .where((c) => c.key == pick)
              .toList();
      setState(() {
        _targetCal =
            (pick == kLocalCalendarId || matches.isEmpty) ? null : matches.first;
      });
    }
    saved?.requestFocus();
  }

  /// Disambiguates calendars across accounts: shows the account email when
  /// more than one account is connected.
  String _calLabel(GoogleCalendarController gc, GoogleCalendarMeta cal) {
    if (gc.accountCount <= 1) return cal.summary;
    return '${cal.summary} · ${cal.accountId}';
  }

  String _calendarLabel(S s) {
    final gc = widget.googleCalendarController;
    final target = _targetCal;
    if (gc == null || target == null) return s.planomLocal;
    return _calLabel(gc, target);
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
    final result = await showDurationPicker(context, _duration);
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
          // Optional calendar picker — only meaningful when a Google account
          // is connected with at least one writable, selected calendar.
          if (widget.googleCalendarController != null &&
              widget.googleCalendarController!.isConnected &&
              widget.googleCalendarController!.writableSelectedCalendars
                  .isNotEmpty) ...[
            GestureDetector(
              onTap: _pickCalendar,
              child: Row(
                children: [
                  Icon(CupertinoIcons.tray,
                      size: 16, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text(
                    _calendarLabel(s),
                    style:
                        TextStyle(fontSize: 14, color: AppColors.accent),
                  ),
                  Icon(CupertinoIcons.chevron_down,
                      size: 12, color: AppColors.accent),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
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
                              ? formatDuration(_duration!)
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

