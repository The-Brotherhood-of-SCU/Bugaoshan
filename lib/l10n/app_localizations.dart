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

  /// No description provided for @wizardWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Bugaoshan'**
  String get wizardWelcomeTitle;

  /// No description provided for @wizardWelcomeDesc.
  ///
  /// In en, this message translates to:
  /// **'Your campus assistant: schedules, grades and campus services in one place'**
  String get wizardWelcomeDesc;

  /// No description provided for @wizardLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login & Import Schedule'**
  String get wizardLoginTitle;

  /// No description provided for @wizardLoginStep1.
  ///
  /// In en, this message translates to:
  /// **'Log in with SCU Unified Identity'**
  String get wizardLoginStep1;

  /// No description provided for @wizardLoginStep2.
  ///
  /// In en, this message translates to:
  /// **'Import schedule from academic system'**
  String get wizardLoginStep2;

  /// No description provided for @wizardLoginDone.
  ///
  /// In en, this message translates to:
  /// **'Logged in'**
  String get wizardLoginDone;

  /// No description provided for @wizardLoginButton.
  ///
  /// In en, this message translates to:
  /// **'Go to Login'**
  String get wizardLoginButton;

  /// No description provided for @wizardImportButton.
  ///
  /// In en, this message translates to:
  /// **'Import Schedule'**
  String get wizardImportButton;

  /// No description provided for @wizardImportHint.
  ///
  /// In en, this message translates to:
  /// **'Auto-fetch schedule after login'**
  String get wizardImportHint;

  /// No description provided for @wizardFeatureTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore More Features'**
  String get wizardFeatureTitle;

  /// No description provided for @wizardFeatureCourse.
  ///
  /// In en, this message translates to:
  /// **'Course Schedule'**
  String get wizardFeatureCourse;

  /// No description provided for @wizardFeatureCourseDesc.
  ///
  /// In en, this message translates to:
  /// **'View weekly classes, manage multiple schedules, import from academic system, share and export as calendar files'**
  String get wizardFeatureCourseDesc;

  /// No description provided for @wizardFeatureCampus.
  ///
  /// In en, this message translates to:
  /// **'Campus Services'**
  String get wizardFeatureCampus;

  /// No description provided for @wizardFeatureCampusDesc.
  ///
  /// In en, this message translates to:
  /// **'Check classroom availability and grades, join CCYL activities, query utility balance, manage network devices'**
  String get wizardFeatureCampusDesc;

  /// No description provided for @wizardFeatureProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get wizardFeatureProfile;

  /// No description provided for @wizardFeatureProfileDesc.
  ///
  /// In en, this message translates to:
  /// **'Log in with SCU Unified Identity, bind CCYL account, customize theme colors, dark mode and language preferences'**
  String get wizardFeatureProfileDesc;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingStart;

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

  /// No description provided for @utilitiesSection.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get utilitiesSection;

  /// No description provided for @academicSection.
  ///
  /// In en, this message translates to:
  /// **'Academic'**
  String get academicSection;

  /// No description provided for @moreFeaturesTitle.
  ///
  /// In en, this message translates to:
  /// **'More Features'**
  String get moreFeaturesTitle;

  /// No description provided for @moreFeaturesDesc.
  ///
  /// In en, this message translates to:
  /// **'Create an Issue to request more features'**
  String get moreFeaturesDesc;

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

  /// No description provided for @classroomPeriodExam.
  ///
  /// In en, this message translates to:
  /// **'Exam'**
  String get classroomPeriodExam;

  /// No description provided for @classroomPeriodExperiment.
  ///
  /// In en, this message translates to:
  /// **'Experiment'**
  String get classroomPeriodExperiment;

  /// No description provided for @classroomTeachingWeek.
  ///
  /// In en, this message translates to:
  /// **'Week {week}'**
  String classroomTeachingWeek(int week);

  /// No description provided for @classroomQueryDate.
  ///
  /// In en, this message translates to:
  /// **'Query Date: {date}'**
  String classroomQueryDate(String date);

  /// No description provided for @classroomCanBorrow.
  ///
  /// In en, this message translates to:
  /// **'Borrowable'**
  String get classroomCanBorrow;

  /// No description provided for @classroomCannotBorrow.
  ///
  /// In en, this message translates to:
  /// **'Not Borrowable'**
  String get classroomCannotBorrow;

  /// No description provided for @classroomRemark.
  ///
  /// In en, this message translates to:
  /// **'Remark'**
  String get classroomRemark;

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
  /// **'Load Failed'**
  String get loadFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @campusNetworkRequired.
  ///
  /// In en, this message translates to:
  /// **'This feature is only available on campus network. Please connect to campus Wi-Fi or use the school VPN.'**
  String get campusNetworkRequired;

  /// No description provided for @campusNetworkRequiredAtNight.
  ///
  /// In en, this message translates to:
  /// **'Access is restricted to campus network during 0:00-6:00. Please connect to campus Wi-Fi or use the school VPN.'**
  String get campusNetworkRequiredAtNight;

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

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

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
  /// **'Dev Team'**
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

  /// No description provided for @gitTag.
  ///
  /// In en, this message translates to:
  /// **'Git Tag'**
  String get gitTag;

  /// No description provided for @appDescription.
  ///
  /// In en, this message translates to:
  /// **'Explore everything, all on the Bugaoshan'**
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
  /// **'Repository'**
  String get projectRepository;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check Updates'**
  String get checkForUpdates;

  /// No description provided for @newVersionAvailable.
  ///
  /// In en, this message translates to:
  /// **'New Version Available'**
  String get newVersionAvailable;

  /// No description provided for @noUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Already on Latest Version'**
  String get noUpdateAvailable;

  /// No description provided for @goToReleases.
  ///
  /// In en, this message translates to:
  /// **'Go to Releases'**
  String get goToReleases;

  /// No description provided for @startUpdate.
  ///
  /// In en, this message translates to:
  /// **'Start Update'**
  String get startUpdate;

  /// No description provided for @startUpdatePreview.
  ///
  /// In en, this message translates to:
  /// **'Update to Preview'**
  String get startUpdatePreview;

  /// No description provided for @updateToLatest.
  ///
  /// In en, this message translates to:
  /// **'Update to Latest'**
  String get updateToLatest;

  /// No description provided for @updateToStable.
  ///
  /// In en, this message translates to:
  /// **'Update to Latest Stable'**
  String get updateToStable;

  /// No description provided for @updateToPreview.
  ///
  /// In en, this message translates to:
  /// **'Update to Latest (Include Preview)'**
  String get updateToPreview;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloading;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get updateFailed;

  /// No description provided for @preReleaseWarning.
  ///
  /// In en, this message translates to:
  /// **'This is a pre-release version. Use with caution.'**
  String get preReleaseWarning;

  /// No description provided for @releaseNotes.
  ///
  /// In en, this message translates to:
  /// **'Release Notes'**
  String get releaseNotes;

  /// No description provided for @neverMind.
  ///
  /// In en, this message translates to:
  /// **'Never Mind'**
  String get neverMind;

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

  /// No description provided for @testPage.
  ///
  /// In en, this message translates to:
  /// **'Test Page'**
  String get testPage;

  /// No description provided for @forceUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update to Latest (Include Preview)'**
  String get forceUpdate;

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
  String weekRange(int start, int end);

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

  /// No description provided for @setCurrentWeek.
  ///
  /// In en, this message translates to:
  /// **'Set Current Week'**
  String get setCurrentWeek;

  /// No description provided for @setCurrentWeekHint.
  ///
  /// In en, this message translates to:
  /// **'Automatically calculates the semester start date based on the current week'**
  String get setCurrentWeekHint;

  /// No description provided for @autoFetchCurrentWeek.
  ///
  /// In en, this message translates to:
  /// **'Auto Fetch Current Week'**
  String get autoFetchCurrentWeek;

  /// No description provided for @autoFetchCurrentWeekHint.
  ///
  /// In en, this message translates to:
  /// **'Fetch current teaching week from academic system'**
  String get autoFetchCurrentWeekHint;

  /// No description provided for @fetchingCurrentWeek.
  ///
  /// In en, this message translates to:
  /// **'Fetching...'**
  String get fetchingCurrentWeek;

  /// No description provided for @loginRequired.
  ///
  /// In en, this message translates to:
  /// **'Please complete SCU Unified Identity login in the Profile page first'**
  String get loginRequired;

  /// No description provided for @goToLogin.
  ///
  /// In en, this message translates to:
  /// **'Go to Login'**
  String get goToLogin;

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

  /// No description provided for @courseCardSection.
  ///
  /// In en, this message translates to:
  /// **'Course Card'**
  String get courseCardSection;

  /// No description provided for @courseGridSection.
  ///
  /// In en, this message translates to:
  /// **'Course Grid'**
  String get courseGridSection;

  /// No description provided for @otherSection.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get otherSection;

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

  /// No description provided for @courseRowHeight.
  ///
  /// In en, this message translates to:
  /// **'Course Row Height'**
  String get courseRowHeight;

  /// No description provided for @backgroundImage.
  ///
  /// In en, this message translates to:
  /// **'Background Image'**
  String get backgroundImage;

  /// No description provided for @setBackgroundImage.
  ///
  /// In en, this message translates to:
  /// **'Set Background Image'**
  String get setBackgroundImage;

  /// No description provided for @extractColorFromBackgroundImage.
  ///
  /// In en, this message translates to:
  /// **'Extract Color from Background'**
  String get extractColorFromBackgroundImage;

  /// No description provided for @themeColorAutoExtractedHint.
  ///
  /// In en, this message translates to:
  /// **'Theme color extracted from background image. Go to Software Setting -> Theme Color to modify.'**
  String get themeColorAutoExtractedHint;

  /// No description provided for @noBackgroundImageSet.
  ///
  /// In en, this message translates to:
  /// **'Please set a background image first'**
  String get noBackgroundImageSet;

  /// No description provided for @removeBackgroundImage.
  ///
  /// In en, this message translates to:
  /// **'Remove Background Image'**
  String get removeBackgroundImage;

  /// No description provided for @backgroundImageOpacity.
  ///
  /// In en, this message translates to:
  /// **'Background Image Opacity'**
  String get backgroundImageOpacity;

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

  /// No description provided for @showNonCurrentWeekCourses.
  ///
  /// In en, this message translates to:
  /// **'Show Non-Current Week Courses'**
  String get showNonCurrentWeekCourses;

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

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

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
  /// **'Import failed'**
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

  /// No description provided for @exportScheduleAsCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy to Clipboard'**
  String get exportScheduleAsCopy;

  /// No description provided for @exportScheduleAsIcs.
  ///
  /// In en, this message translates to:
  /// **'Export to Calendar File'**
  String get exportScheduleAsIcs;

  /// No description provided for @exportScheduleAsCopySuccess.
  ///
  /// In en, this message translates to:
  /// **'Schedule data copied to clipboard'**
  String get exportScheduleAsCopySuccess;

  /// No description provided for @exportScheduleAsCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Copy failed, maybe you can try later'**
  String get exportScheduleAsCopyFailed;

  /// No description provided for @exportScheduleAsIcsTo.
  ///
  /// In en, this message translates to:
  /// **'Save Calendar File to...'**
  String get exportScheduleAsIcsTo;

  /// No description provided for @exportScheduleAsIcsSuccess.
  ///
  /// In en, this message translates to:
  /// **'File saved successfully'**
  String get exportScheduleAsIcsSuccess;

  /// No description provided for @exportScheduleAsIcsFailed.
  ///
  /// In en, this message translates to:
  /// **'File save failed'**
  String get exportScheduleAsIcsFailed;

  /// No description provided for @exportScheduleAsIcsCanceled.
  ///
  /// In en, this message translates to:
  /// **'File save canceled'**
  String get exportScheduleAsIcsCanceled;

  /// No description provided for @icsTeacherLabel.
  ///
  /// In en, this message translates to:
  /// **'Teacher(s)'**
  String get icsTeacherLabel;

  /// No description provided for @exportScheduleAddToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Import to Calendar'**
  String get exportScheduleAddToCalendar;

  /// No description provided for @exportScheduleAddToCalendarSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported to calendar'**
  String get exportScheduleAddToCalendarSuccess;

  /// No description provided for @exportScheduleAddToCalendarFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get exportScheduleAddToCalendarFailed;

  /// No description provided for @copySuffix.
  ///
  /// In en, this message translates to:
  /// **' (Copy)'**
  String get copySuffix;

  /// No description provided for @notThisWeek.
  ///
  /// In en, this message translates to:
  /// **'[Not]'**
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

  /// No description provided for @scuLogin.
  ///
  /// In en, this message translates to:
  /// **'SCU Unified Identity Login'**
  String get scuLogin;

  /// No description provided for @loggedIn.
  ///
  /// In en, this message translates to:
  /// **'Logged In'**
  String get loggedIn;

  /// No description provided for @notLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not Logged In'**
  String get notLoggedIn;

  /// No description provided for @loginSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Login Session Expired'**
  String get loginSessionExpired;

  /// No description provided for @loginSessionExpiredDesc.
  ///
  /// In en, this message translates to:
  /// **'Your login session has expired after 1 hour. Please login again.'**
  String get loginSessionExpiredDesc;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutConfirm;

  /// No description provided for @importFromJwxtOnline.
  ///
  /// In en, this message translates to:
  /// **'Online Import from JWXT'**
  String get importFromJwxtOnline;

  /// No description provided for @importFromJwxtOnlineHint.
  ///
  /// In en, this message translates to:
  /// **'Automatically fetch schedule. Please login with SCU Unified Identity in the Profile page first.'**
  String get importFromJwxtOnlineHint;

  /// No description provided for @selectSemester.
  ///
  /// In en, this message translates to:
  /// **'Select Semester'**
  String get selectSemester;

  /// No description provided for @importAll.
  ///
  /// In en, this message translates to:
  /// **'Import All'**
  String get importAll;

  /// No description provided for @importingProgress.
  ///
  /// In en, this message translates to:
  /// **'Importing {current}/{total}...'**
  String importingProgress(int current, int total);

  /// No description provided for @scuUnifiedAuth.
  ///
  /// In en, this message translates to:
  /// **'Unified Identity Authentication'**
  String get scuUnifiedAuth;

  /// No description provided for @studentId.
  ///
  /// In en, this message translates to:
  /// **'Student ID'**
  String get studentId;

  /// No description provided for @studentIdRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your student ID'**
  String get studentIdRequired;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get passwordRequired;

  /// No description provided for @captcha.
  ///
  /// In en, this message translates to:
  /// **'Captcha'**
  String get captcha;

  /// No description provided for @captchaRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the captcha'**
  String get captchaRequired;

  /// No description provided for @rememberPassword.
  ///
  /// In en, this message translates to:
  /// **'Remember Password'**
  String get rememberPassword;

  /// No description provided for @autoLogin.
  ///
  /// In en, this message translates to:
  /// **'Auto Login'**
  String get autoLogin;

  /// No description provided for @autoLoggingIn.
  ///
  /// In en, this message translates to:
  /// **'Logging in...'**
  String get autoLoggingIn;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @captchaLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load captcha'**
  String get captchaLoadFailed;

  /// No description provided for @captchaNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Please load the captcha first'**
  String get captchaNotLoaded;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error'**
  String get networkError;

  /// No description provided for @gradesStats.
  ///
  /// In en, this message translates to:
  /// **'Grade Statistics'**
  String get gradesStats;

  /// No description provided for @gradesStatsDesc.
  ///
  /// In en, this message translates to:
  /// **'View and analyze your academic performance'**
  String get gradesStatsDesc;

  /// No description provided for @gradesStatsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get gradesStatsComingSoon;

  /// No description provided for @schemeScores.
  ///
  /// In en, this message translates to:
  /// **'Scheme Scores'**
  String get schemeScores;

  /// No description provided for @passingScores.
  ///
  /// In en, this message translates to:
  /// **'Passing Scores'**
  String get passingScores;

  /// No description provided for @gradesLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Please complete SCU Unified Identity login in the Profile page first'**
  String get gradesLoginRequired;

  /// No description provided for @gradesNoData.
  ///
  /// In en, this message translates to:
  /// **'No grade data'**
  String get gradesNoData;

  /// No description provided for @gradesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load grades'**
  String get gradesLoadFailed;

  /// No description provided for @gradesRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed, showing cached data'**
  String get gradesRefreshFailed;

  /// No description provided for @gradesNoPassingData.
  ///
  /// In en, this message translates to:
  /// **'No passing grade data'**
  String get gradesNoPassingData;

  /// No description provided for @gradesGet.
  ///
  /// In en, this message translates to:
  /// **'Fetch Grades'**
  String get gradesGet;

  /// No description provided for @gradesRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get gradesRetry;

  /// No description provided for @gpa.
  ///
  /// In en, this message translates to:
  /// **'GPA'**
  String get gpa;

  /// No description provided for @overallGpa.
  ///
  /// In en, this message translates to:
  /// **'Overall GPA'**
  String get overallGpa;

  /// No description provided for @earnedCredits.
  ///
  /// In en, this message translates to:
  /// **'Earned Cr.'**
  String get earnedCredits;

  /// No description provided for @passedCount.
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get passedCount;

  /// No description provided for @failedCount.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failedCount;

  /// No description provided for @avgScore.
  ///
  /// In en, this message translates to:
  /// **'Avg Score'**
  String get avgScore;

  /// No description provided for @requiredAvgScore.
  ///
  /// In en, this message translates to:
  /// **'Required Avg'**
  String get requiredAvgScore;

  /// No description provided for @requiredCredits.
  ///
  /// In en, this message translates to:
  /// **'Required Cr.'**
  String get requiredCredits;

  /// No description provided for @electiveCredits.
  ///
  /// In en, this message translates to:
  /// **'Elective Cr.'**
  String get electiveCredits;

  /// No description provided for @optionalCredits.
  ///
  /// In en, this message translates to:
  /// **'Optional Cr.'**
  String get optionalCredits;

  /// No description provided for @requiredGpa.
  ///
  /// In en, this message translates to:
  /// **'Required GPA'**
  String get requiredGpa;

  /// No description provided for @totalPassedCount.
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get totalPassedCount;

  /// No description provided for @termCount.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get termCount;

  /// No description provided for @accumulatedCredits.
  ///
  /// In en, this message translates to:
  /// **'Total Credits'**
  String get accumulatedCredits;

  /// No description provided for @creditUnit.
  ///
  /// In en, this message translates to:
  /// **'{credit} cr.'**
  String creditUnit(Object credit);

  /// No description provided for @termPassedSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} courses · {credits} cr.'**
  String termPassedSummary(Object count, Object credits);

  /// No description provided for @sessionExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Expired'**
  String get sessionExpiredTitle;

  /// No description provided for @sessionExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Your login session has expired. Please login again to continue using this feature.'**
  String get sessionExpiredMessage;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired'**
  String get sessionExpired;

  /// No description provided for @relogin.
  ///
  /// In en, this message translates to:
  /// **'Login Again'**
  String get relogin;

  /// No description provided for @trainProgram.
  ///
  /// In en, this message translates to:
  /// **'Training Program'**
  String get trainProgram;

  /// No description provided for @trainProgramDesc.
  ///
  /// In en, this message translates to:
  /// **'Search training programs by college and grade'**
  String get trainProgramDesc;

  /// No description provided for @trainProgramCollege.
  ///
  /// In en, this message translates to:
  /// **'College'**
  String get trainProgramCollege;

  /// No description provided for @trainProgramGrade.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get trainProgramGrade;

  /// No description provided for @trainProgramAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get trainProgramAll;

  /// No description provided for @trainProgramSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get trainProgramSearch;

  /// No description provided for @trainProgramNoData.
  ///
  /// In en, this message translates to:
  /// **'No training program data'**
  String get trainProgramNoData;

  /// No description provided for @trainProgramLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get trainProgramLoading;

  /// No description provided for @trainProgramLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed'**
  String get trainProgramLoadFailed;

  /// No description provided for @trainProgramName.
  ///
  /// In en, this message translates to:
  /// **'Program Name'**
  String get trainProgramName;

  /// No description provided for @trainProgramMajor.
  ///
  /// In en, this message translates to:
  /// **'Major'**
  String get trainProgramMajor;

  /// No description provided for @trainProgramEducationSystem.
  ///
  /// In en, this message translates to:
  /// **'Education System'**
  String get trainProgramEducationSystem;

  /// No description provided for @trainProgramDegreeType.
  ///
  /// In en, this message translates to:
  /// **'Degree Type'**
  String get trainProgramDegreeType;

  /// No description provided for @trainProgramDetail.
  ///
  /// In en, this message translates to:
  /// **'Training Program Detail'**
  String get trainProgramDetail;

  /// No description provided for @trainProgramCredits.
  ///
  /// In en, this message translates to:
  /// **'Total Credits'**
  String get trainProgramCredits;

  /// No description provided for @trainProgramHours.
  ///
  /// In en, this message translates to:
  /// **'Total Hours'**
  String get trainProgramHours;

  /// No description provided for @trainProgramCourses.
  ///
  /// In en, this message translates to:
  /// **'Courses'**
  String get trainProgramCourses;

  /// No description provided for @trainProgramObjective.
  ///
  /// In en, this message translates to:
  /// **'Training Objective'**
  String get trainProgramObjective;

  /// No description provided for @trainProgramCourseStructure.
  ///
  /// In en, this message translates to:
  /// **'Course Structure'**
  String get trainProgramCourseStructure;

  /// No description provided for @trainProgramCourseNumber.
  ///
  /// In en, this message translates to:
  /// **'Course Number'**
  String get trainProgramCourseNumber;

  /// No description provided for @trainProgramOpenCollege.
  ///
  /// In en, this message translates to:
  /// **'Offering College'**
  String get trainProgramOpenCollege;

  /// No description provided for @trainProgramCourseType.
  ///
  /// In en, this message translates to:
  /// **'Course Type'**
  String get trainProgramCourseType;

  /// No description provided for @trainProgramExamType.
  ///
  /// In en, this message translates to:
  /// **'Exam Type'**
  String get trainProgramExamType;

  /// No description provided for @trainProgramTeachingMethod.
  ///
  /// In en, this message translates to:
  /// **'Teaching Method'**
  String get trainProgramTeachingMethod;

  /// No description provided for @trainProgramCourseHoursDetail.
  ///
  /// In en, this message translates to:
  /// **'Course Hours Detail'**
  String get trainProgramCourseHoursDetail;

  /// No description provided for @trainProgramWeekHours.
  ///
  /// In en, this message translates to:
  /// **'Weekly Hours'**
  String get trainProgramWeekHours;

  /// No description provided for @trainProgramActualHours.
  ///
  /// In en, this message translates to:
  /// **'Practice Hours'**
  String get trainProgramActualHours;

  /// No description provided for @trainProgramOpenCourse.
  ///
  /// In en, this message translates to:
  /// **'Open Course'**
  String get trainProgramOpenCourse;

  /// No description provided for @trainProgramCourseArrangement.
  ///
  /// In en, this message translates to:
  /// **'Course Arrangement'**
  String get trainProgramCourseArrangement;

  /// No description provided for @trainProgramPlanName.
  ///
  /// In en, this message translates to:
  /// **'Plan Name'**
  String get trainProgramPlanName;

  /// No description provided for @trainProgramCourseAttribute.
  ///
  /// In en, this message translates to:
  /// **'Course Attribute'**
  String get trainProgramCourseAttribute;

  /// No description provided for @trainProgramAcademicYear.
  ///
  /// In en, this message translates to:
  /// **'Academic Year'**
  String get trainProgramAcademicYear;

  /// No description provided for @trainProgramSemester.
  ///
  /// In en, this message translates to:
  /// **'Semester'**
  String get trainProgramSemester;

  /// No description provided for @trainProgramExperimentHours.
  ///
  /// In en, this message translates to:
  /// **'Experiment Hours'**
  String get trainProgramExperimentHours;

  /// No description provided for @trainProgramLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Please complete SCU Unified Identity login in the Profile page first'**
  String get trainProgramLoginRequired;

  /// No description provided for @planCompletion.
  ///
  /// In en, this message translates to:
  /// **'Plan Completion'**
  String get planCompletion;

  /// No description provided for @planCompletionDesc.
  ///
  /// In en, this message translates to:
  /// **'View progress of each training program module'**
  String get planCompletionDesc;

  /// No description provided for @planCompletionNoData.
  ///
  /// In en, this message translates to:
  /// **'No plan completion data'**
  String get planCompletionNoData;

  /// No description provided for @planCompletionTotalEarned.
  ///
  /// In en, this message translates to:
  /// **'Earned Credits'**
  String get planCompletionTotalEarned;

  /// No description provided for @planCompletionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get planCompletionCompleted;

  /// No description provided for @planCompletionCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get planCompletionCredits;

  /// No description provided for @planCompletionCreditsUnit.
  ///
  /// In en, this message translates to:
  /// **'cr'**
  String get planCompletionCreditsUnit;

  /// No description provided for @planCompletionCourses.
  ///
  /// In en, this message translates to:
  /// **'Courses'**
  String get planCompletionCourses;

  /// No description provided for @planCompletionRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests, please try again later'**
  String get planCompletionRateLimited;

  /// No description provided for @ccylTitle.
  ///
  /// In en, this message translates to:
  /// **'Second Classroom'**
  String get ccylTitle;

  /// No description provided for @ccylDesc.
  ///
  /// In en, this message translates to:
  /// **'Browse activities, participate, make reservations'**
  String get ccylDesc;

  /// No description provided for @ccylSearchActivities.
  ///
  /// In en, this message translates to:
  /// **'Activity Search'**
  String get ccylSearchActivities;

  /// No description provided for @ccylMyActivities.
  ///
  /// In en, this message translates to:
  /// **'My Activities'**
  String get ccylMyActivities;

  /// No description provided for @ccylOrderedActivities.
  ///
  /// In en, this message translates to:
  /// **'Reserved'**
  String get ccylOrderedActivities;

  /// No description provided for @ccylMyCredits.
  ///
  /// In en, this message translates to:
  /// **'Credit List'**
  String get ccylMyCredits;

  /// No description provided for @ccylSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get ccylSelect;

  /// No description provided for @ccylSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get ccylSelectAll;

  /// No description provided for @ccylExportEmail.
  ///
  /// In en, this message translates to:
  /// **'Export to Email'**
  String get ccylExportEmail;

  /// No description provided for @ccylEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'QQ Email'**
  String get ccylEmailAddress;

  /// No description provided for @ccylEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter QQ email to receive the report'**
  String get ccylEmailHint;

  /// No description provided for @ccylExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Report sent to email'**
  String get ccylExportSuccess;

  /// No description provided for @ccylSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search activity name'**
  String get ccylSearchHint;

  /// No description provided for @ccylHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get ccylHours;

  /// No description provided for @ccylAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get ccylAvailable;

  /// No description provided for @ccylInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get ccylInProgress;

  /// No description provided for @ccylCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get ccylCompleted;

  /// No description provided for @ccylSubscribed.
  ///
  /// In en, this message translates to:
  /// **'Subscribed'**
  String get ccylSubscribed;

  /// No description provided for @ccylSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get ccylSubscribe;

  /// No description provided for @ccylCancelSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Cancel Subscribe'**
  String get ccylCancelSubscribe;

  /// No description provided for @ccylSubscribeSuccess.
  ///
  /// In en, this message translates to:
  /// **'Subscribed successfully'**
  String get ccylSubscribeSuccess;

  /// No description provided for @ccylCancelSuccess.
  ///
  /// In en, this message translates to:
  /// **'Subscription cancelled successfully'**
  String get ccylCancelSuccess;

  /// No description provided for @ccylActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed'**
  String get ccylActionFailed;

  /// No description provided for @ccylSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get ccylSignUp;

  /// No description provided for @ccylCancelSignUp.
  ///
  /// In en, this message translates to:
  /// **'Cancel Sign Up'**
  String get ccylCancelSignUp;

  /// No description provided for @ccylSelectScoreType.
  ///
  /// In en, this message translates to:
  /// **'Select ability type to improve'**
  String get ccylSelectScoreType;

  /// No description provided for @ccylSignUpSuccess.
  ///
  /// In en, this message translates to:
  /// **'Signed up successfully'**
  String get ccylSignUpSuccess;

  /// No description provided for @ccylNoScoreType.
  ///
  /// In en, this message translates to:
  /// **'No ability types available'**
  String get ccylNoScoreType;

  /// No description provided for @ccylCurrentValue.
  ///
  /// In en, this message translates to:
  /// **'Current value'**
  String get ccylCurrentValue;

  /// No description provided for @ccylLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Please complete SCU Unified Identity login in the Profile page first'**
  String get ccylLoginRequired;

  /// No description provided for @ccylBindRequired.
  ///
  /// In en, this message translates to:
  /// **'Please bind your Second Classroom account first'**
  String get ccylBindRequired;

  /// No description provided for @ccylBindTitle.
  ///
  /// In en, this message translates to:
  /// **'Bind Second Classroom'**
  String get ccylBindTitle;

  /// No description provided for @ccylBindDesc.
  ///
  /// In en, this message translates to:
  /// **'Bind your Second Classroom account to view activities'**
  String get ccylBindDesc;

  /// No description provided for @ccylOpenOAuth.
  ///
  /// In en, this message translates to:
  /// **'Open OAuth Authorization'**
  String get ccylOpenOAuth;

  /// No description provided for @ccylDoBind.
  ///
  /// In en, this message translates to:
  /// **'Bind Second Classroom'**
  String get ccylDoBind;

  /// No description provided for @ccylBindHelp.
  ///
  /// In en, this message translates to:
  /// **'Click button to bind automatically'**
  String get ccylBindHelp;

  /// No description provided for @ccylActivitySeries.
  ///
  /// In en, this message translates to:
  /// **'Activity Series'**
  String get ccylActivitySeries;

  /// No description provided for @ccylActivityDetail.
  ///
  /// In en, this message translates to:
  /// **'Activity Detail'**
  String get ccylActivityDetail;

  /// No description provided for @ccylActivityInfo.
  ///
  /// In en, this message translates to:
  /// **'Activity Info'**
  String get ccylActivityInfo;

  /// No description provided for @ccylTimeInfo.
  ///
  /// In en, this message translates to:
  /// **'Time Info'**
  String get ccylTimeInfo;

  /// No description provided for @ccylLocationInfo.
  ///
  /// In en, this message translates to:
  /// **'Location Info'**
  String get ccylLocationInfo;

  /// No description provided for @ccylContactInfo.
  ///
  /// In en, this message translates to:
  /// **'Contact Info'**
  String get ccylContactInfo;

  /// No description provided for @ccylStarLevel.
  ///
  /// In en, this message translates to:
  /// **'Star Level'**
  String get ccylStarLevel;

  /// No description provided for @ccylQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get ccylQuality;

  /// No description provided for @ccylScoreType.
  ///
  /// In en, this message translates to:
  /// **'Score Type'**
  String get ccylScoreType;

  /// No description provided for @ccylLiablePerson.
  ///
  /// In en, this message translates to:
  /// **'Liable Person'**
  String get ccylLiablePerson;

  /// No description provided for @ccylLiablePhone.
  ///
  /// In en, this message translates to:
  /// **'Contact Phone'**
  String get ccylLiablePhone;

  /// No description provided for @ccylLiableTeacher.
  ///
  /// In en, this message translates to:
  /// **'Liable Teacher'**
  String get ccylLiableTeacher;

  /// No description provided for @ccylActivities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get ccylActivities;

  /// No description provided for @ccylQuota.
  ///
  /// In en, this message translates to:
  /// **'Quota'**
  String get ccylQuota;

  /// No description provided for @ccylActivityTarget.
  ///
  /// In en, this message translates to:
  /// **'Activity Target'**
  String get ccylActivityTarget;

  /// No description provided for @ccylActivityTime.
  ///
  /// In en, this message translates to:
  /// **'Activity Time'**
  String get ccylActivityTime;

  /// No description provided for @ccylEnrollTime.
  ///
  /// In en, this message translates to:
  /// **'Enrollment Time'**
  String get ccylEnrollTime;

  /// No description provided for @ccylActivityAddress.
  ///
  /// In en, this message translates to:
  /// **'Activity Address'**
  String get ccylActivityAddress;

  /// No description provided for @ccylContactPhone.
  ///
  /// In en, this message translates to:
  /// **'Contact Phone'**
  String get ccylContactPhone;

  /// No description provided for @ccylSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get ccylSignIn;

  /// No description provided for @ccylSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get ccylSignOut;

  /// No description provided for @ccylEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get ccylEnabled;

  /// No description provided for @ccylDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get ccylDisabled;

  /// No description provided for @ccylSeriesName.
  ///
  /// In en, this message translates to:
  /// **'Series Name'**
  String get ccylSeriesName;

  /// No description provided for @ccylOrganizer.
  ///
  /// In en, this message translates to:
  /// **'Organizer'**
  String get ccylOrganizer;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No Data'**
  String get noData;

  /// No description provided for @networkDeviceQuery.
  ///
  /// In en, this message translates to:
  /// **'Network Device Query'**
  String get networkDeviceQuery;

  /// No description provided for @networkDeviceQueryDesc.
  ///
  /// In en, this message translates to:
  /// **'Query campus network account and online devices'**
  String get networkDeviceQueryDesc;

  /// No description provided for @networkDeviceUserInfo.
  ///
  /// In en, this message translates to:
  /// **'User Information'**
  String get networkDeviceUserInfo;

  /// No description provided for @networkDeviceOnlineDevices.
  ///
  /// In en, this message translates to:
  /// **'Online Devices'**
  String get networkDeviceOnlineDevices;

  /// No description provided for @networkDeviceDeviceId.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get networkDeviceDeviceId;

  /// No description provided for @networkDeviceIp.
  ///
  /// In en, this message translates to:
  /// **'IP Address'**
  String get networkDeviceIp;

  /// No description provided for @networkDeviceLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get networkDeviceLogout;

  /// No description provided for @networkDeviceLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout all devices?'**
  String get networkDeviceLogoutConfirm;

  /// No description provided for @networkDeviceForceOffline.
  ///
  /// In en, this message translates to:
  /// **'Force Offline'**
  String get networkDeviceForceOffline;

  /// No description provided for @networkDeviceConfirmOffline.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to offline this device?'**
  String get networkDeviceConfirmOffline;

  /// No description provided for @networkDeviceOfflineSuccess.
  ///
  /// In en, this message translates to:
  /// **'Operation successful'**
  String get networkDeviceOfflineSuccess;

  /// No description provided for @networkDeviceAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed'**
  String get networkDeviceAuthFailed;

  /// No description provided for @networkDeviceOperationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Operation successful'**
  String get networkDeviceOperationSuccess;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginFailed;

  /// No description provided for @invalidCaptcha.
  ///
  /// In en, this message translates to:
  /// **'Invalid captcha, please try again'**
  String get invalidCaptcha;

  /// No description provided for @loginFailedWillLock.
  ///
  /// In en, this message translates to:
  /// **'Login failed, {count} more attempt(s) will lock your account'**
  String loginFailedWillLock(int count);

  /// No description provided for @ccylBindFailed.
  ///
  /// In en, this message translates to:
  /// **'Binding failed, please try again later'**
  String get ccylBindFailed;

  /// No description provided for @ccylActivityLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load activity'**
  String get ccylActivityLoadFailed;

  /// No description provided for @networkOfflineFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to offline device'**
  String get networkOfflineFailed;

  /// No description provided for @balanceQuery.
  ///
  /// In en, this message translates to:
  /// **'Balance Query'**
  String get balanceQuery;

  /// No description provided for @balanceQueryDesc.
  ///
  /// In en, this message translates to:
  /// **'Query electricity and AC fee balance'**
  String get balanceQueryDesc;

  /// No description provided for @electricityFee.
  ///
  /// In en, this message translates to:
  /// **'Electricity'**
  String get electricityFee;

  /// No description provided for @acFee.
  ///
  /// In en, this message translates to:
  /// **'AC Fee'**
  String get acFee;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @unitKwh.
  ///
  /// In en, this message translates to:
  /// **'kWh'**
  String get unitKwh;

  /// No description provided for @bindRoom.
  ///
  /// In en, this message translates to:
  /// **'Bind Room'**
  String get bindRoom;

  /// No description provided for @bindNewRoom.
  ///
  /// In en, this message translates to:
  /// **'Bind New Room'**
  String get bindNewRoom;

  /// No description provided for @switchRoom.
  ///
  /// In en, this message translates to:
  /// **'Switch Room'**
  String get switchRoom;

  /// No description provided for @deleteRoom.
  ///
  /// In en, this message translates to:
  /// **'Delete Room'**
  String get deleteRoom;

  /// No description provided for @selectUnit.
  ///
  /// In en, this message translates to:
  /// **'Select Unit'**
  String get selectUnit;

  /// No description provided for @inputInfo.
  ///
  /// In en, this message translates to:
  /// **'Input Info'**
  String get inputInfo;

  /// No description provided for @stepCampus.
  ///
  /// In en, this message translates to:
  /// **'Cmp'**
  String get stepCampus;

  /// No description provided for @stepBuilding.
  ///
  /// In en, this message translates to:
  /// **'Bld'**
  String get stepBuilding;

  /// No description provided for @stepUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get stepUnit;

  /// No description provided for @stepInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get stepInfo;

  /// No description provided for @inputBindingInfo.
  ///
  /// In en, this message translates to:
  /// **'Input Binding Info'**
  String get inputBindingInfo;

  /// No description provided for @cusName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get cusName;

  /// No description provided for @cusNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter name'**
  String get cusNameHint;

  /// No description provided for @roomNumber.
  ///
  /// In en, this message translates to:
  /// **'Room Number'**
  String get roomNumber;

  /// No description provided for @roomNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Enter room number, e.g. 301C'**
  String get roomNumberHint;

  /// No description provided for @pricePerUnit.
  ///
  /// In en, this message translates to:
  /// **'Price per unit'**
  String get pricePerUnit;

  /// No description provided for @balanceQueryLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Please complete SCU Unified Identity login in the Profile page first'**
  String get balanceQueryLoginRequired;

  /// No description provided for @balanceQueryNoBinding.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t bound any room yet, please bind first'**
  String get balanceQueryNoBinding;

  /// No description provided for @scuLoginDisclaimerPwd.
  ///
  /// In en, this message translates to:
  /// **'When \'Remember Password\' is enabled, your password is encrypted and stored locally using system-level encryption'**
  String get scuLoginDisclaimerPwd;

  /// No description provided for @scuLoginDisclaimerOcr.
  ///
  /// In en, this message translates to:
  /// **'Captcha is recognized by a local OCR model'**
  String get scuLoginDisclaimerOcr;

  /// No description provided for @scuLoginDisclaimerPrivacy.
  ///
  /// In en, this message translates to:
  /// **'We do not collect any personal information'**
  String get scuLoginDisclaimerPrivacy;

  /// No description provided for @openSourceLicenseDesc.
  ///
  /// In en, this message translates to:
  /// **'This app is open-sourced under AGPL-3.0'**
  String get openSourceLicenseDesc;

  /// No description provided for @academicCalendar.
  ///
  /// In en, this message translates to:
  /// **'Academic Calendar'**
  String get academicCalendar;

  /// No description provided for @academicCalendarDesc.
  ///
  /// In en, this message translates to:
  /// **'View SCU academic calendar and semester schedule'**
  String get academicCalendarDesc;

  /// No description provided for @selectAcademicYear.
  ///
  /// In en, this message translates to:
  /// **'Select Academic Year'**
  String get selectAcademicYear;

  /// No description provided for @userInfoLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading user info...'**
  String get userInfoLoading;

  /// No description provided for @userInfoLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load user info'**
  String get userInfoLoadFailed;

  /// No description provided for @userInfoRetry.
  ///
  /// In en, this message translates to:
  /// **'Tap to retry'**
  String get userInfoRetry;

  /// No description provided for @loginToViewUserInfo.
  ///
  /// In en, this message translates to:
  /// **'Login to view user info'**
  String get loginToViewUserInfo;

  /// No description provided for @labelBookBorrowCount.
  ///
  /// In en, this message translates to:
  /// **'Books Borrowed'**
  String get labelBookBorrowCount;

  /// No description provided for @labelCampusCardBalance.
  ///
  /// In en, this message translates to:
  /// **'Card Balance'**
  String get labelCampusCardBalance;

  /// No description provided for @labelNetworkFeeBalance.
  ///
  /// In en, this message translates to:
  /// **'Network Fee'**
  String get labelNetworkFeeBalance;

  /// No description provided for @customDock.
  ///
  /// In en, this message translates to:
  /// **'Custom Dock'**
  String get customDock;

  /// No description provided for @dockPreview.
  ///
  /// In en, this message translates to:
  /// **'Dock Preview'**
  String get dockPreview;

  /// No description provided for @resetDock.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get resetDock;

  /// No description provided for @dockResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset dock bar to default configuration?'**
  String get dockResetConfirm;

  /// No description provided for @cannotDeleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Cannot be deleted'**
  String get cannotDeleteProfile;

  /// No description provided for @dockLabelCourse.
  ///
  /// In en, this message translates to:
  /// **'Course'**
  String get dockLabelCourse;

  /// No description provided for @dockLabelCampus.
  ///
  /// In en, this message translates to:
  /// **'Campus'**
  String get dockLabelCampus;

  /// No description provided for @dockLabelProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get dockLabelProfile;

  /// No description provided for @dockLabelGrades.
  ///
  /// In en, this message translates to:
  /// **'Grades'**
  String get dockLabelGrades;

  /// No description provided for @dockLabelCcyl.
  ///
  /// In en, this message translates to:
  /// **'CCYL'**
  String get dockLabelCcyl;

  /// No description provided for @dockLabelPlanCompletion.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get dockLabelPlanCompletion;

  /// No description provided for @dockLabelTrainProgram.
  ///
  /// In en, this message translates to:
  /// **'Program'**
  String get dockLabelTrainProgram;

  /// No description provided for @dockLabelClassroom.
  ///
  /// In en, this message translates to:
  /// **'Classroom'**
  String get dockLabelClassroom;

  /// No description provided for @dockLabelNetworkDevice.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get dockLabelNetworkDevice;

  /// No description provided for @dockLabelBalanceQuery.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get dockLabelBalanceQuery;

  /// No description provided for @dockLabelAcademicCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get dockLabelAcademicCalendar;

  /// No description provided for @fitnessTest.
  ///
  /// In en, this message translates to:
  /// **'Fitness Test'**
  String get fitnessTest;

  /// No description provided for @fitnessTestDesc.
  ///
  /// In en, this message translates to:
  /// **'Query fitness test scores and view notices'**
  String get fitnessTestDesc;

  /// No description provided for @fitnessTestNotices.
  ///
  /// In en, this message translates to:
  /// **'Notices'**
  String get fitnessTestNotices;

  /// No description provided for @fitnessTestScores.
  ///
  /// In en, this message translates to:
  /// **'Scores'**
  String get fitnessTestScores;

  /// No description provided for @fitnessTestTotalScore.
  ///
  /// In en, this message translates to:
  /// **'Total Score'**
  String get fitnessTestTotalScore;

  /// No description provided for @fitnessTestGrade.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get fitnessTestGrade;

  /// No description provided for @fitnessTestYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get fitnessTestYear;

  /// No description provided for @fitnessTestNoScore.
  ///
  /// In en, this message translates to:
  /// **'No fitness test scores for this year'**
  String get fitnessTestNoScore;

  /// No description provided for @fitnessTestStudentNum.
  ///
  /// In en, this message translates to:
  /// **'Student ID'**
  String get fitnessTestStudentNum;

  /// No description provided for @fitnessTestStudentName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fitnessTestStudentName;

  /// No description provided for @fitnessTestSex.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get fitnessTestSex;

  /// No description provided for @fitnessTestReportType.
  ///
  /// In en, this message translates to:
  /// **'Report Type'**
  String get fitnessTestReportType;

  /// No description provided for @fitnessTestReportStatus.
  ///
  /// In en, this message translates to:
  /// **'Report Status'**
  String get fitnessTestReportStatus;

  /// No description provided for @fitnessTestStudentYear.
  ///
  /// In en, this message translates to:
  /// **'Year Level'**
  String get fitnessTestStudentYear;

  /// No description provided for @fitnessTestBmi.
  ///
  /// In en, this message translates to:
  /// **'Height/Weight'**
  String get fitnessTestBmi;

  /// No description provided for @fitnessTestVitalCapacity.
  ///
  /// In en, this message translates to:
  /// **'Vital Capacity'**
  String get fitnessTestVitalCapacity;

  /// No description provided for @fitnessTestStandingLongJump.
  ///
  /// In en, this message translates to:
  /// **'Standing Long Jump'**
  String get fitnessTestStandingLongJump;

  /// No description provided for @fitnessTestSitAndReach.
  ///
  /// In en, this message translates to:
  /// **'Sit and Reach'**
  String get fitnessTestSitAndReach;

  /// No description provided for @fitnessTestPullUp.
  ///
  /// In en, this message translates to:
  /// **'Pull-ups'**
  String get fitnessTestPullUp;

  /// No description provided for @fitnessTestSitUp.
  ///
  /// In en, this message translates to:
  /// **'Sit-ups'**
  String get fitnessTestSitUp;

  /// No description provided for @fitnessTestFiftyMeters.
  ///
  /// In en, this message translates to:
  /// **'50m Sprint'**
  String get fitnessTestFiftyMeters;

  /// No description provided for @fitnessTestRun.
  ///
  /// In en, this message translates to:
  /// **'800/1000m Run'**
  String get fitnessTestRun;

  /// No description provided for @fitnessTestReadCount.
  ///
  /// In en, this message translates to:
  /// **'reads'**
  String get fitnessTestReadCount;

  /// No description provided for @fitnessTestSticky.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get fitnessTestSticky;

  /// No description provided for @fitnessTestNoticeDetail.
  ///
  /// In en, this message translates to:
  /// **'Notice Detail'**
  String get fitnessTestNoticeDetail;

  /// No description provided for @dockLabelFitnessTest.
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get dockLabelFitnessTest;
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
