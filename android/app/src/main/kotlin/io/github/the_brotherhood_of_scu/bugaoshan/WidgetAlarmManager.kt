package io.github.the_brotherhood_of_scu.bugaoshan

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.Calendar

object WidgetAlarmManager {

    private const val TAG = "WidgetAlarmManager"
    private const val REQUEST_CODE = 20250101

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
            REQUEST_CODE,
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
}
