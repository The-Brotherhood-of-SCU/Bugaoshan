package io.github.the_brotherhood_of_scu.bugaoshan.ui.profile

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
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

            // Menu items
            item {
                ProfileMenuItem(
                    title = stringResource(Res.string.scu_login),
                    emoji = "\uD83D\uDD10",
                    subtitle = if (isLoggedIn) stringResource(Res.string.logged_in) else stringResource(Res.string.not_logged_in),
                    onClick = { /* TODO: Navigate to login */ },
                )
            }

            item {
                ProfileMenuItem(
                    title = stringResource(Res.string.software_setting),
                    emoji = "\u2699\uFE0F",
                    onClick = { /* TODO: Navigate to settings */ },
                )
            }

            item {
                ProfileMenuItem(
                    title = stringResource(Res.string.about),
                    emoji = "\u2139\uFE0F",
                    onClick = { /* TODO: Navigate to about */ },
                )
            }

            // Logout button
            if (isLoggedIn) {
                item {
                    Spacer(modifier = Modifier.height(16.dp))
                    OutlinedButton(
                        onClick = { authViewModel.logout() },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = MaterialTheme.colorScheme.error,
                        ),
                    ) {
                        Text("\uD83D\uDEAA") // Door emoji
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(stringResource(Res.string.logout))
                    }
                }
            }
        }
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
