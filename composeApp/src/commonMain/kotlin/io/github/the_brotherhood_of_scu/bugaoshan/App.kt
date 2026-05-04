package io.github.the_brotherhood_of_scu.bugaoshan

import androidx.compose.runtime.*
import io.github.the_brotherhood_of_scu.bugaoshan.ui.home.HomePage
import io.github.the_brotherhood_of_scu.bugaoshan.ui.theme.BugaoshanTheme
import io.github.the_brotherhood_of_scu.bugaoshan.viewmodel.AppConfigViewModel
import io.github.the_brotherhood_of_scu.bugaoshan.viewmodel.AuthViewModel
import io.github.the_brotherhood_of_scu.bugaoshan.viewmodel.CampusViewModel
import io.github.the_brotherhood_of_scu.bugaoshan.viewmodel.CourseViewModel
import org.koin.compose.viewmodel.koinViewModel

@Composable
fun App(
    appConfigViewModel: AppConfigViewModel = koinViewModel(),
    authViewModel: AuthViewModel = koinViewModel(),
    courseViewModel: CourseViewModel = koinViewModel(),
    campusViewModel: CampusViewModel = koinViewModel(),
) {
    val themeColor by appConfigViewModel.themeColor.collectAsState()

    BugaoshanTheme(
        themeColor = themeColor,
        isDarkTheme = false,
    ) {
        HomePage(
            appConfigViewModel = appConfigViewModel,
            authViewModel = authViewModel,
            courseViewModel = courseViewModel,
            campusViewModel = campusViewModel,
        )
    }
}
