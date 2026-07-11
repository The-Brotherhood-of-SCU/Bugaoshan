// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'academic_calendar.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AcademicCalendarEvent _$AcademicCalendarEventFromJson(
  Map<String, dynamic> json,
) => AcademicCalendarEvent(
  date: const _DateConverter().fromJson(json['date'] as String),
  endDate: const _NullableDateConverter().fromJson(json['endDate'] as String?),
  label: json['label'] as String? ?? '',
  tag: json['tag'] as String? ?? 'event',
);

Map<String, dynamic> _$AcademicCalendarEventToJson(
  AcademicCalendarEvent instance,
) => <String, dynamic>{
  'date': const _DateConverter().toJson(instance.date),
  'endDate': const _NullableDateConverter().toJson(instance.endDate),
  'label': instance.label,
  'tag': instance.tag,
};

AcademicCalendarSemester _$AcademicCalendarSemesterFromJson(
  Map<String, dynamic> json,
) => AcademicCalendarSemester(
  name: json['name'] as String,
  startDate: const _DateConverter().fromJson(json['startDate'] as String),
  totalWeeks: (json['totalWeeks'] as num?)?.toInt() ?? 20,
  events:
      (json['events'] as List<dynamic>?)
          ?.map(
            (e) => AcademicCalendarEvent.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      [],
);

Map<String, dynamic> _$AcademicCalendarSemesterToJson(
  AcademicCalendarSemester instance,
) => <String, dynamic>{
  'name': instance.name,
  'startDate': const _DateConverter().toJson(instance.startDate),
  'totalWeeks': instance.totalWeeks,
  'events': instance.events,
};

AcademicCalendarData _$AcademicCalendarDataFromJson(
  Map<String, dynamic> json,
) => AcademicCalendarData(
  semesters:
      (json['semesters'] as List<dynamic>?)
          ?.map(
            (e) => AcademicCalendarSemester.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      [],
);

Map<String, dynamic> _$AcademicCalendarDataToJson(
  AcademicCalendarData instance,
) => <String, dynamic>{'semesters': instance.semesters};
