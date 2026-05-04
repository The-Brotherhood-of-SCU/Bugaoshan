package io.github.the_brotherhood_of_scu.bugaoshan.ui.course

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.github.the_brotherhood_of_scu.bugaoshan.model.Course
import io.github.the_brotherhood_of_scu.bugaoshan.model.ScheduleConfig
import io.github.the_brotherhood_of_scu.bugaoshan.model.WeekType
import io.github.the_brotherhood_of_scu.bugaoshan.viewmodel.CourseViewModel
import org.jetbrains.compose.resources.stringResource
import bugaoshan.composeapp.generated.resources.Res
import bugaoshan.composeapp.generated.resources.current_week

private val DAY_NAMES = listOf("周一", "周二", "周三", "周四", "周五", "周六", "周日")
private val GRID_BORDER_COLOR = Color(0xFFE0E0E0)
private val HEADER_BACKGROUND = Color(0xFFF5F5F5)
private val TIME_COLUMN_WIDTH = 48.dp
private val COURSE_COLORS = listOf(
    0xFF4CAF50L, 0xFF2196F3L, 0xFFFF9800L, 0xFFE91E63L,
    0xFF9C27B0L, 0xFF00BCD4L, 0xFFFF5722L, 0xFF607D8BL,
)

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
    var showAddDialog by remember { mutableStateOf(false) }
    var editingCourse by remember { mutableStateOf<Course?>(null) }

    Column(modifier = modifier.fillMaxSize()) {
        // Top bar with week navigation
        TopAppBar(
            title = { },
            actions = {
                IconButton(onClick = { courseViewModel.updateCurrentWeek(currentWeek - 1) }) {
                    Text("<", fontSize = 20.sp, fontWeight = FontWeight.Bold)
                }
                Text(
                    text = stringResource(Res.string.current_week, currentWeek),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.padding(horizontal = 8.dp),
                )
                IconButton(onClick = { courseViewModel.updateCurrentWeek(currentWeek + 1) }) {
                    Text(">", fontSize = 20.sp, fontWeight = FontWeight.Bold)
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.surface),
        )

        // Animated loading/empty/content transition
        AnimatedContent(
            targetState = Triple(isLoading, courses, currentWeek),
            modifier = Modifier.weight(1f),
            transitionSpec = {
                fadeIn(tween(300)) togetherWith fadeOut(tween(200))
            },
            contentKey = { "${it.first}_${it.second.size}_${it.third}" },
            label = "courseContent",
        ) { (loading, courseList, week) ->
            if (loading) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            } else {
                val activeCourses = courseList.filter { it.isActiveInWeek(week) }

                if (activeCourses.isEmpty()) {
                    // Animated empty state
                    val infiniteTransition = rememberInfiniteTransition(label = "emptyAnim")
                    val floatOffset by infiniteTransition.animateFloat(
                        initialValue = 0f, targetValue = -12f,
                        animationSpec = infiniteRepeatable(tween(1500, easing = EaseInOutCubic), repeatMode = RepeatMode.Reverse),
                        label = "floatOffset",
                    )
                    val alpha by infiniteTransition.animateFloat(
                        initialValue = 0.4f, targetValue = 1f,
                        animationSpec = infiniteRepeatable(tween(1200, easing = EaseInOutCubic), repeatMode = RepeatMode.Reverse),
                        label = "emptyAlpha",
                    )

                    Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier.graphicsLayer { translationY = floatOffset; this.alpha = alpha },
                        ) {
                            Text("\uD83D\uDCC5", fontSize = 48.sp)
                            Spacer(modifier = Modifier.height(16.dp))
                            Text(
                                text = "第${week}周暂无课程",
                                style = MaterialTheme.typography.bodyLarge,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = "点击右下角 + 添加课程",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                } else {
                    CourseGrid(
                        courses = activeCourses,
                        scheduleConfig = scheduleConfig,
                        onCourseClick = { course ->
                            editingCourse = course
                            showAddDialog = true
                        },
                    )
                }
            }
        }
    }

    // FAB with scale + rotation animation
    val fabVisible by remember { derivedStateOf { !isLoading } }
    val fabScale by animateFloatAsState(
        targetValue = if (fabVisible) 1f else 0f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessLow),
        label = "fabScale",
    )
    val fabRotation by animateFloatAsState(
        targetValue = if (showAddDialog) 45f else 0f,
        animationSpec = tween(300, easing = FastOutSlowInEasing),
        label = "fabRotation",
    )

    Box(modifier = Modifier.fillMaxSize()) {
        FloatingActionButton(
            onClick = {
                editingCourse = null
                showAddDialog = true
            },
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(16.dp)
                .scale(fabScale)
                .graphicsLayer { rotationZ = fabRotation },
            containerColor = MaterialTheme.colorScheme.primary,
        ) {
            Text("+", color = Color.White, fontSize = 24.sp)
        }
    }

    // Animated dialog
    AnimatedVisibility(
        visible = showAddDialog,
        enter = fadeIn(tween(200)) + scaleIn(tween(300, easing = FastOutSlowInEasing), initialScale = 0.85f),
        exit = fadeOut(tween(150)) + scaleOut(tween(200), targetScale = 0.85f),
    ) {
        AddCourseDialog(
            existingCourse = editingCourse,
            scheduleConfig = scheduleConfig,
            onDismiss = { showAddDialog = false; editingCourse = null },
            onSave = { course ->
                if (editingCourse != null) courseViewModel.updateCourse(course)
                else courseViewModel.addCourse(course)
                showAddDialog = false; editingCourse = null
            },
            onDelete = { courseId ->
                courseViewModel.deleteCourse(courseId)
                showAddDialog = false; editingCourse = null
            },
        )
    }
}

