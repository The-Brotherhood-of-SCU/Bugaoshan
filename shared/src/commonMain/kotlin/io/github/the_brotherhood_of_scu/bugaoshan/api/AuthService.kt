package io.github.the_brotherhood_of_scu.bugaoshan.api

import io.github.the_brotherhood_of_scu.bugaoshan.*
import io.ktor.client.*
import io.ktor.client.request.*
import io.ktor.client.request.forms.submitForm
import io.ktor.client.statement.*
import io.ktor.http.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*

class AuthService(private val httpClient: HttpClient) {

    /**
     * Login to SCU unified auth system.
     * Uses OAuth2/CAS flow via HTTP requests.
     * Returns LoginResult with token and user info.
     */
    suspend fun login(studentId: String, password: String): LoginResult = withContext(Dispatchers.Default) {
        try {
            // Step 1: Build the OAuth2 authorization URL
            val authUrl = buildAuthUrl()

            // Step 2: GET the login page to get cookies and any CSRF tokens
            val loginPageResponse = httpClient.get(authUrl)
            val loginPageHtml = loginPageResponse.bodyAsText()

            // Extract execution and lt values from the login form
            val execution = extractFormValue(loginPageHtml, "execution")
            val lt = extractFormValue(loginPageHtml, "lt")

            // Step 3: POST credentials to the CAS login endpoint
            val postUrl = "$SCU_AUTH_BASE/auth/realms/$SCU_ENTERPRISE_ID/login-actions/authenticate"

            val loginResponse = httpClient.submitForm(
                url = postUrl,
                formParameters = parameters {
                    append("username", studentId)
                    append("password", password)
                    if (execution != null) append("execution", execution)
                    if (lt != null) append("lt", lt)
                    append("submit", "LOGIN")
                }
            )

            val responseText = loginResponse.bodyAsText()
            val status = loginResponse.status

            when {
                status.value == 200 && responseText.contains("account-console") -> {
                    // Step 4: Login successful, try to get an access token
                    val tokenResult = obtainToken(studentId, password)
                    tokenResult
                }
                responseText.contains("Invalid username or password") -> {
                    LoginResult.Error("用户名或密码错误")
                }
                responseText.contains("Account is disabled") -> {
                    LoginResult.Error("账号已被禁用")
                }
                status.value in 300..399 -> {
                    // Might be a redirect indicating success
                    val tokenResult = obtainToken(studentId, password)
                    tokenResult
                }
                else -> {
                    LoginResult.Error("登录失败 (${status.value})，请检查网络连接")
                }
            }
        } catch (e: Exception) {
            LoginResult.Error("网络错误: ${e.message ?: "请检查网络连接"}")
        }
    }

    /**
     * Try to obtain an OAuth2 access token using direct grant.
     */
    private suspend fun obtainToken(studentId: String, password: String): LoginResult {
        return try {
            val tokenUrl = "$SCU_AUTH_BASE/auth/realms/$SCU_ENTERPRISE_ID/protocol/openid-connect/token"

            val tokenResponse = httpClient.submitForm(
                url = tokenUrl,
                formParameters = parameters {
                    append("grant_type", "password")
                    append("client_id", SCU_CLIENT_ID)
                    append("username", studentId)
                    append("password", password)
                    append("scope", "openid")
                }
            )

            val json = Json { ignoreUnknownKeys = true }
            val responseBody = tokenResponse.bodyAsText()

            if (tokenResponse.status.value == 200) {
                val tokenJson = json.parseToJsonElement(responseBody).jsonObject
                val accessToken = tokenJson["access_token"]?.jsonPrimitive?.content
                val expiresIn = tokenJson["expires_in"]?.jsonPrimitive?.long ?: 3600L

                if (accessToken != null) {
                    // Try to fetch user info
                    val userInfo = fetchUserInfo(accessToken)
                    LoginResult.Success(
                        accessToken = accessToken,
                        expiresIn = expiresIn,
                        realName = userInfo?.realName ?: studentId,
                        studentNumber = userInfo?.studentNumber ?: studentId,
                    )
                } else {
                    LoginResult.Error("获取令牌失败")
                }
            } else {
                // Direct grant might not be enabled, fall back to session-based auth
                LoginResult.Error("登录方式不支持，请联系管理员")
            }
        } catch (e: Exception) {
            LoginResult.Error("获取令牌失败: ${e.message}")
        }
    }

    /**
     * Fetch user info using the access token.
     */
    private suspend fun fetchUserInfo(accessToken: String): UserInfo? {
        return try {
            val userInfoUrl = "$SCU_AUTH_BASE/auth/realms/$SCU_ENTERPRISE_ID/protocol/openid-connect/userinfo"
            val response = httpClient.get(userInfoUrl) {
                header("Authorization", "Bearer $accessToken")
            }

            if (response.status.value == 200) {
                val json = Json { ignoreUnknownKeys = true }
                val body = response.bodyAsText()
                val userInfoJson = json.parseToJsonElement(body).jsonObject

                UserInfo(
                    realName = userInfoJson["name"]?.jsonPrimitive?.content
                        ?: userInfoJson["preferred_username"]?.jsonPrimitive?.content ?: "",
                    studentNumber = userInfoJson["preferred_username"]?.jsonPrimitive?.content ?: "",
                )
            } else null
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Logout by revoking the token.
     */
    suspend fun logout(accessToken: String) {
        try {
            val logoutUrl = "$SCU_AUTH_BASE/auth/realms/$SCU_ENTERPRISE_ID/protocol/openid-connect/logout"
            httpClient.get(logoutUrl) {
                parameter("client_id", SCU_CLIENT_ID)
                parameter("token", accessToken)
            }
        } catch (_: Exception) {
            // Ignore logout errors
        }
    }

    private fun buildAuthUrl(): String {
        return "$SCU_AUTH_BASE/auth/realms/$SCU_ENTERPRISE_ID/protocol/openid-connect/auth" +
            "?client_id=$SCU_CLIENT_ID" +
            "&response_type=code" +
            "&scope=openid" +
            "&redirect_uri=urn:ietf:wg:oauth:2.0:oob"
    }

    private fun extractFormValue(html: String, name: String): String? {
        val pattern = """name="$name"\s+value="([^"]+)"""".toRegex()
        return pattern.find(html)?.groupValues?.get(1)
    }

    @Serializable
    data class UserInfo(
        val realName: String,
        val studentNumber: String,
    )
}

sealed class LoginResult {
    data class Success(
        val accessToken: String,
        val expiresIn: Long,
        val realName: String,
        val studentNumber: String,
    ) : LoginResult()

    data class Error(val message: String) : LoginResult()
}
