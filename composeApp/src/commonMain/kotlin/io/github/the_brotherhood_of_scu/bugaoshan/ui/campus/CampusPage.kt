package io.github.the_brotherhood_of_scu.bugaoshan.ui.campus

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.github.the_brotherhood_of_scu.bugaoshan.api.BalanceResult
import io.github.the_brotherhood_of_scu.bugaoshan.api.NetworkDeviceResult
import io.github.the_brotherhood_of_scu.bugaoshan.api.TrainingProgramResult
import io.github.the_brotherhood_of_scu.bugaoshan.viewmodel.AuthViewModel
import io.github.the_brotherhood_of_scu.bugaoshan.viewmodel.CampusViewModel
import org.jetbrains.compose.resources.stringResource
import bugaoshan.composeapp.generated.resources.Res
import bugaoshan.composeapp.generated.resources.campus
import bugaoshan.composeapp.generated.resources.classroom_query
import bugaoshan.composeapp.generated.resources.classroom_query_desc
import bugaoshan.composeapp.generated.resources.grades_stats
import bugaoshan.composeapp.generated.resources.grades_stats_desc
import bugaoshan.composeapp.generated.resources.balance_query
import bugaoshan.composeapp.generated.resources.balance_query_desc
import bugaoshan.composeapp.generated.resources.network_device_query
import bugaoshan.composeapp.generated.resources.network_device_query_desc
import bugaoshan.composeapp.generated.resources.train_program
import bugaoshan.composeapp.generated.resources.train_program_desc
import bugaoshan.composeapp.generated.resources.cancel
import bugaoshan.composeapp.generated.resources.campus_network_required
import bugaoshan.composeapp.generated.resources.not_logged_in
import bugaoshan.composeapp.generated.resources.train_program_college

enum class CampusFeatureType {
    CLASSROOM, GRADES, BALANCE, NETWORK, TRAIN
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CampusPage(
    authViewModel: AuthViewModel,
    campusViewModel: CampusViewModel,
    modifier: Modifier = Modifier,
) {
    var selectedFeature by remember { mutableStateOf<CampusFeatureType?>(null) }
    val isLoggedIn by authViewModel.isLoggedIn.collectAsState()
    val token by authViewModel.accessToken.collectAsState()

    Column(modifier = modifier.fillMaxSize()) {
        TopAppBar(title = { Text(stringResource(Res.string.campus)) })

        LazyColumn(
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            item { CampusFeatureCard(stringResource(Res.string.classroom_query), stringResource(Res.string.classroom_query_desc), "\uD83C\uDFEB", onClick = { selectedFeature = CampusFeatureType.CLASSROOM }) }
            item { CampusFeatureCard(stringResource(Res.string.grades_stats), stringResource(Res.string.grades_stats_desc), "\uD83C\uDFC6", onClick = { selectedFeature = CampusFeatureType.GRADES }) }
            item { CampusFeatureCard(stringResource(Res.string.balance_query), stringResource(Res.string.balance_query_desc), "\u26A1", onClick = { selectedFeature = CampusFeatureType.BALANCE }) }
            item { CampusFeatureCard(stringResource(Res.string.network_device_query), stringResource(Res.string.network_device_query_desc), "\uD83D\uDCBB", onClick = { selectedFeature = CampusFeatureType.NETWORK }) }
            item { CampusFeatureCard(stringResource(Res.string.train_program), stringResource(Res.string.train_program_desc), "\uD83C\uDF93", onClick = { selectedFeature = CampusFeatureType.TRAIN }) }
        }
    }

    when (selectedFeature) {
        CampusFeatureType.CLASSROOM -> ClassroomQueryDialog(campusViewModel, token, isLoggedIn) { selectedFeature = null }
        CampusFeatureType.GRADES -> GradesDialog(campusViewModel, token, isLoggedIn) { selectedFeature = null }
        CampusFeatureType.BALANCE -> BalanceDialog(campusViewModel, token, isLoggedIn) { selectedFeature = null }
        CampusFeatureType.NETWORK -> NetworkDeviceDialog(campusViewModel, token, isLoggedIn) { selectedFeature = null }
        CampusFeatureType.TRAIN -> TrainProgramDialog(campusViewModel, token, isLoggedIn) { selectedFeature = null }
        null -> {}
    }
}

// ==================== Classroom Query ====================
@Composable
private fun ClassroomQueryDialog(vm: CampusViewModel, token: String, loggedIn: Boolean, onDismiss: () -> Unit) {
    val classrooms by vm.classrooms.collectAsState()
    val loading by vm.classroomLoading.collectAsState()
    val campuses by vm.campuses.collectAsState()

    var selectedCampus by remember { mutableStateOf("1") }
    var selectedDay by remember { mutableIntStateOf(1) }
    var selectedSection by remember { mutableIntStateOf(1) }
    var queried by remember { mutableStateOf(false) }

    LaunchedEffect(loggedIn) { if (loggedIn && token.isNotEmpty()) vm.loadCampuses(token) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(Res.string.classroom_query)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                if (!loggedIn) {
                    Text(stringResource(Res.string.not_logged_in), color = MaterialTheme.colorScheme.error)
                } else {
                    Text(stringResource(Res.string.campus_network_required), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)

                    Text("校区", style = MaterialTheme.typography.titleSmall)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        if (campuses.isNotEmpty()) {
                            campuses.forEach { c ->
                                FilterChip(selected = selectedCampus == c.number, onClick = { selectedCampus = c.number }, label = { Text(c.name) })
                            }
                        } else {
                            listOf("1" to "望江", "2" to "江安", "3" to "华西").forEach { (n, name) ->
                                FilterChip(selected = selectedCampus == n, onClick = { selectedCampus = n }, label = { Text(name) })
                            }
                        }
                    }

                    Text("星期", style = MaterialTheme.typography.titleSmall)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf(1 to "一", 2 to "二", 3 to "三", 4 to "四", 5 to "五", 6 to "六", 7 to "日").forEach { (d, name) ->
                            FilterChip(selected = selectedDay == d, onClick = { selectedDay = d }, label = { Text("周$name") })
                        }
                    }

                    Text("节次", style = MaterialTheme.typography.titleSmall)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        for (s in 1..12) {
                            FilterChip(selected = selectedSection == s, onClick = { selectedSection = s }, label = { Text("$s") })
                        }
                    }

