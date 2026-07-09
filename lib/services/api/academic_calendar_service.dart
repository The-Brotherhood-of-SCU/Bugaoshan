import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/models/academic_calendar.dart';
import 'package:bugaoshan/utils/calendar_event_utils.dart';

class AcademicCalendarService {
  final SharedPreferences _prefs;
  final http.Client? _client;

  static const String _remoteUrl =
      'https://raw.githubusercontent.com/The-Brotherhood-of-SCU/Bugaoshan/main/assets/academic_calendar.json';
  static const String _cacheKey = 'cached_academic_calendar_json';

  AcademicCalendarService(this._prefs, {http.Client? client}) : _client = client;

  Future<AcademicCalendarData> fetchCalendarData() async {
    try {
      final client = _client ?? http.Client();
      final response = await client.get(Uri.parse(_remoteUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('semesters')) {
          await _prefs.setString(_cacheKey, response.body);
          return AcademicCalendarData.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('AcademicCalendarService: failed to fetch remote calendar: $e');
    }

    final cached = _prefs.getString(_cacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        return AcademicCalendarData.fromJsonString(cached);
      } catch (e) {
        debugPrint('AcademicCalendarService: failed to parse cached calendar: $e');
      }
    }

    try {
      final assetContent = await rootBundle.loadString('assets/academic_calendar.json');
      return AcademicCalendarData.fromJsonString(assetContent);
    } catch (e) {
      debugPrint('AcademicCalendarService: failed to load bundled asset: $e');
      return AcademicCalendarData(semesters: []);
    }
  }

  CalendarExportPayload genExportPayload(AcademicCalendarSemester semester) {
    final events = <CalendarEventPayload>[];
    for (final event in semester.events) {
      final start = DateTime(event.date.year, event.date.month, event.date.day, 8, 0);
      final lastDay = event.endDate ?? event.date;
      final end = DateTime(lastDay.year, lastDay.month, lastDay.day, 18, 0);
      final location = CalendarLocationMapper.resolve('四川大学');
      
      events.add(
        CalendarEventPayload(
          start: start,
          end: end,
          title: event.label,
          location: location.title,
          description: '四川大学官方校历日程\n类型: ${event.tag}',
          uid: 'acad-${semester.name.replaceAll(" ", "_")}-${event.label.replaceAll(" ", "_")}-${event.date.millisecondsSinceEpoch}@bugaoshan',
          structuredLocation: location.structuredLocation,
        ),
      );
    }

    final sanitizedSemesterName = semester.name.replaceAll(RegExp(r'[^\w\u4e00-\u9fff.-]'), '_');
    return CalendarExportPayload(
      fileName: 'SCU_Calendar_$sanitizedSemesterName.ics',
      icsContent: _genCalendarIcs(events),
      events: events.map((e) => e.toPlatformJson()).toList(),
    );
  }

  String _genCalendarIcs(Iterable<CalendarEventPayload> events) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Bugaoshan//Academic Calendar//EN');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');
    buffer.writeln('X-WR-TIMEZONE:Asia/Shanghai');
    buffer.writeln('BEGIN:VTIMEZONE');
    buffer.writeln('TZID:Asia/Shanghai');
    buffer.writeln('BEGIN:STANDARD');
    buffer.writeln('TZOFFSETFROM:+0800');
    buffer.writeln('TZOFFSETTO:+0800');
    buffer.writeln('TZNAME:CST');
    buffer.writeln('DTSTART:19700101T000000');
    buffer.writeln('RRULE:FREQ=YEARLY;BYDAY=1SU;BYMONTH=3');
    buffer.writeln('END:STANDARD');
    buffer.writeln('BEGIN:DAYLIGHT');
    buffer.writeln('TZOFFSETFROM:+0800');
    buffer.writeln('TZOFFSETTO:+0800');
    buffer.writeln('TZNAME:CST');
    buffer.writeln('DTSTART:19700101T000000');
    buffer.writeln('RRULE:FREQ=YEARLY;BYDAY=1SU;BYMONTH=11');
    buffer.writeln('END:DAYLIGHT');
    buffer.writeln('END:VTIMEZONE');

    for (final event in events) {
      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('DTSTART;TZID=${event.timeZone}:${_formatIcsDate(event.start)}');
      buffer.writeln('DTEND;TZID=${event.timeZone}:${_formatIcsDate(event.end)}');
      buffer.writeln('SUMMARY:${_escapeIcsText(event.title)}');
      buffer.writeln('LOCATION:${_escapeIcsText(event.location)}');
      if (event.structuredLocation != null) {
        buffer.writeln('GEO:${event.structuredLocation!.latitude};${event.structuredLocation!.longitude}');
      }
      buffer.writeln('DESCRIPTION:${_escapeIcsText(event.description)}');
      buffer.writeln('UID:${event.uid}');
      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  String _formatIcsDate(DateTime dt) {
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}'
        'T${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}00';
  }

  String _escapeIcsText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('\n', '\\n')
        .replaceAll(',', '\\,')
        .replaceAll(';', '\\;');
  }
}
