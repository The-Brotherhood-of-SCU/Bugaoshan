package io.github.the_brotherhood_of_scu.bugaoshan.liveactivity

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.github.the_brotherhood_of_scu.bugaoshan.MainActivity
import io.github.the_brotherhood_of_scu.bugaoshan.R
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Android 平台实时活动 / 状态栏胶囊（Live Updates）统一管理器。
 *
 * 遵循多层级标准与多厂商双兼容架构：
 * 1. Google Android 16 (API 36) 原生 Live Updates 规范：
 *    - 注入 `android.requestPromotedOngoing` 请求提升为状态栏芯片（Status Bar Chip / Capsule）；
 *    - 注入 `android.shortCriticalText` 状态栏紧凑芯片文案（严格控制在 96dp 容纳范围内）；
 *    - 遵循官方 Dismissal 规范：绑定 `setDeleteIntent`，用户主动划掉后不再重新发送；
 *    - 探测 `canPostPromotedNotifications()` 胶囊开关状态；
 * 2. 荣耀 MagicOS 灵动胶囊 与 OPPO ColorOS 流体云 双兼容映射协议：
 *    - 注入 `notification.live.*` 胶囊与展开卡片配置 Bundle；
 * 3. 传统 Android 系统平滑降级：
 *    - 保持低优先级静默常驻卡片（`Ongoing` + `BigTextStyle`），下课自动销毁。
 */
object AndroidLiveUpdatesManager {

    private const val TAG = "AndroidLiveUpdates"

    /**
     * 实时活动专用通知渠道 ID（升级至 v2，重置历史构建的 IMPORTANCE_HIGH 缓存）。
     */
    const val CHANNEL_ID = "bugaoshan_live_activity_v2"
    private const val LEGACY_CHANNEL_ID = "bugaoshan_live_activity"

    /**
     * 实时活动固定通知 ID（"LIVE" in ASCII = 0x4C495645 = 1279874629）。
     * 保持单一会话覆盖更新，避免多条胶囊冲突。
     */
    const val LIVE_UPDATE_NOTIFICATION_ID = 0x4C495645

    // Google Android 16 (API 36) 原生 Live Updates / Promoted Ongoing 标准规范键名
    private const val EXTRA_REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing"
    private const val EXTRA_SHORT_CRITICAL_TEXT = "android.shortCriticalText"

    // 国内主流系统（荣耀 MagicOS 8/9+ 灵动胶囊、OPPO ColorOS 15/16 流体云、vivo OriginOS 5）协议常量
    // 经荣耀 MagicOS (Android 17) 实测验证：通过在 Notification Extras 中注入此 Bundle 结构，
    // 系统守护进程将其自动提取并提升为顶部状态栏胶囊。
    private const val EXTRA_LIVE_OPERATION = "notification.live.operation"
    private const val EXTRA_LIVE_EVENT = "notification.live.event"
    private const val EXTRA_LIVE_TYPE = "notification.live.type"
    private const val EXTRA_LIVE_TITLE_OVERLAY = "notification.live.titleOverlay"
    private const val EXTRA_LIVE_CAPSULE = "notification.live.capsule"
    private const val EXTRA_LIVE_FEATURE = "notification.live.feature"

    private const val EXTRA_CAPSULE_STATUS = "notification.live.capsuleStatus"
    private const val EXTRA_CAPSULE_TYPE = "notification.live.capsuleType"
    private const val EXTRA_CAPSULE_TITLE = "notification.live.capsuleTitle"
    private const val EXTRA_CAPSULE_CONTENT = "notification.live.capsuleContent"
    private const val EXTRA_CAPSULE_BG_COLOR = "notification.live.capsuleBgColor"
    private const val EXTRA_CAPSULE_ICON = "notification.live.capsuleIcon"

    // 协议魔数定义
    private const val OPERATION_START = 0 // 创建/开始
    private const val OPERATION_UPDATE = 1 // 更新状态
    private const val EVENT_ORDER = "ORDER" // 行程/事件类
    private const val TYPE_ORDER_PROGRESS = 3 // 履约中状态
    private const val CAPSULE_STATUS_SHOW = 1 // 胶囊显示态
    private const val CAPSULE_TYPE_NORMAL = 1 // 常规药丸胶囊
    private const val COLOR_SCU_RED = "#C62828" // 四川大学校色主题红

    private var activeSessionId: String? = null

