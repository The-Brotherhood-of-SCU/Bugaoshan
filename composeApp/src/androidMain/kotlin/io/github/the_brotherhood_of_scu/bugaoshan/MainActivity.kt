package io.github.the_brotherhood_of_scu.bugaoshan

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import io.github.the_brotherhood_of_scu.bugaoshan.di.appModule
import io.github.the_brotherhood_of_scu.bugaoshan.di.viewModelModule
import io.github.the_brotherhood_of_scu.bugaoshan.platform.appContext
import io.koin.android.ext.koin.androidContext
import io.koin.android.ext.koin.androidLogger
import io.koin.core.context.startKoin

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)

        // Initialize app context for platform-specific code
        appContext = applicationContext

        // Initialize Koin
        startKoin {
            androidContext(this@MainActivity)
            androidLogger()
            modules(appModule, viewModelModule)
        }

        setContent {
            App()
        }
    }
}

@Preview
@Composable
fun AppAndroidPreview() {
    App()
}
