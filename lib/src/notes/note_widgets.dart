import 'package:flutter/cupertino.dart';

import '../folders/folder_icon_picker.dart';
import '../models/note.dart';
import '../models/note_folder.dart';

class NoteDeleteBackground extends StatelessWidget {
  const NoteDeleteBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      color: CupertinoColors.destructiveRed,
      child: const Icon(CupertinoIcons.trash, color: CupertinoColors.white),
    );
  }
}

class NoteFolderRow extends StatelessWidget {
  const NoteFolderRow({
    super.key,
    required this.folder,
    required this.onTap,
    this.noteCount,
    this.onExpand,
    this.isExpanded = false,
    this.indent = 0,
  });

  final NoteFolder folder;
  final VoidCallback onTap;
  final int? noteCount;
  final VoidCallback? onExpand;
  final bool isExpanded;
  final double indent;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  16 + indent, 9, onExpand != null ? 4 : 16, 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: buildFolderItemIcon(folder.iconId, isFolder: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      folder.name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (noteCount != null && noteCount! > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '$noteCount',
                      style: TextStyle(
                        fontSize: 15,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (onExpand != null)
          GestureDetector(
            onTap: onExpand,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 48,
              child: Center(
                child: AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    CupertinoIcons.chevron_right,
                    size: 14,
                    color:
                        CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ),
          ),
      ],
      ),
    );
  }
}

class NoteRow extends StatelessWidget {
  const NoteRow({
    super.key,
    required this.note,
    required this.onTap,
    this.indent = 0,
  });

  final Note note;
  final VoidCallback onTap;
  final double indent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16 + indent, 9, 16, 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                CupertinoIcons.doc_text,
                size: 22,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title.isEmpty ? 'Untitled' : note.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontStyle: note.title.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (note.content.isNotEmpty)
                    Text(
                      note.content,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
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

class NoteFolderCircleButton extends StatelessWidget {
  const NoteFolderCircleButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          shape: BoxShape.circle,
        ),
        child: Icon(
          CupertinoIcons.folder_badge_plus,
          size: 20,
          color: CupertinoColors.label.resolveFrom(context),
        ),
      ),
    );
  }
}

class NoteOrangeAddButton extends StatelessWidget {
  const NoteOrangeAddButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          color: Color(0xFFFF4D00),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          CupertinoIcons.plus,
          color: CupertinoColors.white,
          size: 24,
        ),
      ),
    );
  }
}
