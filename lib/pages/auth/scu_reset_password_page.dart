import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/auth/scu_login_button.dart';
import 'package:bugaoshan/pages/auth/scu_login_captcha_row.dart';
import 'package:bugaoshan/pages/auth/scu_login_input_field.dart';
import 'package:bugaoshan/services/api/forgot_password_service.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart' show CaptchaResult;
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:flutter/material.dart';

/// 统一身份认证「重置密码」页（忘记密码流程，无需登录态）。
///
/// 复刻官方三步流程：
/// 1. 确认账户：学/工号 + 图形验证码
/// 2. 安全验证：短信/邮件验证码二选一（联系方式脱敏展示）
/// 3. 重置密码：新密码 + 确认
///
/// 各步由服务端下发的 sToken / token 串联，见 [ForgotPasswordService]。
class ScuResetPasswordPage extends StatefulWidget {
  const ScuResetPasswordPage({super.key});

  @override
  State<ScuResetPasswordPage> createState() => _ScuResetPasswordPageState();
}

class _ScuResetPasswordPageState extends State<ScuResetPasswordPage> {
  final _accountService = getIt<ForgotPasswordService>();

  final _usernameCtrl = TextEditingController();
  final _captchaCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _pwd2Ctrl = TextEditingController();
  final _accountFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _pwdFormKey = GlobalKey<FormState>();

  /// 1 确认账户 / 2 安全验证 / 3 重置密码 / 4 完成
  int _step = 1;

  CaptchaResult? _captcha;
  Uint8List? _captchaImageBytes;
  bool _captchaLoading = false;
  bool _loading = false;
  bool _obscurePwd = true;
  bool _obscurePwd2 = true;
  String? _errorMsg;

  ResetAccountInfo? _accountInfo;
  ResetChannel _channel = ResetChannel.sms;
  String? _resetToken;
  Timer? _countdownTimer;
  int _countdown = 0;

  @override
  void initState() {
    super.initState();
    _loadCaptcha();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _usernameCtrl.dispose();
    _captchaCtrl.dispose();
    _codeCtrl.dispose();
    _pwdCtrl.dispose();
    _pwd2Ctrl.dispose();
    super.dispose();
  }

  Color get _brandColor => Theme.of(context).brightness == Brightness.light
      ? const Color(0xFFE65646)
      : const Color(0xFF8965BD);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Future<void> _loadCaptcha() async {
    setState(() => _captchaLoading = true);
    try {
      final captcha = await _accountService.fetchCaptcha();
      Uint8List? imageBytes;
      try {
        final comma = captcha.captchaBase64.indexOf(',');
        final raw = comma >= 0
            ? captcha.captchaBase64.substring(comma + 1)
            : captcha.captchaBase64;
        imageBytes = base64.decode(raw);
      } catch (e) {
        AppLog.e('ScuResetPasswordPage', 'Captcha decode error: $e');
      }
      if (!mounted) return;
      setState(() {
        _captcha = captcha;
        _captchaImageBytes = imageBytes;
        _captchaCtrl.clear();
      });
    } catch (e) {
      AppLog.e('ScuResetPasswordPage', 'Captcha load error: $e');
      if (!mounted) return;
      setState(() {
        _captcha = null;
        _captchaImageBytes = null;
      });
    } finally {
      if (mounted) setState(() => _captchaLoading = false);
    }
  }

  // ── 步骤1：确认账户 ─────────────────────────────────────────────

