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
  general('General', Icons.auto_awesome, Color(0xFF8E44AD)),
  academic('Academic Advisor', Icons.school, Color(0xFFE67E22)),
  guide('Campus Guide', Icons.map, Color(0xFF27AE60)),
  buddy('Study Buddy', Icons.people, Color(0xFF3498DB));

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
      String accumulatedText = "";

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF000000)
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _currentMode.color,
                    _currentMode.color.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_currentMode.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ],
              ),
              itemBuilder: (context) => AiMode.values.map((mode) {
                return PopupMenuItem(
                  value: mode,
                  child: Row(
                    children: [
                      Icon(mode.icon, color: mode.color, size: 20),
                      const SizedBox(width: 12),
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
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              setState(() {
                _messages = [_messages.first];
              });
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDark ? Colors.grey[900] : Colors.grey[200],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _MessageBubble(
                  message: msg,
                  mode: _currentMode,
                  isDark: isDark,
                );
              },
            ),
          ),

          if (_isTyping && !_messages.last.isStreaming && _messages.last.isUser)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _currentMode.color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "AI is thinking...",
                    style: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          // Input Area
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF000000) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey[900]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.grey[800]!
                              : Colors.transparent,
                        ),
                      ),
                      child: TextField(
                        controller: _inputController,
                        maxLines: null,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ask ${_currentMode.label}...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey[600] : Colors.grey[500],
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _currentMode.color,
                          _currentMode.color.withOpacity(0.8),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(
                        Icons.arrow_upward,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
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

class _MessageBubble extends StatelessWidget {
  final AiMessage message;
  final AiMode mode;
  final bool isDark;

  const _MessageBubble({
    required this.message,
    required this.mode,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [mode.color, mode.color.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(mode.icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? (isDark ? Colors.grey[850] : Colors.grey[200])
                    : (isDark ? Colors.grey[900] : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: !message.isUser
                    ? Border.all(
                        color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                      )
                    : null,
              ),
              child: message.isUser
                  ? Text(
                      message.content,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    )
                  : MarkdownBody(
                      data: message.content.isEmpty ? "..." : message.content,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.black87,
                          fontSize: 15,
                          height: 1.4,
                        ),
                        h1: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        code: TextStyle(
                          backgroundColor: isDark
                              ? Colors.grey[800]
                              : Colors.grey[100],
                          color: mode.color,
                          fontFamily: 'monospace',
                        ),
                        listBullet: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                        ),
                      ),
                    ),
            ),
          ),
          if (message.isUser) const SizedBox(width: 12),
        ],
      ),
    );
  }
}
