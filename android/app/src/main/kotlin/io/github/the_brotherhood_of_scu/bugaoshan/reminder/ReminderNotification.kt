package io.github.the_brotherhood_of_scu.bugaoshan.reminder

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.github.the_brotherhood_of_scu.bugaoshan.MainActivity
import io.github.the_brotherhood_of_scu.bugaoshan.R

/**
 * 本地提醒的通知构建与通知渠道管理。
 *
 * 与既有 [io.github.the_brotherhood_of_scu.bugaoshan.update.DownloadNotificationService] 分离：
 * - 下载通知为低优先级（IMPORTANCE_LOW）常驻进度条，静音且不震动。
 * - 课程提醒为高优先级（IMPORTANCE_HIGH）横幅通知，支持声音与震动。
 *
 * 注意：高优先级**不等于**锁屏唤醒。锁屏全屏展示需要 full-screen intent 且渠道
 * IMPORTANCE_HIGH，本原型两者都没启用；横幅能否弹出也受用户渠道设置与勿扰模式影响。
 * 如需锁屏亮屏（课前提醒的常见诉求），应另行评估 full-screen intent 的政策与体验代价。
 *
 * 渠道 ID 默认为 [DEFAULT_CHANNEL_ID]（与 Dart 侧 `channel: bugaoshan_reminder` 严格对应）。
 */
object ReminderNotification {

    private const val TAG = "ReminderNotification"
    const val DEFAULT_CHANNEL_ID = "bugaoshan_reminder"

    /**
     * 创建课程提醒专用的通知渠道（API 26+）。
     *
     * 设为 IMPORTANCE_HIGH 以获得横幅与提示音；这不等于锁屏唤醒（见类注释）。
     */
    fun createChannel(context: Context, channelId: String = DEFAULT_CHANNEL_ID) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    ?: return

            // 若渠道已存在，系统不会重复创建也不会覆盖用户已修改的设置
            val existing = notificationManager.getNotificationChannel(channelId)
            if (existing != null) return

            val name = try {
                context.getString(R.string.reminder_notification_channel_name)
            } catch (e: Exception) {
                "课程提醒"
            }
            val descriptionText = try {
                context.getString(R.string.reminder_notification_channel_desc)
            } catch (e: Exception) {
                "上课前的课前提醒通知"
            }

            val channel = NotificationChannel(
                channelId,
                name,
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = descriptionText
                enableLights(true)
                enableVibration(true)
                setShowBadge(true)
            }

            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel created: $channelId")
        }
    }

    /**
     * 投递单条提醒通知。
     *
     * @param context 上下文
     * @param item 提醒条目数据
     * @param channelId 通知渠道 ID
     */
    fun showReminder(
        context: Context,
        item: ReminderItemData,
        channelId: String = DEFAULT_CHANNEL_ID,
    ) {
        createChannel(context, channelId)

        // 检查通知权限是否可用，被拒则不发
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            Log.w(TAG, "Notification is disabled by user, skipping reminder: ${item.id}")
            return
        }

        // 点击通知拉起 MainActivity
        val contentIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("reminder_id", item.id)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            item.stableNotificationId,
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(item.title)
            .setContentText(item.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(item.body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setWhen(item.fireAtMillis)
            .setShowWhen(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)

        // 若有折叠分组键，利用 setGroup 归入同一通知组。
        // 仅 setGroup 不会折叠——折叠由 [syncGroupSummaries] 补发的摘要通知驱动。
        if (!item.collapseKey.isNullOrEmpty()) {
            builder.setGroup(item.collapseKey)
        }

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        if (notificationManager != null) {
            notificationManager.notify(item.stableNotificationId, builder.build())
            Log.d(TAG, "Reminder notification posted: id=${item.id}, notifId=${item.stableNotificationId}")
        } else {
            Log.e(TAG, "NotificationManager not available")
        }
    }

    /**
     * 为本次投递涉及的每个通知组补一条「分组摘要」通知。
     *
     * 为什么必须显式发摘要：自 Android 7.0 起，[NotificationCompat.Builder.setGroup] 只负责
     * **归类**，折叠展示由一条 [NotificationCompat.Builder.setGroupSummary] 为 `true` 的摘要
     * 通知驱动，没有摘要的分组只会平铺。本项目 targetSdk 为 Flutter 默认的 API 36，而
     * Android 16 已移除通知自动分组，因此补摘要是折叠生效的唯一途径。
     *
     * 计数取「系统中该组**实际存活**的通知数」而非本批投递条数，原因有二：
     * 1. 单条投递可能失败（见 [ReminderAlarmReceiver] 的 try/catch）；
     * 2. 同一组可能跨多次闹钟投递，且用户可能已手动划掉其中若干条。
     *
     * 存活数 < 2 时不发摘要，并主动撤掉可能残留的旧摘要——否则会出现「组内只剩 1 条、
     * 折叠标题却写着 3 条」的错位。单击通知会连带清掉同组其余通知，故撤摘要的时机
     * 由系统在下一次 [syncGroupSummaries] 调用时收敛。
     *
     * @param context 上下文
     * @param items 本次成功投递的提醒条目（无分组键的条目会被忽略）
     * @param channelId 通知渠道 ID
     */
    fun syncGroupSummaries(
        context: Context,
        items: List<ReminderItemData>,
        channelId: String = DEFAULT_CHANNEL_ID,
    ) {
        // activeNotifications 需要 API 23；本项目 minSdk 26，保留判断以防下调 minSdk。
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        if (items.isEmpty()) return

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

        val groupKeys = items.mapNotNull { it.collapseKey?.takeIf { key -> key.isNotEmpty() } }.toSet()
        for (groupKey in groupKeys) {
            val summaryId = groupSummaryId(groupKey)
            // 取 Notification.getGroup() 而非 StatusBarNotification 的 getter：API 36 起
            // StatusBarNotification 已迁到 android.service.notification 且只暴露 getGroupKey()，
            // 这里读的正是我们经 setGroup() 写入的那个键，跨版本稳定。
            val activeCount = notificationManager.activeNotifications.count {
                it.notification.group == groupKey
            }
            if (activeCount < 2) {
                notificationManager.cancel(summaryId)
                continue
            }
            val summary = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(
                    context.resources.getQuantityString(
                        R.plurals.reminder_notification_group_summary,
                        activeCount,
                        activeCount,
                    ),
                )
                .setGroup(groupKey)
                .setGroupSummary(true)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .build()
            notificationManager.notify(summaryId, summary)
            Log.d(TAG, "Group summary posted: group=$groupKey, count=$activeCount")
        }
    }

    /**
     * 摘要通知 ID：由分组键哈希映射到正数空间，使同一组始终复用同一 ID——
     * 重复投递时覆盖更新而不是在通知栏里堆积多条摘要。
     *
     * 注意它与 [ReminderItemData.stableNotificationId] 共用同一个 ID 空间，
     * 理论上存在与某条提醒撞号的可能（概率约 `n / 2^31`），撞号会让摘要覆盖那一条提醒。
     * 这里接受该概率：换取「同组 ID 稳定」所避免的残留问题要常见得多。
     */
    private fun groupSummaryId(groupKey: String): Int = groupKey.hashCode() and 0x7FFFFFFF
}
