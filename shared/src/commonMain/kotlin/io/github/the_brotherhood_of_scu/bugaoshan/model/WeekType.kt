package io.github.the_brotherhood_of_scu.bugaoshan.model

enum class WeekType {
    EVERY, ODD, EVEN;

    companion object {
        fun fromIndex(index: Int): WeekType = when (index) {
            0 -> EVERY
            1 -> ODD
            2 -> EVEN
            else -> EVERY
        }
    }
}
