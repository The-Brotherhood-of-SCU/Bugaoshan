import 'dart:convert';
import 'dart:typed_data';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart' show CaptchaResult;
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/ocr_service.dart';

class ScuLoginPage extends StatefulWidget {
  const ScuLoginPage({super.key});

  @override
  State<ScuLoginPage> createState() => _ScuLoginPageState();
}

class _ScuLoginPageState extends State<ScuLoginPage> {
  static const double _headerHeight = 260;
  static const double _cornerRadius = 24;
  // 卡片平坦区覆盖背景图直边的像素量
  static const double _flatOverlap = 50;

  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _captchaCtrl = TextEditingController();

  CaptchaResult? _captcha;
  bool _loading = false;
  bool _captchaLoading = false;
  bool _headerReady = false;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_headerReady) {
      _preloadHeaderImage();
    }
  }

  Future<void> _preloadHeaderImage() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await precacheImage(
      AssetImage(
        isDark ? 'assets/scu_header_dark.png' : 'assets/scu_header_light.png',
      ),
      context,
    );
    if (mounted) setState(() => _headerReady = true);
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

  Color get _brandColor => Theme.of(context).brightness == Brightness.light
      ? const Color(0xFFE65646)
      : const Color(0xFF8965BD);

  Color get _cardBgColor => Theme.of(context).brightness == Brightness.light
      ? const Color(0xFFFFFAF7)
      : const Color(0xFF24272C);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.scuUnifiedAuth)),
      body: _headerReady
          ? SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: Center(
                      child: Container(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                          maxWidth: 440,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              children: [
                                _buildHeaderImage(isDark),
                                Padding(
                                  padding: EdgeInsets.only(
                                    top:
                                        _headerHeight -
                                        2 * _cornerRadius -
                                        _flatOverlap,
                                    left: 20,
                                    right: 20,
                                  ),
                                  child: Column(
                                    children: [
                                      _buildFormCard(l10n, isDark),
                                      const SizedBox(height: 32),
                                      _buildDisclaimer(l10n, isDark),
                                      const SizedBox(height: 40),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildHeaderImage(bool isDark) {
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        isDark ? 'assets/scu_header_dark.png' : 'assets/scu_header_light.png',
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
      ),
    );
  }

  Widget _buildFormCard(AppLocalizations l10n, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInputField(
              controller: _usernameCtrl,
              label: l10n.studentId,
              hint: l10n.studentIdHint,
              prefixIcon: Icons.person_outline,
              keyboardType: TextInputType.number,
              isDark: isDark,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.studentIdRequired
                  : null,
            ),
            const SizedBox(height: 16),
            _buildInputField(
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
              validator: (v) =>
                  (v == null || v.isEmpty) ? l10n.passwordRequired : null,
            ),
            const SizedBox(height: 16),
            _buildCaptchaRow(l10n, isDark),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildCheckbox(
                  value: _rememberPassword,
                  label: l10n.rememberPassword,
                  isDark: isDark,
                  onChanged: (v) => setState(() {
                    _rememberPassword = v ?? false;
                    if (!_rememberPassword) _autoLogin = false;
                  }),
                ),
                const SizedBox(width: 24),
                _buildCheckbox(
                  value: _autoLogin,
                  label: l10n.autoLogin,
                  isDark: isDark,
                  onChanged: (v) => setState(() => _autoLogin = v ?? false),
                ),
              ],
            ),
            if (_errorMsg != null) ...[
              const SizedBox(height: 16),
              _buildErrorMessage(_errorMsg!, isDark),
            ],
            const SizedBox(height: 20),
            _buildLoginButton(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    required bool isDark,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.white24 : Colors.grey.shade400,
              fontSize: 14,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.only(left: 4),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _brandColor.withValues(alpha: 0.15),
              ),
              child: Icon(prefixIcon, color: _brandColor, size: 18),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark ? const Color(0xFF2D2F36) : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : Colors.grey.shade300,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : Colors.grey.shade300,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _brandColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.error,
                width: 1,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptchaRow(AppLocalizations l10n, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.captcha,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _captchaCtrl,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.captchaRequired
                    : null,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: l10n.captchaHint,
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white24 : Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  prefixIcon: Container(
                    margin: const EdgeInsets.only(left: 4),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _brandColor.withValues(alpha: 0.15),
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      color: _brandColor,
                      size: 18,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF2C2C2C)
                      : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white12 : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white12 : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _brandColor, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                      width: 1,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _loadCaptcha,
              child: Container(
                width: 120,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _captchaLoading
                    ? Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _brandColor,
                          ),
                        ),
                      )
                    : _captcha != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          _decodeBase64Image(_captcha!.captchaBase64),
                          fit: BoxFit.contain,
                        ),
                      )
                    : Icon(
                        Icons.refresh_outlined,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                        size: 22,
                      ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _loadCaptcha,
              child: Container(
                width: 44,
                height: 52,
                decoration: BoxDecoration(
                  color: _brandColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.refresh_outlined,
                  color: _brandColor,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required String label,
    required bool isDark,
    required ValueChanged<bool?> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? _brandColor : Colors.transparent,
              border: Border.all(
                color: value
                    ? _brandColor
                    : (isDark ? Colors.white38 : Colors.grey.shade400),
                width: 1.5,
              ),
            ),
            child: value
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
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

  Widget _buildLoginButton(AppLocalizations l10n) {
    return FilledButton(
      onPressed: _loading ? null : _submit,
      style:
          FilledButton.styleFrom(
            backgroundColor: _brandColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            elevation: 2,
            shadowColor: _brandColor.withValues(alpha: 0.3),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return Colors.white.withValues(alpha: 0.2);
              }
              if (states.contains(WidgetState.hovered)) {
                return Colors.white.withValues(alpha: 0.1);
              }
              return null;
            }),
          ),
      child: _loading
          ? SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Text(l10n.loginButton),
    );
  }

  Widget _buildDisclaimer(AppLocalizations l10n, bool isDark) {
    final style = TextStyle(
      fontSize: 12,
      color: isDark ? Colors.white38 : Colors.grey.shade500,
      height: 1.4,
    );
    final bulletStyle = TextStyle(
      fontSize: 12,
      color: isDark ? Colors.white24 : Colors.grey.shade400,
      height: 1.4,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('· ', style: bulletStyle),
            Flexible(child: Text(l10n.scuLoginDisclaimerPwd, style: style)),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('· ', style: bulletStyle),
            Flexible(child: Text(l10n.scuLoginDisclaimerOcr, style: style)),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('· ', style: bulletStyle),
            Flexible(child: Text(l10n.scuLoginDisclaimerPrivacy, style: style)),
          ],
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
