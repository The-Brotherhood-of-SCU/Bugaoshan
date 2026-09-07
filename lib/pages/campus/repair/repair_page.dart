import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/repair.dart';
import 'package:bugaoshan/pages/campus/repair/repair_detail_page.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/providers/zhhq_repair_provider.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';

part 'repair_submit_tab.dart';
part 'repair_widgets.dart';

/// 智慧后勤在线报修页。
///
/// 对接 zhhq（智慧后勤）平台的报修服务：选择地址/维修项目、填写故障描述、
/// 上传现场照片、预约时间后提交工单，并可查看我的报修列表。
///
/// 认证通过 [ZhhqAuth]（走 SCU 统一身份认证 SSO 换取 zhhq tokenKey），
/// 与 passpoint/办事大厅同为原生 HTTP 实现。
///
/// 结构：本文件仅含主页面（Tab 容器 + 登录/加载/错误门）；表单与列表等
/// 子 widget 拆到 `repair_submit_tab.dart` / `repair_widgets.dart`。
class RepairPage extends StatefulWidget {
  const RepairPage({super.key});

  @override
  State<RepairPage> createState() => _RepairPageState();
}

class _RepairPageState extends State<RepairPage> {
  /// 用于让 AppBar 刷新按钮直接调用工单列表的统一刷新（force 拉取 + 滚回顶端）。
  final _myTicketsKey = GlobalKey<_MyTicketsTabState>();

  @override
  Widget build(BuildContext context) {
    final auth = getIt<ScuAuthProvider>();
    final provider = getIt<ZhhqRepairProvider>();

    return ListenableBuilder(
      listenable: Listenable.merge([auth, provider]),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.repairTitle),
              bottom: TabBar(
                tabs: [
                  Tab(text: l10n.repairTabSubmit),
                  Tab(text: l10n.repairTabMyTickets),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  // 手动刷新：地址与工单列表都刷新。
                  // 列表走统一 _refresh()（force 拉取 + 滚回顶端）。
                  onPressed: provider.state == RepairLoadState.loading
                      ? null
                      : () {
                          provider.refresh();
                          _myTicketsKey.currentState?._refresh();
                        },
                  tooltip: l10n.refresh,
                ),
              ],
            ),
            body: _buildBody(l10n, auth, provider),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    AppLocalizations l10n,
    ScuAuthProvider auth,
    ZhhqRepairProvider provider,
  ) {
    if (!auth.isLoggedIn) {
      return auth.isAutoLoggingIn
          ? const AutoLoginLoadingWidget()
          : const LoginRequiredWidget();
    }

    final hasData = provider.addresses.isNotEmpty;
    if (provider.state == RepairLoadState.idle ||
        (provider.state == RepairLoadState.loading && !hasData)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.state == RepairLoadState.error && !hasData) {
      return RetryableErrorWidget(
        errorType: provider.error ?? LoadErrorType.networkError,
        onRetry: () {
          // 认证失败时重新走认证；否则直接刷新地址
          if (auth.isLoggedIn && !provider.isReadyForRequest) {
            provider.retryAuth();
          } else {
            provider.refresh();
          }
        },
      );
    }

    // 异步加载工单列表（不阻塞地址展示；myList 服务端慢，独立处理）
    unawaited(provider.loadTickets());

    return TabBarView(
      children: [
        _SubmitTab(provider: provider),
        _MyTicketsTab(key: _myTicketsKey, provider: provider),
      ],
    );
  }
}