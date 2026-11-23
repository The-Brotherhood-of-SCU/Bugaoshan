import ObjectiveC.runtime
import SQLite3
import UIKit
import XCTest
@testable import Runner

/// Observe the actual UIKit setters so a Flutter echo cannot silently replay
/// a native animation. These hooks are installed only for one test at a time.
private enum NativeControlProbe {
  static weak var toggle: UISwitch?
  static weak var slider: UISlider?
  static var switchUpdates: [(Bool, Bool)] = []
  static var sliderUpdates: [(Float, Bool)] = []
}

extension UISwitch {
  @objc fileprivate dynamic func bugaoshan_recordSetOn(_ value: Bool, animated: Bool) {
    if self === NativeControlProbe.toggle {
      NativeControlProbe.switchUpdates.append((value, animated))
    }
    bugaoshan_recordSetOn(value, animated: animated)
  }
}

extension UISlider {
  @objc fileprivate dynamic func bugaoshan_recordSetValue(_ value: Float, animated: Bool) {
    if self === NativeControlProbe.slider {
      NativeControlProbe.sliderUpdates.append((value, animated))
    }
    bugaoshan_recordSetValue(value, animated: animated)
  }
}

final class RunnerTests: XCTestCase {
  private func configuration(_ kind: String, _ value: Any,
                             _ additional: [String: Any] = [:]) -> LiquidGlassControlConfiguration {
    var arguments: [String: Any] = ["kind": kind, "value": value, "enabled": true, "label": "Setting"]
    arguments.merge(additional) { _, new in new }
    return LiquidGlassControlConfiguration(arguments: arguments)
  }

