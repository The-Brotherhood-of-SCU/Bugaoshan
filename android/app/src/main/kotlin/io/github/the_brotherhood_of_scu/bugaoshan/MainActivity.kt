package io.github.the_brotherhood_of_scu.bugaoshan

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "bugaoshan/update"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register periodic widget update via WorkManager
        WidgetUpdateWorker.enqueuePeriodic(this)

        // Register midnight alarm for day-change widget updates
        WidgetAlarmManager.registerMidnightAlarm(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            installApk(path)
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGUMENT", "Path is null", null)
                        }
                    }
                    "updateWidget" -> {
                        updateAllWidgets()
                        result.success(null)
                    }
                    "importIcsToCalendar" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            val res = importIcsToCalendar(path)
                            result.success(res)
                        } else {
                            result.error("INVALID_ARGUMENT", "Path is null", null)
                        }
                    }
                    "pinWidget" -> {
                        val size = call.argument<String>("size")
                        val success = pinWidget(size)
                        result.success(success)
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        val success = requestIgnoreBatteryOptimizations()
                        result.success(success)
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        val isIgnoring = isIgnoringBatteryOptimizations()
                        result.success(isIgnoring)
                    }
                    else -> result.notImplemented()
                }
            }

        // Dynamic App Icon switching (custom implementation to handle namespace vs applicationId)
        val DYNAMIC_ICON_CHANNEL = "bugaoshan/dynamic_icon"
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DYNAMIC_ICON_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getAvailableIcons" -> {
                            result.success(getAvailableDynamicIcons())
                        }
                        "getCurrentIconName" -> {
                            result.success(getCurrentDynamicIcon())
                        }
                        "setAlternateIconName" -> {
                            val iconName = call.argument<String>("iconName")
                            setAlternateDynamicIcon(iconName)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                }
            }
    }

    /**
     * Get the base class name for dynamic icon aliases.
     * Uses MainActivity's own class name to get the correct namespace,
     * avoiding the applicationId suffix issue (e.g., .debug in debug builds).
     */
    private val iconBaseClass: String by lazy {
        MainActivity::class.java.name // "io.github.the_brotherhood_of_scu.bugaoshan.MainActivity"
    }

    /** Query available alternate icon names from activity-alias components. */
    private fun getAvailableDynamicIcons(): List<String> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
            setPackage(packageName)
        }
        val resolveInfos = pm.queryIntentActivities(intent, PackageManager.MATCH_DISABLED_COMPONENTS)
        val prefix = "$iconBaseClass."
        val icons = mutableListOf<String>()

        resolveInfos.forEach { resolveInfo ->
            val componentName = resolveInfo.activityInfo.name
            if (componentName == iconBaseClass) return@forEach // Skip the real MainActivity
            if (componentName.startsWith(prefix)) {
                val suffix = componentName.substring(prefix.length)
                if (suffix != "default") {
                    icons.add(suffix)
                }
            }
        }
        return icons
    }

    /** Return the currently active alternate icon name, or null for default. */
    private fun getCurrentDynamicIcon(): String? {
        val pm = packageManager
        val mainCN = ComponentName(packageName, iconBaseClass)
        val mainState = pm.getComponentEnabledSetting(mainCN)
        if (mainState == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            || mainState == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT) {
            return null
        }
        // Check each alias
        for (iconName in getAvailableDynamicIcons()) {
            val aliasCN = ComponentName(packageName, "$iconBaseClass.$iconName")
            if (pm.getComponentEnabledSetting(aliasCN)
                == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                return iconName
            }
        }
        return null
    }

    /** Apply an icon swap: enable target first, update widgets, then kill process. */
    private fun setAlternateDynamicIcon(iconName: String?) {
        val pm = packageManager
        val mainCN = ComponentName(packageName, iconBaseClass)

        // Determine which component is currently the active launcher.
        // We'll leave it untouched in the DONT_KILL_APP pass, then disable it
        // WITHOUT DONT_KILL_APP at the end to trigger a real process kill.
        val currentIsMain = pm.getComponentEnabledSetting(mainCN) in arrayOf(
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
        )
        val currentAlias = if (currentIsMain) null else getCurrentDynamicIcon()
        val previousActiveCN = if (currentAlias != null)
            ComponentName(packageName, "$iconBaseClass.$currentAlias")
        else
            mainCN

        // Step 1: Enable the target component (DONT_KILL_APP)
        if (iconName.isNullOrEmpty()) {
            pm.setComponentEnabledSetting(
                mainCN,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
        } else {
            val targetCN = ComponentName(packageName, "$iconBaseClass.$iconName")
            pm.setComponentEnabledSetting(
                targetCN,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
        }

        // Step 2: Disable all OTHER components with DONT_KILL_APP,
        // but SKIP the previously-active one — we'll disable it in step 4
        // without DONT_KILL_APP to force-kill the process.
        // Disable MainActivity if switching to an alias and it's not the currently active one
        if (!iconName.isNullOrEmpty() && !currentIsMain) {
            pm.setComponentEnabledSetting(
                mainCN,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
        }
        for (available in getAvailableDynamicIcons()) {
            if (available == iconName) continue // skip target
            if (available == currentAlias) continue // skip current active — will kill later
            val aliasCN = ComponentName(packageName, "$iconBaseClass.$available")
            pm.setComponentEnabledSetting(
                aliasCN,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
        }

        // Step 3: Update widgets — the new component is already enabled,
        // so getLaunchIntentForPackage will resolve to it correctly.
        updateAllWidgets()

        // Step 4: Kill the process by disabling the previously-active component
        // WITHOUT DONT_KILL_APP. This is a real state change (ENABLED→DISABLED),
        // so the system will kill our process and launcher will refresh the icon.
        Handler(Looper.getMainLooper()).postDelayed({
            pm.setComponentEnabledSetting(
                previousActiveCN,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                0 // No flag → kills process, forcing icon refresh
            )
        }, 300)
    }

    private fun updateAllWidgets() {
        try {
            val mgr = AppWidgetManager.getInstance(this)
            val providers = listOf(
                CourseWidgetReceiverSmall::class.java,
                CourseWidgetReceiverMedium::class.java,
                CourseWidgetReceiverLarge::class.java,
            )
            for (cls in providers) {
                val ids = mgr.getAppWidgetIds(ComponentName(this, cls))
                if (ids.isNotEmpty()) {
                    val intent = Intent(this, cls).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                    }
                    sendBroadcast(intent)
                    Log.d("CourseWidget", "Sent update broadcast for ${cls.simpleName}: ${ids.size} widgets")
                }
            }
        } catch (e: Exception) {
            Log.e("CourseWidget", "updateAllWidgets failed", e)
        }
    }

    private fun pinWidget(size: String?): Boolean {
        Log.d("CourseWidget", "pinWidget called with size=$size, SDK=${Build.VERSION.SDK_INT}")
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            Log.w("CourseWidget", "pinWidget requires API 26+")
            return false
        }
        val receiverClass = when (size) {
            "small" -> CourseWidgetReceiverSmall::class.java
            "medium" -> CourseWidgetReceiverMedium::class.java
            "large" -> CourseWidgetReceiverLarge::class.java
            else -> {
                Log.w("CourseWidget", "Unknown widget size: $size")
                return false
            }
        }
        return try {
            val mgr = AppWidgetManager.getInstance(this)
            val component = ComponentName(this, receiverClass)
            Log.d("CourseWidget", "pinWidget requesting pin for $component")
            val result = mgr.requestPinAppWidget(component, null, null)
            Log.d("CourseWidget", "pinWidget result=$result")
            result
        } catch (e: Exception) {
            Log.e("CourseWidget", "pinWidget failed for size=$size", e)
            false
        }
    }

    /**
     * Try to open ICS file directly with a calendar app.
     * Returns "opened" if a calendar app was launched directly,
     * or "picker" if fell back to system document picker.
     */
    private fun importIcsToCalendar(icsPath: String): String {
        val file = File(icsPath)
        val uri = FileProvider.getUriForFile(
            this,
            "${packageName}.fileprovider",
            file
        )

        val knownCalendarPackages = listOf(
            "com.android.calendar",
            "com.google.android.calendar",
            "com.miui.calendar",
            "com.huawei.calendar",
            "com.coloros.calendar",
            "com.bbk.calendar",
            "com.samsung.android.calendar"
        )

        // Try known calendar packages first
        for (pkg in knownCalendarPackages) {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "text/calendar")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                setPackage(pkg)
            }
            if (intent.resolveActivity(packageManager) != null) {
                try {
                    startActivity(intent)
                    Log.d("ImportCalendar", "Opened ICS with $pkg")
                    return "opened"
                } catch (e: Exception) {
                    Log.w("ImportCalendar", "Failed to launch $pkg: $e")
                }
            }
        }

        // Fallback: query any app that can handle text/calendar
        val viewIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "text/calendar")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val activities = packageManager.queryIntentActivities(viewIntent, 0)
        if (activities.isNotEmpty()) {
            startActivity(viewIntent)
            Log.d("ImportCalendar", "Opened ICS with generic ACTION_VIEW")
            return "opened"
        }

        // Last resort: system document picker
        Log.d("ImportCalendar", "No calendar app found, falling back to picker")
        val openIntent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "text/calendar"
        }
        startActivity(openIntent)
        return "picker"
    }

    private fun installApk(apkPath: String) {
        val file = File(apkPath)
        val uri = FileProvider.getUriForFile(
            this,
            "${packageName}.fileprovider",
            file
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
            setDataAndType(uri, "application/vnd.android.package-archive")
        }
        startActivity(intent)
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations(): Boolean {
        if (isIgnoringBatteryOptimizations()) {
            return true
        }
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:$packageName")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        try {
            startActivity(intent)
            return true
        } catch (e: Exception) {
            Log.e("CourseWidget", "requestIgnoreBatteryOptimizations failed", e)
            // Fallback to general battery settings
            try {
                val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(fallbackIntent)
                return true
            } catch (e2: Exception) {
                Log.e("CourseWidget", "Fallback to battery settings also failed", e2)
                return false
            }
        }
    }
}
