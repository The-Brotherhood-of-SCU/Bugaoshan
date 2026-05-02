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
import org.koin.core.context.startKoin
import org.koin.dsl.module

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)

        // Initialize app context for platform-specific code
        appContext = applicationContext

        // Initialize Koin with Android context module
        val androidModule = module {
            single { this@MainActivity }
        }
        startKoin {
            modules(appModule, viewModelModule, androidModule)
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
