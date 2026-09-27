import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/utils/platform_utils.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openLink(String link) async {
  await launchUrl(
    Uri.parse(link),
    mode: isOhos ? LaunchMode.externalApplication : LaunchMode.platformDefault,
  );
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
