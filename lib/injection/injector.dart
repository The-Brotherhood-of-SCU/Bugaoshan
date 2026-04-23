import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:bugaoshan/pages/campus/train_program/train_program_provider.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/grades_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/serivces/database_service.dart';
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
  getIt.registerSingletonAsync<AppConfigProvider>(() async {
    await getIt.isReady<SharedPreferences>();
    final prefs = getIt<SharedPreferences>();
    return AppConfigProvider(prefs);
  });
  getIt.registerSingletonAsync<PackageInfo>(() => PackageInfo.fromPlatform());
  getIt.registerSingletonAsync<AppInfoProvider>(() async {
    await getIt.isReady<PackageInfo>();
    final packageInfo = getIt<PackageInfo>();
    return AppInfoProvider(packageInfo);
  });
  getIt.registerSingletonAsync<DatabaseService>(() async {
    final db = DatabaseService();
    await db.init();
    return db;
  });
  getIt.registerSingletonAsync<CourseProvider>(() async {
    await getIt.isReady<DatabaseService>();
    final db = getIt<DatabaseService>();
    return CourseProvider(db);
  });
  getIt.registerSingletonAsync<ScuAuthProvider>(() async {
    await getIt.isReady<SharedPreferences>();
    final prefs = getIt<SharedPreferences>();
    final provider = ScuAuthProvider(prefs);
    await provider.init();
    return provider;
  });
  getIt.registerSingletonAsync<CcylProvider>(() async {
    await getIt.isReady<SharedPreferences>();
    final prefs = getIt<SharedPreferences>();
    return CcylProvider(prefs);
  });
  getIt.registerSingletonAsync<GradesProvider>(() async {
    await getIt.isReady<SharedPreferences>();
    await getIt.isReady<ScuAuthProvider>();
    final prefs = getIt<SharedPreferences>();
    final auth = getIt<ScuAuthProvider>();
    return GradesProvider(prefs, auth);
  });
  getIt.registerSingletonAsync<TrainProgramProvider>(() async {
    await getIt.isReady<ScuAuthProvider>();
    final auth = getIt<ScuAuthProvider>();
    return TrainProgramProvider(auth);
  });
}

Future<void> ensureBasicDependencies() async {
  await getIt.isReady<CourseProvider>();
  await getIt.isReady<ScuAuthProvider>();
  await getIt.isReady<CcylProvider>();
  await getIt.isReady<GradesProvider>();
  await getIt.isReady<TrainProgramProvider>();
}
