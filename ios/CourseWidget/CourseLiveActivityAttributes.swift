import ActivityKit
import Foundation

// MARK: - 数据契约（Attributes & ContentState）

/// 课程实时活动（Live Activity）数据契约。
///
/// 遵循 ActivityKit 规范：
/// - 静态属性（`sessionId`）在会话生命周期内保持不可变；
/// - 动态状态封装于 `ContentState` 中，通过 `Activity.update` 增量同步；
/// - 包含当前课程详情、时间区间以及后续课程预览信息。
///
/// 本文件只放契约、不含任何 SwiftUI 视图，因此同时编入 `Runner` 与
/// `CourseWidgetExtension`：主 App 的 `LiveActivityChannel` 需要用它构造
/// `Activity<…>.request` 与 `update`，而扩展是独立 binary、主 App 无法 import。
/// 视图侧（`CourseLiveActivity.swift`）只编入扩展；若把视图混进来，
/// 主 App target 会去解析它依赖的小组件内私有辅助函数而编译失败。
@available(iOS 16.1, *)
public struct CourseLiveActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    /// 当前课程名称。
    public var courseName: String

    /// 授课地点。
    public var location: String

    /// 课程开始时间，用于构建系统计时区间。
    public var startAt: Date

    /// 课程结束时间（倒计时目标时刻）。
    public var endAt: Date

    /// 下一节课程名称（可选）。
    public var nextCourseName: String?

    /// 下一节课程授课地点（可选）。
    public var nextLocation: String?

    public init(
      courseName: String,
      location: String,
      startAt: Date,
      endAt: Date,
      nextCourseName: String? = nil,
      nextLocation: String? = nil
    ) {
      self.courseName = courseName
      self.location = location
      self.startAt = startAt
      self.endAt = endAt
      self.nextCourseName = nextCourseName
      self.nextLocation = nextLocation
    }
  }

  /// 实时活动业务会话标识。
  public var sessionId: String

  public init(sessionId: String = "current_course") {
    self.sessionId = sessionId
  }
}
