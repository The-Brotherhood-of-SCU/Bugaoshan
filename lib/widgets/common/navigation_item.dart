import 'package:flutter/material.dart';

class NavigationItemData {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget page;

  const NavigationItemData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.page,
  });
}
