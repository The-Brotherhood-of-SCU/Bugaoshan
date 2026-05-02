package io.github.the_brotherhood_of_scu.bugaoshan.platform

import android.content.Context
import android.content.pm.PackageManager

actual fun getPlatformName(): String = "Android"

actual class PlatformContext(private val context: Context) {
    fun getContext(): Context = context
}

actual fun getAppVersion(): String {
    return try {
        val packageInfo = appContext.packageManager.getPackageInfo(appContext.packageName, 0)
        packageInfo.versionName ?: "1.0.0"
    } catch (e: PackageManager.NameNotFoundException) {
        "1.0.0"
    }
}

actual fun getAppName(): String {
    return try {
        val packageInfo = appContext.packageManager.getPackageInfo(appContext.packageName, 0)
        val labelRes = packageInfo.applicationInfo?.labelRes ?: 0
        if (labelRes != 0) appContext.getString(labelRes) else "Bugaoshan"
    } catch (e: Exception) {
        "Bugaoshan"
    }
}
