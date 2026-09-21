import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/student_type.dart';
import 'package:bugaoshan/pages/graduate/schedule_import_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

import 'import_schedule_page.dart';

/// 日志标签，与 [AppLog] 的 tag 约定一致。
const String _tag = 'ScheduleImportSheet';

/// 「课表导入」来源选择底部弹窗，课表页与课表管理页共用。
///
/// 按全局学生身份过滤入口：分享粘贴（应用自有导出格式，与身份无关）恒展示；
/// 本科生模式展示教务处两个入口（数据粘贴 / 在线拉取），
/// 研究生模式展示研究生课表导入（ehall 直连，页面内部自带 WebView 兜底）。
Future<void> showScheduleImportSheet(
  BuildContext context, {
  required CourseProvider courseProvider,
}) {
  final l10n = AppLocalizations.of(context)!;
  final outerContext = context;
  final appConfig = getIt<AppConfigProvider>();
  return showModalBottomSheet(
    context: context,
    // 入口总高度可能超过默认的 9/16 屏高上限（横屏/矮屏/分屏下会裁掉最后几项），
    // 因此放开高度限制并让内容可滚动，保证入口都能触达。
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppShapes.extraLarge),
      ),
    ),
    builder: (context) => SafeArea(
      child: ValueListenableBuilder<StudentType>(
        valueListenable: appConfig.studentType,
        builder: (context, studentType, _) {
          final isUndergraduate = studentType == StudentType.undergraduate;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Text(
                      l10n.importSchedule,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    leading: const Icon(Icons.share),
                    title: Text(l10n.importFromShare),
                    onTap: () {
                      Navigator.pop(context);
                      popupOrNavigate(
                        outerContext,
                        ImportSchedulePage(
                          courseProvider: courseProvider,
                          mode: ImportMode.share,
                        ),
                      );
                    },
                  ),
                  if (isUndergraduate) ...[
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      leading: const Icon(Icons.school),
                      title: Text(l10n.importFromJwxt),
                      onTap: () {
                        Navigator.pop(context);
                        popupOrNavigate(
                          outerContext,
                          ImportSchedulePage(
                            courseProvider: courseProvider,
                            mode: ImportMode.jwxt,
                          ),
                        );
                      },
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      leading: const Icon(Icons.cloud_download_outlined),
                      title: Text(l10n.importFromJwxtOnline),
                      onTap: () {
                        Navigator.pop(context);
                        popupOrNavigate(
                          outerContext,
                          ImportSchedulePage(
                            courseProvider: courseProvider,
                            mode: ImportMode.online,
                          ),
                        );
                      },
                    ),
                  ] else ...[
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      // 教务处在线入口已用 cloud_download，这里换一个教育相关的图标区分
                      leading: const Icon(Icons.cast_for_education),
                      title: Text(l10n.importFromGraduate),
                      onTap: () {
                        if (kIsWeb) {
                          // Web 端 ehall 不放行跨域凭据请求（见 schedule_import_page.dart），
                          // 这条入口只会落到「请用原生客户端」说明页。暂不隐藏入口，先用日志留痕。
                          AppLog.w(
                            _tag,
                            'Web 端点击「研究生课表导入」：受 ehall CORS 限制，入口不可用',
                          );
                        }
                        Navigator.pop(context);
                        popupOrNavigate(
                          outerContext,
                          const GraduateScheduleImportPage(),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
