import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, showModalBottomSheet;

import '../localization/strings.dart';
import '../models/tag.dart';
import '../theme/app_theme.dart';
import 'task_controller.dart';

/// Multi-select tag picker. Returns the chosen tag id list (or null if the
/// sheet was dismissed without a change). Lets the user create a new tag
/// inline by typing in the search field and tapping the "Create" row.
Future<List<String>?> showTagPickerSheet(
  BuildContext context,
  TaskController controller, {
  required List<String> initialSelected,
}) async {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TagPickerSheet(
      controller: controller,
      initialSelected: initialSelected,
    ),
  );
}

class _TagPickerSheet extends StatefulWidget {
  const _TagPickerSheet({
    required this.controller,
    required this.initialSelected,
  });

  final TaskController controller;
  final List<String> initialSelected;

  @override
  State<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<_TagPickerSheet> {
  late Set<String> _selected;
  final TextEditingController _filter = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = Set.of(widget.initialSelected);
    _filter.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  Future<void> _createTag() async {
    final name = _filter.text.trim();
    if (name.isEmpty) return;
    final tag = await widget.controller.addOrGetTag(name);
    setState(() {
      _selected.add(tag.id);
      _filter.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final filter = _filter.text.trim().toLowerCase();
    final all = widget.controller.tags;
    final matching = filter.isEmpty
        ? all
        : all
            .where((t) => t.name.toLowerCase().contains(filter))
            .toList(growable: false);
    final exactMatch = matching
        .any((t) => t.name.toLowerCase() == filter && filter.isNotEmpty);
    final canCreate = filter.isNotEmpty && !exactMatch;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.tags,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () =>
                          Navigator.of(context).pop(_selected.toList()),
                      child: Text(s.done,
                          style: TextStyle(color: AppColors.accent)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: CupertinoSearchTextField(
                  controller: _filter,
                  placeholder: s.searchOrCreateTag,
                  onSubmitted: (_) {
                    if (canCreate) _createTag();
                  },
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (canCreate)
                      _CreateRow(
                        label: '${s.createTag} "${_filter.text.trim()}"',
                        onTap: _createTag,
                      ),
                    for (final tag in matching)
                      _TagRow(
                        tag: tag,
                        selected: _selected.contains(tag.id),
                        onToggle: () => setState(() {
                          if (_selected.contains(tag.id)) {
                            _selected.remove(tag.id);
                          } else {
                            _selected.add(tag.id);
                          }
                        }),
                      ),
                    if (matching.isEmpty && !canCreate)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            s.noTags,
                            style: TextStyle(
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.tag,
    required this.selected,
    required this.onToggle,
  });

  final Tag tag;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tag.name,
      selected: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tag.color != null
                      ? Color(tag.color!)
                      : CupertinoColors.systemGrey3.resolveFrom(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tag.name,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              if (selected)
                Icon(
                  CupertinoIcons.checkmark,
                  size: 18,
                  color: AppColors.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateRow extends StatelessWidget {
  const _CreateRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(CupertinoIcons.add_circled, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 16, color: AppColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

