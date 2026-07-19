import 'package:bugaoshan/utils/app_shapes.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/models/balance_record.dart';
import 'package:bugaoshan/providers/balance_query_provider.dart';
import 'package:bugaoshan/pages/campus/balance_query/widgets/balance_trend_chart_card.dart';
import 'package:bugaoshan/pages/campus/balance_query/widgets/balance_trend_custom_range_card.dart';
import 'package:bugaoshan/pages/campus/balance_query/widgets/balance_trend_range_selector.dart';
import 'package:bugaoshan/pages/campus/balance_query/widgets/balance_trend_raw_records_card.dart';
import 'package:bugaoshan/pages/campus/balance_query/widgets/balance_trend_stats_card.dart';
import 'package:bugaoshan/pages/campus/balance_query/widgets/balance_trend_time_range.dart';
import 'package:bugaoshan/services/balance/balance_trend_calculator.dart';

/// 电费余额趋势页。
///
/// 分层设计:
/// - 第一层 [BalanceTrendRangeSelector]:4 个预设 tab(全部/30天/90天/自定义),
///   仅负责切换 mode,不弹任何 picker
/// - 第二层 [BalanceTrendCustomRangeCard]:仅当 mode==custom 时显示,
///   包含独立的"开始日期"/"结束日期"两个按钮,用户每次只改一个端点
///
/// 数据加载、状态管理由本文件负责;UI 细节拆分到 `widgets/` 下。
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

  List<BalanceRecord> _records = const [];
  TrendResult _trend = const TrendResult.empty();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// 确保自定义起止日期已初始化(默认倒数 7 天 ~ 今天)。
  void _ensureCustomDatesInitialized() {
    if (_customStart == null || _customEnd == null) {
      final now = DateTime.now();
      _customStart = now.subtract(const Duration(days: 7));
      _customEnd = now;
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      DateTime? since;
      DateTime? until;
      switch (_range) {
        case BalanceTrendTimeRange.days7:
          since = DateTime.now().toUtc().subtract(const Duration(days: 7));
          until = null;
        case BalanceTrendTimeRange.days30:
          since = DateTime.now().toUtc().subtract(const Duration(days: 30));
          until = null;
        case BalanceTrendTimeRange.days90:
          since = DateTime.now().toUtc().subtract(const Duration(days: 90));
          until = null;
        case BalanceTrendTimeRange.custom:
          _ensureCustomDatesInitialized();
          final utc = localDatesToUtc(start: _customStart!, end: _customEnd!);
          since = utc.since;
          until = utc.until;
      }
      final records = await widget.provider.getBalanceHistory(
        balanceType: widget.balanceType,
        since: since,
        until: until,
      );
      if (!mounted) return;
      setState(() {
        _records = records;
        _trend = BalanceTrendCalculator.calculate(records);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadHistory,
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
                    curve: AppCurves.standard,
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
                    trend: _trend,
                    isLoading: _isLoading,
                    themeColor: widget.themeColor,
                  ),
                  const SizedBox(height: 12),
                  BalanceTrendChartCard(
                    trend: _trend,
                    isLoading: _isLoading,
                    themeColor: widget.themeColor,
                  ),
                  const SizedBox(height: 12),
                  BalanceTrendRawRecordsCard(records: _records),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
