import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../services/api_client.dart';
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
      await const ApiClient().login(
        phone: _phoneCtrl.text,
        password: _passwordCtrl.text,
      );
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final logoWidth = (constraints.maxWidth * 0.36).clamp(
                          80.0,
                          106.0,
                        );
                        final logoHeight = (logoWidth / 3.9).clamp(24.0, 32.0);
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppLogo(
                              width: logoWidth,
                              height: logoHeight,
                              darkMode: true,
                            ),
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
                        );
                      },
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
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Телефон',
                            prefixIcon: Icon(
                              Icons.phone_outlined,
                              color: AppColors.brandBlack,
                            ),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? 'Введите телефон' : null,
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
                            onPressed: () {},
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
                              onTap: () => context.go(AppRoutes.register),
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
