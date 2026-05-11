import 'package:flutter/cupertino.dart';

import '../models/note.dart';
import '../utils/item_info_sheet.dart';
import 'note_controller.dart';

class NoteDetailView extends StatefulWidget {
  const NoteDetailView({
    super.key,
    required this.note,
    required this.controller,
    this.isNew = false,
  });

  static const routeName = 'note_detail';

  final Note note;
  final NoteController controller;
  final bool isNew;

  @override
  State<NoteDetailView> createState() => _NoteDetailViewState();
}

class _NoteDetailViewState extends State<NoteDetailView> {
  late final TextEditingController _title;
  late final TextEditingController _content;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note.title);
    _content = TextEditingController(text: widget.note.content);
  }

  void _showDropdown(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _NoteOptionsDropdown(
        onDismiss: () => entry.remove(),
        onInfo: () {
          entry.remove();
          showItemInfoSheet(
            context,
            creationDate: widget.note.creationDate,
            modifiedDate: widget.note.modifiedDate,
          );
        },
      ),
    );
    overlay.insert(entry);
  }

  @override
  void dispose() {
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (widget.isNew) {
      if (title.isNotEmpty || content.isNotEmpty) {
        widget.controller.addNote(
          widget.note.copyWith(title: title, content: content),
        );
      }
    } else {
      widget.controller.updateNote(
        widget.note.copyWith(title: title, content: content),
      );
    }
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        trailing: widget.isNew
            ? null
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showDropdown(context),
                child: const Icon(CupertinoIcons.ellipsis, size: 26),
              ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: CupertinoTextField(
                controller: _title,
                placeholder: 'Title',
                autofocus: widget.isNew,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const BoxDecoration(),
                maxLines: null,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 0.5,
                color: CupertinoColors.separator,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: CupertinoTextField(
                  controller: _content,
                  placeholder: 'Note',
                  style: const TextStyle(fontSize: 16),
                  decoration: const BoxDecoration(),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteOptionsDropdown extends StatelessWidget {
  const _NoteOptionsDropdown({required this.onDismiss, required this.onInfo});
  final VoidCallback onDismiss;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final topOffset = MediaQuery.paddingOf(context).top + 44.0 + 4.0;
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: const SizedBox.expand(),
        ),
        Positioned(
          top: topOffset,
          right: 8,
          child: Container(
            width: 220,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x30000000),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: onInfo,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Info',
                        style: TextStyle(
                          fontSize: 15,
                          color:
                              CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      CupertinoIcons.info,
                      size: 17,
                      color: CupertinoColors.secondaryLabel
                          .resolveFrom(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
