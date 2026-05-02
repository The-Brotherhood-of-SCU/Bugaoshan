package io.github.the_brotherhood_of_scu.bugaoshan.platform

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.jdbc.sqlite.JdbcSqliteDriver
import io.github.the_brotherhood_of_scu.bugaoshan.db.AppDatabase
import java.io.File

actual fun createSqlDriver(): SqlDriver {
    val appDir = File(System.getProperty("user.home"), ".bugaoshan")
    if (!appDir.exists()) {
        appDir.mkdirs()
    }
    val dbFile = File(appDir, "bugaoshan.db")
    val driver = JdbcSqliteDriver("jdbc:sqlite:${dbFile.absolutePath}")
    AppDatabase.Schema.create(driver)
    return driver
}
