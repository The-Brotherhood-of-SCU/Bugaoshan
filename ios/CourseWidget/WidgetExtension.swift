import SQLite3
import SwiftUI
import WidgetKit

struct Course {
    let name: String
    let teacher: String
    let location: String
    let startSection: Int
    let endSection: Int
    let colorValue: Int
    let status: CourseStatus
    var timeText: String? = nil
}

enum CourseStatus {
    case inProgress
    case upcoming
    case completed
    case none
}

struct TimeSlot {
    let section: Int
    let startTime: DateComponents
    let endTime: DateComponents
}

struct ScheduleConfig {
    let semesterStartDate: Date
    let totalWeeks: Int
    let timeSlots: [TimeSlot]
}

let appGroupId = "group.io.github.thebrotherhoodofscu.bugaoshan"

func getDatabasePath() -> String? {
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
        return nil
    }
    return containerURL.appendingPathComponent("bugaoshan.db").path
}

func queryMetadata(_ db: OpaquePointer, key: String) -> String? {
    var stmt: OpaquePointer?
    let query = "SELECT value FROM metadata WHERE key = ?"

    guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
        return nil
    }
    defer { sqlite3_finalize(stmt) }

    // Correctly bind string parameter - use SQLITE_TRANSIENT value (-1)
    key.withCString { cString in
        sqlite3_bind_text(stmt, 1, cString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }

    guard sqlite3_step(stmt) == SQLITE_ROW,
          let cString = sqlite3_column_text(stmt, 0)
    else {
        return nil
    }
    return String(cString: cString)
}

func queryScheduleConfig(_ db: OpaquePointer, scheduleId: String) -> (config: ScheduleConfig, actualId: String)? {
    // First, print all available schedules for debugging
    print("BugaoShan Widget: Looking for schedule with ID: \(scheduleId)")

    var debugStmt: OpaquePointer?
    let debugQuery = "SELECT id FROM schedules"
    if sqlite3_prepare_v2(db, debugQuery, -1, &debugStmt, nil) == SQLITE_OK {
        defer { sqlite3_finalize(debugStmt) }
        print("BugaoShan Widget: Available schedules in database:")
        while sqlite3_step(debugStmt) == SQLITE_ROW {
            if let cString = sqlite3_column_text(debugStmt, 0) {
                print("BugaoShan Widget:  - \(String(cString: cString))")
            }
        }
    } else {
        print("BugaoShan Widget: Failed to list schedules")
    }

    // Try to get the specified schedule
    var stmt: OpaquePointer?
    let query = "SELECT config_json FROM schedules WHERE id = ?"

    guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
        print("BugaoShan Widget: Failed to prepare schedule config query")
        return nil
    }
    defer { sqlite3_finalize(stmt) }

    // Correctly bind string parameter - use SQLITE_TRANSIENT value (-1)
    scheduleId.withCString { cString in
        sqlite3_bind_text(stmt, 1, cString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }

    guard sqlite3_step(stmt) == SQLITE_ROW,
          let cString = sqlite3_column_text(stmt, 0)
    else {
        print("BugaoShan Widget: Schedule ID '\(scheduleId)' not found, trying any available schedule")

        // If specified not found, try to get ANY schedule, AND get its ID
//        sqlite3_reset(stmt)
//        sqlite3_clear_bindings(stmt)
//        sqlite3_finalize(stmt)

        var anyStmt: OpaquePointer?
        let anyQuery = "SELECT id, config_json FROM schedules LIMIT 1"
        guard sqlite3_prepare_v2(db, anyQuery, -1, &anyStmt, nil) == SQLITE_OK else {
            print("BugaoShan Widget: Failed to prepare query for any schedule")
            return nil
        }
        defer { sqlite3_finalize(anyStmt) }

        guard sqlite3_step(anyStmt) == SQLITE_ROW,
              let anyIdCString = sqlite3_column_text(anyStmt, 0),
              let anyJsonCString = sqlite3_column_text(anyStmt, 1)
        else {
            print("BugaoShan Widget: No schedules found at all in database")
            return nil
        }

        let actualId = String(cString: anyIdCString)
        print("BugaoShan Widget: Using schedule with ID: \(actualId)")
        if let config = parseConfigJson(String(cString: anyJsonCString)) {
            return (config, actualId)
        } else {
            return nil
        }
    }

    print("BugaoShan Widget: Found schedule config for ID '\(scheduleId)'")
    if let config = parseConfigJson(String(cString: cString)) {
        return (config, scheduleId)
    } else {
        return nil
    }
}

