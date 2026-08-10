import 'package:flutter/material.dart';
import 'package:bugaoshan/theme_shape.dart';

/// 登录页输入框。
///
/// [label] 为空时只渲染输入框本身（验证码行内字段等场景）；
/// [fillColor] 可覆盖默认填充色（暗色模式下验证码框颜色与普通框略有不同）。
class ScuLoginInputField extends StatelessWidget {
  const ScuLoginInputField({
    super.key,
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    required this.isDark,
    required this.brandColor,
    this.label,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.fillColor,
  });

  final TextEditingController controller;
  final String? label;
  final String hint;
  final IconData prefixIcon;
  final bool isDark;
  final Color brandColor;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: TextStyle(
        fontSize: 15,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: isDark ? Colors.white24 : Colors.grey.shade400,
          fontSize: 14,
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 4),
          width: 36,
          height: 36,
          child: Icon(prefixIcon, color: brandColor, size: 18),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor:
            fillColor ??
            (isDark ? const Color(0xFF2D2F36) : Colors.grey.shade50),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.medium),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.medium),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.medium),
          borderSide: BorderSide(color: brandColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.medium),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );

    final labelText = label;
    if (labelText == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}
