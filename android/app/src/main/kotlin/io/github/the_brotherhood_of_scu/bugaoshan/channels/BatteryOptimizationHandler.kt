package io.github.the_brotherhood_of_scu.bugaoshan.channels

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.os.PowerManager

/**
 * 处理电池优化设置(由 `bugaoshan/update` MethodChannel 调用)。
 *
 * 提供:
 * - [isIgnoring]:查询当前 App 是否在电池优化白名单中
 * - [requestIgnore]:弹系统对话框请求加入白名单(失败回退到电池优化设置页)
 */
class BatteryOptimizationHandler(private val context: Context) {

    companion object {
        private const val TAG = "BatteryOptimization"
    }

    fun isIgnoring(): Boolean {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(context.packageName)
    }

    /**
     * 请求加入电池优化白名单。
     * - 已在白名单:直接返回 true。
     * - 弹出系统请求对话框失败(常见于某些 ROM 禁用了该 intent):
     *   回退到通用电池优化设置页。
     * - 仍失败:返回 false。
     */
    fun requestIgnore(): Boolean {
        if (isIgnoring()) {
            return true
        }
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:${context.packageName}")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        try {
            context.startActivity(intent)
            return true
        } catch (e: Exception) {
            Log.e(TAG, "requestIgnoreBatteryOptimizations failed", e)
            try {
                val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(fallbackIntent)
                return true
            } catch (e2: Exception) {
                Log.e(TAG, "Fallback to battery settings also failed", e2)
                return false
            }
        }
    }
}
