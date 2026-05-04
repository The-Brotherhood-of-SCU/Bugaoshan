import 'package:flutter/widgets.dart';

/// 垂直方向 1/3 居中布局
///
/// 上半部分空白占 1/3，下半部分空白占 2/3
class ThirdCenter extends StatelessWidget {
  final Widget child;

  const ThirdCenter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(alignment: const Alignment(0, -1.3 / 3), child: child);
  }
}
