package io.github.the_brotherhood_of_scu.bugaoshan.model

import kotlinx.datetime.Clock
import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.daysUntil
import kotlinx.datetime.minus
import kotlinx.datetime.toLocalDateTime
import kotlinx.serialization.Serializable

@Serializable
data class ScheduleConfig(
    val id: String = "default",
    val semesterName: String = "",
    val semesterStartDate: String, // ISO date string
    val totalWeeks: Int = 20,
    val morningSections: Int = 4,
    val afternoonSections: Int = 5,
    val eveningSections: Int = 3,
    val courseDuration: Int = 45,
    val breakDuration: Int = 10,
    val autoSyncTime: Boolean = true,
    val timeSlots: List<TimeSlot> = TimeSlot.defaultSlots(),
    val showTeacherName: Boolean = true,
    val showLocation: Boolean = true,
    val showWeekend: Boolean = false,
    val showNonCurrentWeekCourses: Boolean = true,
) {
    val sectionsPerDay: Int
        get() = morningSections + afternoonSections + eveningSections

    fun getCurrentWeek(): Int {
        val now = Clock.System.now()
        val today = now.toLocalDateTime(TimeZone.currentSystemDefault()).date
        val start = LocalDate.parse(semesterStartDate)

        if (today < start) return 1
        val days = start.daysUntil(today)
        val week = (days / 7) + 1
        return week.coerceIn(1, totalWeeks)
    }

    companion object {
        fun defaultConfig(): ScheduleConfig {
            val now = Clock.System.now()
            val today = now.toLocalDateTime(TimeZone.currentSystemDefault()).date
            val monday = today.minus(today.dayOfWeek.value - 1, DateTimeUnit.DAY)
            return ScheduleConfig(
                id = "default",
                semesterName = "默认课表",
                semesterStartDate = monday.toString(),
                totalWeeks = 20,
            )
        }
    }
}
