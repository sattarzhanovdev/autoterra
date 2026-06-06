import 'package:flutter/material.dart';
import '../../core/theme.dart';

class DistributorCabinetScreen extends StatelessWidget {
  const DistributorCabinetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Кабинет дистрибьютора')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.business_center_outlined, size: 64, color: AppColors.brandRed),
            const SizedBox(height: 16),
            const Text(
              'Панель управления дистрибьютора',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Здесь будут заказы и ассортимент',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
