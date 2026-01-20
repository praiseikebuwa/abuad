import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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

class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});

  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  final _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<AiMessage> _messages = [
    const AiMessage(
      content:
          "Hello! I'm your ABUAD AI Assistant. 🎓\n\nI can help you with:\n- Finding classrooms\n- Exam schedules\n- Campus news\n\nHow can I help you today?",
      isUser: false,
    ),
  ];

  bool _isTyping = false;

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();
    setState(() {
      _messages.add(AiMessage(content: text, isUser: true));
      _isTyping = true;
    });

    _scrollToBottom();

    // Mock AI Response Streaming
    await Future.delayed(
      const Duration(seconds: 1),
    ); // Network delay simulation

    final responseText = _getMockResponse(text);

    // Start streaming response
    setState(() {
      _messages.add(
        const AiMessage(content: "", isUser: false, isStreaming: true),
      );
    });

    for (int i = 0; i < responseText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 30)); // Typing speed
      if (!mounted) return;

      setState(() {
        final lastMsg = _messages.last;
        _messages[_messages.length - 1] = lastMsg.copyWith(
          content: lastMsg.content + responseText[i],
        );
      });
      _scrollToBottom();
    }

    if (mounted) {
      setState(() {
        final lastMsg = _messages.last;
        _messages[_messages.length - 1] = lastMsg.copyWith(isStreaming: false);
        _isTyping = false;
      });
    }
  }

  String _getMockResponse(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('map') ||
        lower.contains('class') ||
        lower.contains('where')) {
      return "You can find campus locations in the Map tab. The College of Engineering is located in the northern sector, while the Law College is closer to the main gate. Would you like me to open the map?";
    } else if (lower.contains('exam') || lower.contains('timetable')) {
      return "The provisional exam timetable for this semester is out. Check the student portal or the Feed for the latest PDF download.";
    } else if (lower.contains('library') || lower.contains('book')) {
      return "The ABUAD Central Library is open from 8:00 AM to 9:00 PM on weekdays. Remember to bring your Student ID!";
    }
    return "That's an interesting question about $input. As an AI, I'm constantly learning about ABUAD activities. Could you be more specific?";
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
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.purple),
            SizedBox(width: 8),
            Text('ABUAD AI'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _messages = [_messages.first]; // Reset
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
                      color: msg.isUser
                          ? const Color(0xFF0D47A1)
                          : Colors.white,
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
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: Colors.purple,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Assistant",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
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
                        hintText: 'Ask anything about campus...',
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
                    backgroundColor: const Color(0xFF0D47A1),
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
