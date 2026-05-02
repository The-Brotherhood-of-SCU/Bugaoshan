package io.github.the_brotherhood_of_scu.bugaoshan.ui.home

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import io.github.the_brotherhood_of_scu.bugaoshan.ui.campus.CampusPage
import io.github.the_brotherhood_of_scu.bugaoshan.ui.course.CoursePage
import io.github.the_brotherhood_of_scu.bugaoshan.ui.profile.ProfilePage
import io.github.the_brotherhood_of_scu.bugaoshan.viewmodel.AppConfigViewModel
import io.github.the_brotherhood_of_scu.bugaoshan.viewmodel.AuthViewModel
import io.github.the_brotherhood_of_scu.bugaoshan.viewmodel.CourseViewModel
import org.jetbrains.compose.resources.stringResource
import bugaoshan.composeapp.generated.resources.Res
import bugaoshan.composeapp.generated.resources.course
import bugaoshan.composeapp.generated.resources.campus
import bugaoshan.composeapp.generated.resources.profile

enum class TabRoute {
    Course, Campus, Profile
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomePage(
    appConfigViewModel: AppConfigViewModel,
    authViewModel: AuthViewModel,
    courseViewModel: CourseViewModel,
) {
    var currentTab by remember { mutableStateOf(TabRoute.Course) }

    Scaffold(
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    icon = { Text("\uD83D\uDCC5") }, // Calendar emoji
                    label = { Text(stringResource(Res.string.course)) },
                    selected = currentTab == TabRoute.Course,
                    onClick = { currentTab = TabRoute.Course },
                )
                NavigationBarItem(
                    icon = { Text("\uD83C\uDFEB") }, // Building emoji
                    label = { Text(stringResource(Res.string.campus)) },
                    selected = currentTab == TabRoute.Campus,
                    onClick = { currentTab = TabRoute.Campus },
                )
                NavigationBarItem(
                    icon = { Text("\uD83D\uDC64") }, // Person emoji
                    label = { Text(stringResource(Res.string.profile)) },
                    selected = currentTab == TabRoute.Profile,
                    onClick = { currentTab = TabRoute.Profile },
                )
            }
        }
    ) { innerPadding ->
        when (currentTab) {
            TabRoute.Course -> CoursePage(
                courseViewModel = courseViewModel,
                modifier = Modifier.padding(innerPadding),
            )
            TabRoute.Campus -> CampusPage(
                modifier = Modifier.padding(innerPadding),
            )
            TabRoute.Profile -> ProfilePage(
                authViewModel = authViewModel,
                appConfigViewModel = appConfigViewModel,
                courseViewModel = courseViewModel,
                modifier = Modifier.padding(innerPadding),
            )
        }
    }
}
