import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';

void showItemInfoSheet(
  BuildContext context, {
  required DateTime creationDate,
  DateTime? modifiedDate,
  DateTime? completionDate,
}) {
  final s = S.of(context);
  final months = monthsShort(context);
  showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(s.info),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(
                label: s.created, value: _formatDateTime(creationDate, months)),
            if (modifiedDate != null) ...[
              const SizedBox(height: 6),
              _InfoRow(
                  label: s.modified,
                  value: _formatDateTime(modifiedDate, months)),
            ],
            if (completionDate != null) ...[
              const SizedBox(height: 6),
              _InfoRow(
                  label: s.completedLabel,
                  value: _formatDateTime(completionDate, months)),
            ],
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(s.done),
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
        Text(value, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

String _formatDateTime(DateTime dt, List<String> months) {
  final h = dt.hour;
  final period = h >= 12 ? 'PM' : 'AM';
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  final min = dt.minute.toString().padLeft(2, '0');
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}, $h12:$min $period';
}
