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

  @override
  String get addCourse => '添加课程';

  @override
  String get editCourse => '编辑课程';

  @override
  String get deleteCourse => '删除课程';

  @override
  String get deleteCourseConfirm => '确定要删除这门课程吗？';

  @override
  String get courseName => '课程名称';

  @override
  String get teacher => '教师';

  @override
  String get location => '教室';

  @override
  String get courseColor => '课程颜色';

  @override
  String get week => '周';

  @override
  String get startWeek => '开始周';

  @override
  String get endWeek => '结束周';

  @override
  String get dayOfWeek => '星期';

  @override
  String get startSection => '开始节次';

  @override
  String get endSection => '结束节次';

  @override
  String get monday => '周一';

  @override
  String get tuesday => '周二';

  @override
  String get wednesday => '周三';

  @override
  String get thursday => '周四';

  @override
  String get friday => '周五';

  @override
  String get saturday => '周六';

  @override
  String get sunday => '周日';

  @override
  String currentWeek(Object week) {
    return '第 $week 周';
  }

  @override
  String weekRange(Object end, Object start) {
    return '第 $start - $end 周';
  }

  @override
  String get weekType => '周次类型';

  @override
  String get everyWeek => '每周';

  @override
  String get oddWeek => '单周';

  @override
  String get evenWeek => '双周';

  @override
  String get section => '节';

  @override
  String get sectionCount => '每天节数';

  @override
  String get timeSlot => '时间段';

  @override
  String get startTime => '开始时间';

  @override
  String get endTime => '结束时间';

  @override
  String get semesterConfig => '学期配置';

  @override
  String get semesterName => '学期名称';

  @override
  String get semesterStartDate => '学期开始日期';

  @override
  String get semesterEndDate => '学期结束日期';

  @override
  String get displaySetting => '显示设置';

  @override
  String get colorOpacity => '颜色不透明度';

  @override
  String get fontSize => '字体大小';

  @override
  String get showTeacher => '显示教师';

  @override
  String get showLocation => '显示教室';

  @override
  String get showWeekend => '显示周末';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get customColor => '自定义颜色';

  @override
  String get noCourseThisWeek => '本周没有课程';

  @override
  String get timeConflict => '时间冲突';

  @override
  String get timeConflictMessage => '所选时间段与已有课程冲突。';

  @override
  String get fieldRequired => '此字段不能为空';

  @override
  String get invalidWeekRange => '结束周必须大于或等于开始周';

  @override
  String get invalidSectionRange => '结束节次必须大于开始节次';

  @override
  String totalWeeks(Object value) {
    return '总周数: $value';
  }

  @override
  String get morning => '上午';

  @override
  String get afternoon => '下午';

  @override
  String get evening => '晚上';

  @override
  String get courseDuration => '单节课程时长 (分钟)';

  @override
  String get breakDuration => '课间休息时长 (分钟)';

  @override
  String get autoSyncTime => '自动推算后续时间';
}

/// The translations for Chinese, as used in China, using the Han script (`zh_Hans_CN`).
class AppLocalizationsZhHansCn extends AppLocalizationsZh {
  AppLocalizationsZhHansCn() : super('zh_Hans_CN');

  @override
  String get selfLanguage => '中文-简体-中国';
}
