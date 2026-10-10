import ActivityKit
import Flutter
import Foundation
import UIKit

/// 灵动岛与锁屏实时活动（Live Activity）MethodChannel 原生实现。
///
/// 与 Dart 层接口契约：
/// - 依赖 iOS 16.1 及以上版本的 ActivityKit 框架；
/// - 前台约束：调用 `start` 时宿主应用必须处于前台活跃状态（`UIApplication.shared.applicationState == .active`）；
/// - 系统级渲染：倒计时展示在 WidgetExtension 侧通过 `Text(timerInterval:countsDown:)` 自动渲染，原生宿主不维持高频 update；
/// - 生命周期管理：课程状态变更与下课时分别调用 `update` 与 `end` 对齐会话状态。
final class LiveActivityChannel: NSObject {
  static let channelName = "bugaoshan/live_activity"

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(
          FlutterError(
            code: "RELEASED",
            message: "LiveActivityChannel released",
            details: nil
          )
        )
        return
      }

      if #available(iOS 16.1, *) {
        self.handleCall(call, result: result)
      } else {
        if call.method == "isSupported" {
          result(false)
        } else {
          result(
            FlutterError(
              code: "UNSUPPORTED_PLATFORM",
              message: "Live Activities require iOS 16.1 or later",
              details: nil
            )
          )
        }
      }
    }
  }

  // MARK: - 方法分发（iOS 16.1+）

  @available(iOS 16.1, *)
  private func handleCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      isSupported(result: result)
    case "start":
      guard let arguments = call.arguments as? [String: Any] else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENT",
            message: "Arguments are required for start",
            details: nil
          )
        )
        return
      }
      start(arguments: arguments, result: result)
    case "update":
      guard let arguments = call.arguments as? [String: Any] else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENT",
            message: "Arguments are required for update",
            details: nil
          )
        )
        return
      }
      update(arguments: arguments, result: result)
    case "end":
      end(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - 能力检测与授权

  @available(iOS 16.1, *)
  private func isSupported(result: @escaping FlutterResult) {
    // 读取系统级与应用级实时活动授权状态。
    let areActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    result(areActivitiesEnabled)
  }

  // MARK: - 启动实时活动

  @available(iOS 16.1, *)
  private func start(arguments: [String: Any], result: @escaping FlutterResult) {
    // 状态前置校验：ActivityKit 限制实时活动仅能在应用处于前台活跃状态时启动。
    // 在非活跃状态下直接返回 NOT_IN_FOREGROUND 错误码。
    guard UIApplication.shared.applicationState == .active else {
      result(
        FlutterError(
          code: "NOT_IN_FOREGROUND",
          message: "Live Activity can only be started while the application is in foreground",
          details: nil
        )
      )
      return
    }

    // 校验用户是否在系统设置中启用了实时活动权限。
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      result(
        FlutterError(
          code: "NOT_AUTHORIZED",
          message: "Live Activities are disabled in system settings",
          details: nil
        )
      )
      return
    }

    guard
      let courseName = arguments["courseName"] as? String, !courseName.isEmpty,
      let location = arguments["location"] as? String,
      let endAtMillis = arguments["endAtMillis"] as? NSNumber
    else {
      result(
        FlutterError(
          code: "INVALID_ARGUMENT",
          message: "courseName, location and endAtMillis are required",
          details: nil
        )
      )
      return
    }

    let startAtMillis = arguments["startAtMillis"] as? NSNumber
    let startDate: Date
    if let startAtMillis {
      startDate = Date(timeIntervalSince1970: startAtMillis.doubleValue / 1000.0)
    } else {
      startDate = Date()
    }
    let endDate = Date(timeIntervalSince1970: endAtMillis.doubleValue / 1000.0)

    let nextCourseName = arguments["nextCourseName"] as? String
    let nextLocation = arguments["nextLocation"] as? String

    // 单一活动策略：启动前清理历史会话，确保同一时刻仅维持唯一的课程实时活动。
    cleanExistingActivities()

    let attributes = CourseLiveActivityAttributes(sessionId: "current_course")
    let contentState = CourseLiveActivityAttributes.ContentState(
      courseName: courseName,
      location: location,
      startAt: startDate,
      endAt: endDate,
      nextCourseName: nextCourseName,
      nextLocation: nextLocation
    )

    do {
      if #available(iOS 16.2, *) {
        let content = ActivityContent(state: contentState, staleDate: endDate)
        let activity = try Activity<CourseLiveActivityAttributes>.request(
          attributes: attributes,
          content: content
        )
        result(activity.id)
      } else {
        let activity = try Activity<CourseLiveActivityAttributes>.request(
          attributes: attributes,
          contentState: contentState
        )
        result(activity.id)
      }
    } catch {
      result(
        FlutterError(
          code: "ACTIVITY_START_FAILED",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  // MARK: - 更新实时活动

  @available(iOS 16.1, *)
  private func update(arguments: [String: Any], result: @escaping FlutterResult) {
    guard let activity = Activity<CourseLiveActivityAttributes>.activities.first else {
      result(
        FlutterError(
          code: "NO_ACTIVE_ACTIVITY",
          message: "No active Live Activity found to update",
          details: nil
        )
      )
      return
    }

    // 增量合并：以既有状态为基准合并入参字段。
    let currentState: CourseLiveActivityAttributes.ContentState
    if #available(iOS 16.2, *) {
      currentState = activity.content.state
    } else {
      currentState = activity.contentState
    }

    let courseName = (arguments["courseName"] as? String) ?? currentState.courseName
    let location = (arguments["location"] as? String) ?? currentState.location

    let startDate: Date
    if let startAtMillis = arguments["startAtMillis"] as? NSNumber {
      startDate = Date(timeIntervalSince1970: startAtMillis.doubleValue / 1000.0)
    } else {
      startDate = currentState.startAt
    }

    let endDate: Date
    if let endAtMillis = arguments["endAtMillis"] as? NSNumber {
      endDate = Date(timeIntervalSince1970: endAtMillis.doubleValue / 1000.0)
    } else {
      endDate = currentState.endAt
    }

    let nextCourseName = (arguments["nextCourseName"] as? String) ?? currentState.nextCourseName
    let nextLocation = (arguments["nextLocation"] as? String) ?? currentState.nextLocation

    let newState = CourseLiveActivityAttributes.ContentState(
      courseName: courseName,
      location: location,
      startAt: startDate,
      endAt: endDate,
      nextCourseName: nextCourseName,
      nextLocation: nextLocation
    )

    Task {
      if #available(iOS 16.2, *) {
        let content = ActivityContent(state: newState, staleDate: endDate)
        await activity.update(content)
      } else {
        await activity.update(using: newState)
      }
      DispatchQueue.main.async {
        result(nil)
      }
    }
  }

  // MARK: - 结束实时活动

  @available(iOS 16.1, *)
  private func end(result: @escaping FlutterResult) {
    let activities = Activity<CourseLiveActivityAttributes>.activities
    guard !activities.isEmpty else {
      result(nil)
      return
    }

    Task {
      for activity in activities {
        if #available(iOS 16.2, *) {
          await activity.end(nil, dismissalPolicy: .immediate)
        } else {
          await activity.end(dismissalPolicy: .immediate)
        }
      }
      DispatchQueue.main.async {
        result(nil)
      }
    }
  }

  // MARK: - 内部清理

  @available(iOS 16.1, *)
  private func cleanExistingActivities() {
    let activities = Activity<CourseLiveActivityAttributes>.activities
    for activity in activities {
      Task {
        if #available(iOS 16.2, *) {
          await activity.end(nil, dismissalPolicy: .immediate)
        } else {
          await activity.end(dismissalPolicy: .immediate)
        }
      }
    }
  }
}
