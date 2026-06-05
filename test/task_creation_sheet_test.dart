import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/folders/folder_controller.dart';
import 'package:planom/src/localization/app_localizations.dart';
import 'package:planom/src/tasks/task_controller.dart';
import 'package:planom/src/tasks/task_creation_sheet.dart';

import 'support/test_db.dart';

/// Regression coverage for the "calendar day leaks into the Tasks + sheet" bug.
///
/// The HomeShell keeps a single date selection per surface; previously the
/// Calendar tab's selected day bled into the Tasks tab's task-creation sheet
/// (shared notifier). The structural fix gives the Calendar its own notifier so
/// the Tasks + button only ever pre-fills a date it was explicitly handed.
///
/// These tests lock the underlying contract the fix relies on: the creation
/// sheet shows a date **only** when one is passed via [initialDueDate]. If a
/// stray date ever reaches the sheet again, the "no date" assertion fails.
void main() {
  initTestDatabaseFactory();

  late DatabaseService db;
  late TaskController taskController;
  late FolderController folderController;

  setUp(() async {
    db = freshDb();
    taskController = TaskController(db);
    await taskController.load();
    folderController = FolderController(db);
    await folderController.load();
  });

  tearDown(() async {
    taskController.dispose();
    folderController.dispose();
    await db.close();
  });

  Widget host({DateTime? initialDueDate}) {
    return CupertinoApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => CupertinoPageScaffold(
          child: Center(
            child: CupertinoButton(
              child: const Text('open'),
              onPressed: () => showTaskCreationSheet(
                context,
                taskController,
                folderController,
                initialDueDate: initialDueDate,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
      'creation sheet shows no date when none is provided (Tasks + button)',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The date chip falls back to its "Date" placeholder — never a concrete
    // day. This is exactly what must happen when the + is pressed on the Tasks
    // tab after a day was selected over in the Calendar tab.
    expect(find.text('Date'), findsOneWidget);
  });

  testWidgets('creation sheet shows the provided date when one is passed',
      (tester) async {
    // A fixed, unambiguous date so the formatted label can't collide with the
    // "Date" placeholder.
    final due = DateTime(2026, 3, 15);
    await tester.pumpWidget(host(initialDueDate: due));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Date'), findsNothing);
    expect(find.text('Mar 15'), findsOneWidget);
  });
}
