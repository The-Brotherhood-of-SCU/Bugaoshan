package io.github.the_brotherhood_of_scu.bugaoshan

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log

class WidgetAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "WidgetAlarmReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Midnight alarm fired, updating widgets")
        updateAllWidgets(context)
        // Re-register for the next midnight
        WidgetAlarmManager.registerMidnightAlarm(context)
    }

    private fun updateAllWidgets(context: Context) {
        try {
            val mgr = AppWidgetManager.getInstance(context)
            val providers = listOf(
                CourseWidgetReceiverSmall::class.java,
                CourseWidgetReceiverMedium::class.java,
                CourseWidgetReceiverLarge::class.java,
            )
            for (cls in providers) {
                val ids = mgr.getAppWidgetIds(ComponentName(context, cls))
                if (ids.isNotEmpty()) {
                    val updateIntent = Intent(context, cls).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                    }
                    context.sendBroadcast(updateIntent)
                    Log.d(TAG, "Updated ${cls.simpleName}: ${ids.size} widgets")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "updateAllWidgets failed", e)
        }
    }
}
