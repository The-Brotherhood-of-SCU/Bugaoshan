import 'package:bugaoshan/widgets/adaptive/adaptive_glass_controls.dart';
import 'package:flutter/material.dart';

class ButtonWithMaxWidth extends StatelessWidget {
  final Function() onPressed;
  final Widget child;
  final Widget icon;
  final String label;
  final String? symbol;

  const ButtonWithMaxWidth({
    required this.child,
    required this.onPressed,
    super.key,
    required this.icon,
    required this.label,
    this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    Widget realChild;
    realChild = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: child),
        icon,
      ],
    );
    return SizedBox(
      width: double.infinity,
      child: AdaptiveGlassButton(
        label: label,
        onPressed: onPressed,
        symbol: symbol,
        fallback: ElevatedButton(
          onPressed: onPressed,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
            child: realChild,
          ),
        ),
      ),
    );
  }
}
