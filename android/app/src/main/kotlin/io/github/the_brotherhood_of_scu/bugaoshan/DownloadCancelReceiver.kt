package io.github.the_brotherhood_of_scu.bugaoshan

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 接收通知栏"取消下载"按钮的 PendingIntent,把事件转发到 [DownloadNotificationService]。
 *
 * 由 [DownloadNotificationService.CANCEL_ACTION] 触发(由 PendingIntent 发出),
 * 服务实例通过 [MainActivity.notificationService] 静态字段访问。
 */
class DownloadCancelReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != DownloadNotificationService.CANCEL_ACTION) return
        try {
            MainActivity.notificationService?.notifyCancelPressed()
        } catch (e: Exception) {
            Log.e("DownloadCancel", "Failed to forward cancel event", e)
        }
    }
}
