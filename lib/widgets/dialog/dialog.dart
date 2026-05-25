import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';

final appConfigService = getIt<AppConfigProvider>();

Future showInfoDialog({
  BuildContext? context,
  String title = "",
  String content = "",
  String button = "OK",
}) {
  final ctx = context ?? logicRootContext;
  return showDialog(
    context: ctx,
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
            child: Text(button),
          ),
        ],
      );
    },
  );
}

Future<bool?> showYesNoDialog({
  BuildContext? context,
  String title = "",
  String content = "",
}) {
  final ctx = context ?? logicRootContext;
  return showDialog(
    context: ctx,
    useRootNavigator: false,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: Text(l10n?.confirm ?? 'Yes'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text(l10n?.cancel ?? 'No'),
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
  String title = "Loading",
  required Future Function() func,
  String button = "Cancel",
  void Function()? onError,
}) {
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
        title: Text(title),
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
            child: Text(button),
          ),
        ],
      );
    },
  );
}

Future showLoadingDialogWithErrorString({
  BuildContext? context, //no need
  String title = "Loading",
  required Future Function() func,
  String button = "Cancel",
  String onErrorTitle = "Error",
  String onErrorButton = "OK",
  String onErrorMessage = "error",
}) {
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
        title: Text(isError ? onErrorTitle : title),
        content: AnimatedSize(
          duration: appConfigService.cardSizeAnimationDuration.value,
          curve: Curves.easeOutQuart,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                isError
                    ? Text(onErrorMessage)
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
            child: Text(isError ? onErrorButton : button),
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
