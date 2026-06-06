/// 第二课堂数据模型
library;

class CyclActivity {
  final String? activityId;
  final String activityLibraryId;
  final String orgNo;
  final String name;
  final String activityName;
  final String level;
  final String star;
  final List<String> quality;
  final double classHour;
  final String? describe;
  final String poster;
  final String? startTime;
  final String? endTime;
  final String? enrollStartTime;
  final String? enrollEndTime;
  final int quota;
  final String activityTarget;
  final String? activityTargetName;
  final String isSignIn;
  final String isSignOut;
  final String? mobile;
  final String? activityAddress;
  final String? activityLon;
  final String? activityLat;
  final String status;
  final String? statusName;
  final String orgName;
  final String? levelName;
  final String? starName;
  final String? qualityName;
  final bool doing;
  final bool subscribed;

  CyclActivity({
    this.activityId,
    required this.activityLibraryId,
    required this.orgNo,
    required this.name,
    required this.activityName,
    required this.level,
    required this.star,
    required this.quality,
    required this.classHour,
    this.describe,
    required this.poster,
    this.startTime,
    this.endTime,
    this.enrollStartTime,
    this.enrollEndTime,
    required this.quota,
    required this.activityTarget,
    this.activityTargetName,
    required this.isSignIn,
    required this.isSignOut,
    this.mobile,
    this.activityAddress,
    this.activityLon,
    this.activityLat,
    required this.status,
    this.statusName,
    required this.orgName,
    this.levelName,
    this.starName,
    this.qualityName,
    required this.doing,
    required this.subscribed,
  });

