import 'package:flutter/foundation.dart';

class ProfileLabelsNotifier extends ChangeNotifier {
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
}
