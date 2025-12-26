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

  /// No description provided for @rubbishPlan.
  ///
  /// In en, this message translates to:
  /// **'Rubbish Plan'**
  String get rubbishPlan;

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

  /// No description provided for @globalSetting.
  ///
  /// In en, this message translates to:
  /// **'Global Setting'**
  String get globalSetting;
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