func parseConfigJson(_ jsonString: String) -> ScheduleConfig? {
    print("BugaoShan Widget: Attempting to parse config JSON (length: \(jsonString.count))")

    guard let jsonData = jsonString.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
    else {
        print("BugaoShan Widget: Failed to parse JSON data")
        return nil
    }

    print("BugaoShan Widget: Parsed JSON keys: \(json.keys.joined(separator: ", "))")

    guard let semesterStartDateStr = json["semesterStartDate"] as? String,
          let totalWeeks = json["totalWeeks"] as? Int
    else {
        print("BugaoShan Widget: Missing required fields (semesterStartDate or totalWeeks)")
        return nil
    }

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone.current
    guard let semesterStartDate = dateFormatter.date(from: semesterStartDateStr) else {
        print("BugaoShan Widget: Failed to parse semester start date: \(semesterStartDateStr)")
        return nil
    }

    print("BugaoShan Widget: Parsed semesterStartDate (local time): \(semesterStartDate)")

    var timeSlots: [TimeSlot] = []
    if let timeSlotsArray = json["timeSlots"] as? [[String: Any]] {
        print("BugaoShan Widget: Found \(timeSlotsArray.count) time slots")
        for (index, slot) in timeSlotsArray.enumerated() {
            if let startTimeDict = slot["startTime"] as? [String: Int],
               let endTimeDict = slot["endTime"] as? [String: Int],
               let startHour = startTimeDict["hour"],
               let startMinute = startTimeDict["minute"],
               let endHour = endTimeDict["hour"],
               let endMinute = endTimeDict["minute"]
            {
                timeSlots.append(TimeSlot(
                    section: index + 1,
                    startTime: DateComponents(hour: startHour, minute: startMinute),
                    endTime: DateComponents(hour: endHour, minute: endMinute)
                ))
            }
        }
    } else {
        print("BugaoShan Widget: No time slots found in config")
    }

    print("BugaoShan Widget: Config parsed successfully - \(timeSlots.count) time slots")
    return ScheduleConfig(
        semesterStartDate: semesterStartDate,
        totalWeeks: totalWeeks,
        timeSlots: timeSlots
    )
}

func computeCurrentWeek(semesterStartDate: Date, totalWeeks: Int) -> Int {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let startOfSemester = calendar.startOfDay(for: semesterStartDate)

    print("BugaoShan Widget: computeCurrentWeek - today: \(today), startOfSemester: \(startOfSemester)")

    if today < startOfSemester {
        print("BugaoShan Widget: computeCurrentWeek - today is before semester start, returning 1")
        return 1
    }

    let components1 = calendar.dateComponents([.day], from: startOfSemester, to: today)
    let days = components1.day ?? 0
//    let week = days / 7 + 1
    // 直接请求相差的周数，消除夏令时可能导致的误差
    let components2 = calendar.dateComponents([.weekOfYear], from: startOfSemester, to: today)
    let week = (components2.weekOfYear ?? 0) + 1

    let clampedWeek = max(1, min(week, totalWeeks))
    print("BugaoShan Widget: computeCurrentWeek - days since start: \(days), week: \(week), clampedWeek: \(clampedWeek)")
    return clampedWeek
}

