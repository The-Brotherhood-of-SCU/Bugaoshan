import 'package:flutter/material.dart';

import 'popup_context.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

BuildContext get logicRootContext => navigatorKey.currentContext!;
const bool _showCloseButton = false;

Future popupContent(
  Widget child,
  double width, {
  double? height,
  BuildContext? context,
  bool useFragment = true,
  bool adaptiveHeight = false,
}) {
  final widget = SizedBox(
    width: width,
    height: height,
    child: useFragment ? Fragment(child: child) : child,
  );
  final context0 = context ?? logicRootContext;
  return showDialog(
    context: context0,
    barrierDismissible: true,
    useRootNavigator: false,
    builder: (builder) {
      return PopupContext(
        isInPopup: true,
        child: Dialog(
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.0),
            child: Container(
              color: DialogTheme.of(context0).backgroundColor,
              child: Stack(
                children: [
                  widget,
                  if (_showCloseButton)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.of(context0).pop(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

enum ScreenSizeType { landscape, bigPortrait, smallPortrait }

ScreenSizeType getScreenSizeType(MediaQueryData mediaQuery) {
  var width = mediaQuery.size.width;
  final height = mediaQuery.size.height;
  bool isLandscape = mediaQuery.orientation == Orientation.landscape;
  if (isLandscape) {
    return ScreenSizeType.landscape;
  }
  bool isBigScreen = (width > 600 && height > 600);
  if (isBigScreen) {
    return ScreenSizeType.bigPortrait;
  }
  return ScreenSizeType.smallPortrait;
}

Future<dynamic> popupOrNavigate(
  BuildContext context,
  Widget page, {
  bool adaptiveHeight = false,
  bool useFragment = true,
}) async {
  // 检查是否已经在弹窗内
  final popupContext = PopupContext.of(context);
  final bool isInPopup = popupContext?.isInPopup ?? false;

  var mediaQuery = MediaQuery.of(context);
  var width = mediaQuery.size.width;
  final height = mediaQuery.size.height;
  final screenSizeType = getScreenSizeType(mediaQuery);

  // 如果已经在弹窗内，直接导航而不是再弹窗
  if (isInPopup) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (builder) {
          return page;
        },
      ),
    );
    return;
  }

  if (screenSizeType == ScreenSizeType.landscape) {
    return await popupContent(
      page,
      width / 2,
      useFragment: useFragment,
      adaptiveHeight: adaptiveHeight,
    );
  } else if (screenSizeType == ScreenSizeType.bigPortrait) {
    return await popupContent(
      page,
      width * 2 / 3,
      height: height * 2 / 3,
      useFragment: useFragment,
      adaptiveHeight: adaptiveHeight,
    );
  } else {
    return await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (builder) {
          return page;
        },
      ),
    );
  }
}

class Fragment extends StatelessWidget {
  final Widget child;
  final String root;

  const Fragment({required this.child, this.root = "/", super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      initialRoute: root,
      onGenerateRoute: (RouteSettings settings) {
        WidgetBuilder builder;
        builder = (context) => child;
        return MaterialPageRoute(builder: builder);
      },
    );
  }
}
