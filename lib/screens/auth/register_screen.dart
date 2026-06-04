import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../services/api_client.dart';
import '../../widgets/common/app_logo.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;

  // Page 1 fields
  final _innCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String? _selectedRegion;
  String? _selectedCategory;

  // Page 2 fields
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  bool _loading = false;
  final _api = const ApiClient();

  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  @override
  void dispose() {
    _pageCtrl.dispose();
    _innCtrl.dispose();
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0 && !_formKey1.currentState!.validate()) return;
    if (_selectedRegion == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ВЫБЕРИТЕ РЕГИОН')));
      return;
    }
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ВЫБЕРИТЕ КАТЕГОРИЮ')));
      return;
    }
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage = 1);
  }

  void _register() async {
    if (!_formKey2.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final result = await _api.register(
        inn: _innCtrl.text,
        companyName: _nameCtrl.text,
        region: _selectedRegion!,
        category: _selectedCategory!,
        contactName: _contactCtrl.text,
        phone: _phoneCtrl.text,
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );
      if (mounted) {
        _showSuccessDialog(result['status']?.toString() ?? 'under_review');
      }
    } on ApiException catch (error) {
      if (mounted) {
        _showError(_registrationErrorMessage(error).toUpperCase());
      }
    } on TimeoutException {
      if (mounted) {
        _showError('СЕРВЕР НЕДОСТУПЕН. ПРОВЕРЬТЕ ПОДКЛЮЧЕНИЕ.');
      }
    } catch (_) {
      if (mounted) {
        _showError('ОШИБКА РЕГИСТРАЦИИ. ПОПРОБУЙТЕ ПОЗЖЕ.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _registrationErrorMessage(ApiException error) {
    final details = error.details;
    final code = details is Map<String, dynamic> ? details['code']?.toString() : null;
    switch (code) {
      case 'inn_duplicate':
        return 'ИНН УЖЕ ЗАРЕГИСТРИРОВАН В ДАННОМ РЕГИОНЕ.';
      case 'region_not_found':
        return 'РЕГИОН НЕ НАЙДЕН.';
      case 'phone_duplicate':
        return 'ПОЛЬЗОВАТЕЛЬ С ТАКИМ ТЕЛЕФОНОМ УЖЕ СУЩЕСТВУЕТ.';
      default:
        return error.message.isNotEmpty
            ? error.message
            : 'НЕ УДАЛОСЬ ОТПРАВИТЬ ЗАЯВКУ.';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccessDialog(String status) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.brandBlack.withOpacity(0.05),
                shape: BoxShape.rectangle,
                border: Border.all(color: AppColors.brandBlack, width: 2),
              ),
              child: const Icon(
                Icons.check_sharp,
                color: AppColors.brandBlack,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'ЗАЯВКА ОТПРАВЛЕНА',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'ВАШ СТАТУС: ${_statusLabel(status).toUpperCase()}. ПРОФИЛЬ ПЕРЕДАН ДИСТРИБЬЮТОРУ ДЛЯ ПОДТВЕРЖДЕНИЯ.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('ПЕРЕЙТИ КО ВХОДУ'),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'under_review':
      case 'pending':
        return 'на проверке';
      case 'new':
      case 'newClient':
        return 'новый';
      case 'approved':
      case 'active':
        return 'одобрен';
      case 'rejected':
      case 'blocked':
        return 'отклонён';
      default:
        return 'на проверке';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const AppLogo(width: 92, height: 22),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_sharp),
          onPressed: () => _currentPage == 0
              ? context.go(AppRoutes.login)
              : (() {
                  _pageCtrl.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                  setState(() => _currentPage = 0);
                })(),
        ),
      ),
      body: Column(
        children: [
          _buildStepper(),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [_buildPage1(), _buildPage2()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Container(
      color: AppColors.brandBlack,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Row(
        children: [
          _stepItem(1, 'СЕРВИС', _currentPage >= 0),
          Expanded(
            child: Container(
              height: 2,
              color: _currentPage >= 1
                  ? AppColors.brandRed
                  : Colors.white.withOpacity(0.3),
            ),
          ),
          _stepItem(2, 'КОНТАКТЫ', _currentPage >= 1),
        ],
      ),
    );
  }

  Widget _stepItem(int n, String label, bool active) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: active ? AppColors.brandRed : Colors.white.withOpacity(0.3),
            shape: BoxShape.rectangle,
          ),
          child: Center(
            child: Text(
              '$n',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(active ? 1 : 0.5),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildPage1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'РЕГИСТРАЦИЯ СЕРВИСА',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            Text(
              'ЗАПОЛНИТЕ ДАННЫЕ ВАШЕГО ПРЕДПРИЯТИЯ',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _innCtrl,
              keyboardType: TextInputType.number,
              maxLength: 12,
              decoration: const InputDecoration(
                labelText: 'ИНН ОРГАНИЗАЦИИ *',
                prefixIcon: Icon(Icons.business_sharp),
                counterText: '',
              ),
              validator: (v) {
                if (v!.isEmpty) return 'ВВЕДИТЕ ИНН';
                if (v.length < 10) return 'ИНН ДОЛЖЕН БЫТЬ 10-12 ЦИФР';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'НАЗВАНИЕ СЕРВИСА *',
                prefixIcon: Icon(Icons.store_sharp),
              ),
              validator: (v) => v!.isEmpty ? 'ВВЕДИТЕ НАЗВАНИЕ' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedRegion,
              decoration: const InputDecoration(
                labelText: 'РЕГИОН ПРИСУТСТВИЯ *',
                prefixIcon: Icon(Icons.location_on_sharp),
              ),
              items: AppConstants.regions
                  .map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase())))
                  .toList(),
              onChanged: (v) => setState(() => _selectedRegion = v),
            ),
            const SizedBox(height: 24),
            const Text(
              'КАТЕГОРИЯ СЕРВИСА *',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
            ),
            const SizedBox(height: 12),
            ...AppConstants.clientCategories.entries.map(
              (e) => _categoryCard(e.key, e.value),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _nextPage,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('ДАЛЕЕ'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_sharp, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryCard(String key, String description) {
    final selected = _selectedCategory == key;
    Color color;
    switch (key) {
      case 'A':
        color = AppColors.categoryA;
        break;
      case 'B':
        color = AppColors.categoryB;
        break;
      default:
        color = AppColors.categoryC;
    }
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandBlack.withValues(alpha: 0.05)
              : Colors.white,
          border: Border.all(
            color: selected ? AppColors.brandBlack : AppColors.border,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.zero,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.zero,
              ),
              child: Center(
                child: Text(
                  key,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                description.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            if (selected) const Icon(Icons.check_box_sharp, color: AppColors.brandBlack, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildPage2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'КОНТАКТНЫЕ ДАННЫЕ',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            Text(
              'ДАННЫЕ ОТВЕТСТВЕННОГО ЛИЦА',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _contactCtrl,
              decoration: const InputDecoration(
                labelText: 'ФИО КОНТАКТНОГО ЛИЦА *',
                prefixIcon: Icon(Icons.person_sharp),
              ),
              validator: (v) => v!.isEmpty ? 'ВВЕДИТЕ ФИО' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'ТЕЛЕФОН *',
                prefixIcon: Icon(Icons.phone_sharp),
              ),
              validator: (v) => v!.isEmpty ? 'ВВЕДИТЕ ТЕЛЕФОН' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'EMAIL',
                prefixIcon: Icon(Icons.email_sharp),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'ПАРОЛЬ ДЛЯ ВХОДА *',
                prefixIcon: const Icon(Icons.lock_sharp),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_sharp
                        : Icons.visibility_off_sharp,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                if (v!.isEmpty) return 'ВВЕДИТЕ ПАРОЛЬ';
                if (v.length < 6) return 'МИНИМУМ 6 СИМВОЛОВ';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.brandWhite,
                border: Border.all(color: AppColors.border, width: 1.5),
                borderRadius: BorderRadius.zero,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_sharp,
                    color: AppColors.brandBlack,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ПОСЛЕ РЕГИСТРАЦИИ ВАШ ПРОФИЛЬ БУДЕТ ПРОВЕРЕН РЕГИОНАЛЬНЫМ ДИСТРИБЬЮТОРОМ.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('ЗАРЕГИСТРИРОВАТЬСЯ', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
