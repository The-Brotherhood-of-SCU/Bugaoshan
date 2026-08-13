import 'package:material_ui/material_ui.dart';

/// 登录页主按钮，带加载态（加载中禁用并显示转圈）。
class ScuLoginButton extends StatelessWidget {
  const ScuLoginButton({
    super.key,
    required this.loading,
    required this.onPressed,
    required this.brandColor,
    required this.label,
  });

  final bool loading;
  final VoidCallback onPressed;
  final Color brandColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style:
          FilledButton.styleFrom(
            backgroundColor: brandColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            elevation: 2,
            shadowColor: brandColor.withValues(alpha: 0.3),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return Colors.white.withValues(alpha: 0.2);
              }
              if (states.contains(WidgetState.hovered)) {
                return Colors.white.withValues(alpha: 0.1);
              }
              return null;
            }),
          ),
      child: loading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Text(label),
    );
  }
}
