package io.github.the_brotherhood_of_scu.bugaoshan.channels

import android.app.Activity
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.github.the_brotherhood_of_scu.bugaoshan.CourseWidgetReceiverLarge
import io.github.the_brotherhood_of_scu.bugaoshan.CourseWidgetReceiverMedium
import io.github.the_brotherhood_of_scu.bugaoshan.CourseWidgetReceiverSmall

/**
 * 处理小组件 Pin 到主屏幕的请求(由 `bugaoshan/update` MethodChannel 的 `pinWidget` 调用)。
 *
 * 仅 API 26+ 支持 `AppWidgetManager.requestPinAppWidget`。
 *
 * 注意: `requestPinAppWidget` 返回 true 只表示"请求已提交",并不代表用户真正确认添加。
 * 部分 ROM(如 MIUI)在未授予「创建桌面快捷方式」权限时会静默拦截,系统弹窗根本不会出现。
 * 因此通过成功回调 PendingIntent 上报真实的 Pin 成功事件([onWidgetPinned]),
 * 并提供 [getWidgetIds] 供 Dart 端 diff 验证、[openAppSettings] 引导用户开启权限。
 */
class WidgetPinHandler(private val activity: Activity) {

    companion object {
        private const val TAG = "CourseWidget"
        private const val ACTION_WIDGET_PINNED =
            "io.github.the_brotherhood_of_scu.bugaoshan.WIDGET_PINNED"
        private const val EXTRA_SIZE = "size"
    }

    /** 用户真正确认 Pin 后触发(参数为尺寸 small/medium/large)。 */
    var onWidgetPinned: ((String) -> Unit)? = null

    private val pinSuccessReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != ACTION_WIDGET_PINNED) return
            val size = intent.getStringExtra(EXTRA_SIZE) ?: return
            Log.d(TAG, "widget pinned callback received, size=$size")
            onWidgetPinned?.invoke(size)
        }
    }

    private var receiverRegistered = false

    private fun ensureReceiverRegistered() {
        if (receiverRegistered) return
        val filter = IntentFilter(ACTION_WIDGET_PINNED)
        val appContext = activity.applicationContext
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            appContext.registerReceiver(
                pinSuccessReceiver,
                filter,
                Context.RECEIVER_NOT_EXPORTED,
            )
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            appContext.registerReceiver(pinSuccessReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun receiverClassFor(size: String?): Class<*>? = when (size) {
        "small" -> CourseWidgetReceiverSmall::class.java
        "medium" -> CourseWidgetReceiverMedium::class.java
        "large" -> CourseWidgetReceiverLarge::class.java
        else -> null
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
        val receiverClass = receiverClassFor(size)
        if (receiverClass == null) {
            Log.w(TAG, "Unknown widget size: $size")
            return false
        }
        return try {
            ensureReceiverRegistered()
            val mgr = AppWidgetManager.getInstance(activity)
            val component = ComponentName(activity, receiverClass)
            val callbackIntent = Intent(ACTION_WIDGET_PINNED)
                .setPackage(activity.packageName)
                .putExtra(EXTRA_SIZE, size)
            val successCallback = PendingIntent.getBroadcast(
                activity,
                0,
                callbackIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            Log.d(TAG, "pinWidget requesting pin for $component")
            val result = mgr.requestPinAppWidget(component, null, successCallback)
            Log.d(TAG, "pinWidget result=$result")
            result
        } catch (e: Exception) {
            Log.e(TAG, "pinWidget failed for size=$size", e)
            false
        }
    }

    /** 查询三种尺寸小组件当前已添加到桌面的全部 widget id(用于添加前后 diff 验证)。 */
    fun getWidgetIds(): List<Int> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.JELLY_BEAN_MR1) return emptyList()
        return try {
            val mgr = AppWidgetManager.getInstance(activity)
            listOf(
                CourseWidgetReceiverSmall::class.java,
                CourseWidgetReceiverMedium::class.java,
                CourseWidgetReceiverLarge::class.java,
            ).flatMap { receiver ->
                mgr.getAppWidgetIds(ComponentName(activity, receiver)).toList()
            }
        } catch (e: Exception) {
            Log.e(TAG, "getWidgetIds failed", e)
            emptyList()
        }
    }

    /** 打开本应用的系统详情设置页(引导用户开启「创建桌面快捷方式」等权限)。 */
    fun openAppSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${activity.packageName}")
            }
            activity.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e(TAG, "openAppSettings failed", e)
            false
        }
    }
}
