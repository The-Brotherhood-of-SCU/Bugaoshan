import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/graduate_train_plan.dart';
import 'package:bugaoshan/pages/auth/scu_login_page.dart';
import 'package:bugaoshan/providers/graduate_train_plan_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:flutter/material.dart';

/// 研究生培养进度页。
///
/// 数据链（2026-09-21 抓包定案）：wdxx.do 方案信息 + wdkclbtj.do 分类学分
/// 统计 + wdfakcxx.do 方案课程明细（见 GraduateTrainPlanProvider）。
/// 结构：总进度卡「已修 X / 要求 Y 学分」+ 方案信息卡 + 各课程类别
/// （分类学分进度 + 该类方案课程列表）。
class GraduateTrainPlanPage extends StatefulWidget {
  const GraduateTrainPlanPage({super.key});

  @override
  State<GraduateTrainPlanPage> createState() => _GraduateTrainPlanPageState();
}

class _GraduateTrainPlanPageState extends State<GraduateTrainPlanPage> {
  static const String _tag = 'GraduateTrainPlanPage';

  late final GraduateTrainPlanProvider _provider;

  /// 统一认证会话过期（token 还在）时的自愈刷新进行中。
  bool _recoveringSession = false;

  @override
  void initState() {
    super.initState();
    _provider = getIt<GraduateTrainPlanProvider>();
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
    } catch (e) {
      // 自愈失败：这个 Future 由 listener 回调 fire-and-forget 触发、没人接，
      // 不 catch 会变成 unhandled async error。留在未登录分支，由
      // _buildBody 的「请先登录」引导承接。
      AppLog.w(_tag, '会话自愈失败，转登录引导：$e');
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
          title: Text(l10n.graduateTrainPlan),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.close,
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            if (getIt<ScuAuthProvider>().isLoggedIn &&
                _provider.state != GraduateTrainPlanLoadState.loading)
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

    // 统一认证未登录：自动登录或会话自愈中给加载态，否则给「请先登录」
    // 引导。研教务会话过期的错误态走下方 unauthenticated。
    if (!auth.isLoggedIn) {
      return auth.isAutoLoggingIn || _recoveringSession
          ? const AutoLoginLoadingWidget()
          : const LoginRequiredWidget();
    }

    if (_provider.state == GraduateTrainPlanLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_provider.errorKind == GraduateTrainPlanErrorKind.unauthenticated) {
      // 自愈重试后仍失败：给「会话过期」+ 前往登录 + 重试（与成绩页/
      // 课表导入页失败态同语义），不用死胡同的「请先登录」。
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

    final info = _provider.info;
    final stats = _provider.creditStats;
    if (info == null || stats == null) {
      return Center(
        child: Text(
          l10n.graduateTrainPlanEmpty,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return TrainPlanContentView(
      info: info,
      stats: stats,
      categories: _provider.categories,
      courses: _provider.courses,
    );
  }
}

/// 培养进度数据视图：总进度卡 + 方案信息卡 + 各课程类别
/// （分类学分进度 + 该类方案课程列表）。
class TrainPlanContentView extends StatelessWidget {
  const TrainPlanContentView({
    super.key,
    required this.info,
    required this.stats,
    required this.categories,
    required this.courses,
  });

  final GraduateTrainPlanInfo info;
  final GraduateTrainPlanCreditStats stats;
  final List<GraduateTrainPlanCategoryProgress> categories;
  final List<GraduateTrainPlanCourse> courses;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final grouped = <String, List<GraduateTrainPlanCourse>>{};
    for (final course in courses) {
      grouped.putIfAbsent(course.kclbdm, () => []).add(course);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.graduateTrainPlanProgress,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.graduateTrainPlanCreditText(
                  fmtCredits(stats.selectedCredits),
                  fmtCredits(stats.requiredCredits),
                ),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: stats.requiredCredits > 0
                    ? (stats.selectedCredits / stats.requiredCredits).clamp(
                        0.0,
                        1.0,
                      )
                    : null,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(info.famc, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final text in [
                    info.njdmDisplay,
                    info.pyccdmDisplay,
                    info.zydmDisplay,
                    info.yxdmDisplay,
                    info.shztDisplay,
                  ])
                    if (text != null) _Chip(text: text),
                ],
              ),
            ],
          ),
        ),
        for (final category in _planSections(categories, courses)) ...[
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        category.title,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      l10n.graduateTrainPlanModuleCredit(
                        fmtCredits(category.selectedCredits),
                        fmtCredits(category.requiredCredits),
                      ),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (category.requiredCredits > 0)
                  LinearProgressIndicator(
                    value: (category.selectedCredits / category.requiredCredits)
                        .clamp(0.0, 1.0),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                const SizedBox(height: 10),
                if (category.courses.isEmpty)
                  Text(
                    l10n.graduateTrainPlanNoCourses,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  for (final course in category.courses) ...[
                    const Divider(height: 12, thickness: 0.5),
                    _CourseRow(course: course),
                  ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 一个课程类别区块：标题（类别名）+ 分类学分进度 + 该类方案课程列表。
class _PlanSection {
  const _PlanSection({
    required this.title,
    required this.selectedCredits,
    required this.requiredCredits,
    required this.courses,
  });

  final String title;
  final double selectedCredits;
  final double requiredCredits;
  final List<GraduateTrainPlanCourse> courses;
}

/// 以 `wdkclbtj` 的分类行为主序，把 `wdfakcxx` 的课程按 KCLBDM 归组；
/// 分类行里没有、但课程里出现的类别，按类别名补到末尾。
List<_PlanSection> _planSections(
  List<GraduateTrainPlanCategoryProgress> rows,
  List<GraduateTrainPlanCourse> courses,
) {
  final grouped = <String, List<GraduateTrainPlanCourse>>{};
  for (final course in courses) {
    grouped.putIfAbsent(course.kclbdm, () => []).add(course);
  }

  final sections = [
    for (final row in rows)
      _PlanSection(
        title: row.mc.isEmpty ? (row.dm.isEmpty ? '' : row.dm) : row.mc,
        selectedCredits: row.selectedCredits,
        requiredCredits: row.requiredCredits,
        courses: grouped.remove(row.dm) ?? const [],
      ),
  ];
  for (final entry in grouped.entries) {
    final first = entry.value.first;
    sections.add(
      _PlanSection(
        title: first.kclbdmDisplay?.isNotEmpty == true
            ? first.kclbdmDisplay!
            : entry.key,
        selectedCredits: entry.value.fold(
          0.0,
          (sum, course) => sum + course.credits,
        ),
        requiredCredits: 0.0,
        courses: entry.value,
      ),
    );
  }
  return sections;
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.course});

  final GraduateTrainPlanCourse course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badges = <String>[
      if (course.outOfPlan) '方案外',
      if (course.remark != null) course.remark!,
      if (course.stage != null) course.stage!,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(course.kcmc, style: theme.textTheme.bodyMedium),
              if (badges.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  badges.join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          fmtCredits(course.credits),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 学分数字显示：整数去尾零（14.0 → 14），其余保留一位（5.5 → 5.5）。
String fmtCredits(double value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value';
