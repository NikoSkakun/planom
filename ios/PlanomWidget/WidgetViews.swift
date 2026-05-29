//
//  WidgetViews.swift
//  PlanomWidget
//
//  Reusable SwiftUI building blocks + per-widget content layouts.
//

import SwiftUI
import WidgetKit

// MARK: - Background helper (iOS 17 containerBackground requirement)

extension View {
    @ViewBuilder
    func planomWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) { Color(.systemBackground) }
        } else {
            self.background(Color(.systemBackground))
        }
    }
}

// MARK: - Empty / missing-data state

struct PlaceholderView: View {
    let message: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.title2)
                .foregroundColor(.secondary)
            Text(message)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Header

struct WidgetHeader: View {
    let title: String
    let systemImage: String
    let accent: Color
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(accent)
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.primary)
            Spacer(minLength: 4)
            if let trailing = trailing {
                Text(trailing)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Priority dot

struct PriorityDot: View {
    let priority: Int
    var body: some View {
        let color: Color = {
            switch priority {
            case 3: return .red
            case 2: return .orange
            case 1: return .yellow
            default: return .clear
            }
        }()
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
    }
}

// MARK: - Rows

struct TaskRowView: View {
    let task: WTask
    let payload: WidgetPayload

    var body: some View {
        Link(destination: WidgetLink.completeTask(task.id)) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(
                            task.completed ? payload.completion : Color.secondary.opacity(0.6),
                            lineWidth: 1.6
                        )
                        .frame(width: 16, height: 16)
                    if task.completed {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(payload.completion)
                            .frame(width: 16, height: 16)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                if let color = Color(hex: task.color) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(color)
                        .frame(width: 3, height: 14)
                }
                Text(task.title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .foregroundColor(task.completed ? .secondary : .primary)
                Spacer(minLength: 2)
                if task.priority > 0 && !task.completed {
                    PriorityDot(priority: task.priority)
                }
                if let time = formattedTime(task.minutes, locale: payload.localeObj) {
                    Text(time)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor((task.overdue ?? false) ? .red : .secondary)
                }
            }
        }
    }
}

struct EventRowView: View {
    let event: WEvent
    let payload: WidgetPayload
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.blue)
                .frame(width: 3, height: 14)
            Text(event.title)
                .font(.system(size: 13))
                .lineLimit(1)
                .foregroundColor(.primary)
            Spacer(minLength: 2)
            Text(event.allDay
                 ? payload.label("allDay", "All-day")
                 : (formattedTime(event.minutes, locale: payload.localeObj) ?? ""))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

struct RoutineRowView: View {
    let routine: WRoutine
    let payload: WidgetPayload

    private var color: Color { Color(hex: routine.color) ?? payload.accent }

