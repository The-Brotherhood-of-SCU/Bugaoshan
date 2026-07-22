package io.github.the_brotherhood_of_scu.bugaoshan.channels

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.github.the_brotherhood_of_scu.bugaoshan.MainActivity
import io.github.the_brotherhood_of_scu.bugaoshan.widget.WidgetUpdater

/**
 * 处理应用图标动态切换(由 `bugaoshan/dynamic_icon` MethodChannel 调用)。
 *
 * 使用 [MainActivity] 自身的 class 名作为基类,避免 applicationId 后缀(如 .debug)
 * 导致的命名空间问题。切换流程:
 *  1. 启用目标组件(MainActivity 或 alias)—— DONT_KILL_APP
 *  2. 禁用其他非目标组件 —— DONT_KILL_APP,但跳过当前激活的(留到第 4 步处理)
 *  3. 刷新小组件
 *  4. 不带 DONT_KILL_APP 禁用旧激活组件,强制杀进程让 Launcher 刷新图标
 */
class DynamicIconHandler(private val context: Context) {

    companion object {
        private const val TAG = "DynamicIcon"
    }

    /**
     * 用 [MainActivity] 的 class 名作为基类,确保 namespace 正确(避免 .debug 后缀)。
     */
    private val iconBaseClass: String by lazy {
        MainActivity::class.java.name
    }

    /** 查询所有可用的 alternate icon 名称(从 activity-alias 组件中提取)。 */
    fun getAvailableIcons(): List<String> {
        val pm = context.packageManager
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
            setPackage(context.packageName)
        }
        val resolveInfos = pm.queryIntentActivities(intent, PackageManager.MATCH_DISABLED_COMPONENTS)
        val prefix = "$iconBaseClass."
        val icons = mutableListOf<String>()

        resolveInfos.forEach { resolveInfo ->
            val componentName = resolveInfo.activityInfo.name
            if (componentName == iconBaseClass) return@forEach // Skip the real MainActivity
            if (componentName.startsWith(prefix)) {
                val suffix = componentName.substring(prefix.length)
                if (suffix != "default") {
                    icons.add(suffix)
                }
            }
        }
        return icons
    }

    /** 返回当前激活的 alternate icon 名称,默认图标返回 null。 */
    fun getCurrentIcon(): String? {
        val pm = context.packageManager
        val mainCN = ComponentName(context.packageName, iconBaseClass)
        val mainState = pm.getComponentEnabledSetting(mainCN)
        if (mainState == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            || mainState == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
        ) {
            return null
        }
        // Check each alias
        for (iconName in getAvailableIcons()) {
            val aliasCN = ComponentName(context.packageName, "$iconBaseClass.$iconName")
            if (pm.getComponentEnabledSetting(aliasCN)
                == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            ) {
                return iconName
            }
        }
        return null
    }

    /** 应用图标切换:先启用目标,再禁用其他,刷新 widget,最后强制杀进程让 Launcher 刷新图标。 */
    fun setAlternateIcon(iconName: String?) {
        val pm = context.packageManager
        val mainCN = ComponentName(context.packageName, iconBaseClass)

        val currentIsMain = pm.getComponentEnabledSetting(mainCN) in arrayOf(
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT,
        )
        val currentAlias = if (currentIsMain) null else getCurrentIcon()
        val previousActiveCN = if (currentAlias != null)
            ComponentName(context.packageName, "$iconBaseClass.$currentAlias")
        else
            mainCN

        // Step 1: Enable target (DONT_KILL_APP)
        if (iconName.isNullOrEmpty()) {
            pm.setComponentEnabledSetting(
                mainCN,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP,
            )
        } else {
            val targetCN = ComponentName(context.packageName, "$iconBaseClass.$iconName")
            pm.setComponentEnabledSetting(
                targetCN,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP,
            )
        }

        // Step 2: Disable all OTHER components with DONT_KILL_APP,
        // skipping the previously-active one (will kill later in step 4).
        if (!iconName.isNullOrEmpty() && !currentIsMain) {
            pm.setComponentEnabledSetting(
                mainCN,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
        for (available in getAvailableIcons()) {
            if (available == iconName) continue // skip target
            if (available == currentAlias) continue // skip current active
            val aliasCN = ComponentName(context.packageName, "$iconBaseClass.$available")
            pm.setComponentEnabledSetting(
                aliasCN,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }

        // Step 3: Update widgets
        WidgetUpdater.updateAllWidgets(context)

        // Step 4: Disable the previously-active component WITHOUT DONT_KILL_APP,
        // forcing the system to kill our process so the launcher refreshes the icon.
        Handler(Looper.getMainLooper()).postDelayed({
            try {
                pm.setComponentEnabledSetting(
                    previousActiveCN,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    0, // No flag → kills process
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to disable previous component", e)
            }
        }, 300)
    }
}
