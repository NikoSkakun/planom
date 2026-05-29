# Planom iOS Widgets (WidgetKit)

Home-screen and lock-screen widgets for Planom, built with WidgetKit + SwiftUI.
The Flutter app pushes a "Today" snapshot into a shared **App Group** container;
this extension reads it and renders. No database or network access happens in
the extension — it is a pure view over the JSON the app writes.

## Widgets shipped

| Widget (`kind`)              | Families                                                        | Shows |
|------------------------------|-----------------------------------------------------------------|-------|
| `PlanomTodayTasksWidget`     | small, medium, large, + lock-screen circular/rectangular/inline | Today's tasks (incl. overdue), priority dots, list colors, due times. Tap a row → completes it. |
| `PlanomAgendaWidget`         | medium, large                                                   | Today's events **and** tasks merged into one chronological timeline. |
| `PlanomRoutinesWidget`       | small, medium, large                                            | Today's routines with progress; small shows a completion ring. Tap a row → records progress. |
| `PlanomStatsWidget`          | small                                                           | Remaining tasks / events / inbox counts. |

All widgets are localized via labels passed from the app (10 languages) and use
the user's accent color. Tapping a widget deep-links into the relevant screen.

## Data flow

```
Flutter (WidgetDataBuilder)  ──JSON──▶  UserDefaults(suiteName: group.app.planom)
        │  key: planom_widget_payload              │
        │                                          ▼
        └─ HomeWidget.updateWidget(...)  ──▶  WidgetCenter reloads timelines
                                                   │
                                                   ▼
                                   WidgetStore.load() → SwiftUI views
```

The app re-pushes whenever the active space's tasks / events / routines /
contacts change (debounced) — see `lib/src/widgets/`.

## Deep links

Widget taps open `planom://<host>?homeWidget=…`. The `homeWidget` query item is
required so the `home_widget` plugin forwards the URL to Flutter
(`HomeShell._handleWidgetUri`). Hosts: `today`, `calendar`, `routines`,
`add-task`, `add-event`, `complete-task?id=`, `record-routine?id=`.

`complete-task` / `record-routine` open the app and apply the mutation. iOS 17+
interactive controls (in-place toggling without opening the app) are wired
through `HomeWidgetBackgroundWorker` (`AppDelegate` + the Dart
`widgetInteractivityCallback`); to enable true in-widget buttons, add an
`AppIntent` that calls the worker and link `home_widget` into this extension's
Podfile target.

## CI signing (fastlane)

`fastlane/Fastfile` automates the signing for both targets:

- `match` provisions **both** `app.planom` and `app.planom.PlanomWidget`
  (`force: true` so profiles pick up the App Groups entitlement).
- `ensure_signing_prereqs` (App Store Connect API key) creates the widget App
  ID and enables the **App Groups capability** on both App IDs.
- `update_code_signing_settings` assigns each target its own match profile.

**App Group creation/assignment is the one piece the ASC API key cannot do** —
Apple only exposes App Groups over the Developer Portal (Apple-ID) API. Two ways
to satisfy it:

1. **Automated** — set `FASTLANE_USER` + `FASTLANE_PASSWORD` (an app-specific
   password) repo secrets. The Fastfile then creates `group.app.planom` and
   assigns it to both App IDs automatically.
2. **Manual (once)** — in the Developer Portal, create an App Group
   `group.app.planom` and tick it on the `app.planom` and
   `app.planom.PlanomWidget` App IDs. After that the API-key path keeps it
   in sync on its own.

The entitlement files (`Runner.entitlements`, `PlanomWidget.entitlements`)
already declare the group, and `home_widget` is added to the `Runner` pod
target automatically by `pod install`.

The App Group id is defined once in `WidgetData.swift`
(`WidgetStore.appGroup`), `Runner.entitlements`, `PlanomWidget.entitlements`,
and `lib/src/widgets/widget_keys.dart` — keep them identical if you rename it.
