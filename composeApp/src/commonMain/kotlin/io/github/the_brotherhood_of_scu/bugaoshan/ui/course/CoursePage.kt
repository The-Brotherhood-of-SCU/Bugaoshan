package io.github.the_brotherhood_of_scu.bugaoshan.ui.course

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import io.github.the_brotherhood_of_scu.bugaoshan.model.Course
import io.github.the_brotherhood_of_scu.bugaoshan.viewmodel.CourseViewModel
import org.jetbrains.compose.resources.stringResource
import bugaoshan.composeapp.generated.resources.Res
import bugaoshan.composeapp.generated.resources.no_course_this_week
import bugaoshan.composeapp.generated.resources.current_week

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CoursePage(
    courseViewModel: CourseViewModel,
    modifier: Modifier = Modifier,
) {
    val courses by courseViewModel.courses.collectAsState()
    val currentWeek by courseViewModel.currentWeek.collectAsState()
    val scheduleConfig by courseViewModel.scheduleConfig.collectAsState()
    val isLoading by courseViewModel.isLoading.collectAsState()

    Column(
        modifier = modifier.fillMaxSize(),
    ) {
        // Top bar with week selector
        TopAppBar(
            title = {
                Text(stringResource(Res.string.current_week, currentWeek))
            },
        )

        if (isLoading) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator()
            }
        } else {
            val activeCourses = courses.filter { it.isActiveInWeek(currentWeek) }

            if (activeCourses.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = stringResource(Res.string.no_course_this_week),
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            } else {
                // Course grid placeholder
                CourseGrid(
                    courses = activeCourses,
                    currentWeek = currentWeek,
                    scheduleConfig = scheduleConfig,
                    modifier = Modifier.fillMaxSize(),
                )
            }
        }
    }
}

@Composable
private fun CourseGrid(
    courses: List<Course>,
    currentWeek: Int,
    scheduleConfig: io.github.the_brotherhood_of_scu.bugaoshan.model.ScheduleConfig,
    modifier: Modifier = Modifier,
) {
    // Simple course list for now - will be replaced with proper grid
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(courses.size) { index ->
            CourseCard(
                course = courses[index],
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun CourseCard(
    course: Course,
    modifier: Modifier = Modifier,
) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = androidx.compose.ui.graphics.Color(course.colorValue),
        ),
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
        ) {
            Text(
                text = course.name,
                style = MaterialTheme.typography.titleMedium,
                color = androidx.compose.ui.graphics.Color.White,
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "${course.teacher} @ ${course.location}",
                style = MaterialTheme.typography.bodySmall,
                color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.8f),
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "第${course.startWeek}-${course.endWeek}周 | 第${course.startSection}-${course.endSection}节",
                style = MaterialTheme.typography.bodySmall,
                color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.8f),
            )
        }
    }
}
