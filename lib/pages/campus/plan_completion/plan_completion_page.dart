import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/plan_completion/models/plan_completion.dart';
import 'package:bugaoshan/pages/campus/plan_completion/plan_completion_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/error_widgets.dart';

class PlanCompletionPage extends StatefulWidget {
  const PlanCompletionPage({super.key});

  @override
  State<PlanCompletionPage> createState() => _PlanCompletionPageState();
}

class _PlanCompletionPageState extends State<PlanCompletionPage> {
  late final PlanCompletionProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = getIt<PlanCompletionProvider>();
    _provider.addListener(_onProviderUpdate);
    _provider.fetchPlanCompletion();
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderUpdate);
    super.dispose();
  }

  void _onProviderUpdate() {
    if (_provider.error == 'rateLimited' && mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.planCompletionRateLimited),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.planCompletion),
        actions: [
          ListenableBuilder(
            listenable: _provider,
            builder: (context, _) {
              return IconButton(
                icon: _provider.state == PlanCompletionLoadState.loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: _provider.state == PlanCompletionLoadState.loading
                    ? null
                    : () => _provider.fetchPlanCompletion(forceRefresh: true),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([getIt<ScuAuthProvider>(), _provider]),
        builder: (context, _) {
          final auth = getIt<ScuAuthProvider>();
          if (!auth.isLoggedIn) {
            if (auth.isAutoLoggingIn) {
              return const AutoLoginLoadingWidget();
            }
            return const LoginRequiredWidget();
          }
          return _buildContent(context);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return switch (_provider.state) {
      PlanCompletionLoadState.idle || PlanCompletionLoadState.loading =>
        const Center(child: CircularProgressIndicator()),
      PlanCompletionLoadState.error => RetryableErrorWidget(
        message: _provider.error == 'rateLimited'
            ? l10n.planCompletionRateLimited
            : _provider.error ?? l10n.loadFailed,
        onRetry: () => _provider.fetchPlanCompletion(),
        iconSize: 56,
      ),
      PlanCompletionLoadState.loaded => _buildTree(context),
    };
  }

  Widget _buildTree(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rootNodes = _provider.rootNodes;

    if (rootNodes.isEmpty) {
      return Center(
        child: Text(
          l10n.planCompletionNoData,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Build summary card
    final categoryNodes = _provider.nodes.where((n) => n.isCategory).toList();
    final totalEarned = categoryNodes.fold<double>(
      0,
      (sum, n) => sum + (double.tryParse(n.earnedCredits) ?? 0),
    );
    final completedCount = categoryNodes.where((n) => n.completed).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCard(
          context,
          l10n,
          totalEarned,
          completedCount,
          categoryNodes.length,
        ),
        const SizedBox(height: 16),
        ...rootNodes.map((node) => _buildCategoryTile(context, node, 0)),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    AppLocalizations l10n,
    double totalEarned,
    int completedCount,
    int totalCount,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              context,
              l10n.planCompletionTotalEarned,
              totalEarned.toStringAsFixed(1),
            ),
            _buildStatItem(
              context,
              l10n.planCompletionCompleted,
              '$completedCount/$totalCount',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTile(
    BuildContext context,
    PlanCompletionNode node,
    int depth,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final children = _provider.getChildren(node.id);

    if (children.isEmpty && !node.isCourse) {
      return const SizedBox.shrink();
    }

    // If this is a leaf category with no children, skip
    if (node.isCourse) {
      return _buildCourseTile(context, node, depth);
    }

    final earned = double.tryParse(node.earnedCredits) ?? 0;
    final required = double.tryParse(node.requiredCredits) ?? 0;
    final progress = required > 0 ? (earned / required).clamp(0.0, 1.0) : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(
          node.completed ? Icons.check_circle : Icons.radio_button_unchecked,
          color: node.completed
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
          size: 22,
        ),
        title: Text(
          _extractCategoryDisplayName(node.name),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${l10n.planCompletionCredits}: ${node.earnedCredits}/${node.requiredCredits}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (node.name.contains('已修课程门数')) ...[
                  const SizedBox(width: 12),
                  Text(
                    _extractCourseCountInfo(node.name, l10n),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
        children: children
            .map((child) => _buildCategoryTile(context, child, depth + 1))
            .toList(),
      ),
    );
  }

  String _extractCategoryDisplayName(String name) {
    // Remove parenthesized info: 公共基础课(最低修读学分:25,...) -> 公共基础课
    final idx = name.indexOf('(');
    return idx > 0 ? name.substring(0, idx).trim() : name;
  }

  String _extractCourseCountInfo(String name, AppLocalizations l10n) {
    // Extract: 已及格课程门数:17,必修课未修读:3
    final passedMatch = RegExp(r'已及格课程门数:(\d+)').firstMatch(name);
    final uncompletedMatch = RegExp(r'必修课未修读:(\d+)').firstMatch(name);
    if (passedMatch != null) {
      final passed = int.parse(passedMatch.group(1)!);
      final uncompleted = uncompletedMatch != null
          ? int.parse(uncompletedMatch.group(1)!)
          : 0;
      final total = passed + uncompleted;
      return '${l10n.planCompletionCourses}: $passed/$total';
    }
    return '';
  }

  Widget _buildCourseTile(
    BuildContext context,
    PlanCompletionNode node,
    int depth,
  ) {
    final hasGrade = node.gradeInfo.isNotEmpty;
    String gradeDisplay = '';
    if (hasGrade) {
      // Parse: (必修,96.0(20240107)) -> 96.0
      final gradeMatch = RegExp(r',([\d.]+)\(').firstMatch(node.gradeInfo);
      if (gradeMatch != null) {
        gradeDisplay = gradeMatch.group(1)!;
      }
    }

    final isPassed = RegExp(r'fa-smile-o.*green').hasMatch(node.rawName);

    return Padding(
      padding: EdgeInsets.only(left: 16.0 * depth),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(
          isPassed ? Icons.check_circle_outline : Icons.circle_outlined,
          size: 18,
          color: isPassed
              ? Theme.of(context).colorScheme.primary
              : Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        title: Text(
          node.courseName.isNotEmpty
              ? node.courseName
              : _extractCategoryDisplayName(node.name),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (node.courseCode.isNotEmpty) ...[
                  Text(
                    node.courseCode,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (node.courseCredits.isNotEmpty)
                  Text(
                    '${node.courseCredits}${AppLocalizations.of(context)!.planCompletionCreditsUnit}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (node.academicTerm.isNotEmpty)
              Text(
                node.academicTerm,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        trailing: gradeDisplay.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPassed
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  gradeDisplay,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isPassed
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
