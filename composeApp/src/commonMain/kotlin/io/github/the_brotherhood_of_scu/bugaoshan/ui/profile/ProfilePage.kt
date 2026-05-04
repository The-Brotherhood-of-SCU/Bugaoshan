package io.github.the_brotherhood_of_scu.bugaoshan.ui.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.github.the_brotherhood_of_scu.bugaoshan.APP_LINK
import io.github.the_brotherhood_of_scu.bugaoshan.ORG_LINK
import io.github.the_brotherhood_of_scu.bugaoshan.viewmodel.AppConfigViewModel
import io.github.the_brotherhood_of_scu.bugaoshan.viewmodel.AuthViewModel
import io.github.the_brotherhood_of_scu.bugaoshan.viewmodel.CourseViewModel
import org.jetbrains.compose.resources.stringResource
import bugaoshan.composeapp.generated.resources.Res
import bugaoshan.composeapp.generated.resources.profile
import bugaoshan.composeapp.generated.resources.scu_login
import bugaoshan.composeapp.generated.resources.logged_in
import bugaoshan.composeapp.generated.resources.not_logged_in
import bugaoshan.composeapp.generated.resources.logout
import bugaoshan.composeapp.generated.resources.software_setting
import bugaoshan.composeapp.generated.resources.about
import bugaoshan.composeapp.generated.resources.student_id
import bugaoshan.composeapp.generated.resources.password
import bugaoshan.composeapp.generated.resources.login_button
import bugaoshan.composeapp.generated.resources.cancel
import bugaoshan.composeapp.generated.resources.save
import bugaoshan.composeapp.generated.resources.reset_to_default
import bugaoshan.composeapp.generated.resources.theme_color
import bugaoshan.composeapp.generated.resources.show_teacher
import bugaoshan.composeapp.generated.resources.show_location
import bugaoshan.composeapp.generated.resources.show_weekend
import bugaoshan.composeapp.generated.resources.font_size
import bugaoshan.composeapp.generated.resources.color_opacity
import bugaoshan.composeapp.generated.resources.development_team
import bugaoshan.composeapp.generated.resources.project_repository
import bugaoshan.composeapp.generated.resources.app_description
import bugaoshan.composeapp.generated.resources.clear_all_data
import bugaoshan.composeapp.generated.resources.confirm_message
import bugaoshan.composeapp.generated.resources.confirm
import bugaoshan.composeapp.generated.resources.logout_confirm
import bugaoshan.composeapp.generated.resources.app_name_label
import bugaoshan.composeapp.generated.resources.version
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfilePage(
    authViewModel: AuthViewModel,
    appConfigViewModel: AppConfigViewModel,
    courseViewModel: CourseViewModel,
    modifier: Modifier = Modifier,
) {
    val isLoggedIn by authViewModel.isLoggedIn.collectAsState()
    val userRealName by authViewModel.userRealName.collectAsState()
    val userNumber by authViewModel.userNumber.collectAsState()

    var showLoginDialog by remember { mutableStateOf(false) }
    var showSettingsDialog by remember { mutableStateOf(false) }
    var showAboutDialog by remember { mutableStateOf(false) }
    var showClearDataDialog by remember { mutableStateOf(false) }
    var showLogoutConfirm by remember { mutableStateOf(false) }

    Column(
        modifier = modifier.fillMaxSize(),
    ) {
        TopAppBar(
            title = { Text(stringResource(Res.string.profile)) },
        )

        LazyColumn(
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            // User info card
            item {
                UserCard(
                    isLoggedIn = isLoggedIn,
                    realName = userRealName,
                    studentId = userNumber,
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            // SCU Login
            item {
                ProfileMenuItem(
                    title = stringResource(Res.string.scu_login),
                    emoji = "\uD83D\uDD10",
                    subtitle = if (isLoggedIn) stringResource(Res.string.logged_in) else stringResource(Res.string.not_logged_in),
                    onClick = { showLoginDialog = true },
                )
            }

            // Settings
            item {
                ProfileMenuItem(
                    title = stringResource(Res.string.software_setting),
                    emoji = "\u2699\uFE0F",
                    onClick = { showSettingsDialog = true },
                )
            }

            // About
            item {
                ProfileMenuItem(
                    title = stringResource(Res.string.about),
                    emoji = "\u2139\uFE0F",
                    onClick = { showAboutDialog = true },
                )
            }

            // Logout button
            if (isLoggedIn) {
                item {
                    Spacer(modifier = Modifier.height(16.dp))
                    OutlinedButton(
                        onClick = { showLogoutConfirm = true },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = MaterialTheme.colorScheme.error,
                        ),
                    ) {
                        Text("\uD83D\uDEAA")
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(stringResource(Res.string.logout))
                    }
                }
            }
        }
    }

    // Login Dialog
    if (showLoginDialog) {
        LoginDialog(
            authViewModel = authViewModel,
            onDismiss = { showLoginDialog = false },
        )
    }

    // Settings Dialog
    if (showSettingsDialog) {
        SettingsDialog(
            appConfigViewModel = appConfigViewModel,
            onDismiss = { showSettingsDialog = false },
        )
    }

    // About Dialog
    if (showAboutDialog) {
        AboutDialog(onDismiss = { showAboutDialog = false })
    }

    // Clear Data Confirmation
    if (showClearDataDialog) {
        AlertDialog(
            onDismissRequest = { showClearDataDialog = false },
            title = { Text(stringResource(Res.string.clear_all_data)) },
            text = { Text(stringResource(Res.string.confirm_message)) },
            confirmButton = {
                TextButton(onClick = {
                    courseViewModel.clearAllData()
                    showClearDataDialog = false
                }, colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)) {
                    Text(stringResource(Res.string.confirm))
                }
            },
            dismissButton = {
                TextButton(onClick = { showClearDataDialog = false }) {
                    Text(stringResource(Res.string.cancel))
                }
            },
        )
    }

    // Logout Confirmation
    if (showLogoutConfirm) {
        AlertDialog(
            onDismissRequest = { showLogoutConfirm = false },
            title = { Text(stringResource(Res.string.logout)) },
            text = { Text(stringResource(Res.string.logout_confirm)) },
            confirmButton = {
                TextButton(onClick = {
                    authViewModel.logout()
                    showLogoutConfirm = false
                }, colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)) {
                    Text(stringResource(Res.string.confirm))
                }
            },
            dismissButton = {
                TextButton(onClick = { showLogoutConfirm = false }) {
                    Text(stringResource(Res.string.cancel))
                }
            },
        )
    }
}

