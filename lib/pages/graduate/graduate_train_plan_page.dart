import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
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
/// 骨架：培养进度端点尚未抓包定案，先按标准套路落页面结构与状态机；
/// 总进度「已修 X / 要求 Y 学分」+ 各模块学分进度与课程列表（文案已预留
/// graduateTrainPlan* 全套）随端点定案一并接线（见 GraduateTrainPlanProvider
/// 的 TODO(gs-api)）。
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

    return Center(
      child: Text(
        l10n.graduateTrainPlanEmpty,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
