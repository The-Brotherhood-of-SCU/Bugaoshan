import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/plan_completion/models/plan_completion.dart';
import 'package:bugaoshan/providers/plan_completion_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:bugaoshan/theme_shape.dart';

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
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    // 有缓存时刷新失败，provider 保留旧数据并置 state=loaded、error≠null；
    // 若不提示，用户无法得知看到的是过期缓存（与成绩页保持一致）。
    if (_provider.state == PlanCompletionLoadState.loaded &&
        _provider.error != null) {
      final message = switch (_provider.error!) {
        LoadErrorType.rateLimited => l10n.planCompletionRateLimited,
        LoadErrorType.sessionExpired => l10n.sessionExpired,
        _ => l10n.gradesRefreshFailed,
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
      return;
    }

    if (_provider.error == LoadErrorType.rateLimited) {
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
    return switch (_provider.state) {
      PlanCompletionLoadState.idle || PlanCompletionLoadState.loading =>
        const Center(child: CircularProgressIndicator()),
      PlanCompletionLoadState.error => RetryableErrorWidget(
        errorType: _provider.error!,
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
    final stats = computeSummaryStats(_provider.nodes);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCard(
          context,
          l10n,
          stats.totalEarned,
          stats.completedCount,
          stats.moduleCount,
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
    return StyledCard(
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

    // 无子节点的模块（如美育、创新创业教育、跨学科专业教育）以列表项形式展示，
    // 与教务处方案层级保持一致。
    if (children.isEmpty && !node.isCourse) {
      return _buildLeafModuleTile(context, node, depth);
    }

    if (node.isCourse) {
      return _buildCourseTile(context, node, depth);
    }

    final earned = double.tryParse(node.earnedCredits) ?? 0;
    final required = double.tryParse(node.requiredCredits) ?? 0;
    final progress = required > 0 ? (earned / required).clamp(0.0, 1.0) : 0.0;

    return StyledCard(
      margin: const EdgeInsets.only(bottom: 8),
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
              borderRadius: BorderRadius.circular(AppShapes.xs),
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

  Widget _buildLeafModuleTile(
    BuildContext context,
    PlanCompletionNode node,
    int depth,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final earned = double.tryParse(node.earnedCredits) ?? 0;
    final required = double.tryParse(node.requiredCredits) ?? 0;
    final theme = Theme.of(context);

    return StyledCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              node.completed
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: node.completed
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _extractCategoryDisplayName(node.name),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.planCompletionCredits}: ${node.earnedCredits}/${node.requiredCredits}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 64,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppShapes.xs),
                child: LinearProgressIndicator(
                  value: required > 0
                      ? (earned / required).clamp(0.0, 1.0)
                      : 0.0,
                  minHeight: 4,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                  Flexible(
                    child: Text(
                      node.courseCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (node.courseCredits.isNotEmpty)
                  Flexible(
                    child: Text(
                      '${node.courseCredits}${AppLocalizations.of(context)!.planCompletionCreditsUnit}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
                  borderRadius: BorderRadius.circular(AppShapes.xs),
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

/// 摘要卡的统计结果。
class PlanCompletionSummaryStats {
  final double totalEarned;
  final int completedCount;
  final int moduleCount;

  const PlanCompletionSummaryStats({
    required this.totalEarned,
    required this.completedCount,
    required this.moduleCount,
  });
}

/// 计算摘要卡的统计值。
///
/// 统计根级模块（pId == '-1'）的完成情况，与教务处方案层级一致。
/// 根级模块包括 '001' 大类（如公共基础课、学科基础课）和 '002' 课程组
/// （如选择性思政、通用英语等），不含子层的必修/选修/限选分类节点。
/// 已获学分取各根级模块自身的 yxxf 之和。
PlanCompletionSummaryStats computeSummaryStats(List<PlanCompletionNode> nodes) {
  final rootModuleNodes = nodes
      .where((n) => n.pId == '-1' && (n.isCategory || n.isSubCategory))
      .toList();
  final totalEarned = rootModuleNodes.fold<double>(
    0,
    (sum, n) => sum + (double.tryParse(n.earnedCredits) ?? 0),
  );
  final completedCount = rootModuleNodes.where((n) => n.completed).length;
  return PlanCompletionSummaryStats(
    totalEarned: totalEarned,
    completedCount: completedCount,
    moduleCount: rootModuleNodes.length,
  );
}
