import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

import '../integrations/apple/device_calendar_controller.dart';
import '../integrations/apple/device_event.dart';
import '../integrations/google/google_calendar_controller.dart';
import '../integrations/google/remote_event.dart';
import '../localization/strings.dart';
import '../models/event.dart';
import '../models/recurrence.dart';
import '../tasks/calendar_date_picker.dart';
import '../tasks/recurrence_picker.dart';
import '../theme/app_theme.dart';
import '../utils/duration_picker.dart';
import '../utils/selection_menu.dart';
import 'event_controller.dart';

/// Sentinel calendar id used by the creation sheet to mean "save as a local
/// Planom event" (i.e. not a Google or Apple calendar).
const String kLocalCalendarId = '__planom_local__';

/// Prefix marking a device (Apple Calendar) target in the picker, so its ids
/// can't collide with Google calendar keys.
const String _kDevicePrefix = 'ek:';

void showEventCreationSheet(
  BuildContext context,
  EventController controller, {
  required DateTime initialDate,
  GoogleCalendarController? googleCalendarController,
  DeviceCalendarController? deviceCalendarController,
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
      deviceCalendarController: deviceCalendarController,
    ),
  );
}

class EventCreationSheet extends StatefulWidget {
  const EventCreationSheet({
    super.key,
    required this.controller,
    required this.initialDate,
    this.googleCalendarController,
    this.deviceCalendarController,
  });

  final EventController controller;
  final DateTime initialDate;
  final GoogleCalendarController? googleCalendarController;
  final DeviceCalendarController? deviceCalendarController;

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
  Recurrence? _recurrence;
  bool _titleEmpty = true;

  /// The Google calendar new events go to; null means not a Google target.
  GoogleCalendarMeta? _targetCal;

  /// The Apple (device) calendar new events go to; null means not a device
  /// target. At most one of [_targetCal] / [_targetDeviceCal] is non-null;
  /// both null means save as a local Planom event.
  DeviceCalendarMeta? _targetDeviceCal;

  @override
  void initState() {
    super.initState();
    _date = DateTime(
        widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
    // Default to the user's chosen Google default calendar when they're
    // connected and it's writable + selected; otherwise fall back to the
    // device default calendar; otherwise create locally.
    final gc = widget.googleCalendarController;
    if (gc != null && gc.isConnected) {
      final def = gc.defaultCalendar;
      if (def != null &&
          gc.writableSelectedCalendars.any((c) => c.key == def.key)) {
        _targetCal = def;
      }
    }
    if (_targetCal == null) {
      final ek = widget.deviceCalendarController;
      if (ek != null && ek.isAuthorized) {
        final def = ek.defaultCalendar;
        if (def != null &&
            ek.writableSelectedCalendars.any((c) => c.id == def.id)) {
          _targetDeviceCal = def;
        }
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
    final deviceTarget = _targetDeviceCal;
    if (target != null && widget.googleCalendarController != null) {
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
    } else if (deviceTarget != null &&
        widget.deviceCalendarController != null) {
      // Goes directly to the device's Apple Calendar. Same no-duplication
      // invariant as Google — never written to the local `events` table.
      await widget.deviceCalendarController!.createEvent(
        DeviceEventDraft(
          title: title,
          note: note,
          date: _date,
          doTime: _doTime,
          duration: _duration,
        ),
        calendarId: deviceTarget.id,
      );
    } else {
      await widget.controller.addEvent(Event(
        title: title,
        note: note,
        date: _date,
        doTime: _doTime,
        duration: _duration,
        recurrence: _recurrence?.toJson(),
      ));
    }
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  List<GoogleCalendarMeta> get _googleWritable {
    final gc = widget.googleCalendarController;
    return (gc != null && gc.isConnected)
        ? gc.writableSelectedCalendars
        : const [];
  }

  List<DeviceCalendarMeta> get _deviceWritable {
    final ek = widget.deviceCalendarController;
    return (ek != null && ek.isAuthorized)
        ? ek.writableSelectedCalendars
        : const [];
  }

  /// True when there's any non-local target the user could pick.
  bool get _hasCalendarChoices =>
      _googleWritable.isNotEmpty || _deviceWritable.isNotEmpty;

  Future<void> _pickCalendar() async {
    final s = S.of(context);
    final gc = widget.googleCalendarController;
    final options = <SelectionMenuOption<String>>[
      SelectionMenuOption(value: kLocalCalendarId, label: s.planomLocal),
      for (final cal in _googleWritable)
        SelectionMenuOption(value: cal.key, label: _calLabel(gc!, cal)),
      for (final cal in _deviceWritable)
        SelectionMenuOption(
            value: '$_kDevicePrefix${cal.id}', label: cal.title),
    ];
    if (options.length == 1) return;
    final current = _targetCal?.key ??
        (_targetDeviceCal != null
            ? '$_kDevicePrefix${_targetDeviceCal!.id}'
            : kLocalCalendarId);
    final saved = _activeFocus;
    FocusManager.instance.primaryFocus?.unfocus();
    final pick = await showSelectionMenu<String>(
      context: context,
      title: s.eventCalendar,
      current: current,
      options: options,
    );
    if (!mounted) return;
    if (pick != null) {
      setState(() {
        if (pick == kLocalCalendarId) {
          _targetCal = null;
          _targetDeviceCal = null;
        } else if (pick.startsWith(_kDevicePrefix)) {
          final id = pick.substring(_kDevicePrefix.length);
          final m = _deviceWritable.where((c) => c.id == id).toList();
          _targetDeviceCal = m.isEmpty ? null : m.first;
          _targetCal = null;
        } else {
          final m = _googleWritable.where((c) => c.key == pick).toList();
          _targetCal = m.isEmpty ? null : m.first;
          _targetDeviceCal = null;
        }
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
    if (_targetCal != null && gc != null) return _calLabel(gc, _targetCal!);
    if (_targetDeviceCal != null) return _targetDeviceCal!.title;
    return s.planomLocal;
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

  Future<void> _pickRecurrence() async {
    final saved = _activeFocus;
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await showRecurrencePicker(context, _recurrence);
    if (!mounted) return;
    if (result != null) setState(() => _recurrence = result.value);
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
          // Optional calendar picker — meaningful when a Google account or the
          // device's Apple Calendar offers at least one writable, selected
          // calendar.
          if (_hasCalendarChoices) ...[
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
          // Repeat row — its own line so long date/duration labels never crowd
          // it. Reuses the task recurrence picker + formatter.
          GestureDetector(
            onTap: _pickRecurrence,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.repeat,
                    size: 16,
                    color: _recurrence != null ? AppColors.accent : secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _recurrence != null
                        ? formatRecurrence(context, _recurrence)
                        : s.repeat,
                    style: TextStyle(
                      fontSize: 14,
                      color: _recurrence != null ? AppColors.accent : secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
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

