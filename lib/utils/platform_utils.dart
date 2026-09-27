import 'dart:io';

import 'package:flutter/foundation.dart';

bool get isOhos => !kIsWeb && Platform.operatingSystem == 'ohos';
