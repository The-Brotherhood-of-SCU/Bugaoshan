import 'package:flutter/material.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/exam_plan/models/exam_info.dart';
import 'package:bugaoshan/providers/exam_plan_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/ics_service.dart';
import 'package:bugaoshan/utils/calendar_export_utils.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';

class ExamPlanPage extends StatefulWidget {
  const ExamPlanPage({super.key});

  @override
  State<ExamPlanPage> createState() => _ExamPlanPageState();
}

class _ExamPlanPageState extends State<ExamPlanPage> {
  late final ExamPlanProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = getIt<ExamPlanProvider>();
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
    if (auth.isLoggedIn) _provider.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.examPlan),
        actions: [
          if (getIt<ScuAuthProvider>().isLoggedIn &&
              _provider.state != ExamPlanLoadState.loading &&
              _provider.exams.isNotEmpty)
            IconButton(
              tooltip: l10n.exportExamPlan,
              onPressed: () => _showCalendarActions(l10n),
              icon: const Icon(Icons.calendar_month_outlined),
            ),
          if (getIt<ScuAuthProvider>().isLoggedIn &&
              _provider.state != ExamPlanLoadState.loading)
            IconButton(
              onPressed: _provider.refresh,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_provider, getIt<ScuAuthProvider>()]),
        builder: (context, _) => _buildBody(l10n),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    final auth = getIt<ScuAuthProvider>();

    if (!auth.isLoggedIn && auth.isAutoLoggingIn) {
      return const AutoLoginLoadingWidget();
    }

    if (_provider.state == ExamPlanLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_provider.error == LoadErrorType.notLoggedIn) {
      if (getIt<ScuAuthProvider>().isAutoLoggingIn) {
        return const AutoLoginLoadingWidget();
      }
      return const LoginRequiredWidget();
    }

    if (_provider.error != null) {
      return RetryableErrorWidget(
        errorType: _provider.error!,
        onRetry: _provider.refresh,
      );
    }

    if (_provider.exams.isEmpty) {
      return Center(
        child: Text(
          l10n.examPlanNoData,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _provider.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppShapes.large),
        itemCount: _provider.exams.length,
        itemBuilder: (context, index) => _buildExamCard(_provider.exams[index]),
      ),
    );
  }

  Widget _buildExamCard(ExamInfo exam) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final past = exam.isPast;
    final primary = past ? colorScheme.outline : colorScheme.primary;

    String dateLabel = exam.date;
    String dateSub = exam.weekday;
    final dm = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(exam.date);
    if (dm != null) {
      dateLabel = l10n.dateMonthDay(
        int.parse(dm.group(2)!),
        int.parse(dm.group(3)!),
      );
    }

    return StyledCard(
      margin: const EdgeInsets.only(bottom: 14),
      backgroundColor: past ? colorScheme.surfaceContainerLow : null,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 左侧日期色块 ──
            Container(
              width: 72,
              color: primary.withValues(alpha: 0.08),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dateLabel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (past)
                    Text(
                      l10n.examEnded,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else
                    Text(
                      dateSub,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: primary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            // ── 右侧信息区 ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 课程名 + 周次
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            exam.courseName,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                  color: past
                                      ? colorScheme.onSurface.withValues(
                                          alpha: 0.5,
                                        )
                                      : null,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppShapes.small,
                            ),
                          ),
                          child: Text(
                            exam.week,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 时间
                    _infoChip(
                      Icons.access_time_rounded,
                      exam.timeRange,
                      colorScheme,
                      past: past,
                    ),
                    const SizedBox(height: 8),
                    // 地点
                    _infoChip(
                      Icons.location_on_outlined,
                      exam.location,
                      colorScheme,
                      past: past,
                    ),
                    const SizedBox(height: 8),
                    // 座位号 + 准考证号 同行
                    Row(
                      children: [
                        Expanded(
                          child: _infoChip(
                            Icons.event_seat_outlined,
                            exam.seatNumber,
                            colorScheme,
                            past: past,
                          ),
                        ),
                        if (exam.ticketNumber.isNotEmpty)
                          Expanded(
                            child: _infoChip(
                              Icons.confirmation_number_outlined,
                              exam.ticketNumber,
                              colorScheme,
                              past: past,
                            ),
                          ),
                      ],
                    ),
                    // 提示信息
                    if (exam.tip != '无') ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (past
                                      ? colorScheme.outlineVariant
                                      : colorScheme.surfaceContainerHighest)
                                  .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppShapes.small),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: past
                                  ? colorScheme.onSurface.withValues(alpha: 0.4)
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                exam.tip,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: past
                                          ? colorScheme.onSurface.withValues(
                                              alpha: 0.4,
                                            )
                                          : colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCalendarActions(AppLocalizations l10n) async {
    final action = await CalendarExportUtils.showActionSheet(
      context,
      l10n,
      title: l10n.exportExamPlan,
      includeCopy: true,
    );
    if (!mounted || action == null) return;

    await CalendarExportUtils.handleExportAction(
      context: context,
      l10n: l10n,
      action: action,
      copyToClipboard: () => CalendarExportUtils.copyJsonToClipboard({
        'exams': _provider.exams.map((exam) => exam.toJson()).toList(),
      }, logTag: 'ExamPlanPage'),
      copySuccessMessage: l10n.exportExamPlanAsCopySuccess,
      copyFailedMessage: l10n.exportScheduleAsCopyFailed,
      buildCalendarPayload: () => IcsService.genExamExportPayload(
        exams: _provider.exams,
        fileName: '${_examPlanFileName()}.ics',
      ),
      logTag: 'ExamPlanPage',
    );
  }

  String _examPlanFileName() {
    final dates =
        _provider.exams
            .map((exam) => exam.date)
            .where((date) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date))
            .toList()
          ..sort();
    final suffix = dates.isEmpty ? 'unknown' : '${dates.first}_${dates.last}';
    return 'exam_plan_$suffix'.replaceAll(RegExp(r'[^\w\u4e00-\u9fff-]'), '_');
  }

  Widget _infoChip(
    IconData icon,
    String text,
    ColorScheme colorScheme, {
    bool past = false,
  }) {
    final iconColor = past
        ? colorScheme.onSurface.withValues(alpha: 0.35)
        : colorScheme.onSurfaceVariant;
    final textColor = past
        ? colorScheme.onSurface.withValues(alpha: 0.45)
        : colorScheme.onSurface.withValues(alpha: 0.8);
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: textColor, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
