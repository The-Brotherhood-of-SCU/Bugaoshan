package io.github.the_brotherhood_of_scu.bugaoshan

import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import io.github.the_brotherhood_of_scu.bugaoshan.di.appModule
import io.github.the_brotherhood_of_scu.bugaoshan.di.viewModelModule
import org.koin.core.context.startKoin

fun main() {
    startKoin {
        modules(appModule, viewModelModule)
    }

    application {
        Window(
            onCloseRequest = ::exitApplication,
            title = "Bugaoshan",
        ) {
            App()
        }
    }
}
