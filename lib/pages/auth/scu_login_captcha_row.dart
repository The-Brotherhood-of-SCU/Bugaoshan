import 'dart:typed_data';

import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/auth/scu_login_input_field.dart';
import 'package:flutter/material.dart';

/// 登录页验证码行：输入框 + 可点击刷新的验证码图片。
///
/// 点击验证码图片触发 [onRefresh] 重新拉取验证码。
/// 验证码未加载时图片区域显示刷新图标，同样可点击刷新。
class ScuLoginCaptchaRow extends StatelessWidget {
  const ScuLoginCaptchaRow({
    super.key,
    required this.controller,
    required this.l10n,
    required this.isDark,
    required this.brandColor,
    required this.captchaImageBytes,
    required this.captchaLoading,
    required this.onRefresh,
  });

  final TextEditingController controller;
  final AppLocalizations l10n;
  final bool isDark;
  final Color brandColor;
  final Uint8List? captchaImageBytes;
  final bool captchaLoading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.captcha,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ScuLoginInputField(
                controller: controller,
                hint: l10n.captchaHint,
                prefixIcon: Icons.shield_outlined,
                isDark: isDark,
                brandColor: brandColor,
                fillColor: isDark
                    ? const Color(0xFF2C2C2C)
                    : Colors.grey.shade50,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.captchaRequired
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onRefresh,
              child: Container(
                width: 120,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: captchaLoading
                    ? Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: brandColor,
                          ),
                        ),
                      )
                    : captchaImageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          captchaImageBytes!,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.broken_image_outlined,
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade600,
                            size: 22,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.refresh_outlined,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                        size: 22,
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