func computeWeekForDate(semesterStartDate: Date, totalWeeks: Int, date: Date) -> Int {
    let calendar = Calendar.current
    let target = calendar.startOfDay(for: date)
    let startOfSemester = calendar.startOfDay(for: semesterStartDate)

    if target < startOfSemester {
        return 1
    }

    let components = calendar.dateComponents([.day], from: startOfSemester, to: target)
    let days = components.day ?? 0
    let week = days / 7 + 1
    return max(1, min(week, totalWeeks))
}

func isCourseActive(currentWeek: Int, startWeek: Int, endWeek: Int, weekType: Int) -> Bool {
    print("BugaoShan Widget: isCourseActive - currentWeek: \(currentWeek), startWeek: \(startWeek), endWeek: \(endWeek), weekType: \(weekType)")

    guard currentWeek >= startWeek && currentWeek <= endWeek else {
        print("BugaoShan Widget: isCourseActive - week out of range, returning false")
        return false
    }

    // weekType: 0=every, 1=odd, 2=even (matches Flutter's WeekType enum)
    if weekType == 1 && currentWeek % 2 == 0 {
        print("BugaoShan Widget: isCourseActive - odd week type but even current week, returning false")
        return false
    }
    if weekType == 2 && currentWeek % 2 == 1 {
        print("BugaoShan Widget: isCourseActive - even week type but odd current week, returning false")
        return false
    }

    print("BugaoShan Widget: isCourseActive - course is active, returning true")
    return true
}

func formatTime(_ timeSlots: [TimeSlot], section: Int, isEnd: Bool = false) -> String {
    guard section >= 1 && section <= timeSlots.count else {
        return "--:--"
    }
    let slot = timeSlots[section - 1]
    let components = isEnd ? slot.endTime : slot.startTime
    return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
}

func queryCourses(_ db: OpaquePointer, scheduleId: String, dayOfWeek: Int, currentWeek: Int) -> [Course] {
    var courses: [Course] = []

    // First, print all courses for debugging - simple approach
    var debugStmt: OpaquePointer?
    let debugQuery = "SELECT id, schedule_id, name, teacher, location, start_week, end_week, day_of_week, start_section, end_section, color_value, week_type FROM courses"
    if sqlite3_prepare_v2(db, debugQuery, -1, &debugStmt, nil) == SQLITE_OK {
        defer { sqlite3_finalize(debugStmt) }
        print("BugaoShan Widget: All courses in database:")
        var count = 0
        while sqlite3_step(debugStmt) == SQLITE_ROW {
            count += 1
            let id = sqlite3_column_text(debugStmt, 0).flatMap { String(cString: $0) } ?? ""
            let schedId = sqlite3_column_text(debugStmt, 1).flatMap { String(cString: $0) } ?? ""
            let name = sqlite3_column_text(debugStmt, 2).flatMap { String(cString: $0) } ?? ""
            let dayOfWeek = sqlite3_column_int(debugStmt, 7)
            let startWeek = sqlite3_column_int(debugStmt, 5)
            let endWeek = sqlite3_column_int(debugStmt, 6)
            let weekType = sqlite3_column_int(debugStmt, 11)
            print("  - id: \(id), scheduleId: \(schedId), name: \(name), dayOfWeek: \(dayOfWeek), startWeek: \(startWeek), endWeek: \(endWeek), weekType: \(weekType)")
        }
        print("BugaoShan Widget: Total courses found: \(count)")
    } else {
        print("BugaoShan Widget: Failed to prepare debug query")
    }

    var stmt: OpaquePointer?
    let query = "SELECT name, teacher, location, start_week, end_week, start_section, end_section, color_value, week_type FROM courses WHERE schedule_id = ? AND day_of_week = ?"

    guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
        print("BugaoShan Widget: Failed to prepare course query")
        return []
    }
    defer { sqlite3_finalize(stmt) }

    // Correctly bind string parameter - use SQLITE_TRANSIENT value (-1)
    scheduleId.withCString { cString in
        sqlite3_bind_text(stmt, 1, cString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }
    sqlite3_bind_int(stmt, 2, Int32(dayOfWeek))

    print("BugaoShan Widget: Querying courses with scheduleId: \(scheduleId), dayOfWeek: \(dayOfWeek)")

    var foundCount = 0
    while sqlite3_step(stmt) == SQLITE_ROW {
        foundCount += 1
        let startWeek = Int(sqlite3_column_int(stmt, 3))
        let endWeek = Int(sqlite3_column_int(stmt, 4))
        let weekType = Int(sqlite3_column_int(stmt, 8))

        let name = sqlite3_column_text(stmt, 0).flatMap { String(cString: $0) } ?? ""
        print("BugaoShan Widget: Found course candidate: \(name)")

        guard isCourseActive(currentWeek: currentWeek, startWeek: startWeek, endWeek: endWeek, weekType: weekType) else {
            continue
        }

        let teacher = sqlite3_column_text(stmt, 1).flatMap { String(cString: $0) } ?? ""
        let location = sqlite3_column_text(stmt, 2).flatMap { String(cString: $0) } ?? ""
        let startSection = Int(sqlite3_column_int(stmt, 5))
        let endSection = Int(sqlite3_column_int(stmt, 6))
        let colorValue = Int(sqlite3_column_int(stmt, 7))

        courses.append(Course(
            name: name,
            teacher: teacher,
            location: location,
            startSection: startSection,
            endSection: endSection,
            colorValue: colorValue,
            status: .none
        ))
    }

    print("BugaoShan Widget: Found \(foundCount) course candidates, added \(courses.count) active courses")

    return courses.sorted { $0.startSection < $1.startSection }
}