  @MainActor
  func testSwitchEchoDoesNotRestartNativeAnimation() throws {
    var changes: [Bool] = []
    let container = LiquidGlassControlContainer(
      frame: CGRect(x: 0, y: 0, width: 64, height: 44),
      configuration: configuration("switch", false),
      onEvent: { method, value in
        if method == "change", let value = value as? Bool { changes.append(value) }
      }
    )
    let toggle = try XCTUnwrap(container.subviews.first as? UISwitch)
    let original = try XCTUnwrap(class_getInstanceMethod(UISwitch.self, #selector(UISwitch.setOn(_:animated:))))
    let recorder = try XCTUnwrap(class_getInstanceMethod(UISwitch.self, #selector(UISwitch.bugaoshan_recordSetOn(_:animated:))))
    method_exchangeImplementations(original, recorder)
    NativeControlProbe.toggle = toggle
    defer {
      method_exchangeImplementations(original, recorder)
      NativeControlProbe.toggle = nil
      NativeControlProbe.switchUpdates = []
      container.dispose()
    }

    // UIKit completes a user's toggle, then Flutter acknowledges the same value.
    toggle.setOn(true, animated: false)
    toggle.sendActions(for: .valueChanged)
    NativeControlProbe.switchUpdates = []
    container.update(configuration("switch", true))
    container.update(configuration("switch", true, ["brightness": "dark"]))
    XCTAssertEqual(changes, [true])
    XCTAssertTrue(NativeControlProbe.switchUpdates.isEmpty)

    // A genuinely external change uses exactly one system transition.
    container.update(configuration("switch", false))
    XCTAssertEqual(NativeControlProbe.switchUpdates.count, 1)
    XCTAssertFalse(NativeControlProbe.switchUpdates[0].0)
    XCTAssertEqual(NativeControlProbe.switchUpdates[0].1, !UIAccessibility.isReduceMotionEnabled)

    // If Flutter declines a user change, restore its value without another animation.
    toggle.setOn(true, animated: false)
    toggle.sendActions(for: .valueChanged)
    NativeControlProbe.switchUpdates = []
    container.update(configuration("switch", false))
    XCTAssertEqual(NativeControlProbe.switchUpdates.count, 1)
    XCTAssertFalse(NativeControlProbe.switchUpdates[0].1)
    XCTAssertFalse(toggle.isOn)
    container.update(configuration("switch", true, ["reduceMotion": true]))
    XCTAssertFalse(NativeControlProbe.switchUpdates.last!.1)
  }

  @MainActor
  func testSliderEchoAndExternalChangesDoNotAddAnimations() throws {
    var events: [String] = []
    let container = LiquidGlassControlContainer(
      frame: CGRect(x: 0, y: 0, width: 280, height: 48),
      configuration: configuration("slider", 0.5),
      onEvent: { method, _ in events.append(method) }
    )
    let slider = try XCTUnwrap(container.subviews.first as? UISlider)
    let original = try XCTUnwrap(class_getInstanceMethod(UISlider.self, #selector(UISlider.setValue(_:animated:))))
    let recorder = try XCTUnwrap(class_getInstanceMethod(UISlider.self, #selector(UISlider.bugaoshan_recordSetValue(_:animated:))))
    method_exchangeImplementations(original, recorder)
    NativeControlProbe.slider = slider
    defer {
      method_exchangeImplementations(original, recorder)
      NativeControlProbe.slider = nil
      NativeControlProbe.sliderUpdates = []
      container.dispose()
    }

    slider.sendActions(for: .touchDown)
    slider.setValue(0.7, animated: false)
    slider.sendActions(for: .valueChanged)
    NativeControlProbe.sliderUpdates = []
    container.update(configuration("slider", 0.7))
    slider.sendActions(for: .touchUpInside)
    XCTAssertEqual(events, ["changeStart", "change", "changeEnd"])
    XCTAssertTrue(NativeControlProbe.sliderUpdates.isEmpty)

    container.update(configuration("slider", 0.2))
    XCTAssertEqual(NativeControlProbe.sliderUpdates.count, 1)
    XCTAssertFalse(NativeControlProbe.sliderUpdates[0].1)
    XCTAssertEqual(slider.value, 0.2, accuracy: 0.000001)
    XCTAssertEqual(events.count, 3, "Programmatic updates must not emit business events")
  }

  @MainActor
  func testSliderTicksRangesAndContinuousFallback() throws {
    guard #available(iOS 26.0, *) else { throw XCTSkip("Native ticks require iOS 26") }
    let container = LiquidGlassControlContainer(
      frame: CGRect(x: 0, y: 0, width: 280, height: 48),
      configuration: configuration("slider", 500.0, ["min": 0.0, "max": 1000.0, "divisions": 20]),
      onEvent: { _, _ in }
    )
    defer { container.dispose() }
    let slider = try XCTUnwrap(container.subviews.first as? UISlider)
    XCTAssertEqual(slider.minimumValue, 0)
    XCTAssertEqual(slider.maximumValue, 1000)
    XCTAssertEqual(slider.value, 500)
    XCTAssertEqual(slider.trackConfiguration?.ticks.count, 21)
    XCTAssertEqual(slider.trackConfiguration?.allowsTickValuesOnly, true)

    container.update(configuration("slider", 14.0, ["min": 8.0, "max": 20.0, "divisions": 12]))
    XCTAssertEqual(slider.minimumValue, 8)
    XCTAssertEqual(slider.maximumValue, 20)
    XCTAssertEqual(slider.value, 14)
    XCTAssertEqual(slider.trackConfiguration?.ticks.count, 13)

    container.update(configuration("slider", 0.35))
    XCTAssertEqual(slider.trackConfiguration?.ticks.count, 0)
    XCTAssertEqual(slider.trackConfiguration?.allowsTickValuesOnly, false)
    XCTAssertEqual(slider.value, 0.35, accuracy: 0.000001)
  }

  @MainActor
  func testSliderAccessibilityDisabledAndDisposedEvents() throws {
    var events: [String] = []
    let container = LiquidGlassControlContainer(
      frame: CGRect(x: 0, y: 0, width: 280, height: 48),
      configuration: configuration("slider", 0.5),
      onEvent: { method, _ in events.append(method) }
    )
    let slider = try XCTUnwrap(container.subviews.first as? UISlider)
    // Keyboard and VoiceOver changes have no touchDown/touchUp sequence.
    slider.setValue(0.6, animated: false)
    slider.sendActions(for: .valueChanged)
    XCTAssertEqual(events, ["changeStart", "change", "changeEnd"])
    XCTAssertEqual(slider.accessibilityLabel, "Setting")
    container.update(configuration("slider", 0.6, ["enabled": false]))
    slider.sendActions(for: .valueChanged)
    XCTAssertFalse(slider.isEnabled)
    XCTAssertEqual(events.count, 3)
    container.dispose()
    slider.sendActions(for: .valueChanged)
    XCTAssertEqual(events.count, 3)
  }

  @MainActor
  func testWindowingSafeAreaCalculatorDistinguishesFullScreenAndWindowedOnIPad() {
    let screen = CGRect(x: 0, y: 0, width: 1024, height: 1366)

    // Full-screen portrait and landscape match screen bounds -> not windowed.
    XCTAssertFalse(
      WindowingSafeAreaCalculator.isWindowed(
        idiom: .pad,
        sceneBounds: screen,
        screenBounds: screen
      )
    )
    XCTAssertFalse(
      WindowingSafeAreaCalculator.isWindowed(
        idiom: .pad,
        sceneBounds: CGRect(x: 0, y: 0, width: 1366, height: 1024),
        screenBounds: screen
      )
    )

    // Floating window and Split View are smaller than screen -> windowed.
    XCTAssertTrue(
      WindowingSafeAreaCalculator.isWindowed(
        idiom: .pad,
        sceneBounds: CGRect(x: 0, y: 0, width: 420, height: 760),
        screenBounds: screen
      )
    )
    XCTAssertTrue(
      WindowingSafeAreaCalculator.isWindowed(
        idiom: .pad,
        sceneBounds: CGRect(x: 0, y: 0, width: 507, height: 1366),
        screenBounds: screen
      )
    )

    // iPhone is never treated as iPad windowed mode.
    XCTAssertFalse(
      WindowingSafeAreaCalculator.isWindowed(
        idiom: .phone,
        sceneBounds: CGRect(x: 0, y: 0, width: 393, height: 852),
        screenBounds: screen
      )
    )
  }

  @MainActor
  func testWindowingSafeAreaCalculatorComputesDeltaAndResetsOnFullScreen() {
    // Floating window with 0 base safe area and 36pt traffic-light vertical adaptation.
    XCTAssertEqual(
      WindowingSafeAreaCalculator.additionalTopInset(
        isWindowed: true,
        baseSafeAreaTop: 0,
        cornerAdaptedSafeAreaTop: 36,
        cornerAdaptedMarginsTop: 44,
        unadaptedMarginsTop: 8
      ),
      36
    )

    // Window partially overlapping status bar (baseSafeAreaTop = 12, corner = 36) -> delta 24.
    XCTAssertEqual(
      WindowingSafeAreaCalculator.additionalTopInset(
        isWindowed: true,
        baseSafeAreaTop: 12,
        cornerAdaptedSafeAreaTop: 36,
        cornerAdaptedMarginsTop: 44,
        unadaptedMarginsTop: 8
      ),
      24
    )

    // Fallback when only margins layout region reports the corner control height.
    XCTAssertEqual(
      WindowingSafeAreaCalculator.additionalTopInset(
        isWindowed: true,
        baseSafeAreaTop: 0,
        cornerAdaptedSafeAreaTop: 0,
        cornerAdaptedMarginsTop: 40,
        unadaptedMarginsTop: 8
      ),
      32
    )

    // Dragging back to full-screen must force 0 even if layout guide retains stale value.
    XCTAssertEqual(
      WindowingSafeAreaCalculator.additionalTopInset(
        isWindowed: false,
        baseSafeAreaTop: 24,
        cornerAdaptedSafeAreaTop: 56,
        cornerAdaptedMarginsTop: 64,
        unadaptedMarginsTop: 8
      ),
      0
    )
  }

  @MainActor
  func testSceneDelegateInstallsObserverAndResetsFullScreenAdditionalSafeArea() {
    let delegate = SceneDelegate()
    let window = UIWindow(frame: UIScreen.main.bounds)
    let rootVC = UIViewController()
    rootVC.additionalSafeAreaInsets = UIEdgeInsets(top: 36, left: 4, bottom: 8, right: 4)
    window.rootViewController = rootVC
    delegate.window = window

    delegate.installWindowSafeAreaObserverIfNeeded()
    let observers = window.subviews.compactMap { $0 as? WindowingSafeAreaObserverView }
    XCTAssertEqual(observers.count, 1)
    XCTAssertTrue(observers[0].isHidden)
    XCTAssertFalse(observers[0].isUserInteractionEnabled)

    // Calling install again is idempotent.
    delegate.installWindowSafeAreaObserverIfNeeded()
    XCTAssertEqual(window.subviews.compactMap { $0 as? WindowingSafeAreaObserverView }.count, 1)

    // Full-screen window resets top additionalSafeAreaInsets to 0 while preserving other edges.
    delegate.updateWindowingSafeAreaInsets()
    XCTAssertEqual(rootVC.additionalSafeAreaInsets.top, 0)
    XCTAssertEqual(rootVC.additionalSafeAreaInsets.left, 4)
    XCTAssertEqual(rootVC.additionalSafeAreaInsets.bottom, 8)
    XCTAssertEqual(rootVC.additionalSafeAreaInsets.right, 4)
  }
}

@available(iOS 16.0, *)
final class CourseIntentsTests: XCTestCase {
  private var tempDir: URL!
  private var dbPath: String!

  override func setUpWithError() throws {
    try super.setUpWithError()
    tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("CourseIntentsTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    dbPath = tempDir.appendingPathComponent("bugaoshan.db").path
  }

  override func tearDownWithError() throws {
    if let tempDir {
      try? FileManager.default.removeItem(at: tempDir)
    }
    try super.tearDownWithError()
  }

  private func exec(_ db: OpaquePointer, _ sql: String) throws {
    var errMsg: UnsafeMutablePointer<CChar>?
    let rc = sqlite3_exec(db, sql, nil, nil, &errMsg)
    if rc != SQLITE_OK {
      let msg = errMsg.map { String(cString: $0) } ?? "SQLite error \(rc)"
      sqlite3_free(errMsg)
      XCTFail("SQL failed: \(msg)\n\(sql)")
    }
  }

  private func openSchemaDB() throws -> OpaquePointer {
    var db: OpaquePointer?
    XCTAssertEqual(sqlite3_open(dbPath, &db), SQLITE_OK)
    let handle = try XCTUnwrap(db)
    try exec(handle, """
      CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
      CREATE TABLE schedules (id TEXT PRIMARY KEY, config_json TEXT NOT NULL);
      CREATE TABLE courses (
        id TEXT PRIMARY KEY,
        schedule_id TEXT NOT NULL,
        name TEXT,
        teacher TEXT,
        location TEXT,
        campus TEXT NOT NULL DEFAULT '',
        start_week INTEGER,
        end_week INTEGER,
        day_of_week INTEGER,
        start_section INTEGER,
        end_section INTEGER,
        color_value INTEGER,
        week_type INTEGER,
        custom_weeks TEXT
      );
      """)
    return handle
  }

  private func scheduleJson(id: String, start: String, totalWeeks: Int = 20, slotCount: Int = 12) -> String {
    let preset: [(Int, Int, Int, Int)] = [
      (8, 15, 9, 0), (9, 10, 9, 55), (10, 15, 11, 0), (11, 10, 11, 55),
      (13, 50, 14, 35), (14, 45, 15, 30), (15, 40, 16, 25), (16, 45, 17, 30),
      (17, 40, 18, 25), (19, 20, 20, 5), (20, 15, 21, 0), (21, 10, 21, 55),
    ]
    let slots = preset.prefix(slotCount).map { sH, sM, eH, eM in
      "{\"startTime\":{\"hour\":\(sH),\"minute\":\(sM)},\"endTime\":{\"hour\":\(eH),\"minute\":\(eM)}}"
    }.joined(separator: ",")
    return "{\"id\":\"\(id)\",\"semesterStartDate\":\"\(start)\",\"totalWeeks\":\(totalWeeks),\"timeSlots\":[\(slots)]}"
  }

  private func localDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9, _ minute: Int = 0) -> Date {
    var comps = DateComponents()
    comps.calendar = Calendar.current
    comps.timeZone = TimeZone.current
    comps.year = year
    comps.month = month
    comps.day = day
    comps.hour = hour
    comps.minute = minute
    return comps.date!
  }

  func testSelectsCurrentScheduleIdInsteadOfFirstScheduleRow() throws {
    let db = try openSchemaDB()
    defer { sqlite3_close(db) }

    let oldJson = scheduleJson(id: "2025-2026-1", start: "2025-09-01")
    let activeJson = scheduleJson(id: "2026-2027-1", start: "2026-08-31")
    try exec(db, """
      INSERT INTO schedules (id, config_json) VALUES ('2025-2026-1', '\(oldJson)');
      INSERT INTO schedules (id, config_json) VALUES ('2026-2027-1', '\(activeJson)');
      INSERT INTO metadata (key, value) VALUES ('currentScheduleId', '2026-2027-1');
      INSERT INTO courses VALUES ('c1', '2026-2027-1', '操作系统', '王老师', '江安一教B201', '', 1, 16, 3, 1, 2, 0, 0, NULL);
      """)

    let provider = CourseIntentDataProvider(databasePathResolver: { [dbPath] in dbPath })
    // 2026-11-11 周三属于 2026-08-31 起算的第 11 周
    let now = localDate(2026, 11, 11, 8, 30)
    let result = provider.queryCourses(for: now, now: now)

    guard case .success(let courses, let desc, let week, let active, _) = result else {
      return XCTFail("Expected .success from currentScheduleId, got \(result)")
    }
    XCTAssertEqual(week, 11)
    XCTAssertEqual(courses.map(\.name), ["操作系统"])
    XCTAssertEqual(active?.name, "操作系统")
    XCTAssertTrue(desc.contains("今天 (第11周·周三)"), "Unexpected desc: \(desc)")
  }

  func testMondayStartWeekOneAnchorAndVacationBoundaries() throws {
    let db = try openSchemaDB()
    defer { sqlite3_close(db) }

    let activeJson = scheduleJson(id: "2026-2027-1", start: "2026-08-31", totalWeeks: 20)
    try exec(db, """
      INSERT INTO schedules (id, config_json) VALUES ('2026-2027-1', '\(activeJson)');
      INSERT INTO metadata (key, value) VALUES ('currentScheduleId', '2026-2027-1');
      INSERT INTO courses VALUES ('sun1', '2026-2027-1', '新生研讨', '', '', '', 1, 1, 7, 3, 4, 0, 0, NULL);
      INSERT INTO courses VALUES ('sat20', '2026-2027-1', '期末实训', '', '江安综C101', '', 20, 20, 6, 1, 2, 0, 0, NULL);
      """)

    let provider = CourseIntentDataProvider(databasePathResolver: { [dbPath] in dbPath })

    // 2026-08-29 (周六) 早于第 1 周周日锚点 2026-08-30 -> 假期
    let beforeAnchor = localDate(2026, 8, 29, 10, 0)
    if case .onVacation = provider.queryCourses(for: beforeAnchor, now: beforeAnchor) {
      // expected
    } else {
      XCTFail("Expected .onVacation before week 1 Sunday anchor")
    }

    // 2026-08-30 (第 1 周周日，早于周一起点 1 天) -> 应正常归属第 1 周而非误判放假
    let weekOneSunday = localDate(2026, 8, 30, 9, 0)
    if case .success(let sundayCourses, _, let week, _, let next) = provider.queryCourses(for: weekOneSunday, now: weekOneSunday) {
      XCTAssertEqual(week, 1)
      XCTAssertEqual(sundayCourses.map(\.name), ["新生研讨"])
      XCTAssertEqual(next?.name, "新生研讨")
    } else {
      XCTFail("Expected week 1 Sunday course on 2026-08-30")
    }

    // 2027-01-16 (第 20 周周六，学期最后一天) -> 仍在学期内
    let lastDay = localDate(2027, 1, 16, 8, 0)
    if case .success(let lastDayCourses, _, let week, _, _) = provider.queryCourses(for: lastDay, now: lastDay) {
      XCTAssertEqual(week, 20)
      XCTAssertEqual(lastDayCourses.map(\.name), ["期末实训"])
    } else {
      XCTFail("Expected week 20 Saturday to be inside semester")
    }

    // 2027-01-17 (寒假首日) -> 已结课放假
    let firstVacationDay = localDate(2027, 1, 17, 10, 0)
    if case .onVacation = provider.queryCourses(for: firstVacationDay, now: firstVacationDay) {
      // expected
    } else {
      XCTFail("Expected .onVacation after semesterEndDate")
    }
  }

  func testCourseStatusesAndOutOfRangeSectionsDoNotFalseComplete() throws {
    let db = try openSchemaDB()
    defer { sqlite3_close(db) }

    // 仅配置 4 节时间槽，验证超出范围的第 10-12 节晚课不会在上午被误判为已下课
    let activeJson = scheduleJson(id: "s1", start: "2026-08-31", totalWeeks: 20, slotCount: 4)
    try exec(db, """
      INSERT INTO schedules (id, config_json) VALUES ('s1', '\(activeJson)');
      INSERT INTO metadata (key, value) VALUES ('currentScheduleId', 's1');
      INSERT INTO courses VALUES ('c1', 's1', '高等数学', '李老师', '江安一教A101', '', 1, 16, 3, 1, 2, 0, 0, NULL);
      INSERT INTO courses VALUES ('c2', 's1', '大学英语', '张老师', '江安综B302', '', 1, 16, 3, 3, 4, 0, 0, NULL);
      INSERT INTO courses VALUES ('c3', 's1', '晚间选修', '陈老师', '', '', 1, 16, 3, 10, 12, 0, 0, NULL);
      """)

    let provider = CourseIntentDataProvider(databasePathResolver: { [dbPath] in dbPath })

    // 10:00 处于第 1-2 节(09:55下课)与第 3-4 节(10:15上课)课间
    let breakTime = localDate(2026, 11, 11, 10, 0)
    guard case .success(let courses, _, _, let active, let next) = provider.queryCourses(for: breakTime, now: breakTime) else {
      return XCTFail("Expected .success")
    }
    XCTAssertNil(active)
    XCTAssertEqual(next?.name, "大学英语")
    XCTAssertTrue(courses[0].isCompleted)
    XCTAssertFalse(courses[1].isCompleted)
    XCTAssertEqual(courses[2].startTimeText, "--:--")
    XCTAssertEqual(courses[2].endTimeText, "--:--")
    XCTAssertFalse(courses[2].isCompleted, "Out-of-range evening course must not be marked completed in the morning")
  }

  func testOddEvenAndCustomWeeksFilteringAndSpeechFormatting() throws {
    let db = try openSchemaDB()
    defer { sqlite3_close(db) }

    let activeJson = scheduleJson(id: "s1", start: "2026-08-31")
    try exec(db, """
      INSERT INTO schedules (id, config_json) VALUES ('s1', '\(activeJson)');
      INSERT INTO metadata (key, value) VALUES ('currentScheduleId', 's1');
      INSERT INTO courses VALUES ('odd', 's1', '单周实验', '', '基础教学楼C201', '', 1, 16, 3, 3, 4, 0, 1, NULL);
      INSERT INTO courses VALUES ('even', 's1', '双周实验', '', '基础教学楼C202', '', 1, 16, 3, 5, 6, 0, 2, NULL);
      INSERT INTO courses VALUES ('custom', 's1', '形势与政策', '', '   ', '', 1, 16, 3, 7, 8, 0, 0, '4, 11, 15');
      """)

    let provider = CourseIntentDataProvider(databasePathResolver: { [dbPath] in dbPath })
    // 第 11 周（单周）周三
    let week11Wed = localDate(2026, 11, 11, 8, 0)
    guard case .success(let courses, _, let week, _, _) = provider.queryCourses(for: week11Wed, now: week11Wed) else {
      return XCTFail("Expected .success")
    }
    XCTAssertEqual(week, 11)
    XCTAssertEqual(courses.map(\.name), ["单周实验", "形势与政策"])

    let onlineCourse = courses[1]
    XCTAssertEqual(onlineCourse.speechLocationClause, "")
    XCTAssertEqual(onlineCourse.briefTitleWithLocation, "形势与政策")

    let summary = CourseIntentSpeechFormatter.formatDailySummary(dayLabel: "今天", courses: courses)
    XCTAssertEqual(summary, "你今天一共有 2 节课：第3-4节《单周实验》在基础教学楼C201；第7-8节《形势与政策》。")
  }

  @MainActor
  func testAppIntentsPerformEndToEnd() async throws {
    let fm = FileManager.default
    let appGroupId = "group.io.github.thebrotherhoodofscu.bugaoshan.ios"
    let targetDir: URL
    if let container = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
      targetDir = container
    } else {
      targetDir = try XCTUnwrap(fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first)
    }
    try fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
    let liveDbURL = targetDir.appendingPathComponent("bugaoshan.db")
    let backupURL = targetDir.appendingPathComponent("bugaoshan.db.xctest-backup-\(UUID().uuidString)")
    let hadExisting = fm.fileExists(atPath: liveDbURL.path)
    if hadExisting {
      try fm.moveItem(at: liveDbURL, to: backupURL)
    }
    defer {
      try? fm.removeItem(at: liveDbURL)
      if hadExisting {
        try? fm.moveItem(at: backupURL, to: liveDbURL)
      }
    }

    // 1. 无数据库时验证「不高山上 App」引导文案
    let noDataRes = try await GetTodayCoursesIntent().perform()
    XCTAssertEqual(noDataRes.value, "还没有找到你的课表数据，请先打开不高山上 App 导入或同步课表。")

    // 2. 写入包含历史旧课表 + 当前课表的数据，端到端执行三个 AppIntent
    let calendar = Calendar.current
    let now = Date()
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
    let startOfThisWeekSunday: Date = {
      let start = calendar.startOfDay(for: now)
      let isoWeekday = (calendar.component(.weekday, from: start) + 5) % 7 + 1
      return calendar.date(byAdding: .day, value: -(isoWeekday % 7), to: start)!
    }()
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone.current
    let startStr = df.string(from: startOfThisWeekSunday)
    let todayIso = (calendar.component(.weekday, from: now) + 5) % 7 + 1
    let tomorrowIso = (calendar.component(.weekday, from: tomorrow) + 5) % 7 + 1

    var db: OpaquePointer?
    XCTAssertEqual(sqlite3_open(liveDbURL.path, &db), SQLITE_OK)
    let handle = try XCTUnwrap(db)
    let oldJson = scheduleJson(id: "old-2024", start: "2024-09-01")
    let curJson = scheduleJson(id: "cur-active", start: startStr)
    try exec(handle, """
      CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
      CREATE TABLE schedules (id TEXT PRIMARY KEY, config_json TEXT NOT NULL);
      CREATE TABLE courses (
        id TEXT PRIMARY KEY,
        schedule_id TEXT NOT NULL,
        name TEXT,
        teacher TEXT,
        location TEXT,
        campus TEXT NOT NULL DEFAULT '',
        start_week INTEGER,
        end_week INTEGER,
        day_of_week INTEGER,
        start_section INTEGER,
        end_section INTEGER,
        color_value INTEGER,
        week_type INTEGER,
        custom_weeks TEXT
      );
      INSERT INTO schedules VALUES ('old-2024', '\(oldJson)');
      INSERT INTO schedules VALUES ('cur-active', '\(curJson)');
      INSERT INTO metadata VALUES ('currentScheduleId', 'cur-active');
      INSERT INTO courses VALUES ('t1', 'cur-active', '编译原理', '周老师', '江安一教A305', '', 1, 20, \(todayIso), 1, 2, 0, 0, NULL);
      INSERT INTO courses VALUES ('t2', 'cur-active', '毕业实习', '', '', '', 1, 20, \(tomorrowIso), 3, 4, 0, 0, NULL);
      """)
    sqlite3_close(handle)

    let todayRes = try await GetTodayCoursesIntent().perform()
    XCTAssertEqual(todayRes.value, "你今天有 1 节课：《编译原理》，在江安一教A305，08:15 - 09:55。")

    let tomorrowRes = try await GetTomorrowCoursesIntent().perform()
    XCTAssertEqual(tomorrowRes.value, "你明天有 1 节课：《毕业实习》，10:15 - 11:55。")

    let nextRes = try await GetNextCourseIntent().perform()
    XCTAssertNotNil(nextRes.value)
    XCTAssertFalse(nextRes.value!.contains("在，"), "Speech must not contain broken empty location: \(nextRes.value!)")
    XCTAssertFalse(nextRes.value!.contains("假期"), "Must read active schedule instead of old-2024: \(nextRes.value!)")
  }
}
