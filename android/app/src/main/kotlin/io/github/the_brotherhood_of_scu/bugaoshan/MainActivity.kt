package io.github.the_brotherhood_of_scu.bugaoshan

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.github.the_brotherhood_of_scu.bugaoshan.channels.ApkInstaller
import io.github.the_brotherhood_of_scu.bugaoshan.channels.BatteryOptimizationHandler
import io.github.the_brotherhood_of_scu.bugaoshan.channels.DynamicIconHandler
import io.github.the_brotherhood_of_scu.bugaoshan.channels.IcsImportHandler
import io.github.the_brotherhood_of_scu.bugaoshan.channels.NotificationPermissionHandler
import io.github.the_brotherhood_of_scu.bugaoshan.channels.WidgetPinHandler
import io.github.the_brotherhood_of_scu.bugaoshan.update.DownloadNotificationService
import io.github.the_brotherhood_of_scu.bugaoshan.update.DownloadNotificationServiceHolder
import io.github.the_brotherhood_of_scu.bugaoshan.widget.WidgetAlarmManager
import io.github.the_brotherhood_of_scu.bugaoshan.widget.WidgetUpdater
import io.github.the_brotherhood_of_scu.bugaoshan.widget.WidgetUpdateWorker

private const val UPDATE_CHANNEL = "bugaoshan/update"
private const val DOWNLOAD_CANCEL_EVENT_CHANNEL = "bugaoshan/download_cancel"
private const val DYNAMIC_ICON_CHANNEL = "bugaoshan/dynamic_icon"

/**
 * 应用入口 Activity。仅负责 FlutterEngine 配置与各 channel 的注册分发,
 * 具体业务逻辑均委托给 [channels] / [update] / [widget] 子包中的 handler / service。
 */
class MainActivity : FlutterActivity() {

    private lateinit var notificationPermission: NotificationPermissionHandler
    private lateinit var dynamicIcon: DynamicIconHandler
    private lateinit var icsImport: IcsImportHandler
    private lateinit var batteryOptimization: BatteryOptimizationHandler
    private lateinit var apkInstaller: ApkInstaller
    private lateinit var widgetPin: WidgetPinHandler
    private var downloadNotification: DownloadNotificationService? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize helpers (must be created before channel handlers reference them)
        notificationPermission = NotificationPermissionHandler(this)
        dynamicIcon = DynamicIconHandler(this)
        icsImport = IcsImportHandler(this)
        batteryOptimization = BatteryOptimizationHandler(this)
        apkInstaller = ApkInstaller(this)
        widgetPin = WidgetPinHandler(this)

        // Periodic widget refresh (WorkManager) + midnight day-change alarm
        WidgetUpdateWorker.enqueuePeriodic(this)
        WidgetAlarmManager.registerMidnightAlarm(this)

        // Download notification service (used by DownloadCancelReceiver via holder)
        val notification = DownloadNotificationService(applicationContext)
        downloadNotification = notification
        DownloadNotificationServiceHolder.service = notification

        registerUpdateChannel(flutterEngine)
        registerDownloadCancelEventChannel(flutterEngine)
        registerDynamicIconChannel(flutterEngine)
    }

    override fun onDestroy() {
        super.onDestroy()
        downloadNotification?.cancel()
        downloadNotification = null
        DownloadNotificationServiceHolder.service = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        notificationPermission.consumePermissionResult(requestCode, grantResults)
    }

    /** `bugaoshan/update` — 多功能 channel:APK 安装、widget 更新、ICS 导入、widget pin、电池优化、下载通知。 */
    private fun registerUpdateChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            apkInstaller.installApk(path)
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGUMENT", "Path is null", null)
                        }
                    }
                    "updateWidget" -> {
                        WidgetUpdater.updateAllWidgets(this)
                        result.success(null)
                    }
                    "importIcsToCalendar" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            result.success(icsImport.importIcsToCalendar(path))
                        } else {
                            result.error("INVALID_ARGUMENT", "Path is null", null)
                        }
                    }
                    "pinWidget" -> {
                        result.success(widgetPin.pinWidget(call.argument<String>("size")))
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        result.success(batteryOptimization.requestIgnore())
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        result.success(batteryOptimization.isIgnoring())
                    }
                    "requestNotificationPermission" -> {
                        notificationPermission.requestPermission(result)
                    }
                    "showDownloadNotification" -> {
                        val content = call.argument<String>("content")
                        if (content != null) {
                            downloadNotification?.showProgress(
                                content = content,
                                progress = call.argument<Int>("progress") ?: 0,
                                max = call.argument<Int>("max") ?: 100,
                                indeterminate = call.argument<Boolean>("indeterminate") ?: false,
                                title = call.argument<String>("title") ?: DownloadNotificationService.DEFAULT_TITLE,
                            )
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGUMENT", "content is null", null)
                        }
                    }
                    "updateDownloadProgress" -> {
                        val content = call.argument<String>("content")
                        if (content != null) {
                            downloadNotification?.showProgress(
                                content = content,
                                progress = call.argument<Int>("progress") ?: 0,
                                max = call.argument<Int>("max") ?: 100,
                                indeterminate = call.argument<Boolean>("indeterminate") ?: false,
                                title = call.argument<String>("title") ?: DownloadNotificationService.DEFAULT_TITLE,
                            )
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGUMENT", "content is null", null)
                        }
                    }
                    "showDownloadCompleted" -> {
                        val content = call.argument<String>("content")
                        if (content != null) {
                            downloadNotification?.showCompleted(
                                content = content,
                                title = call.argument<String>("title") ?: DownloadNotificationService.DEFAULT_TITLE,
                            )
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGUMENT", "content is null", null)
                        }
                    }
                    "showDownloadError" -> {
                        val content = call.argument<String>("content")
                        if (content != null) {
                            downloadNotification?.showError(
                                content = content,
                                title = call.argument<String>("title") ?: DownloadNotificationService.DEFAULT_TITLE,
                            )
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGUMENT", "content is null", null)
                        }
                    }
                    "cancelDownloadNotification" -> {
                        downloadNotification?.cancel()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** `bugaoshan/download_cancel` — Kotlin 主动推送"取消"按钮事件到 Dart。 */
    private fun registerDownloadCancelEventChannel(flutterEngine: FlutterEngine) {
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOAD_CANCEL_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    downloadNotification?.setEventSink(sink)
                }

                override fun onCancel(arguments: Any?) {
                    downloadNotification?.setEventSink(null)
                }
            })
    }

    /** `bugaoshan/dynamic_icon` — 应用图标动态切换。 */
    private fun registerDynamicIconChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DYNAMIC_ICON_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getAvailableIcons" -> result.success(dynamicIcon.getAvailableIcons())
                        "getCurrentIconName" -> result.success(dynamicIcon.getCurrentIcon())
                        "setAlternateIconName" -> {
                            dynamicIcon.setAlternateIcon(call.argument<String>("iconName"))
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                }
            }
    }
}
