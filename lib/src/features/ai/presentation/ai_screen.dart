import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import '../data/ai_service.dart';
import '../../../core/services/firebase_storage_service.dart';

class AiMessage {
  final String id;
  final String content;
  final bool isUser;
  final bool isStreaming;
  final String? imageUrl;

  AiMessage({
    String? id,
    required this.content,
    required this.isUser,
    this.isStreaming = false,
    this.imageUrl,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  AiMessage copyWith({
    String? content,
    bool? isStreaming,
    String? imageUrl,
  }) {
    return AiMessage(
      id: id,
      content: content ?? this.content,
      isUser: isUser,
      isStreaming: isStreaming ?? this.isStreaming,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'isUser': isUser,
        'imageUrl': imageUrl,
      };

  factory AiMessage.fromJson(Map<String, dynamic> json) => AiMessage(
        id: json['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
        content: json['content'] ?? '',
        isUser: json['isUser'] ?? false,
        imageUrl: json['imageUrl'],
      );
}

class AiChatSession {
  final String id;
  final String title;
  final String mode;
  final DateTime updatedAt;
  final List<AiMessage> messages;

  AiChatSession({
    required this.id,
    required this.title,
    required this.mode,
    required this.updatedAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'mode': mode,
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory AiChatSession.fromJson(Map<String, dynamic> json) {
    return AiChatSession(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? 'AI Chat',
      mode: json['mode'] ?? 'General',
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      messages: (json['messages'] as List? ?? [])
          .map((m) => AiMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
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

  static AiMode fromLabel(String label) {
    return AiMode.values.firstWhere(
      (m) => m.label == label,
      orElse: () => AiMode.general,
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
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  AiMode _currentMode = AiMode.general;

  String _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
  List<AiMessage> _messages = [];

  bool _isTyping = false;
  bool _isUploadingImage = false;
  XFile? _selectedImageFile;

  final _aiService = AiService();
  final _storage = FirebaseStorageService();

  @override
  void initState() {
    super.initState();
    _initDefaultChat();
    _loadHistorySessions();
  }

  void _initDefaultChat() {
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _messages = [
      AiMessage(
        content:
            "Hello! I'm your ABUAD AI Assistant 🎓.\n\nHow can I help you with your studies or campus questions today?",
        isUser: false,
      ),
    ];
  }

  // Auto-Save Chat Session to SharedPreferences
  Future<void> _saveCurrentSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyRaw = prefs.getString('abuad_ai_chat_history');
      List<AiChatSession> sessions = [];
      if (historyRaw != null) {
        final List decoded = jsonDecode(historyRaw);
        sessions = decoded.map((x) => AiChatSession.fromJson(x)).toList();
      }

      // Title derived from first user message or default
      final firstUserMsg = _messages.firstWhere(
        (m) => m.isUser && m.content.trim().isNotEmpty,
        orElse: () => AiMessage(content: 'New Conversation', isUser: true),
      );
      String title = firstUserMsg.content.trim();
      if (title.length > 35) {
        title = '${title.substring(0, 35)}...';
      }

      final updatedSession = AiChatSession(
        id: _currentSessionId,
        title: title.isEmpty ? 'AI Chat' : title,
        mode: _currentMode.label,
        updatedAt: DateTime.now(),
        messages: _messages.where((m) => !m.isStreaming).toList(),
      );

      final existingIndex = sessions.indexWhere((s) => s.id == _currentSessionId);
      if (existingIndex >= 0) {
        sessions[existingIndex] = updatedSession;
      } else {
        sessions.insert(0, updatedSession);
      }

      await prefs.setString(
        'abuad_ai_chat_history',
        jsonEncode(sessions.map((s) => s.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Error saving AI chat session: $e');
    }
  }

  Future<List<AiChatSession>> _loadHistorySessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyRaw = prefs.getString('abuad_ai_chat_history');
      if (historyRaw != null) {
        final List decoded = jsonDecode(historyRaw);
        return decoded.map((x) => AiChatSession.fromJson(x)).toList();
      }
    } catch (e) {
      debugPrint('Error loading AI chat history: $e');
    }
    return [];
  }

  Future<void> _deleteSession(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyRaw = prefs.getString('abuad_ai_chat_history');
      if (historyRaw != null) {
        final List decoded = jsonDecode(historyRaw);
        final sessions = decoded
            .map((x) => AiChatSession.fromJson(x))
            .where((s) => s.id != sessionId)
            .toList();

        await prefs.setString(
          'abuad_ai_chat_history',
          jsonEncode(sessions.map((s) => s.toJson()).toList()),
        );

        if (_currentSessionId == sessionId) {
          setState(() {
            _initDefaultChat();
          });
        }
      }
    } catch (e) {
      debugPrint('Error deleting chat session: $e');
    }
  }

  void _startNewChat() {
    setState(() {
      _selectedImageFile = null;
      _inputController.clear();
      _initDefaultChat();
    });
  }

  void _loadSession(AiChatSession session) {
    setState(() {
      _currentSessionId = session.id;
      _currentMode = AiMode.fromLabel(session.mode);
      _messages = List.from(session.messages);
      _selectedImageFile = null;
    });
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _selectedImageFile = picked;
      });
    }
  }

  Future<void> _sendMessage({String? overridePrompt}) async {
    String text = (overridePrompt ?? _inputController.text).trim();
    if (text.isEmpty && _selectedImageFile == null) return;
    if (text.isEmpty && _selectedImageFile != null) {
      text = "What is in this image?";
    }

    if (overridePrompt == null) {
      _inputController.clear();
    }

    String? imageUrl;
    final imageToUpload = _selectedImageFile;

    setState(() {
      _selectedImageFile = null;
      if (imageToUpload != null) {
        _isUploadingImage = true;
      }
    });

    if (imageToUpload != null) {
      try {
        imageUrl = await _storage.uploadImage(
          imageToUpload,
          path: 'ai_uploads/$_currentSessionId/',
        );
      } catch (e) {
        debugPrint('Image upload error: $e');
      } finally {
        if (mounted) setState(() => _isUploadingImage = false);
      }
    }

    final userMessage = AiMessage(
      content: text,
      isUser: true,
      imageUrl: imageUrl,
    );

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
      _messages.add(
        AiMessage(content: "", isUser: false, isStreaming: true),
      );
    });

    _scrollToBottom();
    await _saveCurrentSession();

    try {
      String accumulatedText = "";
      final systemPrompt = AiService.getSystemPrompt(_currentMode.label);

      await for (final chunk in _aiService.streamChat(
        text,
        imageUrl: imageUrl,
        systemPrompt: systemPrompt,
      )) {
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
      if (mounted) {
        setState(() {
          final lastMsg = _messages.last;
          _messages[_messages.length - 1] = lastMsg.copyWith(
            content: "Connection error. Please try again.",
          );
        });
      }
    }

    if (mounted) {
      setState(() {
        final lastMsg = _messages.last;
        _messages[_messages.length - 1] = lastMsg.copyWith(isStreaming: false);
        _isTyping = false;
      });
      await _saveCurrentSession();
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

  void _editPrompt(String promptText) {
    _inputController.text = promptText;
    _inputFocusNode.requestFocus();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('$label copied to clipboard!'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.black87,
      ),
    );
  }

  void _showHistorySheet() async {
    final history = await _loadHistorySessions();
    if (!mounted) return;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.history_rounded,
                              color: _currentMode.color,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Chat History",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _startNewChat();
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text("New Chat"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentMode.color,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Expanded(
                      child: history.isEmpty
                          ? Center(
                              child: Text(
                                "No saved conversations yet",
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[600],
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: history.length,
                              itemBuilder: (context, index) {
                                final session = history[index];
                                final isSelected =
                                    session.id == _currentSessionId;
                                final modeObj =
                                    AiMode.fromLabel(session.mode);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? _currentMode.color
                                            .withValues(alpha: 0.15)
                                        : (isDark
                                            ? Colors.grey[900]
                                            : Colors.grey[100]),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? _currentMode.color
                                          : (isDark
                                              ? Colors.grey[800]!
                                              : Colors.grey[200]!),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: ListTile(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      leading: CircleAvatar(
                                        backgroundColor: modeObj.color
                                            .withValues(alpha: 0.2),
                                        child: Icon(
                                          modeObj.icon,
                                          color: modeObj.color,
                                          size: 18,
                                        ),
                                      ),
                                      title: Text(
                                        session.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${session.mode} • ${timeago.format(session.updatedAt)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () async {
                                          await _deleteSession(session.id);
                                          setSheetState(() {
                                            history.removeAt(index);
                                          });
                                        },
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _loadSession(session);
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8F9FA),
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
                    _currentMode.color.withValues(alpha: 0.7),
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
              Icons.history_rounded,
              color: isDark ? Colors.white : Colors.black87,
            ),
            tooltip: "Chat History",
            onPressed: _showHistorySheet,
          ),
          IconButton(
            icon: Icon(
              Icons.add_circle_outline,
              color: isDark ? Colors.white : Colors.black87,
            ),
            tooltip: "New Chat",
            onPressed: _startNewChat,
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
                  onEditPrompt: msg.isUser ? () => _editPrompt(msg.content) : null,
                  onCopyMessage: () => _copyToClipboard(
                    msg.content,
                    msg.isUser ? "Prompt" : "Response",
                  ),
                  onRegenerate: (!msg.isUser && index > 0)
                      ? () {
                          final prevUserMsg = _messages
                              .sublist(0, index)
                              .lastWhere((m) => m.isUser, orElse: () => _messages.first);
                          _sendMessage(overridePrompt: prevUserMsg.content);
                        }
                      : null,
                );
              },
            ),
          ),

          if (_isUploadingImage)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Uploading image...",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
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

          // Selected Image Attachment Bar
          if (_selectedImageFile != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? Colors.grey[950] : Colors.grey[100],
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.network(
                            _selectedImageFile!.path,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(_selectedImageFile!.path),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedImageFile!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _selectedImageFile = null;
                      });
                    },
                  ),
                ],
              ),
            ),

          // Input Area
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
                  // Attachment Icon Button
                  IconButton(
                    icon: Icon(
                      Icons.image_outlined,
                      color: _selectedImageFile != null
                          ? _currentMode.color
                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    onPressed: _pickImage,
                    tooltip: "Attach Image",
                  ),
                  const SizedBox(width: 4),
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
                        focusNode: _inputFocusNode,
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
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _currentMode.color,
                          _currentMode.color.withValues(alpha: 0.8),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => _sendMessage(),
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
  final VoidCallback? onEditPrompt;
  final VoidCallback? onCopyMessage;
  final VoidCallback? onRegenerate;

  const _MessageBubble({
    required this.message,
    required this.mode,
    required this.isDark,
    this.onEditPrompt,
    this.onCopyMessage,
    this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: message.isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
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
                      colors: [mode.color, mode.color.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(mode.icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? (isDark ? Colors.grey[850] : Colors.grey[200])
                        : (isDark ? Colors.grey[900] : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: !message.isUser
                        ? Border.all(
                            color: isDark
                                ? Colors.grey[800]!
                                : Colors.grey[200]!,
                          )
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.imageUrl != null &&
                          message.imageUrl!.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: message.imageUrl!,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                height: 120,
                                color: isDark ? Colors.grey[800] : Colors.grey[300],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      message.isUser
                          ? Text(
                              message.content,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            )
                          : MarkdownBody(
                              data: message.content.isEmpty
                                  ? "..."
                                  : message.content,
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
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[700],
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
              if (message.isUser) const SizedBox(width: 12),
            ],
          ),
          // Action Buttons Bar below Message Bubble
          if (!message.isStreaming && message.content.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: message.isUser ? 0 : 44, right: message.isUser ? 8 : 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isUser && onEditPrompt != null) ...[
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                      tooltip: "Edit Prompt",
                      onPressed: onEditPrompt,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                  if (onCopyMessage != null) ...[
                    IconButton(
                      icon: Icon(
                        Icons.content_copy_outlined,
                        size: 16,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                      tooltip: "Copy Text",
                      onPressed: onCopyMessage,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                  if (!message.isUser && onRegenerate != null) ...[
                    IconButton(
                      icon: Icon(
                        Icons.refresh_rounded,
                        size: 16,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                      tooltip: "Regenerate Response",
                      onPressed: onRegenerate,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
