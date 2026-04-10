// ignore_for_file: use_build_context_synchronously

import 'package:dawnshift/features/auth/auth_service.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.authService});

  final AuthService authService;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _isRegister = false;
  var _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      if (_isRegister) {
        await widget.authService.registerWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await widget.authService.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } on EmailAlreadyInUseException {
      setState(() => _errorMessage = 'このメールアドレスはすでに登録されています。');
    } on UserNotFoundException {
      setState(() => _errorMessage = 'メールアドレスが見つかりません。');
    } on WrongPasswordException {
      setState(() => _errorMessage = 'パスワードが正しくありません。');
    } catch (e) {
      setState(() => _errorMessage = 'エラーが発生しました: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isRegister ? '新規登録' : 'ログイン')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          TextField(
            key: const Key('email-field'),
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'メールアドレス'),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('password-field'),
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'パスワード'),
            obscureText: true,
          ),
          const SizedBox(height: 24),
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
          ],
          FilledButton(
            key: const Key('submit-button'),
            onPressed: _loading ? null : _submit,
            child: Text(_loading
                ? '処理中...'
                : (_isRegister ? '登録する' : 'ログイン')),
          ),
          const SizedBox(height: 12),
          TextButton(
            key: const Key('toggle-mode-button'),
            onPressed: _loading
                ? null
                : () => setState(() => _isRegister = !_isRegister),
            child: Text(_isRegister
                ? 'すでにアカウントをお持ちの方はこちら'
                : 'アカウントを新規作成'),
          ),
          ],
        ),
      ),
    );
  }
}