                    HorizontalDivider()

                    if (loading) {
                        Box(modifier = Modifier.fillMaxWidth().height(80.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(modifier = Modifier.size(32.dp)) }
                    } else if (queried && classrooms.isEmpty()) {
                        Text("未查询到空闲教室", color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.fillMaxWidth().padding(16.dp), textAlign = TextAlign.Center)
                    } else if (queried) {
                        Text("空闲教室 (${classrooms.size})", style = MaterialTheme.typography.titleSmall)
                        classrooms.take(20).forEach { c ->
                            Row(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(c.name, fontWeight = FontWeight.Medium)
                                    if (c.remark.isNotEmpty()) Text(c.remark, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                Text("容纳${c.capacity}人", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary)
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            if (loggedIn) {
                TextButton(onClick = { vm.queryClassrooms(token, selectedCampus, "all", selectedDay, selectedSection); queried = true }, enabled = !loading) { Text("查询") }
            }
            TextButton(onClick = onDismiss) { Text(stringResource(Res.string.cancel)) }
        },
    )
}

// ==================== Grades ====================
@Composable
private fun GradesDialog(vm: CampusViewModel, token: String, loggedIn: Boolean, onDismiss: () -> Unit) {
    val loading by vm.gradeLoading.collectAsState()
    val grades by vm.grades.collectAsState()
    val error by vm.gradeError.collectAsState()
    var loaded by remember { mutableStateOf(false) }

    LaunchedEffect(loggedIn) { if (loggedIn && token.isNotEmpty() && !loaded) { vm.loadGrades(token); loaded = true } }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(Res.string.grades_stats)) },
        text = {
            Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                if (!loggedIn) {
                    Text(stringResource(Res.string.not_logged_in), color = MaterialTheme.colorScheme.error)
                } else if (loading) {
                    Box(modifier = Modifier.fillMaxWidth().height(80.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(modifier = Modifier.size(32.dp)) }
                } else if (error != null) {
                    Text(error!!, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                } else if (grades != null) {
                    val g = grades!!
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                        StatItem("GPA", String.format("%.2f", g.totalGpa))
                        StatItem("总学分", String.format("%.1f", g.totalCredits))
                        StatItem("均分", String.format("%.1f", g.averageScore))
                    }
                    HorizontalDivider()
                    Text("课程明细 (${g.courses.size}门)", style = MaterialTheme.typography.titleSmall)
                    g.courses.forEach { c ->
                        Row(modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(c.name, style = MaterialTheme.typography.bodyMedium, maxLines = 1)
                                Text("${c.courseType} | ${c.credit}学分 | GPA ${String.format("%.1f", c.gpa)}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Text(String.format("%.1f", c.score), style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold, color = if (c.score >= 60) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error)
                        }
                    }
                } else {
                    Text("点击查询按钮获取成绩数据", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        },
        confirmButton = {
            if (loggedIn) { TextButton(onClick = { vm.loadGrades(token); loaded = true }, enabled = !loading) { Text("查询") } }
            TextButton(onClick = onDismiss) { Text(stringResource(Res.string.cancel)) }
        },
    )
}

@Composable
private fun StatItem(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
        Text(label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

// ==================== Balance ====================
@Composable
private fun BalanceDialog(vm: CampusViewModel, token: String, loggedIn: Boolean, onDismiss: () -> Unit) {
    val loading by vm.balanceLoading.collectAsState()
    val result by vm.balanceResult.collectAsState()
    var building by remember { mutableStateOf("") }
    var room by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(Res.string.balance_query)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                if (!loggedIn) {
                    Text(stringResource(Res.string.not_logged_in), color = MaterialTheme.colorScheme.error)
                } else {
                    Text(stringResource(Res.string.campus_network_required), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    OutlinedTextField(building, { building = it }, label = { Text("楼栋") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                    OutlinedTextField(room, { room = it }, label = { Text("房间号") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                    HorizontalDivider()
                    if (loading) {
                        Box(modifier = Modifier.fillMaxWidth().height(60.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(modifier = Modifier.size(24.dp)) }
                    } else if (result is BalanceResult.Success) {
                        val b = result as BalanceResult.Success
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("￥${String.format("%.2f", b.electricityBalance)}", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                                Text("电费余额", style = MaterialTheme.typography.bodySmall)
                            }
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("￥${String.format("%.2f", b.acBalance)}", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.tertiary)
                                Text("空调余额", style = MaterialTheme.typography.bodySmall)
                            }
                        }
                    } else if (result is BalanceResult.Error) {
                        Text((result as BalanceResult.Error).message, color = MaterialTheme.colorScheme.error)
                    }
                }
            }
        },
        confirmButton = {
            if (loggedIn) { TextButton(onClick = { vm.queryBalance(token, building, room) }, enabled = !loading) { Text("查询") } }
            TextButton(onClick = onDismiss) { Text(stringResource(Res.string.cancel)) }
        },
    )
}

// ==================== Network Devices ====================
@Composable
private fun NetworkDeviceDialog(vm: CampusViewModel, token: String, loggedIn: Boolean, onDismiss: () -> Unit) {
    val loading by vm.networkLoading.collectAsState()
    val result by vm.networkResult.collectAsState()
    var loaded by remember { mutableStateOf(false) }

    LaunchedEffect(loggedIn) { if (loggedIn && token.isNotEmpty() && !loaded) { vm.loadOnlineDevices(token); loaded = true } }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(Res.string.network_device_query)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                if (!loggedIn) {
                    Text(stringResource(Res.string.not_logged_in), color = MaterialTheme.colorScheme.error)
                } else if (loading) {
                    Box(modifier = Modifier.fillMaxWidth().height(80.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(modifier = Modifier.size(32.dp)) }
                } else if (result is NetworkDeviceResult.Success) {
                    val n = result as NetworkDeviceResult.Success
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) { Text("账号"); Text(n.username, fontWeight = FontWeight.Bold) }
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) { Text("在线设备数"); Text("${n.onlineCount}", fontWeight = FontWeight.Bold) }
                    HorizontalDivider()
                    n.devices.forEach { d ->
                        Row(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(d.deviceName, fontWeight = FontWeight.Medium)
                                Text(d.ipAddress, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            TextButton(onClick = { vm.disconnectDevice(token, d.macAddress) { loaded = false } }) { Text("下线", color = MaterialTheme.colorScheme.error) }
                        }
                    }
                } else if (result is NetworkDeviceResult.Error) {
                    Text((result as NetworkDeviceResult.Error).message, color = MaterialTheme.colorScheme.error)
                } else {
                    Text("点击查询按钮获取在线设备", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        },
        confirmButton = {
            if (loggedIn) { TextButton(onClick = { vm.loadOnlineDevices(token); loaded = true }, enabled = !loading) { Text("查询") } }
            TextButton(onClick = onDismiss) { Text(stringResource(Res.string.cancel)) }
        },
    )
}

// ==================== Training Program ====================
@Composable
private fun TrainProgramDialog(vm: CampusViewModel, token: String, loggedIn: Boolean, onDismiss: () -> Unit) {
    val loading by vm.trainingLoading.collectAsState()
    val result by vm.trainingResult.collectAsState()
    val colleges by vm.colleges.collectAsState()
    var selectedCollege by remember { mutableStateOf("") }

    LaunchedEffect(loggedIn) { if (loggedIn && token.isNotEmpty()) vm.loadColleges(token) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(Res.string.train_program)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                if (!loggedIn) {
                    Text(stringResource(Res.string.not_logged_in), color = MaterialTheme.colorScheme.error)
                } else {
                    if (colleges.isNotEmpty()) {
                        Text(stringResource(Res.string.train_program_college), style = MaterialTheme.typography.titleSmall)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            colleges.take(6).forEach { c ->
                                FilterChip(selected = selectedCollege == c.id, onClick = { selectedCollege = c.id }, label = { Text(c.name) })
                            }
                        }
                    }
                    HorizontalDivider()
                    if (loading) {
                        Box(modifier = Modifier.fillMaxWidth().height(80.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(modifier = Modifier.size(32.dp)) }
                    } else if (result is TrainingProgramResult.Success) {
                        val t = result as TrainingProgramResult.Success
                        Text(t.programName, fontWeight = FontWeight.Bold)
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                            StatItem("总学分", String.format("%.1f", t.totalCredits))
                            StatItem("必修学分", String.format("%.1f", t.requiredCredits))
                            StatItem("课程数", "${t.courses.size}")
                        }
                        HorizontalDivider()
                        Text("课程列表", style = MaterialTheme.typography.titleSmall)
                        t.courses.forEach { c ->
                            Row(modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(c.name, style = MaterialTheme.typography.bodyMedium, maxLines = 1)
                                    Text("${c.courseType} | ${c.hours}学时 | ${if (c.required) "必修" else "选修"}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                Text("${c.credits}学分", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary)
                            }
                        }
                    } else if (result is TrainingProgramResult.Error) {
                        Text((result as TrainingProgramResult.Error).message, color = MaterialTheme.colorScheme.error)
                    } else {
                        Text("点击查询按钮获取培养方案", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        },
        confirmButton = {
            if (loggedIn) { TextButton(onClick = { vm.loadTrainingProgram(token, selectedCollege.ifEmpty { null }) }, enabled = !loading) { Text("查询") } }
            TextButton(onClick = onDismiss) { Text(stringResource(Res.string.cancel)) }
        },
    )
}

// ==================== Shared ====================
@Suppress("DEPRECATION")
@Composable
private fun CampusFeatureCard(title: String, desc: String, emoji: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Card(modifier = modifier.clickable(onClick = onClick)) {
        Row(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(emoji, style = MaterialTheme.typography.headlineMedium)
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.titleMedium)
                Text(desc, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Text("\u203A", style = MaterialTheme.typography.headlineSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
