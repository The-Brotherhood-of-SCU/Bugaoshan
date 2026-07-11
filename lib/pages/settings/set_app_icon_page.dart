import 'package:bugaoshan/l10n/app_localizations.dart';
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
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.switchAppIcon),
        content: Text(l.switchAppIconConfirm(iconLabel)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.confirm),
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
        final l = AppLocalizations.of(context)!;
        setState(() => _currentIcon = current);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              iconName == null
                  ? l.defaultIconRestored
                  : l.iconSwitched(iconName),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.iconSwitchFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isChanging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.appIcon)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                _IconOption(
                  iconAsset: 'assets/icon.png',
                  label: l.defaultIcon,
                  subtitle: l.newIconSubtitle,
                  isSelected: _currentIcon == null,
                  onTap: _currentIcon == null
                      ? null
                      : () => _confirmAndSwitch(null, l.defaultIcon),
                  isLoading: _isChanging,
                ),
                const SizedBox(height: 12),
                if (_availableIcons.contains('old'))
                  _IconOption(
                    iconAsset: 'assets/icon_old.png',
                    label: l.oldIcon,
                    subtitle: l.oldIconSubtitle,
                    isSelected: _currentIcon == 'old',
                    onTap: _currentIcon == 'old'
                        ? null
                        : () => _confirmAndSwitch('old', l.oldIcon),
                    isLoading: _isChanging,
                  ),
                if (_availableIcons.isEmpty && !_isLoading)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        l.iconSwitchNotSupported,
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
