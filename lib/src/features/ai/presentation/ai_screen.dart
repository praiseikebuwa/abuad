import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../data/ai_service.dart';

class AiMessage {
  final String content;
  final bool isUser;
  final bool isStreaming;

  const AiMessage({
    required this.content,
    required this.isUser,
    this.isStreaming = false,
  });

  AiMessage copyWith({String? content, bool? isStreaming}) {
    return AiMessage(
      content: content ?? this.content,
      isUser: isUser,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

enum AiMode {
  general('General', Icons.auto_awesome, Colors.blue),
  academic('Academic Advisor', Icons.school, Colors.brown),
  guide('Campus Guide', Icons.map, Colors.green),
  buddy('Study Buddy', Icons.people, Colors.orange);

  final String label;
  final IconData icon;
  final Color color;

  const AiMode(this.label, this.icon, this.color);
}

class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});

  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  final _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  AiMode _currentMode = AiMode.general;

  List<AiMessage> _messages = [
    const AiMessage(
      content:
          "Hello! I'm your ABUAD AI Assistant. 🎓\n\nHow can I help you today?",
      isUser: false,
    ),
  ];

  bool _isTyping = false;

  final _aiService = AiService();

  // existing state variables...

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();
    setState(() {
      _messages.add(AiMessage(content: text, isUser: true));
      _isTyping = true;
    });

    _scrollToBottom();

    // Prepare response message container
    setState(() {
      _messages.add(
        const AiMessage(content: "", isUser: false, isStreaming: true),
      );
    });

    try {
      // Send optional system prompt context first if it's a new session or mode switch
      // For simplicity in this demo, we just send user message.
      // In a real app, you might prepend the system prompt to the history or strictly use the system instruction API if available.

      String accumulatedText = "";

      // We'll wrap the user's input with the mode context for better one-shot responses in this simple implementation
      final contextPrompt =
          "${AiService.getSystemPrompt(_currentMode.label)}\n\nUser: $text";

      await for (final chunk in _aiService.streamChat(contextPrompt)) {
        if (!mounted) return;

        accumulatedText += chunk;

        setState(() {
          final lastMsg = _messages.last;
          _messages[_messages.length - 1] = lastMsg.copyWith(
            content: accumulatedText,
          );
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        final lastMsg = _messages.last;
        _messages[_messages.length - 1] = lastMsg.copyWith(
          content: "Connection Error. Please try again.",
        );
      });
    }

    if (mounted) {
      setState(() {
        final lastMsg = _messages.last;
        _messages[_messages.length - 1] = lastMsg.copyWith(isStreaming: false);
        _isTyping = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(_currentMode.icon, color: _currentMode.color),
            const SizedBox(width: 8),
            PopupMenuButton<AiMode>(
              initialValue: _currentMode,
              onSelected: (mode) {
                setState(() {
                  _currentMode = mode;
                  _messages.add(
                    AiMessage(
                      content: "Switched to ${mode.label} mode.",
                      isUser: false,
                    ),
                  );
                });
              },
              child: Row(
                children: [
                  Text(
                    _currentMode.label,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
              itemBuilder: (context) => AiMode.values.map((mode) {
                return PopupMenuItem(
                  value: mode,
                  child: Row(
                    children: [
                      Icon(mode.icon, color: mode.color, size: 20),
                      const SizedBox(width: 8),
                      Text(mode.label),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _messages = [_messages.first];
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: msg.isUser ? _currentMode.color : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: msg.isUser
                            ? const Radius.circular(20)
                            : Radius.zero,
                        bottomRight: msg.isUser
                            ? Radius.zero
                            : const Radius.circular(20),
                      ),
                      boxShadow: [
                        if (!msg.isUser)
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                      ],
                      border: !msg.isUser
                          ? Border.all(color: Colors.grey.shade100)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!msg.isUser) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _currentMode.icon,
                                size: 14,
                                color: _currentMode.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _currentMode.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _currentMode.color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        msg.isUser
                            ? Text(
                                msg.content,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              )
                            : MarkdownBody(data: msg.content),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isTyping && !_messages.last.isStreaming && _messages.last.isUser)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "AI is thinking...",
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: InputDecoration(
                        hintText: 'Ask your ${_currentMode.label}...',
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    onPressed: _sendMessage,
                    backgroundColor: _currentMode.color,
                    elevation: 0,
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
