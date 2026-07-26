import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/utils/app_shapes.dart';

/// 课表页的页面级控制器（不进 GetIt —— 项目约定允许页面级非 DI 类；
/// 且 demo/真实两个 CoursePage 实例共存，单例语义错误）。
///
/// 真源模型（写进类注释防止后人误读）：
/// 控制器持有 [int _pageIndex]（**已结算页码**，唯一权威）；
/// [PageController] 只是执行器（`.page` 在 detach 时会 assert、动画中是 double，
/// 不能当真源）；`PageView.onPageChanged → [onPageSettled]` 是反馈通道。
///
/// [visibleWeek] / [isViewingVacation] 全部从 `_pageIndex` 派生，不存在独立字段
/// 间的不一致中间态。移动判定用**物理位置**（`pageController.page?.round() != target`）
/// 而非缓存 int 比较 —— 根治「同值不通知」bug 类。
class CoursePageController extends ChangeNotifier {
  CoursePageController({
    required ValueListenable<ScheduleConfig> scheduleConfig,
    required ValueListenable<List<ScheduleConfig>> allSchedules,
    required ValueListenable<Duration> animationDuration,
  }) : _scheduleConfig = scheduleConfig,
       _allSchedules = allSchedules,
       _animationDuration = animationDuration,
       showVacationPage = ValueNotifier<bool>(false) {
    showVacationPage.value = _computeShowVacationPage();
    _pageIndex = _indexForToday();
    _pageController = PageController(initialPage: _pageIndex);
    _scheduleConfig.addListener(_onScheduleConfigChanged);
    _allSchedules.addListener(_onAllSchedulesChanged);
  }

  final ValueListenable<ScheduleConfig> _scheduleConfig;
  final ValueListenable<List<ScheduleConfig>> _allSchedules;
  final ValueListenable<Duration> _animationDuration;

  /// 放假页可用性。grid 只在结构变化（pageCount 增减）时需要重建，所以单独暴露
  /// 而非塞进 [notifyListeners] —— 否则每次翻页都会重建整个 PageView。
  final ValueNotifier<bool> showVacationPage;

  late PageController _pageController;

  /// 已结算页码，唯一权威。
  int _pageIndex = 0;

  /// `jumpToPage` 会同步触发 `onPageChanged`。若 PageView 尚未重建到新
  /// `pageCount`（`showVacationPage` 刚翻面），目标页会被旧 PageView clamp，
  /// 回灌的 `onPageChanged` 会把 `_pageIndex` 拉回。此期间抑制反馈通道。
  bool _suppressOnPageSettled = false;

  /// `dispose` 后 `addPostFrameCallback` 仍可能触发，需短路。
  bool _disposed = false;

  // ---- Getters ----

  /// PageController（执行器）。detach 期间可能被换实例，build 每次重读，禁止缓存到
  /// State 字段 —— 否则 detach 重建机制会失效。
  PageController get pageController => _pageController;

  int get pageIndex => _pageIndex;

  /// 用户当前看到的周数（1-based）。放假页时返回末周。
  int get visibleWeek => _pageIndex.clamp(0, totalWeeks - 1) + 1;

  /// 是否正在看放假页。
  bool get isViewingVacation =>
      showVacationPage.value && _pageIndex >= totalWeeks;

  bool get canGoPrevious => _pageIndex > 0;

  bool get canGoNext => _pageIndex < pageCount - 1;

  int get pageCount => showVacationPage.value ? totalWeeks + 1 : totalWeeks;

  ScheduleConfig get config => _scheduleConfig.value;

  /// 防止 [ScheduleConfig.totalWeeks] 为 0 时 clamp(1, 0) 抛 ArgumentError。
  int get totalWeeks => _scheduleConfig.value.totalWeeks < 1
      ? 1
      : _scheduleConfig.value.totalWeeks;

  /// 未 clamp 的日历周（基于 [ScheduleConfig.getCurrentWeek]）。
  int get actualWeek => _scheduleConfig.value.getCurrentWeek();

  /// 顶栏徽章：今天是否在假期中（学期已结束且下学期未开始）。
  bool get isTodayOnVacation =>
      showVacationPage.value && actualWeek > totalWeeks;

  // ---- Public API ----

  /// 跳到指定周（1-based）。> totalWeeks 且有放假页 → 放假页。
  void goToWeek(int week) {
    final tw = totalWeeks;
    final int target;
    if (week > tw && showVacationPage.value) {
      target = tw; // vacation page index
    } else {
      target = week.clamp(1, tw) - 1;
    }
    _moveTo(target, animate: true);
  }

  /// 一行 _moveTo(_pageIndex±1)，取代 _changeWeek/_navigateToVacation 分支团。
  void goToPreviousPage() => _moveTo(_pageIndex - 1, animate: true);

  void goToNextPage() => _moveTo(_pageIndex + 1, animate: true);

  /// 顶栏点日期：refresh + _moveTo(_indexForToday(), animate)。
  /// 注意：不在此处触发 _checkAndPromptNextSemester —— 那是 State 的职责，
  /// 仅在 initState postFrame 调一次。
  void goToToday() {
    refreshVacationAvailability();
    _moveTo(_indexForToday(), animate: true);
  }

