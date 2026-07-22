package io.github.the_brotherhood_of_scu.bugaoshan.update

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 接收通知栏"取消下载"按钮的 PendingIntent,把事件转发到 [DownloadNotificationService]。
 *
 * 由 [DownloadNotificationService.CANCEL_ACTION] 触发(由 PendingIntent 发出),
 * 服务实例通过单例访问(由 MainActivity 在 configureFlutterEngine 中初始化)。
 */
class DownloadCancelReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != DownloadNotificationService.CANCEL_ACTION) return
        try {
            DownloadNotificationServiceHolder.service?.notifyCancelPressed()
        } catch (e: Exception) {
            Log.e("DownloadCancel", "Failed to forward cancel event", e)
        }
    }
}

/**
 * 通知服务单例持有者。
 *
 * 由 [io.github.the_brotherhood_of_scu.bugaoshan.MainActivity] 在
 * [configureFlutterEngine][io.github.the_brotherhood_of_scu.bugaoshan.MainActivity.configureFlutterEngine]
 * 中赋值,由 [DownloadCancelReceiver] 读取。
 *
 * 不放在 MainActivity 的 companion object 中,是为了避免 BroadcastReceiver
 * 跨包访问 MainActivity 的私有字段(Kotlin 跨包访问伴生对象成员有可见性约束)。
 */
object DownloadNotificationServiceHolder {
    @Volatile
    var service: DownloadNotificationService? = null
}
