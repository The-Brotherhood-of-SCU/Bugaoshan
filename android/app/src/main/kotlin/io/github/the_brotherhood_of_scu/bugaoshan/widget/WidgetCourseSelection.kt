package io.github.the_brotherhood_of_scu.bugaoshan.widget

/**
 * 只读取用户当前选中的课表。
 *
 * 查询结果为空表示该课表当天确实没有课程,不能据此改查其他课表。
 */
internal inline fun <T> loadCoursesForSelectedSchedule(
    selectedScheduleId: String,
    query: (String) -> T,
): T = query(selectedScheduleId)
