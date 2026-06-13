import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/scheme_score.dart';
import 'package:bugaoshan/providers/grades_provider.dart';
import 'package:bugaoshan/widgets/common/error_widgets.dart';
import 'package:bugaoshan/widgets/common/stat_item.dart';
import 'package:bugaoshan/utils/app_shapes.dart';
import 'scheme_scores_tab.dart' show ScoreCardWidget;

class CustomStatsTab extends StatefulWidget {
  const CustomStatsTab({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  State<CustomStatsTab> createState() => _CustomStatsTabState();
}

class _CustomStatsTabState extends State<CustomStatsTab> {
  final Set<String> _selectedKeys = {};
  String? _attrFilter;

  static String _itemKey(SchemeScoreItem item) =>
      '${item.courseName}|${item.academicYearCode}|${item.termName}|${item.courseAttributeName}';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: getIt<GradesProvider>(),
      builder: (context, _) {
        final provider = getIt<GradesProvider>();
        if (provider.schemeState == GradesLoadState.loaded &&
            provider.schemeError != null) {
          final errorKey = provider.schemeError;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            provider.clearSchemeError();
            if (!mounted) return;
            final l10n = AppLocalizations.of(context)!;
            final message = errorKey == 'sessionExpired'
                ? l10n.sessionExpired
                : l10n.gradesRefreshFailed;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          });
        }
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
            Icons.analytics_outlined,
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
    return RetryableErrorWidget(
      message: _getErrorMessage(l10n, provider.schemeError),
      onRetry: provider.refreshSchemeScores,
      iconSize: 56,
    );
  }

  String _getErrorMessage(AppLocalizations l10n, String? errorKey) {
    switch (errorKey) {
      case 'sessionExpired':
        return l10n.sessionExpired;
      case 'zhjwCampusNetworkRequiredAtNight':
        return l10n.zhjwCampusNetworkRequiredAtNight;
      case 'gradesLoadFailed':
        return l10n.gradesLoadFailed;
      default:
        return l10n.loadFailed;
    }
  }

