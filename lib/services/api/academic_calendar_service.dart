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
  static const String _mirrorUrl =
      'https://gh-proxy.com/https://raw.githubusercontent.com/The-Brotherhood-of-SCU/Bugaoshan/refs/heads/main/assets/academic_calendar.json';
  static const String _cacheKey = 'cached_academic_calendar_json';

  AcademicCalendarService(this._prefs, {http.Client? client})
    : _client = client;

  /// Parse a calendar JSON string (supports both compact and expanded formats).
  AcademicCalendarData _parseCalendarJson(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return AcademicCalendarData.fromJson(expandCalendarJson(decoded));
  }

  /// Expand compact format (with eventTypes registry) to the model's expected
  /// expanded format. If already expanded, returns as-is.
  static Map<String, dynamic> expandCalendarJson(Map<String, dynamic> compact) {
    final eventTypes = compact['eventTypes'];
    if (eventTypes == null) return compact;

    final types = eventTypes as Map<String, dynamic>;
    final semesters = (compact['semesters'] as List<dynamic>).map((s) {
      s = s as Map<String, dynamic>;
      final eventsMap = (s['e'] as Map<String, dynamic>?) ?? {};
      final expandedEvents = <Map<String, dynamic>>[];

      for (final entry in eventsMap.entries) {
        final typeInfo = types[entry.key] as Map<String, dynamic>?;
        if (typeInfo == null) continue;

        final event = <String, dynamic>{
          'label': typeInfo['l'],
          'tag': typeInfo['t'],
        };

        final value = entry.value;
        if (value is String) {
          event['date'] = value;
        } else if (value is List && value.length >= 2) {
          event['date'] = value[0];
          event['endDate'] = value[1];
        }

        expandedEvents.add(event);
      }

      return {
        'name': s['n'],
        'startDate': s['s'],
        'totalWeeks': s['w'],
        'events': expandedEvents,
      };
    }).toList();

    return {'semesters': semesters};
  }

  /// 优先本地数据（缓存 → 内置 asset）快速返回，避免首次打开等网络；
  /// 仅当本地无数据（首次安装）时才兜底走网络。
  Future<AcademicCalendarData> fetchCalendarData() async {
    final local = await _loadLocalCalendar();
    if (local != null) return local;

    final client = _client ?? http.Client();
    try {
      for (final url in [_mirrorUrl, _remoteUrl]) {
        final calendar = await _tryFetch(client, url);
        if (calendar != null) return calendar;
      }
    } finally {
      // 仅关闭本次自建的 client；注入的 _client 由注入方管理生命周期。
      if (_client == null) client.close();
    }
    return AcademicCalendarData(semesters: []);
  }

  /// 下拉刷新：仅走网络拉取最新校历，成功写缓存并返回新数据，失败返回 null。
  Future<AcademicCalendarData?> refreshCalendarData() async {
    final client = _client ?? http.Client();
    try {
      for (final url in [_mirrorUrl, _remoteUrl]) {
        final calendar = await _tryFetch(client, url);
        if (calendar != null) return calendar;
      }
    } finally {
      if (_client == null) client.close();
    }
    return null;
  }

  /// 读取本地校历：优先 SharedPreferences 缓存，其次内置 asset。
  /// 两者都不可用时返回 null。
  Future<AcademicCalendarData?> _loadLocalCalendar() async {
    final cached = _prefs.getString(_cacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        return _parseCalendarJson(cached);
      } catch (e) {
        debugPrint(
          'AcademicCalendarService: failed to parse cached calendar: $e',
        );
      }
    }

    try {
      final assetContent = await rootBundle.loadString(
        'assets/academic_calendar.json',
      );
      return _parseCalendarJson(assetContent);
    } catch (e) {
      debugPrint('AcademicCalendarService: failed to load bundled asset: $e');
      return null;
    }
  }

  /// 从 [url] 拉取远程校历；成功时写入缓存并返回，失败返回 null。
  Future<AcademicCalendarData?> _tryFetch(
    http.Client client,
    String url,
  ) async {
    try {
      final response = await client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('semesters')) {
          final calendar = _parseCalendarJson(response.body);
          // 空校历（semesters 为空数组）不写缓存：本地优先策略下写入后
          // 会一直展示「无校历数据」且不再回退到内置 asset，造成污染。
          if (calendar.semesters.isEmpty) return null;
          await _prefs.setString(_cacheKey, response.body);
          return calendar;
        }
      }
    } catch (e) {
      debugPrint(
        'AcademicCalendarService: failed to fetch remote calendar from $url: $e',
      );
    }
    return null;
  }

  /// 解析后的内置校历缓存。rootBundle 只缓存资源的原始字符串，
  /// jsonDecode + expandCalendarJson + 模型构造每次调用都会重跑；
  /// 而 bundle 资源在进程生命周期内不会变，解析一次即可。
  static AcademicCalendarData? _bundledCalendarCache;

  /// Load and parse the bundled academic calendar JSON asset.
  static Future<AcademicCalendarData> loadBundledCalendar() async {
    final cached = _bundledCalendarCache;
    if (cached != null) return cached;

    final assetContent = await rootBundle.loadString(
      'assets/academic_calendar.json',
    );
    final decoded = jsonDecode(assetContent) as Map<String, dynamic>;
    // 只在解析成功后写缓存；抛异常时缓存保持为空，下次调用会重试。
    final data = AcademicCalendarData.fromJson(expandCalendarJson(decoded));
    _bundledCalendarCache = data;
    return data;
  }

  /// 根据课表名称从校历中匹配学期并返回总周数，未匹配则返回 null。
  /// 匹配逻辑：提取学年（如 "2025-2026"）和季节（春/秋），与校历学期名对比。
  static Future<int?> findTotalWeeksFromCalendar(String scheduleName) async {
    try {
      final data = await loadBundledCalendar();

      final yearMatch = RegExp(r'(\d{4})-(\d{4})').firstMatch(scheduleName);
      if (yearMatch == null) return null;

      final academicYear = '${yearMatch.group(1)}-${yearMatch.group(2)}';
      final isSpring = scheduleName.contains('春');
      final isFall = scheduleName.contains('秋');

      for (final semester in data.semesters) {
        if (semester.name.contains(academicYear)) {
          if (isSpring && semester.name.contains('春')) {
            return semester.totalWeeks;
          }
          if (isFall && semester.name.contains('秋')) return semester.totalWeeks;
          if (!isSpring && !isFall) return semester.totalWeeks;
        }
      }
      return null;
    } catch (e) {
      debugPrint(
        'AcademicCalendarService: failed to find matching semester: $e',
      );
      return null;
    }
  }

  /// 根据课表名称从校历中匹配完整的学期信息。
  /// 匹配逻辑与 [findTotalWeeksFromCalendar] 一致，但返回整个 [AcademicCalendarSemester]。
  static Future<AcademicCalendarSemester?> findMatchingSemester(
    String scheduleName,
  ) async {
    try {
      final data = await loadBundledCalendar();

      final yearMatch = RegExp(r'(\d{4})-(\d{4})').firstMatch(scheduleName);
      if (yearMatch == null) return null;

      final academicYear = '${yearMatch.group(1)}-${yearMatch.group(2)}';
      final isSpring = scheduleName.contains('春');
      final isFall = scheduleName.contains('秋');

      for (final semester in data.semesters) {
        if (semester.name.contains(academicYear)) {
          if (isSpring && semester.name.contains('春')) return semester;
          if (isFall && semester.name.contains('秋')) return semester;
          if (!isSpring && !isFall) return semester;
        }
      }
      return null;
    } catch (e) {
      debugPrint(
        'AcademicCalendarService: failed to find matching semester: $e',
      );
      return null;
    }
  }

  CalendarExportPayload genExportPayload(AcademicCalendarSemester semester) {
    final events = <CalendarEventPayload>[];
    for (final event in semester.events) {
      final start = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
        8,
        0,
      );
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
          uid:
              'acad-${semester.name.replaceAll(" ", "_")}-${event.label.replaceAll(" ", "_")}-${event.date.millisecondsSinceEpoch}@bugaoshan',
          structuredLocation: location.structuredLocation,
        ),
      );
    }

    final sanitizedSemesterName = semester.name.replaceAll(
      RegExp(r'[^\w\u4e00-\u9fff.-]'),
      '_',
    );
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
      buffer.writeln(
        'DTSTART;TZID=${event.timeZone}:${_formatIcsDate(event.start)}',
      );
      buffer.writeln(
        'DTEND;TZID=${event.timeZone}:${_formatIcsDate(event.end)}',
      );
      buffer.writeln('SUMMARY:${_escapeIcsText(event.title)}');
      buffer.writeln('LOCATION:${_escapeIcsText(event.location)}');
      if (event.structuredLocation != null) {
        buffer.writeln(
          'GEO:${event.structuredLocation!.latitude};${event.structuredLocation!.longitude}',
        );
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
