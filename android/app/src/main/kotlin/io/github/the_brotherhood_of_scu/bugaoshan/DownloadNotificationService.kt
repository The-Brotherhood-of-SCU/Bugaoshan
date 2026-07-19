package io.github.the_brotherhood_of_scu.bugaoshan

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.EventChannel

/**
 * 负责下载更新时的系统通知栏进度条。
 *
 * - 创建 [CHANNEL_ID] 通道(IMPORTANCE_LOW,不发声不振动)。
 * - 用 [NotificationCompat.Builder.setProgress] 显示进度条。
 * - "取消"按钮通过 [CANCEL_ACTION] PendingIntent 触发 [DownloadCancelReceiver],
 *   后者通过 [notifyCancelPressed] 把事件转发给 EventChannel sink,从而回调到 Dart 端。
 *
 * 实例由 [MainActivity] 在 [configureFlutterEngine] 中创建并静态持有,
 * [DownloadCancelReceiver] 通过 companion object 访问。
 */
class DownloadNotificationService(private val context: Context) {

    companion object {
        const val CHANNEL_ID = "bugaoshan_download"
        const val NOTIFICATION_ID = 1001
        const val CANCEL_ACTION = "bugaoshan.action.CANCEL_DOWNLOAD"
    }

    private var eventSink: EventChannel.EventSink? = null
    private val notificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    init {
        createChannel()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Bugaoshan 下载",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "应用更新下载进度"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    /**
     * 显示或更新下载进度通知。
     * - [indeterminate] 为 true 时显示不确定进度的滚动条(总大小未知)。
     * - [progress] / [max] 在 indeterminate=false 时使用,通常 max=100。
     */
    fun showProgress(
        content: String,
        progress: Int,
        max: Int,
        indeterminate: Boolean,
    ) {
        val builder = buildBuilder(content, progress, max, indeterminate)
        notificationManager.notify(NOTIFICATION_ID, builder.build())
    }

    /**
     * 下载完成:显示"正在安装"且无进度条,允许滑动清除。
     */
    fun showCompleted(content: String) {
        val builder = buildBuilder(content, 0, 0, false)
            .setProgress(0, 0, false)
            .setOngoing(false)
        notificationManager.notify(NOTIFICATION_ID, builder.build())
    }

    /**
     * 下载失败:显示错误内容,允许滑动清除。
     */
    fun showError(content: String) {
        val builder = buildBuilder(content, 0, 0, false)
            .setProgress(0, 0, false)
            .setOngoing(false)
        notificationManager.notify(NOTIFICATION_ID, builder.build())
    }

    /**
     * 取消通知(下载被取消或安装开始后调用)。
     */
    fun cancel() {
        notificationManager.cancel(NOTIFICATION_ID)
    }

    private fun buildBuilder(
        content: String,
        progress: Int,
        max: Int,
        indeterminate: Boolean,
    ): NotificationCompat.Builder {
        val cancelIntent = PendingIntent.getBroadcast(
            context,
            0,
            Intent(CANCEL_ACTION).setPackage(context.packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Bugaoshan")
            .setContentText(content)
            .setProgress(max, progress, indeterminate)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(R.drawable.ic_notification, "取消", cancelIntent)
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    /**
     * 由 [DownloadCancelReceiver.onReceive] 调用,把"取消"事件转发给 Dart 端。
     */
    fun notifyCancelPressed() {
        eventSink?.success(null)
    }
}
