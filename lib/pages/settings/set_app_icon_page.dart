import 'package:bugaoshan/services/dynamic_icon_service.dart';
import 'package:flutter/material.dart';

class SetAppIconPage extends StatefulWidget {
  const SetAppIconPage({super.key});

  @override
  State<SetAppIconPage> createState() => _SetAppIconPageState();
}

class _SetAppIconPageState extends State<SetAppIconPage> {
  List<String> _availableIcons = [];
  String? _currentIcon;
  bool _isLoading = true;
  bool _isChanging = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final icons = await DynamicIconService.getAvailableIcons();
      final current = await DynamicIconService.getCurrentIconName();
      setState(() {
        _availableIcons = icons;
        _currentIcon = current;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmAndSwitch(String? iconName, String iconLabel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('切换应用图标'),
        content: Text('切换至「$iconLabel」后应用将重启，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isChanging = true);
    try {
      await DynamicIconService.setAlternateIconName(iconName);
      final current = await DynamicIconService.getCurrentIconName();
      if (mounted) {
        setState(() => _currentIcon = current);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(iconName == null ? '已恢复默认图标' : '已切换到图标: $iconName'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('切换失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isChanging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('应用图标')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // 默认图标
                _IconOption(
                  iconAsset: 'assets/icon.png',
                  label: '默认图标',
                  subtitle: 'Bugaoshan 新图标',
                  isSelected: _currentIcon == null,
                  onTap: _currentIcon == null
                      ? null
                      : () => _confirmAndSwitch(null, '默认图标'),
                  isLoading: _isChanging,
                ),
                const SizedBox(height: 12),
                // 旧版图标
                if (_availableIcons.contains('old'))
                  _IconOption(
                    iconAsset: 'assets/icon_old.png',
                    label: '旧版图标',
                    subtitle: 'Bugaoshan 经典图标',
                    isSelected: _currentIcon == 'old',
                    onTap: _currentIcon == 'old'
                        ? null
                        : () => _confirmAndSwitch('old', '旧版图标'),
                    isLoading: _isChanging,
                  ),
                if (_availableIcons.isEmpty && !_isLoading)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        '当前平台不支持动态切换应用图标',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _IconOption extends StatelessWidget {
  final String iconAsset;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isLoading;

  const _IconOption({
    required this.iconAsset,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    this.onTap,
    required this.isLoading,
  });

  Widget _buildIconPreview(BuildContext context) {
    final theme = Theme.of(context);
    final size = 64.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        iconAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.broken_image,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isLoading ? 0.5 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 图标预览
                _buildIconPreview(context),
                const SizedBox(width: 16),
                // 文字说明
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // 选中标记
                if (isSelected)
                  Icon(Icons.check_circle, color: theme.colorScheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
