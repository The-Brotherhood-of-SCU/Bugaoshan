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

  @override
  String get animationDuration => '动画时长';

  @override
  String get confirm => '确认';

  @override
  String currentAnimationDuration(Object value) {
    return '当前动画时长: $value ms';
  }

  @override
  String animationDurationUpdated(Object value) {
    return '动画时长已更新为 $value ms';
  }

  @override
  String get animationDurationHint => '提示：调整滑块查看动画效果，点击确认后才会保存设置';

  @override
  String get themeColor => '主题颜色';

  @override
  String get changeThemeColor => '更改主题颜色';

  @override
  String get confirmButton => '确认';

  @override
  String get customizedColorHint => '自定义颜色由颜色种子生成';

  @override
  String get tips => '提示';

  @override
  String get resetToDefault => '重置为默认';

  @override
  String get blockPicker => '色块';

  @override
  String get materialPicker => '材质';

  @override
  String get advancedPicker => '高级';

  @override
  String get about => '关于';

  @override
  String get developmentTeam => '开发团队';

  @override
  String get projectInfo => '项目信息';

  @override
  String get appName => '应用名称';

  @override
  String get version => '版本';

  @override
  String get description => '描述';

  @override
  String get appDescription => '一款简洁实用的课程管理应用';

  @override
  String get contactUs => '联系我们';

  @override
  String developedBy(Object team) {
    return '由 $team 倾情打造';
  }

  @override
  String get externalResources => '外部资源';

  @override
  String get projectRepository => '项目仓库';

  @override
  String get clearAllData => '清除所有数据';

  @override
  String get confirmMessage => '真的要这样做吗？';

  @override
  String get environmentInfo => '环境信息';

  @override
  String get scheduleSetting => '课表设置';

  @override
  String get globalSetting => '全局设置';
}

/// The translations for Chinese, as used in China, using the Han script (`zh_Hans_CN`).
class AppLocalizationsZhHansCn extends AppLocalizationsZh {
  AppLocalizationsZhHansCn() : super('zh_Hans_CN');

  @override
  String get selfLanguage => '中文-简体-中国';
}
