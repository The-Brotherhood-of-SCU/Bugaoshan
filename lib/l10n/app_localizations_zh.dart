// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get rubbishPlan => '混沌课表';

  @override
  String get selfLanguage => '中文';

  @override
  String get course => '课程';

  @override
  String get profile => '我的';

  @override
  String get softwareSetting => '软件设置';

  @override
  String get followSystem => '跟随系统';

  @override
  String get modifyLanguage => '修改语言';

  @override
  String get current => '当前';
}

/// The translations for Chinese, as used in China, using the Han script (`zh_Hans_CN`).
class AppLocalizationsZhHansCn extends AppLocalizationsZh {
  AppLocalizationsZhHansCn() : super('zh_Hans_CN');

  @override
  String get selfLanguage => '中文-简体-中国';
}
