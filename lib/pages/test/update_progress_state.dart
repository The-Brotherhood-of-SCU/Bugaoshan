import 'package:flutter/foundation.dart';

class UpdateProgressState extends ChangeNotifier {
  String _status = 'Downloading...';
  int _received = 0;
  int _total = 0;

  String get status => _status;
  int get received => _received;
  int get total => _total;
  int get percent => _total > 0 ? ((_received / _total) * 100).toInt() : 0;

  void setStatus(String status) {
    _status = status;
    notifyListeners();
  }

  void setProgress(int received, int total) {
    _received = received;
    _total = total;
    notifyListeners();
  }
}
