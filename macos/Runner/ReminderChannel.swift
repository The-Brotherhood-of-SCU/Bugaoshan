import Cocoa
import FlutterMacOS
import UserNotifications

/// macOS delivery host for the business-free Dart reminder plan protocol.
final class ReminderChannel: NSObject, UNUserNotificationCenterDelegate {
  private static let prefix = "bugaoshan.reminder."
  private static let storedPlanKey = "bugaoshan.reminder.plan"
  private let center = UNUserNotificationCenter.current()
  // Keep asynchronous full replacements and cancellations in arrival order.
  private var mutations: [() -> Void] = []

  func register(messenger: FlutterBinaryMessenger) {
    center.delegate = self
    let channel = FlutterMethodChannel(name: "bugaoshan/reminder", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "RELEASED", message: "Reminder host released", details: nil))
        return
      }
      switch call.method {
      case "requestAuthorization":
        // Mac uses explicit authorization; iOS-only provisional input is ignored.
        self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
          if let error {
            self.reply(result, FlutterError(code: "AUTHORIZATION_FAILED", message: error.localizedDescription, details: nil))
          } else {
            self.reply(result, granted)
          }
        }
      case "getPermissionStatus":
        self.center.getNotificationSettings { settings in
          let status: String
          switch settings.authorizationStatus {
          case .authorized: status = "authorized"
          case .provisional: status = "provisional"
          case .denied: status = "denied"
          case .notDetermined: status = "notDetermined"
          @unknown default: status = "unknown"
          }
          self.reply(result, status)
        }
      case "syncPlan":
        guard let payload = call.arguments as? [String: Any],
              payload["schema"] as? Int == 1,
              let reminders = payload["reminders"] as? [[String: Any]] else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid reminder plan", details: nil))
          return
        }
        self.enqueue(result: result) { complete in
          self.syncPlan(reminders, payload: payload, result: complete)
        }
      case "cancelAll":
        self.enqueue(result: result) { complete in
          self.center.getPendingNotificationRequests { pending in
            self.center.removePendingNotificationRequests(
              withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
            )
            UserDefaults.standard.removeObject(forKey: Self.storedPlanKey)
            complete(nil)
          }
        }
      case "getPendingCount":
        self.enqueue(result: result) { complete in
          self.center.getPendingNotificationRequests { pending in
            complete(pending.filter { $0.identifier.hasPrefix(Self.prefix) }.count)
          }
        }
      case "openNotificationSettings":
        let identifier = Bundle.main.bundleIdentifier ?? ""
        let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(identifier)")!
        result(NSWorkspace.shared.open(url))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func reply(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async { result(value) }
  }

  private func enqueue(
    result: @escaping FlutterResult,
    operation: @escaping (@escaping FlutterResult) -> Void
  ) {
    mutations.append {
      operation { value in
        DispatchQueue.main.async {
          result(value)
          self.mutations.removeFirst()
          self.mutations.first?()
        }
      }
    }
    if mutations.count == 1 { mutations.first?() }
  }

  private func syncPlan(
    _ reminders: [[String: Any]], payload: [String: Any], result: @escaping FlutterResult
  ) {
    // Validate before removing the previous plan. Ignore elapsed timestamps as on iOS.
    var requests: [UNNotificationRequest] = []
    var identifiers = Set<String>()
    for reminder in reminders {
      guard let id = reminder["id"] as? String, !id.isEmpty,
            identifiers.insert(id).inserted,
            let timestamp = reminder["fireAtMillis"] as? NSNumber,
            timestamp.doubleValue.isFinite else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid reminder", details: nil))
        return
      }
      let date = Date(timeIntervalSince1970: timestamp.doubleValue / 1000)
      guard date > Date() else { continue }
      let content = UNMutableNotificationContent()
      content.title = reminder["title"] as? String ?? ""
      content.body = reminder["body"] as? String ?? ""
      content.sound = .default
      content.threadIdentifier = reminder["collapseKey"] as? String ?? ""
      var components = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute, .second], from: date
      )
      components.timeZone = .current
      requests.append(UNNotificationRequest(
        identifier: Self.prefix + id,
        content: content,
        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
      ))
    }

    // Query without prompting: only a deliberate authorization action may show UI.
    center.getNotificationSettings { settings in
      guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
        result(FlutterError(code: "NOT_AUTHORIZED", message: "Notification authorization not granted", details: nil))
        return
      }
      self.center.getPendingNotificationRequests { pending in
        self.center.removePendingNotificationRequests(
          withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        )
        self.add(requests) { value in
          if let count = value as? Int {
            // Diagnostics only: the OS owns the persistent pending requests.
            var summary: [String: Any] = [
              "planId": payload["planId"] as? String ?? "",
              "requestedCount": reminders.count,
              "scheduledCount": count,
            ]
            summary["windowEndMillis"] = payload["windowEndMillis"]
            UserDefaults.standard.set(summary, forKey: Self.storedPlanKey)
          }
          result(value)
        }
      }
    }
  }

  private func add(_ requests: [UNNotificationRequest], result: @escaping FlutterResult) {
    guard !requests.isEmpty else { result(0); return }
    let group = DispatchGroup()
    let lock = NSLock()
    var firstError: Error?
    for request in requests {
      group.enter()
      center.add(request) { error in
        lock.lock()
        if firstError == nil { firstError = error }
        lock.unlock()
        group.leave()
      }
    }
    group.notify(queue: .main) {
      if let error = firstError {
        result(FlutterError(code: "SCHEDULE_FAILED", message: error.localizedDescription, details: nil))
      } else {
        result(requests.count)
      }
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Foreground reminders use the same banner and sound as background delivery.
    completionHandler(notification.request.identifier.hasPrefix(Self.prefix) ? [.banner, .list, .sound] : [])
  }
}
