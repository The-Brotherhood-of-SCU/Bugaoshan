import AppIntents
import Foundation
import SQLite3
import SwiftUI

// MARK: - 数据模型

@available(iOS 16.0, *)
public struct IntentCourseInfo: Identifiable, Sendable {
    public let id = UUID()
    public let name: String
    public let teacher: String
    public let location: String
    public let startSection: Int
    public let endSection: Int
    public let startTimeText: String
    public let endTimeText: String
    public let isCurrent: Bool
    public let isCompleted: Bool

    public var sectionText: String {
        startSection == endSection ? "第\(startSection)节" : "第\(startSection)-\(endSection)节"
    }

    public var timeRangeText: String {
        "\(startTimeText) - \(endTimeText)"
    }

    public var hasValidTimeRange: Bool {
        startTimeText != "--:--" && endTimeText != "--:--"
    }

    public var trimmedLocation: String {
        location.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 语音播报用的上课地点从句；无教室时返回空串，避免拼出「在，」。
    public var speechLocationClause: String {
        trimmedLocation.isEmpty ? "" : "，在\(trimmedLocation)"
    }

    /// 卡片副标题用的课程简述；无教室时不拼接空括号。
    public var briefTitleWithLocation: String {
        trimmedLocation.isEmpty ? name : "\(name) (\(trimmedLocation))"
    }

    /// 语音播报用的开始时间描述；节次时间缺失时回退为节次文本。
    public var speechStartClause: String {
        startTimeText == "--:--" ? sectionText : "\(startTimeText)开始"
    }

    /// 语音播报用的下课时间描述；节次时间缺失时回退为节次文本。
    public var speechEndClause: String {
        endTimeText == "--:--" ? "（\(sectionText)）" : "，将于\(endTimeText)下课"
    }
}

@available(iOS 16.0, *)
public enum CourseQueryResult: Sendable {
    case noData
    case onVacation(message: String)
    case noCourses(dateDescription: String)
    case success(
        courses: [IntentCourseInfo],
        dateDescription: String,
        currentWeek: Int,
        activeCourse: IntentCourseInfo?,
        nextCourse: IntentCourseInfo?
    )
}

// MARK: - 课表数据读取工具

@available(iOS 16.0, *)
public final class CourseIntentDataProvider {
    public static let shared = CourseIntentDataProvider()
    private static let appGroupId = "group.io.github.thebrotherhoodofscu.bugaoshan.ios"
    private let databasePathResolver: () -> String?

    public convenience init() {
        self.init(databasePathResolver: Self.defaultDatabasePath)
    }

    init(databasePathResolver: @escaping () -> String?) {
        self.databasePathResolver = databasePathResolver
    }

    private struct TimeSlotData {
        let section: Int
        let startHour: Int
        let startMinute: Int
        let endHour: Int
        let endMinute: Int
    }

    private struct ScheduleData {
        let scheduleId: String
        let semesterStartDate: Date
        let totalWeeks: Int
        let timeSlots: [TimeSlotData]
    }

    private static func defaultDatabasePath() -> String? {
        let fileManager = FileManager.default

        // 1. 优先读取 App Group 共享目录
        if let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
            let path = containerURL.appendingPathComponent("bugaoshan.db").path
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }

        // 2. 兜底读取本地沙盒 Application Support 目录（个人免费账号未配置 App Group 时）
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let path = appSupportURL.appendingPathComponent("bugaoshan.db").path
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }

