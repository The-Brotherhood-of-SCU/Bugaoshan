import Foundation
import UserNotifications

/// 本地提醒原生平台投递实现。
///
/// 与 Dart 层排期契约：原生宿主不包含业务规则，仅负责在指定时间戳执行本地通知调度。
///
/// 调度行为：
/// - `syncPlan`：按标识前缀撤销所有存量待投递项并全量注册新计划，未包含在计划内的项自动失效；
/// - `cancelAll`：撤销全部挂起通知并清理持久化缓存。
///
/// 计划数据持久化至 App Group UserDefaults 仅供排查与状态展示；
/// 物理投递完全依赖 UNUserNotificationCenter 注册的 UNNotificationRequest。
/// iOS 系统在设备重启后自动保留已注册的通知请求，无需原生重启恢复广播。
final class ReminderChannel: NSObject {
  static let channelName = "bugaoshan/reminder"

  /// 通知唯一标识前缀。用于按命名空间筛选并撤销通知，避免误删宿主内其他业务通知。
  private static let identifierPrefix = "bugaoshan.reminder."
  private static let appGroupId = "group.io.github.thebrotherhoodofscu.bugaoshan.ios"
  private static let storedPlanKey = "bugaoshan.reminder.plan"

  /// 协议版本号，与 Dart 层 ReminderPlan.schema 对齐；未知版本将直接拒绝处理。
  private static let supportedSchema = 1

