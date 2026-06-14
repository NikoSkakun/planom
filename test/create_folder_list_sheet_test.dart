import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/folders/create_folder_list_sheet.dart';
import 'package:planom/src/folders/folder_controller.dart';
import 'package:planom/src/localization/app_localizations.dart';

import 'support/test_db.dart';

/// The create List/Folder sheet hides its optional fields (description,
/// list type, color) behind a "…" toggle next to the Create button.
void main() {
  initTestDatabaseFactory();

  Future<FolderController> openSheet(WidgetTester tester) async {
    final db = freshDb();
    final folder = FolderController(db);
    await tester.runAsync(() => folder.load());

    await tester.pumpWidget(CupertinoApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) => CupertinoButton(
          onPressed: () => showCreateFolderListSheet(context, folder),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return folder;
  }

  testWidgets('optional fields are hidden until the "…" button is tapped',
      (tester) async {
    await openSheet(tester);

    // Default = List. Create button + name field show; optional fields hidden.
    expect(find.text('Create List'), findsOneWidget);
    expect(find.text('List Type'), findsNothing);
    expect(find.text('List Color'), findsNothing);
    expect(find.text('Add a description (optional)'), findsNothing);
    expect(find.byIcon(CupertinoIcons.ellipsis), findsOneWidget);

    // Expand.
    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();
    expect(find.text('List Type'), findsOneWidget);
    expect(find.text('List Color'), findsOneWidget);
    expect(find.text('Add a description (optional)'), findsOneWidget);

    // Collapse again.
    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();
    expect(find.text('List Type'), findsNothing);
    expect(find.text('List Color'), findsNothing);
  });

  testWidgets('a folder exposes only a description when expanded',
      (tester) async {
    await openSheet(tester);

    // Switch to Folder via the type switcher.
    await tester.tap(find.text('Folder'));
    await tester.pumpAndSettle();
    expect(find.text('Create Folder'), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();
    // Folders have a description but no list type / color.
    expect(find.text('Add a description (optional)'), findsOneWidget);
    expect(find.text('List Type'), findsNothing);
    expect(find.text('List Color'), findsNothing);
  });
}
