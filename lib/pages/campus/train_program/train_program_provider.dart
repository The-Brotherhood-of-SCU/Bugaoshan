import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:bugaoshan/pages/campus/train_program/models/train_program.dart';
import 'package:bugaoshan/pages/campus/train_program/models/train_program_model.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/serivces/scu_auth_service.dart';
import 'package:bugaoshan/utils/session_expiry_handler.dart';

enum TrainProgramLoadState { idle, loading, loaded, error }

class TrainProgramProvider extends ChangeNotifier {
  final ScuAuthProvider _authProvider;

  TrainProgramProvider(this._authProvider);

  List<College> _colleges = [];
  List<Grade> _grades = [];
  List<TrainProgram> _programs = [];
  TrainProgramDetail? _currentDetail;
  CourseDetail? _currentCourseDetail;

  TrainProgramLoadState _collegesState = TrainProgramLoadState.idle;
  TrainProgramLoadState _gradesState = TrainProgramLoadState.idle;
  TrainProgramLoadState _programsState = TrainProgramLoadState.idle;
  TrainProgramLoadState _detailState = TrainProgramLoadState.idle;
  TrainProgramLoadState _courseDetailState = TrainProgramLoadState.idle;

  String? _collegesError;
  String? _gradesError;
  String? _programsError;
  String? _detailError;
  String? _courseDetailError;

  String? _selectedCollege;
  String? _selectedGrade;

  List<College> get colleges => _colleges;
  List<Grade> get grades => _grades;
  List<TrainProgram> get programs => _programs;
  TrainProgramDetail? get currentDetail => _currentDetail;
  CourseDetail? get currentCourseDetail => _currentCourseDetail;

  TrainProgramLoadState get collegesState => _collegesState;
  TrainProgramLoadState get gradesState => _gradesState;
  TrainProgramLoadState get programsState => _programsState;
  TrainProgramLoadState get detailState => _detailState;
  TrainProgramLoadState get courseDetailState => _courseDetailState;

  String? get collegesError => _collegesError;
  String? get gradesError => _gradesError;
  String? get programsError => _programsError;
  String? get detailError => _detailError;
  String? get courseDetailError => _courseDetailError;

  String? get selectedCollege => _selectedCollege;
  String? get selectedGrade => _selectedGrade;

  void setSelectedCollege(String? value) {
    _selectedCollege = value;
    notifyListeners();
  }

  void setSelectedGrade(String? value) {
    _selectedGrade = value;
    notifyListeners();
  }