func attachTimesAndStatuses(_ courses: [Course], timeSlots: [TimeSlot], currentTimeMinutes: Int?, forceUpcoming: Bool = false) -> [Course] {
    var updatedCourses: [Course] = []

    for course in courses {
        var status: CourseStatus

        if forceUpcoming {
            status = .upcoming
        } else if let currentTime = currentTimeMinutes {
            let startSlot = timeSlots.indices.contains(course.startSection - 1) ? timeSlots[course.startSection - 1] : nil
            let endSlot = timeSlots.indices.contains(course.endSection - 1) ? timeSlots[course.endSection - 1] : nil

            if let start = startSlot, let end = endSlot {
                let startMinutes = (start.startTime.hour ?? 0) * 60 + (start.startTime.minute ?? 0)
                let endMinutes = (end.endTime.hour ?? 0) * 60 + (end.endTime.minute ?? 0)

                if currentTime >= endMinutes {
                    status = .completed // ✨ 以前这里是 continue，现在改为标记已完成
                } else if currentTime >= startMinutes, currentTime < endMinutes {
                    status = .inProgress
                } else {
                    status = .upcoming
                }
            } else {
                status = .upcoming
            }
        } else {
            status = .upcoming
        }

        // 计算课程实际时间字符串 (例如 "08:00-09:40")
        let startStr = formatTime(timeSlots, section: course.startSection, isEnd: false)
        let endStr = formatTime(timeSlots, section: course.endSection, isEnd: true)
        let timeText = "\(startStr)-\(endStr)"

        updatedCourses.append(Course(
            name: course.name,
            teacher: course.teacher,
            location: course.location,
            startSection: course.startSection,
            endSection: course.endSection,
            colorValue: course.colorValue,
            status: status,
            timeText: timeText
        ))
    }

    return updatedCourses
}

