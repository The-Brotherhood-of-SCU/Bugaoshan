class ClassroomCampus {
  final String campusName;
  final String campusNumber;

  ClassroomCampus({required this.campusName, required this.campusNumber});

  factory ClassroomCampus.fromJson(Map<String, dynamic> json) {
    return ClassroomCampus(
      campusName: json['campusName'] as String,
      campusNumber: json['campusNumber'] as String,
    );
  }
}

class ClassroomBuilding {
  final String campusNumber;
  final String teachingBuildingNumber;
  final String teachingBuildingName;

  ClassroomBuilding({
    required this.campusNumber,
    required this.teachingBuildingNumber,
    required this.teachingBuildingName,
  });

  factory ClassroomBuilding.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as Map<String, dynamic>;
    return ClassroomBuilding(
      campusNumber: id['campusNumber'] as String,
      teachingBuildingNumber: id['teachingBuildingNumber'].toString(),
      teachingBuildingName: json['teachingBuildingName'] as String,
    );
  }
}

class ClassroomType {
  final String classroomtypecode;
  final String classroomtypename;

  ClassroomType({
    required this.classroomtypecode,
    required this.classroomtypename,
  });

  factory ClassroomType.fromJson(Map<String, dynamic> json) {
    return ClassroomType(
      classroomtypecode: json['classroomtypecode'] as String,
      classroomtypename: json['classroomtypename'] as String,
    );
  }
}

class ClassroomInfo {
  final String classroomName;
  final String classroomStatusCode;
  final String classroomTypeCode;
  final String campusNumber;
  final String classroomNumber;
  final String teachingBuildingNumber;
  final int placeNum;
  final String remark;
  final String sfkjy;

  ClassroomInfo({
    required this.classroomName,
    required this.classroomStatusCode,
    required this.classroomTypeCode,
    required this.campusNumber,
    required this.classroomNumber,
    required this.teachingBuildingNumber,
    required this.placeNum,
    required this.remark,
    required this.sfkjy,
  });

  factory ClassroomInfo.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as Map<String, dynamic>;
    return ClassroomInfo(
      classroomName: json['classroomName'] as String,
      classroomStatusCode: json['classroomStatusCode'] as String? ?? '',
      classroomTypeCode: json['classroomTypeCode'] as String? ?? '',
      campusNumber: id['campusNumber'] as String,
      classroomNumber: id['classroomNumber'] as String,
      teachingBuildingNumber: id['teachingBuildingNumber'] as String,
      placeNum: int.tryParse(json['placeNum']?.toString() ?? '0') ?? 0,
      remark: json['remark'] as String? ?? '',
      sfkjy: json['sfkjy'] as String? ?? '',
    );
  }
}

class ClassroomTimeSlot {
  final String campusNumber;
  final String teachingBuildingNumber;
  final String classroomNumber;
  final int xq;
  final int sessionstart;
  final int continuingsession;
  final String timestatenumber;
  final String occupancymoduleId;

  ClassroomTimeSlot({
    required this.campusNumber,
    required this.teachingBuildingNumber,
    required this.classroomNumber,
    required this.xq,
    required this.sessionstart,
    required this.continuingsession,
    required this.timestatenumber,
    required this.occupancymoduleId,
  });

  factory ClassroomTimeSlot.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as Map<String, dynamic>;
    return ClassroomTimeSlot(
      campusNumber: id['campusNumber'] as String,
      teachingBuildingNumber: id['teachingBuildingNumber'] as String,
      classroomNumber: id['classroomNumber'] as String,
      xq: id['xq'] as int,
      sessionstart: id['sessionstart'] as int,
      continuingsession: json['continuingsession'] as int? ?? 1,
      timestatenumber: json['timestatenumber'] as String? ?? '',
      occupancymoduleId: json['occupancymoduleId'] as String? ?? '',
    );
  }

  ClassroomPeriodStatus get status {
    switch (occupancymoduleId) {
      case '06':
        return ClassroomPeriodStatus.inClass;
      case '07':
        return ClassroomPeriodStatus.exam;
      case '14':
        return ClassroomPeriodStatus.experiment;
      case 'room':
        return ClassroomPeriodStatus.borrowed;
      default:
        return ClassroomPeriodStatus.free;
    }
  }
}

enum ClassroomPeriodStatus { free, inClass, exam, experiment, borrowed }

class ClassroomQueryResult {
  final List<ClassroomInfo> classrooms;
  final List<ClassroomTimeSlot> classroomTime;
  final String date;
  final int jxzc;

  ClassroomQueryResult({
    required this.classrooms,
    required this.classroomTime,
    required this.date,
    required this.jxzc,
  });

  factory ClassroomQueryResult.fromJson(Map<String, dynamic> json) {
    return ClassroomQueryResult(
      classrooms:
          (json['classrooms'] as List?)
              ?.map((e) => ClassroomInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      classroomTime:
          (json['classroomTime'] as List?)
              ?.map(
                (e) => ClassroomTimeSlot.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      date: json['date'] as String? ?? '',
      jxzc: json['jxzc'] as int? ?? 0,
    );
  }

  List<ClassroomTimeSlot> slotsFor(String classroomNumber) =>
      classroomTime.where((s) => s.classroomNumber == classroomNumber).toList();

  Map<int, ClassroomPeriodStatus> periodStatusMap(String classroomNumber) {
    final map = <int, ClassroomPeriodStatus>{};
    for (final slot in slotsFor(classroomNumber)) {
      map[slot.sessionstart] = slot.status;
    }
    return map;
  }
}
