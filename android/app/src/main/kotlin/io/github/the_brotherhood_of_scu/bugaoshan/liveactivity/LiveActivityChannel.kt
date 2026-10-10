package io.github.the_brotherhood_of_scu.bugaoshan.liveactivity

import android.app.Activity
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Android 平台实时活动 / 状态栏胶囊 MethodChannel 桥接实现。
 *
 * 与 Dart 层契约（见 `lib/services/reminder/live_activity_service.dart`）：
 * - Channel 名称: `bugaoshan/live_activity`
 * - 暴露方法:
 *   1. `isSupported()`: 检查当前设备是否开启了通知权限；
 *   2. `start(arguments)`: 启动实时活动/胶囊，返回会话唯一标识字符串；
 *   3. `update(arguments)`: 更新进行中的实时活动状态；
 *   4. `end()`: 结束活跃会话。
 */
class LiveActivityChannel(private var activity: Activity?) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "LiveActivityChannel"
        const val CHANNEL_NAME = "bugaoshan/live_activity"
    }

    private var channel: MethodChannel? = null

    /**
     * 注册 MethodChannel。
     */
    fun register(messenger: BinaryMessenger) {
        val ch = MethodChannel(messenger, CHANNEL_NAME)
        ch.setMethodCallHandler(this)
        channel = ch
    }

    /**
     * Activity 销毁时释放资源，断开通道监听。
     */
    fun release() {
        channel?.setMethodCallHandler(null)
        channel = null
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("RELEASED", "LiveActivityChannel has been released", null)
            return
        }

        when (call.method) {
            "isSupported" -> {
                val supported = AndroidLiveUpdatesManager.isSupported(currentActivity)
                result.success(supported)
            }
            "start" -> {
                val arguments = call.arguments as? Map<String, Any?>
                if (arguments == null) {
                    result.error("INVALID_ARGUMENT", "Arguments are required for start", null)
                    return
                }
                handleStart(currentActivity, arguments, result)
            }
            "update" -> {
                val arguments = call.arguments as? Map<String, Any?>
                if (arguments == null) {
                    result.error("INVALID_ARGUMENT", "Arguments are required for update", null)
                    return
                }
                handleUpdate(currentActivity, arguments, result)
            }
            "end" -> {
                handleEnd(currentActivity, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun handleStart(
        activity: Activity,
        arguments: Map<String, Any?>,
        result: MethodChannel.Result,
    ) {
        if (!AndroidLiveUpdatesManager.isSupported(activity)) {
            result.error(
                "NOT_AUTHORIZED",
                "Notification permission is not granted for live activity",
                null,
            )
            return
        }

        val courseName = arguments["courseName"] as? String
        val location = (arguments["location"] as? String) ?: ""
        val endAtMillis = (arguments["endAtMillis"] as? Number)?.toLong()
        val startAtMillis = (arguments["startAtMillis"] as? Number)?.toLong()
        val nextCourseName = arguments["nextCourseName"] as? String
        val nextLocation = arguments["nextLocation"] as? String

        if (courseName.isNullOrEmpty() || endAtMillis == null) {
            result.error(
                "INVALID_ARGUMENT",
                "courseName and endAtMillis are required",
                null,
            )
            return
        }

        try {
            val sessionId = AndroidLiveUpdatesManager.startLiveUpdate(
                context = activity,
                courseName = courseName,
                location = location,
                startAtMillis = startAtMillis,
                endAtMillis = endAtMillis,
                nextCourseName = nextCourseName,
                nextLocation = nextLocation,
            )
            result.success(sessionId)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start live activity: $e", e)
            result.error("OPERATION_FAILED", "Failed to start live activity: ${e.message}", null)
        }
    }

    private fun handleUpdate(
        activity: Activity,
        arguments: Map<String, Any?>,
        result: MethodChannel.Result,
    ) {
        if (!AndroidLiveUpdatesManager.hasActiveSession(activity)) {
            result.error(
                "NO_ACTIVE_ACTIVITY",
                "No active live activity session to update",
                null,
            )
            return
        }

        val courseName = arguments["courseName"] as? String
        val location = arguments["location"] as? String
        val endAtMillis = (arguments["endAtMillis"] as? Number)?.toLong()
        val startAtMillis = (arguments["startAtMillis"] as? Number)?.toLong()
        val nextCourseName = arguments["nextCourseName"] as? String
        val nextLocation = arguments["nextLocation"] as? String

        try {
            AndroidLiveUpdatesManager.updateLiveUpdate(
                context = activity,
                courseName = courseName,
                location = location,
                startAtMillis = startAtMillis,
                endAtMillis = endAtMillis,
                nextCourseName = nextCourseName,
                nextLocation = nextLocation,
            )
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update live activity: $e", e)
            result.error("OPERATION_FAILED", "Failed to update live activity: ${e.message}", null)
        }
    }

    private fun handleEnd(activity: Activity, result: MethodChannel.Result) {
        try {
            AndroidLiveUpdatesManager.endLiveUpdate(activity)
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to end live activity: $e", e)
            result.error("OPERATION_FAILED", "Failed to end live activity: ${e.message}", null)
        }
    }
}