func computeNextTransitionMillis(_ courses: [Course], timeSlots: [TimeSlot], currentTimeMinutes: Int) -> Date? {
    var nextMinutes: Int? = nil

    func consider(_ minutes: Int?) {
        guard let m = minutes, m > currentTimeMinutes else { return }
        if let currentNext = nextMinutes {
            if m < currentNext {
                nextMinutes = m
            }
        } else {
            nextMinutes = m
        }
    }

    for course in courses {
        if timeSlots.indices.contains(course.startSection - 1) {
            let slot = timeSlots[course.startSection - 1]
            consider((slot.startTime.hour ?? 0) * 60 + (slot.startTime.minute ?? 0))
        }
        if timeSlots.indices.contains(course.endSection - 1) {
            let slot = timeSlots[course.endSection - 1]
            consider((slot.endTime.hour ?? 0) * 60 + (slot.endTime.minute ?? 0))
        }
    }

    guard let m = nextMinutes else { return nil }

    let calendar = Calendar.current
    var components = calendar.dateComponents([.year, .month, .day], from: Date())
    components.hour = m / 60
    components.minute = m % 60
    components.second = 0
    return calendar.date(from: components)
}

func shouldShowTomorrow() -> Bool {
    guard let sharedDefaults = UserDefaults(suiteName: appGroupId) else {
        return false
    }
    return sharedDefaults.bool(forKey: "widget_show_tomorrow")
}

func loadWidgetData() -> (courses: [Course], dateText: String, weekText: String, isTomorrow: Bool, nextTransition: Date?)? {
    print("BugaoShan Widget: loadWidgetData() called")

    guard let dbPath = getDatabasePath() else {
        print("BugaoShan Widget: Failed to get database path")
        return nil
    }
    print("BugaoShan Widget: Database path: \(dbPath)")

    // Check if file exists
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: dbPath) {
        print("BugaoShan Widget: Database file does NOT exist at \(dbPath)")
        return nil
    } else {
        print("BugaoShan Widget: Database file exists at \(dbPath)")
        // Check file attributes
        if let attrs = try? fileManager.attributesOfItem(atPath: dbPath) {
            let fileSize = attrs[.size] as? Int64 ?? 0
            print("BugaoShan Widget: Database file size: \(fileSize) bytes")
        }
    }

    var db: OpaquePointer?
    // 如果只读模式打开失败
    if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
        print("BugaoShan Widget: Failed to open database in read-only mode, trying read-write")
        // 尝试读写模式，如果也失败，则退出并返回 nil
        if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READWRITE, nil) != SQLITE_OK {
            let errorMsg = String(cString: sqlite3_errmsg(db)!)
            print("BugaoShan Widget: Failed to open database in read-write mode: \(errorMsg)")
            return nil
        }
    }
    defer { sqlite3_close(db) }
    print("BugaoShan Widget: Database opened successfully")

    guard let safeDB = db else { return nil }
    let currentScheduleId = queryMetadata(safeDB, key: "currentScheduleId") ?? "default"
    print("BugaoShan Widget: Current schedule ID from metadata: \(currentScheduleId)")

    guard let (config, actualScheduleId) = queryScheduleConfig(safeDB, scheduleId: currentScheduleId) else {
        print("BugaoShan Widget: Failed to load schedule config for ID: \(currentScheduleId)")
        return nil
    }
    print("BugaoShan Widget: Schedule config loaded for ID: \(actualScheduleId) - semesterStartDate: \(config.semesterStartDate), totalWeeks: \(config.totalWeeks)")

    let calendar = Calendar.current
    let now = Date()
    let dayOfWeek = (calendar.component(.weekday, from: now) + 5) % 7 + 1 // Convert to Monday=1 to Sunday=7
    let currentWeek = computeCurrentWeek(semesterStartDate: config.semesterStartDate, totalWeeks: config.totalWeeks)
    print("BugaoShan Widget: Today - dayOfWeek: \(dayOfWeek), currentWeek: \(currentWeek)")

    var courses = queryCourses(safeDB, scheduleId: actualScheduleId, dayOfWeek: dayOfWeek, currentWeek: currentWeek)
    print("BugaoShan Widget: Loaded \(courses.count) courses for today")

    let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
    let currentTimeMinutes = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)

    courses = attachTimesAndStatuses(courses, timeSlots: config.timeSlots, currentTimeMinutes: currentTimeMinutes)
    print("BugaoShan Widget: After applying status - \(courses.count) courses")

    var isTomorrow = false
    // ✨ 如果今天没有课，或者今天的课“全都上完了”，才尝试显示明天
    let hasUnfinishedCourses = courses.contains { $0.status != .completed }

    if !hasUnfinishedCourses && shouldShowTomorrow() {
        print("BugaoShan Widget: No active courses for today, checking tomorrow")
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
            let tomorrowDayOfWeek = (calendar.component(.weekday, from: tomorrow) + 5) % 7 + 1
            let tomorrowWeek = computeWeekForDate(semesterStartDate: config.semesterStartDate, totalWeeks: config.totalWeeks, date: tomorrow)
            let tomorrowCourses = queryCourses(safeDB, scheduleId: actualScheduleId, dayOfWeek: tomorrowDayOfWeek, currentWeek: tomorrowWeek)

            // 显示明天的课
            isTomorrow = true
            if !tomorrowCourses.isEmpty {
                // 明天有课时: 获取明天的课时，依然全部标记为 upcoming
                courses = attachTimesAndStatuses(tomorrowCourses, timeSlots: config.timeSlots, currentTimeMinutes: nil, forceUpcoming: true)
            } else {
                // 明天没课时: 清空今天已完成的课，展示"明天没课"
                courses = []
            }
        }
    }

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "M/d"
    let dayFormatter = DateFormatter()
    dayFormatter.dateFormat = "EEE"
    dayFormatter.locale = Locale(identifier: "zh_CN")

    let displayDate = isTomorrow ? calendar.date(byAdding: .day, value: 1, to: now)! : now
    let weekNum = isTomorrow ? computeWeekForDate(semesterStartDate: config.semesterStartDate, totalWeeks: config.totalWeeks, date: displayDate) : currentWeek

    var dateText = "\(dateFormatter.string(from: displayDate)) \(dayFormatter.string(from: displayDate))"
    if isTomorrow {
        dateText += " 明天"
    }
    let weekText = "第\(weekNum)周"

    let nextTransition = isTomorrow ? nil : computeNextTransitionMillis(courses, timeSlots: config.timeSlots, currentTimeMinutes: currentTimeMinutes)

    return (courses, dateText, weekText, isTomorrow, nextTransition)
}

