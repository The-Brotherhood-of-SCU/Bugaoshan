import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// 登录页底部免责声明（安全/隐私提示）。
class ScuLoginDisclaimer extends StatelessWidget {
  const ScuLoginDisclaimer({
    super.key,
    required this.l10n,
    required this.isDark,
  });

  final AppLocalizations l10n;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 12,
      color: isDark ? Colors.white38 : Colors.grey.shade500,
      height: 1.4,
    );
    final bulletStyle = TextStyle(
      fontSize: 12,
      color: isDark ? Colors.white24 : Colors.grey.shade400,
      height: 1.4,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('· ', style: bulletStyle),
            Flexible(child: Text(l10n.scuLoginDisclaimerPwd, style: style)),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('· ', style: bulletStyle),
            Flexible(child: Text(l10n.scuLoginDisclaimerOcr, style: style)),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('· ', style: bulletStyle),
            Flexible(child: Text(l10n.scuLoginDisclaimerPrivacy, style: style)),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('· ', style: bulletStyle),
            Flexible(child: Text(l10n.scuLoginPasswordHint, style: style)),
          ],
        ),
      ],
    );
  }
}
