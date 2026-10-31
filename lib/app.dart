import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

// 这个库是为了在iOS上使用CupertinoPageTransitionsBuilder，flutter新版已经分离出来了，不要删
// ignore: unnecessary_import
import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/pages/home_page.dart';
import 'package:bugaoshan/pages/wizard/eula_gate_page.dart';
import 'package:bugaoshan/pages/wizard/wizard_page.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
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

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  late final BackgroundCacheService _bgCache = getIt<BackgroundCacheService>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bgCache.precache();
    });
    if (!kIsWeb && ref.read(logPersistenceEnabledSettingProvider)) {
      unawaited(getIt<AppLogger>().enableFileSink());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    ref.listen(logPersistenceEnabledSettingProvider, (previous, next) {
      if (kIsWeb) return;
      final logger = getIt<AppLogger>();
      if (next) {
        unawaited(logger.enableFileSink());
      } else {
        unawaited(logger.deletePersistedFiles());
      }
    });

    final locale = ref.watch(localeSettingProvider);
    final themeColor = ref.watch(themeColorSettingProvider);
    final themeColorMode = ref.watch(themeColorModeSettingProvider);
    final themeMode = ref.watch(themeModeSettingProvider);
    final useGoogleFonts = ref.watch(useGoogleFontsSettingProvider);
    final cardAnimDuration =
        ref.watch(cardSizeAnimationDurationSettingProvider);
    final eulaVersion = ref.watch(acceptedEulaVersionSettingProvider);
    final wizardCompleted =
        ref.watch(firstLaunchWizardCompletedSettingProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      locale: locale,
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx)!.bugaoshan,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      scrollBehavior: const AppScrollBehavior(),
      theme: _buildTheme(
        Brightness.light,
        context,
        themeColor: themeColor,
        themeColorMode: themeColorMode,
        useGoogleFonts: useGoogleFonts,
        cardAnimDuration: cardAnimDuration,
      ),
      darkTheme: _buildTheme(
        Brightness.dark,
        context,
        themeColor: themeColor,
        themeColorMode: themeColorMode,
        useGoogleFonts: useGoogleFonts,
        cardAnimDuration: cardAnimDuration,
      ),
      themeMode: themeMode,
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
      home: eulaVersion < currentEulaVersion
          ? const EulaGatePage()
          : (wizardCompleted ? const HomePage() : const WizardPage()),
    );
  }

  ThemeData _buildTheme(
    Brightness brightness,
    BuildContext context, {
    required Color themeColor,
    required ThemeColorMode themeColorMode,
    required bool useGoogleFonts,
    required Duration cardAnimDuration,
  }) {
    final seedColor = themeColorMode == ThemeColorMode.system
        ? SystemTheme.accentColor.accent
        : themeColor;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    return buildTheme(
      brightness: brightness,
      seedColor: seedColor,
      useGoogleFonts: useGoogleFonts,
      textScale: textScale,
      pageTransitionDuration: cardAnimDuration,
    );
  }
}

/// 全局滚动行为：桌面端允许鼠标左键拖动滚动视图。
///
/// Flutter 默认的 [ScrollBehavior.dragDevices] 不含 [PointerDeviceKind.mouse]，
/// 桌面 / Web 上按住鼠标拖不动任何列表与横向标签条（只能滚轮）。在默认集合
/// 基础上追加鼠标，不手动抄整套——默认值里的 `unknown` 是 Android 无障碍
/// 语音滚动（VoiceAccess）依赖的，漏掉会让 TalkBack 用户滑不动列表，以后
/// Flutter 新增设备类型也不会在这里漏跟。
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices =>
      {...super.dragDevices, PointerDeviceKind.mouse};
}
