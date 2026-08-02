import 'package:flutter/material.dart';

/// 登录页圆形复选框。
class ScuLoginCheckbox extends StatelessWidget {
  const ScuLoginCheckbox({
    super.key,
    required this.value,
    required this.label,
    required this.isDark,
    required this.brandColor,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final bool isDark;
  final Color brandColor;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? brandColor : Colors.transparent,
              border: Border.all(
                color: value
                    ? brandColor
                    : (isDark ? Colors.white38 : Colors.grey.shade400),
                width: 1.5,
              ),
            ),
            child: value
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
