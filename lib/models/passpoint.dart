/// 校园网无感认证（passpoint）相关的强类型模型。
///
/// 对应后勤 newservice 平台 `site/passpoint/*` 接口的返回结构
/// （已通过真实抓包确认字段）。
library;

/// 无感设备列表项。
///
/// 对应 `query-user-mab-info` 返回的 `d.data[]` 元素。
///
/// 注意：服务端返回的 `macExpireTime` 是**到期日期字符串**
/// （`YYYY-MM-DD`，例如添加 1 天有效期后返回 `2026-09-02`），
/// 并非天数；无法解析（如空串 / `0`，对应"最长有效期 6 年"）时为 null。
class PasspointDevice {
  final String userMac;

  /// 到期日期；`null` 表示无法解析（典型为「最长有效期 6 年」）。
  final DateTime? macExpireTime;
  final String defaultServiceName;
  final bool isOnline;

  const PasspointDevice({
    required this.userMac,
    required this.macExpireTime,
    required this.defaultServiceName,
    required this.isOnline,
  });

  factory PasspointDevice.fromJson(Map<String, dynamic> json) {
    return PasspointDevice(
      userMac: json['userMac']?.toString() ?? '',
      macExpireTime: _parseExpireTime(json['macExpireTime']),
      defaultServiceName: json['defaultServiceName']?.toString() ?? '',
      isOnline:
          json['isOnline'] == true ||
          json['isOnline']?.toString() == '1' ||
          json['isOnline']?.toString() == 'true',
    );
  }

  /// 解析服务端到期日期字符串（`YYYY-MM-DD`）；空值 / 非法值返回 null。
  static DateTime? _parseExpireTime(Object? value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

/// 校园网账户信息。
///
/// 对应 `query-user` 返回的 `d.queryUserResult.data`。
class PasspointUserInfo {
  final String userId;
  final String userName;
  final String userGroupName;
  final int accountState;
  final String mobile;
  final String email;

  const PasspointUserInfo({
    required this.userId,
    required this.userName,
    required this.userGroupName,
    required this.accountState,
    required this.mobile,
    required this.email,
  });

  /// 账户是否在线（1=在线）。
  bool get isOnline => accountState == 1;

  factory PasspointUserInfo.fromJson(Map<String, dynamic> json) {
    return PasspointUserInfo(
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      userGroupName: json['userGroupName']?.toString() ?? '',
      accountState: int.tryParse(json['accountState']?.toString() ?? '') ?? 0,
      mobile: json['mobile']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }
}

/// 校园网无感认证平台支持的出口（`defaultServiceName` 可选项）。
///
/// 前端页面固定为：校园网（空串）/ 中国电信 / 中国移动 / 中国联通。
class PasspointExit {
  final String label;
  final String value;

  const PasspointExit({required this.label, required this.value});

  static const List<PasspointExit> all = [
    PasspointExit(label: '校园网', value: ''),
    PasspointExit(label: '中国电信', value: '中国电信'),
    PasspointExit(label: '中国移动', value: '中国移动'),
    PasspointExit(label: '中国联通', value: '中国联通'),
  ];
}
