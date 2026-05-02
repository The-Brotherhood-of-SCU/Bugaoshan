package io.github.the_brotherhood_of_scu.bugaoshan.platform

import com.russhwolf.settings.NSUserDefaultsSettings
import com.russhwolf.settings.Settings
import platform.Foundation.NSUserDefaults

actual fun createSettings(): Settings {
    val defaults = NSUserDefaults.standardUserDefaults
    return NSUserDefaultsSettings(defaults)
}
