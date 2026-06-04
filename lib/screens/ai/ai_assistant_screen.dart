import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _api = const ApiClient();
  final List<_Message> _messages = [
    _Message(
      text:
          'Привет! Я AI-помощник AutoTerra. Помогу подобрать материалы, расскажу о технологии нанесения, разберу дефекты и отвечу на вопросы по продукции. Чем могу помочь?',
      isAi: true,
    ),
  ];
  bool _isTyping = false;

  final _suggestions = [
    'Какой грунт подойдёт для алюминия?',
    'Проблема: лак пузырится после сушки',
    'Подберите комплект для кузовного ремонта',
    'Технология нанесения 2K лака',
  ];

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_Message(text: text, isAi: false));
      _isTyping = true;
      _msgCtrl.clear();
    });
    _scrollToBottom();
    String answer;
    try {
      final response = await _api.aiChatWithMeta(text);
      answer = response['answer'] as String;
    } catch (e) {
      answer =
          'AI-помощник сейчас недоступен. Попробуйте позже или отправьте вопрос технологу через раздел Вопрос-Ответ.';
    }
    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add(_Message(text: answer, isAi: true));
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.brandRed,
                borderRadius: BorderRadius.zero,
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI-ПОМОЩНИК',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
                Text(
                  'AutoTerra Assistant',
                  style: TextStyle(fontSize: 10, color: Colors.white60, letterSpacing: 0.3),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_messages.length == 1) _buildSuggestions(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, i) {
                  if (_isTyping && i == _messages.length) return _TypingBubble();
                  return _MessageBubble(message: _messages[i]);
                },
              ),
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ЧАСТЫЕ ВОПРОСЫ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions
                .map(
                  (s) => GestureDetector(
                    onTap: () => _sendMessage(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandWhite,
                        border: Border.all(
                          color: AppColors.brandBlack,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        s,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.brandBlack,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.brandBlack, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              decoration: const InputDecoration(
                hintText: 'Задайте вопрос...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: AppColors.brandBlack, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                isDense: true,
                filled: true,
                fillColor: AppColors.canvas,
              ),
              maxLines: 4,
              minLines: 1,
              onSubmitted: _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(_msgCtrl.text),
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.brandRed,
                borderRadius: BorderRadius.zero,
              ),
              child: const Icon(
                Icons.send_sharp,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _Message message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: message.isAi
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isAi) ...[
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.brandBlack,
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isAi ? Colors.white : AppColors.brandBlack,
                border: message.isAi
                    ? Border.all(color: AppColors.brandBlack, width: 1.5)
                    : null,
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isAi ? AppColors.brandBlack : Colors.white,
                  fontSize: 14,
                  fontWeight: message.isAi ? FontWeight.w500 : FontWeight.w400,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            color: AppColors.brandBlack,
            child: const Icon(
              Icons.smart_toy_outlined,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.brandBlack, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(0),
                const SizedBox(width: 4),
                _dot(200),
                const SizedBox(width: 4),
                _dot(400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int delay) {
    return Container(
      width: 6,
      height: 6,
      color: AppColors.brandBlack.withOpacity(0.5),
    );
  }
}

class _Message {
  final String text;
  final bool isAi;
  const _Message({required this.text, required this.isAi});
}
