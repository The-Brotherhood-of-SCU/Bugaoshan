import 'package:flutter/foundation.dart';
import 'package:bugaoshan/services/update_service.dart';

class UpdateResultNotifier extends ChangeNotifier {
  UpdateCheckResult _value = UpdateCheckResult.initial();

  UpdateCheckResult get value => _value;

  set value(UpdateCheckResult v) {
    _value = v;
    notifyListeners();
  }
}