struct CourseWidgetEntry: TimelineEntry {
    let date: Date
    let courses: [Course]
    let dateText: String
    let weekText: String
    let isTomorrow: Bool
}

struct CourseProvider: TimelineProvider {
    func placeholder(in context: Context) -> CourseWidgetEntry {
        CourseWidgetEntry(
            date: Date(),
            courses: [
                Course(name: "高等数学", teacher: "张老师", location: "教学楼A101", startSection: 1, endSection: 2, colorValue: 0xFF4CAF50, status: .inProgress),
                Course(name: "大学物理", teacher: "李老师", location: "教学楼B202", startSection: 3, endSection: 4, colorValue: 0xFF2196F3, status: .upcoming)
            ],
            dateText: "1/1 周一",
            weekText: "第1周",
            isTomorrow: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CourseWidgetEntry) -> ()) {
        if let data = loadWidgetData() {
            let entry = CourseWidgetEntry(
                date: Date(),
                courses: data.courses,
                dateText: data.dateText,
                weekText: data.weekText,
                isTomorrow: data.isTomorrow
            )
            completion(entry)
        } else {
            completion(placeholder(in: context))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let now = Date()

        if let data = loadWidgetData() {
            let entry = CourseWidgetEntry(
                date: now,
                courses: data.courses,
                dateText: data.dateText,
                weekText: data.weekText,
                isTomorrow: data.isTomorrow
            )

            var nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: now)
            if let nextTransition = data.nextTransition, nextTransition > now {
                // 确保至少有 1 分钟的间隔，防止瞬间重复刷新
                nextUpdate = max(nextTransition, now.addingTimeInterval(60))
            } else if data.courses.isEmpty {
                // If no courses, update at midnight
//                nextUpdate = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Calendar.current.date(byAdding: .day, value: 1, to: now)!)
                // 安全解包
                if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now),
                   let midnight = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow)
                {
                    nextUpdate = midnight
                } else {
                    nextUpdate = now.addingTimeInterval(3600) // Fallback
                }
            }

            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate!))
            completion(timeline)
        } else {
            let entry = placeholder(in: context)
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: now)
            completion(Timeline(entries: [entry], policy: .after(nextUpdate!)))
        }
    }
}

