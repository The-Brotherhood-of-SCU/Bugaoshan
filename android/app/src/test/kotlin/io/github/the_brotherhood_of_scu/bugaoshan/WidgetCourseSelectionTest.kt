package io.github.the_brotherhood_of_scu.bugaoshan

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class WidgetCourseSelectionTest {
    @Test
    fun emptyCurrentScheduleDoesNotQueryDefaultSchedule() {
        val queriedScheduleIds = mutableListOf<String>()

        val courses =
            loadCoursesForSelectedSchedule("empty-selected") { scheduleId ->
                queriedScheduleIds += scheduleId
                emptyList<String>()
            }

        assertTrue(courses.isEmpty())
        assertEquals(listOf("empty-selected"), queriedScheduleIds)
    }
}
