import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rubbish_plan/providers/version.dart';
import 'package:rubbish_plan/serivces/app_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'injector.config.dart';

final getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'init', // default
  preferRelativeImports: true, // default
  asExtension: true, // default
)
void configureDependencies() {
  getIt.init();
  _configureAsyncDependencies();
}

void _configureAsyncDependencies() {
  getIt.registerSingletonAsync<SharedPreferences>(
    () => SharedPreferences.getInstance(),
  );
  getIt.registerSingletonAsync<AppConfigService>(() async {
    await getIt.isReady<SharedPreferences>();
    final prefs = getIt<SharedPreferences>();
    return AppConfigService(prefs);
  });
  getIt.registerSingletonAsync<PackageInfo>(() => PackageInfo.fromPlatform());
  getIt.registerSingletonAsync<VersionProvider>(() async {
    await getIt.isReady<PackageInfo>();
    final packageInfo = getIt<PackageInfo>();
    return VersionProvider(packageInfo);
  });
}

Future<void> ensureBasicDependencies() async {
  await getIt.isReady<AppConfigService>();
}
