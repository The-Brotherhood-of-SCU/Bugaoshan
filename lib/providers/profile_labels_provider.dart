import 'package:flutter/foundation.dart';
import 'package:bugaoshan/services/api/wfw_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';

class ProfileLabelsProvider extends ChangeNotifier {
  final WfwApiService _wfwApi;

  ProfileLabelsProvider(this._wfwApi);

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
      _labels = await _wfwApi.fetchProfileLabels();
      _error = false;
    } on UnauthenticatedException {
      _error = true;
    } catch (e) {
      _error = true;
    }
    _loading = false;
    notifyListeners();
  }
}
