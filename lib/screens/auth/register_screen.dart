import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../services/api_client.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _api = ApiClient();
  final _pageCtrl = PageController();
  int _currentPage = 0;

  // Page 1 fields
  final _innCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String? _selectedRegionId;
  List<Map<String, dynamic>> _regions = [];

  // Page 2 fields
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  bool _loading = false;
  String? _innError;

  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  bool _loadingRegions = false;

  @override
  void initState() {
    super.initState();
    _fetchRegions();
  }

  Future<void> _fetchRegions() async {
    if (mounted) setState(() => _loadingRegions = true);
    try {
      final regions = await _api.getRegions();
      if (mounted) {
        setState(() {
          _regions = regions;
          _loadingRegions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingRegions = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки регионов: $e'),
            backgroundColor: AppColors.brandRed,
            action: SnackBarAction(
              label: 'ПОВТОР',
              textColor: Colors.white,
              onPressed: _fetchRegions,
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _innCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    setState(() => _innError = null);
    if (_currentPage == 0 && !_formKey1.currentState!.validate()) return;
    if (_selectedRegionId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Выберите регион')));
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
    setState(() {
      _loading = true;
      _innError = null;
    });

    try {
      final result = await _api.register({
        'username': _phoneCtrl.text,
        'password': _passwordCtrl.text,
        'inn': _innCtrl.text,
        'region_id': int.parse(_selectedRegionId!),
        'company_name': _nameCtrl.text,
        'contact_name': _contactCtrl.text,
        'store_address': _addressCtrl.text,
      });

      if (mounted) {
        _showSuccessDialog(result['requires_approval'] == true);
      }
    } on ApiException catch (e) {
      setState(() => _loading = false);

      final details = e.details;
      String? code;
      String? backendMsg;

      if (details is Map) {
        code = details['code']?.toString();
        backendMsg = details['detail']?.toString();
      }

      if (code == 'inn_duplicate') {
        setState(() {
          _innError = backendMsg ?? e.message;
          _currentPage = 0;
          _pageCtrl.animateToPage(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        });
      } else {
        // Если есть ошибки по конкретным полям (400)
        String finalMsg = backendMsg ?? e.message;
        if (details is Map && details['errors'] is Map) {
          final errs = details['errors'] as Map;
          if (errs.isNotEmpty) {
            finalMsg = errs.values.first.toString();
          }
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(finalMsg),
            backgroundColor: AppColors.brandRed,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.brandRed,
        ),
      );
    }
  }

  void _showSuccessDialog(bool requiresApproval) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.brandBlack,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'РЕГИСТРАЦИЯ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppColors.brandRed,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              requiresApproval
                  ? 'Заявка на регистрацию филиала отправлена на модерацию.'
                  : 'Регистрация успешно завершена.',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Вы можете войти в систему после подтверждения.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.go(AppRoutes.login),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.brandRed,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: const Text('ВОЙТИ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('РЕГИСТРАЦИЯ'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _currentPage == 0
              ? context.pop()
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
              height: 1,
              color: _currentPage >= 1
                  ? AppColors.brandRed
                  : Colors.white.withValues(alpha: 0.2),
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
            color: active
                ? AppColors.brandRed
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: active ? AppColors.brandRed : Colors.white24,
            ),
          ),
          child: Center(
            child: Text(
              n.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
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
            const Text(
              'ДАННЫЕ АВТОСЕРВИСА',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _innCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'ИНН ОРГАНИЗАЦИИ *',
                errorText: _innError,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              validator: (v) {
                if (v!.isEmpty) return 'Введите ИНН';
                if (v.length < 10) return 'ИНН должен содержать 10-12 цифр';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'НАЗВАНИЕ СЕРВИСА *',
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
              ),
              validator: (v) => v!.isEmpty ? 'Введите название' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'АДРЕС МАГАЗИНА/ТОЧКИ *',
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                prefixIcon: Icon(Icons.location_on_outlined, size: 20),
              ),
              validator: (v) => v!.isEmpty ? 'Введите адрес' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedRegionId,
              hint: Text(_loadingRegions ? 'ЗАГРУЗКА РЕГИОНОВ...' : 'ВЫБЕРИТЕ РЕГИОН'),
              decoration: const InputDecoration(
                labelText: 'РЕГИОН *',
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
              ),
              items: _regions
                  .map(
                    (r) => DropdownMenuItem(
                      value: r['id'].toString(),
                      child: Text(r['name']),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedRegionId = v),
              validator: (v) => v == null ? 'Выберите регион' : null,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandBlack,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('ДАЛЕЕ'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
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
            const Text(
              'КОНТАКТЫ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _contactCtrl,
              decoration: const InputDecoration(
                labelText: 'ФИО КОНТАКТНОГО ЛИЦА *',
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
              ),
              validator: (v) => v!.isEmpty ? 'Введите ФИО' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'ТЕЛЕФОН (ЛОГИН) *',
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
              ),
              validator: (v) => v!.isEmpty ? 'Введите телефон' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'ПАРОЛЬ *',
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                if (v!.isEmpty) return 'Введите пароль';
                if (v.length < 8) return 'Минимум 8 символов';
                return null;
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandRed,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('ЗАРЕГИСТРИРОВАТЬСЯ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
