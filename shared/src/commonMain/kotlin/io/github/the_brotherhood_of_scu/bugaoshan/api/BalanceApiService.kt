package io.github.the_brotherhood_of_scu.bugaoshan.api

import io.ktor.client.*
import io.ktor.client.request.*
import io.ktor.client.statement.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*

class BalanceApiService(private val httpClient: HttpClient) {

    /**
     * Query electricity and AC balance for a room.
     * @param accessToken SCU auth token
     * @param buildingId Building identifier
     * @param roomId Room identifier
     */
    suspend fun queryBalance(
        accessToken: String,
        buildingId: String,
        roomId: String,
    ): BalanceResult = withContext(Dispatchers.Default) {
        try {
            val response = httpClient.get("https://ecard.scu.edu.cn/api/balance/query") {
                header("Authorization", "Bearer $accessToken")
                parameter("buildingId", buildingId)
                parameter("roomId", roomId)
            }

            if (response.status.value == 200) {
                val json = Json { ignoreUnknownKeys = true }
                val body = response.bodyAsText()
                val root = json.parseToJsonElement(body).jsonObject
                val data = root["data"]?.jsonObject ?: return@withContext BalanceResult.Error("查询失败")

                BalanceResult.Success(
                    electricityBalance = data["electricityBalance"]?.jsonPrimitive?.double ?: 0.0,
                    acBalance = data["acBalance"]?.jsonPrimitive?.double ?: 0.0,
                    dormitory = data["dormitory"]?.jsonPrimitive?.content ?: "",
                    building = data["building"]?.jsonPrimitive?.content ?: "",
                )
            } else {
                BalanceResult.Error("查询失败 (${response.status.value})")
            }
        } catch (e: Exception) {
            BalanceResult.Error("网络错误: ${e.message}")
        }
    }

    /**
     * Get list of dormitories.
     */
    suspend fun getDormitories(accessToken: String): List<Dormitory> = withContext(Dispatchers.Default) {
        try {
            val response = httpClient.get("https://ecard.scu.edu.cn/api/balance/dormitories") {
                header("Authorization", "Bearer $accessToken")
            }

            if (response.status.value == 200) {
                val json = Json { ignoreUnknownKeys = true }
                val body = response.bodyAsText()
                val element = json.parseToJsonElement(body)
                val data = element.jsonObject["data"]?.jsonArray ?: emptyList()
                data.map { item ->
                    val obj = item.jsonObject
                    Dormitory(
                        id = obj["id"]?.jsonPrimitive?.content ?: "",
                        name = obj["name"]?.jsonPrimitive?.content ?: "",
                        building = obj["building"]?.jsonPrimitive?.content ?: "",
                    )
                }
            } else emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }
}

sealed class BalanceResult {
    data class Success(
        val electricityBalance: Double,
        val acBalance: Double,
        val dormitory: String,
        val building: String,
    ) : BalanceResult()

    data class Error(val message: String) : BalanceResult()
}

@Serializable
data class Dormitory(
    val id: String,
    val name: String,
    val building: String,
)