@Composable
private fun LoginDialog(
    authViewModel: AuthViewModel,
    onDismiss: () -> Unit,
) {
    val savedUsername by authViewModel.savedUsername.collectAsState()
    val savedPassword by authViewModel.savedPassword.collectAsState()
    val rememberPassword by authViewModel.rememberPassword.collectAsState()
    val isLoggingIn by authViewModel.isLoggingIn.collectAsState()
    val loginError by authViewModel.loginError.collectAsState()
    val isLoggedIn by authViewModel.isLoggedIn.collectAsState()

    var username by remember { mutableStateOf(savedUsername) }
    var password by remember { mutableStateOf(savedPassword) }
    var remember by remember { mutableStateOf(rememberPassword) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    // Dismiss dialog on successful login
    LaunchedEffect(isLoggedIn) {
        if (isLoggedIn) onDismiss()
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(Res.string.scu_login)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    text = "使用四川大学统一身份认证登录",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                OutlinedTextField(
                    value = username,
                    onValueChange = { username = it; errorMessage = null },
                    label = { Text(stringResource(Res.string.student_id)) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !isLoggingIn,
                )
                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it; errorMessage = null },
                    label = { Text(stringResource(Res.string.password)) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !isLoggingIn,
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Checkbox(
                        checked = remember,
                        onCheckedChange = { remember = it },
                        enabled = !isLoggingIn,
                    )
                    Text(
                        text = "记住密码",
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
                if (isLoggingIn) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        CircularProgressIndicator(modifier = Modifier.size(20.dp))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("正在登录...", style = MaterialTheme.typography.bodyMedium)
                    }
                }
                val displayError = errorMessage ?: loginError
                if (displayError != null) {
                    Text(
                        text = displayError,
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    if (username.isBlank()) {
                        errorMessage = "请输入学号"
                        return@TextButton
                    }
                    if (password.isBlank()) {
                        errorMessage = "请输入密码"
                        return@TextButton
                    }
                    authViewModel.login(username, password, remember)
                },
                enabled = !isLoggingIn,
            ) {
                Text(stringResource(Res.string.login_button))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(Res.string.cancel))
            }
        },
    )
}

