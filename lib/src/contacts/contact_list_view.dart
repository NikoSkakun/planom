import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/contact.dart';
import '../tasks/task_row.dart' show TaskDeleteBackground;
import '../utils/fast_route.dart';
import '../utils/undo_controller.dart';
import 'contact_controller.dart';
import 'contact_detail_view.dart';
import 'contact_row.dart';

/// Body widget rendered inside ListTaskView when the list's type is
/// Birthdays. Sorts contacts by their next celebration date and splits
/// this-year from next-year with a year-label separator row.
class ContactListView extends StatelessWidget {
  const ContactListView({
    super.key,
    required this.listId,
    required this.controller,
  });

  final String listId;
  final ContactController controller;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final all = controller.contactsForList(listId);

        if (all.isEmpty) {
          return Center(
            child: Text(
              s.noTasks,
              style: const TextStyle(color: CupertinoColors.secondaryLabel),
            ),
          );
        }

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // Build (contact, celebrationDate) tuples. For each contact we
        // compute the next occurrence on/after today, plus a next-year
        // iteration so the user can see what's coming next year.
        final entries = <_ContactEntry>[];
        for (final c in all) {
          final thisYear = _safeDate(today.year, c.birthMonth, c.birthDay);
          final nextYear =
              _safeDate(today.year + 1, c.birthMonth, c.birthDay);
          if (!thisYear.isBefore(today)) {
            entries.add(_ContactEntry(c, thisYear));
            entries.add(_ContactEntry(c, nextYear));
          } else {
            entries.add(_ContactEntry(c, nextYear));
          }
        }
        entries.sort((a, b) => a.date.compareTo(b.date));

        // Group by year so we can insert year-header separator rows.
        final widgets = <Widget>[];
        int? lastYear;
        for (final e in entries) {
          if (e.date.year != lastYear) {
            widgets.add(_YearHeader(year: e.date.year));
            lastYear = e.date.year;
          }
          widgets.add(
            Dismissible(
              key: ValueKey('contact_${e.contact.id}_${e.date.year}'),
              direction: DismissDirection.endToStart,
              background: const TaskDeleteBackground(),
              onDismissed: (_) {
                final savedListId = e.contact.listId;
                controller.deleteContact(e.contact.id);
                UndoScope.maybeOf(context)?.show(
                  label: S.of(context).taskTrashedToast,
                  onUndo: () =>
                      controller.restoreContact(e.contact.id, savedListId),
                );
              },
              child: ContactRow(
                contact: e.contact,
                celebrationDate: e.date,
                onToggle: () => controller.toggleCompleted(e.contact.id),
                onTap: () => Navigator.of(context).push(
                  FastRoute<void>(
                    settings: const RouteSettings(
                        name: ContactDetailView.routeName),
                    builder: (_) => ContactDetailView(
                      contact: e.contact,
                      controller: controller,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: widgets,
        );
      },
    );
  }

  /// Valid DateTime at midnight for the given y/m/d, clamping day to the
  /// last day of the month so Feb 29 → Feb 28 in non-leap years.
  static DateTime _safeDate(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDay ? lastDay : day);
  }
}

class _ContactEntry {
  const _ContactEntry(this.contact, this.date);
  final Contact contact;
  final DateTime date;
}

class _YearHeader extends StatelessWidget {
  const _YearHeader({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        '$year',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}
