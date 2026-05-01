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
