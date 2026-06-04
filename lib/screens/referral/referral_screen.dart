import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../services/data_repository.dart';
import '../../widgets/common/section_header.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  late Future<DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = const DataRepository().dashboard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('РЕФЕРАЛЬНАЯ ПРОГРАММА')),
      body: FutureBuilder<DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString().toUpperCase()));
          }
          final client = snapshot.data!.client;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReferralCard(client),
                const SizedBox(height: 24),
                const SectionHeader(title: 'КАК ЭТО РАБОТАЕТ'),
                const SizedBox(height: 12),
                _buildSteps(),
                const SizedBox(height: 24),
                const SectionHeader(title: 'ВАШИ РЕФЕРАЛЫ'),
                const SizedBox(height: 12),
                _buildReferralsList(),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReferralCard(Client client) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ВАША ССЫЛКА ДЛЯ ПРИГЛАШЕНИЯ',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              border: Border.all(color: AppColors.border, width: 1.5),
              borderRadius: BorderRadius.zero,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'autoterra.ru/reg?ref=SA2901',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_sharp, color: AppColors.brandRed, size: 20),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ПРИГЛАШАЙТЕ ПАРТНЕРОВ И ПОЛУЧАЙТЕ БОНУСЫ НА СЧЕТ ЗА ИХ ЗАКУПКИ.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSteps() {
    return AppCard(
      child: Column(
        children: [
          _step('1', 'ОТПРАВЬТЕ ССЫЛКУ ПАРТНЕРУ ИЛИ ДРУГОМУ АВТОСЕРВИСУ.'),
          _step('2', 'ОНИ РЕГИСТРИРУЮТСЯ И УКАЗЫВАЮТ ВАШ КОД.'),
          _step('3', 'ВЫ ПОЛУЧАЕТЕ 1% ОТ ИХ ЗАКУПОК НА СВОЙ БОНУСНЫЙ СЧЕТ.'),
        ],
      ),
    );
  }

  Widget _step(String n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.brandBlack,
              shape: BoxShape.rectangle,
            ),
            child: Center(
              child: Text(
                n,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralsList() {
    return AppCard(
      child: Column(
        children: [
          _referralItem('СТО "МАСТЕР"', 'АКТИВЕН', '12 400 ₽'),
          const Divider(height: 24),
          _referralItem('КУЗОВНОЙ ЦЕНТР №1', 'АКТИВЕН', '8 200 ₽'),
          const Divider(height: 24),
          _referralItem('ИП ИВАНОВ А.В.', 'НОВЫЙ', '0 ₽'),
        ],
      ),
    );
  }

  Widget _referralItem(String name, String status, String bonus) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                status,
                style: TextStyle(
                  color: status == 'АКТИВЕН' ? AppColors.brandBlack : AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Text(
          bonus,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.brandRed),
        ),
      ],
    );
  }
}
