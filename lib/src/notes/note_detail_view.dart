import 'package:flutter/cupertino.dart';

import '../models/note.dart';
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

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final content = _content.text.trim();

    if (widget.isNew) {
      if (title.isEmpty && content.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      await widget.controller.addNote(
        widget.note.copyWith(title: title, content: content),
      );
    } else {
      await widget.controller.updateNote(
        widget.note.copyWith(title: title, content: content),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text(
            'Done',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
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
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const BoxDecoration(),
                maxLines: null,
                textInputAction: TextInputAction.next,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
