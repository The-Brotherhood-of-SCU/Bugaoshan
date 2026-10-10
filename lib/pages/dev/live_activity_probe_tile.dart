import 'package:flutter/material.dart';

import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/services/reminder/live_activity_service.dart';

/// 开发者选项中的课程实时活动（灵动岛）探针组件。
///
/// 用于在课表数据不可用、或当前不在上课时段时验证灵动岛与锁屏的渲染形态：
/// 直接经原生通道启动一条示例会话，跳过「当前必须有课」这一业务前提。
///
/// 与业务链路的分工：本探针不经过 [LiveActivityCoordinator]，验证范围是原生投递
/// 与系统渲染，不含课程判定与生命周期编排。
///
/// 并发说明：若调用时确实处于上课时段，协调器会在下一次前台恢复时按真实课程
/// 覆盖当前会话：它只比对自身记录的会话标识，不感知探针启动的会话。这是预期
/// 行为：探针用于单次界面验证，不与业务链路并行维护同一条会话。
class LiveActivityProbeTile extends StatefulWidget {
  const LiveActivityProbeTile({super.key, this.service});

  /// 注入用服务实例，缺省时使用默认通道实现。
  final LiveActivityService? service;

  @override
  State<LiveActivityProbeTile> createState() => _LiveActivityProbeTileState();
}

class _LiveActivityProbeTileState extends State<LiveActivityProbeTile> {
  /// 示例会话时长。取值较短，便于快速走完「启动 → 倒计时 → 自动结束」全流程，
  /// 同时留出切至主屏、长按灵动岛的操作时间。
  static const Duration _sampleDuration = Duration(minutes: 30);

  late final LiveActivityService _service =
      widget.service ?? LiveActivityService();

  bool _busy = false;
  bool? _supported;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshSupport();
  }

  Future<void> _refreshSupport() async {
    final supported = await _service.isSupported();
    if (mounted) setState(() => _supported = supported);
  }

  /// 将平台异常映射为可操作的提示文案。
  ///
  /// 三种前置条件不满足时（不支持、未授权、非前台）在系统层面均表现为「无任何反应」，
  /// 若直接把 PlatformException 原文交给使用者则无法定位原因，故逐一给出对应处置方式。
  String _describe(Object error, AppLocalizations l10n) {
    if (error is LiveActivityUnsupportedException) {
      return l10n.liveActivityProbeUnsupported;
    }
    if (error is LiveActivityNotAuthorizedException) {
      return l10n.liveActivityProbeNotAuthorized;
    }
    if (error is LiveActivityForegroundRequiredException) {
      return l10n.liveActivityProbeForegroundRequired;
    }
    return '${l10n.liveActivityProbeFailed}: $error';
  }

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.startSample(
        courseName: l10n.liveActivityProbeSampleCourse,
        location: l10n.liveActivityProbeSampleLocation,
        nextCourseName: l10n.liveActivityProbeSampleNext,
        duration: _sampleDuration,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.liveActivityProbeStarted)),
      );
    } catch (e) {
      setState(() => _error = _describe(e, l10n));
    } finally {
      await _refreshSupport();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _end() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await _service.end();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.liveActivityProbeEnded)),
      );
    } catch (e) {
      setState(() => _error = _describe(e, l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 构建系统实时活动可用性状态行。
  ///
  /// 保持 ListTile 默认 contentPadding，使左侧图标列与同级列表项对齐。
  Widget _buildStatusRow(AppLocalizations l10n, ThemeData theme) {
    final supported = _supported;
    final ok = supported == true;
    return ListTile(
      leading: Icon(
        ok ? Icons.sensors : Icons.sensors_off,
        color: ok ? theme.colorScheme.primary : theme.colorScheme.error,
      ),
      title: Text(l10n.liveActivityProbeStatusTitle),
      subtitle: Text(
        supported == null
            ? l10n.liveActivityProbeRunning
            : (ok
                  ? l10n.liveActivityProbeStatusSupported
                  : l10n.liveActivityProbeStatusUnsupported),
        style: theme.textTheme.bodySmall,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStatusRow(l10n, theme),
        const Divider(height: 24),
        ListTile(
          leading: const Icon(Icons.punch_clock_outlined),
          title: Text(l10n.liveActivityProbeTitle),
          subtitle: Text(
            l10n.liveActivityProbeSubtitle(_sampleDuration.inMinutes),
            style: theme.textTheme.bodySmall,
          ),
          trailing: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : FilledButton.tonal(
                  onPressed: _supported == false ? null : _start,
                  child: Text(l10n.liveActivityProbeAction),
                ),
        ),
        // 启动后即可回到主屏查看灵动岛；如需立即收尾，用这里的结束入口。
        if (_supported == true)
          ListTile(
            leading: const Icon(Icons.stop_circle_outlined),
            title: Text(l10n.liveActivityProbeEndAction),
            trailing: TextButton(
              onPressed: _busy ? null : _end,
              child: Text(l10n.liveActivityProbeEndNowAction),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
