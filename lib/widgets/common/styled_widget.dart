import 'package:flutter/material.dart';

class ButtonWithMaxWidth extends StatelessWidget {
  final Function() onPressed;
  final Widget child;
  final Widget? icon;

  const ButtonWithMaxWidth({
    required this.child,
    required this.onPressed,
    super.key,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Widget realChild;
    if (icon != null) {
      realChild = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Container(), child, icon!],
      );
    } else {
      realChild = child;
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
          child: realChild,
        ),
      ),
    );
  }
}
