package io.github.the_brotherhood_of_scu.bugaoshan.model

import kotlinx.serialization.Serializable
import kotlin.time.Clock
import kotlin.time.ExperimentalTime

@Serializable
data class Course(
    val id: String = generateId(),
    val name: String,
    val teacher: String,
    val location: String,
    val startWeek: Int,
    val endWeek: Int,
    val dayOfWeek: Int, // 1=Mon ... 7=Sun
    val startSection: Int,
    val endSection: Int,
    val colorValue: Long, // ARGB
    val weekType: WeekType = WeekType.EVERY,
) {
    fun isInWeekRange(week: Int): Boolean {
        return week in startWeek..endWeek
    }

    fun isActiveInWeek(week: Int): Boolean {
        if (!isInWeekRange(week)) return false
        if (weekType == WeekType.ODD && week % 2 == 0) return false
        if (weekType == WeekType.EVEN && week % 2 != 0) return false
        return true
    }

    fun conflictsWith(other: Course, excludeId: String? = null): Boolean {
        if (excludeId != null && id == excludeId) return false
        if (dayOfWeek != other.dayOfWeek) return false

        for (w in startWeek..endWeek) {
            if (isActiveInWeek(w) && other.isActiveInWeek(w)) {
                if (endSection >= other.startSection && startSection <= other.endSection) {
                    return true
                }
            }
        }
        return false
    }

    companion object {
        private var idCounter = 0

        @OptIn(ExperimentalTime::class)
        fun generateId(): String {
            idCounter++
            return "${Clock.System.now().toEpochMilliseconds()}_$idCounter"
        }
    }
}
