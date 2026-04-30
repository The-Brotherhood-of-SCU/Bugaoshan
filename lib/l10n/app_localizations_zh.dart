// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get bugaoshan => '不高山上';

  @override
  String get selfLanguage => '中文';

  @override
  String get wizardWelcomeTitle => '欢迎使用不高山上';

  @override
  String get wizardWelcomeDesc => '你的校园生活助手，一站式查看课表、成绩与校园服务';

  @override
  String get wizardLoginTitle => '登录与导入课表';

  @override
  String get wizardLoginStep1 => '完成统一身份认证登录';

  @override
  String get wizardLoginStep2 => '从教务系统导入课表';

  @override
  String get wizardLoginDone => '已登录';

  @override
  String get wizardLoginButton => '去登录';

  @override
  String get wizardImportButton => '导入课表';

  @override
  String get wizardImportHint => '登录后可自动获取课表';

  @override
  String get wizardFeatureTitle => '探索更多功能';

  @override
  String get wizardFeatureCourse => '课表管理';

  @override
  String get wizardFeatureCourseDesc => '查看每周课程安排与多课表管理，支持从教务系统一键导入、分享与导出为日历文件';

  @override
  String get wizardFeatureCampus => '校园服务';

  @override
  String get wizardFeatureCampusDesc =>
      '查询空闲教室与学业成绩，参与第二课堂活动，查询电费与空调余额，管理校园网设备';

  @override
  String get wizardFeatureProfile => '个人中心';

  @override
  String get wizardFeatureProfileDesc => '使用统一身份认证登录并绑定第二课堂，自定义主题颜色、深色模式与语言偏好';

  @override
  String get onboardingSkip => '跳过';

  @override
  String get onboardingNext => '下一步';

  @override
  String get onboardingStart => '立即体验';

  @override
  String get course => '课程';

  @override
  String get profile => '我的';

  @override
  String get campus => '校园';

  @override
  String get classroomQuery => '教室查询';

  @override
  String get classroomQueryDesc => '查询教室空闲、借用和上课信息';

  @override
  String get utilitiesSection => '实用工具';

  @override
  String get academicSection => '学术';

  @override
  String get moreFeaturesTitle => '更多功能';

  @override
  String get moreFeaturesDesc => '更多功能请创建 Issue 交流';

  @override
  String get selectCampus => '选择校区';

  @override
  String get selectBuilding => '选择楼栋';

  @override
  String get allBuildings => '全部教学楼';

  @override
  String get seats => '座';

  @override
  String get free => '空闲';

  @override
  String get inClass => '上课中';

  @override
  String get borrowed => '已借用';

  @override
  String get period => '节次';

  @override
  String get loading => '加载中...';

  @override
  String get loadFailed => '加载失败，点击重试';

  @override
  String get campusNetworkRequired => '该功能仅限校园网访问，请连接校园网或使用学校 VPN 后重试';

  @override
  String get appOnly => '仅 App 端可使用';

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
  String get gitTag => 'Git 标签';

  @override
  String get description => '描述';

  @override
  String get appDescription => '探索一切，尽在不高山上';

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
  String get checkForUpdates => '检查更新';

  @override
  String get newVersionAvailable => '发现新版本';

  @override
  String get noUpdateAvailable => '已是最新版本';

  @override
  String get goToReleases => '前往 Releases';

  @override
  String get startUpdate => '开始更新';

  @override
  String get startUpdatePreview => '更新到预览版';

  @override
  String get updateToLatest => '升级到最新版本';

  @override
  String get updateToStable => '更新到最新稳定版';

  @override
  String get updateToPreview => '更新到最新版（包括预览版）';

  @override
  String get downloading => '正在下载';

  @override
  String get updateFailed => '更新失败';

  @override
  String get preReleaseWarning => '这是预发布版本，使用时请注意。';

  @override
  String get releaseNotes => '更新日志';

  @override
  String get neverMind => '算了吧';

  @override
  String get clearAllData => '清除所有数据';

  @override
  String get confirmMessage => '真的要这样做吗？';

  @override
  String get environmentInfo => '环境信息';

  @override
  String get testPage => '测试页面';

  @override
  String get forceUpdate => '更新到最新版本（含预览版）';

  @override
  String get scheduleSetting => '课表设置';

  @override
  String get scheduleManagement => '课表管理';

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
  String get thisWeek => '本周';

  @override
  String weekRange(int start, int end) {
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
  String get setCurrentWeek => '设置当前周数';

  @override
  String get setCurrentWeekHint => '将根据当前周数自动推算学期开始日期';

  @override
  String get semesterEndDate => '学期结束日期';

  @override
  String get displaySetting => '显示设置';

  @override
  String get colorOpacity => '颜色不透明度';

  @override
  String get fontSize => '字体大小';

  @override
  String get showCourseGrid => '显示课表网格';

  @override
  String get courseRowHeight => '课表网格高度';

  @override
  String get backgroundImage => '背景图片';

  @override
  String get setBackgroundImage => '设置背景图片';

  @override
  String get removeBackgroundImage => '移除背景图片';

  @override
  String get backgroundImageOpacity => '背景图片不透明度';

  @override
  String get showTeacher => '显示教师';

  @override
  String get showLocation => '显示教室';

  @override
  String get showWeekend => '显示周末';

  @override
  String get showNonCurrentWeekCourses => '显示非本周课程';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get back => '上一步';

  @override
  String get next => '下一步';

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
  String get duplicateScheduleName => '课表名称已存在';

  @override
  String get importSchedule => '导入课表';

  @override
  String get importFromShare => '从分享导入';

  @override
  String get importFromJwxt => '从教务系统抓包导入';

  @override
  String get importDataHint => '请在此处粘贴 JSON 数据...';

  @override
  String get importSuccess => '课表导入成功';

  @override
  String get importFailed => '导入失败';

  @override
  String get importedScheduleDefaultName => '导入的课表';

  @override
  String importNameConflictHint(Object name) {
    return '名称 \"$name\" 已存在，请重命名：';
  }

  @override
  String get importNameSuffix => '(导入)';

  @override
  String get defaultScheduleName => '默认课表';

  @override
  String deleteScheduleConfirm(Object name) {
    return '确定要删除课表 \"$name\" 吗？';
  }

  @override
  String get exportSchedule => '导出课表';

  @override
  String get exportScheduleAsCopy => '复制到剪切板';

  @override
  String get exportScheduleAsIcs => '导出为日历文件';

  @override
  String get exportScheduleAsCopySuccess => '课表已复制到剪切板';

  @override
  String get exportScheduleAsCopyFailed => '复制失败，您可以稍后再试';

  @override
  String get exportScheduleAsIcsTo => '保存日历文件到...';

  @override
  String get exportScheduleAsIcsSuccess => '保存成功';

  @override
  String get exportScheduleAsIcsFailed => '保存失败';

  @override
  String get exportScheduleAsIcsCanceled => '取消保存';

  @override
  String get icsTeacherLabel => '教师';

  @override
  String get copySuffix => ' (副本)';

  @override
  String get notThisWeek => '[非本周]';

  @override
  String actualCurrentWeek(Object week) {
    return '本周第 $week 周';
  }

  @override
  String totalWeeksSubtitle(Object count) {
    return '共 $count 周';
  }

  @override
  String get invalidSectionRange => '结束节次必须大于开始节次';

  @override
  String get crossPeriodError => '跨时间段错误';

  @override
  String get crossPeriodErrorMessage => '一门课程不能跨越上午、下午或晚上。';

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

  @override
  String get scuLogin => '统一身份认证登录';

  @override
  String get loggedIn => '已登录';

  @override
  String get notLoggedIn => '未登录';

  @override
  String get loginSessionExpired => '登录状态已过期';

  @override
  String get loginSessionExpiredDesc => '登录会话过期，请重新登录';

  @override
  String get logout => '退出登录';

  @override
  String get logoutConfirm => '确定要退出登录吗？';

  @override
  String get importFromJwxtOnline => '从教务系统在线导入';

  @override
  String get importFromJwxtOnlineHint => '将自动获取课表，需要先在「我的」页面完成统一身份认证登录';

  @override
  String get selectSemester => '选择学期';

  @override
  String get importAll => '全部导入';

  @override
  String get scuUnifiedAuth => '统一身份认证';

  @override
  String get studentId => '学号';

  @override
  String get studentIdRequired => '请输入学号';

  @override
  String get password => '密码';

  @override
  String get passwordRequired => '请输入密码';

  @override
  String get captcha => '验证码';

  @override
  String get captchaRequired => '请输入验证码';

  @override
  String get rememberPassword => '记住密码';

  @override
  String get loginButton => '登录';

  @override
  String get captchaLoadFailed => '验证码加载失败';

  @override
  String get captchaNotLoaded => '请先加载验证码';

  @override
  String get networkError => '网络错误';

  @override
  String get gradesStats => '成绩统计';

  @override
  String get gradesStatsDesc => '查看和分析你的学业成绩';

  @override
  String get gradesStatsComingSoon => '功能即将上线';

  @override
  String get schemeScores => '方案成绩';

  @override
  String get passingScores => '及格成绩';

  @override
  String get gradesLoginRequired => '请先在「我的」页面完成统一身份认证登录';

  @override
  String get gradesNoData => '暂无成绩数据';

  @override
  String get gradesLoadFailed => '成绩加载失败';

  @override
  String get gradesRefreshFailed => '刷新失败，显示的是缓存数据';

  @override
  String get gradesNoPassingData => '暂无及格成绩数据';

  @override
  String get gradesGet => '获取成绩';

  @override
  String get gradesRetry => '重试';

  @override
  String get gpa => 'GPA';

  @override
  String get overallGpa => '综合 GPA';

  @override
  String get earnedCredits => '已修学分';

  @override
  String get passedCount => '通过';

  @override
  String get failedCount => '未通过';

  @override
  String get avgScore => '平均成绩';

  @override
  String get requiredAvgScore => '必修均分';

  @override
  String get requiredCredits => '必修学分';

  @override
  String get electiveCredits => '选修学分';

  @override
  String get optionalCredits => '任选学分';

  @override
  String get requiredGpa => '必修 GPA';

  @override
  String get totalPassedCount => '通过门数';

  @override
  String get termCount => '学期数';

  @override
  String get accumulatedCredits => '累计学分';

  @override
  String creditUnit(Object credit) {
    return '$credit 学分';
  }

  @override
  String termPassedSummary(Object count, Object credits) {
    return '$count 门 · $credits 学分';
  }

  @override
  String get sessionExpiredTitle => '会话已过期';

  @override
  String get sessionExpiredMessage => '登录会话已过期，请重新登录后继续使用该功能。';

  @override
  String get sessionExpired => '登录会话已过期';

  @override
  String get relogin => '重新登录';

  @override
  String get trainProgram => '培养方案';

  @override
  String get trainProgramDesc => '查询各学院各年级的培养方案';

  @override
  String get trainProgramCollege => '学院';

  @override
  String get trainProgramGrade => '年级';

  @override
  String get trainProgramAll => '全部';

  @override
  String get trainProgramSearch => '查询';

  @override
  String get trainProgramNoData => '暂无培养方案数据';

  @override
  String get trainProgramLoading => '加载中...';

  @override
  String get trainProgramLoadFailed => '加载失败';

  @override
  String get trainProgramName => '方案名称';

  @override
  String get trainProgramMajor => '专业';

  @override
  String get trainProgramEducationSystem => '学制';

  @override
  String get trainProgramDegreeType => '学位类型';

  @override
  String get trainProgramDetail => '培养方案详情';

  @override
  String get trainProgramCredits => '总学分';

  @override
  String get trainProgramHours => '总学时';

  @override
  String get trainProgramCourses => '课程数';

  @override
  String get trainProgramObjective => '培养目标';

  @override
  String get trainProgramCourseStructure => '课程结构';

  @override
  String get trainProgramCourseNumber => '课程号';

  @override
  String get trainProgramOpenCollege => '开课学院';

  @override
  String get trainProgramCourseType => '课程类别';

  @override
  String get trainProgramExamType => '考核方式';

  @override
  String get trainProgramTeachingMethod => '教学方式';

  @override
  String get trainProgramCourseHoursDetail => '内含学时';

  @override
  String get trainProgramWeekHours => '周学时';

  @override
  String get trainProgramActualHours => '实践学时';

  @override
  String get trainProgramOpenCourse => '开放课程';

  @override
  String get trainProgramCourseArrangement => '课程安排';

  @override
  String get trainProgramPlanName => '方案名称';

  @override
  String get trainProgramCourseAttribute => '课程属性';

  @override
  String get trainProgramAcademicYear => '学年';

  @override
  String get trainProgramSemester => '学期';

  @override
  String get trainProgramExperimentHours => '实验学时';

  @override
  String get trainProgramLoginRequired => '请先在「我的」页面完成统一身份认证登录';

  @override
  String get ccylTitle => '第二课堂';

  @override
  String get ccylDesc => '查看活动、参与活动、预约活动';

  @override
  String get ccylSearchActivities => '活动搜索';

  @override
  String get ccylMyActivities => '我参与的活动';

  @override
  String get ccylOrderedActivities => '预约的活动';

  @override
  String get ccylMyCredits => '成绩单';

  @override
  String get ccylSelect => '选择';

  @override
  String get ccylSelectAll => '全选';

  @override
  String get ccylExportEmail => '导出到邮箱';

  @override
  String get ccylEmailAddress => 'QQ邮箱';

  @override
  String get ccylEmailHint => '请输入接收成绩单的QQ邮箱';

  @override
  String get ccylExportSuccess => '成绩单已发送至邮箱';

  @override
  String get ccylSearchHint => '搜索活动名称';

  @override
  String get ccylHours => '学时';

  @override
  String get ccylAvailable => '可预约';

  @override
  String get ccylInProgress => '进行中';

  @override
  String get ccylCompleted => '已结束';

  @override
  String get ccylSubscribed => '已预约';

  @override
  String get ccylSubscribe => '预约';

  @override
  String get ccylCancelSubscribe => '取消预约';

  @override
  String get ccylSubscribeSuccess => '预约成功';

  @override
  String get ccylCancelSuccess => '取消预约成功';

  @override
  String get ccylActionFailed => '操作失败';

  @override
  String get ccylSignUp => '报名';

  @override
  String get ccylCancelSignUp => '取消报名';

  @override
  String get ccylSelectScoreType => '选择希望提升的能力类型';

  @override
  String get ccylSignUpSuccess => '报名成功';

  @override
  String get ccylNoScoreType => '暂无能力类型';

  @override
  String get ccylCurrentValue => '当前值';

  @override
  String get ccylLoginRequired => '请先在「我的」页面完成统一身份认证登录';

  @override
  String get ccylBindRequired => '请先绑定第二课堂账号';

  @override
  String get ccylBindTitle => '绑定第二课堂';

  @override
  String get ccylBindDesc => '绑定第二课堂账号后即可查看活动信息';

  @override
  String get ccylOpenOAuth => '打开统一认证授权页';

  @override
  String get ccylDoBind => '绑定第二课堂';

  @override
  String get ccylBindHelp => '点击按钮自动完成绑定';

  @override
  String get ccylActivitySeries => '活动系列';

  @override
  String get ccylActivityDetail => '活动详情';

  @override
  String get ccylActivityInfo => '活动信息';

  @override
  String get ccylTimeInfo => '时间信息';

  @override
  String get ccylLocationInfo => '地点信息';

  @override
  String get ccylContactInfo => '联系信息';

  @override
  String get ccylStarLevel => '星级';

  @override
  String get ccylQuality => '性质';

  @override
  String get ccylScoreType => '积分类型';

  @override
  String get ccylLiablePerson => '负责人';

  @override
  String get ccylLiablePhone => '联系电话';

  @override
  String get ccylLiableTeacher => '指导老师';

  @override
  String get ccylLiableTeacherPhone => '指导老师电话';

  @override
  String get ccylActivities => '系列活动';

  @override
  String get ccylQuota => '名额';

  @override
  String get ccylActivityTarget => '活动对象';

  @override
  String get ccylActivityTime => '活动时间';

  @override
  String get ccylEnrollTime => '报名时间';

  @override
  String get ccylActivityAddress => '活动地点';

  @override
  String get ccylContactPhone => '联系电话';

  @override
  String get ccylSignIn => '签到';

  @override
  String get ccylSignOut => '签退';

  @override
  String get ccylEnabled => '开启';

  @override
  String get ccylDisabled => '关闭';

  @override
  String get ccylSeriesName => '系列名称';

  @override
  String get ccylOrganizer => '主办单位';

  @override
  String get noData => '暂无数据';

  @override
  String get networkDeviceQuery => '校园网设备查询';

  @override
  String get networkDeviceQueryDesc => '查询校园网账户和在线设备';

  @override
  String get networkDeviceUserInfo => '用户信息';

  @override
  String get networkDeviceOnlineDevices => '在线设备';

  @override
  String get networkDeviceDeviceId => '设备ID';

  @override
  String get networkDeviceIp => 'IP 地址';

  @override
  String get networkDeviceLogout => '下线';

  @override
  String get networkDeviceLogoutConfirm => '确定要下线所有设备吗？';

  @override
  String get networkDeviceForceOffline => '强制下线';

  @override
  String get networkDeviceConfirmOffline => '确定要下线该设备吗？';

  @override
  String get networkDeviceOfflineSuccess => '操作成功';

  @override
  String get networkDeviceAuthFailed => '认证失败';

  @override
  String get networkDeviceOperationSuccess => '操作成功';

  @override
  String get loginFailed => '登录失败';

  @override
  String get invalidCaptcha => '验证码错误，请重试';

  @override
  String loginFailedWillLock(int count) {
    return '登录失败，再输错 $count 次将锁定账户';
  }

  @override
  String get ccylBindFailed => '绑定失败，请稍后重试';

  @override
  String get ccylActivityLoadFailed => '活动加载失败';

  @override
  String get networkOfflineFailed => '下线失败';

  @override
  String get balanceQuery => '余额查询';

  @override
  String get balanceQueryDesc => '查询电费和空调费用余额';

  @override
  String get electricityFee => '电费';

  @override
  String get acFee => '空调费';

  @override
  String get balance => '余额';

  @override
  String get bindRoom => '绑定房间';

  @override
  String get bindNewRoom => '绑定新房间';

  @override
  String get switchRoom => '切换房间';

  @override
  String get deleteRoom => '删除房间';

  @override
  String get selectUnit => '选择单元';

  @override
  String get inputInfo => '输入信息';

  @override
  String get stepCampus => '校区';

  @override
  String get stepBuilding => '楼栋';

  @override
  String get stepUnit => '单元';

  @override
  String get stepInfo => '信息';

  @override
  String get inputBindingInfo => '输入绑定信息';

  @override
  String get cusName => '姓名';

  @override
  String get cusNameHint => '请输入姓名';

  @override
  String get roomNumber => '房间号';

  @override
  String get roomNumberHint => '请输入房间号，如 301C';

  @override
  String get pricePerUnit => '单价';

  @override
  String get balanceQueryLoginRequired => '请先在「我的」页面完成统一身份认证登录';

  @override
  String get balanceQueryNoBinding => '您还没有绑定房间，请先绑定';
}

/// The translations for Chinese, as used in China, using the Han script (`zh_Hans_CN`).
class AppLocalizationsZhHansCn extends AppLocalizationsZh {
  AppLocalizationsZhHansCn() : super('zh_Hans_CN');

  @override
  String get bugaoshan => '不高山上';

  @override
  String get selfLanguage => '中文-简体-中国';
}
