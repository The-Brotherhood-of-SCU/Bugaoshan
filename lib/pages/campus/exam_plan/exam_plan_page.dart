import 'package:flutter/material.dart';
import 'package:bugaoshan/utils/app_shapes.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/exam_plan/models/exam_info.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/error_widgets.dart';
import 'package:bugaoshan/widgets/common/campus_network_required_widget.dart';

class ExamPlanPage extends StatefulWidget {
  const ExamPlanPage({super.key});

  @override
  State<ExamPlanPage> createState() => _ExamPlanPageState();
}

class _ExamPlanPageState extends State<ExamPlanPage> {
  List<ExamInfo> _exams = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    getIt<ScuAuthProvider>().addListener(_onAuthChanged);
    _loadData();
  }

  @override
  void dispose() {
    getIt<ScuAuthProvider>().removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final auth = getIt<ScuAuthProvider>();
    if (auth.isLoggedIn && mounted) {
      _loadData();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadData() async {
    final auth = getIt<ScuAuthProvider>();
    if (!auth.isLoggedIn) {
      if (auth.isAutoLoggingIn) return;
      setState(() => _error = 'notLoggedIn');
      return;
    }

    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = getIt<ZhjwApiService>();
      final exams = await api.fetchExamPlan();
      if (mounted) {
        setState(() {
          _exams = exams;
          _loading = false;
        });
      }
    } on UnauthenticatedException {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'notLoggedIn';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = campusNetworkErrorKey('loadFailed');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.examPlan),
        actions: [
          if (getIt<ScuAuthProvider>().isLoggedIn && !_loading)
            IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    final auth = getIt<ScuAuthProvider>();

    if (!auth.isLoggedIn && auth.isAutoLoggingIn) {
      return const AutoLoginLoadingWidget();
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error == 'notLoggedIn') {
      if (getIt<ScuAuthProvider>().isAutoLoggingIn) {
        return const AutoLoginLoadingWidget();
      }
      return const LoginRequiredWidget();
    }

    if (_error != null) {
      return RetryableErrorWidget(
        message: _getErrorMessage(l10n, _error!),
        onRetry: _loadData,
      );
    }

    if (_exams.isEmpty) {
      return Center(
        child: Text(
          l10n.examPlanNoData,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _exams.length,
        itemBuilder: (context, index) => _buildExamCard(_exams[index]),
      ),
    );
  }

  String _getErrorMessage(AppLocalizations l10n, String errorKey) {
    switch (errorKey) {
      case 'zhjwCampusNetworkRequiredAtNight':
        return l10n.zhjwCampusNetworkRequiredAtNight;
      default:
        return l10n.examPlanLoadFailed;
    }
  }

  Widget _buildExamCard(ExamInfo exam) {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;

    String dateLabel = exam.date;
    String dateSub = exam.weekday;
    final dm = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(exam.date);
    if (dm != null) {
      dateLabel = '${int.parse(dm.group(2)!)}月${int.parse(dm.group(3)!)}日';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
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
                            borderRadius: BorderRadius.circular(6),
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
                    ),
                    const SizedBox(height: 8),
                    // 地点
                    _infoChip(
                      Icons.location_on_outlined,
                      exam.location,
                      colorScheme,
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
                          ),
                        ),
                        if (exam.ticketNumber.isNotEmpty)
                          Expanded(
                            child: _infoChip(
                              Icons.confirmation_number_outlined,
                              exam.ticketNumber,
                              colorScheme,
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
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(AppShapes.small),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                exam.tip,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
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

  Widget _infoChip(IconData icon, String text, ColorScheme colorScheme) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