  Widget _buildContent(BuildContext context, GradesProvider provider) {
    final summary = provider.schemeScores!;
    final query = widget.searchQuery.trim();
    final allGroups = summary.groupedByTerm;

    // Filter by search query and attribute filter
    final groups = allGroups
        .map((g) {
          var filtered = g.items.where((item) {
            final matchesSearch =
                query.isEmpty ||
                item.courseName.toLowerCase().contains(query.toLowerCase());
            final matchesAttr =
                _attrFilter == null || item.courseAttributeName == _attrFilter;
            return matchesSearch && matchesAttr;
          }).toList();
          return (label: g.label, items: filtered);
        })
        .where((g) => g.items.isNotEmpty)
        .toList();

    // Build selected items from ALL courses (not filtered)
    final selectedItems = <SchemeScoreItem>[];
    for (final group in allGroups) {
      for (final item in group.items) {
        if (_selectedKeys.contains(_itemKey(item))) {
          selectedItems.add(item);
        }
      }
    }

    // Visible keys for select-all (respects current filter)
    final visibleKeys = groups.expand((g) => g.items.map(_itemKey)).toSet();

    return CustomScrollView(
      slivers: [
        // 1. Quick-select chip bar
        SliverToBoxAdapter(child: _buildChipBar(context, visibleKeys)),
        // 2. Summary card (only when something is selected)
        if (selectedItems.isNotEmpty)
          SliverToBoxAdapter(
            child: _CustomSummaryCard(selectedItems: selectedItems),
          )
        else
          SliverToBoxAdapter(child: _buildEmptySelectionHint(context)),
        // 3. Term-grouped course list
        if (groups.isEmpty && query.isNotEmpty)
          SliverFillRemaining(
            child: Center(
              child: Text(
                AppLocalizations.of(context)!.gradesNoSearchResults,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else ...[
          for (final group in groups) ...[
            SliverToBoxAdapter(
              child: _TermSelectHeader(
                label: group.label,
                items: group.items,
                selectedKeys: _selectedKeys,
                itemKeyFn: _itemKey,
                onSelectAllInTerm: () => _selectAllInTerm(group.items, true),
                onDeselectAllInTerm: () => _selectAllInTerm(group.items, false),
              ),
            ),
            SliverList.builder(
              itemCount: group.items.length,
              itemBuilder: (context, i) {
                final item = group.items[i];
                final key = _itemKey(item);
                return ScoreCardWidget(
                  item: item,
                  selected: _selectedKeys.contains(key),
                  onTap: () => _toggleItem(key),
                );
              },
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ],
    );
  }

  // --- Chip bar ---

  Widget _buildChipBar(BuildContext context, Set<String> visibleKeys) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAttrChips(context),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _selectVisible(visibleKeys, true),
                  icon: const Icon(Icons.select_all, size: 18),
                  label: Text(l10n.selectAll),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _selectVisible(visibleKeys, false),
                  icon: const Icon(Icons.deselect, size: 18),
                  label: Text(l10n.deselectAll),
                ),
                const Spacer(),
                Text(
                  l10n.selectedCount(_selectedKeys.length),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttrChips(BuildContext context) {
    final attrs = ['必修', '选修', '任选'];
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: Text(AppLocalizations.of(context)!.trainProgramAll),
          selected: _attrFilter == null,
          onSelected: (_) => setState(() => _attrFilter = null),
        ),
        for (final attr in attrs)
          ChoiceChip(
            label: Text(attr),
            selected: _attrFilter == attr,
            onSelected: (selected) {
              setState(() => _attrFilter = selected ? attr : null);
            },
          ),
      ],
    );
  }

  // --- Selection helpers ---

  void _toggleItem(String key) {
    setState(() {
      if (_selectedKeys.contains(key)) {
        _selectedKeys.remove(key);
      } else {
        _selectedKeys.add(key);
      }
    });
  }

  void _selectAllInTerm(List<SchemeScoreItem> items, bool select) {
    setState(() {
      for (final item in items) {
        final key = _itemKey(item);
        if (select) {
          _selectedKeys.add(key);
        } else {
          _selectedKeys.remove(key);
        }
      }
    });
  }

  void _selectVisible(Set<String> visibleKeys, bool select) {
    setState(() {
      if (select) {
        _selectedKeys.addAll(visibleKeys);
      } else {
        _selectedKeys.removeAll(visibleKeys);
      }
    });
  }

  // --- Empty selection hint ---

  Widget _buildEmptySelectionHint(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            l10n.customStatsSelectHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// --- Term select header ---

class _TermSelectHeader extends StatelessWidget {
  const _TermSelectHeader({
    required this.label,
    required this.items,
    required this.selectedKeys,
    required this.itemKeyFn,
    required this.onSelectAllInTerm,
    required this.onDeselectAllInTerm,
  });

  final String label;
  final List<SchemeScoreItem> items;
  final Set<String> selectedKeys;
  final String Function(SchemeScoreItem) itemKeyFn;
  final VoidCallback onSelectAllInTerm;
  final VoidCallback onDeselectAllInTerm;

  @override
  Widget build(BuildContext context) {
    final keysInTerm = items.map(itemKeyFn).toSet();
    final selectedInTerm = selectedKeys.intersection(keysInTerm);
    final allSelected =
        selectedInTerm.length == keysInTerm.length && keysInTerm.isNotEmpty;
    final someSelected = selectedInTerm.isNotEmpty && !allSelected;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          InkWell(
            onTap: allSelected ? onDeselectAllInTerm : onSelectAllInTerm,
            borderRadius: BorderRadius.circular(AppShapes.xs),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    allSelected
                        ? Icons.check_box
                        : someSelected
                        ? Icons.indeterminate_check_box
                        : Icons.check_box_outline_blank,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${selectedInTerm.length}/${keysInTerm.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Custom summary card ---

class _CustomSummaryCard extends StatelessWidget {
  const _CustomSummaryCard({required this.selectedItems});

  final List<SchemeScoreItem> selectedItems;

  double get _gpa {
    double totalPoints = 0;
    double totalCredits = 0;
    for (final item in selectedItems) {
      final credit = double.tryParse(item.credit) ?? 0;
      if (credit > 0 && item.passed) {
        totalPoints += item.gradePointScore * credit;
        totalCredits += credit;
      }
    }
    return totalCredits > 0 ? totalPoints / totalCredits : 0.0;
  }

  double get _requiredGpa {
    double totalPoints = 0;
    double totalCredits = 0;
    for (final item in selectedItems) {
      if (!item.passed || item.courseAttributeName != '必修') continue;
      final credit = double.tryParse(item.credit) ?? 0;
      if (credit <= 0) continue;
      totalPoints += item.gradePointScore * credit;
      totalCredits += credit;
    }
    return totalCredits > 0 ? totalPoints / totalCredits : 0.0;
  }

  double get _weightedAvgScore {
    double totalScore = 0;
    double totalCredits = 0;
    for (final item in selectedItems) {
      if (!item.passed) continue;
      final credit = double.tryParse(item.credit) ?? 0;
      if (credit <= 0) continue;
      totalScore += item.courseScore * credit;
      totalCredits += credit;
    }
    return totalCredits > 0 ? totalScore / totalCredits : 0.0;
  }

  double get _requiredWeightedAvgScore {
    double totalScore = 0;
    double totalCredits = 0;
    for (final item in selectedItems) {
      if (!item.passed || item.courseAttributeName != '必修') continue;
      final credit = double.tryParse(item.credit) ?? 0;
      if (credit <= 0) continue;
      totalScore += item.courseScore * credit;
      totalCredits += credit;
    }
    return totalCredits > 0 ? totalScore / totalCredits : 0.0;
  }

  int get _passedCount => selectedItems.where((i) => i.passed).length;
  int get _failedCount => selectedItems.where((i) => !i.passed).length;

  double get _earnedCredits => selectedItems
      .where((i) => i.passed)
      .fold(0.0, (sum, i) => sum + (double.tryParse(i.credit) ?? 0));

  double _creditsByAttr(String attr) => selectedItems
      .where((i) => i.passed && i.courseAttributeName == attr)
      .fold(0.0, (sum, i) => sum + (double.tryParse(i.credit) ?? 0));

  double get _requiredCredits => _creditsByAttr('必修');
  double get _electiveCredits => _creditsByAttr('选修');
  double get _optionalCredits => _creditsByAttr('任选');

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
              l10n.customStats,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                StatItem(
                  label: l10n.gpa,
                  value: _gpa.toStringAsFixed(2),
                  highlight: true,
                ),
                StatItem(
                  label: l10n.requiredGpa,
                  value: _requiredGpa.toStringAsFixed(2),
                ),
                StatItem(label: l10n.passedCount, value: '$_passedCount'),
                StatItem(
                  label: l10n.failedCount,
                  value: '$_failedCount',
                  isError: _failedCount > 0,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                StatItem(
                  label: l10n.avgScore,
                  value: _weightedAvgScore.toStringAsFixed(2),
                ),
                StatItem(
                  label: l10n.requiredAvgScore,
                  value: _requiredWeightedAvgScore.toStringAsFixed(2),
                ),
                const Expanded(child: SizedBox()),
                const Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                StatItem(
                  label: l10n.earnedCredits,
                  value: _earnedCredits.toStringAsFixed(1),
                ),
                StatItem(
                  label: l10n.requiredCredits,
                  value: _requiredCredits.toStringAsFixed(1),
                ),
                StatItem(
                  label: l10n.electiveCredits,
                  value: _electiveCredits.toStringAsFixed(1),
                ),
                StatItem(
                  label: l10n.optionalCredits,
                  value: _optionalCredits.toStringAsFixed(1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
