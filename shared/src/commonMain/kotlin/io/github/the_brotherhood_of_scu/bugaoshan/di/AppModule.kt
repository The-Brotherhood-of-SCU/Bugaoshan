package io.github.the_brotherhood_of_scu.bugaoshan.di

import io.github.the_brotherhood_of_scu.bugaoshan.api.*
import io.github.the_brotherhood_of_scu.bugaoshan.db.AppDatabase
import io.github.the_brotherhood_of_scu.bugaoshan.db.DatabaseService
import io.github.the_brotherhood_of_scu.bugaoshan.platform.createSqlDriver
import io.ktor.client.HttpClient
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json
import org.koin.dsl.module

val appModule = module {
    single {
        Json {
            ignoreUnknownKeys = true
            isLenient = true
            prettyPrint = false
        }
    }

    single {
        HttpClient {
            install(ContentNegotiation) {
                json(get())
            }
        }
    }

    single {
        val driver = createSqlDriver()
        AppDatabase(driver)
    }

    single {
        DatabaseService(get())
    }

    // API Services
    single { AuthService(get()) }
    single { ClassroomApiService(get()) }
    single { GradeApiService(get()) }
    single { BalanceApiService(get()) }
    single { NetworkDeviceApiService(get()) }
    single { TrainingProgramApiService(get()) }
}
