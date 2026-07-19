package io.github.the_brotherhood_of_scu.bugaoshan.channels

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File

/**
 * 处理 APK 安装(由 `bugaoshan/update` MethodChannel 的 `installApk` 调用)。
 *
 * 通过 FileProvider 暴露 APK 文件,启动系统 PackageInstaller。
 */
class ApkInstaller(private val context: Context) {

    /**
     * 启动 APK 安装意图。
     * 调用前需确保 [apkPath] 指向的文件存在且可被 FileProvider 访问(已在 file_paths.xml 中配置)。
     */
    fun installApk(apkPath: String) {
        val file = File(apkPath)
        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
            setDataAndType(uri, "application/vnd.android.package-archive")
        }
        context.startActivity(intent)
    }
}
