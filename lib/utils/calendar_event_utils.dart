import 'dart:convert';

import 'package:crypto/crypto.dart';

class CalendarStructuredLocation {
  final String title;
  final double latitude;
  final double longitude;
  final double radius;

  const CalendarStructuredLocation({
    required this.title,
    required this.latitude,
    required this.longitude,
    this.radius = 250,
  });

  Map<String, Object> toPlatformJson() {
    return {
      'title': title,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
    };
  }
}

class CalendarResolvedLocation {
  final String title;
  final CalendarStructuredLocation? structuredLocation;

  const CalendarResolvedLocation({
    required this.title,
    this.structuredLocation,
  });
}

class CalendarExportPayload {
  final String fileName;
  final String icsContent;
  final List<Map<String, Object>> events;

  const CalendarExportPayload({
    required this.fileName,
    required this.icsContent,
    required this.events,
  });
}

class CalendarLocationMapper {
  const CalendarLocationMapper._();

  static const _campusLocations = [
    _CampusGeoReference(
      fullName: '四川大学江安校区',
      latitude: 30.5601863,
      longitude: 103.9973029,
      keywords: ['江安'],
    ),
    _CampusGeoReference(
      fullName: '四川大学望江校区',
      latitude: 30.6335392,
      longitude: 104.0815556,
      keywords: ['望江'],
    ),
    _CampusGeoReference(
      fullName: '四川大学华西校区',
      latitude: 30.6425541,
      longitude: 104.0673888,
      keywords: ['华西'],
    ),
  ];

  static CalendarResolvedLocation resolve(String rawLocation) {
    final location = rawLocation.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (location.isEmpty) {
      return CalendarResolvedLocation(title: location);
    }

    final campus = _campusForLocation(location);
    if (campus == null) {
      return CalendarResolvedLocation(title: location);
    }

    final title = location.contains(campus.fullName)
        ? location
        : '${campus.fullName} · $location';
    return CalendarResolvedLocation(
      title: title,
      structuredLocation: CalendarStructuredLocation(
        title: title,
        latitude: campus.latitude,
        longitude: campus.longitude,
      ),
    );
  }

  static _CampusGeoReference? _campusForLocation(String location) {
    for (final campus in _campusLocations) {
      if (campus.keywords.any((keyword) => location.contains(keyword))) {
        return campus;
      }
    }
    return null;
  }
}

class CalendarEventIdentity {
  const CalendarEventIdentity._();

  static const _domain = 'bugaoshan';

  static String courseUid({required String courseId, required int week}) {
    // Keep the legacy course UID shape so existing imported course events can
    // still be matched by calendar apps and the iOS local UID map.
    return '${courseId}_$week@$_domain';
  }

  static String examUid({required String name}) {
    // Exam de-duplication follows the authoritative course name only; UI state
    // such as "past" and the display-only finished marker must not affect it.
    final key = ['exam', normalizeName(name)].join('|');
    final digest = sha1.convert(utf8.encode(key)).toString().substring(0, 24);
    return 'exam-$digest@$_domain';
  }

  static String normalizeName(String name) {
    return name
        .replaceAll(RegExp(r'\s*[（(]\s*已结束\s*[）)]\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class CalendarEventPayload {
  final DateTime start;
  final DateTime end;
  final String title;
  final String location;
  final String description;
  final String uid;
  final String timeZone;
  final CalendarStructuredLocation? structuredLocation;

  const CalendarEventPayload({
    required this.start,
    required this.end,
    required this.title,
    required this.location,
    required this.description,
    required this.uid,
    this.timeZone = 'Asia/Shanghai',
    this.structuredLocation,
  });

  Map<String, Object> toPlatformJson() {
    final payload = <String, Object>{
      'title': title,
      'location': location,
      'notes': description,
      'uid': uid,
      'timeZone': timeZone,
      'start': _dateComponents(start),
      'end': _dateComponents(end),
    };
    final structuredLocation = this.structuredLocation;
    if (structuredLocation != null) {
      payload['structuredLocation'] = structuredLocation.toPlatformJson();
    }
    return payload;
  }

  static Map<String, int> _dateComponents(DateTime dateTime) {
    return {
      'year': dateTime.year,
      'month': dateTime.month,
      'day': dateTime.day,
      'hour': dateTime.hour,
      'minute': dateTime.minute,
    };
  }
}

class _CampusGeoReference {
  final String fullName;
  final double latitude;
  final double longitude;
  final List<String> keywords;

  const _CampusGeoReference({
    required this.fullName,
    required this.latitude,
    required this.longitude,
    required this.keywords,
  });
}
