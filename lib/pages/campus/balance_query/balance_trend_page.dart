import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/utils/beijing_time.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/providers/balance_query_provider.dart';
import 'package:bugaoshan/pages/campus/balance_query/widgets/balance_trend_chart_card.dart';
import 'package:bugaoshan/pages/campus/balance_query/widgets/balance_trend_custom_range_card.dart';
import 'package:bugaoshan/pages/campus/balance_query/widgets/balance_trend_range_selector.dart';
import 'package:bugaoshan/pages/campus/balance_query/widgets/balance_trend_raw_records_card.dart';
import 'package:bugaoshan/pages/campus/balance_query/widgets/balance_trend_stats_card.dart';
import 'package:bugaoshan/pages/campus/balance_query/widgets/balance_trend_time_range.dart';

/// 电费余额趋势页。
///
/// 分层设计:
/// - 第一层 [BalanceTrendRangeSelector]:4 个预设 tab(全部/30天/90天/自定义),
///   仅负责切换 mode,不弹任何 picker
/// - 第二层 [BalanceTrendCustomRangeCard]:仅当 mode==custom 时显示,
///   包含独立的"开始日期"/"结束日期"两个按钮,用户每次只改一个端点
///
/// 趋势数据与加载状态由 [BalanceQueryProvider] 管理；本页面只保留范围选择。
class BalanceTrendPage extends StatefulWidget {
  final BalanceQueryProvider provider;
  final int balanceType;
  final String title;
  final Color themeColor;

  const BalanceTrendPage({
    super.key,
    required this.provider,
    required this.balanceType,
    required this.title,
    required this.themeColor,
  });

  @override
  State<BalanceTrendPage> createState() => _BalanceTrendPageState();
}

class _BalanceTrendPageState extends State<BalanceTrendPage> {
  BalanceTrendTimeRange _range = BalanceTrendTimeRange.days7;

  /// 自定义模式的起止日期(本地日期,仅日期部分有效)。
  /// 懒初始化:首次切到 custom 时设为"倒数 7 天 ~ 今天"。
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// 确保自定义起止日期已初始化(默认倒数 7 天 ~ 北京今日)。
  /// 端点仅日期分量有意义,按北京日历日解释,不依赖设备时区。
  void _ensureCustomDatesInitialized() {
    if (_customStart == null || _customEnd == null) {
      final b = DateTime.now().toUtc().add(kBeijingUtcOffset);
      final today = DateTime(b.year, b.month, b.day);
      _customStart = today.subtract(const Duration(days: 7));
      _customEnd = today;
    }
  }

  ({DateTime? since, DateTime? until}) _queryRange() {
    final now = DateTime.now().toUtc();
    // 预设范围按 UTC 日界归一化，避免每次 build 产生不同 key 而错过
    // Provider 的同范围缓存；自定义范围已由 localDatesToUtc 归一化。
    final todayUtc = DateTime.utc(now.year, now.month, now.day);
    return switch (_range) {
      BalanceTrendTimeRange.days7 => (
        since: todayUtc.subtract(const Duration(days: 7)),
        until: null,
      ),
      BalanceTrendTimeRange.days30 => (
        since: todayUtc.subtract(const Duration(days: 30)),
        until: null,
      ),
      BalanceTrendTimeRange.days90 => (
        since: todayUtc.subtract(const Duration(days: 90)),
        until: null,
      ),
      BalanceTrendTimeRange.custom => localDatesToUtc(
        start: _customStart!,
        end: _customEnd!,
      ),
    };
  }

  Future<void> _loadHistory({bool force = false}) async {
    final range = _queryRange();
    try {
      await widget.provider.ensureTrend(
        balanceType: widget.balanceType,
        since: range.since,
        until: range.until,
        force: force,
      );
    } catch (_) {
      // 错误保留在 Provider 的趋势状态中。
    }
  }

  void _onRangeChanged(BalanceTrendTimeRange v) {
    if (v == _range) return;
    if (v == BalanceTrendTimeRange.custom) {
      _ensureCustomDatesInitialized();
    }
    setState(() => _range = v);
    _loadHistory();
  }

  void _onCustomStartChanged(DateTime v) {
    // 起始日期不能晚于结束日期,若用户选了更晚的日期则自动对调
    if (_customEnd != null && v.isAfter(_customEnd!)) {
      setState(() {
        final tmp = _customEnd!;
        _customEnd = v;
        _customStart = tmp;
      });
    } else {
      setState(() => _customStart = v);
    }
    _loadHistory();
  }

  void _onCustomEndChanged(DateTime v) {
    if (_customStart != null && v.isBefore(_customStart!)) {
      setState(() {
        final tmp = _customStart!;
        _customStart = v;
        _customEnd = tmp;
      });
    } else {
      setState(() => _customEnd = v);
    }
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListenableBuilder(
        listenable: widget.provider,
        builder: (context, _) {
          final range = _queryRange();
          final state = widget.provider.trendStateFor(
            balanceType: widget.balanceType,
            since: range.since,
            until: range.until,
          );
          if (state.error != null && !state.hasValue) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  state.error.toString(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => _loadHistory(force: true),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 第一层:4 个预设 tab
                BalanceTrendRangeSelector(
                  range: _range,
                  onChanged: _onRangeChanged,
                ),

                // 第二层:自定义日期范围卡片(仅 custom 模式显示)
                AnimatedSize(
                  duration: appConfigService.cardSizeAnimationDuration.value,
                  curve: AppCurves.quick,
                  child: _range == BalanceTrendTimeRange.custom
                      ? BalanceTrendCustomRangeCard(
                          key: const ValueKey('customRange'),
                          start: _customStart!,
                          end: _customEnd!,
                          onStartChanged: _onCustomStartChanged,
                          onEndChanged: _onCustomEndChanged,
                        )
                      : const SizedBox.shrink(key: ValueKey('emptyRange')),
                ),

                const SizedBox(height: 12),
                BalanceTrendStatsCard(
                  trend: state.trend,
                  isLoading: state.isLoading,
                  themeColor: widget.themeColor,
                ),
                const SizedBox(height: 12),
                BalanceTrendChartCard(
                  trend: state.trend,
                  isLoading: state.isLoading,
                  themeColor: widget.themeColor,
                ),
                const SizedBox(height: 12),
                BalanceTrendRawRecordsCard(records: state.records),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
