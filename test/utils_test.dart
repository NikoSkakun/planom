import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/utils/duration_picker.dart';
import 'package:planom/src/utils/selection_controller.dart';
import 'package:planom/src/utils/undo_controller.dart';
import 'package:planom/src/settings/smart_list_prefs.dart';
import 'package:planom/src/tasks/task_field_prefs.dart';

void main() {
  group('formatDuration', () {
    test('formats sub-hour values as minutes', () {
      expect(formatDuration(15), '15m');
      expect(formatDuration(45), '45m');
      expect(formatDuration(0), '0m');
      expect(formatDuration(59), '59m');
    });

    test('formats whole hours', () {
      expect(formatDuration(60), '1h');
      expect(formatDuration(120), '2h');
      expect(formatDuration(180), '3h');
    });

    test('formats hours + minutes', () {
      expect(formatDuration(90), '1h 30m');
      expect(formatDuration(125), '2h 5m');
      expect(formatDuration(61), '1h 1m');
    });
  });

  group('SelectionController', () {
    test('starts inactive and empty', () {
      final c = SelectionController();
      expect(c.active, isFalse);
      expect(c.isEmpty, isTrue);
      expect(c.count, 0);
      expect(c.kind, isNull);
    });

    test('start() activates and notifies', () {
      final c = SelectionController();
      var notified = 0;
      c.addListener(() => notified++);
      c.start();
      expect(c.active, isTrue);
      expect(notified, 1);
      // Second start() is a no-op (no extra notify).
      c.start();
      expect(notified, 1);
    });

    test('toggle selects, locks kind, and notifies', () {
      final c = SelectionController();
      var notified = 0;
      c.addListener(() => notified++);

      c.toggle('a', SelectionItemKind.task);
      expect(c.isSelected('a'), isTrue);
      expect(c.count, 1);
      expect(c.kind, SelectionItemKind.task);
      expect(notified, 1);

      c.toggle('b', SelectionItemKind.task);
      expect(c.count, 2);
      expect(notified, 2);
    });

    test('toggling a different kind after lock is ignored', () {
      final c = SelectionController();
      var notified = 0;
      c.addListener(() => notified++);

      c.toggle('a', SelectionItemKind.task);
      expect(notified, 1);

      // Mismatched kind is silently ignored: no selection change, no notify.
      c.toggle('note1', SelectionItemKind.note);
      expect(c.isSelected('note1'), isFalse);
      expect(c.count, 1);
      expect(c.kind, SelectionItemKind.task);
      expect(notified, 1);
    });

    test('toggling same id again deselects', () {
      final c = SelectionController();
      c.toggle('a', SelectionItemKind.task);
      c.toggle('b', SelectionItemKind.task);
      expect(c.count, 2);

      c.toggle('a', SelectionItemKind.task);
      expect(c.isSelected('a'), isFalse);
      expect(c.count, 1);
      // Kind stays locked while items remain.
      expect(c.kind, SelectionItemKind.task);
    });

    test('removing last item unlocks kind, allowing a new kind', () {
      final c = SelectionController();
      c.toggle('a', SelectionItemKind.task);
      c.toggle('a', SelectionItemKind.task); // deselect last
      expect(c.isEmpty, isTrue);
      expect(c.kind, isNull);

      // Now a fresh selection of a different kind is allowed.
      c.toggle('n1', SelectionItemKind.note);
      expect(c.isSelected('n1'), isTrue);
      expect(c.kind, SelectionItemKind.note);
    });

    test('replaceAll replaces selection and sets kind', () {
      final c = SelectionController();
      c.toggle('a', SelectionItemKind.task);

      var notified = 0;
      c.addListener(() => notified++);
      c.replaceAll(['x', 'y', 'z'], SelectionItemKind.list);
      expect(c.selectedIds, {'x', 'y', 'z'});
      expect(c.kind, SelectionItemKind.list);
      expect(c.count, 3);
      expect(notified, 1);

      // replaceAll with empty clears the kind.
      c.replaceAll(const [], SelectionItemKind.list);
      expect(c.isEmpty, isTrue);
      expect(c.kind, isNull);
    });

    test('selectedIds is unmodifiable', () {
      final c = SelectionController();
      c.toggle('a', SelectionItemKind.task);
      expect(() => c.selectedIds.add('b'), throwsUnsupportedError);
    });

    test('cancel clears everything and notifies', () {
      final c = SelectionController();
      c.start();
      c.toggle('a', SelectionItemKind.task);

      var notified = 0;
      c.addListener(() => notified++);
      c.cancel();
      expect(c.active, isFalse);
      expect(c.isEmpty, isTrue);
      expect(c.kind, isNull);
      expect(notified, 1);
    });
  });

  group('UndoController', () {
    test('show sets pending and notifies', () {
      final c = UndoController();
      var notified = 0;
      c.addListener(() => notified++);

      c.show(label: 'Deleted task', onUndo: () async {});
      expect(c.pending, isNotNull);
      expect(c.pending!.label, 'Deleted task');
      expect(notified, 1);

      c.dispose();
    });

    test('a second show replaces pending', () {
      final c = UndoController();
      c.show(label: 'first', onUndo: () async {});
      c.show(label: 'second', onUndo: () async {});
      expect(c.pending!.label, 'second');
      c.dispose();
    });

    test('invoke runs the onUndo callback and clears pending', () async {
      final c = UndoController();
      var ran = false;
      c.show(
        label: 'x',
        onUndo: () async {
          ran = true;
        },
      );
      await c.invoke();
      expect(ran, isTrue);
      expect(c.pending, isNull);
      c.dispose();
    });

    test('invoke with no pending is a safe no-op', () async {
      final c = UndoController();
      await c.invoke(); // must not throw
      expect(c.pending, isNull);
      c.dispose();
    });

    test('invoke only runs the latest action after replacement', () async {
      final c = UndoController();
      var firstRan = false;
      var secondRan = false;
      c.show(label: 'first', onUndo: () async => firstRan = true);
      c.show(label: 'second', onUndo: () async => secondRan = true);
      await c.invoke();
      expect(firstRan, isFalse);
      expect(secondRan, isTrue);
      c.dispose();
    });
  });

  group('SmartListPrefs', () {
    test('toJson then applyJson round-trips all fields', () {
      final src = SmartListPrefs(
        today: SmartListVisibility.hidden,
        tomorrow: SmartListVisibility.show,
        upcoming: SmartListVisibility.showIfNotEmpty,
        allTasks: SmartListVisibility.show,
        completed: SmartListVisibility.hidden,
        trash: SmartListVisibility.show,
        notesTrash: SmartListVisibility.hidden,
        hideTabLabels: true,
        showAddFolderButton: false,
        showNotesAddFolderButton: false,
        notesUseMarkdown: false,
      );

      final json = src.toJson();
      final dst = SmartListPrefs();
      dst.applyJson(json);

      expect(dst.today, SmartListVisibility.hidden);
      expect(dst.tomorrow, SmartListVisibility.show);
      expect(dst.upcoming, SmartListVisibility.showIfNotEmpty);
      expect(dst.allTasks, SmartListVisibility.show);
      expect(dst.completed, SmartListVisibility.hidden);
      expect(dst.trash, SmartListVisibility.show);
      expect(dst.notesTrash, SmartListVisibility.hidden);
      expect(dst.hideTabLabels, isTrue);
      expect(dst.showAddFolderButton, isFalse);
      expect(dst.showNotesAddFolderButton, isFalse);
      expect(dst.notesUseMarkdown, isFalse);
    });

    test('round-trips defaults', () {
      final src = SmartListPrefs();
      final dst = SmartListPrefs(
        // Start from non-default values to prove applyJson overwrites them.
        today: SmartListVisibility.hidden,
        hideTabLabels: true,
        notesUseMarkdown: false,
      );
      dst.applyJson(src.toJson());

      expect(dst.today, SmartListVisibility.show);
      expect(dst.tomorrow, SmartListVisibility.showIfNotEmpty);
      expect(dst.upcoming, SmartListVisibility.show);
      expect(dst.allTasks, SmartListVisibility.hidden);
      expect(dst.completed, SmartListVisibility.showIfNotEmpty);
      expect(dst.trash, SmartListVisibility.showIfNotEmpty);
      expect(dst.notesTrash, SmartListVisibility.showIfNotEmpty);
      expect(dst.hideTabLabels, isFalse);
      expect(dst.showAddFolderButton, isTrue);
      expect(dst.showNotesAddFolderButton, isTrue);
      expect(dst.notesUseMarkdown, isTrue);
    });

    test('toJson encodes enums as the expected string tokens', () {
      final json = SmartListPrefs(
        today: SmartListVisibility.show,
        tomorrow: SmartListVisibility.showIfNotEmpty,
        upcoming: SmartListVisibility.hidden,
      ).toJson();
      expect(json['today'], 'show');
      expect(json['tomorrow'], 'showIfNotEmpty');
      expect(json['upcoming'], 'hidden');
    });
  });

  group('TaskFieldPrefs', () {
    test('fromJson(toJson()) round-trips all fields', () {
      final src = TaskFieldPrefs(
        showPriority: false,
        showDate: false,
        showRepeat: false,
        showList: false,
        showDuration: false,
        showTags: false,
        showReminders: false,
        showListCount: false,
        useMarkdown: false,
        folderCounterMode: FolderCounterMode.recursive,
        checkboxStyle: TaskCheckboxStyle.circle,
        showUndoOnComplete: true,
      );

      final dst = TaskFieldPrefs.fromJson(src.toJson());

      expect(dst.showPriority, isFalse);
      expect(dst.showDate, isFalse);
      expect(dst.showRepeat, isFalse);
      expect(dst.showList, isFalse);
      expect(dst.showDuration, isFalse);
      expect(dst.showTags, isFalse);
      expect(dst.showReminders, isFalse);
      expect(dst.showListCount, isFalse);
      expect(dst.useMarkdown, isFalse);
      expect(dst.folderCounterMode, FolderCounterMode.recursive);
      expect(dst.checkboxStyle, TaskCheckboxStyle.circle);
      expect(dst.showUndoOnComplete, isTrue);
    });

    test('round-trips every folderCounterMode and checkboxStyle value', () {
      for (final mode in FolderCounterMode.values) {
        for (final style in TaskCheckboxStyle.values) {
          final dst = TaskFieldPrefs.fromJson(
            TaskFieldPrefs(folderCounterMode: mode, checkboxStyle: style)
                .toJson(),
          );
          expect(dst.folderCounterMode, mode);
          expect(dst.checkboxStyle, style);
        }
      }
    });

    test('toJson produces valid JSON', () {
      final raw = TaskFieldPrefs().toJson();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['priority'], isTrue);
      expect(decoded['folderCounter'], 'directOnly');
      expect(decoded['checkboxStyle'], 'roundedRect');
    });

    test('fromJson(null) returns defaults', () {
      final d = TaskFieldPrefs.fromJson(null);
      expect(d.showPriority, isTrue);
      expect(d.showDate, isTrue);
      expect(d.useMarkdown, isTrue);
      expect(d.folderCounterMode, FolderCounterMode.directOnly);
      expect(d.checkboxStyle, TaskCheckboxStyle.roundedRect);
      expect(d.showUndoOnComplete, isFalse);
    });

    test('fromJson empty string returns defaults', () {
      final d = TaskFieldPrefs.fromJson('');
      expect(d.showPriority, isTrue);
      expect(d.checkboxStyle, TaskCheckboxStyle.roundedRect);
    });

    test('fromJson garbage returns defaults', () {
      final d = TaskFieldPrefs.fromJson('not valid json {{{');
      expect(d.showPriority, isTrue);
      expect(d.showDate, isTrue);
      expect(d.folderCounterMode, FolderCounterMode.directOnly);
    });

    test('copy produces an equal-valued independent object', () {
      final src = TaskFieldPrefs(
        showPriority: false,
        folderCounterMode: FolderCounterMode.recursive,
        checkboxStyle: TaskCheckboxStyle.sharpRect,
        showUndoOnComplete: true,
      );
      final copy = src.copy();

      expect(identical(copy, src), isFalse);
      expect(copy.toJson(), src.toJson());

      // Mutating the copy must not affect the original.
      copy.showPriority = true;
      copy.folderCounterMode = FolderCounterMode.hidden;
      expect(src.showPriority, isFalse);
      expect(src.folderCounterMode, FolderCounterMode.recursive);
    });
  });
}
