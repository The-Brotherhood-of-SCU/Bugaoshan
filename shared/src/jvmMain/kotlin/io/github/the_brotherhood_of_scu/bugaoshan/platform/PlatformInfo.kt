package io.github.the_brotherhood_of_scu.bugaoshan.platform

actual fun getPlatformName(): String = "Desktop"

actual class PlatformContext

actual fun getAppVersion(): String {
    return try {
        val properties = java.util.Properties()
        val inputStream = object {}::class.java.getResourceAsStream("/app.properties")
        if (inputStream != null) {
            properties.load(inputStream)
            properties.getProperty("app.version", "1.0.0")
        } else {
            "1.0.0"
        }
    } catch (e: Exception) {
        "1.0.0"
    }
}

actual fun getAppName(): String {
    return try {
        val properties = java.util.Properties()
        val inputStream = object {}::class.java.getResourceAsStream("/app.properties")
        if (inputStream != null) {
            properties.load(inputStream)
            properties.getProperty("app.name", "Bugaoshan")
        } else {
            "Bugaoshan"
        }
    } catch (e: Exception) {
        "Bugaoshan"
    }
}
