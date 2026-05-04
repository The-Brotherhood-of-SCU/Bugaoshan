import 'package:flutter/material.dart';

class NavigationItemData {
  final String id;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget page;

  const NavigationItemData({
    required this.id,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.page,
  });
}
