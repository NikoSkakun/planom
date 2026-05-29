//
//  Provider.swift
//  PlanomWidget
//
//  Shared timeline provider for every Planom widget. The Flutter app reloads
//  timelines whenever its data changes (via home_widget's updateWidget), so the
//  provider only needs to serve the current snapshot plus a periodic refresh to
//  keep "today" / relative times accurate across midnight and the hour.
//

import WidgetKit

struct WidgetEntry: TimelineEntry {
    let date: Date
    let payload: WidgetPayload?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), payload: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        let payload = context.isPreview ? .sample : (WidgetStore.load() ?? .sample)
        completion(WidgetEntry(date: Date(), payload: payload))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let now = Date()
        let entry = WidgetEntry(date: now, payload: WidgetStore.load())

        // Refresh on the next half-hour boundary, and force one at midnight so
        // the "today" window rolls over even if the app hasn't been opened.
        let cal = Calendar.current
        let inHalfHour = cal.date(byAdding: .minute, value: 30, to: now) ?? now
        let nextMidnight = cal.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? inHalfHour
        let refresh = min(inHalfHour, nextMidnight)

        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}
