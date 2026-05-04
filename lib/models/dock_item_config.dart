import 'package:flutter/material.dart';
import 'package:bugaoshan/utils/constants.dart';

class DockItemConfig {
  final String id;
  final int iconCodePoint;
  final int selectedIconCodePoint;
  final String labelKey;
  final bool isVisible;
  final int sortOrder;
  final bool isDeletable;

  const DockItemConfig({
    required this.id,
    required this.iconCodePoint,
    required this.selectedIconCodePoint,
    required this.labelKey,
    required this.isVisible,
    required this.sortOrder,
    this.isDeletable = true,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  IconData get selectedIcon =>
      IconData(selectedIconCodePoint, fontFamily: 'MaterialIcons');

  DockItemConfig copyWith({
    String? id,
    int? iconCodePoint,
    int? selectedIconCodePoint,
    String? labelKey,
    bool? isVisible,
    int? sortOrder,
    bool? isDeletable,
  }) {
    return DockItemConfig(
      id: id ?? this.id,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      selectedIconCodePoint:
          selectedIconCodePoint ?? this.selectedIconCodePoint,
      labelKey: labelKey ?? this.labelKey,
      isVisible: isVisible ?? this.isVisible,
      sortOrder: sortOrder ?? this.sortOrder,
      isDeletable: isDeletable ?? this.isDeletable,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'iconCodePoint': iconCodePoint,
        'selectedIconCodePoint': selectedIconCodePoint,
        'labelKey': labelKey,
        'isVisible': isVisible,
        'sortOrder': sortOrder,
        'isDeletable': isDeletable,
      };

  factory DockItemConfig.fromJson(Map<String, dynamic> json) =>
      DockItemConfig(
        id: json['id'] as String,
        iconCodePoint: json['iconCodePoint'] as int,
        selectedIconCodePoint: json['selectedIconCodePoint'] as int,
        labelKey: json['labelKey'] as String,
        isVisible: json['isVisible'] as bool,
        sortOrder: json['sortOrder'] as int,
        isDeletable: json['isDeletable'] as bool? ?? true,
      );
}

List<DockItemConfig> defaultDockItems() => [
      DockItemConfig(
        id: dockIdCourse,
        iconCodePoint: Icons.menu_book_outlined.codePoint,
        selectedIconCodePoint: Icons.menu_book.codePoint,
        labelKey: dockIdCourse,
        isVisible: true,
        sortOrder: 0,
      ),
      DockItemConfig(
        id: dockIdCampus,
        iconCodePoint: Icons.school_outlined.codePoint,
        selectedIconCodePoint: Icons.school.codePoint,
        labelKey: dockIdCampus,
        isVisible: true,
        sortOrder: 1,
      ),
      DockItemConfig(
        id: dockIdProfile,
        iconCodePoint: Icons.person_outlined.codePoint,
        selectedIconCodePoint: Icons.person.codePoint,
        labelKey: dockIdProfile,
        isVisible: true,
        sortOrder: 2,
        isDeletable: false,
      ),
    ];
