import 'dart:convert';
import 'dart:typed_data';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/scu_auth_service.dart';
import 'package:bugaoshan/services/ocr_service.dart';

class ScuLoginPage extends StatefulWidget {
  const ScuLoginPage({super.key});

  @override
  State<ScuLoginPage> createState() => _ScuLoginPageState();
}

class _ScuLoginPageState extends State<ScuLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _captchaCtrl = TextEditingController();

  CaptchaResult? _captcha;
  bool _loading = false;
  bool _captchaLoading = false;
  String? _errorMsg;
  bool _obscurePassword = true;
  bool _rememberPassword = true;

  @override
  void initState() {
    super.initState();
    OcrService.init().catchError((e) {
      debugPrint('OCR Init error: $e');
    });
    _loadSaved();
    _loadCaptcha();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _captchaCtrl.dispose();
    OcrService.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final credentials = await getIt<ScuAuthProvider>().getSavedCredentials();
    if (credentials == null) return;
    if (!mounted) return;
    setState(() {
      _rememberPassword = true;
      _usernameCtrl.text = credentials['username']!;
      _passwordCtrl.text = credentials['password']!;
    });
  }

  Future<void> _loadCaptcha() async {
    setState(() => _captchaLoading = true);
    try {
      final captcha = await getIt<ScuAuthProvider>().service.fetchCaptcha();
      String? recognizedText;
      try {
        final comma = captcha.captchaBase64.indexOf(',');
        final raw = comma >= 0
            ? captcha.captchaBase64.substring(comma + 1)
            : captcha.captchaBase64;
        final imageBytes = base64.decode(raw);
        recognizedText = await OcrService.performOcr(imageBytes);
      } catch (e) {
        debugPrint('OCR error: $e');
      }

      if (!mounted) return;

      setState(() {
        _captcha = captcha;
        if (recognizedText != null && recognizedText.isNotEmpty) {
          _captchaCtrl.text = recognizedText;
        } else {
          _captchaCtrl.clear();
        }
      });
    } catch (e) {
      debugPrint('Captcha load error: $e');
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() => _errorMsg = l10n.captchaLoadFailed);
    } finally {
      if (mounted) {
        setState(() => _captchaLoading = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_captcha == null) {
      final l10n = AppLocalizations.of(context)!;
      setState(() => _errorMsg = l10n.captchaNotLoaded);
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    try {
      final authProvider = getIt<ScuAuthProvider>();
      await authProvider.login(
        username: username,
        password: password,
        captchaCode: _captcha!.code,
        captchaText: _captchaCtrl.text.trim(),
      );

      if (_rememberPassword) {
        await authProvider.saveCredentials(username, password);
      } else {
        await authProvider.clearCredentials();
      }

      if (!logicRootContext.mounted) return;
      Navigator.of(logicRootContext).pop(true);
    } on ScuLoginException catch (e) {
      debugPrint(
        'Login failed: ${e.message} (sessionExpired=${e.sessionExpired})',
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() => _errorMsg = _localizeLoginError(e, l10n));
      _loadCaptcha();
    } catch (e) {
      debugPrint('Login network error: $e');
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() => _errorMsg = l10n.networkError);
      _loadCaptcha();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _localizeLoginError(ScuLoginException e, AppLocalizations l10n) {
    if (e.sessionExpired) return l10n.sessionExpiredMessage;
    switch (e.message) {
      case 'invalid_captcha':
        return l10n.invalidCaptcha;
      case String msg when msg.startsWith('login_failed_will_lock'):
        final parts = msg.split('_');
        final attempted = int.tryParse(parts[4]);
        final total = int.tryParse(parts[5]);
        if (attempted != null && total != null && total > attempted) {
          return l10n.loginFailedWillLock(total - attempted);
        }
        return l10n.loginFailed;
      default:
        debugPrint('Unlocalized login error message: ${e.message}');
        return l10n.loginFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final formContent = [
      const SizedBox(height: 8),
      Container(
        width: 88,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset('assets/scu.jpg', fit: BoxFit.cover),
        ),
      ),
      const SizedBox(height: 2),
      Text(
        l10n.scuUnifiedAuth,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)
            .copyWith(fontSize: 24),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 2),
      TextFormField(
        controller: _usernameCtrl,
        decoration: InputDecoration(
          labelText: l10n.studentId,
          prefixIcon: const Icon(Icons.person_outline),
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? l10n.studentIdRequired : null,
      ),
      TextFormField(
        controller: _passwordCtrl,
        decoration: InputDecoration(
          labelText: l10n.password,
          prefixIcon: const Icon(Icons.lock_outline),
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        obscureText: _obscurePassword,
        validator: (v) =>
            (v == null || v.isEmpty) ? l10n.passwordRequired : null,
      ),
      _CaptchaRow(
        captcha: _captcha,
        loading: _captchaLoading,
        controller: _captchaCtrl,
        onRefresh: _loadCaptcha,
      ),
      Row(
        children: [
          Checkbox(
            value: _rememberPassword,
            onChanged: (v) => setState(() => _rememberPassword = v ?? false),
          ),
          Text(l10n.rememberPassword),
        ],
      ),
      if (_errorMsg != null)
        Text(
          _errorMsg!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
          textAlign: TextAlign.center,
        ),
      FilledButton(
        onPressed: _loading ? null : _submit,
        child: _loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(l10n.loginButton),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DisclaimerRow('· ${l10n.scuLoginDisclaimerPwd}'),
          _DisclaimerRow('· ${l10n.scuLoginDisclaimerOcr}'),
          _DisclaimerRow('· ${l10n.scuLoginDisclaimerPrivacy}'),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.scuUnifiedAuth)),
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 16,
                        children: formContent,
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerRow extends StatelessWidget {
  final String text;
  const _DisclaimerRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _CaptchaRow extends StatelessWidget {
  final CaptchaResult? captcha;
  final bool loading;
  final TextEditingController controller;
  final VoidCallback onRefresh;

  const _CaptchaRow({
    required this.captcha,
    required this.loading,
    required this.controller,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: l10n.captcha,
              prefixIcon: const Icon(Icons.security),
              border: const OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? l10n.captchaRequired : null,
          ),
        ),
        GestureDetector(
          onTap: onRefresh,
          child: Container(
            width: 110,
            height: 56,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : captcha != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Image.memory(
                      _decodeBase64Image(captcha!.captchaBase64),
                      fit: BoxFit.contain,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ),
      ],
    );
  }

  Uint8List _decodeBase64Image(String b64) {
    final comma = b64.indexOf(',');
    final raw = comma >= 0 ? b64.substring(comma + 1) : b64;
    return base64.decode(raw);
  }
}
