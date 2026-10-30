import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/riverpod/campus/ccyl_pods.dart';
import 'package:bugaoshan/services/auth/ccyl_oauth_service.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';

class CcylBindPage extends ConsumerStatefulWidget {
  const CcylBindPage({super.key});

  @override
  ConsumerState<CcylBindPage> createState() => _CcylBindPageState();
}

class _CcylBindPageState extends ConsumerState<CcylBindPage> {
  static const String _tag = 'CcylBindPageState';

  late final CcylOAuthService _oauthService;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _oauthService = CcylOAuthService(ref.read(scuAuthBridge));
  }

  Future<void> _doOAuthBind() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final l10n = AppLocalizations.of(context)!;
    try {
      final code = await _oauthService.getOAuthCode();
      if (code == null) {
        if (mounted) {
          setState(() {
            _error = l10n.getAuthCodeFailed;
          });
        }
        return;
      }

      await ref.read(ccylAuthNotifierProvider.notifier).loginWithOAuthCode(code);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e, logStackTrace) {
      AppLog.e(_tag, '_doOAuthBind 失败', error: e, stackTrace: logStackTrace);

      if (mounted) {
        setState(() {
          _error = LoadErrorType.ccylBindFailed;
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
                  _error is LoadErrorType
                      ? (_error as LoadErrorType).message(l10n)
                      : _error as String,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
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
}
