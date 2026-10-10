import 'dart:async';

// 这个库是为了在iOS上使用CupertinoPageTransitionsBuilder，flutter新版已经分离出来了，不要删
// ignore: unnecessary_import
import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/pages/home_page.dart';
import 'package:bugaoshan/pages/wizard/eula_gate_page.dart';
import 'package:bugaoshan/pages/wizard/wizard_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/background_cache_service.dart';
import 'package:bugaoshan/services/reminder/live_activity_coordinator.dart';
import 'package:bugaoshan/services/reminder/reminder_service.dart';
import 'package:bugaoshan/theme.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:bugaoshan/widgets/common/session_expired_listener.dart';
import 'package:bugaoshan/widgets/eula_content.dart';
import 'package:bugaoshan/widgets/route/mouse_back_handler.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:system_theme/system_theme.dart';
import 'l10n/app_localizations.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final AppConfigProvider _appConfig = getIt<AppConfigProvider>();
  late final BackgroundCacheService _bgCache = getIt<BackgroundCacheService>();
  late final void Function() _logPersistenceListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bgCache.precache();
    });
    _bindLogPersistence();
  }

  /// 按用户开关启停 warn/error 日志落盘。
  ///
  /// 默认开启（`AppConfigProvider.logPersistenceEnabled`）：落盘是崩溃现场的
  /// 唯一后手，默认关闭等于要求用户在出问题前就去设置里翻开关。用户关闭时
  /// 同时清理可能残留的旧文件。
  void _bindLogPersistence() {
    final logger = getIt<AppLogger>();
    final notifier = _appConfig.logPersistenceEnabled;
    void apply(bool enabled) {
      if (enabled) {
        unawaited(logger.enableFileSink());
      } else {
        unawaited(
          logger.disableFileSink().then((_) {
            return logger.deletePersistedFiles();
          }),
        );
      }
    }

    _logPersistenceListener = () => apply(notifier.value);
    notifier.addListener(_logPersistenceListener);
    apply(notifier.value);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appConfig.logPersistenceEnabled.removeListener(_logPersistenceListener);
    _bgCache.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 应用恢复前台时重新触发排期：处理系统设置中的权限变更以及覆盖时间窗口滚动的更新场景。
    if (state != AppLifecycleState.resumed) return;
    // 校验异步单例就绪状态（isReadySync）：避免在冷启动或注册未完成的异步间隙中直接调用
    // `getIt<ReminderService>()` 引发 StateError。
    if (getIt.isReadySync<ReminderService>()) {
      unawaited(getIt<ReminderService>().reschedule());
    }
    // 实时活动必须在前台启动，前台唤醒是核心触发节点；同时用于对齐课间与下一节课程的状态转换。
    if (getIt.isReadySync<LiveActivityCoordinator>()) {
      unawaited(getIt<LiveActivityCoordinator>().tick());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _appConfig.locale,
        _appConfig.themeColor,
        _appConfig.themeColorMode,
        _appConfig.themeMode,
        _appConfig.useGoogleFonts,
        // 页面转场时长跟随设置变化，需要重建 MaterialApp 使新主题生效
        // （「页面切换动画」开关只控制 Dock 栏切换，不进全局主题）
        _appConfig.cardSizeAnimationDuration,
      ]),
      builder: (context, _) => MaterialApp(
        navigatorKey: navigatorKey,
        locale: _appConfig.locale.value,
        onGenerateTitle: (ctx) => AppLocalizations.of(ctx)!.bugaoshan,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: _buildTheme(Brightness.light, context),
        darkTheme: _buildTheme(Brightness.dark, context),
        themeMode: _appConfig.themeMode.value,
        builder: (context, child) {
          final scale = MediaQuery.textScalerOf(context).scale(1.0);
          final clamped = scale.clamp(1.0, 2.0);
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(clamped)),
            child: MouseBackHandler(
              child: SessionExpiredListener(child: child ?? const SizedBox()),
            ),
          );
        },
        home: ValueListenableBuilder<int>(
          valueListenable: _appConfig.acceptedEulaVersion,
          builder: (_, eulaVersion, _) {
            if (eulaVersion < currentEulaVersion) {
              return const EulaGatePage();
            }
            return ValueListenableBuilder<bool>(
              valueListenable: _appConfig.firstLaunchWizardCompleted,
              builder: (_, completed, _) =>
                  completed ? const HomePage() : const WizardPage(),
            );
          },
        ),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness, BuildContext context) {
    final seedColor = _appConfig.themeColorMode.value == ThemeColorMode.system
        ? SystemTheme.accentColor.accent
        : _appConfig.themeColor.value;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    return buildTheme(
      brightness: brightness,
      seedColor: seedColor,
      useGoogleFonts: _appConfig.useGoogleFonts.value,
      textScale: textScale,
      pageTransitionDuration: _appConfig.cardSizeAnimationDuration.value,
    );
  }
}
