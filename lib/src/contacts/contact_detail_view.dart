import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/contact.dart';
import '../theme/app_theme.dart';
import '../utils/reminder_picker.dart';
import 'contact_controller.dart';

class ContactDetailView extends StatefulWidget {
  const ContactDetailView({
    super.key,
    required this.contact,
    required this.controller,
  });

  static const routeName = 'contact_detail';

  final Contact contact;
  final ContactController controller;

  @override
  State<ContactDetailView> createState() => _ContactDetailViewState();
}

class _ContactDetailViewState extends State<ContactDetailView> {
  late final TextEditingController _name;
  late final TextEditingController _note;
  late int _birthMonth;
  late int _birthDay;
  late int? _birthYear;
  late bool _isCompletable;
  late List<int> _reminderOffsets;
  Timer? _autosaveTimer;
  final bool _deleted = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.contact.name);
    _note = TextEditingController(text: widget.contact.note ?? '');
    _birthMonth = widget.contact.birthMonth;
    _birthDay = widget.contact.birthDay;
    _birthYear = widget.contact.birthYear;
    _isCompletable = widget.contact.isCompletable;
    _reminderOffsets = List.of(widget.contact.reminderOffsets);
    _name.addListener(_scheduleAutosave);
    _note.addListener(_scheduleAutosave);
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _save();
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 3), _save);
  }

  void _save() {
    if (_deleted) return;
    final name = _name.text.trim();
    if (name.isEmpty) return;
    widget.controller.updateContact(widget.contact.copyWith(
      name: name,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      clearNote: _note.text.trim().isEmpty,
      birthMonth: _birthMonth,
      birthDay: _birthDay,
      birthYear: _birthYear,
      clearBirthYear: _birthYear == null,
      isCompletable: _isCompletable,
      reminderOffsets: _reminderOffsets,
    ));
  }

  Future<void> _pickDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final initial = DateTime(_birthYear ?? 2000, _birthMonth, _birthDay);
    DateTime temp = initial;
    final picked = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (ctx) => Container(
        height: 320,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(S.of(ctx).cancel),
                    ),
                    CupertinoButton(
                      onPressed: () => Navigator.of(ctx).pop(temp),
                      child: Text(S.of(ctx).done),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initial,
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (d) => temp = d,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _birthMonth = picked.month;
        _birthDay = picked.day;
        if (_birthYear != null) _birthYear = picked.year;
      });
      _save();
    }
  }

  Future<void> _pickReminders() async {
    final result =
        await showReminderPicker(context, _reminderOffsets);
    if (!mounted || result == null) return;
    setState(() => _reminderOffsets = result);
    _save();
  }

  String _formatBirth() {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final base = '${months[_birthMonth - 1]} $_birthDay';
    return _birthYear != null ? '$base, $_birthYear' : base;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bg = CupertinoColors.tertiarySystemFill.resolveFrom(context);
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(border: null),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2D55).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.gift_fill,
                        size: 16, color: Color(0xFFFF2D55)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoTextField(
                    controller: _name,
                    placeholder: s.birthdayName,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w600),
                    decoration: const BoxDecoration(),
                    maxLines: null,
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.gift,
                        size: 18, color: Color(0xFFFF2D55)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(s.birthDate,
                          style: const TextStyle(fontSize: 15)),
                    ),
                    Text(
                      _formatBirth(),
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(s.includeYear,
                        style: const TextStyle(fontSize: 15)),
                  ),
                  CupertinoSwitch(
                    value: _birthYear != null,
                    activeColor: AppColors.accent,
                    onChanged: (v) {
                      setState(() {
                        _birthYear = v ? DateTime.now().year : null;
                      });
                      _save();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(s.completable,
                        style: const TextStyle(fontSize: 15)),
                  ),
                  CupertinoSwitch(
                    value: _isCompletable,
                    activeColor: AppColors.accent,
                    onChanged: (v) {
                      setState(() => _isCompletable = v);
                      _save();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickReminders,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.bell,
                        size: 18,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(s.reminders,
                          style: const TextStyle(fontSize: 15)),
                    ),
                    Text(
                      _reminderOffsets.isEmpty ? '—' : '${_reminderOffsets.length}',
                      style: TextStyle(
                        fontSize: 15,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: _note,
              placeholder: s.note,
              maxLines: null,
              minLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ],
        ),
      ),
    );
  }
}
