package io.github.the_brotherhood_of_scu.bugaoshan.reminder

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 本地提醒的 MethodChannel 处理入口。
 *
 * 与 Dart 侧的契约（方法名、参数名、返回结构）：
 * - Channel 名称: `bugaoshan/reminder`
 * - 六个暴露方法:
 *   1. `syncPlan(payload)`: 全量替换排期计划，返回本次排入的未来提醒**条目数**
 *      （注意同一时刻的多条提醒只注册 1 个 AlarmManager 闹钟，故该数可能大于闹钟数；
 *      要看真实闹钟数请用 `getPendingCount`）。未授权返回 NOT_AUTHORIZED；
 *      不支持的 schema 返回 UNSUPPORTED_SCHEMA；payload 结构破损返回 INVALID_ARGUMENT。
 *   2. `cancelAll()`: 撤销全部排期并清空持久化存储。
 *   3. `requestAuthorization(provisional)`: 请求通知权限，返回是否已获得。
 *   4. `getPermissionStatus()`: 查询当前授权状态，取值仅
 *      `authorized` / `denied` / `notDetermined` 三种。
 *   5. `getPendingCount()`: 查询当前系统中有效待触发的提醒条数。
 *   6. `openNotificationSettings()`: 跳转到系统通知设置页面。
 *
 * ⚠️ **Dart 侧尚未落地**：`lib/services/reminder/reminder_transport.dart` 在本 PR 时点
 * 仍不存在（父 issue 的 iOS PR 负责），因此该 channel 目前**没有任何 Dart 调用方**，
 * 属于运行时不可达的死代码。本文档只固定原生侧的契约形状，供 Dart 侧对齐。
 */
class ReminderChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "ReminderChannel"
        const val CHANNEL_NAME = "bugaoshan/reminder"
        private const val SUPPORTED_SCHEMA = 1

        /**
         * 独立权限请求码，与 NotificationPermissionHandler (1001) 互不重叠。
         */
        const val REQUEST_CODE_REMINDER_POST_NOTIFICATIONS = 1002

        private const val PREFS_NAME = "bugaoshan_reminder_channel_prefs"
        private const val KEY_HAS_REQUESTED_PERMISSION = "has_requested_notification_permission"
    }

    private var pendingAuthResult: MethodChannel.Result? = null

    /**
     * 注册 MethodChannel。
     */
    fun register(messenger: BinaryMessenger) {
        val channel = MethodChannel(messenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "syncPlan" -> {
                // 先收成 Map<*, *> 再按 key 归一，避免对泛型不明的参数直接 `as Map<String, Any?>`
                // 触发 unchecked cast 告警；同时容忍 Dart 侧传来非 String 的键。
                val rawArguments = call.arguments as? Map<*, *>
                if (rawArguments == null) {
                    result.error("INVALID_ARGUMENT", "Plan is required", null)
                    return
                }
                val arguments = rawArguments.entries.associate { (key, value) -> key.toString() to value }
                syncPlan(arguments, result)
            }
            "cancelAll" -> {
                cancelAll(result)
            }
            "requestAuthorization" -> {
                requestAuthorization(result)
            }
            "getPermissionStatus" -> {
                getPermissionStatus(result)
            }
            "getPendingCount" -> {
                getPendingCount(result)
            }
            "openNotificationSettings" -> {
                openNotificationSettings(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * Activity 处理运行时权限结果的回调钩子。
     */
    fun consumePermissionResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_CODE_REMINDER_POST_NOTIFICATIONS) return false
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingAuthResult?.success(granted)
        pendingAuthResult = null
        return true
    }

    /**
     * 切断本实例对宿主 Activity 的引用，由宿主在 `onDestroy` 中调用。
     *
     * [pendingAuthResult] 是 [MethodChannel.Result]，其实现绑定到注册本实例的
     * BinaryMessenger。若在权限弹窗尚未回调时 Activity 被销毁，这个引用将没有清理入口：
     * Dart 侧 `requestAuthorization` 的 Future 既不会完成、也不会拿到 false 兜底。
     *
     * 与 [io.github.the_brotherhood_of_scu.bugaoshan.channels.WidgetPinHandler.release]
     * 同构——同类 channel 的宿主清理入口保持一致，后续维护成本更低。
     */
    fun release() {
        pendingAuthResult = null
    }

    // MARK: - 业务逻辑实现

    private fun syncPlan(payload: Map<String, Any?>, result: MethodChannel.Result) {
        val schema = (payload["schema"] as? Number)?.toInt()
        if (schema != SUPPORTED_SCHEMA) {
            result.error(
                "UNSUPPORTED_SCHEMA",
                "Unsupported reminder plan schema",
                payload["schema"],
            )
            return
        }

        // 检查通知授权状态，未授权时绝不登记
        if (!isNotificationAuthorized(activity)) {
            result.error(
                "NOT_AUTHORIZED",
                "Notification authorization not granted",
                null,
            )
            return
        }

        val planData = ReminderPlanData.fromChannelMap(payload)
        if (planData == null) {
            result.error("INVALID_ARGUMENT", "Malformed reminder plan payload", null)
            return
        }

        val scheduledCount = ReminderScheduler.syncPlan(activity, planData)
        // 契约返回 void，传 null 或 scheduledCount 均可
        result.success(scheduledCount)
    }

    private fun cancelAll(result: MethodChannel.Result) {
        ReminderScheduler.cancelAll(activity)
        result.success(null)
    }

    private fun requestAuthorization(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            // Android 13 之前，通知权限在安装时默认开启，检查是否在系统设置中被关闭
            val enabled = NotificationManagerCompat.from(activity).areNotificationsEnabled()
            result.success(enabled)
            return
        }

        if (ContextCompat.checkSelfPermission(
                activity,
                android.Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }

        // 记录曾经发起过权限请求，供 getPermissionStatus 区分 notDetermined 与 denied
        markPermissionRequested()

        // MethodChannel 没有超时兜底：若上一次请求的结果还没回来（并发调用、Activity 重建），
        // 直接覆盖会让先到的那次 Dart Future 永久挂起。必须先给旧 Result 一个终态。
        pendingAuthResult?.let { stale ->
            Log.w(TAG, "Replacing a stale pendingAuthResult from a previous request")
            stale.success(false)
        }
        pendingAuthResult = result

        try {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                REQUEST_CODE_REMINDER_POST_NOTIFICATIONS,
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request POST_NOTIFICATIONS", e)
            pendingAuthResult = null
            // 弹窗根本没弹出来，不能留下「已询问」的痕迹，否则用户永远退回不了 notDetermined。
            clearPermissionRequested()
            result.success(false)
        }
    }

    private fun getPermissionStatus(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            // Android 13 之前没有 POST_NOTIFICATIONS 运行时权限，通知总开关即授权状态。
            val enabled = NotificationManagerCompat.from(activity).areNotificationsEnabled()
            result.success(if (enabled) "authorized" else "denied")
            return
        }

        // Android 13+ 必须先判权限本身：未授予时 areNotificationsEnabled() 恒为 false，
        // 若像原先那样先看总开关就会把「从未询问」一律误报成 denied，
        // notDetermined 分支永远走不到，Dart 侧也就无法区分「还没问」与「问了被拒」。
        val granted = ContextCompat.checkSelfPermission(
            activity,
            android.Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED

        result.success(
            when {
                granted -> "authorized"
                hasRequestedPermission() -> "denied"
                else -> "notDetermined"
            },
        )
    }

    private fun getPendingCount(result: MethodChannel.Result) {
        val count = ReminderScheduler.getPendingCount(activity)
        result.success(count)
    }

    private fun openNotificationSettings(result: MethodChannel.Result) {
        try {
            // minSdk 26，ACTION_APP_NOTIFICATION_SETTINGS 必然可用，无需再分 API 26 的旧分支。
            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
            }
            activity.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to open notification settings directly, falling back to app details", e)
            try {
                val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", activity.packageName, null)
                }
                activity.startActivity(fallback)
                result.success(true)
            } catch (e2: Exception) {
                Log.e(TAG, "Failed to open any settings page", e2)
                result.success(false)
            }
        }
    }

    // MARK: - 辅助检查

    private fun isNotificationAuthorized(context: Context): Boolean {
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            return false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return ContextCompat.checkSelfPermission(
                context,
                android.Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        }
        return true
    }

    private fun markPermissionRequested() {
        val prefs = activity.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_HAS_REQUESTED_PERMISSION, true).apply()
    }

    private fun clearPermissionRequested() {
        val prefs = activity.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_HAS_REQUESTED_PERMISSION, false).apply()
    }

    private fun hasRequestedPermission(): Boolean {
        val prefs = activity.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_HAS_REQUESTED_PERMISSION, false)
    }
}
