package io.github.the_brotherhood_of_scu.bugaoshan.ui.home

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import io.github.the_brotherhood_of_scu.bugaoshan.ui.campus.CampusPage
import io.github.the_brotherhood_of_scu.bugaoshan.ui.course.CoursePage
import io.github.the_brotherhood_of_scu.bugaoshan.ui.profile.ProfilePage
import io.github.the_brotherhood_of_scu.bugaoshan.viewmodel.AppConfigViewModel
import io.github.the_brotherhood_of_scu.bugaoshan.viewmodel.AuthViewModel
import io.github.the_brotherhood_of_scu.bugaoshan.viewmodel.CampusViewModel
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
    campusViewModel: CampusViewModel,
) {
    var currentTab by remember { mutableStateOf(TabRoute.Course) }

    Scaffold(
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    icon = {
                        // Animated emoji scale on selection
                        val scale by animateFloatAsState(
                            targetValue = if (currentTab == TabRoute.Course) 1.2f else 1f,
                            animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessLow),
                            label = "iconScale"
                        )
                        Text("\uD83D\uDCC5", modifier = Modifier.graphicsLayer { scaleX = scale; scaleY = scale })
                    },
                    label = { Text(stringResource(Res.string.course)) },
                    selected = currentTab == TabRoute.Course,
                    onClick = { currentTab = TabRoute.Course },
                )
                NavigationBarItem(
                    icon = {
                        val scale by animateFloatAsState(
                            targetValue = if (currentTab == TabRoute.Campus) 1.2f else 1f,
                            animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessLow),
                            label = "iconScale"
                        )
                        Text("\uD83C\uDFEB", modifier = Modifier.graphicsLayer { scaleX = scale; scaleY = scale })
                    },
                    label = { Text(stringResource(Res.string.campus)) },
                    selected = currentTab == TabRoute.Campus,
                    onClick = { currentTab = TabRoute.Campus },
                )
                NavigationBarItem(
                    icon = {
                        val scale by animateFloatAsState(
                            targetValue = if (currentTab == TabRoute.Profile) 1.2f else 1f,
                            animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessLow),
                            label = "iconScale"
                        )
                        Text("\uD83D\uDC64", modifier = Modifier.graphicsLayer { scaleX = scale; scaleY = scale })
                    },
                    label = { Text(stringResource(Res.string.profile)) },
                    selected = currentTab == TabRoute.Profile,
                    onClick = { currentTab = TabRoute.Profile },
                )
            }
        }
    ) { innerPadding ->
        // AnimatedContent for smooth crossfade between tabs
        AnimatedContent(
            targetState = currentTab,
            modifier = Modifier.padding(innerPadding),
            transitionSpec = {
                fadeIn(animationSpec = tween(300)) + slideInVertically(
                    animationSpec = tween(300),
                    initialOffsetY = { it / 20 }
                ) togetherWith fadeOut(animationSpec = tween(200))
            },
            contentKey = { it },
            label = "tabContent",
        ) { tab ->
            when (tab) {
                TabRoute.Course -> CoursePage(
                    courseViewModel = courseViewModel,
                )
                TabRoute.Campus -> CampusPage(
                    authViewModel = authViewModel,
                    campusViewModel = campusViewModel,
                )
                TabRoute.Profile -> ProfilePage(
                    authViewModel = authViewModel,
                    appConfigViewModel = appConfigViewModel,
                    courseViewModel = courseViewModel,
                )
            }
        }
    }
}