    var body: some View {
        Link(destination: WidgetLink.recordRoutine(routine.id)) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(routine.done ? 1.0 : 0.18))
                        .frame(width: 22, height: 22)
                    Image(systemName: routine.done ? "checkmark" : "circle")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(routine.done ? .white : color)
                }
                Text(routine.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .foregroundColor(routine.done ? .secondary : .primary)
                Spacer(minLength: 2)
                if routine.goalType == "certain_amount", let goal = routine.goal {
                    Text("\(routine.progress ?? 0)/\(goal)\(routine.unit.map { " \($0)" } ?? "")")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Today Tasks content

struct TodayTasksContent: View {
    let payload: WidgetPayload
    let family: WidgetFamily

    private var limit: Int {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 4
        default: return 8
        }
    }

    var body: some View {
        let tasks = payload.todayTasks
        VStack(alignment: .leading, spacing: family == .systemSmall ? 4 : 7) {
            WidgetHeader(
                title: payload.label("today", "Today"),
                systemImage: "checklist",
                accent: payload.accent,
                trailing: payload.counts.todayRemaining > 0
                    ? "\(payload.counts.todayRemaining)" : nil
            )
            if tasks.isEmpty {
                PlaceholderView(message: payload.label("noTasks", "No tasks today"))
            } else {
                ForEach(tasks.prefix(limit)) { TaskRowView(task: $0, payload: payload) }
                let extra = tasks.count - limit
                if extra > 0 {
                    Text("+\(extra)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(family == .systemSmall ? 12 : 14)
        .planomWidgetBackground()
        .widgetURL(WidgetLink.today)
    }
}

// MARK: - Agenda content (events + tasks merged chronologically)

private enum AgendaItem: Identifiable {
    case event(WEvent)
    case task(WTask)

    var id: String {
        switch self {
        case .event(let e): return "e_" + e.id
        case .task(let t): return "t_" + t.id
        }
    }
    /// Sort key: timed items by minute, untimed pushed to the end.
    var sortKey: Int {
        switch self {
        case .event(let e): return e.minutes ?? 100_000
        case .task(let t): return t.minutes ?? 100_001
        }
    }
}

struct AgendaContent: View {
    let payload: WidgetPayload
    let family: WidgetFamily

    private var limit: Int { family == .systemMedium ? 4 : 9 }

    private var items: [AgendaItem] {
        var merged: [AgendaItem] = payload.todayEvents.map { .event($0) }
        merged += payload.todayTasks.filter { !$0.completed }.map { .task($0) }
        return merged.sorted { $0.sortKey < $1.sortKey }
    }

    var body: some View {
        let all = items
        VStack(alignment: .leading, spacing: 7) {
            WidgetHeader(
                title: payload.label("agenda", "Today"),
                systemImage: "calendar",
                accent: payload.accent,
                trailing: trailingSummary
            )
            if all.isEmpty {
                PlaceholderView(message: payload.label("allDone", "All done!"))
            } else {
                ForEach(all.prefix(limit)) { item in
                    switch item {
                    case .event(let e): EventRowView(event: e, payload: payload)
                    case .task(let t): TaskRowView(task: t, payload: payload)
                    }
                }
                let extra = all.count - limit
                if extra > 0 {
                    Text("+\(extra)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .planomWidgetBackground()
        .widgetURL(WidgetLink.calendar)
    }

    private var trailingSummary: String {
        let e = payload.counts.todayEvents
        let t = payload.counts.todayRemaining
        return "\(e) · \(t)"
    }
}

// MARK: - Routines content

struct RoutinesContent: View {
    let payload: WidgetPayload
    let family: WidgetFamily

    var body: some View {
        if family == .systemSmall {
            smallBody
        } else {
            listBody
        }
    }

    private var smallBody: some View {
        let total = payload.counts.routinesTotal
        let done = payload.counts.routinesDone
        let progress = total == 0 ? 0 : Double(done) / Double(total)
        return VStack(alignment: .leading, spacing: 6) {
            WidgetHeader(title: payload.label("routines", "Routines"),
                         systemImage: "repeat", accent: payload.accent)
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(payload.accent.opacity(0.18), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(payload.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(done)/\(total)")
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .planomWidgetBackground()
        .widgetURL(WidgetLink.routines)
    }

    private var listBody: some View {
        let routines = payload.routines
        let limit = family == .systemMedium ? 4 : 9
        return VStack(alignment: .leading, spacing: 7) {
            WidgetHeader(
                title: payload.label("routines", "Routines"),
                systemImage: "repeat",
                accent: payload.accent,
                trailing: "\(payload.counts.routinesDone)/\(payload.counts.routinesTotal)"
            )
            if routines.isEmpty {
                PlaceholderView(message: payload.label("noRoutines", "No routines today"))
            } else {
                ForEach(routines.prefix(limit)) { RoutineRowView(routine: $0, payload: payload) }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .planomWidgetBackground()
        .widgetURL(WidgetLink.routines)
    }
}

// MARK: - Stats content (small overview)

struct StatsContent: View {
    let payload: WidgetPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(title: payload.spaceName,
                         systemImage: "square.grid.2x2", accent: payload.accent)
            Spacer(minLength: 0)
            statRow(value: payload.counts.todayRemaining,
                    label: payload.label("today", "Today"), color: payload.accent)
            statRow(value: payload.counts.todayEvents,
                    label: payload.label("events", "Calendar"), color: .blue)
            statRow(value: payload.counts.inbox,
                    label: payload.label("inbox", "Inbox"), color: .gray)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .planomWidgetBackground()
        .widgetURL(WidgetLink.today)
    }

    private func statRow(value: Int, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
                .frame(minWidth: 26, alignment: .leading)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - Lock-screen accessory views (iOS 16+)

@available(iOSApplicationExtension 16.0, *)
struct AccessoryCircularView: View {
    let payload: WidgetPayload
    var body: some View {
        let total = max(payload.counts.todayTasks, 1)
        let done = payload.counts.todayCompleted
        Gauge(value: Double(done), in: 0...Double(total)) {
            Image(systemName: "checklist")
        } currentValueLabel: {
            Text("\(payload.counts.todayRemaining)")
        }
        .gaugeStyle(.accessoryCircular)
    }
}

@available(iOSApplicationExtension 16.0, *)
struct AccessoryRectangularView: View {
    let payload: WidgetPayload
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "checklist").font(.system(size: 11, weight: .bold))
                Text(payload.label("today", "Today"))
                    .font(.system(size: 13, weight: .semibold))
            }
            if let first = payload.todayTasks.first(where: { !$0.completed }) {
                Text(first.title).font(.system(size: 12)).lineLimit(1)
            } else if let ev = payload.todayEvents.first {
                Text(ev.title).font(.system(size: 12)).lineLimit(1)
            } else {
                Text(payload.label("allDone", "All done!"))
                    .font(.system(size: 12)).foregroundColor(.secondary)
            }
            Text("\(payload.counts.todayRemaining) · \(payload.counts.todayEvents)")
                .font(.system(size: 11)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOSApplicationExtension 16.0, *)
struct AccessoryInlineView: View {
    let payload: WidgetPayload
    var body: some View {
        Label("\(payload.counts.todayRemaining) \(payload.label("tasks", "Tasks"))",
              systemImage: "checklist")
    }
}
