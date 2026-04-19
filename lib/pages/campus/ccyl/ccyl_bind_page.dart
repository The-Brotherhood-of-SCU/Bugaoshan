import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/serivces/ccyl_oauth_service.dart';

class CcylBindPage extends StatefulWidget {
  const CcylBindPage({super.key});

  @override
  State<CcylBindPage> createState() => _CcylBindPageState();
}

class _CcylBindPageState extends State<CcylBindPage> {
  final _oauthService = CcylOAuthService();
  bool _loading = false;
  String? _error;

  Future<void> _doOAuthBind() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final code = await _oauthService.getOAuthCode();
      if (code == null) {
        if (mounted) {
          setState(() {
            _error = '获取授权码失败';
          });
        }
        return;
      }

      final provider = getIt<CcylProvider>();
      await provider.loginWithOAuthCode(code);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('CCYL bind error: $e');
      if (mounted) {
        setState(() {
          _error = 'ccylBindFailed';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ccylBindTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.ccylBindDesc,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _getErrorMessage(l10n, _error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ElevatedButton.icon(
              onPressed: _loading ? null : _doOAuthBind,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(l10n.ccylDoBind),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.ccylBindHelp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getErrorMessage(AppLocalizations l10n, String errorKey) {
    switch (errorKey) {
      case 'ccylBindFailed':
        return l10n.ccylBindFailed;
      default:
        return l10n.loadFailed;
    }
  }
}
