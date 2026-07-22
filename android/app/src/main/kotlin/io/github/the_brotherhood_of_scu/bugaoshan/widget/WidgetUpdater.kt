package io.github.the_brotherhood_of_scu.bugaoshan.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 小组件更新的公共入口。通过发送 ACTION_APPWIDGET_UPDATE 广播触发
 * Glance 重新组合(组合时从 SQLite 重新加载最新数据)。
 */
object WidgetUpdater {
    private const val TAG = "WidgetUpdater"

    private val receiverClasses = listOf(
        CourseWidgetReceiverSmall::class.java,
        CourseWidgetReceiverMedium::class.java,
        CourseWidgetReceiverLarge::class.java,
    )

    /** 向所有已添加的小组件发送更新广播。 */
    fun updateAllWidgets(context: Context) {
        try {
            val mgr = AppWidgetManager.getInstance(context)
            for (cls in receiverClasses) {
                val ids = mgr.getAppWidgetIds(ComponentName(context, cls))
                if (ids.isNotEmpty()) {
                    val intent = Intent(context, cls).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                    }
                    context.sendBroadcast(intent)
                    Log.d(TAG, "Sent update broadcast for ${cls.simpleName}: ${ids.size} widgets")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "updateAllWidgets failed", e)
        }
    }

    /**
     * 语言环境变化后清布局缓存并刷新全部小组件。
     * 只在一个 Receiver 上注册 LOCALE_CHANGED,避免三种尺寸各自重复全量更新。
     */
    fun onLocaleChanged(context: Context) {
        WidgetLayoutCache.clear()
        updateAllWidgets(context)
    }
}
