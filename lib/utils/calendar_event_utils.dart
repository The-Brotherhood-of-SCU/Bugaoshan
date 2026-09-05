import 'dart:convert';

import 'package:crypto/crypto.dart';

class CalendarStructuredLocation {
  final String title;
  final double? latitude;
  final double? longitude;
  final double? radius;

  const CalendarStructuredLocation({
    required this.title,
    this.latitude,
    this.longitude,
    this.radius,
  });

  Map<String, Object> toPlatformJson() {
    return {
      'title': title,
      'latitude': ?latitude,
      'longitude': ?longitude,
      'radius': ?radius,
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
      keywords: ['江安'],
      buildingKeywords: [
        '一教',
        '第一教学楼',
        '启明楼',
        '二教',
        '第二教学楼',
        '综楼',
        '综合楼',
        '综合教学楼',
        '易明楼',
        '综A',
        '综B',
        '综C',
        '二基楼',
        '第二基础',
        '水明楼',
        '文科楼',
        '文襄楼',
        '匹兹堡',
        '灾后',
        '空天',
        '法学院',
        '艺术学院',
        '建环',
        '水利水电',
      ],
    ),
    _CampusGeoReference(
      fullName: '四川大学望江校区',
      keywords: ['望江'],
      buildingKeywords: [
        '基础教学楼',
        '基础教学大楼',
        '基础楼',
        '启秀楼',
        '基A',
        '基B',
        '基C',
        '东三教',
        '东三教学楼',
        '汇文楼',
        '西三教',
        '西五教',
        '泓文楼',
        '物理馆',
        '化学馆',
        '校史馆',
        '水电大楼',
        '水电馆',
        '智行楼',
        '机械大楼',
        '机械馆',
        '纺织楼',
        '化工楼',
        '逸夫科技',
        '工科大楼',
      ],
    ),
    _CampusGeoReference(
      fullName: '四川大学华西校区',
      keywords: ['华西'],
      buildingKeywords: [
        '八教',
        '第八教学楼',
        '启德堂',
        '老八教',
        '九教',
        '第九教学楼',
        '敬德堂',
        '十教',
        '第十教学楼',
        '仁德堂',
        '七教',
        '第七教学楼',
        '志德堂',
        '五教',
        '第五教学楼',
        '六教',
        '第六教学楼',
        '怀德堂',
        '药学大楼',
        '基础医学',
        '公卫大楼',
        '法医大楼',
        '口腔楼',
      ],
    ),
  ];

