package io.github.the_brotherhood_of_scu.bugaoshan.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.Calendar
import java.util.Date

object WidgetAlarmManager {

    private const val TAG = "WidgetAlarmManager"
    private const val REQUEST_CODE_MIDNIGHT = 20250101
    private const val REQUEST_CODE_COURSE_BOUNDARY = 20250102

    const val ACTION_COURSE_BOUNDARY =
        "io.github.the_brotherhood_of_scu.bugaoshan.action.WIDGET_COURSE_BOUNDARY"

    /**
     * Schedule a one-shot alarm at 00:00:01 to update widgets when the day changes.
     * Uses setAndAllowWhileIdle to fire even during Doze mode.
     * The receiver re-registers this alarm after each fire.
     */
    fun registerMidnightAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, WidgetAlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE_MIDNIGHT,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val nextMidnight = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 1)
            set(Calendar.MILLISECOND, 0)
        }

        alarmManager.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            nextMidnight.timeInMillis,
            pendingIntent,
        )

        Log.d(TAG, "Midnight widget alarm registered for ${nextMidnight.time}")
    }

    /**
     * 在最近的下一个课程开始/结束时刻安排一次性闹钟,使小组件在上下课时
     * 立即刷新,而不是被动等待周期轮询(最长可能延迟 30 分钟)。
     *
     * [triggerAtMillis] 为 null 时取消边界闹钟(今天已无状态变化点)。
     * 每次小组件重新渲染后都会用最新数据调用本方法,形成链式调度;
     * 闹钟触发后由 Receiver 刷新小组件,渲染时再计算并挂上下一个边界。
     */
    fun scheduleCourseBoundaryAlarm(context: Context, triggerAtMillis: Long?) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, WidgetAlarmReceiver::class.java).apply {
            action = ACTION_COURSE_BOUNDARY
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE_COURSE_BOUNDARY,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        if (triggerAtMillis == null) {
            alarmManager.cancel(pendingIntent)
            Log.d(TAG, "Course boundary alarm cancelled (no more transitions today)")
            return
        }

        alarmManager.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAtMillis,
            pendingIntent,
        )

        Log.d(TAG, "Course boundary alarm scheduled for ${Date(triggerAtMillis)}")
    }
}