        // 3. 兜底读取 Documents 目录
        if let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let path = docsURL.appendingPathComponent("bugaoshan.db").path
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }

        return nil
    }

    private func getDatabasePath() -> String? {
        databasePathResolver()
    }

    private func courseWeekAnchor(semesterStartDate: Date) -> Date? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: semesterStartDate)
        let isoWeekday = (calendar.component(.weekday, from: start) + 5) % 7 + 1
        return calendar.date(byAdding: .day, value: -(isoWeekday % 7), to: start)
    }

    private func computeWeekForDate(semesterStartDate: Date, totalWeeks: Int, date: Date) -> Int {
        let calendar = Calendar.current
        let target = calendar.startOfDay(for: date)
        guard let anchor = courseWeekAnchor(semesterStartDate: semesterStartDate) else { return 1 }
        if target < anchor { return 1 }
        let days = calendar.dateComponents([.day], from: anchor, to: target).day ?? 0
        let week = days / 7 + 1
        return max(1, min(week, totalWeeks))
    }

    private func computeSemesterEndDate(semesterStartDate: Date, totalWeeks: Int) -> Date? {
        guard totalWeeks > 0 else { return nil }
        guard let anchor = courseWeekAnchor(semesterStartDate: semesterStartDate) else { return nil }
        return Calendar.current.date(byAdding: .day, value: totalWeeks * 7 - 1, to: anchor)
    }

    private func isCourseActive(
        currentWeek: Int,
        startWeek: Int,
        endWeek: Int,
        weekType: Int,
        customWeeks: String?
    ) -> Bool {
        if let customWeeks = customWeeks, !customWeeks.isEmpty {
            let activeWeeks = customWeeks.split(separator: ",").compactMap {
                Int($0.trimmingCharacters(in: .whitespaces))
            }
            if !activeWeeks.isEmpty {
                return activeWeeks.contains(currentWeek)
            }
        }
        guard currentWeek >= startWeek && currentWeek <= endWeek else {
            return false
        }
        if weekType == 1 && currentWeek % 2 == 0 { return false }
        if weekType == 2 && currentWeek % 2 == 1 { return false }
        return true
    }

    private static func intValue(_ raw: Any?) -> Int? {
        if let value = raw as? Int { return value }
        if let num = raw as? NSNumber { return num.intValue }
        return nil
    }

    private func loadScheduleData(db: OpaquePointer) -> ScheduleData? {
        var activeId: String?
        var metaStmt: OpaquePointer?
        // 与 DatabaseService._keyCurrentScheduleId 及 WidgetExtension 保持同一键名
        let metaQuery = "SELECT value FROM metadata WHERE key = 'currentScheduleId'"
        if sqlite3_prepare_v2(db, metaQuery, -1, &metaStmt, nil) == SQLITE_OK {
            if sqlite3_step(metaStmt) == SQLITE_ROW,
               let cStr = sqlite3_column_text(metaStmt, 0) {
                activeId = String(cString: cStr)
            }
            sqlite3_finalize(metaStmt)
        }

        var jsonString: String?
        var resolvedScheduleId: String?

        if let targetId = activeId, !targetId.isEmpty {
            var schedStmt: OpaquePointer?
            let schedQuery = "SELECT config_json FROM schedules WHERE id = ?"
            if sqlite3_prepare_v2(db, schedQuery, -1, &schedStmt, nil) == SQLITE_OK {
                _ = targetId.withCString { cStr in
                    sqlite3_bind_text(schedStmt, 1, cStr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                }
                if sqlite3_step(schedStmt) == SQLITE_ROW,
                   let cStr = sqlite3_column_text(schedStmt, 0) {
                    jsonString = String(cString: cStr)
                    resolvedScheduleId = targetId
                }
                sqlite3_finalize(schedStmt)
            }
        }

        if jsonString == nil {
            var fallbackStmt: OpaquePointer?
            let fallbackQuery = "SELECT id, config_json FROM schedules LIMIT 1"
            if sqlite3_prepare_v2(db, fallbackQuery, -1, &fallbackStmt, nil) == SQLITE_OK {
                if sqlite3_step(fallbackStmt) == SQLITE_ROW,
                   let idCStr = sqlite3_column_text(fallbackStmt, 0),
                   let jsonCStr = sqlite3_column_text(fallbackStmt, 1) {
                    resolvedScheduleId = String(cString: idCStr)
                    jsonString = String(cString: jsonCStr)
                }
                sqlite3_finalize(fallbackStmt)
            }
        }

        guard let validJson = jsonString,
              let finalId = resolvedScheduleId,
              let jsonData = validJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let startStr = json["semesterStartDate"] as? String,
              let totalWeeks = Self.intValue(json["totalWeeks"])
        else {
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        guard let semesterStartDate = dateFormatter.date(from: startStr) else {
            return nil
        }

        var timeSlots: [TimeSlotData] = []
        if let slotsArray = json["timeSlots"] as? [[String: Any]] {
            for (idx, slot) in slotsArray.enumerated() {
                if let startDict = slot["startTime"] as? [String: Any],
                   let endDict = slot["endTime"] as? [String: Any],
                   let sHour = Self.intValue(startDict["hour"]),
                   let sMin = Self.intValue(startDict["minute"]),
                   let eHour = Self.intValue(endDict["hour"]),
                   let eMin = Self.intValue(endDict["minute"]) {
                    timeSlots.append(TimeSlotData(
                        section: idx + 1,
                        startHour: sHour,
                        startMinute: sMin,
                        endHour: eHour,
                        endMinute: eMin
                    ))
                }
            }
        }

        return ScheduleData(
            scheduleId: finalId,
            semesterStartDate: semesterStartDate,
            totalWeeks: totalWeeks,
            timeSlots: timeSlots
        )
    }

    public func queryCourses(for targetDate: Date, now: Date = Date()) -> CourseQueryResult {
        guard let dbPath = getDatabasePath() else {
            return .noData
        }

        var db: OpaquePointer?
        if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READWRITE, nil) != SQLITE_OK {
                return .noData
            }
        }
        defer { sqlite3_close(db) }
        guard let safeDb = db else { return .noData }
        sqlite3_busy_timeout(safeDb, 5000)

        guard let schedule = loadScheduleData(db: safeDb) else {
            return .noData
        }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: targetDate)
        guard let weekOneAnchor = courseWeekAnchor(semesterStartDate: schedule.semesterStartDate),
              let semesterEnd = computeSemesterEndDate(
                  semesterStartDate: schedule.semesterStartDate,
                  totalWeeks: schedule.totalWeeks
              )
        else {
            return .noData
        }

        if todayStart < weekOneAnchor {
            return .onVacation(message: "当前学期尚未开始，享受假期时光吧！")
        }
        if todayStart > semesterEnd {
            return .onVacation(message: "本学期已结课，假期愉快！")
        }

        let currentWeek = computeWeekForDate(
            semesterStartDate: schedule.semesterStartDate,
            totalWeeks: schedule.totalWeeks,
            date: targetDate
        )

        let isoWeekday = (calendar.component(.weekday, from: targetDate) + 5) % 7 + 1

        var hasCustomWeeks = false
        var pragmaStmt: OpaquePointer?
        if sqlite3_prepare_v2(safeDb, "PRAGMA table_info(courses)", -1, &pragmaStmt, nil) == SQLITE_OK {
            while sqlite3_step(pragmaStmt) == SQLITE_ROW {
                if let col = sqlite3_column_text(pragmaStmt, 1).flatMap({ String(cString: $0) }),
                   col == "custom_weeks" {
                    hasCustomWeeks = true
                    break
                }
            }
            sqlite3_finalize(pragmaStmt)
        }

        let query = hasCustomWeeks
            ? "SELECT name, teacher, location, start_week, end_week, start_section, end_section, week_type, custom_weeks FROM courses WHERE schedule_id = ? AND day_of_week = ?"
            : "SELECT name, teacher, location, start_week, end_week, start_section, end_section, week_type FROM courses WHERE schedule_id = ? AND day_of_week = ?"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(safeDb, query, -1, &stmt, nil) == SQLITE_OK else {
            return .noData
        }
        defer { sqlite3_finalize(stmt) }

        _ = schedule.scheduleId.withCString { cStr in
            sqlite3_bind_text(stmt, 1, cStr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        sqlite3_bind_int(stmt, 2, Int32(isoWeekday))

        struct RawCourse {
            let name: String
            let teacher: String
            let location: String
            let startSection: Int
            let endSection: Int
        }

        var rawList: [RawCourse] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let startWeek = Int(sqlite3_column_int(stmt, 3))
            let endWeek = Int(sqlite3_column_int(stmt, 4))
            let weekType = Int(sqlite3_column_int(stmt, 7))
            let customWeeks = hasCustomWeeks ? (sqlite3_column_text(stmt, 8).flatMap { String(cString: $0) }) : nil

            guard isCourseActive(
                currentWeek: currentWeek,
                startWeek: startWeek,
                endWeek: endWeek,
                weekType: weekType,
                customWeeks: customWeeks
            ) else { continue }

            let name = sqlite3_column_text(stmt, 0).flatMap { String(cString: $0) } ?? ""
            let teacher = sqlite3_column_text(stmt, 1).flatMap { String(cString: $0) } ?? ""
            let location = sqlite3_column_text(stmt, 2).flatMap { String(cString: $0) } ?? ""
            let startSection = Int(sqlite3_column_int(stmt, 5))
            let endSection = Int(sqlite3_column_int(stmt, 6))

            rawList.append(RawCourse(
                name: name,
                teacher: teacher,
                location: location,
                startSection: startSection,
                endSection: endSection
            ))
        }

        rawList.sort { ($0.startSection, $0.endSection) < ($1.startSection, $1.endSection) }

        let isSameDayAsNow = calendar.isDate(targetDate, inSameDayAs: now)
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        let nowMinutes = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)

        var courses: [IntentCourseInfo] = []
        var activeCourse: IntentCourseInfo?
        var nextCourse: IntentCourseInfo?

        for raw in rawList {
            let sSlot = schedule.timeSlots.first { $0.section == raw.startSection }
            let eSlot = schedule.timeSlots.first { $0.section == raw.endSection }

            let startTimeText: String
            let endTimeText: String
            let isCurrent: Bool
            let isCompleted: Bool
            let isUpcomingToday: Bool

            if let sSlot, let eSlot {
                startTimeText = String(format: "%02d:%02d", sSlot.startHour, sSlot.startMinute)
                endTimeText = String(format: "%02d:%02d", eSlot.endHour, eSlot.endMinute)
                let startMinutes = sSlot.startHour * 60 + sSlot.startMinute
                let endMinutes = eSlot.endHour * 60 + eSlot.endMinute

                if isSameDayAsNow && endMinutes >= startMinutes {
                    isCurrent = nowMinutes >= startMinutes && nowMinutes < endMinutes
                    isCompleted = nowMinutes >= endMinutes
                    isUpcomingToday = startMinutes > nowMinutes
                } else {
                    isCurrent = false
                    isCompleted = false
                    isUpcomingToday = false
                }
            } else {
                startTimeText = sSlot.map { String(format: "%02d:%02d", $0.startHour, $0.startMinute) } ?? "--:--"
                endTimeText = eSlot.map { String(format: "%02d:%02d", $0.endHour, $0.endMinute) } ?? "--:--"
                isCurrent = false
                isCompleted = false
                isUpcomingToday = isSameDayAsNow
            }

            let info = IntentCourseInfo(
                name: raw.name,
                teacher: raw.teacher,
                location: raw.location,
                startSection: raw.startSection,
                endSection: raw.endSection,
                startTimeText: startTimeText,
                endTimeText: endTimeText,
                isCurrent: isCurrent,
                isCompleted: isCompleted
            )
            courses.append(info)

            if isCurrent && activeCourse == nil {
                activeCourse = info
            }

            if isUpcomingToday && nextCourse == nil {
                nextCourse = info
            }
        }

        let weekdayNames = ["一", "二", "三", "四", "五", "六", "日"]
        let weekdayName = weekdayNames[max(0, min(isoWeekday - 1, 6))]
        let tomorrowOfNow = calendar.date(byAdding: .day, value: 1, to: now)
        let dayPrefix: String
        if isSameDayAsNow {
            dayPrefix = "今天"
        } else if let tomorrowOfNow, calendar.isDate(targetDate, inSameDayAs: tomorrowOfNow) {
            dayPrefix = "明天"
        } else {
            let mdFormatter = DateFormatter()
            mdFormatter.locale = Locale(identifier: "zh_CN")
            mdFormatter.dateFormat = "M月d日"
            dayPrefix = mdFormatter.string(from: targetDate)
        }
        let dateDesc = "\(dayPrefix) (第\(currentWeek)周·周\(weekdayName))"

        if courses.isEmpty {
            return .noCourses(dateDescription: dateDesc)
        }

        return .success(
            courses: courses,
            dateDescription: dateDesc,
            currentWeek: currentWeek,
            activeCourse: activeCourse,
            nextCourse: nextCourse
        )
    }
}

