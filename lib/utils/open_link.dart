import 'package:bugaoshan/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openLink(String link) async {
  await launchUrl(Uri.parse(link));
}

Future<void> openProjectRepository() async {
  await openLink(appLink);
}

Future<void> openDeveloperTeam() async {
  await openLink(orgLink);
}
