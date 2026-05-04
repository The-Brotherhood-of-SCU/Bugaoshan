package io.github.the_brotherhood_of_scu.bugaoshan.api

import io.ktor.client.*
import io.ktor.client.request.*
import io.ktor.client.statement.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*

class NetworkDeviceApiService(private val httpClient: HttpClient) {

    /**
     * Get online devices for the current user.
     * @param accessToken SCU auth token
     */
    suspend fun getOnlineDevices(accessToken: String): NetworkDeviceResult = withContext(Dispatchers.Default) {
        try {
            val response = httpClient.get("https://nic.scu.edu.cn/api/device/online") {
                header("Authorization", "Bearer $accessToken")
            }

            if (response.status.value == 200) {
                val json = Json { ignoreUnknownKeys = true }
                val body = response.bodyAsText()
                val root = json.parseToJsonElement(body).jsonObject
                val data = root["data"]?.jsonObject ?: return@withContext NetworkDeviceResult.Error("查询失败")

                val userInfo = data["userInfo"]?.jsonObject
                val devices = data["devices"]?.jsonArray?.map { item ->
                    val obj = item.jsonObject
                    OnlineDevice(
                        deviceName = obj["deviceName"]?.jsonPrimitive?.content ?: "",
                        ipAddress = obj["ipAddress"]?.jsonPrimitive?.content ?: "",
                        macAddress = obj["macAddress"]?.jsonPrimitive?.content ?: "",
                        onlineTime = obj["onlineTime"]?.jsonPrimitive?.content ?: "",
                    )
                } ?: emptyList()

                NetworkDeviceResult.Success(
                    username = userInfo?.get("username")?.jsonPrimitive?.content ?: "",
                    onlineCount = devices.size,
                    devices = devices,
                )
            } else {
                NetworkDeviceResult.Error("查询失败 (${response.status.value})")
            }
        } catch (e: Exception) {
            NetworkDeviceResult.Error("网络错误: ${e.message}")
        }
    }

    /**
     * Disconnect a specific device.
     * @param accessToken SCU auth token
     * @param macAddress MAC address of the device to disconnect
     */
    suspend fun disconnectDevice(accessToken: String, macAddress: String): Boolean = withContext(Dispatchers.Default) {
        try {
            val response = httpClient.post("https://nic.scu.edu.cn/api/device/disconnect") {
                header("Authorization", "Bearer $accessToken")
                parameter("macAddress", macAddress)
            }
            response.status.value == 200
        } catch (e: Exception) {
            false
        }
    }
}

sealed class NetworkDeviceResult {
    data class Success(
        val username: String,
        val onlineCount: Int,
        val devices: List<OnlineDevice>,
    ) : NetworkDeviceResult()

    data class Error(val message: String) : NetworkDeviceResult()
}

@Serializable
data class OnlineDevice(
    val deviceName: String,
    val ipAddress: String,
    val macAddress: String,
    val onlineTime: String,
)
