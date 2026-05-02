package io.github.the_brotherhood_of_scu.bugaoshan.platform

import com.russhwolf.settings.Settings
import com.russhwolf.settings.SharedPreferencesSettings

actual fun createSettings(): Settings {
    val prefs = appContext.getSharedPreferences("bugaoshan_settings", 0)
    return SharedPreferencesSettings(prefs)
}
