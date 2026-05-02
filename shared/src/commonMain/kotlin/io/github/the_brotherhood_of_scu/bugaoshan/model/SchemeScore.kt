package io.github.the_brotherhood_of_scu.bugaoshan.model

import kotlinx.serialization.Serializable

@Serializable
data class SchemeScore(
    val semesterName: String,
    val courses: List<SchemeScoreCourse>,
    val totalCredits: Double,
    val totalGpa: Double,
    val averageScore: Double,
)

@Serializable
data class SchemeScoreCourse(
    val name: String,
    val credit: Double,
    val score: Double,
    val gpa: Double,
    val courseType: String,
    val semester: String,
)
