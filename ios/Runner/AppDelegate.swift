import Flutter
import CoreLocation
import EventKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "bugaoshan/update"
  private let calendarEventIdentifierMapKey = "bugaoshan.calendarEventIdentifiers"
  private let eventStore = EKEventStore()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      registerBugaoshanMethodChannel(messenger: controller.binaryMessenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func registerBugaoshanMethodChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "listWritableCalendars":
        self?.listWritableCalendars(result: result)
      case "importIcsToCalendar":
        guard
          let arguments = call.arguments as? [String: Any],
          let events = arguments["events"] as? [[String: Any]],
          !events.isEmpty
        else {
          result(FlutterError(
            code: "INVALID_ARGUMENT",
            message: "Events are empty",
            details: nil
          ))
          return
        }
        self?.importEventsToCalendar(
          events: events,
          calendarIdentifier: arguments["calendarIdentifier"] as? String,
          result: result
        )
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func listWritableCalendars(result: @escaping FlutterResult) {
    // Listing the user's calendars is a read operation. On iOS 17+ that means
    // full calendar access; write-only access can save events but cannot power
    // a user-facing target-calendar picker.
    requestCalendarFullAccess { [weak self] granted, error in
      guard let self else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "APP_DELEGATE_RELEASED",
            message: "Unable to list calendars",
            details: nil
          ))
        }
        return
      }

      DispatchQueue.main.async {
        if let error {
          result(FlutterError(
            code: "CALENDAR_PERMISSION_ERROR",
            message: error.localizedDescription,
            details: nil
          ))
          return
        }
        guard granted else {
          result(FlutterError(
            code: "CALENDAR_PERMISSION_DENIED",
            message: "Calendar full access denied",
            details: nil
          ))
          return
        }

        let defaultIdentifier = self.eventStore
          .defaultCalendarForNewEvents?
          .calendarIdentifier
        let calendars = self.eventStore
          .calendars(for: .event)
          .filter { $0.allowsContentModifications }
          .map { calendar in
            [
              "id": calendar.calendarIdentifier,
              "title": calendar.title,
              "sourceTitle": calendar.source.title,
              "isDefault": calendar.calendarIdentifier == defaultIdentifier,
            ] as [String: Any]
          }
        result(calendars)
      }
    }
  }

  private func importEventsToCalendar(
    events: [[String: Any]],
    calendarIdentifier: String?,
    result: @escaping FlutterResult
  ) {
    // iOS/iPadOS do not provide a public API that silently imports a local
    // .ics file into Calendar. Writing the exported lessons through EventKit
    // gives iPad users a real one-tap import path instead of a file preview.
    requestCalendarAccess(
      needsCalendarList: calendarIdentifier != nil
    ) { [weak self] granted, error in
      guard let self else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "APP_DELEGATE_RELEASED",
            message: "Unable to import calendar events",
            details: nil
          ))
        }
        return
      }
      DispatchQueue.main.async {
        if let error {
          result(FlutterError(
            code: "CALENDAR_PERMISSION_ERROR",
            message: error.localizedDescription,
            details: nil
          ))
          return
        }
        guard granted else {
          result(FlutterError(
            code: "CALENDAR_PERMISSION_DENIED",
            message: "Calendar write access denied",
            details: nil
          ))
          return
        }
        self.saveEvents(
          events,
          calendarIdentifier: calendarIdentifier,
          result: result
        )
      }
    }
  }

  private func requestCalendarAccess(
    needsCalendarList: Bool,
    completion: @escaping (Bool, Error?) -> Void
  ) {
    if needsCalendarList {
      requestCalendarFullAccess(completion: completion)
    } else {
      requestCalendarWriteAccess(completion: completion)
    }
  }

  private func requestCalendarWriteAccess(
    completion: @escaping (Bool, Error?) -> Void
  ) {
    if #available(iOS 17.0, *) {
      eventStore.requestWriteOnlyAccessToEvents(completion: completion)
    } else {
      eventStore.requestAccess(to: .event, completion: completion)
    }
  }

  private func requestCalendarFullAccess(
    completion: @escaping (Bool, Error?) -> Void
  ) {
    if #available(iOS 17.0, *) {
      eventStore.requestFullAccessToEvents(completion: completion)
    } else {
      eventStore.requestAccess(to: .event, completion: completion)
    }
  }

  private func saveEvents(
    _ payloads: [[String: Any]],
    calendarIdentifier: String?,
    result: @escaping FlutterResult
  ) {
    guard let targetCalendar = targetCalendar(identifier: calendarIdentifier) else {
      result(FlutterError(
        code: "NO_WRITABLE_CALENDAR",
        message: "No writable calendar is available",
        details: calendarIdentifier
      ))
      return
    }

    do {
      var existingEvents = existingEventIndex(
        for: payloads,
        targetCalendar: targetCalendar
      )
      var savedUidEvents: [(uid: String, event: EKEvent)] = []
      for (index, payload) in payloads.enumerated() {
        guard let event = makeEvent(
          from: payload,
          targetCalendar: targetCalendar
        ) else {
          result(FlutterError(
            code: "INVALID_EVENT",
            message: "Invalid calendar event payload",
            details: index
          ))
          return
        }
        let eventToSave: EKEvent
        if let existingEvent = matchingExistingEvent(
          for: payload,
          event: event,
          in: existingEvents
        ) {
          copyEventFields(from: event, to: existingEvent)
          eventToSave = existingEvent
        } else {
          eventToSave = event
        }
        try eventStore.save(eventToSave, span: .thisEvent, commit: false)
        if let uid = payload["uid"] as? String, !uid.isEmpty {
          savedUidEvents.append((uid: uid, event: eventToSave))
        }
        for key in eventKeys(for: payload, event: eventToSave) {
          existingEvents[key] = eventToSave
        }
      }
      try eventStore.commit()
      rememberEventIdentifiers(savedUidEvents)
      result("imported")
    } catch {
      result(FlutterError(
        code: "CALENDAR_SAVE_FAILED",
        message: error.localizedDescription,
        details: nil
      ))
    }
  }

  private func targetCalendar(identifier: String?) -> EKCalendar? {
    guard let identifier, !identifier.isEmpty else {
      return eventStore.defaultCalendarForNewEvents
    }
    guard
      let calendar = eventStore.calendar(withIdentifier: identifier),
      calendar.allowsContentModifications
    else {
      return nil
    }
    return calendar
  }

  private func makeEvent(
    from payload: [String: Any],
    targetCalendar: EKCalendar
  ) -> EKEvent? {
    guard
      let title = payload["title"] as? String,
      let startComponents = payload["start"] as? [String: Any],
      let endComponents = payload["end"] as? [String: Any]
    else {
      return nil
    }

    let timeZoneIdentifier = payload["timeZone"] as? String ?? "Asia/Shanghai"
    let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
    guard
      let startDate = date(from: startComponents, timeZone: timeZone),
      let endDate = date(from: endComponents, timeZone: timeZone)
    else {
      return nil
    }

    let event = EKEvent(eventStore: eventStore)
    event.title = title
    event.location = payload["location"] as? String
    event.notes = payload["notes"] as? String
    event.startDate = startDate
    event.endDate = endDate
    event.timeZone = timeZone
    event.calendar = targetCalendar
    event.structuredLocation = structuredLocation(from: payload)
    return event
  }

  private func existingEventIndex(
    for payloads: [[String: Any]],
    targetCalendar: EKCalendar
  ) -> [String: EKEvent] {
    guard let dateRange = eventDateRange(for: payloads) else {
      return [:]
    }

    let predicate = eventStore.predicateForEvents(
      withStart: dateRange.start,
      end: dateRange.end,
      calendars: [targetCalendar]
    )
    var index: [String: EKEvent] = [:]
    for event in eventStore.events(matching: predicate) {
      for key in eventKeys(for: event) {
        index[key] = event
      }
    }
    return index
  }

  private func eventDateRange(
    for payloads: [[String: Any]]
  ) -> (start: Date, end: Date)? {
    var starts: [Date] = []
    var ends: [Date] = []
    for payload in payloads {
      let timeZoneIdentifier = payload["timeZone"] as? String ?? "Asia/Shanghai"
      let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
      guard
        let startComponents = payload["start"] as? [String: Any],
        let endComponents = payload["end"] as? [String: Any],
        let start = date(from: startComponents, timeZone: timeZone),
        let end = date(from: endComponents, timeZone: timeZone)
      else {
        continue
      }
      starts.append(start)
      ends.append(end)
    }

    guard let start = starts.min(), let end = ends.max() else {
      return nil
    }
    let calendar = Calendar.current
    guard
      let endOfDay = calendar.date(
        byAdding: .day,
        value: 1,
        to: calendar.startOfDay(for: end)
      )
    else {
      return nil
    }
    return (
      start: calendar.startOfDay(for: start),
      end: endOfDay
    )
  }

  private func matchingExistingEvent(
    for payload: [String: Any],
    event: EKEvent,
    in existingEvents: [String: EKEvent]
  ) -> EKEvent? {
    if
      let uid = payload["uid"] as? String,
      !uid.isEmpty,
      let mappedEvent = eventForUid(uid, targetCalendar: event.calendar)
    {
      return mappedEvent
    }
    for key in eventKeys(for: payload, event: event) {
      if let existingEvent = existingEvents[key] {
        return existingEvent
      }
    }
    return nil
  }

  private func eventForUid(
    _ uid: String,
    targetCalendar: EKCalendar
  ) -> EKEvent? {
    // EventKit has no writable hidden UID field. Keep an app-local UID map so
    // repeated imports update events without exposing internal links in Calendar.
    guard let eventIdentifier = storedEventIdentifiers()[uid] else {
      return nil
    }
    guard let event = eventStore.event(withIdentifier: eventIdentifier) else {
      forgetEventIdentifier(for: uid)
      return nil
    }
    guard event.calendar.calendarIdentifier == targetCalendar.calendarIdentifier else {
      return nil
    }
    return event
  }

  private func rememberEventIdentifiers(
    _ uidEvents: [(uid: String, event: EKEvent)]
  ) {
    var identifiers = storedEventIdentifiers()
    for uidEvent in uidEvents {
      if let eventIdentifier = uidEvent.event.eventIdentifier {
        identifiers[uidEvent.uid] = eventIdentifier
      }
    }
    UserDefaults.standard.set(identifiers, forKey: calendarEventIdentifierMapKey)
  }

  private func forgetEventIdentifier(for uid: String) {
    var identifiers = storedEventIdentifiers()
    identifiers.removeValue(forKey: uid)
    UserDefaults.standard.set(identifiers, forKey: calendarEventIdentifierMapKey)
  }

  private func storedEventIdentifiers() -> [String: String] {
    UserDefaults.standard.dictionary(
      forKey: calendarEventIdentifierMapKey
    ) as? [String: String] ?? [:]
  }

  private func copyEventFields(from source: EKEvent, to target: EKEvent) {
    target.title = source.title
    target.location = source.location
    target.notes = source.notes
    target.startDate = source.startDate
    target.endDate = source.endDate
    target.timeZone = source.timeZone
    target.calendar = source.calendar
    target.structuredLocation = source.structuredLocation
    target.url = nil
  }

  private func eventKeys(for payload: [String: Any], event: EKEvent) -> [String] {
    var keys: [String] = []
    if let uid = payload["uid"] as? String, !uid.isEmpty {
      keys.append("uid:\(uid)")
    }
    if let contentKey = contentKey(for: event) {
      keys.append(contentKey)
    }
    return keys
  }

  private func eventKeys(for event: EKEvent) -> [String] {
    var keys: [String] = []
    if let uid = uid(from: event.url) {
      keys.append("uid:\(uid)")
    }
    if let contentKey = contentKey(for: event) {
      keys.append(contentKey)
    }
    return keys
  }

  private func uid(from url: URL?) -> String? {
    guard
      let url,
      url.scheme == "bugaoshan",
      url.host == "calendar-event"
    else {
      return nil
    }

    let uid = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    if uid.isEmpty {
      return nil
    }
    return uid.removingPercentEncoding ?? uid
  }

  private func contentKey(for event: EKEvent) -> String? {
    guard
      let title = event.title,
      let startDate = event.startDate,
      let endDate = event.endDate
    else {
      return nil
    }
    return [
      "content",
      title,
      String(Int(startDate.timeIntervalSince1970)),
      String(Int(endDate.timeIntervalSince1970)),
    ].joined(separator: "|")
  }

  private func structuredLocation(
    from payload: [String: Any]
  ) -> EKStructuredLocation? {
    guard
      let locationPayload = payload["structuredLocation"] as? [String: Any],
      let title = locationPayload["title"] as? String,
      let latitude = doubleValue(locationPayload["latitude"]),
      let longitude = doubleValue(locationPayload["longitude"])
    else {
      return nil
    }

    let structuredLocation = EKStructuredLocation(title: title)
    structuredLocation.geoLocation = CLLocation(
      latitude: latitude,
      longitude: longitude
    )
    if let radius = doubleValue(locationPayload["radius"]) {
      structuredLocation.radius = radius
    }
    return structuredLocation
  }

  private func date(
    from payload: [String: Any],
    timeZone: TimeZone
  ) -> Date? {
    guard
      let year = intValue(payload["year"]),
      let month = intValue(payload["month"]),
      let day = intValue(payload["day"]),
      let hour = intValue(payload["hour"]),
      let minute = intValue(payload["minute"])
    else {
      return nil
    }

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar.date(from: DateComponents(
      timeZone: timeZone,
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute
    ))
  }

  private func intValue(_ value: Any?) -> Int? {
    if let value = value as? Int {
      return value
    }
    if let value = value as? NSNumber {
      return value.intValue
    }
    return nil
  }

  private func doubleValue(_ value: Any?) -> Double? {
    if let value = value as? Double {
      return value
    }
    if let value = value as? NSNumber {
      return value.doubleValue
    }
    return nil
  }
}
