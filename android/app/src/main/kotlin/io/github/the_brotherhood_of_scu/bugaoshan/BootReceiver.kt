package io.github.the_brotherhood_of_scu.bugaoshan

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d("BootReceiver", "Device booted, re-registering widget alarm")
            WidgetAlarmManager.registerMidnightAlarm(context)
        }
    }
}
