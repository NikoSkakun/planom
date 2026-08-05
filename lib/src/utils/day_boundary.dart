/// Helpers for the user-configurable day boundary (`SettingsController
/// .dayBoundaryHour`). When the user sets a non-zero hour H, a wall-clock time
/// from midnight through H still counts as the previous calendar day — so a
/// task scheduled "for today" at 1 AM is still part of "today" even when the
/// user reads the app at 2:30 AM.
///
/// We're not modelling timezones — the shift is purely how we slice
/// wall-clock time into days for smart-list filtering.
library;

/// Globally-mutable mirror of [SettingsController.dayBoundaryHour] so the
/// controllers (TaskController, RoutineController, EventController …) and
/// view code can call [DayBoundary.todayBase] without taking a Settings
/// dependency. Mirrored from [SettingsController.loadSettings] and bumped on
/// every change to [SettingsController.updateDayBoundaryHour].
class DayBoundary {
  /// ISO weekday (1=Mon … 7=Sun) the user's week starts on — mirrored from
  /// [SettingsController.firstDayOfWeek] so plain controllers can do week
  /// arithmetic without a settings dependency, exactly like [hour].
  static int firstWeekday = DateTime.monday;

  /// Midnight of the first day of the week containing [date], honouring
  /// [firstWeekday]. Uses calendar arithmetic rather than Duration subtraction
  /// so a DST change inside the week can't shift the result by a day.
  static DateTime startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final offset = (day.weekday - firstWeekday + 7) % 7;
    return DateTime(day.year, day.month, day.day - offset);
  }

  DayBoundary._();

  /// 0–23. Default 0 = standard midnight rollover.
  static int hour = 0;

  /// Local date that [now] belongs to after applying the user's boundary
  /// shift. Returns a `DateTime` at 00:00 local time so callers can use it
  /// as the start-of-day key.
  static DateTime startOfTodayFor(DateTime now) {
    if (hour == 0) {
      return DateTime(now.year, now.month, now.day);
    }
    // If we're still before the boundary, "today" is yesterday's calendar day.
    if (now.hour < hour) {
      final shifted = now.subtract(const Duration(days: 1));
      return DateTime(shifted.year, shifted.month, shifted.day);
    }
    return DateTime(now.year, now.month, now.day);
  }

  /// Local date that represents "today" right now.
  static DateTime today() => startOfTodayFor(DateTime.now());

  /// Local date that represents "tomorrow" (the day after [today]).
  static DateTime tomorrow() => today().add(const Duration(days: 1));
}

/// Globally-mutable mirror of [SettingsController.use24hTime] so the top-level
/// [formatDoTime] helper and the Cupertino date/time pickers can read the
/// time-of-day display style without plumbing it through every call site
/// (same pattern as [DayBoundary.hour]). Mirrored from
/// [SettingsController.loadSettings] and bumped on every change to
/// [SettingsController.updateUse24hTime].
class TimeFormatPref {
  TimeFormatPref._();

  /// When true, times render as 24-hour ("14:30"); otherwise AM/PM ("2:30 PM").
  static bool use24h = false;
}
