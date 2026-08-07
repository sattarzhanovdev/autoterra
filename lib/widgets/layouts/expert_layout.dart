import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../screens/ai/ai_assistant_screen.dart';
import '../../screens/expert/expert_knowledge_base_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/qa/qa_screen.dart';
import '../../core/theme.dart';
import '../../widgets/common/brand_icon.dart';

class ExpertLayout extends StatefulWidget {
  const ExpertLayout({super.key});

  @override
  State<ExpertLayout> createState() => _ExpertLayoutState();
}

class _ExpertLayoutState extends State<ExpertLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const AiAssistantScreen(),
    const QaScreen(),
    const KnowledgeBaseScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.brandBlack, width: 2)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: AppColors.brandBlack,
          selectedItemColor: AppColors.brandRed,
          unselectedItemColor: Colors.white.withValues(alpha: 0.5),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.chat_bubble_2_fill, size: 24),
              label: 'ЧАТ AI',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.question_circle_fill, size: 24),
              label: 'ТИКЕТЫ',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.book_fill, size: 24),
              label: 'БАЗА ЗНАНИЙ',
            ),
            BottomNavigationBarItem(
              icon: Icon(BrandIcons.person, size: 24),
              label: 'ПРОФИЛЬ',
            ),
          ],
        ),
      ),
    );
  }
}
