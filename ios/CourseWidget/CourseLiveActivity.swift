import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

// 数据契约见 CourseLiveActivityAttributes.swift：那份文件同时编入
// Runner 与扩展，本文件只含 SwiftUI 视图，仅编入扩展。

// MARK: - 辅助方法

@available(iOS 16.1, *)
private func safeTimerInterval(from start: Date, to end: Date) -> ClosedRange<Date> {
  let lower = min(start, end)
  let upper = max(start, end)
  if lower == upper {
    return lower...upper.addingTimeInterval(1)
  }
  return lower...upper
}

@available(iOS 16.1, *)
private func formatEndTime(_ date: Date) -> String {
  let formatter = DateFormatter()
  formatter.dateFormat = "HH:mm"
  return formatter.string(from: date)
}

// MARK: - Live Activity Widget 配置

/// 课程实时活动的 Widget 配置组件。
///
/// 定义锁屏横幅与灵动岛（展开、紧凑与最小化）展示形态。
/// 倒计时采用 SwiftUI 的 `Text(timerInterval:countsDown:)`，
/// 由系统运行时自动驱动倒计时刷新，避免通过前后台通信触发高频更新。
@available(iOS 16.1, *)
public struct CourseLiveActivity: Widget {
  public let kind: String = "CourseLiveActivity"

  public init() {}

  public var body: some WidgetConfiguration {
    ActivityConfiguration(for: CourseLiveActivityAttributes.self) { context in
      // MARK: 锁屏横幅界面
      CourseLockScreenView(context: context)
    } dynamicIsland: { context in
      DynamicIsland {
        // MARK: 灵动岛 - 展开态（长按呈现）
        DynamicIslandExpandedRegion(.leading) {
          HStack(spacing: 8) {
            Image(systemName: "book.closed.fill")
              .foregroundColor(.cyan)
              .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
              Text(context.state.courseName)
                .font(.headline)
                .lineLimit(1)
              if !context.state.location.isEmpty {
                Label(context.state.location, systemImage: "mappin.and.ellipse")
                  .font(.caption2)
                  .foregroundColor(.secondary)
                  .lineLimit(1)
              }
            }
          }
          .padding(.leading, 4)
        }

        DynamicIslandExpandedRegion(.trailing) {
          VStack(alignment: .trailing, spacing: 2) {
            Text(
              timerInterval: safeTimerInterval(from: context.state.startAt, to: context.state.endAt),
              countsDown: true
            )
            .monospacedDigit()
            .font(.title3.weight(.bold))
            .foregroundColor(.orange)
            Text(widgetLocalizedString("liveActivity.untilClassEnds"))
              .font(.caption2)
              .foregroundColor(.secondary)
          }
          .padding(.trailing, 4)
        }

        DynamicIslandExpandedRegion(.bottom) {
          if let nextCourse = context.state.nextCourseName, !nextCourse.isEmpty {
            HStack(spacing: 4) {
              Image(systemName: "arrow.forward.circle.fill")
                .foregroundColor(.blue)
                .font(.caption)
              Text(widgetLocalizedFormat("liveActivity.nextCourse", nextCourse))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
              if let nextLoc = context.state.nextLocation, !nextLoc.isEmpty {
                Text("· \(nextLoc)")
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .lineLimit(1)
              }
              Spacer()
            }
            .padding(.top, 4)
          } else {
            HStack {
              Spacer()
              Text(widgetLocalizedFormat("liveActivity.classEndsAt", formatEndTime(context.state.endAt)))
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding(.top, 4)
          }
        }
      } compactLeading: {
        // MARK: 灵动岛 - 紧凑左侧（书本图标 + 课程简称）
        HStack(spacing: 4) {
          Image(systemName: "book.closed.fill")
            .foregroundColor(.cyan)
            .font(.caption2)
          Text(context.state.courseName)
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .frame(maxWidth: 56)
        }
      } compactTrailing: {
        // MARK: 灵动岛 - 紧凑右侧（自更新倒计时）
        Text(
          timerInterval: safeTimerInterval(from: context.state.startAt, to: context.state.endAt),
          countsDown: true
        )
        .monospacedDigit()
        .font(.caption2.weight(.semibold))
        .foregroundColor(.orange)
        .frame(minWidth: 32)
      } minimal: {
        // MARK: 灵动岛 - 最小化（多活动并存时的图标）
        Image(systemName: "book.closed.fill")
          .foregroundColor(.cyan)
          .font(.caption2)
      }
    }
  }
}

// MARK: - 锁屏视图组件

@available(iOS 16.1, *)
private struct CourseLockScreenView: View {
  let context: ActivityViewContext<CourseLiveActivityAttributes>

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // 顶行：课程名与倒计时
      HStack(alignment: .center) {
        HStack(spacing: 6) {
          Image(systemName: "book.closed.fill")
            .font(.subheadline)
            .foregroundColor(.cyan)
          Text(context.state.courseName)
            .font(.headline)
            .lineLimit(1)
        }
        Spacer()
        HStack(spacing: 4) {
          Image(systemName: "timer")
            .font(.caption2)
            .foregroundColor(.secondary)
          Text(
            timerInterval: safeTimerInterval(from: context.state.startAt, to: context.state.endAt),
            countsDown: true
          )
          .monospacedDigit()
          .font(.subheadline.weight(.semibold))
          .foregroundColor(.orange)
        }
      }

      // 次行：地点与下课时刻
      HStack {
        if !context.state.location.isEmpty {
          Label(context.state.location, systemImage: "mappin.and.ellipse")
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
        Spacer()
        Text(widgetLocalizedFormat("liveActivity.classEndsAt", formatEndTime(context.state.endAt)))
          .font(.caption2)
          .foregroundColor(.secondary)
      }

      // 底行：下一节课程预览（若有）
      if let nextCourse = context.state.nextCourseName, !nextCourse.isEmpty {
        Divider()
          .padding(.vertical, 2)
        HStack(spacing: 6) {
          Image(systemName: "arrow.forward.circle.fill")
            .font(.caption2)
            .foregroundColor(.blue)
          Text(widgetLocalizedFormat("liveActivity.nextCourse", nextCourse))
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(1)
          if let nextLoc = context.state.nextLocation, !nextLoc.isEmpty {
            Text("· \(nextLoc)")
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
        }
      }
    }
    .padding(14)
    .activityBackgroundTint(Color(.systemBackground).opacity(0.85))
    .activitySystemActionForegroundColor(Color.primary)
  }
}
