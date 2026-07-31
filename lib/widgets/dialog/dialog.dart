import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

final appConfigService = getIt<AppConfigProvider>();

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
  rebuildDialog() {
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
          duration: appConfigService.cardSizeAnimationDuration.value,
          curve: Curves.easeOutQuart,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                isError
                    ? Text(onErrorMessage ?? l10n.error)
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

void popDialog([dynamic result]) {
  if (logicRootContext.mounted) {
    Navigator.of(logicRootContext).pop(result);
  }
}