@Composable
private fun SettingsDialog(
    appConfigViewModel: AppConfigViewModel,
    onDismiss: () -> Unit,
) {
    val themeColor by appConfigViewModel.themeColor.collectAsState()
    val showTeacher by appConfigViewModel.showTeacher.collectAsState()
    val showLocation by appConfigViewModel.showLocation.collectAsState()
    val showWeekend by appConfigViewModel.showWeekend.collectAsState()
    val fontSize by appConfigViewModel.fontSize.collectAsState()
    val colorOpacity by appConfigViewModel.colorOpacity.collectAsState()

    var selectedColor by remember { mutableStateOf(themeColor) }
    var localShowTeacher by remember { mutableStateOf(showTeacher) }
    var localShowLocation by remember { mutableStateOf(showLocation) }
    var localShowWeekend by remember { mutableStateOf(showWeekend) }
    var localFontSize by remember { mutableFloatStateOf(fontSize) }
    var localColorOpacity by remember { mutableFloatStateOf(colorOpacity) }

    val themeColors = listOf(
        0xFF2196F3L, 0xFF4CAF50L, 0xFFFF9800L, 0xFFE91E63L,
        0xFF9C27B0L, 0xFF00BCD4L, 0xFFFF5722L, 0xFF607D8BL,
    )

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(Res.string.software_setting)) },
        text = {
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                // Theme color
                Text(stringResource(Res.string.theme_color), style = MaterialTheme.typography.titleSmall)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    themeColors.forEach { color ->
                        Box(
                            modifier = Modifier.size(36.dp).clip(CircleShape)
                                .background(Color(color))
                                .then(if (selectedColor == color) Modifier.border(3.dp, MaterialTheme.colorScheme.outline, CircleShape) else Modifier)
                                .clickable { selectedColor = color },
                        )
                    }
                }

                HorizontalDivider()

                // Display settings
                Text("显示设置", style = MaterialTheme.typography.titleSmall)

                SettingSwitch(
                    title = stringResource(Res.string.show_teacher),
                    checked = localShowTeacher,
                    onCheckedChange = { localShowTeacher = it },
                )
                SettingSwitch(
                    title = stringResource(Res.string.show_location),
                    checked = localShowLocation,
                    onCheckedChange = { localShowLocation = it },
                )
                SettingSwitch(
                    title = stringResource(Res.string.show_weekend),
                    checked = localShowWeekend,
                    onCheckedChange = { localShowWeekend = it },
                )

                HorizontalDivider()

                // Font size
                Text("${stringResource(Res.string.font_size)}: ${localFontSize.toInt()}sp", style = MaterialTheme.typography.titleSmall)
                Slider(
                    value = localFontSize,
                    onValueChange = { localFontSize = it },
                    valueRange = 8f..20f,
                    steps = 11,
                )

                // Color opacity
                Text("${stringResource(Res.string.color_opacity)}: ${(localColorOpacity * 100).toInt()}%", style = MaterialTheme.typography.titleSmall)
                Slider(
                    value = localColorOpacity,
                    onValueChange = { localColorOpacity = it },
                    valueRange = 0.1f..1f,
                    steps = 8,
                )

                HorizontalDivider()

                // Reset
                TextButton(
                    onClick = {
                        appConfigViewModel.resetToDefaults()
                        onDismiss()
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(stringResource(Res.string.reset_to_default))
                }
            }
        },
        confirmButton = {
            TextButton(onClick = {
                appConfigViewModel.updateThemeColor(selectedColor)
                appConfigViewModel.updateShowTeacher(localShowTeacher)
                appConfigViewModel.updateShowLocation(localShowLocation)
                appConfigViewModel.updateShowWeekend(localShowWeekend)
                appConfigViewModel.updateFontSize(localFontSize)
                appConfigViewModel.updateColorOpacity(localColorOpacity)
                onDismiss()
            }) {
                Text(stringResource(Res.string.save))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(Res.string.cancel))
            }
        },
    )
}

@Composable
private fun SettingSwitch(
    title: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = MaterialTheme.typography.bodyLarge)
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Composable
private fun AboutDialog(onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(Res.string.about)) },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text("\uD83D\uDC68\u200D\uD83D\uDCBB", fontSize = 48.sp)
                Text(
                    text = "Bugaoshan",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    text = stringResource(Res.string.app_description),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )

                HorizontalDivider()

                // Info rows
                AboutInfoRow(label = stringResource(Res.string.app_name_label), value = "Bugaoshan")
                AboutInfoRow(label = stringResource(Res.string.version), value = "1.0.0")
                AboutInfoRow(label = stringResource(Res.string.development_team), value = "The Brotherhood of SCU")

                HorizontalDivider()

                // Links
                Text(
                    text = stringResource(Res.string.project_repository),
                    style = MaterialTheme.typography.titleSmall,
                    modifier = Modifier.fillMaxWidth(),
                )
                Text(
                    text = APP_LINK,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(Res.string.cancel))
            }
        },
    )
}

@Composable
private fun AboutInfoRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium,
        )
    }
}

@Composable
private fun UserCard(
    isLoggedIn: Boolean,
    realName: String,
    studentId: String,
    modifier: Modifier = Modifier,
) {
    @Suppress("DEPRECATION")
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer,
        ),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "\uD83D\uDC64",
                style = MaterialTheme.typography.displaySmall,
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = if (isLoggedIn && realName.isNotEmpty()) realName else stringResource(Res.string.not_logged_in),
                    style = MaterialTheme.typography.headlineSmall,
                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                )
                if (isLoggedIn && studentId.isNotEmpty()) {
                    Text(
                        text = studentId,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.7f),
                    )
                }
            }
        }
    }
}

@Suppress("DEPRECATION")
@Composable
private fun ProfileMenuItem(
    title: String,
    emoji: String,
    subtitle: String? = null,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Card(
        modifier = modifier.clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = emoji,
                style = MaterialTheme.typography.headlineSmall,
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.bodyLarge,
                )
                if (subtitle != null) {
                    Text(
                        text = subtitle,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            Text(
                text = "\u203A",
                style = MaterialTheme.typography.headlineSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