// 桌面小组件
struct DesktopWidgetView: View {
    var entry: CourseProvider.Entry
    var widgetFamily: WidgetFamily

    var body: some View {
        // iOS 17 以后系统自带了 widget margin (约16px)。
        // 如果再加一层外边距会导致内容被过度挤压。建议移除或大幅减小这里的手动 padding。
        let widgetPadding: CGFloat = widgetFamily == .systemSmall ? 0 : 2

        // 适当增大最外层间距，让内容呼吸感更强
        VStack(alignment: .leading, spacing: widgetFamily == .systemSmall ? 8 : 12) {
            // 1. 动态头部
            HStack {
                if widgetFamily == .systemLarge {
                    Text("不高山上")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(entry.dateText) \(entry.weekText)")
                        .font(.subheadline) // 稍微调大
                        .foregroundColor(.secondary)
                } else {
                    Text("\(entry.dateText) \(entry.weekText)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(.bottom, 2)

            // 根据尺寸决定是否保留“已上完的课”
            let displayableCourses = widgetFamily == .systemLarge
                ? entry.courses
                : entry.courses.filter { $0.status != .completed }

            if displayableCourses.isEmpty {
                Spacer(minLength: 0)
                // 区分是真没课，还是课上完了
                Text(entry.courses.isEmpty ? (entry.isTomorrow ? "明天没课" : "今天没课") : "今天的课都上完啦")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 0)
            } else {
                // 中组件限制为2节，大组件限制为6节
                let maxCourses = (widgetFamily == .systemSmall || widgetFamily == .systemMedium) ? 2 : 6
                let displayCourses = Array(displayableCourses.prefix(maxCourses))

                VStack(alignment: .leading, spacing: widgetFamily == .systemSmall ? 8 : 10) {
                    ForEach(displayCourses.indices, id: \.self) { index in
                        CourseCard(course: displayCourses[index], isTomorrow: entry.isTomorrow, compact: widgetFamily == .systemSmall)
                    }
                }
                // 底部剩余课程提示
                if displayableCourses.count > maxCourses {
                    Text("还有 \(displayableCourses.count - maxCourses) 节课")
                        .font(.caption) // 从 .caption2 调大为 .caption
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(widgetPadding)
    }
}

// 锁屏小组件
struct LockScreenRectangularView: View {
    var entry: CourseProvider.Entry

    var body: some View {
        // 过滤掉已经上完的课，获取接下来要上的第一节课
        let pendingCourses = entry.courses.filter { $0.status != .completed }
        let nextCourse = pendingCourses.first

        VStack(alignment: .leading, spacing: 4) {
            if let course = nextCourse {
                // 有课的状态
                HStack(alignment: .center) {
                    // 可以加一个图标增加辨识度
                    Image(systemName: "book.closed.fill")
                        .font(.caption2)
                    Text(course.name)
                        .font(.headline)
                        .fontWeight(.bold)
                }
                // ✨ .widgetAccentable() 能够让这段文字跟随用户在锁屏设置的自定义颜色
                .widgetAccentable()

                Text("\(formatCourseTime(course)) · \(course.location)")
                    .font(.caption)
                    .lineLimit(1)
                    // 锁屏下使用 .secondary 会自动渲染为半透明，形成层级感
                    .foregroundColor(.secondary)
            } else {
                // 没课的状态
                HStack {
                    Image(systemName: "sparkles")
                    Text(entry.isTomorrow ? "明天没课" : "今天课上完啦")
                        .font(.headline)
                }
                .widgetAccentable()

                Text("好好休息吧")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        // 锁屏组件需要撑满靠左对齐
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 提取格式化时间的工具方法（原先在你写的 CourseCard 里，现在提出来共用）
    private func formatCourseTime(_ course: Course) -> String {
        if course.startSection == course.endSection {
            return "第\(course.startSection)节"
        } else {
            return "第\(course.startSection)-\(course.endSection)节"
        }
    }
}

struct CourseWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: CourseProvider.Entry

    var body: some View {
        switch widgetFamily {
            case .accessoryRectangular:
                // 锁屏小组件视图
                LockScreenRectangularView(entry: entry)
            default:
                // 桌面小组件视图
                DesktopWidgetView(entry: entry, widgetFamily: widgetFamily)
        }
    }
}

struct CourseCard: View {
    let course: Course
    let isTomorrow: Bool
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            // 小组件下课程名使用更大的 .footnote，时间地点使用 .caption2
            Text(course.name)
                .font(compact ? .footnote : .subheadline)
                .fontWeight(course.status == .inProgress ? .bold : .medium)
                .foregroundColor(isTomorrow ? .orange : .primary)
                .lineLimit(2)

            // 显示具体小时分钟，如果解析失败则回退到"第x-y节"
            let timeDisplay = course.timeText ?? formatCourseTime()

            if compact {
                // Small 尺寸：分三行，地点与时间独立
                if !course.location.isEmpty {
                    Text(course.location)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Text(timeDisplay)
                    .font(.caption2)
                    .foregroundColor(course.status == .inProgress ? courseColor : .secondary)
                    .lineLimit(1)
            } else {
                // Medium / Large 尺寸：合并为一行
                Text("\(timeDisplay) · \(course.location)")
                    .font(.caption)
                    .foregroundColor(course.status == .inProgress ? courseColor : .secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // 宽度 3 + 间距 6 = 9 (Compact)；宽度 4 + 间距 8 = 12 (Normal)
        // 这样既能精确控制间距，又能保证色条与文本区绝对等高，不会无限拉伸出 bug！
        .padding(.leading, compact ? 9 : 12)
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .fill(courseColor)
                .frame(width: compact ? 3 : 4),
            alignment: .leading
        )
        // 由于 HStack 自动包裹高度，竖线会自动与 VStack 等高。无需额外设定高度。
        .opacity(course.status == .completed ? 0.4 : 1.0)
    }

    var courseColor: Color {
        let argb = UInt32(bitPattern: Int32(truncatingIfNeeded: course.colorValue))
        if argb == 0 || (argb >> 24) == 0 {
            return isTomorrow ? .orange : .blue
        }
        let a = Double((argb >> 24) & 0xFF) / 255.0
        let r = Double((argb >> 16) & 0xFF) / 255.0
        let g = Double((argb >> 8) & 0xFF) / 255.0
        let b = Double(argb & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b, opacity: a)
    }

    func formatCourseTime() -> String {
        if course.startSection == course.endSection {
            return "第\(course.startSection)节"
        } else {
            return "第\(course.startSection)-\(course.endSection)节"
        }
    }
}

@main
struct CourseWidget: Widget {
    let kind: String = "CourseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CourseProvider()) { entry in
            CourseWidgetEntryView(entry: entry)
                .containerBackground(Color(.systemBackground), for: .widget)
        }
        .configurationDisplayName("课表组件")
        .description("显示不高山上的课表信息")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
