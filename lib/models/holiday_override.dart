/// 调休记录：标记某天为放假/调休日
///
/// [active] 表示用户是否将此日设为放假：
/// - `true`：该日放假
/// - `false`（默认）：非放假状态，由用户交互控制
class HolidayOverride {
  final DateTime date;
  final DateTime? makeupDate;
  final bool active;

  HolidayOverride({required this.date, this.makeupDate, this.active = false});

  Map<String, dynamic> toJson() => {
    'date': _fmt(date),
    if (makeupDate != null) 'makeupDate': _fmt(makeupDate!),
    if (!active) 'active': false,
  };

  factory HolidayOverride.fromJson(Map<String, dynamic> json) {
    return HolidayOverride(
      date: DateTime.parse(json['date'] as String),
      makeupDate: json['makeupDate'] != null
          ? DateTime.parse(json['makeupDate'] as String)
          : null,
      active: json['active'] as bool? ?? false,
    );
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
