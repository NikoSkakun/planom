//
//  PlanomWidgetBundle.swift
//  PlanomWidget
//
//  WidgetKit extension entry point. Declares every Planom widget. The `kind`
//  strings must match `kIosWidgetKinds` in lib/src/widgets/widget_keys.dart so
//  the Flutter app can target each timeline for reloads.
//

import SwiftUI
import WidgetKit

@main
struct PlanomWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlanomTodayTasksWidget()
        PlanomAgendaWidget()
        PlanomRoutinesWidget()
        PlanomStatsWidget()
    }
}

// MARK: - Today Tasks

struct PlanomTodayTasksWidget: Widget {
    let kind = "PlanomTodayTasksWidget"

    private var families: [WidgetFamily] {
        var f: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
        if #available(iOSApplicationExtension 16.0, *) {
            f += [.accessoryCircular, .accessoryRectangular, .accessoryInline]
        }
        return f
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TodayTasksEntryView(entry: entry)
        }
        .configurationDisplayName("Today's Tasks")
        .description("Your tasks due today, with quick complete.")
        .supportedFamilies(families)
    }
}

struct TodayTasksEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetEntry

    var body: some View {
        let payload = entry.payload ?? .sample
        switch family {
        case .accessoryCircular:
            if #available(iOSApplicationExtension 16.0, *) {
                AccessoryCircularView(payload: payload)
            }
        case .accessoryRectangular:
            if #available(iOSApplicationExtension 16.0, *) {
                AccessoryRectangularView(payload: payload)
            }
        case .accessoryInline:
            if #available(iOSApplicationExtension 16.0, *) {
                AccessoryInlineView(payload: payload)
            }
        default:
            TodayTasksContent(payload: payload, family: family)
        }
    }
}

// MARK: - Agenda (tasks + events)

struct PlanomAgendaWidget: Widget {
    let kind = "PlanomAgendaWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            AgendaEntryView(entry: entry)
        }
        .configurationDisplayName("Today Agenda")
        .description("Your events and tasks for today in one timeline.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct AgendaEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetEntry
    var body: some View {
        AgendaContent(payload: entry.payload ?? .sample, family: family)
    }
}

// MARK: - Routines

struct PlanomRoutinesWidget: Widget {
    let kind = "PlanomRoutinesWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            RoutinesEntryView(entry: entry)
        }
        .configurationDisplayName("Routines")
        .description("Track today's routines and habits.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct RoutinesEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetEntry
    var body: some View {
        RoutinesContent(payload: entry.payload ?? .sample, family: family)
    }
}

// MARK: - Stats overview

struct PlanomStatsWidget: Widget {
    let kind = "PlanomStatsWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            StatsContent(payload: entry.payload ?? .sample)
        }
        .configurationDisplayName("Overview")
        .description("Remaining tasks, events and inbox at a glance.")
        .supportedFamilies([.systemSmall])
    }
}
