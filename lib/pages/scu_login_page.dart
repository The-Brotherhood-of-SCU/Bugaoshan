import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:Bugaoshan/injection/injector.dart';
import 'package:Bugaoshan/l10n/app_localizations.dart';
import 'package:Bugaoshan/providers/scu_auth_provider.dart';

class SCULoginPage extends StatefulWidget {
  const SCULoginPage({super.key});

  @override
  State<SCULoginPage> createState() => _SCULoginPageState();
}

class _SCULoginPageState extends State<SCULoginPage> {
  final _auth = getIt<SCUAuthProvider>();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  final _captchaCtrl = TextEditingController();

  Uint8List? _captchaImage;
  bool _loadingCaptcha = false;
  bool _loggingIn = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: _auth.savedUsername);
    _passwordCtrl = TextEditingController(text: _auth.savedPassword);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _captchaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCaptcha() async {
    if (_usernameCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _error = '请先填写学号和密码');
      return;
    }
    setState(() {
      _loadingCaptcha = true;
      _error = null;
    });
    try {
      final img = await _auth.getCaptcha(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text,
      );
      setState(() => _captchaImage = img);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loadingCaptcha = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_captchaImage == null) {
      setState(() => _error = '请先获取验证码');
      return;
    }
    setState(() {
      _loggingIn = true;
      _error = null;
    });
    try {
      _auth.saveCredentials(_usernameCtrl.text.trim(), _passwordCtrl.text);
      await _auth.login(_captchaCtrl.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _captchaImage = null; // 验证码失效，需重新获取
        _captchaCtrl.clear();
      });
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scuLogin)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                spacing: 16,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.scuStudentId,
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? l10n.fieldRequired : null,
                  ),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.scuPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? l10n.fieldRequired : null,
                  ),
                  Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _captchaCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.scuCaptcha,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? l10n.fieldRequired
                              : null,
                        ),
                      ),
                      _buildCaptchaWidget(),
                    ],
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13,
                      ),
                    ),
                  FilledButton(
                    onPressed: _loggingIn ? null : _submit,
                    child: _loggingIn
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.scuLoginButton),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptchaWidget() {
    if (_loadingCaptcha) {
      return const SizedBox(
        width: 100,
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_captchaImage != null) {
      return GestureDetector(
        onTap: _loadCaptcha,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.memory(
            _captchaImage!,
            width: 100,
            height: 48,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return OutlinedButton(
      onPressed: _loadCaptcha,
      style: OutlinedButton.styleFrom(minimumSize: const Size(100, 48)),
      child: Text(AppLocalizations.of(context)!.scuGetCaptcha),
    );
  }
}
