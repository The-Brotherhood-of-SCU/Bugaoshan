package io.github.the_brotherhood_of_scu.bugaoshan

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
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
                    else -> result.notImplemented()
                }
            }
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
}