@Composable
private fun CourseGrid(
    courses: List<Course>,
    scheduleConfig: ScheduleConfig,
    onCourseClick: (Course) -> Unit,
    modifier: Modifier = Modifier,
) {
    val sectionsPerDay = scheduleConfig.sectionsPerDay
    val scrollState = rememberScrollState()

    // Animate grid fade in
    var gridVisible by remember { mutableStateOf(false) }
    LaunchedEffect(courses) {
        gridVisible = false
        kotlinx.coroutines.delay(50)
        gridVisible = true
    }

    AnimatedVisibility(
        visible = gridVisible,
        modifier = modifier,
        enter = fadeIn(tween(400)) + slideInVertically(tween(400), initialOffsetY = { it / 30 }),
        exit = fadeOut(tween(200)),
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Day header row
            Row(
                modifier = Modifier.fillMaxWidth()
                    .background(HEADER_BACKGROUND)
                    .border(0.5.dp, GRID_BORDER_COLOR),
            ) {
                Box(
                    modifier = Modifier.width(TIME_COLUMN_WIDTH).height(36.dp)
                        .border(0.5.dp, GRID_BORDER_COLOR),
                    contentAlignment = Alignment.Center,
                ) {
                    Text("节", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                for (day in 1..7) {
                    // Animate header cells
                    val headerAlpha by animateFloatAsState(
                        targetValue = 1f,
                        animationSpec = tween(300, delayMillis = day * 30),
                        label = "headerAlpha$day",
                    )
                    Box(
                        modifier = Modifier.weight(1f).height(36.dp).border(0.5.dp, GRID_BORDER_COLOR)
                            .graphicsLayer { alpha = headerAlpha },
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(DAY_NAMES[day - 1], style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
                    }
                }
            }

            // Scrollable grid body
            Column(
                modifier = Modifier.fillMaxWidth().weight(1f).verticalScroll(scrollState),
            ) {
                for (section in 1..sectionsPerDay) {
                    Row(modifier = Modifier.fillMaxWidth().height(72.dp)) {
                        // Section number
                        Box(
                            modifier = Modifier.width(TIME_COLUMN_WIDTH).height(72.dp)
                                .border(0.5.dp, GRID_BORDER_COLOR).background(HEADER_BACKGROUND),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text("$section", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }

                        // Day cells
                        for (day in 1..7) {
                            val courseInCell = courses.find {
                                it.dayOfWeek == day && section in it.startSection..it.endSection
                            }

                            // Animated course cell appearance
                            var cellVisible by remember(courseInCell?.id) { mutableStateOf(false) }
                            LaunchedEffect(courseInCell?.id) {
                                cellVisible = false
                                kotlinx.coroutines.delay((day * 20 + section * 10).toLong())
                                cellVisible = true
                            }

                            Box(
                                modifier = Modifier.weight(1f).height(72.dp)
                                    .border(0.5.dp, GRID_BORDER_COLOR)
                                    .then(
                                        when {
                                            courseInCell != null && section == courseInCell.startSection ->
                                                Modifier.graphicsLayer {
                                                    scaleX = if (cellVisible) 1f else 0.8f
                                                    scaleY = if (cellVisible) 1f else 0.8f
                                                    alpha = if (cellVisible) 1f else 0f
                                                }.background(Color(courseInCell.colorValue).copy(alpha = 0.85f))
                                                    .clickable { onCourseClick(courseInCell) }
                                            courseInCell != null ->
                                                Modifier.background(Color(courseInCell.colorValue).copy(alpha = 0.85f))
                                            else -> Modifier
                                        }
                                    ),
                                contentAlignment = Alignment.Center,
                            ) {
                                if (courseInCell != null && section == courseInCell.startSection) {
                                    CourseCellContent(courseInCell, scheduleConfig.showTeacherName, scheduleConfig.showLocation)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CourseCellContent(course: Course, showTeacher: Boolean, showLocation: Boolean) {
    Column(modifier = Modifier.padding(2.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = course.name, fontSize = 10.sp, fontWeight = FontWeight.Bold,
            color = Color.White, maxLines = 2, overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center, lineHeight = 12.sp,
        )
        if (showTeacher && course.teacher.isNotEmpty()) {
            Text(
                text = course.teacher, fontSize = 8.sp,
                color = Color.White.copy(alpha = 0.85f), maxLines = 1,
                overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center,
            )
        }
        if (showLocation && course.location.isNotEmpty()) {
            Text(
                text = course.location, fontSize = 8.sp,
                color = Color.White.copy(alpha = 0.85f), maxLines = 1,
                overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center,
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AddCourseDialog(
    existingCourse: Course?,
    scheduleConfig: ScheduleConfig,
    onDismiss: () -> Unit,
    onSave: (Course) -> Unit,
    onDelete: (String) -> Unit,
) {
    val isEditing = existingCourse != null
    var name by remember { mutableStateOf(existingCourse?.name ?: "") }
    var teacher by remember { mutableStateOf(existingCourse?.teacher ?: "") }
    var location by remember { mutableStateOf(existingCourse?.location ?: "") }
    var dayOfWeek by remember { mutableIntStateOf(existingCourse?.dayOfWeek ?: 1) }
    var startSection by remember { mutableIntStateOf(existingCourse?.startSection ?: 1) }
    var endSection by remember { mutableIntStateOf(existingCourse?.endSection ?: 2) }
    var startWeek by remember { mutableIntStateOf(existingCourse?.startWeek ?: 1) }
    var endWeek by remember { mutableIntStateOf(existingCourse?.endWeek ?: scheduleConfig.totalWeeks) }
    var weekType by remember { mutableStateOf(existingCourse?.weekType ?: WeekType.EVERY) }
    var colorValue by remember { mutableLongStateOf(existingCourse?.colorValue ?: COURSE_COLORS[0]) }
    var showDeleteConfirm by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (isEditing) "编辑课程" else "添加课程") },
        text = {
            Column(modifier = Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("课程名称") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(value = teacher, onValueChange = { teacher = it }, label = { Text("教师") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(value = location, onValueChange = { location = it }, label = { Text("教室") }, singleLine = true, modifier = Modifier.fillMaxWidth())

                Text("星期", style = MaterialTheme.typography.bodyMedium)
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    for (day in 1..7) {
                        val selected = dayOfWeek == day
                        // Animated selection
                        val bgColor by animateColorAsState(
                            targetValue = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant,
                            animationSpec = tween(200),
                            label = "dayColor$day",
                        )
                        val textColor by animateColorAsState(
                            targetValue = if (selected) Color.White else MaterialTheme.colorScheme.onSurfaceVariant,
                            animationSpec = tween(200),
                            label = "dayTextColor$day",
                        )
                        val scale by animateFloatAsState(
                            targetValue = if (selected) 1.1f else 1f,
                            animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessMedium),
                            label = "dayScale$day",
                        )
                        Box(
                            modifier = Modifier.size(36.dp).scale(scale).clip(RoundedCornerShape(4.dp))
                                .background(bgColor)
                                .clickable { dayOfWeek = day },
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(DAY_NAMES[day - 1].removePrefix("周"), color = textColor, fontSize = 12.sp)
                        }
                    }
                }

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                    OutlinedTextField(value = startSection.toString(), onValueChange = { it.toIntOrNull()?.let { v -> startSection = v.coerceIn(1, scheduleConfig.sectionsPerDay) } }, label = { Text("开始节") }, singleLine = true, modifier = Modifier.weight(1f))
                    OutlinedTextField(value = endSection.toString(), onValueChange = { it.toIntOrNull()?.let { v -> endSection = v.coerceIn(1, scheduleConfig.sectionsPerDay) } }, label = { Text("结束节") }, singleLine = true, modifier = Modifier.weight(1f))
                }

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                    OutlinedTextField(value = startWeek.toString(), onValueChange = { it.toIntOrNull()?.let { v -> startWeek = v.coerceIn(1, scheduleConfig.totalWeeks) } }, label = { Text("开始周") }, singleLine = true, modifier = Modifier.weight(1f))
                    OutlinedTextField(value = endWeek.toString(), onValueChange = { it.toIntOrNull()?.let { v -> endWeek = v.coerceIn(1, scheduleConfig.totalWeeks) } }, label = { Text("结束周") }, singleLine = true, modifier = Modifier.weight(1f))
                }

                Text("周类型", style = MaterialTheme.typography.bodyMedium)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    WeekType.entries.forEach { type ->
                        FilterChip(
                            selected = weekType == type,
                            onClick = { weekType = type },
                            label = { Text(when (type) { WeekType.EVERY -> "每周"; WeekType.ODD -> "单周"; WeekType.EVEN -> "双周" }) },
                        )
                    }
                }

                Text("颜色", style = MaterialTheme.typography.bodyMedium)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    COURSE_COLORS.forEach { color ->
                        val selected = colorValue == color
                        val scale by animateFloatAsState(
                            targetValue = if (selected) 1.2f else 1f,
                            animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
                            label = "colorScale",
                        )
                        Box(
                            modifier = Modifier.size(32.dp).scale(scale).clip(RoundedCornerShape(4.dp))
                                .background(Color(color)).clickable { colorValue = color }
                                .then(if (selected) Modifier.border(2.dp, Color.White, RoundedCornerShape(4.dp)) else Modifier),
                        )
                    }
                }
            }
        },
        confirmButton = {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (isEditing) {
                    TextButton(onClick = { showDeleteConfirm = true }, colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)) { Text("删除") }
                }
                TextButton(onClick = onDismiss) { Text("取消") }
                TextButton(
                    onClick = {
                        if (name.isNotBlank()) {
                            onSave(Course(
                                id = existingCourse?.id ?: Course.generateId(),
                                name = name.trim(), teacher = teacher.trim(), location = location.trim(),
                                dayOfWeek = dayOfWeek, startSection = startSection, endSection = endSection,
                                startWeek = startWeek, endWeek = endWeek, weekType = weekType, colorValue = colorValue,
                            ))
                        }
                    },
                    enabled = name.isNotBlank(),
                ) { Text("保存") }
            }
        },
    )

    if (showDeleteConfirm && existingCourse != null) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text("确认删除") },
            text = { Text("确定要删除「${existingCourse.name}」吗？") },
            confirmButton = { TextButton(onClick = { onDelete(existingCourse.id) }, colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)) { Text("删除") } },
            dismissButton = { TextButton(onClick = { showDeleteConfirm = false }) { Text("取消") } },
        )
    }
}
