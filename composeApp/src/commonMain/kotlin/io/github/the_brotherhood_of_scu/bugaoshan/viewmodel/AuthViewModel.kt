package io.github.the_brotherhood_of_scu.bugaoshan.viewmodel

import androidx.lifecycle.ViewModel
import com.russhwolf.settings.Settings
import io.github.the_brotherhood_of_scu.bugaoshan.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlin.time.Clock

class AuthViewModel(private val settings: Settings) : ViewModel() {
    private val _isLoggedIn = MutableStateFlow(checkLoginStatus())
    val isLoggedIn: StateFlow<Boolean> = _isLoggedIn.asStateFlow()

    private val _accessToken = MutableStateFlow(settings.getString(KEY_ACCESS_TOKEN, ""))
    val accessToken: StateFlow<String> = _accessToken.asStateFlow()

    private val _userRealName = MutableStateFlow(settings.getString(KEY_USER_REALNAME, ""))
    val userRealName: StateFlow<String> = _userRealName.asStateFlow()

    private val _userNumber = MutableStateFlow(settings.getString(KEY_USER_NUMBER, ""))
    val userNumber: StateFlow<String> = _userNumber.asStateFlow()

    private val _savedUsername = MutableStateFlow(settings.getString(KEY_SAVED_USERNAME, ""))
    val savedUsername: StateFlow<String> = _savedUsername.asStateFlow()

    private val _savedPassword = MutableStateFlow(settings.getString(KEY_SAVED_PASSWORD, ""))
    val savedPassword: StateFlow<String> = _savedPassword.asStateFlow()

    private val _rememberPassword = MutableStateFlow(settings.getBoolean(KEY_REMEMBER, false))
    val rememberPassword: StateFlow<Boolean> = _rememberPassword.asStateFlow()

    private fun checkLoginStatus(): Boolean {
        val token = settings.getString(KEY_ACCESS_TOKEN, "")
        val loginTimestamp = settings.getLong(KEY_LOGIN_TIMESTAMP, 0L)
        val now = Clock.System.now().toEpochMilliseconds() / 1000
        val elapsed = now - loginTimestamp

        return token.isNotEmpty() && elapsed <= SESSION_DURATION_SECONDS
    }

    fun loginSucceed(token: String) {
        settings.putString(KEY_ACCESS_TOKEN, token)
        settings.putLong(KEY_LOGIN_TIMESTAMP, Clock.System.now().toEpochMilliseconds() / 1000)
        _accessToken.value = token
        _isLoggedIn.value = true
    }

    fun logout() {
        settings.remove(KEY_ACCESS_TOKEN)
        settings.remove(KEY_LOGIN_TIMESTAMP)
        settings.remove(KEY_USER_REALNAME)
        settings.remove(KEY_USER_NUMBER)
        _accessToken.value = ""
        _isLoggedIn.value = false
        _userRealName.value = ""
        _userNumber.value = ""
    }

    fun saveUserInfo(realName: String, number: String) {
        settings.putString(KEY_USER_REALNAME, realName)
        settings.putString(KEY_USER_NUMBER, number)
        _userRealName.value = realName
        _userNumber.value = number
    }

    fun saveUsernamePassword(username: String, password: String, remember: Boolean) {
        settings.putString(KEY_SAVED_USERNAME, username)
        settings.putString(KEY_SAVED_PASSWORD, password)
        settings.putBoolean(KEY_REMEMBER, remember)
        _savedUsername.value = username
        _savedPassword.value = password
        _rememberPassword.value = remember
    }
}
