import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfigServiceHelper {
  SharedPreferences get _prefs => getIt<SharedPreferences>();

  ValueNotifier<Duration> get cardSizeAnimationDuration => ValueNotifier(
    Duration(
      milliseconds: getIt.isRegistered<SharedPreferences>()
          ? (_prefs.getInt('cardSizeAnimationDuration') ?? 200)
          : 200,
    ),
  );

  ValueNotifier<bool> get forceCaptchaForDownload => ValueNotifier(
    getIt.isRegistered<SharedPreferences>()
        ? (_prefs.getBool('forceCaptchaForDownload') ?? false)
        : false,
  );
}

final AppConfigServiceHelper appConfigService = AppConfigServiceHelper();

Duration get _animationDuration => appConfigService.cardSizeAnimationDuration.value;

Future showInfoDialog({
  BuildContext? context, //this is no need anymore
  String title = "",
  String content = "",
  String? button,
}) {
  final l10n = AppLocalizations.of(logicRootContext)!;
  return showDialog(
    context: logicRootContext,
    useRootNavigator: false,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(button ?? l10n.confirm),
          ),
        ],
      );
    },
  );
}

Future<bool?> showYesNoDialog({
  BuildContext? context, //no need
  String title = "",
  String content = "",
}) {
  final l10n = AppLocalizations.of(logicRootContext)!;
  return showDialog(
    context: logicRootContext,
    useRootNavigator: false,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: Text(l10n.confirm),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text(l10n.cancel),
          ),
        ],
      );
    },
  );
}

class ContextWrapper {
  late BuildContext context;
}

Future showLoadingDialog({
  BuildContext? context, //no need
  String? title,
  required Future Function() func,
  String? button,
  void Function()? onError,
}) {
  final l10n = AppLocalizations.of(logicRootContext)!;
  ContextWrapper contextWrapper = ContextWrapper();
  var future =
      Future.wait([func(), Future.delayed(const Duration(milliseconds: 100))])
          .then((v) async {
            if (contextWrapper.context.mounted) {
              Navigator.pop(contextWrapper.context, true);
            }
          })
          .onError((error, stackTrace) {
            //await Future.delayed(const Duration(microseconds: 5000));
            if (contextWrapper.context.mounted) {
              Navigator.pop(contextWrapper.context);
            }
            if (onError != null) {
              onError();
            }
          });
  var myCancelableFuture = CancelableOperation.fromFuture(future);

  return showDialog(
    barrierDismissible: false,
    context: logicRootContext,
    useRootNavigator: false,
    builder: (context) {
      contextWrapper.context = context;
      return AlertDialog(
        title: Text(title ?? l10n.loading),
        content: const Padding(
          padding: EdgeInsets.fromLTRB(0, 10, 0, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [CircularProgressIndicator()],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              myCancelableFuture.cancel();
              Navigator.of(context).pop();
            },
            child: Text(button ?? l10n.cancel),
          ),
        ],
      );
    },
  );
}

Future showLoadingDialogWithErrorString({
  BuildContext? context, //no need
  String? title,
  required Future Function() func,
  String? button,
  String? onErrorTitle,
  String? onErrorButton,
  String? onErrorMessage,
}) {
  final l10n = AppLocalizations.of(logicRootContext)!;
  bool isError = false;
  ContextWrapper contextWrapper = ContextWrapper();
  void rebuildDialog() {
    if (contextWrapper.context.mounted) {
      (contextWrapper.context as Element).markNeedsBuild();
    }
  }

  var future = func()
      .then((v) async {
        await Future.delayed(const Duration(milliseconds: 100));
        if (contextWrapper.context.mounted) {
          Navigator.pop(contextWrapper.context);
        }
      })
      .onError((error, stackTrace) {
        isError = true;
        rebuildDialog();
      });
  var myCancelableFuture = CancelableOperation.fromFuture(future);

  return showDialog(
    barrierDismissible: isError,
    context: logicRootContext,
    useRootNavigator: false,
    builder: (context) {
      contextWrapper.context = context;
      return AlertDialog(
        title: Text(
          isError ? (onErrorTitle ?? l10n.error) : (title ?? l10n.loading),
        ),
        content: AnimatedSize(
          duration: _animationDuration,
          curve: Curves.easeOutQuart,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                isError
                    ? Flexible(
                        child: Text(
                          onErrorMessage ?? l10n.error,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (!isError) {
                myCancelableFuture.cancel();
              }
              Navigator.of(context).pop();
            },
            child: Text(
              isError
                  ? (onErrorButton ?? l10n.confirm)
                  : (button ?? l10n.cancel),
            ),
          ),
        ],
      );
    },
  );
}

/// 关闭由 [popupOrNavigate] 以弹窗形式承载的页面（或任意根导航器上的弹窗）。
///
/// 宽屏 / 横屏下 [popupOrNavigate] 把页面放进 `Dialog` 的内层 `Navigator`，
/// 页面内直接 `Navigator.of(context).pop()` 只会弹掉内层路由，外层
/// `Dialog` 与遮罩仍在（#331 研究生课表导入）。
///
/// 传入 [context]（页面自身的 context）时优先弹**最近一层** Navigator：
/// - 内层还有上一页（例如从课表导入 sheet 进入、下面压着
///   `ImportSchedulePage`）→ 只退出当前页，保留下层页面状态；
/// - 内层已到栈底（页面就是弹窗的初始路由）→ 关闭承载它的 `Dialog`；
/// - 页面在根导航器上直接 push → 正常返回上一页。
///
/// 不传 [context] 时直接操作根导航器，等价于「关闭整个弹窗」，仅适用于
/// 页面本身独占一个弹窗的场景。
///
/// 走 [NavigatorState.maybePop] 而非硬 `pop`：与鼠标侧键 / 系统返回键
/// 那条链路（`mouse_back_handler.dart`）保持同一套语义，尊重页面
/// `PopScope(canPop: false)` 的拦截，栈底时也不会产生副作用。**注意**：
/// 因此关闭按钮在 `PopScope(canPop: false)` 的页面上会被静默拦截，这是
/// 预期行为，调用方需要自行提供可离开的路径。
void popDialog({dynamic result, BuildContext? context}) {
  if (context != null && context.mounted) {
    final nested = Navigator.of(context);
    if (nested.canPop()) {
      nested.maybePop(result);
      return;
    }
  }
  if (logicRootContext.mounted) {
    Navigator.of(logicRootContext).maybePop(result);
  }
}
