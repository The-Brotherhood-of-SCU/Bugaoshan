package io.github.the_brotherhood_of_scu.bugaoshan.platform

import com.russhwolf.settings.Settings
import com.russhwolf.settings.PreferencesSettings
import java.util.prefs.Preferences

actual fun createSettings(): Settings {
    val prefs = Preferences.userRoot().node("io.github.the_brotherhood_of_scu.bugaoshan")
    return PreferencesSettings(prefs)
}
