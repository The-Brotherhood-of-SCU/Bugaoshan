package io.github.the_brotherhood_of_scu.bugaoshan.api

import io.github.the_brotherhood_of_scu.bugaoshan.model.SchemeScore
import io.github.the_brotherhood_of_scu.bugaoshan.model.SchemeScoreCourse
import io.ktor.client.*
import io.ktor.client.request.*
import io.ktor.client.statement.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.*

class GradeApiService(private val httpClient: HttpClient) {

    /**
     * Fetch grades for the current user.
     * @param accessToken SCU auth token
     * @param semester Optional semester filter (e.g., "2024-2025-1")
     */
    suspend fun fetchGrades(
        accessToken: String,
        semester: String? = null,
    ): SchemeScore = withContext(Dispatchers.Default) {
        try {
            val response = httpClient.get("https://zhjw.scu.edu.cn/api/grade/query") {
                header("Authorization", "Bearer $accessToken")
                if (semester != null) {
                    parameter("semester", semester)
                }
            }

            if (response.status.value == 200) {
                val json = Json { ignoreUnknownKeys = true }
                val body = response.bodyAsText()
                val root = json.parseToJsonElement(body).jsonObject
                val data = root["data"]?.jsonObject ?: return@withContext emptySchemeScore()

                val courses = data["courses"]?.jsonArray?.map { item ->
                    val obj = item.jsonObject
                    SchemeScoreCourse(
                        name = obj["courseName"]?.jsonPrimitive?.content ?: "",
                        credit = obj["credit"]?.jsonPrimitive?.double ?: 0.0,
                        score = obj["score"]?.jsonPrimitive?.double ?: 0.0,
                        gpa = obj["gpa"]?.jsonPrimitive?.double ?: 0.0,
                        courseType = obj["courseType"]?.jsonPrimitive?.content ?: "",
                        semester = obj["semester"]?.jsonPrimitive?.content ?: "",
                    )
                } ?: emptyList()

                val totalCredits = courses.sumOf { it.credit }
                val weightedGpa = if (totalCredits > 0) {
                    courses.sumOf { it.gpa * it.credit } / totalCredits
                } else 0.0
                val averageScore = if (courses.isNotEmpty()) {
                    courses.mapNotNull { if (it.score > 0) it.score else null }.let { scores ->
                        if (scores.isNotEmpty()) scores.average() else 0.0
                    }
                } else 0.0

                SchemeScore(
                    semesterName = semester ?: "全部学期",
                    courses = courses,
                    totalCredits = totalCredits,
                    totalGpa = weightedGpa,
                    averageScore = averageScore,
                )
            } else {
                emptySchemeScore()
            }
        } catch (e: Exception) {
            emptySchemeScore()
        }
    }

    /**
     * Fetch available semesters.
     */
    suspend fun fetchSemesters(accessToken: String): List<String> = withContext(Dispatchers.Default) {
        try {
            val response = httpClient.get("https://zhjw.scu.edu.cn/api/grade/semesters") {
                header("Authorization", "Bearer $accessToken")
            }

            if (response.status.value == 200) {
                val json = Json { ignoreUnknownKeys = true }
                val body = response.bodyAsText()
                val element = json.parseToJsonElement(body)
                val data = element.jsonObject["data"]?.jsonArray ?: emptyList()
                data.map { it.jsonPrimitive.content }
            } else emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun emptySchemeScore() = SchemeScore(
        semesterName = "",
        courses = emptyList(),
        totalCredits = 0.0,
        totalGpa = 0.0,
        averageScore = 0.0,
    )
}