  private let center = UNUserNotificationCenter.current()

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "RELEASED", message: "ReminderChannel released", details: nil))
        return
      }
      switch call.method {
      case "syncPlan":
        guard let arguments = call.arguments as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Plan is required", details: nil))
          return
        }
        self.syncPlan(arguments, result: result)
      case "cancelAll":
        self.cancelAll(result: result)
      case "requestAuthorization":
        let provisional = (call.arguments as? [String: Any])?["provisional"] as? Bool ?? false
        self.requestAuthorization(provisional: provisional, result: result)
      case "getPermissionStatus":
        self.getPermissionStatus(result: result)
      case "getPendingCount":
        // 返回系统当前实际挂起的通知数量，供 Dart 层计算实际登记量与截断差值。
        self.getPendingCount(result: result)
      case "openNotificationSettings":
        self.openNotificationSettings(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - 排期

  private func syncPlan(_ payload: [String: Any], result: @escaping FlutterResult) {
    guard let schema = payload["schema"] as? Int, schema == Self.supportedSchema else {
      result(FlutterError(
        code: "UNSUPPORTED_SCHEMA",
        message: "Unsupported reminder plan schema",
        details: payload["schema"]
      ))
      return
    }

    let reminders = payload["reminders"] as? [[String: Any]] ?? []

    center.getNotificationSettings { [weak self] settings in
      guard let self else { return }
      guard settings.authorizationStatus == .authorized ||
        settings.authorizationStatus == .provisional ||
        settings.authorizationStatus == .ephemeral
      else {
        // 未授权状态下终止登记，直接返回 NOT_AUTHORIZED 错误。
        result(FlutterError(
          code: "NOT_AUTHORIZED",
          message: "Notification authorization not granted",
          details: nil
        ))
        return
      }

      // 执行全量替换：先撤销历史挂起项，再注册新计划项。
      self.center.getPendingNotificationRequests { pending in
        let stale = pending
          .map(\.identifier)
          .filter { $0.hasPrefix(Self.identifierPrefix) }
        if !stale.isEmpty {
          self.center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        self.addRequests(reminders) { added in
          self.persistPlan(payload, scheduledCount: added)
          result(added)
        }
      }
    }
  }

  private func addRequests(_ reminders: [[String: Any]], completion: @escaping (Int) -> Void) {
    var remaining = reminders.count
    if remaining == 0 {
      completion(0)
      return
    }

    // 使用锁保护并发写入的完成计数与成功计数。
    var added = 0
    let lock = NSLock()

    for reminder in reminders {
      guard
        let id = reminder["id"] as? String, !id.isEmpty,
        let fireAtMillis = reminder["fireAtMillis"] as? NSNumber
      else {
        lock.lock()
        remaining -= 1
        let done = remaining == 0
        lock.unlock()
        if done { completion(added) }
        continue
      }

      // 过滤已过期的触发时间点，防止因时钟漂移向系统注册无效通知。
      let fireDate = Date(timeIntervalSince1970: fireAtMillis.doubleValue / 1000.0)
      guard fireDate.timeIntervalSinceNow > 0 else {
        lock.lock()
        remaining -= 1
        let done = remaining == 0
        lock.unlock()
        if done { completion(added) }
        continue
      }

      let content = UNMutableNotificationContent()
      content.title = (reminder["title"] as? String) ?? ""
      content.body = (reminder["body"] as? String) ?? ""
      // 显式指定 sound 为 default，确保在锁屏等场景下按声音与震动强提醒，避免降级为静默通知。
      content.sound = .default
      // 按 collapseKey 划分 threadIdentifier，将同一课程的多次提前提醒折叠归并。
      let collapseKey = reminder["collapseKey"] as? String
      if let collapseKey, !collapseKey.isEmpty {
        content.threadIdentifier = collapseKey
      }

      var components = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute, .second],
        from: fireDate
      )
      components.timeZone = TimeZone.current

      let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
      let request = UNNotificationRequest(
        identifier: Self.identifierPrefix + id,
        content: content,
        trigger: trigger
      )

      center.add(request) { error in
        lock.lock()
        if error == nil { added += 1 }
        remaining -= 1
        let done = remaining == 0
        lock.unlock()
        if done { completion(added) }
      }
    }
  }

  private func cancelAll(result: @escaping FlutterResult) {
    center.getPendingNotificationRequests { [weak self] pending in
      guard let self else { return }
      let stale = pending
        .map(\.identifier)
        .filter { $0.hasPrefix(Self.identifierPrefix) }
      if !stale.isEmpty {
        self.center.removePendingNotificationRequests(withIdentifiers: stale)
      }
      self.clearStoredPlan()
      result(nil)
    }
  }

  // MARK: - 授权

  private func requestAuthorization(provisional: Bool, result: @escaping FlutterResult) {
    // provisional 选项请求临时静默通知权限（Provisional Authorization），通知仅进入通知中心且不触发弹窗与声音。
    let options: UNAuthorizationOptions = provisional
      ? [.alert, .sound, .badge, .provisional]
      : [.alert, .sound, .badge]
    center.requestAuthorization(options: options) { granted, error in
      DispatchQueue.main.async {
        if let error {
          result(FlutterError(
            code: "AUTHORIZATION_FAILED",
            message: error.localizedDescription,
            details: nil
          ))
          return
        }
        result(granted)
      }
    }
  }

  private func getPermissionStatus(result: @escaping FlutterResult) {
    center.getNotificationSettings { settings in
      let status: String
      switch settings.authorizationStatus {
      case .authorized: status = "authorized"
      case .provisional: status = "provisional"
      case .ephemeral: status = "ephemeral"
      case .denied: status = "denied"
      case .notDetermined: status = "notDetermined"
      @unknown default: status = "unknown"
      }
      DispatchQueue.main.async { result(status) }
    }
  }

  // MARK: - 落盘（仅供排查与展示）

  /// 查询系统当前处于挂起状态的提醒数量。
  ///
  /// 用于 Dart 层对比下发数量与系统挂起数量，评估系统截断或过滤情况。
  private func getPendingCount(result: @escaping FlutterResult) {
    center.getPendingNotificationRequests { pending in
      let count = pending
        .map(\.identifier)
        .filter { $0.hasPrefix(Self.identifierPrefix) }
        .count
      DispatchQueue.main.async { result(count) }
    }
  }

  // MARK: - 设置跳转

  /// 跳转应用对应的系统设置界面。
  ///
  /// 利用 UIApplication.openSettingsURLString 引导用户手动调整通知权限。
  private func openNotificationSettings(result: @escaping FlutterResult) {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      result(false)
      return
    }
    DispatchQueue.main.async {
      UIApplication.shared.open(url, options: [:]) { opened in
        result(opened)
      }
    }
  }

  private var sharedDefaults: UserDefaults? {
    UserDefaults(suiteName: Self.appGroupId)
  }

  private func persistPlan(_ payload: [String: Any], scheduledCount: Int) {
    guard let defaults = sharedDefaults else { return }
    var summary: [String: Any] = [
      "planId": (payload["planId"] as? String) ?? "",
      "scheduledCount": scheduledCount,
      "requestedCount": (payload["reminders"] as? [[String: Any]])?.count ?? 0,
    ]
    if let windowEnd = payload["windowEndMillis"] as? NSNumber {
      summary["windowEndMillis"] = windowEnd
    }
    defaults.set(summary, forKey: Self.storedPlanKey)
  }

  private func clearStoredPlan() {
    sharedDefaults?.removeObject(forKey: Self.storedPlanKey)
  }
}
