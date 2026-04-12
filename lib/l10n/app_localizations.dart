import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(
      languageCode: 'zh',
      countryCode: 'CN',
      scriptCode: 'Hans',
    ),
  ];

  /// No description provided for @bugaoshan.
  ///
  /// In en, this message translates to:
  /// **'Bugaoshan'**
  String get bugaoshan;

  /// No description provided for @selfLanguage.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get selfLanguage;

  /// No description provided for @course.
  ///
  /// In en, this message translates to:
  /// **'Course'**
  String get course;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @campus.
  ///
  /// In en, this message translates to:
  /// **'Campus'**
  String get campus;

  /// No description provided for @classroomQuery.
  ///
  /// In en, this message translates to:
  /// **'Classroom Query'**
  String get classroomQuery;

  /// No description provided for @classroomQueryDesc.
  ///
  /// In en, this message translates to:
  /// **'Check classroom availability and borrowing status'**
  String get classroomQueryDesc;

  /// No description provided for @selectCampus.
  ///
  /// In en, this message translates to:
  /// **'Select Campus'**
  String get selectCampus;

  /// No description provided for @selectBuilding.
  ///
  /// In en, this message translates to:
  /// **'Select Building'**
  String get selectBuilding;

  /// No description provided for @allBuildings.
  ///
  /// In en, this message translates to:
  /// **'All Buildings'**
  String get allBuildings;

  /// No description provided for @seats.
  ///
  /// In en, this message translates to:
  /// **'seats'**
  String get seats;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @inClass.
  ///
  /// In en, this message translates to:
  /// **'In Class'**
  String get inClass;

  /// No description provided for @borrowed.
  ///
  /// In en, this message translates to:
  /// **'Borrowed'**
  String get borrowed;

  /// No description provided for @period.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get period;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed, tap to retry'**
  String get loadFailed;

  /// No description provided for @campusNetworkRequired.
  ///
  /// In en, this message translates to:
  /// **'This feature is only available on campus network. Please connect to campus Wi-Fi or use the school VPN.'**
  String get campusNetworkRequired;

  /// No description provided for @appOnly.
  ///
  /// In en, this message translates to:
  /// **'Available on App only'**
  String get appOnly;

  /// No description provided for @softwareSetting.
  ///
  /// In en, this message translates to:
  /// **'Software Setting'**
  String get softwareSetting;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get followSystem;

  /// No description provided for @modifyLanguage.
  ///
  /// In en, this message translates to:
  /// **'Modify Language'**
  String get modifyLanguage;

  /// No description provided for @current.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get current;

  /// No description provided for @animationDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get animationDuration;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @currentAnimationDuration.
  ///
  /// In en, this message translates to:
  /// **'Current Animation Duration: {value} ms'**
  String currentAnimationDuration(Object value);

  /// No description provided for @animationDurationUpdated.
  ///
  /// In en, this message translates to:
  /// **'Animation Duration updated to {value} ms'**
  String animationDurationUpdated(Object value);

  /// No description provided for @animationDurationHint.
  ///
  /// In en, this message translates to:
  /// **'Hint: Adjust the slider to preview the animation, click Confirm to save the settings'**
  String get animationDurationHint;

  /// No description provided for @themeColor.
  ///
  /// In en, this message translates to:
  /// **'Theme Color'**
  String get themeColor;

  /// No description provided for @changeThemeColor.
  ///
  /// In en, this message translates to:
  /// **'Change Theme Color'**
  String get changeThemeColor;

  /// No description provided for @confirmButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmButton;

  /// No description provided for @customizedColorHint.
  ///
  /// In en, this message translates to:
  /// **'Customized color is generated by color seed'**
  String get customizedColorHint;

  /// No description provided for @tips.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get tips;

  /// No description provided for @resetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get resetToDefault;

  /// No description provided for @blockPicker.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get blockPicker;

  /// No description provided for @materialPicker.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get materialPicker;

  /// No description provided for @advancedPicker.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advancedPicker;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @developmentTeam.
  ///
  /// In en, this message translates to:
  /// **'Developer Team'**
  String get developmentTeam;

  /// No description provided for @projectInfo.
  ///
  /// In en, this message translates to:
  /// **'Project Info'**
  String get projectInfo;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'App Name'**
  String get appName;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @appDescription.
  ///
  /// In en, this message translates to:
  /// **'A simple and practical course management app'**
  String get appDescription;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// No description provided for @developedBy.
  ///
  /// In en, this message translates to:
  /// **'Developed by {team}'**
  String developedBy(Object team);

  /// No description provided for @externalResources.
  ///
  /// In en, this message translates to:
  /// **'External Resources'**
  String get externalResources;

  /// No description provided for @projectRepository.
  ///
  /// In en, this message translates to:
  /// **'Project Repository'**
  String get projectRepository;

  /// No description provided for @clearAllData.
  ///
  /// In en, this message translates to:
  /// **'Clear All Data'**
  String get clearAllData;

  /// No description provided for @confirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get confirmMessage;

  /// No description provided for @environmentInfo.
  ///
  /// In en, this message translates to:
  /// **'Environment Info'**
  String get environmentInfo;

  /// No description provided for @scheduleSetting.
  ///
  /// In en, this message translates to:
  /// **'Schedule Setting'**
  String get scheduleSetting;

  /// No description provided for @scheduleManagement.
  ///
  /// In en, this message translates to:
  /// **'Schedule Management'**
  String get scheduleManagement;

  /// No description provided for @globalSetting.
  ///
  /// In en, this message translates to:
  /// **'Global Setting'**
  String get globalSetting;

  /// No description provided for @addCourse.
  ///
  /// In en, this message translates to:
  /// **'Add Course'**
  String get addCourse;

  /// No description provided for @editCourse.
  ///
  /// In en, this message translates to:
  /// **'Edit Course'**
  String get editCourse;

  /// No description provided for @deleteCourse.
  ///
  /// In en, this message translates to:
  /// **'Delete Course'**
  String get deleteCourse;

  /// No description provided for @deleteCourseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this course?'**
  String get deleteCourseConfirm;

  /// No description provided for @courseName.
  ///
  /// In en, this message translates to:
  /// **'Course Name'**
  String get courseName;

  /// No description provided for @teacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get teacher;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @courseColor.
  ///
  /// In en, this message translates to:
  /// **'Course Color'**
  String get courseColor;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @startWeek.
  ///
  /// In en, this message translates to:
  /// **'Start Week'**
  String get startWeek;

  /// No description provided for @endWeek.
  ///
  /// In en, this message translates to:
  /// **'End Week'**
  String get endWeek;

  /// No description provided for @dayOfWeek.
  ///
  /// In en, this message translates to:
  /// **'Day of Week'**
  String get dayOfWeek;

  /// No description provided for @startSection.
  ///
  /// In en, this message translates to:
  /// **'Start Section'**
  String get startSection;

  /// No description provided for @endSection.
  ///
  /// In en, this message translates to:
  /// **'End Section'**
  String get endSection;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get sunday;

  /// No description provided for @currentWeek.
  ///
  /// In en, this message translates to:
  /// **'Week {week}'**
  String currentWeek(Object week);

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @weekRange.
  ///
  /// In en, this message translates to:
  /// **'Week {start} - {end}'**
  String weekRange(Object end, Object start);

  /// No description provided for @weekType.
  ///
  /// In en, this message translates to:
  /// **'Week Type'**
  String get weekType;

  /// No description provided for @everyWeek.
  ///
  /// In en, this message translates to:
  /// **'Every Week'**
  String get everyWeek;

  /// No description provided for @oddWeek.
  ///
  /// In en, this message translates to:
  /// **'Odd Week'**
  String get oddWeek;

  /// No description provided for @evenWeek.
  ///
  /// In en, this message translates to:
  /// **'Even Week'**
  String get evenWeek;

  /// No description provided for @section.
  ///
  /// In en, this message translates to:
  /// **'Sec'**
  String get section;

  /// No description provided for @sectionCount.
  ///
  /// In en, this message translates to:
  /// **'Sections per Day'**
  String get sectionCount;

  /// No description provided for @timeSlot.
  ///
  /// In en, this message translates to:
  /// **'Time Slot'**
  String get timeSlot;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End Time'**
  String get endTime;

  /// No description provided for @semesterConfig.
  ///
  /// In en, this message translates to:
  /// **'Semester Config'**
  String get semesterConfig;

  /// No description provided for @semesterName.
  ///
  /// In en, this message translates to:
  /// **'Semester Name'**
  String get semesterName;

  /// No description provided for @semesterStartDate.
  ///
  /// In en, this message translates to:
  /// **'Semester Start Date'**
  String get semesterStartDate;

  /// No description provided for @semesterEndDate.
  ///
  /// In en, this message translates to:
  /// **'Semester End Date'**
  String get semesterEndDate;

  /// No description provided for @displaySetting.
  ///
  /// In en, this message translates to:
  /// **'Display Setting'**
  String get displaySetting;

  /// No description provided for @colorOpacity.
  ///
  /// In en, this message translates to:
  /// **'Color Opacity'**
  String get colorOpacity;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get fontSize;

  /// No description provided for @showCourseGrid.
  ///
  /// In en, this message translates to:
  /// **'Show Course Grid'**
  String get showCourseGrid;

  /// No description provided for @showTeacher.
  ///
  /// In en, this message translates to:
  /// **'Show Teacher'**
  String get showTeacher;

  /// No description provided for @showLocation.
  ///
  /// In en, this message translates to:
  /// **'Show Location'**
  String get showLocation;

  /// No description provided for @showWeekend.
  ///
  /// In en, this message translates to:
  /// **'Show Weekend'**
  String get showWeekend;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @customColor.
  ///
  /// In en, this message translates to:
  /// **'Custom Color'**
  String get customColor;

  /// No description provided for @noCourseThisWeek.
  ///
  /// In en, this message translates to:
  /// **'No courses this week'**
  String get noCourseThisWeek;

  /// No description provided for @timeConflict.
  ///
  /// In en, this message translates to:
  /// **'Time Conflict'**
  String get timeConflict;

  /// No description provided for @timeConflictMessage.
  ///
  /// In en, this message translates to:
  /// **'The selected time slot conflicts with an existing course.'**
  String get timeConflictMessage;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// No description provided for @invalidWeekRange.
  ///
  /// In en, this message translates to:
  /// **'End week must be greater than or equal to start week'**
  String get invalidWeekRange;

  /// No description provided for @duplicateScheduleName.
  ///
  /// In en, this message translates to:
  /// **'Schedule name already exists'**
  String get duplicateScheduleName;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Schedule data copied to clipboard'**
  String get exportSuccess;

  /// No description provided for @importSchedule.
  ///
  /// In en, this message translates to:
  /// **'Import Schedule'**
  String get importSchedule;

  /// No description provided for @importFromShare.
  ///
  /// In en, this message translates to:
  /// **'Import from Share'**
  String get importFromShare;

  /// No description provided for @importFromJwxt.
  ///
  /// In en, this message translates to:
  /// **'Import from Education System'**
  String get importFromJwxt;

  /// No description provided for @importDataHint.
  ///
  /// In en, this message translates to:
  /// **'Paste JSON data here...'**
  String get importDataHint;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Schedule imported successfully'**
  String get importSuccess;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed, please check data format'**
  String get importFailed;

  /// No description provided for @importedScheduleDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Imported Schedule'**
  String get importedScheduleDefaultName;

  /// No description provided for @importNameConflictHint.
  ///
  /// In en, this message translates to:
  /// **'Name \"{name}\" already exists, please rename:'**
  String importNameConflictHint(Object name);

  /// No description provided for @importNameSuffix.
  ///
  /// In en, this message translates to:
  /// **'(Import)'**
  String get importNameSuffix;

  /// No description provided for @defaultScheduleName.
  ///
  /// In en, this message translates to:
  /// **'Default Schedule'**
  String get defaultScheduleName;

  /// No description provided for @deleteScheduleConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete schedule \"{name}\"?'**
  String deleteScheduleConfirm(Object name);

  /// No description provided for @exportSchedule.
  ///
  /// In en, this message translates to:
  /// **'Export Schedule'**
  String get exportSchedule;

  /// No description provided for @copySuffix.
  ///
  /// In en, this message translates to:
  /// **' (Copy)'**
  String get copySuffix;

  /// No description provided for @notThisWeek.
  ///
  /// In en, this message translates to:
  /// **'[Not this week]'**
  String get notThisWeek;

  /// No description provided for @actualCurrentWeek.
  ///
  /// In en, this message translates to:
  /// **'Week {week}'**
  String actualCurrentWeek(Object week);

  /// No description provided for @totalWeeksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} weeks'**
  String totalWeeksSubtitle(Object count);

  /// No description provided for @invalidSectionRange.
  ///
  /// In en, this message translates to:
  /// **'End section must be greater than start section'**
  String get invalidSectionRange;

  /// No description provided for @crossPeriodError.
  ///
  /// In en, this message translates to:
  /// **'Cross Period Error'**
  String get crossPeriodError;

  /// No description provided for @crossPeriodErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'A course cannot span across morning, afternoon, or evening periods.'**
  String get crossPeriodErrorMessage;

  /// No description provided for @totalWeeks.
  ///
  /// In en, this message translates to:
  /// **'Total Weeks: {value}'**
  String totalWeeks(Object value);

  /// No description provided for @morning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get morning;

  /// No description provided for @afternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get afternoon;

  /// No description provided for @evening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get evening;

  /// No description provided for @courseDuration.
  ///
  /// In en, this message translates to:
  /// **'Course Duration (mins)'**
  String get courseDuration;

  /// No description provided for @breakDuration.
  ///
  /// In en, this message translates to:
  /// **'Break Duration (mins)'**
  String get breakDuration;

  /// No description provided for @autoSyncTime.
  ///
  /// In en, this message translates to:
  /// **'Auto-calculate subsequent times'**
  String get autoSyncTime;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script+country codes are specified.
  switch (locale.toString()) {
    case 'zh_Hans_CN':
      return AppLocalizationsZhHansCn();
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
