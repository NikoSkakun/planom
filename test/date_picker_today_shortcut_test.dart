import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/localization/app_localizations.dart';
import 'package:planom/src/tasks/calendar_date_picker.dart';
import 'package:planom/src/utils/date_wheel_picker.dart';

/// Both date pickers must offer a way back to today once the user has moved
/// away from it — the wheels give no other route home, and the calendar grid
/// would otherwise have to be paged back a month at a time.
void main() {
  DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Widget host(VoidCallback Function(BuildContext) onPressed) {
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
              onPressed: onPressed(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  group('wheel date picker (routine start date, finance entry date)', () {
    testWidgets('Today snaps the wheels back and is the value Done returns',
        (tester) async {
      DateTime? result;
      await tester.pumpWidget(host((context) => () async {
            result = await showDateWheelPicker(
              context,
              initial: today().subtract(const Duration(days: 60)),
            );
          }));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Parked two months back: the shortcut is offered.
      expect(find.text('Today'), findsOneWidget);
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      // Already on today — nothing left to jump to.
      expect(find.text('Today'), findsNothing);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(result, today());
    });

    testWidgets('no shortcut when the picker already opens on today',
        (tester) async {
      await tester.pumpWidget(host((context) => () {
            showDateWheelPicker(context, initial: today());
          }));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsNothing);
    });

    testWidgets('no shortcut when today is outside the allowed range',
        (tester) async {
      await tester.pumpWidget(host((context) => () {
            final cutoff = today().subtract(const Duration(days: 30));
            showDateWheelPicker(
              context,
              initial: cutoff.subtract(const Duration(days: 60)),
              maximumDate: cutoff,
            );
          }));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsNothing);
    });
  });

  group('calendar grid picker', () {
    // The grid's shortcut lives inside the PageView; the commit-and-close
    // "Today" chip sits above it, so scope the finder to the month header.
    Finder headerToday() => find.descendant(
          of: find.byType(PageView),
          matching: find.text('Today'),
        );

    testWidgets('paging away from the current month reveals a jump back',
        (tester) async {
      await tester.pumpWidget(host((context) => () {
            showCalendarDatePicker(
              context,
              initial: DateTime(today().year + 1, today().month, 15),
            );
          }));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(headerToday(), findsOneWidget);
      await tester.tap(headerToday());
      await tester.pumpAndSettle();
      // Back on the current month, so the jump is gone.
      expect(headerToday(), findsNothing);
    });

    testWidgets('the current month shows no jump button', (tester) async {
      await tester.pumpWidget(host((context) => () {
            showCalendarDatePicker(context, initial: today());
          }));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(headerToday(), findsNothing);
      // The commit-and-close quick chip is still there.
      expect(find.text('Today'), findsOneWidget);
    });
  });
}
