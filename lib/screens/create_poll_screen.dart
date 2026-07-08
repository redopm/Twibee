import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/chat_service.dart';
import 'package:provider/provider.dart';

class CreatePollScreen extends StatefulWidget {
  final String chatId;
  // If provided, this callback is used instead of ChatService.sendMessage
  final Future<void> Function(String question, List<String> options)? onSend;
  const CreatePollScreen({super.key, required this.chatId, this.onSend});

  @override
  State<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePollScreen> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _allowMultipleAnswers = true;

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  bool _isSendEnabled() {
    if (_questionController.text.trim().isEmpty) return false;
    int filledOptions = 0;
    for (var controller in _optionControllers) {
      if (controller.text.trim().isNotEmpty) filledOptions++;
    }
    return filledOptions >= 2;
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F6),
      appBar: TwibeeAppBar(
        title: 'Create poll',
        centerTitle: true,
        onBack: () => Navigator.pop(context),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.dark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSendEnabled()
                ? () async {
                    final options = _optionControllers.map((c) => c.text.trim()).where((o) => o.isNotEmpty).toList();
                    final question = _questionController.text.trim();
                    if (widget.onSend != null) {
                      Navigator.pop(context);
                      await widget.onSend!(question, options);
                    } else {
                      final pollData = {
                        'question': question,
                        'options': options,
                        'allows_multiple_answers': _allowMultipleAnswers,
                      };
                      context.read<ChatService>().sendMessage(
                            chatId: widget.chatId,
                            messageType: 'poll',
                            content: jsonEncode(pollData),
                          );
                      Navigator.pop(context);
                    }
                  }
                : null,
            child: Text('Send', style: TextStyle(color: _isSendEnabled() ? AppColors.green : Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text('QUESTION', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: _questionController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Ask question',
                hintStyle: TextStyle(color: AppColors.grey2),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text('OPTIONS', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                for (int i = 0; i < _optionControllers.length; i++) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _optionControllers[i],
                          onChanged: (_) {
                            setState(() {});
                            // Auto-add new option if we type in the last one
                            if (i == _optionControllers.length - 1 && _optionControllers[i].text.isNotEmpty && _optionControllers.length < 12) {
                              _addOption();
                            }
                          },
                          decoration: const InputDecoration(
                            hintText: 'Add',
                            hintStyle: TextStyle(color: AppColors.grey2),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      if (i > 1 && _optionControllers[i].text.isEmpty && _optionControllers.length > 2)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                          onPressed: () => _removeOption(i),
                        ),
                    ],
                  ),
                  if (i < _optionControllers.length - 1) const Divider(height: 1, indent: 16),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              title: const Text('Allow multiple answers'),
              value: _allowMultipleAnswers,
              activeThumbColor: AppColors.green,
              onChanged: (val) => setState(() => _allowMultipleAnswers = val),
            ),
          ),
        ],
      ),
    );
  }
}

