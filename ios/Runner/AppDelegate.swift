import UIKit
import Flutter
import UserNotifications
import EventKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  private var eventKitBridge: EventKitBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    UNUserNotificationCenter.current().delegate = self

    if let controller = window?.rootViewController as? FlutterViewController {
      eventKitBridge = EventKitBridge(messenger: controller.binaryMessenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// Native bridge for the `app.planom/eventkit` MethodChannel. Exposes the
/// device's calendars + events (read/write) to the Dart `EventKitService`.
/// The Dart and macOS sides share this exact protocol; this file is kept in
/// sync with `macos/Runner/MainFlutterWindow.swift`.
final class EventKitBridge: NSObject {
  private let store = EKEventStore()
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "app.planom/eventkit", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "authorizationStatus":
      result(EventKitBridgeShared.statusString())
    case "requestAccess":
      EventKitBridgeShared.requestAccess(store: store) { granted in
        DispatchQueue.main.async { result(granted) }
      }
    case "listCalendars":
      result(EventKitBridgeShared.listCalendars(store: store))
    case "fetchEvents":
      let args = call.arguments as? [String: Any] ?? [:]
      result(EventKitBridgeShared.fetchEvents(store: store, args: args))
    case "createEvent":
      let args = call.arguments as? [String: Any] ?? [:]
      EventKitBridgeShared.createEvent(store: store, args: args, result: result)
    case "updateEvent":
      let args = call.arguments as? [String: Any] ?? [:]
      EventKitBridgeShared.updateEvent(store: store, args: args, result: result)
    case "deleteEvent":
      let args = call.arguments as? [String: Any] ?? [:]
      EventKitBridgeShared.deleteEvent(store: store, args: args, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// Platform-agnostic EventKit logic shared verbatim between the iOS and macOS
/// bridges. Keep the two copies identical.
enum EventKitBridgeShared {
  static func statusString() -> String {
    let status = EKEventStore.authorizationStatus(for: .event)
    switch status {
    case .notDetermined: return "notDetermined"
    case .restricted: return "restricted"
    case .denied: return "denied"
    case .authorized: return "authorized"
    default:
      if #available(iOS 17.0, macOS 14.0, *) {
        switch status {
        case .fullAccess: return "fullAccess"
        case .writeOnly: return "writeOnly"
        default: return "notDetermined"
        }
      }
      return "notDetermined"
    }
  }

  static func requestAccess(store: EKEventStore, completion: @escaping (Bool) -> Void) {
    if #available(iOS 17.0, macOS 14.0, *) {
      store.requestFullAccessToEvents { granted, _ in completion(granted) }
    } else {
      store.requestAccess(to: .event) { granted, _ in completion(granted) }
    }
  }

  static func argb(from cgColor: CGColor?) -> Int {
    guard let cg = cgColor, let comps = cg.components else { return 0xFFFF3B30 }
    let r: CGFloat, g: CGFloat, b: CGFloat
    if comps.count >= 3 {
      r = comps[0]; g = comps[1]; b = comps[2]
    } else {
      // Grayscale.
      r = comps[0]; g = comps[0]; b = comps[0]
    }
    let ri = Int((r * 255).rounded()) & 0xFF
    let gi = Int((g * 255).rounded()) & 0xFF
    let bi = Int((b * 255).rounded()) & 0xFF
    return (0xFF << 24) | (ri << 16) | (gi << 8) | bi
  }

  static func listCalendars(store: EKEventStore) -> [[String: Any]] {
    let defaultId = store.defaultCalendarForNewEvents?.calendarIdentifier
    return store.calendars(for: .event).map { cal in
      [
        "id": cal.calendarIdentifier,
        "title": cal.title,
        "colorArgb": argb(from: cal.cgColor),
        "allowsModify": cal.allowsContentModifications,
        "isPrimary": cal.calendarIdentifier == defaultId,
        "sourceTitle": cal.source?.title ?? "",
      ]
    }
  }

  static func eventMap(_ e: EKEvent) -> [String: Any] {
    var map: [String: Any] = [
      "id": e.eventIdentifier ?? "",
      "calendarId": e.calendar?.calendarIdentifier ?? "",
      "calendarName": e.calendar?.title ?? "",
      "colorArgb": argb(from: e.calendar?.cgColor),
      "title": e.title ?? "",
      "notes": e.notes ?? "",
      "startMs": Int((e.startDate?.timeIntervalSince1970 ?? 0) * 1000),
      "isAllDay": e.isAllDay,
      "isReadOnly": !(e.calendar?.allowsContentModifications ?? false),
      "hasRecurrence": e.hasRecurrenceRules,
    ]
    if let end = e.endDate {
      map["endMs"] = Int(end.timeIntervalSince1970 * 1000)
    }
    return map
  }

  static func fetchEvents(store: EKEventStore, args: [String: Any]) -> [[String: Any]] {
    guard let startMs = args["startMs"] as? Int,
          let endMs = args["endMs"] as? Int,
          let ids = args["calendarIds"] as? [String] else { return [] }
    let all = store.calendars(for: .event)
    let wanted = all.filter { ids.contains($0.calendarIdentifier) }
    if wanted.isEmpty { return [] }
    let start = Date(timeIntervalSince1970: Double(startMs) / 1000)
    let end = Date(timeIntervalSince1970: Double(endMs) / 1000)
    let predicate = store.predicateForEvents(withStart: start, end: end, calendars: wanted)
    return store.events(matching: predicate).map { eventMap($0) }
  }

  static func applyTimes(to e: EKEvent, args: [String: Any]) {
    let isAllDay = (args["isAllDay"] as? Bool) ?? false
    e.isAllDay = isAllDay
    if let startMs = args["startMs"] as? Int {
      e.startDate = Date(timeIntervalSince1970: Double(startMs) / 1000)
    }
    if let endMs = args["endMs"] as? Int {
      e.endDate = Date(timeIntervalSince1970: Double(endMs) / 1000)
    }
  }

  static func createEvent(store: EKEventStore, args: [String: Any], result: @escaping FlutterResult) {
    guard let calId = args["calendarId"] as? String,
          let cal = store.calendar(withIdentifier: calId) else {
      result(FlutterError(code: "no_calendar", message: "Calendar not found", details: nil))
      return
    }
    let e = EKEvent(eventStore: store)
    e.calendar = cal
    e.title = (args["title"] as? String) ?? ""
    e.notes = args["notes"] as? String
    applyTimes(to: e, args: args)
    do {
      try store.save(e, span: .thisEvent, commit: true)
      result(eventMap(e))
    } catch {
      result(FlutterError(code: "save_failed", message: error.localizedDescription, details: nil))
    }
  }

  static func updateEvent(store: EKEventStore, args: [String: Any], result: @escaping FlutterResult) {
    guard let id = args["id"] as? String,
          let e = store.event(withIdentifier: id) else {
      result(FlutterError(code: "not_found", message: "Event not found", details: nil))
      return
    }
    e.title = (args["title"] as? String) ?? e.title
    e.notes = args["notes"] as? String
    applyTimes(to: e, args: args)
    do {
      try store.save(e, span: .thisEvent, commit: true)
      result(eventMap(e))
    } catch {
      result(FlutterError(code: "save_failed", message: error.localizedDescription, details: nil))
    }
  }

  static func deleteEvent(store: EKEventStore, args: [String: Any], result: @escaping FlutterResult) {
    guard let id = args["id"] as? String,
          let e = store.event(withIdentifier: id) else {
      result(false)
      return
    }
    do {
      try store.remove(e, span: .thisEvent, commit: true)
      result(true)
    } catch {
      result(FlutterError(code: "delete_failed", message: error.localizedDescription, details: nil))
    }
  }
}
