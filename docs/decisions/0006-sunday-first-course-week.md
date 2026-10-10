# ADR-0006：教学周按校历「周日~周六」成行，全端统一锚定口径

- 状态：已接受并实施
- 决策日期：2026-09-19

## 背景

校历的教学周以周日为首日成行（`assets/academic_calendar.json` 中的学期起点为「教学第一周开始」，历史上绝大多数为周日，2026-2027 秋季学期为周一 2026-08-31），学生与校历都以这一行为「第几周」的依据。

代码里长期存在两套「日期 → 教学周」的算法：

1. **课表页口径**：`ScheduleConfig.dateForCourseDay` 把网格列固定为「周日在首列」，周内偏移为「周一前一日」，即第 W 周的周日 = 学期起点所在行的周日 + (W-1)×7。
2. **小组件 / 顶栏 / 校历徽标口径**：`computeWeekForDate`（Android/iOS）、`ScheduleConfig.getCurrentWeek`、`AcademicCalendarSemester.getCurrentWeek`、课表设置页「当前周」都用「自学期起点起算的整 7 天块」。

两种口径只在**学期起点为周日**时重合（校历其余 11 个学期都是周日），因此直到 2026-2027 秋季学期（起点周一 2026-08-31）才暴露：9/20(日) 按校历是**第 4 周**，而小组件按第 2 种算法算成第 3 周，于是周六晚的「当天课程结束后显示第二天课程」按第 3 周查库，查不到那天周日的课，显示「明天没课」，而课表页同一门课正画在 9/20 的周日列上。

## 决策

**教学周与自然日的换算只保留一套口径，并以校历（周日成行）为准：**

1. 教学周以周日为首日成行，**第 1 周 = 包含学期起点的那一周**。教学周块首日（第 1 周的周日）= 学期起点所在行的周日：起点为周日时即起点本身，起点为周一时是起点前一天（2026-08-31 → 2026-08-30）。
2. 第 W 周 = `[块首日 + (W-1)*7, 块首日 + (W-1)*7 + 6]`，即第 W 周的周日 = `块首日 + (W-1)*7`。
3. 口径唯一收敛在 `lib/utils/semester_week.dart`：`courseWeekAnchor`（块首日 = 学期起点所在周的周日）/ `courseWeekOf`。
   课表页 `ScheduleConfig.dateForCourseDay` 改为复用同一块首日（列序仍是「日、一、…、六」）；
   周日起点与周一起点的输出逐日不变，仅当起点落在周二~周六（校历不存在，但课表设置页可手选日期）时，
   第 1 周回到「包含起点的那一行」——旧实现取的是起点之后的周一，会漏掉起点当天。
4. 小组件（Android `weekAnchor`/`weekOf`、iOS `courseWeekAnchor`）、顶栏与校历徽标（`ScheduleConfig.getCurrentWeek` / `AcademicCalendarSemester.getCurrentWeek`）、课表设置页「当前周」一律取同一口径，禁止各自实现。

## 理由

1. **校历是学生与产品共同的事实来源**。课表页本来就按周日成行排布，小组件与顶栏的算法与之相悖，属于实现漂移而非设计取舍。
2. **漂移只在周一起点的学期可见**，这类「大多数时候正确」的差异最容易被漏测；把口径收敛到一个纯函数文件是唯一能防止复发的做法。
3. **对历史学期零行为变化**：校历其余学期起点均为周日，此时块首日就是学期起点，两套算法逐日相同。

## 兼容性

- 周日起点的学期：`getCurrentWeek` / 校历徽标 / 设置页「当前周」结果与旧实现完全一致。
- 周一起点的学期：周日（以及受其推导的页面归属）周次 +1，与课表页 `dateForCourseDay` 的列日期对齐；`test/course_week_anchor_test.dart` 用「列日期反算周次 ≡ 页号」的不变量覆盖 7 种起点星期。
- 学期最后一天（放假判定）改用同一块首日：`ScheduleConfig.semesterEndDate` 与
  `AcademicCalendarSemester.isDateInSemester` 的右界 = 块首日 + `totalWeeks*7 - 1`。
  周日起点的学期不变；周一起点的学期提前一天（2026-2027 秋季学期 → 2027-01-16(六)，
  次日 1/17 即校历寒假第一天），小组件 Android/iOS 的 `computeSemesterEndDate` 同步。
- `test/academic_calendar_test.dart` 中原先按「自起点起算」编写的两条断言按新口径更新。

## 后果

正面影响：

- 小组件、顶栏、校历徽标、设置页与课表页对同一日期给出同一周次；周日不再漏显示第二天的课。
- 周日当天 `_indexForToday` 会落在真正包含今天的页上，「今天」高亮不再缺失。

代价：

- 学期起点非周日的学期里，周日会被归入下一周（与校历一致，但与「自起点起算」的直觉不同）；需要以注释与 ADR 固化认知。
- 日期 → 周次的实现分散在 Dart / Kotlin / Swift 三处，只能靠注释与不变量测试对齐（平台代码不在 Dart 测试覆盖范围内）。

## 相关实现

- `lib/utils/semester_week.dart`（口径唯一来源）、`lib/models/schedule_config.dart`、`lib/models/academic_calendar.dart`、`lib/pages/course/settings/course_schedule_setting.dart`
- `android/app/src/main/kotlin/io/github/the_brotherhood_of_scu/bugaoshan/CourseGlanceWidget.kt`、`ios/CourseWidget/WidgetExtension.swift`
- 回归测试：`test/course_week_anchor_test.dart`、`test/academic_calendar_test.dart`
