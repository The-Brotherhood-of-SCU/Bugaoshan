import 'package:material_ui/material_ui.dart';

/// 登录页头部背景图。
///
/// 暗色/亮色各一张 WebP 资源，按主题自动选择；
/// 仅顶部圆角，底部直边与下方的表单卡片无缝衔接。
/// 高度随宽度按图片 2:1 比例自适应，不写死（写死会在图片下方露出背景色块）。
class ScuLoginHeaderImage extends StatelessWidget {
  const ScuLoginHeaderImage({super.key, required this.isDark});

  /// 头部图片圆角半径。
  static const double cornerRadius = 24;

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // 顶部圆角，底部直边与下方表单卡片无缝衔接
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(cornerRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        isDark ? 'assets/scu_header_dark.webp' : 'assets/scu_header_light.webp',
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
      ),
    );
  }
}
