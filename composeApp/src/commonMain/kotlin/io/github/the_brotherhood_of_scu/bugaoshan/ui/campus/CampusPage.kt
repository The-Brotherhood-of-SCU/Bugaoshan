package io.github.the_brotherhood_of_scu.bugaoshan.ui.campus

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.jetbrains.compose.resources.stringResource
import bugaoshan.composeapp.generated.resources.Res
import bugaoshan.composeapp.generated.resources.campus
import bugaoshan.composeapp.generated.resources.classroom_query
import bugaoshan.composeapp.generated.resources.classroom_query_desc
import bugaoshan.composeapp.generated.resources.grades_stats
import bugaoshan.composeapp.generated.resources.grades_stats_desc
import bugaoshan.composeapp.generated.resources.ccyl_title
import bugaoshan.composeapp.generated.resources.ccyl_desc
import bugaoshan.composeapp.generated.resources.balance_query
import bugaoshan.composeapp.generated.resources.balance_query_desc
import bugaoshan.composeapp.generated.resources.network_device_query
import bugaoshan.composeapp.generated.resources.network_device_query_desc
import bugaoshan.composeapp.generated.resources.train_program
import bugaoshan.composeapp.generated.resources.train_program_desc

data class CampusFeature(
    val titleRes: String,
    val descRes: String,
    val emoji: String,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CampusPage(
    modifier: Modifier = Modifier,
) {
    val features = remember {
        listOf(
            CampusFeature("classroom_query", "classroom_query_desc", "\uD83C\uDFEB"),
            CampusFeature("grades_stats", "grades_stats_desc", "\uD83C\uDFC6"),
            CampusFeature("ccyl_title", "ccyl_desc", "\uD83C\uDF89"),
            CampusFeature("balance_query", "balance_query_desc", "\u26A1"),
            CampusFeature("network_device_query", "network_device_query_desc", "\uD83D\uDCBB"),
            CampusFeature("train_program", "train_program_desc", "\uD83C\uDF93"),
        )
    }

    Column(
        modifier = modifier.fillMaxSize(),
    ) {
        TopAppBar(
            title = { Text(stringResource(Res.string.campus)) },
        )

        LazyColumn(
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(features.size) { index ->
                CampusFeatureCard(
                    feature = features[index],
                    title = stringResource(
                        when (features[index].titleRes) {
                            "classroom_query" -> Res.string.classroom_query
                            "grades_stats" -> Res.string.grades_stats
                            "ccyl_title" -> Res.string.ccyl_title
                            "balance_query" -> Res.string.balance_query
                            "network_device_query" -> Res.string.network_device_query
                            "train_program" -> Res.string.train_program
                            else -> Res.string.campus
                        }
                    ),
                    desc = stringResource(
                        when (features[index].descRes) {
                            "classroom_query_desc" -> Res.string.classroom_query_desc
                            "grades_stats_desc" -> Res.string.grades_stats_desc
                            "ccyl_desc" -> Res.string.ccyl_desc
                            "balance_query_desc" -> Res.string.balance_query_desc
                            "network_device_query_desc" -> Res.string.network_device_query_desc
                            "train_program_desc" -> Res.string.train_program_desc
                            else -> Res.string.campus
                        }
                    ),
                    onClick = { /* TODO: Navigate to feature */ },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

@Suppress("DEPRECATION")
@Composable
private fun CampusFeatureCard(
    feature: CampusFeature,
    title: String,
    desc: String,
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
                text = feature.emoji,
                style = MaterialTheme.typography.headlineMedium,
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                )
                Text(
                    text = desc,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Text(
                text = "\u203A",
                style = MaterialTheme.typography.headlineSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
