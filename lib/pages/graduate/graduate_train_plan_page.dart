import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/graduate_grades.dart';
import 'package:bugaoshan/models/graduate_train_plan.dart';
import 'package:bugaoshan/pages/auth/scu_login_page.dart';
import 'package:bugaoshan/providers/graduate_train_plan_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/graduate_train_plan_progress.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:flutter/material.dart';

/// 研究生培养进度页。
///
/// 数据链（2026-09-21 抓包定案）：wdxx.do 方案信息 + wdkclbtj.do 方案要求
/// + wdfakcxx.do 课程类别归属 + xscjcx.do 成绩行（及格有效=已修，重修去
/// 重），归并逻辑见 graduate_train_plan_progress.dart。
/// 结构：总进度卡「已修 X / 要求 Y 学分」+ 方案信息卡 + 各课程类别
/// （该类已修/要求 + 已修课程列表）。
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
      requiredCredits: stats.requiredCredits,
      sections: _provider.sections,
      earnedTotal: _provider.earnedTotal,
    );
  }
}

/// 培养进度数据视图：总进度卡 + 方案信息卡 + 各课程类别
/// （该类已修学分/要求 + 已修课程列表）。
class TrainPlanContentView extends StatelessWidget {
  const TrainPlanContentView({
    super.key,
    required this.info,
    required this.requiredCredits,
    required this.sections,
    required this.earnedTotal,
  });

  final GraduateTrainPlanInfo info;

  /// 计划要求总学分（wdkclbtj.do reMapData.ZDXF）。
  final double requiredCredits;

  final List<TrainPlanProgressSection> sections;

  /// 已修（通过）学分总和，含方案外。
  final double earnedTotal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

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
                  graduateTrainPlanFmtCredits(earnedTotal),
                  graduateTrainPlanFmtCredits(requiredCredits),
                ),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: requiredCredits > 0
                    ? (earnedTotal / requiredCredits).clamp(0.0, 1.0)
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
        for (final section in sections) ...[
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
                        section.title,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      l10n.graduateTrainPlanModuleCredit(
                        graduateTrainPlanFmtCredits(section.earnedCredits),
                        graduateTrainPlanFmtCredits(section.requiredCredits),
                      ),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (section.requiredCredits > 0) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: (section.earnedCredits / section.requiredCredits)
                        .clamp(0.0, 1.0),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
                const SizedBox(height: 10),
                if (section.rows.isEmpty)
                  Text(
                    l10n.graduateTrainPlanNoCourses,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  for (final row in section.rows) ...[
                    const Divider(height: 12, thickness: 0.5),
                    _CompletedCourseRow(row: row),
                  ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 已修课程行：课程名 + 学期/成绩显示小字 + 学分。
class _CompletedCourseRow extends StatelessWidget {
  const _CompletedCourseRow({required this.row});

  final GraduateGradeRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = <String>[
      if (row.termName != null) row.termName!,
      if (row.gradeDisplay != null) row.gradeDisplay!,
      if (row.remark != null) row.remark!,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.courseName, style: theme.textTheme.bodyMedium),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle.join(' · '),
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
          graduateTrainPlanFmtCredits(row.credit),
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
