package io.github.the_brotherhood_of_scu.bugaoshan.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class WidgetAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "WidgetAlarmReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Widget alarm fired: ${intent.action}")
        WidgetUpdater.updateAllWidgets(context)
        // Re-register for the next midnight
        WidgetAlarmManager.registerMidnightAlarm(context)
    }
}
