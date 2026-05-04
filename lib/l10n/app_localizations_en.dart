// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get bugaoshan => 'Bugaoshan';

  @override
  String get selfLanguage => 'English';

  @override
  String get wizardWelcomeTitle => 'Welcome to Bugaoshan';

  @override
  String get wizardWelcomeDesc =>
      'Your campus assistant: schedules, grades and campus services in one place';

  @override
  String get wizardLoginTitle => 'Login & Import Schedule';

  @override
  String get wizardLoginStep1 => 'Log in with SCU Unified Identity';

  @override
  String get wizardLoginStep2 => 'Import schedule from academic system';

  @override
  String get wizardLoginDone => 'Logged in';

  @override
  String get wizardLoginButton => 'Go to Login';

  @override
  String get wizardImportButton => 'Import Schedule';

  @override
  String get wizardImportHint => 'Auto-fetch schedule after login';

  @override
  String get wizardFeatureTitle => 'Explore More Features';

  @override
  String get wizardFeatureCourse => 'Course Schedule';

  @override
  String get wizardFeatureCourseDesc =>
      'View weekly classes, manage multiple schedules, import from academic system, share and export as calendar files';

  @override
  String get wizardFeatureCampus => 'Campus Services';

  @override
  String get wizardFeatureCampusDesc =>
      'Check classroom availability and grades, join CCYL activities, query utility balance, manage network devices';

  @override
  String get wizardFeatureProfile => 'Profile';

  @override
  String get wizardFeatureProfileDesc =>
      'Log in with SCU Unified Identity, bind CCYL account, customize theme colors, dark mode and language preferences';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get Started';

  @override
  String get course => 'Course';

  @override
  String get profile => 'Profile';

  @override
  String get campus => 'Campus';

  @override
  String get classroomQuery => 'Classroom Query';

  @override
  String get classroomQueryDesc =>
      'Check classroom availability and borrowing status';

  @override
  String get utilitiesSection => 'Utilities';

  @override
  String get academicSection => 'Academic';

  @override
  String get moreFeaturesTitle => 'More Features';

  @override
  String get moreFeaturesDesc => 'Create an Issue to request more features';

  @override
  String get selectCampus => 'Select Campus';

  @override
  String get selectBuilding => 'Select Building';

  @override
  String get allBuildings => 'All Buildings';

  @override
  String get seats => 'seats';

  @override
  String get free => 'Free';

  @override
  String get inClass => 'In Class';

  @override
  String get borrowed => 'Borrowed';

  @override
  String get classroomPeriodExam => 'Exam';

  @override
  String get classroomPeriodExperiment => 'Experiment';

  @override
  String classroomTeachingWeek(int week) {
    return 'Week $week';
  }

  @override
  String classroomQueryDate(String date) {
    return 'Query Date: $date';
  }

  @override
  String get classroomCanBorrow => 'Borrowable';

  @override
  String get classroomCannotBorrow => 'Not Borrowable';

  @override
  String get classroomRemark => 'Remark';

  @override
  String get period => 'Period';

  @override
  String get loading => 'Loading...';

  @override
  String get loadFailed => 'Load Failed';

  @override
  String get retry => 'Retry';

  @override
  String get campusNetworkRequired =>
      'This feature is only available on campus network. Please connect to campus Wi-Fi or use the school VPN.';

  @override
  String get campusNetworkRequiredAtNight =>
      'Access is restricted to campus network during 0:00-6:00. Please connect to campus Wi-Fi or use the school VPN.';

  @override
  String get appOnly => 'Available on App only';

  @override
  String get softwareSetting => 'Software Setting';

  @override
  String get followSystem => 'Follow System';

  @override
  String get modifyLanguage => 'Modify Language';

  @override
  String get current => 'Current';

  @override
  String get animationDuration => 'Duration';

  @override
  String get confirm => 'Confirm';

  @override
  String get today => 'Today';

  @override
  String currentAnimationDuration(Object value) {
    return 'Current Animation Duration: $value ms';
  }

  @override
  String animationDurationUpdated(Object value) {
    return 'Animation Duration updated to $value ms';
  }

  @override
  String get animationDurationHint =>
      'Hint: Adjust the slider to preview the animation, click Confirm to save the settings';

  @override
  String get themeColor => 'Theme Color';

  @override
  String get changeThemeColor => 'Change Theme Color';

  @override
  String get confirmButton => 'Confirm';

  @override
  String get customizedColorHint =>
      'Customized color is generated by color seed';

  @override
  String get tips => 'Tips';

  @override
  String get resetToDefault => 'Reset to Default';

  @override
  String get blockPicker => 'Block';

  @override
  String get materialPicker => 'Material';

  @override
  String get advancedPicker => 'Advanced';

  @override
  String get about => 'About';

  @override
  String get developmentTeam => 'Dev Team';

  @override
  String get projectInfo => 'Project Info';

  @override
  String get appName => 'App Name';

  @override
  String get version => 'Version';

  @override
  String get gitTag => 'Git Tag';

  @override
  String get appDescription => 'Explore everything, all on the Bugaoshan';

  @override
  String get contactUs => 'Contact Us';

  @override
  String developedBy(Object team) {
    return 'Developed by $team';
  }

  @override
  String get externalResources => 'External Resources';

  @override
  String get projectRepository => 'Repository';

  @override
  String get checkForUpdates => 'Check Updates';

  @override
  String get newVersionAvailable => 'New Version Available';

  @override
  String get noUpdateAvailable => 'Already on Latest Version';

  @override
  String get goToReleases => 'Go to Releases';

  @override
  String get startUpdate => 'Start Update';

  @override
  String get startUpdatePreview => 'Update to Preview';

  @override
  String get updateToLatest => 'Update to Latest';

  @override
  String get updateToStable => 'Update to Latest Stable';

  @override
  String get updateToPreview => 'Update to Latest (Include Preview)';

  @override
  String get downloading => 'Downloading';

  @override
  String get updateFailed => 'Update failed';

  @override
  String get preReleaseWarning =>
      'This is a pre-release version. Use with caution.';

  @override
  String get releaseNotes => 'Release Notes';

  @override
  String get neverMind => 'Never Mind';

  @override
  String get clearAllData => 'Clear All Data';

  @override
  String get confirmMessage => 'Are you sure?';

  @override
  String get environmentInfo => 'Environment Info';

  @override
  String get testPage => 'Test Page';

  @override
  String get forceUpdate => 'Update to Latest (Include Preview)';

  @override
  String get scheduleSetting => 'Schedule Setting';

  @override
  String get scheduleManagement => 'Schedule Management';

  @override
  String get globalSetting => 'Global Setting';

  @override
  String get addCourse => 'Add Course';

  @override
  String get editCourse => 'Edit Course';

  @override
  String get deleteCourse => 'Delete Course';

  @override
  String get deleteCourseConfirm =>
      'Are you sure you want to delete this course?';

  @override
  String get courseName => 'Course Name';

  @override
  String get teacher => 'Teacher';

  @override
  String get location => 'Location';

  @override
  String get courseColor => 'Course Color';

  @override
  String get week => 'Week';

  @override
  String get startWeek => 'Start Week';

  @override
  String get endWeek => 'End Week';

  @override
  String get dayOfWeek => 'Day of Week';

  @override
  String get startSection => 'Start Section';

  @override
  String get endSection => 'End Section';

  @override
  String get monday => 'Mon';

  @override
  String get tuesday => 'Tue';

  @override
  String get wednesday => 'Wed';

  @override
  String get thursday => 'Thu';

  @override
  String get friday => 'Fri';

  @override
  String get saturday => 'Sat';

  @override
  String get sunday => 'Sun';

  @override
  String currentWeek(Object week) {
    return 'Week $week';
  }

  @override
  String get thisWeek => 'This week';

  @override
  String weekRange(int start, int end) {
    return 'Week $start - $end';
  }

  @override
  String get weekType => 'Week Type';

  @override
  String get everyWeek => 'Every Week';

  @override
  String get oddWeek => 'Odd Week';

  @override
  String get evenWeek => 'Even Week';

  @override
  String get section => 'Sec';

  @override
  String get sectionCount => 'Sections per Day';

  @override
  String get timeSlot => 'Time Slot';

  @override
  String get startTime => 'Start Time';

  @override
  String get endTime => 'End Time';

  @override
  String get semesterConfig => 'Semester Config';

  @override
  String get semesterName => 'Semester Name';

  @override
  String get semesterStartDate => 'Semester Start Date';

  @override
  String get setCurrentWeek => 'Set Current Week';

  @override
  String get setCurrentWeekHint =>
      'Automatically calculates the semester start date based on the current week';

  @override
  String get autoFetchCurrentWeek => 'Auto Fetch Current Week';

  @override
  String get autoFetchCurrentWeekHint =>
      'Fetch current teaching week from academic system';

  @override
  String get fetchingCurrentWeek => 'Fetching...';

  @override
  String get loginRequired =>
      'Please complete SCU Unified Identity login in the Profile page first';

  @override
  String get goToLogin => 'Go to Login';

  @override
  String get semesterEndDate => 'Semester End Date';

  @override
  String get displaySetting => 'Display Setting';

  @override
  String get courseCardSection => 'Course Card';

  @override
  String get courseGridSection => 'Course Grid';

  @override
  String get otherSection => 'Other';

  @override
  String get colorOpacity => 'Color Opacity';

  @override
  String get fontSize => 'Font Size';

  @override
  String get showCourseGrid => 'Show Course Grid';

  @override
  String get courseRowHeight => 'Course Row Height';

  @override
  String get backgroundImage => 'Background Image';

  @override
  String get setBackgroundImage => 'Set Background Image';

  @override
  String get removeBackgroundImage => 'Remove Background Image';

  @override
  String get backgroundImageOpacity => 'Background Image Opacity';

  @override
  String get showTeacher => 'Show Teacher';

  @override
  String get showLocation => 'Show Location';

  @override
  String get showWeekend => 'Show Weekend';

  @override
  String get showNonCurrentWeekCourses => 'Show Non-Current Week Courses';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get delete => 'Delete';

  @override
  String get customColor => 'Custom Color';

  @override
  String get noCourseThisWeek => 'No courses this week';

  @override
  String get timeConflict => 'Time Conflict';

  @override
  String get timeConflictMessage =>
      'The selected time slot conflicts with an existing course.';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get invalidWeekRange =>
      'End week must be greater than or equal to start week';

  @override
  String get duplicateScheduleName => 'Schedule name already exists';

  @override
  String get importSchedule => 'Import Schedule';

  @override
  String get importFromShare => 'Import from Share';

  @override
  String get importFromJwxt => 'Import from Education System';

  @override
  String get importDataHint => 'Paste JSON data here...';

  @override
  String get importSuccess => 'Schedule imported successfully';

  @override
  String get importFailed => 'Import failed';

  @override
  String get importedScheduleDefaultName => 'Imported Schedule';

  @override
  String importNameConflictHint(Object name) {
    return 'Name \"$name\" already exists, please rename:';
  }

  @override
  String get importNameSuffix => '(Import)';

  @override
  String get defaultScheduleName => 'Default Schedule';

  @override
  String deleteScheduleConfirm(Object name) {
    return 'Are you sure you want to delete schedule \"$name\"?';
  }

  @override
  String get exportSchedule => 'Export Schedule';

  @override
  String get exportScheduleAsCopy => 'Copy to Clipboard';

  @override
  String get exportScheduleAsIcs => 'Export to Calendar File';

  @override
  String get exportScheduleAsCopySuccess => 'Schedule data copied to clipboard';

  @override
  String get exportScheduleAsCopyFailed =>
      'Copy failed, maybe you can try later';

  @override
  String get exportScheduleAsIcsTo => 'Save Calendar File to...';

  @override
  String get exportScheduleAsIcsSuccess => 'File saved successfully';

  @override
  String get exportScheduleAsIcsFailed => 'File save failed';

  @override
  String get exportScheduleAsIcsCanceled => 'File save canceled';

  @override
  String get icsTeacherLabel => 'Teacher(s)';

  @override
  String get exportScheduleAddToCalendar => 'Import to Calendar';

  @override
  String get exportScheduleAddToCalendarSuccess => 'Imported to calendar';

  @override
  String get exportScheduleAddToCalendarFailed => 'Import failed';

  @override
  String get copySuffix => ' (Copy)';

  @override
  String get notThisWeek => '[Not]';

  @override
  String actualCurrentWeek(Object week) {
    return 'Week $week';
  }

  @override
  String totalWeeksSubtitle(Object count) {
    return '$count weeks';
  }

  @override
  String get invalidSectionRange =>
      'End section must be greater than start section';

  @override
  String get crossPeriodError => 'Cross Period Error';

  @override
  String get crossPeriodErrorMessage =>
      'A course cannot span across morning, afternoon, or evening periods.';

  @override
  String totalWeeks(Object value) {
    return 'Total Weeks: $value';
  }

  @override
  String get morning => 'Morning';

  @override
  String get afternoon => 'Afternoon';

  @override
  String get evening => 'Evening';

  @override
  String get courseDuration => 'Course Duration (mins)';

  @override
  String get breakDuration => 'Break Duration (mins)';

  @override
  String get autoSyncTime => 'Auto-calculate subsequent times';

  @override
  String get scuLogin => 'SCU Unified Identity Login';

  @override
  String get loggedIn => 'Logged In';

  @override
  String get notLoggedIn => 'Not Logged In';

  @override
  String get loginSessionExpired => 'Login Session Expired';

  @override
  String get loginSessionExpiredDesc =>
      'Your login session has expired after 1 hour. Please login again.';

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirm => 'Are you sure you want to logout?';

  @override
  String get importFromJwxtOnline => 'Online Import from JWXT';

  @override
  String get importFromJwxtOnlineHint =>
      'Automatically fetch schedule. Please login with SCU Unified Identity in the Profile page first.';

  @override
  String get selectSemester => 'Select Semester';

  @override
  String get importAll => 'Import All';

  @override
  String importingProgress(int current, int total) {
    return 'Importing $current/$total...';
  }

  @override
  String get scuUnifiedAuth => 'Unified Identity Authentication';

  @override
  String get studentId => 'Student ID';

  @override
  String get studentIdRequired => 'Please enter your student ID';

  @override
  String get password => 'Password';

  @override
  String get passwordRequired => 'Please enter your password';

  @override
  String get captcha => 'Captcha';

  @override
  String get captchaRequired => 'Please enter the captcha';

  @override
  String get rememberPassword => 'Remember Password';

  @override
  String get autoLogin => 'Auto Login';

  @override
  String get autoLoggingIn => 'Logging in...';

  @override
  String get loginButton => 'Login';

  @override
  String get captchaLoadFailed => 'Failed to load captcha';

  @override
  String get captchaNotLoaded => 'Please load the captcha first';

  @override
  String get networkError => 'Network error';

  @override
  String get gradesStats => 'Grade Statistics';

  @override
  String get gradesStatsDesc => 'View and analyze your academic performance';

  @override
  String get gradesStatsComingSoon => 'Coming soon';

  @override
  String get schemeScores => 'Scheme Scores';

  @override
  String get passingScores => 'Passing Scores';

  @override
  String get gradesLoginRequired =>
      'Please complete SCU Unified Identity login in the Profile page first';

  @override
  String get gradesNoData => 'No grade data';

  @override
  String get gradesLoadFailed => 'Failed to load grades';

  @override
  String get gradesRefreshFailed => 'Refresh failed, showing cached data';

  @override
  String get gradesNoPassingData => 'No passing grade data';

  @override
  String get gradesGet => 'Fetch Grades';

  @override
  String get gradesRetry => 'Retry';

  @override
  String get gpa => 'GPA';

  @override
  String get overallGpa => 'Overall GPA';

  @override
  String get earnedCredits => 'Earned Cr.';

  @override
  String get passedCount => 'Passed';

  @override
  String get failedCount => 'Failed';

  @override
  String get avgScore => 'Avg Score';

  @override
  String get requiredAvgScore => 'Required Avg';

  @override
  String get requiredCredits => 'Required Cr.';

  @override
  String get electiveCredits => 'Elective Cr.';

  @override
  String get optionalCredits => 'Optional Cr.';

  @override
  String get requiredGpa => 'Required GPA';

  @override
  String get totalPassedCount => 'Passed';

  @override
  String get termCount => 'Terms';

  @override
  String get accumulatedCredits => 'Total Credits';

  @override
  String creditUnit(Object credit) {
    return '$credit cr.';
  }

  @override
  String termPassedSummary(Object count, Object credits) {
    return '$count courses · $credits cr.';
  }

  @override
  String get sessionExpiredTitle => 'Session Expired';

  @override
  String get sessionExpiredMessage =>
      'Your login session has expired. Please login again to continue using this feature.';

  @override
  String get sessionExpired => 'Session expired';

  @override
  String get relogin => 'Login Again';

  @override
  String get trainProgram => 'Training Program';

  @override
  String get trainProgramDesc =>
      'Search training programs by college and grade';

  @override
  String get trainProgramCollege => 'College';

  @override
  String get trainProgramGrade => 'Grade';

  @override
  String get trainProgramAll => 'All';

  @override
  String get trainProgramSearch => 'Search';

  @override
  String get trainProgramNoData => 'No training program data';

  @override
  String get trainProgramLoading => 'Loading...';

  @override
  String get trainProgramLoadFailed => 'Load failed';

  @override
  String get trainProgramName => 'Program Name';

  @override
  String get trainProgramMajor => 'Major';

  @override
  String get trainProgramEducationSystem => 'Education System';

  @override
  String get trainProgramDegreeType => 'Degree Type';

  @override
  String get trainProgramDetail => 'Training Program Detail';

  @override
  String get trainProgramCredits => 'Total Credits';

  @override
  String get trainProgramHours => 'Total Hours';

  @override
  String get trainProgramCourses => 'Courses';

  @override
  String get trainProgramObjective => 'Training Objective';

  @override
  String get trainProgramCourseStructure => 'Course Structure';

  @override
  String get trainProgramCourseNumber => 'Course Number';

  @override
  String get trainProgramOpenCollege => 'Offering College';

  @override
  String get trainProgramCourseType => 'Course Type';

  @override
  String get trainProgramExamType => 'Exam Type';

  @override
  String get trainProgramTeachingMethod => 'Teaching Method';

  @override
  String get trainProgramCourseHoursDetail => 'Course Hours Detail';

  @override
  String get trainProgramWeekHours => 'Weekly Hours';

  @override
  String get trainProgramActualHours => 'Practice Hours';

  @override
  String get trainProgramOpenCourse => 'Open Course';

  @override
  String get trainProgramCourseArrangement => 'Course Arrangement';

  @override
  String get trainProgramPlanName => 'Plan Name';

  @override
  String get trainProgramCourseAttribute => 'Course Attribute';

  @override
  String get trainProgramAcademicYear => 'Academic Year';

  @override
  String get trainProgramSemester => 'Semester';

  @override
  String get trainProgramExperimentHours => 'Experiment Hours';

  @override
  String get trainProgramLoginRequired =>
      'Please complete SCU Unified Identity login in the Profile page first';

  @override
  String get planCompletion => 'Plan Completion';

  @override
  String get planCompletionDesc =>
      'View progress of each training program module';

  @override
  String get planCompletionNoData => 'No plan completion data';

  @override
  String get planCompletionTotalEarned => 'Earned Credits';

  @override
  String get planCompletionCompleted => 'Completed';

  @override
  String get planCompletionCredits => 'Credits';

  @override
  String get planCompletionCreditsUnit => 'cr';

  @override
  String get planCompletionCourses => 'Courses';

  @override
  String get planCompletionRateLimited =>
      'Too many requests, please try again later';

  @override
  String get ccylTitle => 'Second Classroom';

  @override
  String get ccylDesc => 'Browse activities, participate, make reservations';

  @override
  String get ccylSearchActivities => 'Activity Search';

  @override
  String get ccylMyActivities => 'My Activities';

  @override
  String get ccylOrderedActivities => 'Reserved';

  @override
  String get ccylMyCredits => 'Credit List';

  @override
  String get ccylSelect => 'Select';

  @override
  String get ccylSelectAll => 'Select All';

  @override
  String get ccylExportEmail => 'Export to Email';

  @override
  String get ccylEmailAddress => 'QQ Email';

  @override
  String get ccylEmailHint => 'Enter QQ email to receive the report';

  @override
  String get ccylExportSuccess => 'Report sent to email';

  @override
  String get ccylSearchHint => 'Search activity name';

  @override
  String get ccylHours => 'Hours';

  @override
  String get ccylAvailable => 'Available';

  @override
  String get ccylInProgress => 'In Progress';

  @override
  String get ccylCompleted => 'Completed';

  @override
  String get ccylSubscribed => 'Subscribed';

  @override
  String get ccylSubscribe => 'Subscribe';

  @override
  String get ccylCancelSubscribe => 'Cancel Subscribe';

  @override
  String get ccylSubscribeSuccess => 'Subscribed successfully';

  @override
  String get ccylCancelSuccess => 'Subscription cancelled successfully';

  @override
  String get ccylActionFailed => 'Action failed';

  @override
  String get ccylSignUp => 'Sign Up';

  @override
  String get ccylCancelSignUp => 'Cancel Sign Up';

  @override
  String get ccylSelectScoreType => 'Select ability type to improve';

  @override
  String get ccylSignUpSuccess => 'Signed up successfully';

  @override
  String get ccylNoScoreType => 'No ability types available';

  @override
  String get ccylCurrentValue => 'Current value';

  @override
  String get ccylLoginRequired =>
      'Please complete SCU Unified Identity login in the Profile page first';

  @override
  String get ccylBindRequired =>
      'Please bind your Second Classroom account first';

  @override
  String get ccylBindTitle => 'Bind Second Classroom';

  @override
  String get ccylBindDesc =>
      'Bind your Second Classroom account to view activities';

  @override
  String get ccylOpenOAuth => 'Open OAuth Authorization';

  @override
  String get ccylDoBind => 'Bind Second Classroom';

  @override
  String get ccylBindHelp => 'Click button to bind automatically';

  @override
  String get ccylActivitySeries => 'Activity Series';

  @override
  String get ccylActivityDetail => 'Activity Detail';

  @override
  String get ccylActivityInfo => 'Activity Info';

  @override
  String get ccylTimeInfo => 'Time Info';

  @override
  String get ccylLocationInfo => 'Location Info';

  @override
  String get ccylContactInfo => 'Contact Info';

  @override
  String get ccylStarLevel => 'Star Level';

  @override
  String get ccylQuality => 'Quality';

  @override
  String get ccylScoreType => 'Score Type';

  @override
  String get ccylLiablePerson => 'Liable Person';

  @override
  String get ccylLiablePhone => 'Contact Phone';

  @override
  String get ccylLiableTeacher => 'Liable Teacher';

  @override
  String get ccylActivities => 'Activities';

  @override
  String get ccylQuota => 'Quota';

  @override
  String get ccylActivityTarget => 'Activity Target';

  @override
  String get ccylActivityTime => 'Activity Time';

  @override
  String get ccylEnrollTime => 'Enrollment Time';

  @override
  String get ccylActivityAddress => 'Activity Address';

  @override
  String get ccylContactPhone => 'Contact Phone';

  @override
  String get ccylSignIn => 'Sign In';

  @override
  String get ccylSignOut => 'Sign Out';

  @override
  String get ccylEnabled => 'Enabled';

  @override
  String get ccylDisabled => 'Disabled';

  @override
  String get ccylSeriesName => 'Series Name';

  @override
  String get ccylOrganizer => 'Organizer';

  @override
  String get noData => 'No Data';

  @override
  String get networkDeviceQuery => 'Network Device Query';

  @override
  String get networkDeviceQueryDesc =>
      'Query campus network account and online devices';

  @override
  String get networkDeviceUserInfo => 'User Information';

  @override
  String get networkDeviceOnlineDevices => 'Online Devices';

  @override
  String get networkDeviceDeviceId => 'Device ID';

  @override
  String get networkDeviceIp => 'IP Address';

  @override
  String get networkDeviceLogout => 'Logout';

  @override
  String get networkDeviceLogoutConfirm =>
      'Are you sure you want to logout all devices?';

  @override
  String get networkDeviceForceOffline => 'Force Offline';

  @override
  String get networkDeviceConfirmOffline =>
      'Are you sure you want to offline this device?';

  @override
  String get networkDeviceOfflineSuccess => 'Operation successful';

  @override
  String get networkDeviceAuthFailed => 'Authentication failed';

  @override
  String get networkDeviceOperationSuccess => 'Operation successful';

  @override
  String get loginFailed => 'Login failed';

  @override
  String get invalidCaptcha => 'Invalid captcha, please try again';

  @override
  String loginFailedWillLock(int count) {
    return 'Login failed, $count more attempt(s) will lock your account';
  }

  @override
  String get ccylBindFailed => 'Binding failed, please try again later';

  @override
  String get ccylActivityLoadFailed => 'Failed to load activity';

  @override
  String get networkOfflineFailed => 'Failed to offline device';

  @override
  String get balanceQuery => 'Balance Query';

  @override
  String get balanceQueryDesc => 'Query electricity and AC fee balance';

  @override
  String get electricityFee => 'Electricity';

  @override
  String get acFee => 'AC Fee';

  @override
  String get balance => 'Balance';

  @override
  String get unitKwh => 'kWh';

  @override
  String get bindRoom => 'Bind Room';

  @override
  String get bindNewRoom => 'Bind New Room';

  @override
  String get switchRoom => 'Switch Room';

  @override
  String get deleteRoom => 'Delete Room';

  @override
  String get selectUnit => 'Select Unit';

  @override
  String get inputInfo => 'Input Info';

  @override
  String get stepCampus => 'Cmp';

  @override
  String get stepBuilding => 'Bld';

  @override
  String get stepUnit => 'Unit';

  @override
  String get stepInfo => 'Info';

  @override
  String get inputBindingInfo => 'Input Binding Info';

  @override
  String get cusName => 'Name';

  @override
  String get cusNameHint => 'Enter name';

  @override
  String get roomNumber => 'Room Number';

  @override
  String get roomNumberHint => 'Enter room number, e.g. 301C';

  @override
  String get pricePerUnit => 'Price per unit';

  @override
  String get balanceQueryLoginRequired =>
      'Please complete SCU Unified Identity login in the Profile page first';

  @override
  String get balanceQueryNoBinding =>
      'You haven\'t bound any room yet, please bind first';

  @override
  String get scuLoginDisclaimerPwd =>
      'When \'Remember Password\' is enabled, your password is encrypted and stored locally using system-level encryption';

  @override
  String get scuLoginDisclaimerOcr =>
      'Captcha is recognized by a local OCR model';

  @override
  String get scuLoginDisclaimerPrivacy =>
      'We do not collect any personal information';

  @override
  String get openSourceLicenseDesc => 'This app is open-sourced under AGPL-3.0';

  @override
  String get academicCalendar => 'Academic Calendar';

  @override
  String get academicCalendarDesc =>
      'View SCU academic calendar and semester schedule';

  @override
  String get selectAcademicYear => 'Select Academic Year';

  @override
  String get userInfoLoading => 'Loading user info...';

  @override
  String get userInfoLoadFailed => 'Failed to load user info';

  @override
  String get userInfoRetry => 'Tap to retry';

  @override
  String get loginToViewUserInfo => 'Login to view user info';

  @override
  String get labelBookBorrowCount => 'Books Borrowed';

  @override
  String get labelCampusCardBalance => 'Card Balance';

  @override
  String get labelNetworkFeeBalance => 'Network Fee';

  @override
  String get customDock => 'Custom Dock';

  @override
  String get dockPreview => 'Dock Preview';

  @override
  String get resetDock => 'Reset to Default';

  @override
  String get dockResetConfirm => 'Reset dock bar to default configuration?';

  @override
  String get cannotDeleteProfile => 'Cannot be deleted';

  @override
  String get dockLabelCourse => 'Course';

  @override
  String get dockLabelCampus => 'Campus';

  @override
  String get dockLabelProfile => 'Profile';

  @override
  String get dockLabelGrades => 'Grades';

  @override
  String get dockLabelCcyl => 'CCYL';

  @override
  String get dockLabelPlanCompletion => 'Plan';

  @override
  String get dockLabelTrainProgram => 'Program';

  @override
  String get dockLabelClassroom => 'Classroom';

  @override
  String get dockLabelNetworkDevice => 'Network';

  @override
  String get dockLabelBalanceQuery => 'Balance';

  @override
  String get dockLabelAcademicCalendar => 'Calendar';
}
