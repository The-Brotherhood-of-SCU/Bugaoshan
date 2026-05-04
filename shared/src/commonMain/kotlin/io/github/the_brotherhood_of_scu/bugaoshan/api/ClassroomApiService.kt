package io.github.the_brotherhood_of_scu.bugaoshan.api

import io.github.the_brotherhood_of_scu.bugaoshan.model.*
import io.ktor.client.*
import io.ktor.client.request.*
import io.ktor.client.statement.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.*

class ClassroomApiService(private val httpClient: HttpClient) {

    /**
     * Query available classrooms.
     * @param campus Campus number (e.g., "1" for Wangjiang, "2" for Jiang'an)
     * @param building Building number, or "all" for all buildings
     * @param dayOfWeek Day of week (1-7)
     * @param section Section number to check
     * @param accessToken SCU auth token
     */
    suspend fun queryClassrooms(
        campus: String,
        building: String,
        dayOfWeek: Int,
        section: Int,
        accessToken: String,
    ): ClassroomQueryResult = withContext(Dispatchers.Default) {
        try {
            val response = httpClient.get("https://ic.scu.edu.cn/api/classroom/query") {
                header("Authorization", "Bearer $accessToken")
                parameter("campus", campus)
                parameter("building", building)
                parameter("dayOfWeek", dayOfWeek)
                parameter("section", section)
            }

            if (response.status.value == 200) {
                val body = response.bodyAsText()
                val json = Json { ignoreUnknownKeys = true }
                val element = json.parseToJsonElement(body)
                ClassroomQueryResult.fromJsonObject(element)
            } else {
                ClassroomQueryResult(classrooms = emptyList(), total = 0)
            }
        } catch (e: Exception) {
            ClassroomQueryResult(classrooms = emptyList(), total = 0)
        }
    }

    /**
     * Get list of campus buildings.
     */
    suspend fun getCampuses(accessToken: String): List<ClassroomCampus> = withContext(Dispatchers.Default) {
        try {
            val response = httpClient.get("https://ic.scu.edu.cn/api/classroom/campuses") {
                header("Authorization", "Bearer $accessToken")
            }

            if (response.status.value == 200) {
                val json = Json { ignoreUnknownKeys = true }
                val body = response.bodyAsText()
                val element = json.parseToJsonElement(body)
                val data = element.jsonObject["data"]?.jsonArray ?: emptyList()
                data.map { item ->
                    val obj = item.jsonObject
                    ClassroomCampus(
                        number = obj["number"]?.jsonPrimitive?.content ?: "",
                        name = obj["name"]?.jsonPrimitive?.content ?: "",
                    )
                }
            } else emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    /**
     * Get buildings for a campus.
     */
    suspend fun getBuildings(campus: String, accessToken: String): List<ClassroomBuilding> = withContext(Dispatchers.Default) {
        try {
            val response = httpClient.get("https://ic.scu.edu.cn/api/classroom/buildings") {
                header("Authorization", "Bearer $accessToken")
                parameter("campus", campus)
            }

            if (response.status.value == 200) {
                val json = Json { ignoreUnknownKeys = true }
                val body = response.bodyAsText()
                val element = json.parseToJsonElement(body)
                val data = element.jsonObject["data"]?.jsonArray ?: emptyList()
                data.map { item ->
                    val obj = item.jsonObject
                    ClassroomBuilding(
                        number = obj["number"]?.jsonPrimitive?.content ?: "",
                        name = obj["name"]?.jsonPrimitive?.content ?: "",
                    )
                }
            } else emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    /**
     * Get free classroom types (e.g., regular, lab, multimedia).
     */
    suspend fun getFreeClassrooms(
        campus: String,
        building: String,
        dayOfWeek: Int,
        section: Int,
        accessToken: String,
    ): List<ClassroomInfo> = withContext(Dispatchers.Default) {
        try {
            val response = httpClient.get("https://ic.scu.edu.cn/api/classroom/free") {
                header("Authorization", "Bearer $accessToken")
                parameter("campus", campus)
                parameter("building", building)
                parameter("dayOfWeek", dayOfWeek)
                parameter("section", section)
            }

            if (response.status.value == 200) {
                val json = Json { ignoreUnknownKeys = true }
                val body = response.bodyAsText()
                val element = json.parseToJsonElement(body)
                val data = element.jsonObject["data"]?.jsonArray ?: emptyList()
                data.map { item ->
                    val obj = item.jsonObject
                    val periods = obj["periods"]?.jsonArray?.map { p ->
                        val pObj = p.jsonObject
                        ClassroomPeriod(
                            period = pObj["period"]?.jsonPrimitive?.content ?: "",
                            status = pObj["status"]?.jsonPrimitive?.content ?: "",
                            courseName = pObj["courseName"]?.jsonPrimitive?.content,
                            teacher = pObj["teacher"]?.jsonPrimitive?.content,
                        )
                    } ?: emptyList()

                    ClassroomInfo(
                        name = obj["name"]?.jsonPrimitive?.content ?: "",
                        capacity = obj["capacity"]?.jsonPrimitive?.int ?: 0,
                        status = obj["status"]?.jsonPrimitive?.content ?: "",
                        periods = periods,
                        canBorrow = obj["canBorrow"]?.jsonPrimitive?.booleanOrNull ?: false,
                        remark = obj["remark"]?.jsonPrimitive?.content ?: "",
                    )
                }
            } else emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }
}
