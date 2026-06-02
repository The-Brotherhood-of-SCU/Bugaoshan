import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';

class ProfileLabelsProvider extends ChangeNotifier {
  List<Map<String, dynamic>>? _labels;
  bool _loading = false;
  bool _error = false;

  List<Map<String, dynamic>>? get labels => _labels;
  bool get loading => _loading;
  bool get error => _error;
  bool get hasData => _labels != null;

  set loading(bool value) {
    _loading = value;
    notifyListeners();
  }

  set error(bool value) {
    _error = value;
    notifyListeners();
  }

  void setLabels(List<Map<String, dynamic>> labels) {
    _labels = labels;
    _error = false;
    notifyListeners();
  }

  void clear() {
    _labels = null;
    _error = false;
    _loading = false;
    notifyListeners();
  }

  Future<void> fetchLabels() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    try {
      final json = await getIt<ScuAuthProvider>().service.request((
        client,
      ) async {
        final resp = await client.get(
          Uri.parse('https://wfw.scu.edu.cn/mashupapp/wap/real/user'),
          headers: {
            'Accept': 'application/json, text/plain, */*',
            'X-Requested-With': 'XMLHttpRequest',
            'Referer': 'https://wfw.scu.edu.cn',
          },
        );
        return jsonDecode(resp.body) as Map<String, dynamic>;
      });

      if (json['e'] == 0 && json['d']?['labels'] != null) {
        _labels = (json['d']['labels'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _error = false;
      } else {
        _error = true;
      }
    } catch (e) {
      _error = true;
    }
    _loading = false;
    notifyListeners();
  }
}
