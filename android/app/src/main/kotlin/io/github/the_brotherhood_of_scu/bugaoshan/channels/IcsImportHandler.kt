package io.github.the_brotherhood_of_scu.bugaoshan.channels

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.core.content.FileProvider
import java.io.File

/**
 * 处理 ICS 文件导入系统日历(由 `bugaoshan/update` MethodChannel 调用)。
 *
 * 返回值语义:
 * - "opened":已用某个日历 App 直接打开 ICS
 * - "picker":没有已知日历 App,回退到系统文件选择器
 */
class IcsImportHandler(private val context: Context) {

    companion object {
        private const val TAG = "ImportCalendar"
    }

    /**
     * 已知日历 App 包名列表,按优先级尝试。
     * 覆盖原生 AOSP、Google、小米、华为、OPPO、vivo、Samsung。
     */
    private val knownCalendarPackages = listOf(
        "com.android.calendar",
        "com.google.android.calendar",
        "com.miui.calendar",
        "com.huawei.calendar",
        "com.coloros.calendar",
        "com.bbk.calendar",
        "com.samsung.android.calendar",
    )

    /**
     * 尝试用日历 App 打开 ICS 文件。
     * 先按 [knownCalendarPackages] 顺序尝试已知日历包,失败后查任意能处理 text/calendar 的 App,
     * 最后回退到系统文件选择器。
     */
    fun importIcsToCalendar(icsPath: String): String {
        val file = File(icsPath)
        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file,
        )

        // Try known calendar packages first
        for (pkg in knownCalendarPackages) {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "text/calendar")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                setPackage(pkg)
            }
            if (intent.resolveActivity(context.packageManager) != null) {
                try {
                    context.startActivity(intent)
                    Log.d(TAG, "Opened ICS with $pkg")
                    return "opened"
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to launch $pkg: $e")
                }
            }
        }

        // Fallback: query any app that can handle text/calendar
        val viewIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "text/calendar")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val activities = context.packageManager.queryIntentActivities(viewIntent, 0)
        if (activities.isNotEmpty()) {
            context.startActivity(viewIntent)
            Log.d(TAG, "Opened ICS with generic ACTION_VIEW")
            return "opened"
        }

        // Last resort: system document picker
        Log.d(TAG, "No calendar app found, falling back to picker")
        val openIntent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "text/calendar"
        }
        context.startActivity(openIntent)
        return "picker"
    }
}