    /**
     * 记录当前会话是否已被用户在系统通知栏主动划掉。
     *
     * 遵循 Google Android 16 官方 Dismissal 规范：
     * "Don't repost Live Updates that the user dismissed. Use setDeleteIntent to detect dismissed updates."
     * 一旦用户主动划掉，后续的后台 update 均静默忽略，避免骚扰用户导致权限被系统收回；
     * 下一节新课程开始（startLiveUpdate）时重置该标志。
     */
    @Volatile
    private var dismissedByUser: Boolean = false

    // 会话状态缓存，供 update 时执行字段增量合并
    private var lastCourseName: String? = null
    private var lastLocation: String? = null
    private var lastStartAtMillis: Long? = null
    private var lastEndAtMillis: Long? = null
    private var lastNextCourseName: String? = null
    private var lastNextLocation: String? = null

    /**
     * 检查当前设备是否支持并允许展示实时活动 / 胶囊。
     *
     * 1. 基础检查：应用通知权限是否开启；
     * 2. Android 16+ (API 36+) 专属检查：用户是否开启了 Promoted Notifications 开关。
     */
    fun isSupported(context: Context): Boolean {
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            return false
        }

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return false

        // 探测 Android 16 (API 36) 用户级 Promoted Notifications 开关
        try {
            val method = notificationManager.javaClass.getMethod("canPostPromotedNotifications")
            val canPromote = method.invoke(notificationManager) as? Boolean
            if (canPromote != null) return canPromote
        } catch (_: Throwable) {
            // API < 36 或平台未提供该方法，依循基础通知权限
        }