  Future<void> _submitAccount() async {
    if (!_accountFormKey.currentState!.validate()) return;
    final captcha = _captcha;
    if (captcha == null) {
      setState(
        () => _errorMsg = AppLocalizations.of(context)!.captchaNotLoaded,
      );
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final info = await _accountService.verifyUser(
        username: _usernameCtrl.text.trim(),
        captchaText: _captchaCtrl.text.trim(),
        captchaCode: captcha.code,
      );
      if (!mounted) return;
      setState(() {
        _accountInfo = info;
        _channel = info.hasPhone ? ResetChannel.sms : ResetChannel.email;
        _step = 2;
      });
    } on ForgotPasswordException catch (e) {
      AppLog.w('ScuResetPasswordPage', 'verifyUser failed: ${e.message}');
      if (!mounted) return;
      setState(() => _errorMsg = e.message);
      // 400 验证码错误 / 439 验证码过期：与官方一致刷新验证码重试
      if (e.businessCode == 400 || e.businessCode == 439) {
        unawaited(_loadCaptcha());
      }
    } catch (e) {
      AppLog.e('ScuResetPasswordPage', 'verifyUser error: $e');
      if (!mounted) return;
      setState(() => _errorMsg = AppLocalizations.of(context)!.networkError);
      unawaited(_loadCaptcha());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── 步骤2：安全验证 ─────────────────────────────────────────────

  Future<void> _sendCode() async {
    if (_countdown > 0 || _loading) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      await _accountService.sendVerifyCode(
        username: _usernameCtrl.text.trim(),
        channel: _channel,
        sToken: _accountInfo!.sToken,
      );
      if (!mounted) return;
      setState(() => _countdown = 60);
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _countdown -= 1;
          if (_countdown <= 0) {
            _countdown = 0;
            timer.cancel();
          }
        });
      });
    } on ForgotPasswordException catch (e) {
      AppLog.w('ScuResetPasswordPage', 'obtainCode failed: ${e.message}');
      if (!mounted) return;
      setState(() => _errorMsg = e.message);
    } catch (e) {
      AppLog.e('ScuResetPasswordPage', 'obtainCode error: $e');
      if (!mounted) return;
      setState(() => _errorMsg = AppLocalizations.of(context)!.networkError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitCode() async {
    if (!_codeFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final token = await _accountService.verifyCode(
        username: _usernameCtrl.text.trim(),
        channel: _channel,
        code: _codeCtrl.text.trim(),
        sToken: _accountInfo!.sToken,
      );
      if (!mounted) return;
      setState(() {
        _resetToken = token;
        _step = 3;
      });
    } on ForgotPasswordException catch (e) {
      AppLog.w('ScuResetPasswordPage', 'verifyCode failed: ${e.message}');
      if (!mounted) return;
      setState(() => _errorMsg = e.message);
    } catch (e) {
      AppLog.e('ScuResetPasswordPage', 'verifyCode error: $e');
      if (!mounted) return;
      setState(() => _errorMsg = AppLocalizations.of(context)!.networkError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── 步骤3：重置密码 ─────────────────────────────────────────────

  Future<void> _submitNewPassword() async {
    if (!_pwdFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      await _accountService.submitNewPassword(
        username: _usernameCtrl.text.trim(),
        channel: _channel,
        token: _resetToken!,
        password: _pwdCtrl.text,
      );
      if (!mounted) return;
      _countdownTimer?.cancel();
      setState(() => _step = 4);
    } on ForgotPasswordException catch (e) {
      AppLog.w('ScuResetPasswordPage', 'submit failed: ${e.message}');
      if (!mounted) return;
      setState(() => _errorMsg = e.message);
    } catch (e) {
      AppLog.e('ScuResetPasswordPage', 'submit error: $e');
      if (!mounted) return;
      setState(() => _errorMsg = AppLocalizations.of(context)!.networkError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goBackStep() {
    setState(() {
      _errorMsg = null;
      _step -= 1;
      if (_step == 1) unawaited(_loadCaptcha());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: _step == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_step == 4) {
          Navigator.of(context).pop(true);
        } else if (_step > 1) {
          _goBackStep();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.resetPassword)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStepIndicator(l10n),
                    const SizedBox(height: 24),
                    switch (_step) {
                      1 => _buildAccountStep(l10n),
                      2 => _buildVerifyStep(l10n),
                      3 => _buildNewPasswordStep(l10n),
                      _ => _buildSuccessView(l10n),
                    },
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(AppLocalizations l10n) {
    final labels = [
      l10n.resetPasswordStepAccount,
      l10n.resetPasswordStepVerify,
      l10n.resetPasswordStepReset,
    ];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 1.5,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: _step > i
                    ? _brandColor
                    : (_isDark ? Colors.white24 : Colors.grey.shade300),
              ),
            ),
          _buildStepBadge(i + 1),
          const SizedBox(width: 6),
          Text(
            labels[i],
            style: TextStyle(
              fontSize: 12,
              fontWeight: _step == i + 1 ? FontWeight.w600 : FontWeight.w400,
              color: _step >= i + 1
                  ? _brandColor
                  : (_isDark ? Colors.white38 : Colors.grey.shade500),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepBadge(int index) {
    final reached = _step >= index;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: reached ? _brandColor : Colors.transparent,
        border: Border.all(
          color: reached
              ? _brandColor
              : (_isDark ? Colors.white24 : Colors.grey.shade400),
          width: 1.5,
        ),
      ),
      child: Center(
        child: reached
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : Text(
                '$index',
                style: TextStyle(
                  fontSize: 12,
                  color: _isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
      ),
    );
  }

  // ── 各步骤表单 ──────────────────────────────────────────────────

  Widget _buildAccountStep(AppLocalizations l10n) {
    return Form(
      key: _accountFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScuLoginInputField(
            controller: _usernameCtrl,
            label: l10n.studentId,
            hint: l10n.studentIdHint,
            prefixIcon: Icons.person_outline,
            keyboardType: TextInputType.number,
            isDark: _isDark,
            brandColor: _brandColor,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? l10n.studentIdRequired : null,
          ),
          const SizedBox(height: 16),
          ScuLoginCaptchaRow(
            controller: _captchaCtrl,
            l10n: l10n,
            isDark: _isDark,
            brandColor: _brandColor,
            captchaImageBytes: _captchaImageBytes,
            captchaLoading: _captchaLoading,
            onRefresh: _loadCaptcha,
          ),
          _buildErrorAndActions(l10n, l10n.resetPasswordNext, _submitAccount),
        ],
      ),
    );
  }

  Widget _buildVerifyStep(AppLocalizations l10n) {
    final info = _accountInfo!;
    final channels = [
      if (info.hasPhone)
        (
          ResetChannel.sms,
          l10n.resetPasswordViaSms,
          l10n.resetPasswordSmsTip(ResetAccountInfo.maskedPhone(info.phone)),
        ),
      if (info.hasEmail)
        (
          ResetChannel.email,
          l10n.resetPasswordViaEmail,
          l10n.resetPasswordEmailTip(ResetAccountInfo.maskedEmail(info.email)),
        ),
    ];
    return Form(
      key: _codeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.resetPasswordChooseMethod,
            style: TextStyle(
              fontSize: 14,
              color: _isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          for (final (channel, title, tip) in channels) ...[
            _buildChannelCard(channel, title, tip),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ScuLoginInputField(
                  controller: _codeCtrl,
                  hint: l10n.captchaHint,
                  prefixIcon: Icons.shield_outlined,
                  keyboardType: TextInputType.number,
                  isDark: _isDark,
                  brandColor: _brandColor,
                  validator: (v) =>
                      (v == null || !RegExp(r'^\d{6}$').hasMatch(v.trim()))
                      ? l10n.resetPasswordCodeRequired
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton(
                  onPressed: _countdown > 0 || _loading ? null : _sendCode,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brandColor,
                    side: BorderSide(
                      color: _countdown > 0
                          ? (_isDark ? Colors.white24 : Colors.grey.shade300)
                          : _brandColor,
                    ),
                  ),
                  child: Text(
                    _countdown > 0
                        ? l10n.resetPasswordResendAfter(_countdown)
                        : l10n.resetPasswordSendCode,
                  ),
                ),
              ),
            ],
          ),
          _buildErrorAndActions(l10n, l10n.resetPasswordNext, _submitCode),
        ],
      ),
    );
  }

  Widget _buildChannelCard(ResetChannel channel, String title, String tip) {
    final selected = _channel == channel;
    return InkWell(
      onTap: () => setState(() => _channel = channel),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? _brandColor
                : (_isDark ? Colors.white24 : Colors.grey.shade300),
            width: selected ? 1.5 : 1,
          ),
          color: selected
              ? _brandColor.withValues(alpha: 0.06)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              channel == ResetChannel.sms
                  ? Icons.sms_outlined
                  : Icons.mail_outline,
              color: selected ? _brandColor : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tip,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? _brandColor : Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewPasswordStep(AppLocalizations l10n) {
    return Form(
      key: _pwdFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScuLoginInputField(
            controller: _pwdCtrl,
            label: l10n.resetPasswordNewPasswordLabel,
            hint: l10n.passwordHint,
            prefixIcon: Icons.lock_outline,
            obscureText: _obscurePwd,
            suffixIcon: _buildEyeToggle(_obscurePwd, () {
              setState(() => _obscurePwd = !_obscurePwd);
            }),
            isDark: _isDark,
            brandColor: _brandColor,
            validator: (v) =>
                (v == null || v.isEmpty) ? l10n.passwordRequired : null,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.resetPasswordPolicyTip,
            style: TextStyle(
              fontSize: 12,
              color: _isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 16),
          ScuLoginInputField(
            controller: _pwd2Ctrl,
            label: l10n.resetPasswordConfirmPasswordLabel,
            hint: l10n.passwordHint,
            prefixIcon: Icons.lock_outline,
            obscureText: _obscurePwd2,
            suffixIcon: _buildEyeToggle(_obscurePwd2, () {
              setState(() => _obscurePwd2 = !_obscurePwd2);
            }),
            isDark: _isDark,
            brandColor: _brandColor,
            validator: (v) => (v == null || v.isEmpty)
                ? l10n.passwordRequired
                : (v != _pwdCtrl.text
                      ? l10n.resetPasswordPasswordMismatch
                      : null),
          ),
          _buildErrorAndActions(
            l10n,
            l10n.resetPasswordSubmit,
            _submitNewPassword,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Icon(Icons.check_circle_outline, size: 72, color: _brandColor),
        const SizedBox(height: 16),
        Text(
          l10n.resetPasswordSuccess,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: _isDark ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 24),
        ScuLoginButton(
          loading: false,
          onPressed: () => Navigator.of(context).pop(true),
          brandColor: _brandColor,
          label: l10n.resetPasswordBackToLogin,
        ),
      ],
    );
  }

  Widget _buildEyeToggle(bool obscure, VoidCallback onTap) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: _isDark ? Colors.white54 : Colors.grey.shade600,
        size: 20,
      ),
      onPressed: onTap,
    );
  }

  Widget _buildErrorAndActions(
    AppLocalizations l10n,
    String buttonLabel,
    VoidCallback onPressed,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMsg != null) ...[
          const SizedBox(height: 16),
          _buildErrorMessage(_errorMsg!, _isDark),
        ],
        const SizedBox(height: 20),
        ScuLoginButton(
          loading: _loading,
          onPressed: onPressed,
          brandColor: _brandColor,
          label: buttonLabel,
        ),
      ],
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
}
