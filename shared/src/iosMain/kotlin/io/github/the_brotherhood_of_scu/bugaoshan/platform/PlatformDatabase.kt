package io.github.the_brotherhood_of_scu.bugaoshan.platform

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.native.NativeSqliteDriver
import io.github.the_brotherhood_of_scu.bugaoshan.db.AppDatabase

actual fun createSqlDriver(): SqlDriver {
    return NativeSqliteDriver(
        schema = AppDatabase.Schema,
        name = "bugaoshan.db",
    )
}
