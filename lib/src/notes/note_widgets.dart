import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';

import '../folders/folder_icon_picker.dart';
import '../localization/strings.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import '../utils/emoji_text.dart';
import '../utils/plus_drag_payload.dart';
import '../utils/reorder_drag.dart';

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
      spans.addAll(buildEmojiSpans(text.substring(last, m.start), base));
    }
    if (m.group(1) != null) {
      spans.addAll(buildEmojiSpans(
          m.group(1)!, base.copyWith(fontWeight: FontWeight.w700)));
    } else if (m.group(2) != null) {
      spans.addAll(buildEmojiSpans(
          m.group(2)!, base.copyWith(fontStyle: FontStyle.italic)));
    } else if (m.group(3) != null) {
      spans.addAll(buildEmojiSpans(
          m.group(3)!, base.copyWith(decoration: TextDecoration.lineThrough)));
    } else if (m.group(4) != null) {
      spans.addAll(buildEmojiSpans(
          m.group(4)!, base.copyWith(fontFamily: 'Menlo', fontSize: 12.0)));
    } else if (m.group(5) != null) {
      spans.addAll(buildEmojiSpans(m.group(5)!, base));
    }
    last = m.end;
  }
  if (last < text.length) {
    spans.addAll(buildEmojiSpans(text.substring(last), base));
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

class NoteRow extends StatefulWidget {
  const NoteRow({
    super.key,
    required this.note,
    required this.onTap,
    this.indent = 0,
    this.draggable = true,
  });

  final Note note;
  final VoidCallback onTap;
  final double indent;
  // When true (default), wraps the row in a LongPressDraggable<NoteDragData>
  // so the user can drop it on a NoteFolderRow to re-parent the note.
  final bool draggable;

  @override
  State<NoteRow> createState() => _NoteRowState();
}

class _NoteRowState extends State<NoteRow> {
  final GlobalKey _measureKey = GlobalKey();

  double _measureHeight() {
    final ctx = _measureKey.currentContext;
    final renderObject = ctx?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size.height;
    }
    return 56;
  }

  void _onDragStarted() {
    ReorderDragNotifier.instance
        .start(widget.note.id, 'note', _measureHeight());
  }

  void _onDragEnded() {
    ReorderDragNotifier.instance.end();
  }

  @override
  void dispose() {
    if (ReorderDragNotifier.instance.draggingId == widget.note.id) {
      ReorderDragNotifier.instance.end();
    }
    super.dispose();
  }

  Note get note => widget.note;
  double get indent => widget.indent;

  Widget _content(BuildContext context) {
    final hasBody = note.content.isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
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

  @override
  Widget build(BuildContext context) {
    if (!widget.draggable) {
      return KeyedSubtree(key: _measureKey, child: _content(context));
    }
    final content = _content(context);
    final feedbackWidth = MediaQuery.sizeOf(context).width;
    return AnimatedSize(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: LongPressDraggable<NoteDragData>(
        data: NoteDragData(note.id),
        delay: const Duration(milliseconds: 400),
        onDragStarted: _onDragStarted,
        onDragEnd: (_) => _onDragEnded(),
        onDraggableCanceled: (_, __) => _onDragEnded(),
        onDragCompleted: _onDragEnded,
        // Render the actual row as the drag feedback so the lifted
        // card looks identical to the source row (icon, title, body
        // preview) rather than a stripped-down title-only card.
        feedback: buildReorderDragFeedback(context, feedbackWidth, content),
        childWhenDragging: const SizedBox.shrink(),
        child: KeyedSubtree(key: _measureKey, child: content),
      ),
    );
  }
}

/// Payload dragged when the user long-presses a note. Distinct from
/// the generic string used by tasks so DragTargets can route notes and
/// tasks differently.
class NoteDragData {
  const NoteDragData(this.noteId);
  final String noteId;
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
          color: AppColors.circleButtonBackground.resolveFrom(context),
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
