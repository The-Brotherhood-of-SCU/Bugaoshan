package io.github.the_brotherhood_of_scu.bugaoshan.channels

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.net.Uri
import android.os.Build
import android.util.Log

/**
 * 判断「安装来源包」是否为 F-Droid 系客户端(由 `bugaoshan/update` MethodChannel 调用)。
 *
 * 不维护客户端包名名单,而是探测该包自身是否注册了 F-Droid 的「添加软件源」scheme
 * (`fdroidrepo` / `fdroidrepos`)：官方客户端、F-Droid Basic、Droid-ify、Neo Store
 * 以及各种 fork 都注册了其中之一,新客户端出现时无需更新名单。
 *
 * 探测对象是 **installer 包**,而不是「设备上是否装有 F-Droid 客户端」:
 * 从 GitHub Releases 安装、但手机里恰好装了 F-Droid 的用户,其 installer 是浏览器或
 * 文件管理器,不会命中,应用内更新照常可用。
 *
 * 任何异常或未知情况一律按「非 F-Droid」处理(fail-open):宁可让 F-Droid 用户多看到
 * 一次自更新入口,也不能让非 F-Droid 用户彻底失去更新能力。
 */
class FdroidInstallDetector(private val context: Context) {

    companion object {
        private const val TAG = "FdroidInstallDetector"

        /**
         * F-Droid 客户端注册的「添加软件源」scheme。
         *
         * 官方客户端只注册复数形式,部分第三方客户端单复数都有,所以两者都要探。
         */
        private val REPO_SCHEMES = listOf("fdroidrepo", "fdroidrepos")
    }

    /**
     * @param installerPackage `PackageManager` 记录的安装来源包名,可能为 null
     *   (`adb install`、文件管理器直装等场景)。
     * @return 该包是否注册了 F-Droid 的添加仓库 scheme。
     */
    fun isFdroidInstaller(installerPackage: String?): Boolean {
        if (installerPackage.isNullOrBlank()) return false
        return try {
            val packageManager = context.packageManager
            REPO_SCHEMES.any { scheme ->
                // setPackage 直接把查询限定到 installer 包本身，不用全局查完再比包名
                val probe = Intent(Intent.ACTION_VIEW, Uri.parse("$scheme://"))
                    .setPackage(installerPackage)
                queryHandlers(packageManager, probe).isNotEmpty()
            }
        } catch (e: Exception) {
            Log.w(TAG, "探测安装来源失败: $installerPackage", e)
            false
        }
    }

    /** `queryIntentActivities(Intent, Int)` 自 API 33 起废弃,按版本选新重载。 */
    @Suppress("DEPRECATION")
    private fun queryHandlers(
        packageManager: PackageManager,
        intent: Intent,
    ): List<ResolveInfo> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                intent,
                PackageManager.ResolveInfoFlags.of(0L),
            )
        } else {
            packageManager.queryIntentActivities(intent, 0)
        }
}
