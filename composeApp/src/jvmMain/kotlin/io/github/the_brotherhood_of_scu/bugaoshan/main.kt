package io.github.the_brotherhood_of_scu.bugaoshan

import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application

fun main() = application {
    Window(
        onCloseRequest = ::exitApplication,
        title = "Bugaoshan",
    ) {
        App()
    }
}