  /// 重算放假页可用性；关掉放假页时若正在看 → 退回末周。
  void refreshVacationAvailability() {
    final next = _computeShowVacationPage();
    if (next == showVacationPage.value) return;
    final wasViewingVacation = isViewingVacation;
    showVacationPage.value = next;
    if (!next && wasViewingVacation) {
      _moveTo(totalWeeks - 1, animate: false);
    } else {
      notifyListeners();
    }
  }

  /// 回前台：刷新可用性 + notify，绝不跳周。
  void refreshToday() {
    refreshVacationAvailability();
    notifyListeners();
  }

  /// PageView.onPageChanged 反馈通道。== _pageIndex 时静默吸收
  /// （自己发起的动画回灌）。越界 index 会 clamp 到 [0, pageCount-1]。
  void onPageSettled(int index) {
    if (_suppressOnPageSettled) return;
    final clamped = index.clamp(0, pageCount - 1);
    if (clamped == _pageIndex) return;
    _pageIndex = clamped;
    notifyListeners();
  }

  // ---- Private ----

  /// 构造与切表共用的「今天对应页」规则：
  /// 假期且有放假页 → totalWeeks；否则 actualWeek.clamp(1, totalWeeks) - 1。
  /// 消灭现在「先跳末周再动画进放假页」的两段式行为。
  int _indexForToday() {
    final aw = actualWeek;
    final tw = totalWeeks;
    if (showVacationPage.value && aw > tw) {
      return tw; // vacation page index
    }
    return aw.clamp(1, tw) - 1;
  }

  /// 核心移动逻辑：clamp → 更新 _pageIndex → 同步 PageController → notify on change。
  /// 移动判定用物理位置（pageController.page?.round() != target）而非缓存 int 比较，
  /// 根治「同值不通知」bug。
  void _moveTo(int target, {required bool animate}) {
    final clamped = target.clamp(0, pageCount - 1);
    if (clamped == _pageIndex) return;
    _pageIndex = clamped;
    if (_pageController.hasClients) {
      final physicalPage = _pageController.page?.round();
      if (physicalPage != clamped) {
        if (animate) {
          _pageController.animateToPage(
            clamped,
            duration: _animationDuration.value,
            curve: AppCurves.quick,
          );
        } else {
          // jumpToPage 同步触发 onPageChanged，期间抑制反馈通道防止 clamp 回灌。
          // animateToPage 是异步的（动画结束后才回灌），不抑制 —— 否则用户
          // 滑动/动画落位后的反馈会被吞掉。
          _suppressOnPageSettled = true;
          _pageController.jumpToPage(clamped);
          _suppressOnPageSettled = false;
        }
      }
    } else {
      // !hasClients：PageView 未挂载，jumpToPage 会被静默丢弃（「未挂载跳页丢失」bug）。
      // 换新 PageController(initialPage: target)，旧实例无 clients 可立即 dispose
      // （initialPage 构造后不可变，所以必须换实例）。
      _pageController.dispose();
      _pageController = PageController(initialPage: clamped);
    }
    notifyListeners();
  }

  /// 切换课表/导入时：刷新放假页 → 落到新当前周 → 无条件 notify
  /// （totalWeeks/actualWeek 变了顶栏也要重画）。
  ///
  /// `showVacationPage` 翻面会改变 `pageCount`，但 PageView 要到下一帧才重建到
  /// 新 itemCount。`_moveTo` 里的 `jumpToPage` 可能在旧 PageView 上被 clamp
  /// （抑制了顶栏回灌，但 PageController 物理位置仍停在 clamp 后的页）。
  /// 下一帧再同步一次，确保网格也跳到目标页。
  void _onScheduleConfigChanged() {
    showVacationPage.value = _computeShowVacationPage();
    _moveTo(_indexForToday(), animate: false);
    WidgetsBinding.instance.addPostFrameCallback(_resyncPageController);
    notifyListeners();
  }

  void _resyncPageController(Duration _) {
    if (_disposed) return;
    if (!_pageController.hasClients) return;
    final physicalPage = _pageController.page?.round();
    if (physicalPage != _pageIndex) {
      _suppressOnPageSettled = true;
      _pageController.jumpToPage(_pageIndex);
      _suppressOnPageSettled = false;
    }
  }

  /// allSchedules 单独变化（新增/删除非当前课表）：仅刷新放假页可用性，
  /// 不自动跳周。
  void _onAllSchedulesChanged() => refreshVacationAvailability();

  /// 从 course_page.dart 原样搬入：当前学期已结束且下学期未开始 → 显示放假页。
  bool _computeShowVacationPage() {
    final config = _scheduleConfig.value;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 学期未结束 → 不显示
    if (!today.isAfter(config.semesterEndDate)) return false;

    // 找下学期（当前学期结束后最早开始的课表）
    ScheduleConfig? next;
    for (final s in _allSchedules.value) {
      if (s.id != config.id &&
          s.semesterStartDate.isAfter(config.semesterEndDate)) {
        if (next == null ||
            s.semesterStartDate.isBefore(next.semesterStartDate)) {
          next = s;
        }
      }
    }
    if (next == null) return false;

    // 今天在下学期开始前
    return today.isBefore(next.semesterStartDate);
  }

  @override
  void dispose() {
    _disposed = true;
    _scheduleConfig.removeListener(_onScheduleConfigChanged);
    _allSchedules.removeListener(_onAllSchedulesChanged);
    showVacationPage.dispose();
    _pageController.dispose();
    super.dispose();
  }
}
