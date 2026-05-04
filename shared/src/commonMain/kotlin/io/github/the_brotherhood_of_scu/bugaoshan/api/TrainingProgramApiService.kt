package io.github.the_brotherhood_of_scu.bugaoshan.api

import io.ktor.client.*
import io.ktor.client.request.*
import io.ktor.client.statement.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*

class TrainingProgramApiService(private val httpClient: HttpClient) {

    /**
     * Get training program (培养方案) for the current user.
     * @param accessToken SCU auth token
     * @param college College filter
     * @param grade Grade filter
     */
    suspend fun getTrainingProgram(
        accessToken: String,
        college: String? = null,
        grade: String? = null,
    ): TrainingProgramResult = withContext(Dispatchers.Default) {
        try {
            val response = httpClient.get("https://zhjw.scu.edu.cn/api/training-program/query") {
                header("Authorization", "Bearer $accessToken")
                if (college != null) parameter("college", college)
                if (grade != null) parameter("grade", grade)
            }

            if (response.status.value == 200) {
                val json = Json { ignoreUnknownKeys = true }
                val body = response.bodyAsText()
                val root = json.parseToJsonElement(body).jsonObject
                val data = root["data"]?.jsonObject ?: return@withContext TrainingProgramResult.Error("查询失败")

                val courses = data["courses"]?.jsonArray?.map { item ->
                    val obj = item.jsonObject
                    TrainingCourse(
                        name = obj["name"]?.jsonPrimitive?.content ?: "",
                        credits = obj["credits"]?.jsonPrimitive?.double ?: 0.0,
                        hours = obj["hours"]?.jsonPrimitive?.int ?: 0,
                        courseType = obj["courseType"]?.jsonPrimitive?.content ?: "",
                        required = obj["required"]?.jsonPrimitive?.boolean ?: true,
                        semester = obj["semester"]?.jsonPrimitive?.content ?: "",
                    )
                } ?: emptyList()

                val totalCredits = courses.sumOf { it.credits }
                val requiredCredits = courses.filter { it.required }.sumOf { it.credits }
                val completedCredits = courses.filter { it.required }.sumOf { it.credits }

                TrainingProgramResult.Success(
                    programName = data["programName"]?.jsonPrimitive?.content ?: "",
                    college = data["college"]?.jsonPrimitive?.content ?: "",
                    totalCredits = totalCredits,
                    requiredCredits = requiredCredits,
                    courses = courses,
                )
            } else {
                TrainingProgramResult.Error("查询失败 (${response.status.value})")
            }
        } catch (e: Exception) {
            TrainingProgramResult.Error("网络错误: ${e.message}")
        }
    }

    /**
     * Get available colleges for filtering.
     */
    suspend fun getColleges(accessToken: String): List<CollegeInfo> = withContext(Dispatchers.Default) {
        try {
            val response = httpClient.get("https://zhjw.scu.edu.cn/api/training-program/colleges") {
                header("Authorization", "Bearer $accessToken")
            }

            if (response.status.value == 200) {
                val json = Json { ignoreUnknownKeys = true }
                val body = response.bodyAsText()
                val element = json.parseToJsonElement(body)
                val data = element.jsonObject["data"]?.jsonArray ?: emptyList()
                data.map { item ->
                    val obj = item.jsonObject
                    CollegeInfo(
                        id = obj["id"]?.jsonPrimitive?.content ?: "",
                        name = obj["name"]?.jsonPrimitive?.content ?: "",
                    )
                }
            } else emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }
}

sealed class TrainingProgramResult {
    data class Success(
        val programName: String,
        val college: String,
        val totalCredits: Double,
        val requiredCredits: Double,
        val courses: List<TrainingCourse>,
    ) : TrainingProgramResult()

    data class Error(val message: String) : TrainingProgramResult()
}

@Serializable
data class TrainingCourse(
    val name: String,
    val credits: Double,
    val hours: Int,
    val courseType: String,
    val required: Boolean,
    val semester: String,
)

@Serializable
data class CollegeInfo(
    val id: String,
    val name: String,
)