  factory CyclActivity.fromJson(Map<String, dynamic> json) {
    return CyclActivity(
      activityId: json['activityId']?.toString(),
      activityLibraryId: json['activityLibraryId']?.toString() ?? '',
      orgNo: json['orgNo']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      activityName: json['activityName']?.toString() ?? '',
      level: json['level']?.toString() ?? '',
      star: json['star']?.toString() ?? '',
      quality:
          (json['quality'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      classHour: (json['classHour'] as num?)?.toDouble() ?? 0.0,
      describe: json['describe']?.toString(),
      poster: json['poster']?.toString() ?? '',
      startTime: json['startTime']?.toString(),
      endTime: json['endTime']?.toString(),
      enrollStartTime: json['enrollStartTime']?.toString(),
      enrollEndTime: json['enrollEndTime']?.toString(),
      quota: json['quota'] is int
          ? json['quota']
          : int.tryParse(json['quota']?.toString() ?? '0') ?? 0,
      activityTarget: json['activityTarget']?.toString() ?? '',
      activityTargetName: json['activityTargetName']?.toString(),
      isSignIn: json['isSignIn']?.toString() ?? '0',
      isSignOut: json['isSignOut']?.toString() ?? '0',
      mobile: json['mobile']?.toString(),
      activityAddress: json['activityAddress']?.toString(),
      activityLon: json['activityLon']?.toString(),
      activityLat: json['activityLat']?.toString(),
      status: json['status']?.toString() ?? '',
      statusName: json['statusName']?.toString(),
      orgName: json['orgName']?.toString() ?? '',
      levelName: json['levelName']?.toString(),
      starName: json['starName']?.toString(),
      qualityName: json['qualityName']?.toString(),
      doing: json['doing'] == true,
      subscribed: json['subscribed'] == true,
    );
  }
}

class CyclOrg {
  final String orgNo;
  final String orgName;
  final String? parentNo;
  CyclOrg({required this.orgNo, required this.orgName, this.parentNo});
  factory CyclOrg.fromJson(Map<String, dynamic> json) => CyclOrg(
    orgNo: json['orgNo']?.toString() ?? '',
    orgName: json['orgName']?.toString() ?? '',
    parentNo: json['parentNo']?.toString(),
  );
}

class CyclScoreType {
  final String? id;
  final String? groupId;
  final String name;
  final String value;
  final String? code;
  CyclScoreType({
    this.id,
    this.groupId,
    required this.name,
    required this.value,
    this.code,
  });
  factory CyclScoreType.fromJson(Map<String, dynamic> json) => CyclScoreType(
    id: json['id']?.toString(),
    groupId: json['groupId']?.toString(),
    name: json['name']?.toString() ?? '',
    value: json['value']?.toString() ?? '',
    code: json['code']?.toString(),
  );
}

class CyclDict {
  final String code;
  final String name;
  final String? groupCode;
  CyclDict({required this.code, required this.name, this.groupCode});
  factory CyclDict.fromJson(Map<String, dynamic> json) => CyclDict(
    code: json['code']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    groupCode: json['groupCode']?.toString(),
  );
}

class CcylUser {
  final String id;
  final String userName;
  final String realname;
  final String orgName;
  final String? mobile;
  final String? headImgUrl;
  final String? majorName;
  final String? classes;
  final String? grade;
  CcylUser({
    required this.id,
    required this.userName,
    required this.realname,
    required this.orgName,
    this.mobile,
    this.headImgUrl,
    this.majorName,
    this.classes,
    this.grade,
  });
  factory CcylUser.fromJson(Map<String, dynamic> json) => CcylUser(
    id: json['id']?.toString() ?? '',
    userName: json['userName']?.toString() ?? '',
    realname: json['realname']?.toString() ?? '',
    orgName: json['orgName']?.toString() ?? '',
    mobile: json['mobile']?.toString(),
    headImgUrl: json['headImgUrl']?.toString(),
    majorName: json['majorName']?.toString(),
    classes: json['classes']?.toString(),
    grade: json['grade']?.toString(),
  );
}

class CyclCredit {
  final String creditId;
  final String? reportId;
  final String userId;
  final String userName;
  final String activityName;
  final String? activityType;
  final double classHour;
  final String scoreType;
  final String? classCredit;
  final String creditStatus;
  final String? comment;
  final String createTime;
  final String? updateTime;
  final String scoreTypeName;
  final String? activityLevel;
  final String? activityLevelName;
  final String? activityStar;
  final String creditStatusName;
  CyclCredit({
    required this.creditId,
    this.reportId,
    required this.userId,
    required this.userName,
    required this.activityName,
    this.activityType,
    required this.classHour,
    required this.scoreType,
    this.classCredit,
    required this.creditStatus,
    this.comment,
    required this.createTime,
    this.updateTime,
    required this.scoreTypeName,
    this.activityLevel,
    this.activityLevelName,
    this.activityStar,
    required this.creditStatusName,
  });
  factory CyclCredit.fromJson(Map<String, dynamic> json) => CyclCredit(
    creditId: json['creditId']?.toString() ?? '',
    reportId: json['reportId']?.toString(),
    userId: json['userId']?.toString() ?? '',
    userName: json['userName']?.toString() ?? '',
    activityName: json['activityName']?.toString() ?? '',
    activityType: json['activityType']?.toString(),
    classHour: (json['classHour'] as num?)?.toDouble() ?? 0.0,
    scoreType: json['scoreType']?.toString() ?? '',
    classCredit: json['classCredit']?.toString(),
    creditStatus: json['creditStatus']?.toString() ?? '',
    comment: json['comment']?.toString(),
    createTime: json['createTime']?.toString() ?? '',
    updateTime: json['updateTime']?.toString(),
    scoreTypeName: json['scoreTypeName']?.toString() ?? '',
    activityLevel: json['activityLevel']?.toString(),
    activityLevelName: json['activityLevelName']?.toString(),
    activityStar: json['activityStar']?.toString(),
    creditStatusName: json['creditStatusName']?.toString() ?? '',
  );
}

class CyclActivityLib {
  final String activityLibraryId;
  final String orgNo;
  final String name;
  final String level;
  final String star;
  final String? activityType;
  final List<String> quality;
  final double classHour;
  final String? classCredit;
  final String? avgRank;
  final String? isPrize;
  final int prizeClassHour;
  final String? describe;
  final String scoringMode;
  final String creator;
  final String createTime;
  final String? updater;
  final String? updateTime;
  final bool isDelete;
  final String liablePer;
  final String liablePerPhone;
  final String liableTer;
  final String liableTerPhone;
  final double instructorHour;
  final String orgName;
  final String? levelName;
  final String? starName;
  final String? activityTypeName;
  final String? doing;
  final String? subscribed;
  final String? scoreTypeNames;
  final String? qualityName;
  CyclActivityLib({
    required this.activityLibraryId,
    required this.orgNo,
    required this.name,
    required this.level,
    required this.star,
    this.activityType,
    required this.quality,
    required this.classHour,
    this.classCredit,
    this.avgRank,
    this.isPrize,
    required this.prizeClassHour,
    this.describe,
    required this.scoringMode,
    required this.creator,
    required this.createTime,
    this.updater,
    this.updateTime,
    required this.isDelete,
    required this.liablePer,
    required this.liablePerPhone,
    required this.liableTer,
    required this.liableTerPhone,
    required this.instructorHour,
    required this.orgName,
    this.levelName,
    this.starName,
    this.activityTypeName,
    this.doing,
    this.subscribed,
    this.scoreTypeNames,
    this.qualityName,
  });
  factory CyclActivityLib.fromJson(Map<String, dynamic> json) =>
      CyclActivityLib(
        activityLibraryId: json['activityLibraryId']?.toString() ?? '',
        orgNo: json['orgNo']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        level: json['level']?.toString() ?? '',
        star: json['star']?.toString() ?? '',
        activityType: json['activityType']?.toString(),
        quality:
            (json['quality'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        classHour: (json['classHour'] as num?)?.toDouble() ?? 0.0,
        classCredit: json['classCredit']?.toString(),
        avgRank: json['avgRank']?.toString(),
        isPrize: json['isPrize']?.toString(),
        prizeClassHour: json['prizeClassHour'] is int
            ? json['prizeClassHour']
            : int.tryParse(json['prizeClassHour']?.toString() ?? '0') ?? 0,
        describe: json['describe']?.toString(),
        scoringMode: json['scoringMode']?.toString() ?? '',
        creator: json['creator']?.toString() ?? '',
        createTime: json['createTime']?.toString() ?? '',
        updater: json['updater']?.toString(),
        updateTime: json['updateTime']?.toString(),
        isDelete: json['isDelete'] == true,
        liablePer: json['liablePer']?.toString() ?? '',
        liablePerPhone: json['liablePerPhone']?.toString() ?? '',
        liableTer: json['liableTer']?.toString() ?? '',
        liableTerPhone: json['liableTerPhone']?.toString() ?? '',
        instructorHour: (json['instructorHour'] as num?)?.toDouble() ?? 0.0,
        orgName: json['orgName']?.toString() ?? '',
        levelName: json['levelName']?.toString(),
        starName: json['starName']?.toString(),
        activityTypeName: json['activityTypeName']?.toString(),
        doing: json['doing']?.toString(),
        subscribed: json['subscribed']?.toString(),
        scoreTypeNames: json['scoreTypeNames']?.toString(),
        qualityName: json['qualityName']?.toString(),
      );
}
