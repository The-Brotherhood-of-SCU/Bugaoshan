import 'package:bugaoshan/utils/auth_logger.dart';

/// Include the cause as well as the original stack in startup failure reports.
/// The report is shown in the UI and may be shared as a screenshot.
String formatOhosStartupError(Object error, StackTrace stackTrace) {
  return AuthLogRedactor.apply(
    '${error.runtimeType}: ${_safeText(error)}\n\n${_safeText(stackTrace)}',
  );
}

String _safeText(Object value) {
  try {
    return value.toString();
  } catch (_) {
    // Reporting must not replace the original failure with a formatting error.
    return '<${value.runtimeType}: text unavailable>';
  }
}
