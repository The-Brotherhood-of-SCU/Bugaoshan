import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/scheme_score.dart';
import 'package:bugaoshan/providers/grades_provider.dart';
import 'scheme_scores_tab.dart' show ScoreCardWidget;

class PassingScoresTab extends StatelessWidget {
  const PassingScoresTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: getIt<GradesProvider>(),
      builder: (context, _) {
        final provider = getIt<GradesProvider>();
        return switch (provider.passingState) {
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
            Icons.check_circle_outline,
            size: 56,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.gradesNoPassingData,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: provider.refreshPassingScores,
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
              provider.passingError ?? l10n.loadFailed,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: provider.refreshPassingScores,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.gradesRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, GradesProvider provider) {
    final result = provider.passingScores!;
    return RefreshIndicator(
      onRefresh: provider.refreshPassingScores,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _OverallSummaryCard(result: result)),
          for (final group in result.groups) ...[
            SliverToBoxAdapter(child: _TermHeader(group: group)),
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

class _OverallSummaryCard extends StatelessWidget {
  const _OverallSummaryCard({required this.result});
  final PassingScoreResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _StatCol(
                  label: l10n.overallGpa,
                  value: result.gpa.toStringAsFixed(2),
                  highlight: true,
                ),
                _StatCol(
                  label: l10n.accumulatedCredits,
                  value: result.totalCredits.toStringAsFixed(1),
                ),
                _StatCol(
                  label: l10n.totalPassedCount,
                  value: '${result.totalPassed}',
                ),
                _StatCol(
                  label: l10n.termCount,
                  value: '${result.groups.length}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatCol(
                  label: l10n.avgScore,
                  value: result.weightedAvgScore.toStringAsFixed(2),
                ),
                _StatCol(
                  label: l10n.requiredAvgScore,
                  value: result.requiredWeightedAvgScore.toStringAsFixed(2),
                ),
                const Expanded(child: SizedBox()),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  const _StatCol({
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: highlight ? Theme.of(context).colorScheme.primary : null,
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

class _TermHeader extends StatelessWidget {
  const _TermHeader({required this.group});
  final PassingScoreGroup group;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              group.label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            l10n.termPassedSummary(group.tgms, group.yxxf.toStringAsFixed(1)),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
