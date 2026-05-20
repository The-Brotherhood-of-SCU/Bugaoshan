import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

final appConfigService = getIt<AppConfigProvider>();

Future showInfoDialog({
  BuildContext? context, //this is no need anymore
  String title = "",
  String content = "",
  String button = "OK",
}) {
  return GlassDialog.show(
    context: logicRootContext,
    title: title,
    message: content,
    actions: [
      GlassDialogAction(
        label: button,
        onPressed: () => Navigator.of(logicRootContext).pop(),
      ),
    ],
  );
}

Future<bool?> showYesNoDialog({
  BuildContext? context, //no need
  String title = "",
  String content = "",
}) {
  return GlassDialog.show<bool>(
    context: logicRootContext,
    title: title,
    message: content,
    actions: [
      GlassDialogAction(
        label: "Yes",
        isPrimary: true,
        onPressed: () => Navigator.of(logicRootContext).pop(true),
      ),
      GlassDialogAction(
        label: "No",
        onPressed: () => Navigator.of(logicRootContext).pop(false),
      ),
    ],
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
        content: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [GlassProgressIndicator.circular()],
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
                    : GlassProgressIndicator.circular(),
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
  Navigator.of(logicRootContext).pop(result);
}
