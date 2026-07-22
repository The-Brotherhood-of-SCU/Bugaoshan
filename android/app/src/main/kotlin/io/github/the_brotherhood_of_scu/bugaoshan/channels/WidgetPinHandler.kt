package io.github.the_brotherhood_of_scu.bugaoshan.channels

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Build
import android.util.Log
import io.github.the_brotherhood_of_scu.bugaoshan.widget.CourseWidgetReceiverLarge
import io.github.the_brotherhood_of_scu.bugaoshan.widget.CourseWidgetReceiverMedium
import io.github.the_brotherhood_of_scu.bugaoshan.widget.CourseWidgetReceiverSmall

/**
 * 处理小组件 Pin 到主屏幕的请求(由 `bugaoshan/update` MethodChannel 的 `pinWidget` 调用)。
 *
 * 仅 API 26+ 支持 `AppWidgetManager.requestPinAppWidget`。
 */
class WidgetPinHandler(private val activity: Activity) {

    companion object {
        private const val TAG = "CourseWidget"
    }

    /**
     * 请求系统将指定尺寸的 widget Pin 到主屏幕。
     * @param size "small" / "medium" / "large"
     * @return true 表示请求已提交(系统会弹 Pin 快捷方式)
     */
    fun pinWidget(size: String?): Boolean {
        Log.d(TAG, "pinWidget called with size=$size, SDK=${Build.VERSION.SDK_INT}")
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            Log.w(TAG, "pinWidget requires API 26+")
            return false
        }
        val receiverClass = when (size) {
            "small" -> CourseWidgetReceiverSmall::class.java
            "medium" -> CourseWidgetReceiverMedium::class.java
            "large" -> CourseWidgetReceiverLarge::class.java
            else -> {
                Log.w(TAG, "Unknown widget size: $size")
                return false
            }
        }
        return try {
            val mgr = AppWidgetManager.getInstance(activity)
            val component = ComponentName(activity, receiverClass)
            Log.d(TAG, "pinWidget requesting pin for $component")
            val result = mgr.requestPinAppWidget(component, null, null)
            Log.d(TAG, "pinWidget result=$result")
            result
        } catch (e: Exception) {
            Log.e(TAG, "pinWidget failed for size=$size", e)
            false
        }
    }
}
