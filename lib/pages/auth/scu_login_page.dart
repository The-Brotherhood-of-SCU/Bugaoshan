import 'dart:convert';
import 'dart:typed_data';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/auth/scu_login_button.dart';
import 'package:bugaoshan/pages/auth/scu_login_captcha_row.dart';
import 'package:bugaoshan/pages/auth/scu_login_checkbox.dart';
import 'package:bugaoshan/pages/auth/scu_login_disclaimer.dart';
import 'package:bugaoshan/pages/auth/scu_login_header_image.dart';
import 'package:bugaoshan/pages/auth/scu_login_input_field.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart' show CaptchaResult;
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/ocr_service.dart';
import 'package:bugaoshan/widgets/common/third_center.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:flutter/material.dart';

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
  Uint8List? _captchaImageBytes;
  bool _loading = false;
  bool _captchaLoading = false;
  String? _errorMsg;
  bool _obscurePassword = true;
  bool _rememberPassword = true;
  bool _autoLogin = true;

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
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final authProvider = getIt<ScuAuthProvider>();
    final credentials = await authProvider.getSavedCredentials();
    final autoLoginEnabled = await authProvider.isAutoLoginEnabled();
    if (!mounted) return;
    if (credentials != null) {
      setState(() {
        _rememberPassword = true;
        _usernameCtrl.text = credentials['username']!;
        _passwordCtrl.text = credentials['password']!;
        _autoLogin = autoLoginEnabled;
      });
    } else {
      setState(() => _autoLogin = autoLoginEnabled);
    }
  }

  Future<void> _loadCaptcha() async {
    setState(() => _captchaLoading = true);
    try {
      final captcha = await getIt<ScuAuthProvider>().fetchCaptcha();

      // 提前解码，避免在 build 中解码失败导致整页崩溃
      Uint8List? imageBytes;
      try {
        imageBytes = _decodeBase64Image(captcha.captchaBase64);
      } catch (e) {
        debugPrint('Captcha decode error: $e');
      }

      String? recognizedText;
      if (imageBytes != null) {
        try {
          recognizedText = await OcrService.performOcr(imageBytes);
        } catch (e) {
          debugPrint('OCR error: $e');
        }
      }

      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;

      setState(() {
        _captcha = captcha;
        _captchaImageBytes = imageBytes;
        // 重载成功后清除上一次「验证码加载失败」的提示
        if (_errorMsg == l10n.captchaLoadFailed) _errorMsg = null;
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
        await authProvider.setAutoLogin(_autoLogin);
      } else {
        await authProvider.clearCredentials();
        await authProvider.setAutoLogin(false);
      }

      if (!logicRootContext.mounted) return;
      Navigator.of(logicRootContext).pop(true);
    } on ScuLoginException catch (e) {
      debugPrint('Login failed: ${e.message}');
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
    switch (e.message) {
      case 'invalid_captcha':
        return l10n.invalidCaptcha;
      case String msg when msg.startsWith('login_failed_will_lock'):
        // 预期格式: login_failed_will_lock_<已尝试>_<上限>，格式不符时回退通用文案
        final parts = msg.split('_');
        final attempted = parts.length > 5 ? int.tryParse(parts[4]) : null;
        final total = parts.length > 5 ? int.tryParse(parts[5]) : null;
        if (attempted != null && total != null && total > attempted) {
          return l10n.loginFailedWillLock(total - attempted);
        }
        return l10n.loginFailed;
      default:
        debugPrint('Unlocalized login error message: ${e.message}');
        return l10n.loginFailed;
    }
  }

  Color get _brandColor => Theme.of(context).brightness == Brightness.light
      ? const Color(0xFFE65646)
      : const Color(0xFF8965BD);

  Color get _cardBgColor => Theme.of(context).brightness == Brightness.light
      ? const Color.fromARGB(255, 255, 245, 239)
      : const Color(0xFF24272C);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final body = SafeArea(
      minimum: const EdgeInsets.symmetric(horizontal: 16),
      child: ThirdCenter(
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                ScuLoginHeaderImage(isDark: isDark),
                _buildForm(l10n, isDark),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scuUnifiedAuth)),
      body: body,
    );
  }

  Widget _buildForm(AppLocalizations l10n, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: BoxDecoration(
        // 顶部直边与头部图片衔接，仅保留底部圆角
        color: _cardBgColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScuLoginInputField(
              controller: _usernameCtrl,
              label: l10n.studentId,
              hint: l10n.studentIdHint,
              prefixIcon: Icons.person_outline,
              keyboardType: TextInputType.number,
              isDark: isDark,
              brandColor: _brandColor,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.studentIdRequired
                  : null,
            ),
            const SizedBox(height: 16),
            ScuLoginInputField(
              controller: _passwordCtrl,
              label: l10n.password,
              hint: l10n.passwordHint,
              prefixIcon: Icons.lock_outline,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              isDark: isDark,
              brandColor: _brandColor,
              validator: (v) =>
                  (v == null || v.isEmpty) ? l10n.passwordRequired : null,
            ),
            const SizedBox(height: 16),
            ScuLoginCaptchaRow(
              controller: _captchaCtrl,
              l10n: l10n,
              isDark: isDark,
              brandColor: _brandColor,
              captchaImageBytes: _captchaImageBytes,
              captchaLoading: _captchaLoading,
              onRefresh: _loadCaptcha,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                ScuLoginCheckbox(
                  value: _rememberPassword,
                  label: l10n.rememberPassword,
                  isDark: isDark,
                  brandColor: _brandColor,
                  onChanged: (v) => setState(() {
                    _rememberPassword = v ?? false;
                    if (!_rememberPassword) _autoLogin = false;
                  }),
                ),
                ScuLoginCheckbox(
                  value: _autoLogin,
                  label: l10n.autoLogin,
                  isDark: isDark,
                  brandColor: _brandColor,
                  onChanged: (v) => setState(() => _autoLogin = v ?? false),
                ),
              ],
            ),
            if (_errorMsg != null) ...[
              const SizedBox(height: 16),
              _buildErrorMessage(_errorMsg!, isDark),
            ],
            const SizedBox(height: 20),
            ScuLoginButton(
              loading: _loading,
              onPressed: _submit,
              brandColor: _brandColor,
              label: l10n.loginButton,
            ),
            const SizedBox(height: 16),
            ScuLoginDisclaimer(l10n: l10n, isDark: isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage(String message, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _brandColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _brandColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: _brandColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: _brandColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Uint8List _decodeBase64Image(String b64) {
    final comma = b64.indexOf(',');
    final raw = comma >= 0 ? b64.substring(comma + 1) : b64;
    return base64.decode(raw);
  }
}
