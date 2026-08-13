import 'package:material_ui/material_ui.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';

/// A card container that groups child widgets with dividers between them.
///
/// 视觉样式委托给 [StyledCard]，本组件只负责"分组 + 分隔线"的内容组织，
/// 不再自己处理背景/圆角/描边。
class InfoCard extends StatelessWidget {
  final List<Widget> children;

  /// 分隔线缩进。默认 56（对齐 leading icon 之后）；
  /// tile 无 leading icon 时可传 0 使用全宽分隔线。
  final double indent;

  const InfoCard({super.key, required this.children, this.indent = 56});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StyledCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _intersperse(children, divider(theme, indent)),
      ),
    );
  }

  /// Standard divider between tiles (default indent: 56 to align after icon).
  static Widget divider(ThemeData theme, [double indent = 56]) {
    return Divider(
      height: 1,
      indent: indent,
      color: theme.dividerColor.withValues(alpha: 0.08),
    );
  }

  static List<Widget> _intersperse(List<Widget> widgets, Widget separator) {
    if (widgets.length <= 1) return widgets;
    final result = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      if (i > 0) result.add(separator);
      result.add(widgets[i]);
    }
    return result;
  }
}
