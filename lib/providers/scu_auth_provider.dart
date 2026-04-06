import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Bugaoshan/models/scu_user_info.dart';
import 'package:Bugaoshan/serivces/scu_login.dart';

enum SCULoginStatus { loggedOut, loggingIn, loggedIn, sessionExpired }

class SCUAuthProvider {
  final SharedPreferences _prefs;

  static const _keyUsername = 'scu_username';
  static const _keyPassword = 'scu_password';
  static const _ssoUrl =
      'https://id.scu.edu.cn/enduser/sp/sso/scdxplugin_jwt23'
      '?enterpriseId=scdx&target_url=index';
  static const _pyfaUrl = 'http://zhjw.scu.edu.cn/main/showPyfaInfo';
  static const _photoUrl = 'http://zhjw.scu.edu.cn/student/rollInfo/img';

  SCUAuthProvider(this._prefs);

  final ValueNotifier<SCULoginStatus> status = ValueNotifier(
    SCULoginStatus.loggedOut,
  );
  final ValueNotifier<SCUUserInfo?> userInfo = ValueNotifier(null);
  final ValueNotifier<String?> errorMessage = ValueNotifier(null);

  SCUSession? _session;
  SCULogin? _sdk;

  String get savedUsername => _prefs.getString(_keyUsername) ?? '';
  String get savedPassword => _prefs.getString(_keyPassword) ?? '';
  bool get hasCredentials =>
      savedUsername.isNotEmpty && savedPassword.isNotEmpty;

  void saveCredentials(String username, String password) {
    _prefs.setString(_keyUsername, username);
    _prefs.setString(_keyPassword, password);
  }

  void clearCredentials() {
    _prefs.remove(_keyUsername);
    _prefs.remove(_keyPassword);
    _session = null;
    _sdk = null;
    userInfo.value = null;
    status.value = SCULoginStatus.loggedOut;
    errorMessage.value = null;
  }

  Future<Uint8List> getCaptcha(String username, String password) async {
    _sdk = SCULogin(username: username, password: password);
    return _sdk!.getCaptcha();
  }

  Future<void> login(String capText) async {
    if (_sdk == null) throw StateError('请先调用 getCaptcha');
    status.value = SCULoginStatus.loggingIn;
    errorMessage.value = null;
    try {
      _session = await _sdk!.ssoLogin(_ssoUrl, capText: capText);
      await _fetchUserInfo();
      status.value = SCULoginStatus.loggedIn;
    } catch (e) {
      status.value = SCULoginStatus.loggedOut;
      errorMessage.value = e.toString();
      rethrow;
    }
  }

  Future<void> refreshUserInfo() async {
    if (_session == null) {
      status.value = SCULoginStatus.sessionExpired;
      return;
    }
    try {
      await _fetchUserInfo();
    } catch (_) {
      status.value = SCULoginStatus.sessionExpired;
    }
  }

  Future<void> _fetchUserInfo() async {
    // 先访问主页建立 session
    await _session!.get('http://zhjw.scu.edu.cn/index');
    final resp = await _session!.post(_pyfaUrl);
    debugPrint('[SCUAuth] pyfa status: ${resp.statusCode}');
    debugPrint('[SCUAuth] pyfa response: ${resp.data}');
    final body = _parseBody(resp.data);
    if (body is! Map) {
      throw Exception('showPyfaInfo 响应格式异常: $body');
    }
    final data = body['data'];
    if (data == null || (data is List && data.isEmpty)) {
      throw Exception('showPyfaInfo 未返回数据');
    }
    final first = data[0] as List;
    userInfo.value = SCUUserInfo(
      majorName: first[0]?.toString() ?? '',
      majorCode: first[1]?.toString() ?? '',
      photoUrl: _photoUrl,
    );
  }

  static dynamic _parseBody(dynamic data) {
    if (data is String) {
      try {
        return jsonDecode(data);
      } catch (_) {
        return data;
      }
    }
    return data;
  }

  SCUSession? get session => _session;
}
