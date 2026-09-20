import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/graduate_grades.dart';
import 'package:bugaoshan/pages/auth/scu_login_page.dart';
import 'package:bugaoshan/providers/graduate_grades_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/stat_item.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:flutter/material.dart';

/// 研究生成绩页（仿本科「方案成绩」：统计汇总卡 + 按学期分组的课程明细）。
///
/// 数据链：[GsApiService.fetchGrades]（`_postForm` 自愈链）→
/// [graduateGradeRowsFromJson] → [graduateGradesStatsFromRows]。
class GraduateGradesPage extends StatefulWidget {
  const GraduateGradesPage({super.key});

  @override
  State<GraduateGradesPage> createState() => _GraduateGradesPageState();
}

class _GraduateGradesPageState extends State<GraduateGradesPage> {
  late final GraduateGradesProvider _provider;

  /// 统一认证会话过期（token 还在）时的自愈刷新进行中。
  bool _recoveringSession = false;

  @override
  void initState() {
    super.initState();
    _provider = getIt<GraduateGradesProvider>();
    getIt<ScuAuthProvider>().addListener(_onAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onAuthChanged();
    });
  }

  @override
  void dispose() {
    getIt<ScuAuthProvider>().removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final auth = getIt<ScuAuthProvider>();
    if (auth.isLoggedIn) {
      _provider.ensureLoaded();
    } else if (!auth.isAutoLoggingIn &&
        !_recoveringSession &&
        auth.accessToken != null) {
      // token 还在但状态非 ready（统一认证 1 小时会话过期）：先自愈
      // （bindSession → 自动登录），失败才落到「前往登录」引导。
      _recoverSession();
    }
  }

  Future<void> _recoverSession() async {
    setState(() => _recoveringSession = true);
    try {
      await getIt<ScuAuth>().refresh();
    } finally {
      if (mounted) setState(() => _recoveringSession = false);
    }
  }

  /// 打开应用自带的统一认证登录页；登录完成返回后由用户点「重试」。
  void _openLoginPage() {
    popupOrNavigate(context, const ScuLoginPage());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: Listenable.merge([_provider, getIt<ScuAuthProvider>()]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(l10n.graduateGrades),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.close,
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            if (getIt<ScuAuthProvider>().isLoggedIn &&
                _provider.state != GraduateGradesLoadState.loading)
              IconButton(
                onPressed: _provider.refresh,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        body: _buildBody(l10n),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    final auth = getIt<ScuAuthProvider>();

    // 统一认证未登录：自动登录或会话自愈中给加载态，
    // 否则给「请先登录」引导。研教务会话过期的错误态走下方 unauthenticated。
    if (!auth.isLoggedIn) {
      return auth.isAutoLoggingIn || _recoveringSession
          ? const AutoLoginLoadingWidget()
          : const LoginRequiredWidget();
    }

    if (_provider.state == GraduateGradesLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_provider.errorKind == GraduateGradesErrorKind.unauthenticated) {
      // 自愈重试后仍失败：给「会话过期」+ 前往登录 + 重试（与课表导入页
      // 失败态同语义），不用死胡同的「请先登录」——用户往往明明已登录。
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.sessionExpired,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _openLoginPage,
                icon: const Icon(Icons.login),
                label: Text(l10n.goToLogin),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _provider.refresh,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_provider.errorKind != null) {
      return RetryableErrorWidget.message(
        message: _provider.errorMessage ?? l10n.loadFailed,
        onRetry: _provider.refresh,
      );
    }

    final stats = _provider.stats;
    if (stats == null) {
      return Center(
        child: Text(
          l10n.graduateGradesEmpty,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _provider.refresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildSummaryCard(stats)),
          for (final group in _groupRowsByTerm(_provider.rows)) ...[
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
              itemCount: group.rows.length,
              itemBuilder: (context, index) =>
                  _GradeCard(row: group.rows[index]),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  /// 统计汇总卡（与本科「方案成绩」的 StatItem 行同款）。
  Widget _buildSummaryCard(GraduateGradesStats stats) {
    final l10n = AppLocalizations.of(context)!;
    return StyledCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.graduateGradesStats,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                StatItem(
                  label: l10n.graduateStatsCourseCount,
                  value: '${stats.courseCount}',
                  highlight: true,
                ),
                StatItem(
                  label: l10n.graduateStatsTotalCredit,
                  value: stats.totalCredit.toStringAsFixed(1),
                ),
                StatItem(
                  label: l10n.graduateStatsAverage,
                  value: stats.weightedAverage?.toStringAsFixed(2) ?? '--',
                ),
                StatItem(
                  label: l10n.graduateStatsPassRate,
                  value: _percentLabel(stats.passRate),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 通过率：整数不带小数、小数保留 1 位，null 显示占位符。
  static String _percentLabel(double? value) {
    if (value == null) return '--';
    return value % 1 == 0
        ? '${value.toStringAsFixed(0)}%'
        : '${value.toStringAsFixed(1)}%';
  }

  /// 按学期分组（新学期在前），label 优先用学期显示名。
  List<({String label, List<GraduateGradeRow> rows})> _groupRowsByTerm(
    List<GraduateGradeRow> rows,
  ) {
    final byTerm = <String, List<GraduateGradeRow>>{};
    for (final row in rows) {
      byTerm.putIfAbsent(row.termCode, () => []).add(row);
    }
    final terms = byTerm.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final term in terms)
        (
          label: byTerm[term]!.first.termName ?? term,
          rows: byTerm[term]!,
        ),
    ];
  }
}

/// 单门课的成绩卡片（仿本科 ScoreCardWidget）。
class _GradeCard extends StatelessWidget {
  const _GradeCard({required this.row});

  final GraduateGradeRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final attrColor = switch (row.category) {
      final c? when c.contains('必修') => colorScheme.primaryContainer,
      final c? when c.contains('选修') => colorScheme.secondaryContainer,
      _ => colorScheme.tertiaryContainer,
    };
    final attrTextColor = switch (row.category) {
      final c? when c.contains('必修') => colorScheme.onPrimaryContainer,
      final c? when c.contains('选修') => colorScheme.onSecondaryContainer,
      _ => colorScheme.onTertiaryContainer,
    };

    final scoreColor = !row.passed
        ? colorScheme.error
        : (row.percentile != null && row.percentile! >= 90)
        ? colorScheme.primary
        : null;

    final gradeLabel = row.gradeDisplay ?? row.gradeText ?? '--';
    final gradeSub = row.gradeSubLabel;

    return StyledCard(
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
                    row.courseName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (row.courseNameEn != null &&
                      row.courseNameEn!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        row.courseNameEn!.trim(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (row.category != null && row.category!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: attrColor,
                            borderRadius: BorderRadius.circular(AppShapes.xs),
                          ),
                          child: Text(
                            row.category!,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: attrTextColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        l10n.creditUnit(row.credit),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (row.attemptType != null &&
                          row.attemptType!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          row.attemptType!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                  if (!row.remarkIsRedundant &&
                      row.remark != null &&
                      row.remark!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        row.remark!.trim(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  gradeLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
                if (gradeSub != null && gradeSub.isNotEmpty)
                  Text(
                    gradeSub,
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
