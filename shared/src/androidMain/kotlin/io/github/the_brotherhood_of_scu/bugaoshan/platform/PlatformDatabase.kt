package io.github.the_brotherhood_of_scu.bugaoshan.platform

import android.content.Context
import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.android.AndroidSqliteDriver
import io.github.the_brotherhood_of_scu.bugaoshan.db.AppDatabase

lateinit var appContext: Context

actual fun createSqlDriver(): SqlDriver {
    return AndroidSqliteDriver(
        schema = AppDatabase.Schema,
        context = appContext,
        name = "bugaoshan.db",
    )
}
