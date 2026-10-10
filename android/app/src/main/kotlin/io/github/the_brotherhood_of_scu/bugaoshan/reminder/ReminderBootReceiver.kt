package io.github.the_brotherhood_of_scu.bugaoshan.reminder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 系统事件后恢复本地提醒的排期：
 * - BOOT_COMPLETED: 设备重启后，AlarmManager 的所有闹钟都会被系统清空，必须从持久化存储重建。
 * - MY_PACKAGE_REPLACED: 应用覆盖安装更新后，AlarmManager 闹钟可能被系统移除。
 * - TIME_SET / TIMEZONE_CHANGED: 用户调整系统时间或跨时区后，墙钟绝对时刻需要重新核对并过滤。
 *
 * 架构考量（为何不直接改写 widget.BootReceiver）：
 * - 模块解耦：reminder 包与 widget 包属于独立功能域，互不依赖。
 * - 故障隔离：若某一子系统的恢复逻辑发生异常，不会阻断另一子系统的正常恢复。
 * - 声明清晰：在 AndroidManifest.xml 中独立配置，便于审查与后续裁剪。
 */
class ReminderBootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ReminderBootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                Log.d(TAG, "System event ${intent.action} received, reconstructing reminder schedule")
                ReminderScheduler.reconstructSchedule(context)
            }
        }
    }
}
