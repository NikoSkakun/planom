import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';

import '../folders/folder_icon_picker.dart';
import '../localization/strings.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import '../utils/plus_drag_payload.dart';

List<InlineSpan> _parseInlineMarkdown(String text, TextStyle base) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(
    r'\*\*([^*]+)\*\*'        // **bold**
    r'|\*([^*]+)\*'            // *italic*
    r'|~~([^~]+)~~'            // ~~strikethrough~~
    r'|`([^`]+)`'              // `code`
    r'|\[([^\]]*)\]\([^)]*\)', // [text](url)
  );
  int last = 0;
  for (final m in pattern.allMatches(text)) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start), style: base));
    }
    if (m.group(1) != null) {
      spans.add(TextSpan(text: m.group(1), style: base.copyWith(fontWeight: FontWeight.w700)));
    } else if (m.group(2) != null) {
      spans.add(TextSpan(text: m.group(2), style: base.copyWith(fontStyle: FontStyle.italic)));
    } else if (m.group(3) != null) {
      spans.add(TextSpan(text: m.group(3), style: base.copyWith(decoration: TextDecoration.lineThrough)));
    } else if (m.group(4) != null) {
      spans.add(TextSpan(text: m.group(4), style: base.copyWith(fontFamily: 'Menlo', fontSize: 12.0)));
    } else if (m.group(5) != null) {
      spans.add(TextSpan(text: m.group(5), style: base));
    }
    last = m.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last), style: base));
  }
  return spans;
}

Widget _buildFirstLinePreview(String content, TextStyle base) {
  var line = content.split('\n').first;
  final isHeading = RegExp(r'^#{1,6} ').hasMatch(line);
  line = line.replaceFirst(RegExp(r'^#{1,6} '), '');
  line = line.replaceFirst(RegExp(r'^[-*+] '), '');
  line = line.replaceFirst(RegExp(r'^\d+\. '), '');
  line = line.replaceFirst(RegExp(r'^> ?'), '');
  final effectiveBase =
      isHeading ? base.copyWith(fontWeight: FontWeight.w700) : base;
  return Text.rich(
    TextSpan(children: _parseInlineMarkdown(line, effectiveBase)),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}

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
    final hasBody = note.content.isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16 + indent, 9, 16, 9),
        child: Row(
          crossAxisAlignment:
              hasBody ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.only(top: hasBody ? 2 : 0),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    note.title.isEmpty ? S.of(context).untitled : note.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontStyle: note.title.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasBody)
                    _buildFirstLinePreview(
                      note.content,
                      TextStyle(
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
  const NoteFolderCircleButton({
    super.key,
    required this.onPressed,
    this.onAcceptPlus,
  });
  final VoidCallback onPressed;
  final VoidCallback? onAcceptPlus;

  Widget _button(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    if (onAcceptPlus == null) return _button(context);
    return DragTarget<PlusDragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (_) => onAcceptPlus!(),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: hovering
                ? [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: _button(context),
        );
      },
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
        decoration: BoxDecoration(
          color: AppColors.accent,
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
