import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/app_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _resetLoading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final response = await ApiClient().login(
        phone: _phoneCtrl.text,
        password: _passwordCtrl.text,
      );

      // Update auth service with backend user role
      if (response['user'] != null) {
        authService.updateFromBackendUser(
          response['user'] as Map<String, dynamic>,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    context.go(AppRoutes.home);
  }

  Future<void> _showPasswordResetDialog() async {
    final resetFormKey = GlobalKey<FormState>();
    final resetPhoneCtrl = TextEditingController(text: _phoneCtrl.text);
    final resetInnCtrl = TextEditingController();
    final resetPasswordCtrl = TextEditingController();
    var resetObscure = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (!resetFormKey.currentState!.validate()) return;
              setDialogState(() => _resetLoading = true);
              try {
                await ApiClient().resetPassword(
                  phone: resetPhoneCtrl.text.trim(),
                  inn: resetInnCtrl.text.trim(),
                  newPassword: resetPasswordCtrl.text,
                );
              } on ApiException catch (e) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(e.message),
                    backgroundColor: AppColors.error,
                  ),
                );
                setDialogState(() => _resetLoading = false);
                return;
              } catch (e) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(e.toString()),
                    backgroundColor: AppColors.error,
                  ),
                );
                setDialogState(() => _resetLoading = false);
                return;
              }

              if (!dialogContext.mounted || !mounted) return;
              _phoneCtrl.text = resetPhoneCtrl.text.trim();
              _passwordCtrl.text = resetPasswordCtrl.text;
              setDialogState(() => _resetLoading = false);
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Пароль обновлен. Можно войти с новым паролем.',
                  ),
                  backgroundColor: AppColors.success,
                ),
              );
            }

            return AlertDialog(
              backgroundColor: AppColors.brandWhite,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              title: const Text(
                'ВОССТАНОВЛЕНИЕ ПАРОЛЯ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              content: Form(
                key: resetFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: resetPhoneCtrl,
                        keyboardType: TextInputType.text,
                        decoration: const InputDecoration(
                          labelText: 'Телефон или Логин',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Введите телефон или логин'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: resetInnCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'ИНН организации',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) {
                          final digits = (v ?? '').replaceAll(
                            RegExp(r'\D'),
                            '',
                          );
                          if (digits.isEmpty) return 'Введите ИНН';
                          if (digits.length != 10 && digits.length != 12) {
                            return 'ИНН должен содержать 10 или 12 цифр';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: resetPasswordCtrl,
                        obscureText: resetObscure,
                        decoration: InputDecoration(
                          labelText: 'Новый пароль',
                          prefixIcon: const Icon(Icons.lock_reset_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              resetObscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setDialogState(
                              () => resetObscure = !resetObscure,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Введите новый пароль';
                          }
                          if (v.length < 8) return 'Минимум 8 символов';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _resetLoading
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('ОТМЕНА'),
                ),
                ElevatedButton(
                  onPressed: _resetLoading ? null : submit,
                  child: _resetLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('ОБНОВИТЬ'),
                ),
              ],
            );
          },
        );
      },
    );

    resetPhoneCtrl.dispose();
    resetInnCtrl.dispose();
    resetPasswordCtrl.dispose();
    if (mounted && _resetLoading) {
      setState(() => _resetLoading = false);
    } else {
      _resetLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      body: SafeArea(
        child: Column(
          children: [
            // Header with logo
            Expanded(
              flex: 2,
              child: Stack(
                children: [
                  // Decorative red bar
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 3, color: AppColors.brandRed),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppLogo(height: 32, darkMode: true),
                        const SizedBox(height: 12),
                        Text(
                          'Федеральная B2B-платформа ЛКМ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Form panel
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: AppColors.brandWhite,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          'ВХОД В СИСТЕМУ',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Введите данные для входа',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.text,
                          decoration: const InputDecoration(
                            labelText: 'Телефон или Логин',
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: AppColors.brandBlack,
                            ),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? 'Введите телефон или логин' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Пароль',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: AppColors.brandBlack,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? 'Введите пароль' : null,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showPasswordResetDialog,
                            child: const Text('Забыли пароль?'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('ВОЙТИ'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Нет аккаунта? ',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.push(AppRoutes.register),
                              child: const Text(
                                'Зарегистрироваться',
                                style: TextStyle(
                                  color: AppColors.brandRed,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
