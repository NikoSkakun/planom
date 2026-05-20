import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';

/// Toolbar that sits above the keyboard while editing a note. Buttons wrap the
/// current selection (or insert at the cursor) with markdown syntax, then
/// restore focus so the keyboard stays open.
class MarkdownToolbar extends StatelessWidget {
  const MarkdownToolbar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onPromptLink,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<({String text, String url})?> Function(String selectedText)
      onPromptLink;

  void _wrap(String prefix, String suffix, {String placeholder = ''}) {
    final value = controller.value;
    final sel = value.selection;
    final text = value.text;

    int start = sel.start;
    int end = sel.end;
    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }

    final selected = text.substring(start, end);
    final inner = selected.isEmpty ? placeholder : selected;
    final replacement = '$prefix$inner$suffix';

    final newText = text.replaceRange(start, end, replacement);
    final cursorPos = selected.isEmpty
        ? start + prefix.length
        : start + replacement.length;
    final selectionEnd = selected.isEmpty
        ? cursorPos + placeholder.length
        : cursorPos;

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: cursorPos,
        extentOffset: selectionEnd,
      ),
    );
    focusNode.requestFocus();
  }

  void _linePrefix(String prefix) {
    final value = controller.value;
    final text = value.text;
    int caret = value.selection.baseOffset;
    if (caret < 0) caret = text.length;

    int lineStart = caret;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    final newText = text.replaceRange(lineStart, lineStart, prefix);
    final newCaret = caret + prefix.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCaret),
    );
    focusNode.requestFocus();
  }

  Future<void> _insertLink(BuildContext context) async {
    final value = controller.value;
    final sel = value.selection;
    final selected = sel.isValid && !sel.isCollapsed
        ? value.text.substring(sel.start, sel.end)
        : '';

    final result = await onPromptLink(selected);
    if (result == null) return;

    final label = result.text.isEmpty ? result.url : result.text;
    final replacement = '[$label](${result.url})';

    final start = sel.isValid ? sel.start : value.text.length;
    final end = sel.isValid ? sel.end : value.text.length;
    final newText = value.text.replaceRange(start, end, replacement);

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemGrey6.resolveFrom(context);
    final border = CupertinoColors.separator.resolveFrom(context);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  children: [
                    _ToolbarTextButton(
                      label: 'H1',
                      onTap: () => _linePrefix('# '),
                    ),
                    _ToolbarTextButton(
                      label: 'H2',
                      onTap: () => _linePrefix('## '),
                    ),
                    _ToolbarTextButton(
                      label: 'H3',
                      onTap: () => _linePrefix('### '),
                    ),
                    _ToolbarButton(
                      icon: CupertinoIcons.bold,
                      onTap: () => _wrap('**', '**', placeholder: 'bold'),
                    ),
                    _ToolbarButton(
                      icon: CupertinoIcons.italic,
                      onTap: () => _wrap('*', '*', placeholder: 'italic'),
                    ),
                    _ToolbarButton(
                      icon: CupertinoIcons.strikethrough,
                      onTap: () => _wrap('~~', '~~', placeholder: 'text'),
                    ),
                    _ToolbarButton(
                      icon: CupertinoIcons.list_bullet,
                      onTap: () => _linePrefix('- '),
                    ),
                    _ToolbarButton(
                      icon: CupertinoIcons.list_number,
                      onTap: () => _linePrefix('1. '),
                    ),
                    _ToolbarButton(
                      icon: CupertinoIcons.quote_bubble,
                      onTap: () => _linePrefix('> '),
                    ),
                    _ToolbarButton(
                      icon: CupertinoIcons.chevron_left_slash_chevron_right,
                      onTap: () => _wrap('`', '`', placeholder: 'code'),
                    ),
                    _ToolbarButton(
                      icon: CupertinoIcons.link,
                      onTap: () => _insertLink(context),
                    ),
                  ],
                ),
              ),
              Container(width: 0.5, color: border),
              _ToolbarButton(
                icon: CupertinoIcons.keyboard_chevron_compact_down,
                onTap: () => focusNode.unfocus(),
                color: AppColors.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarTextButton extends StatelessWidget {
  const _ToolbarTextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = CupertinoColors.label.resolveFrom(context);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      minSize: 36,
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: tint,
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? CupertinoColors.label.resolveFrom(context);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      minSize: 36,
      onPressed: onTap,
      child: Icon(icon, size: 22, color: tint),
    );
  }
}

/// Modal dialog to prompt for a URL (and optionally a display label).
Future<({String text, String url})?> showLinkPromptDialog(
  BuildContext context, {
  required String initialText,
}) async {
  final textCtrl = TextEditingController(text: initialText);
  final urlCtrl = TextEditingController();
  final result = await showCupertinoDialog<({String text, String url})>(
    context: context,
    builder: (ctx) {
      return CupertinoAlertDialog(
        title: const Text('Insert Link'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                controller: textCtrl,
                placeholder: 'Link text (optional)',
                autocorrect: false,
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: urlCtrl,
                placeholder: 'https://…',
                keyboardType: TextInputType.url,
                autocorrect: false,
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final url = urlCtrl.text.trim();
              if (url.isEmpty) {
                Navigator.of(ctx).pop();
                return;
              }
              Navigator.of(ctx).pop(
                (text: textCtrl.text.trim(), url: url),
              );
            },
            child: const Text('Insert'),
          ),
        ],
      );
    },
  );
  textCtrl.dispose();
  urlCtrl.dispose();
  return result;
}
