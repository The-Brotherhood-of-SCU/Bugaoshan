import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/scheme_score.dart';
import 'package:bugaoshan/providers/grades_provider.dart';

class SchemeScoresTab extends StatelessWidget {
  const SchemeScoresTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: getIt<GradesProvider>(),
      builder: (context, _) {
        final provider = getIt<GradesProvider>();
        return switch (provider.schemeState) {
          GradesLoadState.idle => _buildEmpty(context, provider),
          GradesLoadState.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          GradesLoadState.error => _buildError(context, provider),
          GradesLoadState.loaded => _buildContent(context, provider),
        };
      },
    );
  }

  Widget _buildEmpty(BuildContext context, GradesProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.gradesNoData,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: provider.refreshSchemeScores,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.gradesGet),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, GradesProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _getErrorMessage(l10n, provider.schemeError),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: provider.refreshSchemeScores,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.gradesRetry),
            ),
          ],
        ),
      ),
    );
  }

  String _getErrorMessage(AppLocalizations l10n, String? errorKey) {
    switch (errorKey) {
      case 'sessionExpired':
        return l10n.sessionExpired;
      case 'gradesLoadFailed':
        return l10n.gradesLoadFailed;
      default:
        return l10n.loadFailed;
    }
  }

  Widget _buildContent(BuildContext context, GradesProvider provider) {
    final summary = provider.schemeScores!;
    final groups = summary.groupedByTerm;
    return RefreshIndicator(
      onRefresh: provider.refreshSchemeScores,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _SummaryCard(summary: summary)),
          for (final group in groups) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  group.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: group.items.length,
              itemBuilder: (context, i) =>
                  ScoreCardWidget(item: group.items[i]),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final SchemeScoreSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary.cjlx,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatItem(
                  label: l10n.gpa,
                  value: summary.gpa.toStringAsFixed(2),
                  highlight: true,
                ),
                _StatItem(
                  label: l10n.requiredGpa,
                  value: summary.requiredGpa.toStringAsFixed(2),
                ),
                _StatItem(label: l10n.passedCount, value: '${summary.tgms}'),
                _StatItem(
                  label: l10n.failedCount,
                  value: '${summary.wtgms}',
                  isError: summary.wtgms > 0,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatItem(
                  label: l10n.avgScore,
                  value: summary.weightedAvgScore.toStringAsFixed(2),
                ),
                _StatItem(
                  label: l10n.requiredAvgScore,
                  value: summary.requiredWeightedAvgScore.toStringAsFixed(2),
                ),
                const Expanded(child: SizedBox()),
                const Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatItem(
                  label: l10n.earnedCredits,
                  value: summary.earnedCredits.toStringAsFixed(1),
                ),
                _StatItem(
                  label: l10n.requiredCredits,
                  value: summary.requiredCredits.toStringAsFixed(1),
                ),
                _StatItem(
                  label: l10n.electiveCredits,
                  value: summary.electiveCredits.toStringAsFixed(1),
                ),
                _StatItem(
                  label: l10n.optionalCredits,
                  value: summary.optionalCredits.toStringAsFixed(1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    this.highlight = false,
    this.isError = false,
  });
  final String label;
  final String value;
  final bool highlight;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? Theme.of(context).colorScheme.error
        : highlight
        ? Theme.of(context).colorScheme.primary
        : null;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class ScoreCardWidget extends StatelessWidget {
  const ScoreCardWidget({super.key, required this.item});
  final SchemeScoreItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scoreColor = !item.passed
        ? Theme.of(context).colorScheme.error
        : item.courseScore >= 90
        ? Theme.of(context).colorScheme.primary
        : null;

    final attrColor = switch (item.courseAttributeName) {
      '必修' => Theme.of(context).colorScheme.primaryContainer,
      '选修' => Theme.of(context).colorScheme.secondaryContainer,
      _ => Theme.of(context).colorScheme.tertiaryContainer,
    };
    final attrTextColor = switch (item.courseAttributeName) {
      '必修' => Theme.of(context).colorScheme.onPrimaryContainer,
      '选修' => Theme.of(context).colorScheme.onSecondaryContainer,
      _ => Theme.of(context).colorScheme.onTertiaryContainer,
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.courseName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: attrColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.courseAttributeName,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: attrTextColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.creditUnit(item.credit),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.cj,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
                Text(
                  item.gradeName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
