import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

import '../localization/strings.dart';
import '../models/contact.dart';
import '../theme/app_theme.dart';
import 'contact_controller.dart';

/// Modal sheet for adding a Contact (birthday entry) to a Birthdays-typed
/// list. Captures the name + birth date; day & month are required, year is
/// optional (toggle "Include year"). Reminders / notes can be added later
/// from the contact detail view.
void showContactCreationSheet(
  BuildContext context,
  ContactController controller, {
  required String listId,
}) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => _ContactCreationSheet(
      controller: controller,
      listId: listId,
    ),
  );
}

class _ContactCreationSheet extends StatefulWidget {
  const _ContactCreationSheet({
    required this.controller,
    required this.listId,
  });

  final ContactController controller;
  final String listId;

  @override
  State<_ContactCreationSheet> createState() => _ContactCreationSheetState();
}

class _ContactCreationSheetState extends State<_ContactCreationSheet> {
  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _includeYear = false;
  DateTime _picked = DateTime(2000, 1, 1);
  bool _nameEmpty = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() {
      final empty = _nameCtrl.text.trim().isEmpty;
      if (empty != _nameEmpty) setState(() => _nameEmpty = empty);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    DateTime temp = _picked;
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
                  initialDateTime: _picked,
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (d) => temp = d,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _picked = picked);
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    await widget.controller.addContact(Contact(
      name: name,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      listId: widget.listId,
      birthMonth: _picked.month,
      birthDay: _picked.day,
      birthYear: _includeYear ? _picked.year : null,
      isCompletable: false,
    ));
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final m = months[d.month - 1];
    if (_includeYear) return '$m ${d.day}, ${d.year}';
    return '$m ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(12)),
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
          const SizedBox(height: 12),
          Center(
            child: Text(
              s.addBirthday,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          CupertinoTextField(
            controller: _nameCtrl,
            placeholder: s.birthdayName,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            decoration: BoxDecoration(
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.gift,
                    size: 18,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.birthDate,
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                  Text(
                    _formatDate(_picked),
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
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(s.includeYear,
                      style: const TextStyle(fontSize: 17)),
                ),
                CupertinoSwitch(
                  value: _includeYear,
                  activeColor: AppColors.accent,
                  onChanged: (v) => setState(() => _includeYear = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _noteCtrl,
            placeholder: s.note,
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: BoxDecoration(
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            color: _nameEmpty
                ? CupertinoColors.tertiarySystemFill.resolveFrom(context)
                : AppColors.accent,
            borderRadius: BorderRadius.circular(12),
            onPressed: _nameEmpty ? null : _submit,
            child: Text(
              s.add,
              style: TextStyle(
                color: _nameEmpty
                    ? CupertinoColors.tertiaryLabel.resolveFrom(context)
                    : CupertinoColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
