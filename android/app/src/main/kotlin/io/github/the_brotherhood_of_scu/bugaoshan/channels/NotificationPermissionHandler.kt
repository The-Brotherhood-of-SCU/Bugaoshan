package io.github.the_brotherhood_of_scu.bugaoshan.channels

import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel

/**
 * 处理 POST_NOTIFICATIONS 运行时权限请求(Android 13+)。
 *
 * - API < 33:无运行时权限要求,直接返回 true。
 * - API >= 33 且已授予:返回 true。
 * - API >= 33 且未授予:启动系统权限对话框,结果在 [Activity.onRequestPermissionsResult]
 *   中通过 [consumePermissionResult] 回传给挂起的 [MethodChannel.Result]。
 *
 * 注意:权限被拒绝不阻断下载流程,调用方应忽略返回值继续执行下载逻辑。
 */
class NotificationPermissionHandler(private val activity: Activity) {

    companion object {
        private const val TAG = "NotificationPerm"
        private const val REQUEST_CODE_POST_NOTIFICATIONS = 1001
    }

    private var pendingResult: MethodChannel.Result? = null

    /**
     * 由 Activity 在 [Activity.onRequestPermissionsResult] 中调用,
     * 把权限请求结果回传给挂起的 [MethodChannel.Result]。
     */
    fun consumePermissionResult(
        requestCode: Int,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE_POST_NOTIFICATIONS) return false
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingResult?.success(granted)
        pendingResult = null
        return true
    }

    /**
     * 请求权限。在 Android 13+ 启动系统权限对话框;其他情况直接同步返回 true。
     */
    fun requestPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        if (ContextCompat.checkSelfPermission(
                activity,
                android.Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        pendingResult = result
        try {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                REQUEST_CODE_POST_NOTIFICATIONS,
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request POST_NOTIFICATIONS", e)
            pendingResult = null
            result.success(false)
        }
    }
}
