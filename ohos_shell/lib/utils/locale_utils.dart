import 'dart:ui';

Locale? parseLocale(String? lang) {
  if (lang == null) {
    return null;
  }

  Locale? locale;

  var splitLang = lang.split("-");
  if (splitLang.length == 1) {
    locale = Locale(lang);
  } else if (splitLang.length == 2) {
    locale = Locale.fromSubtags(
      languageCode: splitLang[0],
      scriptCode: splitLang[1],
    );
  } else if (splitLang.length == 3) {
    locale = Locale.fromSubtags(
      languageCode: splitLang[0],
      scriptCode: splitLang[1],
      countryCode: splitLang[2],
    );
  }

  return locale;
}