  static const _buildingLocations = [
    // ═══════════════════════════════════════════════════════════════════
    //  江安校区
    // ═══════════════════════════════════════════════════════════════════
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '第一教学楼A座',
      matchPatterns: ['一教A', '一教 A', '第一教学楼A', '第一教学楼 A', '启明楼A', '启明楼 A'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '第一教学楼B座',
      matchPatterns: ['一教B', '一教 B', '第一教学楼B', '第一教学楼 B', '启明楼B', '启明楼 B'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '第一教学楼C座',
      matchPatterns: ['一教C', '一教 C', '第一教学楼C', '第一教学楼 C', '启明楼C', '启明楼 C'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '第一教学楼D座',
      matchPatterns: ['一教D', '一教 D', '第一教学楼D', '第一教学楼 D', '启明楼D', '启明楼 D'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '第一教学楼',
      matchPatterns: ['一教', '第一教学楼', '启明楼'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '第二教学楼',
      matchPatterns: ['二教', '第二教学楼'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '综合楼A座',
      matchPatterns: ['综A', '综 A', '综合楼A', '综合楼 A', '易明楼A', '易明楼 A'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '逸夫教学楼',
      redirectNote: '综B',
      matchPatterns: ['综B', '综 B', '综合楼B', '综合楼 B', '易明楼B', '易明楼 B'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '逸夫教学楼',
      redirectNote: '综C',
      matchPatterns: ['综C', '综 C', '综合楼C', '综合楼 C', '易明楼C', '易明楼 C'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '逸夫教学楼',
      redirectNote: '综合楼',
      matchPatterns: ['综楼', '综合楼', '综合教学楼', '易明楼', '逸夫教学楼', '逸夫楼'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '第二基础实验大楼',
      matchPatterns: ['二基楼', '第二基础实验', '第二基础', '水明楼'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '文科楼一区',
      matchPatterns: ['文科楼一区', '文科楼1区', '文科楼一', '文科楼1'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '文科楼二区',
      matchPatterns: ['文科楼二区', '文科楼2区', '文科楼二', '文科楼2'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '文科楼三区',
      matchPatterns: ['文科楼三区', '文科楼3区', '文科楼三', '文科楼3'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '文科楼四区',
      matchPatterns: ['文科楼四区', '文科楼4区', '文科楼四', '文科楼4'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '文科楼',
      matchPatterns: ['文科楼', '文襄楼'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '法学院',
      matchPatterns: ['法学院'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '艺术学院',
      matchPatterns: ['艺术学院', '艺术大楼'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '匹兹堡学院',
      matchPatterns: ['匹兹堡'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '灾后重建与管理学院',
      matchPatterns: ['灾后重建', '灾后'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '制造工程实验楼',
      matchPatterns: ['制造工程', '制造梦工厂', '基础力学', '土木结构'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '水利水电实验基地',
      matchPatterns: ['江安水电', '水利水电学院实验'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学江安校区',
      canonicalBuildingName: '江安体育馆',
      matchPatterns: ['江安体育馆', '江安体育', '江安游泳池', '江安网球场', '江安田径场'],
    ),

    // ═══════════════════════════════════════════════════════════════════
    //  望江校区
    // ═══════════════════════════════════════════════════════════════════
    _BuildingGeoReference(
      campusName: '四川大学望江校区',
      canonicalBuildingName: '基础教学楼A座',
      matchPatterns: ['基础教学楼A', '基础教学楼 A', '基教A', '基教 A', '基A', '基 A', '启秀楼A'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学望江校区',
      canonicalBuildingName: '基础教学楼B座',
      matchPatterns: ['基础教学楼B', '基础教学楼 B', '基教B', '基教 B', '基B', '基 B', '启秀楼B'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学望江校区',
      canonicalBuildingName: '基础教学楼C座',
      matchPatterns: ['基础教学楼C', '基础教学楼 C', '基教C', '基教 C', '基C', '基 C', '启秀楼C'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学望江校区',
      canonicalBuildingName: '基础教学楼',
      matchPatterns: ['基础教学楼', '基础教学大楼', '基础楼', '基教', '启秀楼'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学望江校区',
      canonicalBuildingName: '东三教学楼',
      matchPatterns: ['东三教', '东三教学楼', '东三', '汇文楼'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学望江校区',
      canonicalBuildingName: '东一教学楼',
      matchPatterns: ['东一教', '东一教学楼', '东一'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学望江校区',
      canonicalBuildingName: '东二教学楼',
      matchPatterns: ['东二教', '东二教学楼', '东二'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学望江校区',
      canonicalBuildingName: '望江文科楼',
      matchPatterns: ['望江文科楼', '泓文楼'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学望江校区',
      canonicalBuildingName: '物理馆',
      matchPatterns: ['物理馆', '物理楼', '第一理科楼'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学望江校区',
      canonicalBuildingName: '第二理科楼',
      matchPatterns: ['第二理科楼'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学望江校区',
      canonicalBuildingName: '化学馆',
      matchPatterns: ['化学馆', '化学楼'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学望江校区',
      canonicalBuildingName: '水电大楼',
      matchPatterns: ['水电大楼', '水电馆', '智行楼'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学望江校区',
      canonicalBuildingName: '逸夫科技楼',
      matchPatterns: ['逸夫科技楼', '逸夫楼'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学望江校区',
      canonicalBuildingName: '西四教',
      matchPatterns: ['西四教', '西五教', '西三教'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学望江校区',
      canonicalBuildingName: '机电科技楼',
      matchPatterns: ['机械大楼', '机械馆', '机电科技楼'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学望江校区',
      canonicalBuildingName: '纺工楼',
      matchPatterns: ['纺工楼', '纺织楼'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学望江校区',
      canonicalBuildingName: '望江体育馆',
      matchPatterns: ['望江体育馆', '望江游泳池'],
    ),

    // ═══════════════════════════════════════════════════════════════════
    //  华西校区
    // ═══════════════════════════════════════════════════════════════════
    _BuildingGeoReference(
      campusName: '四川大学华西校区',
      canonicalBuildingName: '第八教学楼',
      matchPatterns: ['八教', '第八教学楼', '老八教', '启德堂'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学华西校区',
      canonicalBuildingName: '第九教学楼',
      matchPatterns: ['九教', '第九教学楼', '敬德堂'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学华西校区',
      canonicalBuildingName: '第十教学楼',
      matchPatterns: ['十教', '第十教学楼', '仁德堂'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学华西校区',
      canonicalBuildingName: '第七教学楼',
      matchPatterns: ['七教', '第七教学楼', '志德堂'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学华西校区',
      canonicalBuildingName: '第六教学楼',
      matchPatterns: ['六教', '第六教学楼', '万德堂'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学华西校区',
      canonicalBuildingName: '第五教学楼',
      matchPatterns: ['五教', '第五教学楼', '育德堂'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学华西校区',
      canonicalBuildingName: '第四教学楼',
      matchPatterns: ['四教', '第四教学楼', '合德堂'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学华西校区',
      canonicalBuildingName: '第三教学楼',
      matchPatterns: ['三教', '第三教学楼', '树德堂'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学华西校区',
      canonicalBuildingName: '第二教学楼',
      matchPatterns: ['华西二教', '华西第二教学楼', '懿德堂'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学华西校区',
      canonicalBuildingName: '第一教学楼',
      matchPatterns: ['华西一教', '华西第一教学楼', '嘉德堂'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学华西校区',
      canonicalBuildingName: '办公楼（怀德堂）',
      matchPatterns: ['怀德堂'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学华西校区',
      canonicalBuildingName: '逸夫基础医学楼',
      matchPatterns: ['基础医学', '基础医学大楼', '逸夫基础医学楼'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学华西校区',
      canonicalBuildingName: '法医楼',
      matchPatterns: ['法医大楼', '法医教学楼', '法医楼', '正德楼'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学华西校区',
      canonicalBuildingName: '口腔科研楼',
      matchPatterns: ['口腔楼', '口腔科教楼', '口腔科研楼', '涵德楼'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学华西校区',
      canonicalBuildingName: '药物化学楼',
      matchPatterns: ['药学大楼', '药物化学楼', '药学科教大楼'],
    ),
    _BuildingGeoReference(
      campusName: '四川大学华西校区',
      canonicalBuildingName: '体育馆',
      matchPatterns: ['华西体育馆'],
    ),
  ];

  static CalendarResolvedLocation resolve(
    String rawLocation, {
    String? campusName,
  }) {
    final location = rawLocation.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 1. 优先从 campusName 或 location 中识别目标校区（江安/望江/华西）
    _CampusGeoReference? explicitCampus;
    if (campusName != null && campusName.trim().isNotEmpty) {
      final cName = campusName.trim();
      for (final ref in _campusLocations) {
        if (ref.keywords.any((k) => cName.contains(k))) {
          explicitCampus = ref;
          break;
        }
      }
    }
    if (explicitCampus == null && location.isNotEmpty) {
      for (final ref in _campusLocations) {
        if (ref.keywords.any((k) => location.contains(k))) {
          explicitCampus = ref;
          break;
        }
      }
    }

    // 2. 尝试匹配高精度建筑（OSM 坐标 + 标准建筑全称）
    _BuildingGeoReference? matchedBuilding;
    if (location.isNotEmpty) {
      if (explicitCampus != null) {
        for (final building in _buildingLocations) {
          if (building.campusName == explicitCampus.fullName &&
              building.matches(location)) {
            matchedBuilding = building;
            break;
          }
        }
      } else {
        for (final building in _buildingLocations) {
          if (building.matches(location)) {
            matchedBuilding = building;
            break;
          }
        }
      }
    }

    if (matchedBuilding != null) {
      final fullBuildingName =
          '${matchedBuilding.campusName}${matchedBuilding.canonicalBuildingName}';
      final room = _extractRoomName(location, matchedBuilding);
      final noteSuffix = matchedBuilding.redirectNote != null
          ? ' (${matchedBuilding.redirectNote})'
          : '';
      final title = room.isNotEmpty
          ? '$fullBuildingName · $room$noteSuffix'
          : '$fullBuildingName$noteSuffix';
      return CalendarResolvedLocation(
        title: title,
        structuredLocation: CalendarStructuredLocation(title: title),
      );
    }

    // 3. 若未命中具体建筑，回退到校区级推断
    _CampusGeoReference? campus = explicitCampus;
    if (campus == null && location.isNotEmpty) {
      for (final ref in _campusLocations) {
        if (ref.buildingKeywords.any((b) => location.contains(b))) {
          campus = ref;
          break;
        }
      }
    }

    if (location.isEmpty) {
      if (campus != null) {
        return CalendarResolvedLocation(
          title: campus.fullName,
          structuredLocation: CalendarStructuredLocation(
            title: campus.fullName,
          ),
        );
      }
      return const CalendarResolvedLocation(title: '');
    }

    if (campus == null) {
      return CalendarResolvedLocation(title: location);
    }

    final title = location.contains(campus.fullName)
        ? location
        : '${campus.fullName} · $location';
    return CalendarResolvedLocation(
      title: title,
      structuredLocation: CalendarStructuredLocation(title: title),
    );
  }

  static String _extractRoomName(
    String location,
    _BuildingGeoReference building,
  ) {
    var text = location;

    // 1. 移除校区全称和校区关键字
    for (final campus in _campusLocations) {
      text = text.replaceAll(campus.fullName, ' ');
      for (final k in campus.keywords) {
        text = text.replaceAll(k, ' ');
      }
    }

    // 2. 移除教学楼名称（保留教室编号前的英文字母如 A101, C407, B503）
    final buildingNamesToStrip = <String>{
      building.canonicalBuildingName,
      ...building.matchPatterns,
      '第一教学楼',
      '第二教学楼',
      '第三教学楼',
      '第四教学楼',
      '第五教学楼',
      '第六教学楼',
      '第七教学楼',
      '第八教学楼',
      '第九教学楼',
      '第十教学楼',
      '综合教学楼',
      '综合楼',
      '第二基础实验大楼',
      '第二基础实验楼',
      '第二基础教学楼',
      '第二基础',
      '二基楼',
      '文科楼一区',
      '文科楼二区',
      '文科楼三区',
      '文科楼四区',
      '文科楼',
      '基础教学大楼',
      '基础教学楼',
      '东三教学楼',
      '东一教学楼',
      '东二教学楼',
      '教学楼',
      '实验大楼',
      '实验楼',
      '启明楼',
      '易明楼',
      '水明楼',
      '文襄楼',
      '启秀楼',
      '汇文楼',
      '泓文楼',
      '逸夫教学楼',
      '逸夫科技楼',
      '逸夫楼',
      '启德堂',
      '敬德堂',
      '仁德堂',
      '志德堂',
      '嘉德堂',
      '懿德堂',
      '树德堂',
      '合德堂',
      '育德堂',
      '万德堂',
      '怀德堂',
      '一教',
      '二教',
      '三教',
      '四教',
      '五教',
      '六教',
      '七教',
      '八教',
      '九教',
      '十教',
      '基教',
      '综楼',
      '综',
    }.toList()..sort((a, b) => b.length.compareTo(a.length));

    for (final bName in buildingNamesToStrip) {
      // 若形如 "综C407" / "一教A101"，且 bName 为 "综C" 或 "一教A"，
      // 当后面紧接数字时，只剔除中文前缀，保留 C407 / A101
      final letterMatch = RegExp(r'^(.+?)([A-Za-z])$').firstMatch(bName);
      if (letterMatch != null) {
        final prefix = letterMatch.group(1)!;
        final letter = letterMatch.group(2)!;
        text = text.replaceAllMapped(
          RegExp('${RegExp.escape(prefix)}${RegExp.escape(letter)}(\\d+)'),
          (m) => ' $letter${m.group(1)}',
        );
      }
      text = text.replaceAll(bName, ' ');
    }

    // 移除独立的 "座" / "栋"
    text = text.replaceAll(RegExp(r'[座栋]'), ' ');

    // 3. 清理首尾及连续多余空白和标点
    text = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[·\s\-_:：/、]+|[·\s\-_:：/、]+$'), '')
        .trim();

    // 4. 若只剩下一个单独的座号字母（如原本就是 "一教A" 或 "一教A座" 无房间号），房间号视为空
    if (RegExp(r'^[A-Za-z]$').hasMatch(text)) {
      return '';
    }

    // 5. 若出现重复座号如 "B B503"，合并为 "B503"
    final duplicateLetterMatch = RegExp(
      r'^[A-Za-z]\s+([A-Za-z]\d+.*)$',
    ).firstMatch(text);
    if (duplicateLetterMatch != null) {
      text = duplicateLetterMatch.group(1)!;
    }

    // 6. 若形如 "A 101" 中间有空格，规范化合并为 "A101"
    final letterNumMatch = RegExp(r'^([A-Za-z])\s+(\d+.*)$').firstMatch(text);
    if (letterNumMatch != null) {
      text = '${letterNumMatch.group(1)}${letterNumMatch.group(2)}';
    }

    return text;
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
  final List<String> keywords;
  final List<String> buildingKeywords;

  const _CampusGeoReference({
    required this.fullName,
    required this.keywords,
    this.buildingKeywords = const [],
  });

  bool matches(String text) {
    return keywords.any((keyword) => text.contains(keyword)) ||
        buildingKeywords.any((building) => text.contains(building));
  }
}

class _BuildingGeoReference {
  final String campusName;
  final String canonicalBuildingName;
  final List<String> matchPatterns;
  final String? redirectNote;

  const _BuildingGeoReference({
    required this.campusName,
    required this.canonicalBuildingName,
    required this.matchPatterns,
    this.redirectNote,
  });

  bool matches(String text) {
    return matchPatterns.any((pattern) => text.contains(pattern));
  }
}
