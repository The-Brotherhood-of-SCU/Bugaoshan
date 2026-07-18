package io.github.the_brotherhood_of_scu.bugaoshan

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 系统事件后恢复小组件的定时刷新：
 * - BOOT_COMPLETED：重启后闹钟被清除，需要重新注册
 * - MY_PACKAGE_REPLACED：应用更新后 AlarmManager 闹钟会被系统移除，
 *   否则更新后不打开 App 跨天刷新将一直失效
 * - TIME_SET / TIMEZONE_CHANGED：系统时间/时区变化后，按旧时间注册的
 *   闹钟时刻不再正确，且小组件显示的日期/周数需要刷新
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                Log.d(TAG, "System event ${intent.action}, restoring widget schedule")
                WidgetAlarmManager.registerMidnightAlarm(context)
                WidgetUpdater.updateAllWidgets(context)
            }
        }
    }
}
