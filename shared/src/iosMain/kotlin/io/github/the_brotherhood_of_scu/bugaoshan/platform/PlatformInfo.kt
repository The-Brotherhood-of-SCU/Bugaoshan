package io.github.the_brotherhood_of_scu.bugaoshan.platform

import platform.Foundation.NSBundle

actual fun getPlatformName(): String = "iOS"

actual class PlatformContext

actual fun getAppVersion(): String {
    return try {
        NSBundle.mainBundle.infoDictionary?.get("CFBundleShortVersionString") as? String ?: "1.0.0"
    } catch (e: Exception) {
        "1.0.0"
    }
}

actual fun getAppName(): String {
    return try {
        NSBundle.mainBundle.infoDictionary?.get("CFBundleName") as? String ?: "Bugaoshan"
    } catch (e: Exception) {
        "Bugaoshan"
    }
}