// MARK: - Siri / 快捷指令界面卡片 (SwiftUI Snippets)

@available(iOS 16.0, *)
public struct NextCourseSnippetView: View {
    public let activeCourse: IntentCourseInfo?
    public let nextCourse: IntentCourseInfo?
    public let summaryText: String
    public let subtitleText: String?

    public init(
        activeCourse: IntentCourseInfo?,
        nextCourse: IntentCourseInfo?,
        summaryText: String,
        subtitleText: String?
    ) {
        self.activeCourse = activeCourse
        self.nextCourse = nextCourse
        self.summaryText = summaryText
        self.subtitleText = subtitleText
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let active = activeCourse {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("正在上课", systemImage: "play.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.orange)
                        Spacer()
                        Text(active.sectionText)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                    Text(active.name)
                        .font(.headline)
                        .lineLimit(2)
                    HStack(spacing: 12) {
                        Label(active.timeRangeText, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if !active.trimmedLocation.isEmpty {
                            Label(active.trimmedLocation, systemImage: "mappin.and.ellipse")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(10)
            }

            if let next = nextCourse {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(activeCourse != nil ? "下一节课" : "下节课预告", systemImage: "book.fill")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.accentColor)
                        Spacer()
                        Text(next.sectionText)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                    }
                    Text(next.name)
                        .font(.headline)
                        .lineLimit(2)
                    HStack(spacing: 12) {
                        Label(next.timeRangeText, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if !next.trimmedLocation.isEmpty {
                            Label(next.trimmedLocation, systemImage: "mappin.and.ellipse")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(10)
            }

            if activeCourse == nil && nextCourse == nil {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(summaryText)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 4)
            }

            if let subtitle = subtitleText, !subtitle.isEmpty {
                Divider()
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
    }
}

@available(iOS 16.0, *)
public struct DailyCoursesSnippetView: View {
    public let title: String
    public let courses: [IntentCourseInfo]
    public let emptyMessage: String?

    public init(title: String, courses: [IntentCourseInfo], emptyMessage: String? = nil) {
        self.title = title
        self.courses = courses
        self.emptyMessage = emptyMessage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if !courses.isEmpty {
                    Text("共 \(courses.count) 节课")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(4)
                }
            }

            if courses.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundColor(.orange)
                    Text(emptyMessage ?? "今日无课程安排")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 6) {
                    ForEach(courses) { course in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(course.startTimeText)
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(course.isCurrent ? .orange : (course.isCompleted ? .secondary : .primary))
                                Text(course.endTimeText)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 44, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(course.name)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                    .strikethrough(course.isCompleted, color: .secondary)
                                    .foregroundColor(course.isCompleted ? .secondary : .primary)
                                if !course.trimmedLocation.isEmpty {
                                    HStack(spacing: 3) {
                                        Image(systemName: "mappin.and.ellipse")
                                            .font(.system(size: 9))
                                        Text(course.trimmedLocation)
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                }
                            }

                            Spacer()

                            if course.isCurrent {
                                Text("进行中")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(4)
                            } else if course.isCompleted {
                                Image(systemName: "checkmark.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(course.isCurrent ? Color.orange.opacity(0.08) : Color.clear)
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding(12)
    }
}

// MARK: - 语音文案构建工具

@available(iOS 16.0, *)
enum CourseIntentSpeechFormatter {
    static func formatDailySummary(dayLabel: String, courses: [IntentCourseInfo]) -> String {
        let courseCount = courses.count
        if courseCount == 1, let c = courses.first {
            let timeDetail = c.hasValidTimeRange ? c.timeRangeText : c.sectionText
            return "你\(dayLabel)有 1 节课：《\(c.name)》\(c.speechLocationClause)，\(timeDetail)。"
        }
        let items = courses.prefix(3).map { c in
            let loc = c.trimmedLocation.isEmpty ? "" : "在\(c.trimmedLocation)"
            return "\(c.sectionText)《\(c.name)》\(loc)"
        }.joined(separator: "；")
        return courseCount > 3
            ? "你\(dayLabel)一共有 \(courseCount) 节课：\(items) 等，可在屏幕查看完整课表。"
            : "你\(dayLabel)一共有 \(courseCount) 节课：\(items)。"
    }
}

// MARK: - App Intents 定义

@available(iOS 16.0, *)
public struct GetNextCourseIntent: AppIntent {
    public static var title: LocalizedStringResource = "查询下节课"
    public static var description = IntentDescription("查询下一节课程的名称、教室和上课时间")
    public static var openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView & ReturnsValue<String> {
        let provider = CourseIntentDataProvider.shared
        let now = Date()
        let todayResult = provider.queryCourses(for: now, now: now)

        switch todayResult {
        case .noData:
            let text = "还没有找到你的课表数据，请先打开不高山上 App 导入或同步课表。"
            return .result(value: text, dialog: IntentDialog(stringLiteral: text)) {
                NextCourseSnippetView(
                    activeCourse: nil,
                    nextCourse: nil,
                    summaryText: text,
                    subtitleText: "提示：在 App 登录后将自动同步课表"
                )
            }

        case .onVacation(let message):
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
            let tomorrowResult = provider.queryCourses(for: tomorrow, now: now)
            if case .success(let tomorrowCourses, _, _, _, _) = tomorrowResult,
               let firstTomorrow = tomorrowCourses.first {
                let speech = "明天即将开始新学期课程！第一节课是《\(firstTomorrow.name)》\(firstTomorrow.speechLocationClause)，\(firstTomorrow.speechStartClause)。"
                return .result(value: speech, dialog: IntentDialog(stringLiteral: speech)) {
                    NextCourseSnippetView(
                        activeCourse: nil,
                        nextCourse: firstTomorrow,
                        summaryText: "新学期明日开课",
                        subtitleText: "明早首节：\(firstTomorrow.briefTitleWithLocation)"
                    )
                }
            }
            let text = "当前处于假期中：\(message)"
            return .result(value: text, dialog: IntentDialog(stringLiteral: text)) {
                NextCourseSnippetView(
                    activeCourse: nil,
                    nextCourse: nil,
                    summaryText: text,
                    subtitleText: nil
                )
            }

        case .noCourses:
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
            let tomorrowResult = provider.queryCourses(for: tomorrow, now: now)

            if case .success(let tomorrowCourses, _, _, _, _) = tomorrowResult,
               let firstTomorrow = tomorrowCourses.first {
                let speech = "今天没有课程安排。明天的第一节课是《\(firstTomorrow.name)》\(firstTomorrow.speechLocationClause)，\(firstTomorrow.speechStartClause)。"
                return .result(value: speech, dialog: IntentDialog(stringLiteral: speech)) {
                    NextCourseSnippetView(
                        activeCourse: nil,
                        nextCourse: firstTomorrow,
                        summaryText: "今天无课 · 明天首节预告",
                        subtitleText: "明早首节：\(firstTomorrow.briefTitleWithLocation)"
                    )
                }
            } else {
                let text = "今天没有课程安排，明天也没有课，好好休息吧！"
                return .result(value: text, dialog: IntentDialog(stringLiteral: text)) {
                    NextCourseSnippetView(
                        activeCourse: nil,
                        nextCourse: nil,
                        summaryText: text,
                        subtitleText: nil
                    )
                }
            }

        case .success(_, _, _, let active, let next):
            if let active = active {
                if let next = next {
                    let speech = "你正在上《\(active.name)》\(active.speechLocationClause)\(active.speechEndClause)。下一节课是《\(next.name)》\(next.speechLocationClause)，\(next.speechStartClause)。"
                    return .result(value: speech, dialog: IntentDialog(stringLiteral: speech)) {
                        NextCourseSnippetView(
                            activeCourse: active,
                            nextCourse: next,
                            summaryText: "正在上课中",
                            subtitleText: "下节预告：\(next.briefTitleWithLocation)"
                        )
                    }
                } else {
                    let speech = "你正在上今天的最后一节课《\(active.name)》\(active.speechLocationClause)\(active.speechEndClause)。"
                    return .result(value: speech, dialog: IntentDialog(stringLiteral: speech)) {
                        NextCourseSnippetView(
                            activeCourse: active,
                            nextCourse: nil,
                            summaryText: "今日最后一节课",
                            subtitleText: "下课后今天就结课啦！"
                        )
                    }
                }
            } else if let next = next {
                let startDetail = next.startTimeText == "--:--" ? "（\(next.sectionText)）" : "，将于\(next.startTimeText)开始"
                let speech = "你的下一节课是《\(next.name)》\(next.speechLocationClause)\(startDetail)。"
                let subtitle = next.hasValidTimeRange ? "\(next.sectionText) · \(next.timeRangeText)" : next.sectionText
                return .result(value: speech, dialog: IntentDialog(stringLiteral: speech)) {
                    NextCourseSnippetView(
                        activeCourse: nil,
                        nextCourse: next,
                        summaryText: "下一节课",
                        subtitleText: subtitle
                    )
                }
            } else {
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
                let tomorrowResult = provider.queryCourses(for: tomorrow, now: now)

                if case .success(let tomorrowCourses, _, _, _, _) = tomorrowResult,
                   let firstTomorrow = tomorrowCourses.first {
                    let speech = "今天的所有课程已经结束啦！明天的第一节课是《\(firstTomorrow.name)》\(firstTomorrow.speechLocationClause)，\(firstTomorrow.speechStartClause)。"
                    return .result(value: speech, dialog: IntentDialog(stringLiteral: speech)) {
                        NextCourseSnippetView(
                            activeCourse: nil,
                            nextCourse: firstTomorrow,
                            summaryText: "今日课程已结束",
                            subtitleText: "明天首节：\(firstTomorrow.briefTitleWithLocation)"
                        )
                    }
                } else {
                    let speech = "今天的所有课程已经结束，明天也没有课，好好休息吧！"
                    return .result(value: speech, dialog: IntentDialog(stringLiteral: speech)) {
                        NextCourseSnippetView(
                            activeCourse: nil,
                            nextCourse: nil,
                            summaryText: speech,
                            subtitleText: nil
                        )
                    }
                }
            }
        }
    }
}

@available(iOS 16.0, *)
public struct GetTodayCoursesIntent: AppIntent {
    public static var title: LocalizedStringResource = "查询今日课表"
    public static var description = IntentDescription("查询今天的所有课程安排")
    public static var openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView & ReturnsValue<String> {
        let provider = CourseIntentDataProvider.shared
        let now = Date()
        let result = provider.queryCourses(for: now, now: now)

        switch result {
        case .noData:
            let text = "还没有找到你的课表数据，请先打开不高山上 App 导入或同步课表。"
            return .result(value: text, dialog: IntentDialog(stringLiteral: text)) {
                DailyCoursesSnippetView(
                    title: "今日课表",
                    courses: [],
                    emptyMessage: text
                )
            }

        case .onVacation(let message):
            let text = "当前处于假期中：\(message)"
            return .result(value: text, dialog: IntentDialog(stringLiteral: text)) {
                DailyCoursesSnippetView(
                    title: "今日课表",
                    courses: [],
                    emptyMessage: text
                )
            }

        case .noCourses(let desc):
            let text = "今天没有课程安排，好好享受空闲时光吧！"
            return .result(value: text, dialog: IntentDialog(stringLiteral: text)) {
                DailyCoursesSnippetView(
                    title: desc,
                    courses: [],
                    emptyMessage: text
                )
            }

        case .success(let courses, let desc, _, _, _):
            let speech = CourseIntentSpeechFormatter.formatDailySummary(dayLabel: "今天", courses: courses)

            return .result(value: speech, dialog: IntentDialog(stringLiteral: speech)) {
                DailyCoursesSnippetView(
                    title: desc,
                    courses: courses
                )
            }
        }
    }
}

@available(iOS 16.0, *)
public struct GetTomorrowCoursesIntent: AppIntent {
    public static var title: LocalizedStringResource = "查询明日课表"
    public static var description = IntentDescription("查询明天的所有课程安排")
    public static var openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView & ReturnsValue<String> {
        let provider = CourseIntentDataProvider.shared
        let now = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        let result = provider.queryCourses(for: tomorrow, now: now)

        switch result {
        case .noData:
            let text = "还没有找到你的课表数据，请先打开不高山上 App 导入或同步课表。"
            return .result(value: text, dialog: IntentDialog(stringLiteral: text)) {
                DailyCoursesSnippetView(
                    title: "明日课表",
                    courses: [],
                    emptyMessage: text
                )
            }

        case .onVacation(let message):
            let text = "当前处于假期中：\(message)"
            return .result(value: text, dialog: IntentDialog(stringLiteral: text)) {
                DailyCoursesSnippetView(
                    title: "明日课表",
                    courses: [],
                    emptyMessage: text
                )
            }

        case .noCourses(let desc):
            let text = "明天没有课程安排，好好享受空闲时光吧！"
            return .result(value: text, dialog: IntentDialog(stringLiteral: text)) {
                DailyCoursesSnippetView(
                    title: desc,
                    courses: [],
                    emptyMessage: text
                )
            }

        case .success(let courses, let desc, _, _, _):
            let speech = CourseIntentSpeechFormatter.formatDailySummary(dayLabel: "明天", courses: courses)

            return .result(value: speech, dialog: IntentDialog(stringLiteral: speech)) {
                DailyCoursesSnippetView(
                    title: desc,
                    courses: courses
                )
            }
        }
    }
}

// MARK: - AppShortcutsProvider 注册

@available(iOS 16.0, *)
public struct CourseShortcutsProvider: AppShortcutsProvider {
    public static var shortcutTileColor: ShortcutTileColor = .blue

    public static func refreshShortcuts() {
        updateAppShortcutParameters()
    }

    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetNextCourseIntent(),
            phrases: [
                "用 \(.applicationName) 查下节课",
                "用 \(.applicationName) 查看下节课",
                "用 \(.applicationName) 下节是什么课",
                "用 \(.applicationName) 下节课在哪里上",
                "\(.applicationName) 下节课",
                "\(.applicationName) 下节是什么课",
                "\(.applicationName) 下节课在哪里上"
            ],
            shortTitle: "查询下节课",
            systemImageName: "book.fill"
        )

        AppShortcut(
            intent: GetTodayCoursesIntent(),
            phrases: [
                "用 \(.applicationName) 查今天课表",
                "用 \(.applicationName) 查看今天课表",
                "用 \(.applicationName) 今天有什么课",
                "用 \(.applicationName) 查看今日课程",
                "\(.applicationName) 今天课表",
                "\(.applicationName) 今日课表",
                "\(.applicationName) 今天有什么课"
            ],
            shortTitle: "查询今日课表",
            systemImageName: "calendar"
        )

        AppShortcut(
            intent: GetTomorrowCoursesIntent(),
            phrases: [
                "用 \(.applicationName) 查明天课表",
                "用 \(.applicationName) 查看明天课表",
                "用 \(.applicationName) 明天有什么课",
                "\(.applicationName) 明天课表",
                "\(.applicationName) 明日课表",
                "\(.applicationName) 明天有什么课"
            ],
            shortTitle: "查询明日课表",
            systemImageName: "arrow.right.circle.fill"
        )
    }
}
