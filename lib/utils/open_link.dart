import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/utils/platform_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bugaoshan/utils/app_log.dart';

const String _tag = 'OpenLink';

Future<void> openLink(String link) async {
  await AppLog.guard(_tag, '打开链接', () => openUri(Uri.parse(link)));
}

Future<bool> openUri(Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) {
  return AppLog.guard(_tag, '启动外部应用', () async {
    final effectiveMode = isOhos && mode == LaunchMode.platformDefault
        ? LaunchMode.externalApplication
        : mode;
    final opened = await launchUrl(uri, mode: effectiveMode);
    if (!opened) {
      AppLog.e(_tag, '没有可打开该链接的应用 url=$uri');
    }
    return opened;
  });
}

Future<void> openProjectRepository() async {
  await openLink(appLink);
}

Future<void> openOfficialWebsite() async {
  await openLink(officialWebsiteLink);
}

Future<void> openUserManual() async {
  await openLink(userManualLink);
}

Future<void> openDeveloperTeam() async {
  await openLink(orgLink);
}

Future<void> openLicense() async {
  await openLink("$appLink/blob/main/LICENSE");
}