  void _safeNotify() {
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  Future<void> fetchCollegesAndGrades() async {
    if (_collegesState == TrainProgramLoadState.loading ||
        _gradesState == TrainProgramLoadState.loading)
      return;

    _collegesState = TrainProgramLoadState.loading;
    _gradesState = TrainProgramLoadState.loading;
    _collegesError = null;
    _gradesError = null;
    _safeNotify();

    try {
      final client = await _authProvider.service.bindSession();
      try {
        final resp = await client.get(
          Uri.parse(
            'http://zhjw.scu.edu.cn/student/comprehensiveQuery/search/trainProgram/index',
          ),
          headers: {
            'Accept': 'text/html,*/*',
            'Referer': 'http://zhjw.scu.edu.cn/',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
          },
        );

        final body = resp.body;
        _colleges = _parseOptions(body, 'xsh');
        _grades = _parseGradeOptions(body, 'nj');

        _collegesState = TrainProgramLoadState.loaded;
        _gradesState = TrainProgramLoadState.loaded;
      } finally {
        client.close();
      }
    } on ScuLoginException catch (e) {
      if (e.sessionExpired) {
        await SessionExpiryHandler.handle(_authProvider);
      }
      _collegesState = TrainProgramLoadState.error;
      _gradesState = TrainProgramLoadState.error;
      _collegesError = e.toString();
      _gradesError = e.toString();
    } catch (e) {
      _collegesState = TrainProgramLoadState.error;
      _gradesState = TrainProgramLoadState.error;
      _collegesError = e.toString();
      _gradesError = e.toString();
    }
    _safeNotify();
  }

  List<College> _parseOptions(String html, String selectId) {
    final selectRegex = RegExp(
      '''<select[^>]*name="$selectId"[^>]*>([\\s\\S]*?)</select>''',
    );
    final match = selectRegex.firstMatch(html);
    if (match == null) return [];

    final optionsRegex = RegExp(
      '''<option[^>]*value="([^"]*)"[^>]*>(.*?)</option>''',
    );
    final options = optionsRegex.allMatches(match.group(1)!);
    return options
        .where((m) => m.group(1)!.isNotEmpty)
        .map(
          (m) => College(
            value: m.group(1)!,
            name: m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim(),
          ),
        )
        .toList();
  }

  List<Grade> _parseGradeOptions(String html, String selectId) {
    final selectRegex = RegExp(
      '''<select[^>]*name="$selectId"[^>]*>([\\s\\S]*?)</select>''',
    );
    final match = selectRegex.firstMatch(html);
    if (match == null) return [];

    final optionsRegex = RegExp(
      '''<option[^>]*value="([^"]*)"[^>]*>(.*?)</option>''',
    );
    final options = optionsRegex.allMatches(match.group(1)!);
    return options
        .where((m) => m.group(1)!.isNotEmpty)
        .map(
          (m) => Grade(
            value: m.group(1)!,
            label: m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim(),
          ),
        )
        .toList();
  }

  Future<void> searchPrograms() async {
    if (_programsState == TrainProgramLoadState.loading) return;
    _programsState = TrainProgramLoadState.loading;
    _programsError = null;
    _safeNotify();

    try {
      final client = await _authProvider.service.bindSession();
      try {
        final resp = await client.post(
          Uri.parse(
            'http://zhjw.scu.edu.cn/student/comprehensiveQuery/search/trainProgram/load',
          ),
          headers: {
            'Accept': 'application/json, */*',
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'Referer':
                'http://zhjw.scu.edu.cn/student/comprehensiveQuery/search/trainProgram/index',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
          },
          body:
              'famc=&jhmc=&nj=${_selectedGrade ?? ''}&xw=&xzlx=&xdlx=00001&xsh=${_selectedCollege ?? ''}&pageNum=1&pageSize=100',
        );

        final body = resp.body.trim();
        if (body.startsWith('<')) {
          throw ScuLoginException('登录已过期，请重新登录', sessionExpired: true);
        }

        final json = jsonDecode(body) as Map<String, dynamic>;
        final records = json['data']['records'] as List<dynamic>? ?? [];
        _programs = records
            .map((e) => TrainProgram.fromJson(e as Map<String, dynamic>))
            .toList();
        _programsState = TrainProgramLoadState.loaded;
      } finally {
        client.close();
      }
    } on ScuLoginException catch (e) {
      if (e.sessionExpired) {
        await SessionExpiryHandler.handle(_authProvider);
      }
      _programsState = TrainProgramLoadState.error;
      _programsError = e.toString();
    } catch (e) {
      _programsState = TrainProgramLoadState.error;
      _programsError = e.toString();
    }
    _safeNotify();
  }

  Future<void> fetchProgramDetail(String fajhh) async {
    if (_detailState == TrainProgramLoadState.loading) return;
    _detailState = TrainProgramLoadState.loading;
    _detailError = null;
    _safeNotify();

    try {
      final client = await _authProvider.service.bindSession();
      try {
        final resp = await client.post(
          Uri.parse(
            'http://zhjw.scu.edu.cn/student/comprehensiveQuery/search/trainProgram/detail',
          ),
          headers: {
            'Accept': 'application/json, */*',
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'Referer':
                'http://zhjw.scu.edu.cn/student/comprehensiveQuery/search/trainProgram/index',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
          },
          body: 'fajhh=$fajhh&lx=1',
        );

        final body = resp.body.trim();
        if (body.startsWith('<')) {
          throw ScuLoginException('登录已过期，请重新登录', sessionExpired: true);
        }

        final json = jsonDecode(body) as Map<String, dynamic>;
        _currentDetail = TrainProgramDetail.fromJson(json);
        _detailState = TrainProgramLoadState.loaded;
      } finally {
        client.close();
      }
    } on ScuLoginException catch (e) {
      if (e.sessionExpired) {
        await SessionExpiryHandler.handle(_authProvider);
      }
      _detailState = TrainProgramLoadState.error;
      _detailError = e.toString();
    } catch (e) {
      _detailState = TrainProgramLoadState.error;
      _detailError = e.toString();
    }
    _safeNotify();
  }

  void clearDetail() {
    _currentDetail = null;
    _detailState = TrainProgramLoadState.idle;
    _safeNotify();
  }

  Future<void> fetchCourseDetail(String urlPath) async {
    if (_courseDetailState == TrainProgramLoadState.loading) return;
    _courseDetailState = TrainProgramLoadState.loading;
    _courseDetailError = null;
    _safeNotify();

    try {
      final client = await _authProvider.service.bindSession();
      try {
        final fullUrl = 'http://zhjw.scu.edu.cn$urlPath';
        final resp = await client.get(
          Uri.parse(fullUrl),
          headers: {
            'Accept': 'application/json, */*',
            'Referer':
                'http://zhjw.scu.edu.cn/student/comprehensiveQuery/search/trainProgram/index',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
          },
        );

        final body = resp.body.trim();
        if (body.startsWith('<')) {
          throw ScuLoginException('登录已过期，请重新登录', sessionExpired: true);
        }

        final json = jsonDecode(body) as Map<String, dynamic>;
        _currentCourseDetail = CourseDetail.fromJson(json);
        _courseDetailState = TrainProgramLoadState.loaded;
      } finally {
        client.close();
      }
    } on ScuLoginException catch (e) {
      if (e.sessionExpired) {
        await SessionExpiryHandler.handle(_authProvider);
      }
      _courseDetailState = TrainProgramLoadState.error;
      _courseDetailError = e.toString();
    } catch (e) {
      _courseDetailState = TrainProgramLoadState.error;
      _courseDetailError = e.toString();
    }
    _safeNotify();
  }

  void clearCourseDetail() {
    _currentCourseDetail = null;
    _courseDetailState = TrainProgramLoadState.idle;
    _safeNotify();
  }
}
