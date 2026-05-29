//
//  WidgetData.swift
//  PlanomWidget
//
//  Decodes the JSON payload the Flutter app writes into the shared App Group
//  container (see lib/src/widgets/widget_data_builder.dart). Keep these models
//  in sync with that builder.
//

import Foundation
import SwiftUI

// MARK: - Decoded payload models

struct WTask: Decodable, Identifiable {
    let id: String
    let title: String
    let minutes: Int?
    let completed: Bool
    let priority: Int
    let overdue: Bool?
    let color: String?
}

struct WEvent: Decodable, Identifiable {
    let id: String
    let title: String
    let minutes: Int?
    let allDay: Bool
    let duration: Int?
}

struct WRoutine: Decodable, Identifiable {
    let id: String
    let name: String
    let color: String
    let done: Bool
    let goalType: String
    let progress: Int?
    let goal: Int?
    let unit: String?
}

struct WBirthday: Decodable {
    let name: String
    let age: Int?
}

struct WCounts: Decodable {
    let todayTasks: Int
    let todayRemaining: Int
    let todayCompleted: Int
    let inbox: Int
    let tomorrowTasks: Int
    let todayEvents: Int
    let birthdays: Int
    let routinesTotal: Int
    let routinesDone: Int
}

struct WidgetPayload: Decodable {
    let updatedAt: Int
    let accentColor: String
    let completionColor: String?
    let spaceName: String
    let locale: String
    let labels: [String: String]
    let counts: WCounts
    let todayTasks: [WTask]
    let tomorrowTasks: [WTask]
    let todayEvents: [WEvent]
    let birthdays: [WBirthday]
    let routines: [WRoutine]

    func label(_ key: String, _ fallback: String) -> String {
        labels[key] ?? fallback
    }

    var accent: Color { Color(hex: accentColor) ?? .orange }
    var completion: Color { Color(hex: completionColor) ?? .green }
    var localeObj: Locale { Locale(identifier: locale) }
}

// MARK: - Shared-store loader

enum WidgetStore {
    static let appGroup = "group.app.planom"
    static let payloadKey = "planom_widget_payload"

    static func load() -> WidgetPayload? {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let raw = defaults.string(forKey: payloadKey),
              let data = raw.data(using: .utf8)
        else { return nil }
        return try? JSONDecoder().decode(WidgetPayload.self, from: data)
    }
}

// MARK: - Helpers

extension Color {
    /// Parses a `#RRGGBB` string.
    init?(hex: String?) {
        guard var h = hex else { return nil }
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = Int(h, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((v >> 16) & 0xFF) / 255.0,
            green: Double((v >> 8) & 0xFF) / 255.0,
            blue: Double(v & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

/// Formats minutes-since-midnight into a locale-aware short time string.
func formattedTime(_ minutes: Int?, locale: Locale) -> String? {
    guard let minutes = minutes else { return nil }
    let cal = Calendar.current
    let start = cal.startOfDay(for: Date())
    let date = cal.date(byAdding: .minute, value: minutes, to: start) ?? start
    let f = DateFormatter()
    f.locale = locale
    f.timeStyle = .short
    f.dateStyle = .none
    return f.string(from: date)
}

// MARK: - Deep links

enum WidgetLink {
    static let scheme = "planom"

    /// Widget URLs must carry a `homeWidget` query item so the home_widget
    /// plugin recognises and forwards them to the Flutter app.
    static func url(_ host: String, id: String? = nil) -> URL {
        var c = URLComponents()
        c.scheme = scheme
        c.host = host
        var items = [URLQueryItem(name: "homeWidget", value: host)]
        if let id = id { items.append(URLQueryItem(name: "id", value: id)) }
        c.queryItems = items
        return c.url ?? URL(string: "\(scheme)://\(host)")!
    }

    static let today = url("today")
    static let calendar = url("calendar")
    static let routines = url("routines")
    static let addTask = url("add-task")
    static func completeTask(_ id: String) -> URL { url("complete-task", id: id) }
    static func recordRoutine(_ id: String) -> URL { url("record-routine", id: id) }
}

// MARK: - Sample data (placeholders / previews)

extension WidgetPayload {
    static let sample = WidgetPayload(
        updatedAt: Int(Date().timeIntervalSince1970),
        accentColor: "#FF4D00",
        completionColor: "#34C759",
        spaceName: "Planom",
        locale: "en",
        labels: [
            "today": "Today", "tomorrow": "Tomorrow", "tasks": "Tasks",
            "events": "Calendar", "routines": "Routines", "inbox": "Inbox",
            "noTasks": "No tasks today", "allDone": "All done!",
            "noEvents": "No events", "noRoutines": "No routines today",
            "agenda": "Today", "addTask": "Add Task", "remaining": "remaining",
            "allDay": "All-day", "birthday": "Birthday", "done": "Done",
        ],
        counts: WCounts(
            todayTasks: 4, todayRemaining: 3, todayCompleted: 1, inbox: 2,
            tomorrowTasks: 5, todayEvents: 2, birthdays: 1,
            routinesTotal: 3, routinesDone: 1
        ),
        todayTasks: [
            WTask(id: "1", title: "Morning standup", minutes: 540,
                  completed: false, priority: 2, overdue: false, color: "#007AFF"),
            WTask(id: "2", title: "Reply to investor email", minutes: nil,
                  completed: false, priority: 3, overdue: true, color: nil),
            WTask(id: "3", title: "Review pull requests", minutes: 840,
                  completed: false, priority: 0, overdue: false, color: "#34C759"),
            WTask(id: "4", title: "Plan the week", minutes: nil,
                  completed: true, priority: 0, overdue: false, color: nil),
        ],
        tomorrowTasks: [],
        todayEvents: [
            WEvent(id: "e1", title: "Dentist", minutes: 600, allDay: false, duration: 60),
            WEvent(id: "e2", title: "Team lunch", minutes: 720, allDay: false, duration: 90),
        ],
        birthdays: [WBirthday(name: "Alex", age: 30)],
        routines: [
            WRoutine(id: "r1", name: "Drink water", color: "#00C7BE",
                     done: false, goalType: "certain_amount", progress: 3, goal: 8, unit: "glasses"),
            WRoutine(id: "r2", name: "Read", color: "#5856D6",
                     done: true, goalType: "achieve_all", progress: 1, goal: nil, unit: nil),
            WRoutine(id: "r3", name: "Workout", color: "#FF2D55",
                     done: false, goalType: "achieve_all", progress: 0, goal: nil, unit: nil),
        ]
    )
}
