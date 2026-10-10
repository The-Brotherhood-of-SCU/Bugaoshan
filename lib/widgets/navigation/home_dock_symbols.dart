import 'package:bugaoshan/utils/constants.dart';

/// SF Symbols 只在原生 Dock 中使用；Material 图标仍由 CampusItemConfig 提供。
/// 新增入口未配置时使用通用符号，避免影响导航可用性。
({String normal, String selected}) homeDockSymbols(String id) => switch (id) {
  dockIdCourse => (normal: 'book', selected: 'book.fill'),
  dockIdCampus => (normal: 'building.2', selected: 'building.2.fill'),
  dockIdProfile => (
    normal: 'person.crop.circle',
    selected: 'person.crop.circle.fill',
  ),
  dockIdGrades => (normal: 'chart.bar', selected: 'chart.bar.fill'),
  dockIdCcyl => (normal: 'star', selected: 'star.fill'),
  dockIdPlanCompletion => (normal: 'chart.pie', selected: 'chart.pie.fill'),
  dockIdTrainProgram => (
    normal: 'list.bullet.rectangle',
    selected: 'list.bullet.rectangle.fill',
  ),
  dockIdClassroom => (
    normal: 'door.left.hand.open',
    selected: 'door.left.hand.open',
  ),
  dockIdNetworkDevice => (normal: 'network', selected: 'network'),
  dockIdPasspoint => (normal: 'wifi', selected: 'wifi'),
  dockIdBalanceQuery => (normal: 'bolt', selected: 'bolt.fill'),
  dockIdAcademicCalendar => (normal: 'calendar', selected: 'calendar'),
  dockIdFitnessTest => (normal: 'figure.run', selected: 'figure.run'),
  dockIdNotice => (normal: 'megaphone', selected: 'megaphone.fill'),
  dockIdDownloadedAttachments => (normal: 'folder', selected: 'folder.fill'),
  dockIdClassScheduleInquiry => (
    normal: 'magnifyingglass',
    selected: 'magnifyingglass',
  ),
  dockIdCourseCurriculum => (
    normal: 'books.vertical',
    selected: 'books.vertical.fill',
  ),
  dockIdExamPlan => (normal: 'doc.text', selected: 'doc.text.fill'),
  dockIdZysc => (normal: 'heart', selected: 'heart.fill'),
  dockIdLeave => (normal: 'checklist', selected: 'checklist'),
  dockIdRepair => (
    normal: 'wrench.and.screwdriver',
    selected: 'wrench.and.screwdriver.fill',
  ),
  _ => (normal: 'square.grid.2x2', selected: 'square.grid.2x2.fill'),
};
