package io.github.the_brotherhood_of_scu.bugaoshan.model

import kotlinx.serialization.Serializable

@Serializable
data class TimeSlot(
    val startHour: Int,
    val startMinute: Int,
    val endHour: Int,
    val endMinute: Int,
) {
    val startTimeString: String
        get() = "%02d:%02d".format(startHour, startMinute)

    val endTimeString: String
        get() = "%02d:%02d".format(endHour, endMinute)

    companion object {
        fun defaultSlots(
            morning: Int = 4,
            afternoon: Int = 5,
            evening: Int = 3,
            courseDuration: Int = 45,
            breakDuration: Int = 10,
        ): List<TimeSlot> {
            if (morning == 4 && afternoon == 5 && evening == 3) {
                return listOf(
                    // Morning
                    TimeSlot(8, 15, 9, 0),
                    TimeSlot(9, 10, 9, 55),
                    TimeSlot(10, 15, 11, 0),
                    TimeSlot(11, 10, 11, 55),
                    // Afternoon
                    TimeSlot(13, 50, 14, 35),
                    TimeSlot(14, 45, 15, 30),
                    TimeSlot(15, 40, 16, 25),
                    TimeSlot(16, 45, 17, 30),
                    TimeSlot(17, 40, 18, 25),
                    // Evening
                    TimeSlot(19, 20, 20, 5),
                    TimeSlot(20, 15, 21, 0),
                    TimeSlot(21, 10, 21, 55),
                )
            }

            val slots = mutableListOf<TimeSlot>()

            // Morning (starts at 8:00)
            var currentHour = 8
            var currentMin = 0
            for (i in 0 until morning) {
                var endMin = currentMin + courseDuration
                val endHour = currentHour + (endMin / 60)
                endMin %= 60
                slots.add(TimeSlot(currentHour, currentMin, endHour, endMin))
                currentMin = endMin + breakDuration
                currentHour = endHour + (currentMin / 60)
                currentMin %= 60
            }

            // Afternoon (starts at 14:00)
            currentHour = 14
            currentMin = 0
            for (i in 0 until afternoon) {
                var endMin = currentMin + courseDuration
                val endHour = currentHour + (endMin / 60)
                endMin %= 60
                slots.add(TimeSlot(currentHour, currentMin, endHour, endMin))
                currentMin = endMin + breakDuration
                currentHour = endHour + (currentMin / 60)
                currentMin %= 60
            }

            // Evening (starts at 19:00)
            currentHour = 19
            currentMin = 0
            for (i in 0 until evening) {
                var endMin = currentMin + courseDuration
                val endHour = currentHour + (endMin / 60)
                endMin %= 60
                slots.add(TimeSlot(currentHour, currentMin, endHour, endMin))
                currentMin = endMin + breakDuration
                currentHour = endHour + (currentMin / 60)
                currentMin %= 60
            }

            return slots
        }
    }
}
