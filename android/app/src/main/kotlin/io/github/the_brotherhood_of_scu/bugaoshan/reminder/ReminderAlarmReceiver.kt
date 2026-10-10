package io.github.the_brotherhood_of_scu.bugaoshan.reminder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationManagerCompat

/**
 * 接收 [ReminderScheduler] 安排的闹钟广播并触发系统通知。
 *
 * 核心考量：
 * 1. 权限拦截：触发时若用户已在系统设置中关闭通知，则静默跳过，避免无谓开销。
 * 2. Doze 兜底与合并投递：
 *    Doze 模式下多条闹钟可能被系统对齐或延后。因此，闹钟唤醒时不仅投递与当前闹钟
 *    时刻完全匹配的条目，还会扫描计划中「<= 当前时刻 + 1分钟 且 在过去 2 小时内」且
 *    「尚未投递」的所有条目一并投递。这样即便前一个闹钟被 Doze 挤压，醒来后也不会漏发。
 * 3. 幂等标记：投递后记录已投递的 reminder ID，防止重复触发。
 */
class ReminderAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ReminderAlarmReceiver"
        // 允许提前 1 分钟内的微小时钟抖动
        private const val CLOCK_SKEW_TOLERANCE_MILLIS = 60_000L
        // 超过 2 小时的过期条目不再补发（比如关机半天后开机，上完的课不必再提醒）。
        // 提到 internal：ReminderScheduler 剪枝已投递历史时要用同一个窗口，避免两处口径漂移。
        internal const val MAX_STALE_TOLERANCE_MILLIS = 2 * 3600_000L
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ReminderScheduler.ACTION_REMINDER_ALARM) {
            return
        }

        // 1. 权限检查
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            Log.w(TAG, "Notification is disabled by user, ignoring alarm trigger")
            return
        }

        val plan = ReminderScheduler.getStoredPlan(context)
        if (plan == null) {
            Log.w(TAG, "No reminder plan stored, nothing to fire")
            return
        }

        val now = System.currentTimeMillis()
        val deliveredIds = ReminderScheduler.getDeliveredIds(context)

        // 2. 查找本次需要投递的提醒条目（包括被 Doze 延迟堆积的条目）
        val dueReminders = plan.reminders.filter { item ->
            val isDue = item.fireAtMillis <= (now + CLOCK_SKEW_TOLERANCE_MILLIS)
            val isNotTooOld = item.fireAtMillis >= (now - MAX_STALE_TOLERANCE_MILLIS)
            val notYetDelivered = !deliveredIds.contains(item.id)
            isDue && isNotTooOld && notYetDelivered
        }

        if (dueReminders.isEmpty()) {
            Log.d(TAG, "Alarm triggered at $now but no pending due reminders found")
            return
        }

        Log.i(TAG, "Alarm fired: delivering ${dueReminders.size} reminder(s)")

        // 3. 逐条投递通知
        val deliveredBatchIds = mutableListOf<String>()
        val deliveredItems = mutableListOf<ReminderItemData>()
        for (item in dueReminders) {
            try {
                ReminderNotification.showReminder(context, item, plan.channel)
                deliveredBatchIds.add(item.id)
                deliveredItems.add(item)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to show notification for reminder ${item.id}", e)
            }
        }

        // 3.5 为本次涉及的分组补发摘要通知（组内实际存活 ≥ 2 条时才发，否则不折叠）。
        //     只统计成功投递的条目，实际存活数以系统内通知为准。
        try {
            ReminderNotification.syncGroupSummaries(context, deliveredItems, plan.channel)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to sync group summaries", e)
        }

        // 4. 记录已投递 ID 保证幂等
        ReminderScheduler.markDelivered(context, deliveredBatchIds)
    }
}