        return true
    }

    /**
     * 创建实时活动专用的静默通知渠道（API 26+）。
     *
     * 采用 [NotificationManager.IMPORTANCE_LOW]，无声无横幅常驻于状态栏与通知中心，
     * 避免上课开始时弹出强打扰横幅或触发震动。若存在旧版本的 HIGH 渠道则执行清理升级。
     */
    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    ?: return

            // 清理旧版可能残留的 HIGH 渠道，确保 IMPORTANCE_LOW 生效
            try {
                if (notificationManager.getNotificationChannel(LEGACY_CHANNEL_ID) != null) {
                    notificationManager.deleteNotificationChannel(LEGACY_CHANNEL_ID)
                }
            } catch (_: Throwable) {}

            val existing = notificationManager.getNotificationChannel(CHANNEL_ID)
            if (existing != null) return

            val channelName = try {
                context.getString(R.string.live_activity_channel_name)
            } catch (e: Exception) {
                "课程实时动态"
            }
            val channelDesc = try {
                context.getString(R.string.live_activity_channel_desc)
            } catch (e: Exception) {
                "上课期间状态栏胶囊与锁屏实时卡片"
            }

            val channel = NotificationChannel(
                CHANNEL_ID,
                channelName,
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = channelDesc
                enableLights(false)
                enableVibration(false)
                setShowBadge(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }

            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Live update channel created: $CHANNEL_ID")
        }
    }

    /**
     * 启动实时活动会话。
     *
     * @return 返回原生生成的唯一会话标识。
     */
    fun startLiveUpdate(
        context: Context,
        courseName: String,
        location: String,
        startAtMillis: Long?,
        endAtMillis: Long,
        nextCourseName: String?,
        nextLocation: String?,
    ): String {
        ensureChannel(context)

        // 新课程会话启动，重置用户划掉状态
        dismissedByUser = false

        val sessionId = "android_live_${System.currentTimeMillis()}"
        cacheSessionState(
            courseName = courseName,
            location = location,
            startAtMillis = startAtMillis,
            endAtMillis = endAtMillis,
            nextCourseName = nextCourseName,
            nextLocation = nextLocation,
        )

        postLiveNotification(
            context = context,
            operation = OPERATION_START,
            courseName = courseName,
            location = location,
            startAtMillis = startAtMillis,
            endAtMillis = endAtMillis,
            nextCourseName = nextCourseName,
            nextLocation = nextLocation,
        )
        activeSessionId = sessionId
        Log.i(TAG, "Live update started: $sessionId ($courseName @ $location)")
        return sessionId
    }

    /**
     * 更新进行中的实时活动状态。
     *
     * 采用增量合并语义：传入 null 的字段继承上一次会话缓存。
     * 若用户此前已主动划掉通知，则静默忽略更新（符合 Google Android 16 规范）。
     */
    fun updateLiveUpdate(
        context: Context,
        courseName: String?,
        location: String?,
        startAtMillis: Long?,
        endAtMillis: Long?,
        nextCourseName: String?,
        nextLocation: String?,
    ) {
        if (dismissedByUser) {
            Log.d(TAG, "Live update was dismissed by user, skipping repost")
            return
        }

        ensureChannel(context)

        val effectiveCourseName = courseName ?: lastCourseName ?: "当前课程"
        val effectiveLocation = location ?: lastLocation ?: ""
        val effectiveStartAtMillis = startAtMillis ?: lastStartAtMillis
        val effectiveEndAtMillis = endAtMillis ?: lastEndAtMillis
        val effectiveNextCourseName = nextCourseName ?: lastNextCourseName
        val effectiveNextLocation = nextLocation ?: lastNextLocation

        cacheSessionState(
            courseName = effectiveCourseName,
            location = effectiveLocation,
            startAtMillis = effectiveStartAtMillis,
            endAtMillis = effectiveEndAtMillis,
            nextCourseName = effectiveNextCourseName,
            nextLocation = effectiveNextLocation,
        )

        postLiveNotification(
            context = context,
            operation = OPERATION_UPDATE,
            courseName = effectiveCourseName,
            location = effectiveLocation,
            startAtMillis = effectiveStartAtMillis,
            endAtMillis = effectiveEndAtMillis,
            nextCourseName = effectiveNextCourseName,
            nextLocation = effectiveNextLocation,
        )
        Log.d(TAG, "Live update updated ($effectiveCourseName)")
    }

    /**
     * 结束并清除实时活动。
     *
     * 直接调用 [NotificationManager.cancel]，避免与异步 notify 发生 IPC 竞态，
     * 同时规避空文本投递导致的脏文本展示。
     */
    fun endLiveUpdate(context: Context) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return

        notificationManager.cancel(LIVE_UPDATE_NOTIFICATION_ID)
        activeSessionId = null
        dismissedByUser = false
        clearSessionState()
        Log.i(TAG, "Live update ended and cancelled")
    }

    /**
     * 用户主动从通知中心划掉通知的回调入口（由 [LiveUpdateDismissReceiver] 触发）。
     */
    fun onUserDismissed() {
        Log.i(TAG, "User dismissed live update notification, marking session as dismissed")
        activeSessionId = null
        dismissedByUser = true
        clearSessionState()
    }

    /**
     * 查询是否存在活跃会话。
     *
     * 结合内存标识与系统真实存活通知：即使应用进程在后台被回收重启，
     * 只要通知栏/状态栏胶囊依然存在且未被划掉，即视为处于活跃状态并支持隐式恢复会话，
     * 避免向 Dart 误报 NO_ACTIVE_ACTIVITY。
     */
    fun hasActiveSession(context: Context? = null): Boolean {
        if (dismissedByUser) return false
        if (activeSessionId != null) return true
        if (context == null) return false

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return false

        val hasActiveNotification = notificationManager.activeNotifications.any {
            it.id == LIVE_UPDATE_NOTIFICATION_ID
        }
        if (hasActiveNotification) {
            activeSessionId = "android_live_restored"
            return true
        }
        return false
    }

    private fun cacheSessionState(
        courseName: String,
        location: String,
        startAtMillis: Long?,
        endAtMillis: Long?,
        nextCourseName: String?,
        nextLocation: String?,
    ) {
        lastCourseName = courseName
        lastLocation = location
        lastStartAtMillis = startAtMillis
        lastEndAtMillis = endAtMillis
        lastNextCourseName = nextCourseName
        lastNextLocation = nextLocation
    }

    private fun clearSessionState() {
        lastCourseName = null
        lastLocation = null
        lastStartAtMillis = null
        lastEndAtMillis = null
        lastNextCourseName = null
        lastNextLocation = null
    }

    private fun postLiveNotification(
        context: Context,
        operation: Int,
        courseName: String,
        location: String,
        startAtMillis: Long?,
        endAtMillis: Long?,
        nextCourseName: String?,
        nextLocation: String?,
    ) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return

        val contentIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            LIVE_UPDATE_NOTIFICATION_ID,
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        // 绑定 deleteIntent 监听用户主动划掉通知
        val deleteIntent = Intent(context, LiveUpdateDismissReceiver::class.java).apply {
            action = LiveUpdateDismissReceiver.ACTION_DISMISS
        }
        val deletePendingIntent = PendingIntent.getBroadcast(
            context,
            LIVE_UPDATE_NOTIFICATION_ID,
            deleteIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val endTimeText = formatTime(endAtMillis)
        val displayText = when {
            location.isNotEmpty() -> "地点：$location"
            endTimeText.isNotEmpty() -> "预计 $endTimeText 下课"
            else -> "进行中"
        }

        // 状态栏芯片（Chip）文本：根据 Android 16 规范严格控制在 96dp 以内，
        // 优先展示清晰紧凑的 "11:40 下课"，避免过长文案被系统截断
        val shortCriticalText = if (endTimeText.isNotEmpty()) "$endTimeText 下课" else courseName

        val summaryText = buildString {
            if (location.isNotEmpty()) {
                append("地点：").append(location)
            }
            if (endTimeText.isNotEmpty()) {
                if (isNotEmpty()) append("  |  ")
                append("预计 ").append(endTimeText).append(" 下课")
            }
            if (!nextCourseName.isNullOrEmpty()) {
                append("\n下节预告：").append(nextCourseName)
                if (!nextLocation.isNullOrEmpty()) {
                    append(" · ").append(nextLocation)
                }
            }
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(courseName)
            .setContentText(displayText)
            .setStyle(NotificationCompat.BigTextStyle().bigText(summaryText))
            .setContentIntent(pendingIntent)
            .setDeleteIntent(deletePendingIntent)
            .setOngoing(true) // Promoted Ongoing 必须满足 ongoing 约束
            .setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_LOW) // 静默无感常驻
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_EVENT)
            .setShowWhen(false) // 禁用 when 倒计时覆盖 shortCriticalText

        if (startAtMillis != null) {
            builder.setWhen(startAtMillis)
        }

        // 注入 Android 16 原生 Live Updates + 国内主流厂商胶囊参数
        val liveExtras = Bundle().apply {
            // 1. Google Android 16 (API 36) 原生 Live Updates 标准规范
            //    - EXTRA_REQUEST_PROMOTED_ONGOING: 请求提升为状态栏芯片（Chip）
            //    - EXTRA_SHORT_CRITICAL_TEXT: 状态栏芯片紧凑展示文本（≤96dp）
            putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true)
            putCharSequence(EXTRA_SHORT_CRITICAL_TEXT, shortCriticalText)

            // 2. 荣耀 MagicOS 灵动胶囊 & OPPO ColorOS 流体云 双兼容协议字段
            putInt(EXTRA_LIVE_OPERATION, operation)
            putString(EXTRA_LIVE_EVENT, EVENT_ORDER)
            putInt(EXTRA_LIVE_TYPE, TYPE_ORDER_PROGRESS)
            putCharSequence(EXTRA_LIVE_TITLE_OVERLAY, courseName)

            // 胶囊态配置（状态栏胶囊药丸）
            val capsule = Bundle().apply {
                putInt(EXTRA_CAPSULE_STATUS, CAPSULE_STATUS_SHOW)
                putInt(EXTRA_CAPSULE_TYPE, CAPSULE_TYPE_NORMAL)
                putString(EXTRA_CAPSULE_TITLE, courseName)
                putString(EXTRA_CAPSULE_CONTENT, if (location.isNotEmpty()) location else "$endTimeText 下课")
                putString(EXTRA_CAPSULE_BG_COLOR, COLOR_SCU_RED)

                // 兼容老版本/无前缀键名
                putString("capsuleTitle", courseName)
                putString("capsuleContent", displayText)
                putString("capsuleBgColor", COLOR_SCU_RED)

                try {
                    putParcelable(
                        EXTRA_CAPSULE_ICON,
                        Icon.createWithResource(context, R.drawable.ic_notification),
                    )
                } catch (e: Throwable) {
                    // 安全防护
                }
            }
            putBundle(EXTRA_LIVE_CAPSULE, capsule)

            // 展开卡片业务数据
            val feature = Bundle().apply {
                putString("courseName", courseName)
                putString("location", location)
                if (!nextCourseName.isNullOrEmpty()) {
                    putString("nextCourse", nextCourseName)
                }
                if (!nextLocation.isNullOrEmpty()) {
                    putString("nextLocation", nextLocation)
                }
            }
            putBundle(EXTRA_LIVE_FEATURE, feature)
        }

        builder.addExtras(liveExtras)
        notificationManager.notify(LIVE_UPDATE_NOTIFICATION_ID, builder.build())
    }

    private fun formatTime(millis: Long?): String {
        if (millis == null || millis <= 0) return ""
        return try {
            val sdf = SimpleDateFormat("HH:mm", Locale.getDefault())
            sdf.format(Date(millis))
        } catch (e: Exception) {
            ""
        }
    }
}
