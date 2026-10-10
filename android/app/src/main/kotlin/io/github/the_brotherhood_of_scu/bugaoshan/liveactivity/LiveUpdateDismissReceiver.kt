package io.github.the_brotherhood_of_scu.bugaoshan.liveactivity

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 接收用户划掉 Live Updates 通知时的系统 deleteIntent 回调。
 *
 * 遵循 Google Android 16 Live Updates 官方设计准则：
 * "Don't repost Live Updates that the user dismissed. Use setDeleteIntent to detect dismissed updates."
 */
class LiveUpdateDismissReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "LiveUpdateDismiss"
        const val ACTION_DISMISS =
            "io.github.the_brotherhood_of_scu.bugaoshan.action.LIVE_UPDATE_DISMISS"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_DISMISS) return
        Log.i(TAG, "Live update notification was dismissed by user")
        AndroidLiveUpdatesManager.onUserDismissed()
    }
}
