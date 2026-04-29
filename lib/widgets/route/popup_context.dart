import 'package:flutter/material.dart';

class PopupContext extends InheritedWidget {
  final bool isInPopup;

  const PopupContext({
    super.key,
    required this.isInPopup,
    required super.child,
  });

  static PopupContext? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PopupContext>();
  }

  @override
  bool updateShouldNotify(PopupContext oldWidget) {
    return isInPopup != oldWidget.isInPopup;
  }
}
