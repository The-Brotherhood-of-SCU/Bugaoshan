import 'package:flutter/material.dart';

class ButtonWithMaxWidth extends StatelessWidget {
  final Function() onPressed;
  final Widget child;
  final Widget icon;

  const ButtonWithMaxWidth({
    required this.child,
    required this.onPressed,
    super.key,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Widget realChild;
    realChild = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Container(), child, icon!],
    );
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
