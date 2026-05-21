enum WidgetSize { small, medium, large }

extension WidgetSizeExtension on WidgetSize {
  String toPinArgument() {
    switch (this) {
      case WidgetSize.small:
        return 'small';
      case WidgetSize.medium:
        return 'medium';
      case WidgetSize.large:
        return 'large';
    }
  }
}
