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
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

enum _AttachOption { camera, photos, files }

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
  PlatformFile? _selectedDocFile;
  String? _docFileContent;

  bool _isExpandedView = false;
  bool _isRecordingVoice = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  final _audioRecorder = AudioRecorder();
  bool _stopRequested = false;

  final _aiService = AiService();
  final _storage = FirebaseStorageService();

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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
      _selectedDocFile = null;
      _docFileContent = null;
      _isExpandedView = false;
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
      _selectedDocFile = null;
      _docFileContent = null;
      _isExpandedView = false;
    });
    _scrollToBottom();
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _selectedImageFile = picked;
        _selectedDocFile = null;
        _docFileContent = null;
      });
    }
  }

  Future<void> _pickFromGallery() async {
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
        _selectedDocFile = null;
        _docFileContent = null;
      });
    }
  }

  Future<void> _pickDocumentFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'csv', 'md'],
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        String? content;
        if (!kIsWeb &&
            file.path != null &&
            (file.extension == 'txt' ||
                file.extension == 'csv' ||
                file.extension == 'md')) {
          try {
            content = await File(file.path!).readAsString();
          } catch (_) {}
        }
        setState(() {
          _selectedDocFile = file;
          _docFileContent = content;
          _selectedImageFile = null;
        });
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
    }
  }

  Future<void> _showAttachOptions(BuildContext context) async {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final action = await showModalBottomSheet<_AttachOption>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E7EB),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              _buildAttachMenuItem(
                icon: Icons.camera_alt_outlined,
                title: 'Camera',
                subtitle: 'Take a photo or scan notes',
                isDark: isDark,
                onTap: () => Navigator.pop(context, _AttachOption.camera),
              ),
              Divider(
                height: 1,
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F5F9),
              ),
              _buildAttachMenuItem(
                icon: Icons.photo_library_outlined,
                title: 'Photos',
                subtitle: 'Upload images from gallery',
                isDark: isDark,
                onTap: () => Navigator.pop(context, _AttachOption.photos),
              ),
              Divider(
                height: 1,
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F5F9),
              ),
              _buildAttachMenuItem(
                icon: Icons.attach_file_rounded,
                title: 'Files',
                subtitle: 'Attach documents (PDF, DOCX, TXT)',
                isDark: isDark,
                onTap: () => Navigator.pop(context, _AttachOption.files),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (action == null) return;

    switch (action) {
      case _AttachOption.camera:
        _pickFromCamera();
        break;
      case _AttachOption.photos:
        _pickFromGallery();
        break;
      case _AttachOption.files:
        _pickDocumentFile();
        break;
    }
  }

  Widget _buildAttachMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleVoiceInput() async {
    HapticFeedback.mediumImpact();
    if (_isRecordingVoice) {
      await _stopVoiceRecording(sendImmediately: true);
    } else {
      await _startVoiceRecording();
    }
  }

  Future<void> _startVoiceRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission required')),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/ai_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      setState(() {
        _isRecordingVoice = true;
        _recordingSeconds = 0;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _isRecordingVoice) {
          setState(() {
            _recordingSeconds++;
          });
        }
      });
    } catch (e) {
      debugPrint('Voice recording start error: $e');
    }
  }

  Future<void> _stopVoiceRecording({bool sendImmediately = false}) async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();
      final duration = _recordingSeconds;

      setState(() {
        _isRecordingVoice = false;
        _recordingSeconds = 0;
      });

      if (sendImmediately && path != null && duration > 0) {
        final promptText = _inputController.text.trim();
        final voiceNoteText = promptText.isNotEmpty
            ? '$promptText (Voice input attached, ${duration}s)'
            : 'Voice question ($duration seconds recording)';
        _sendMessage(overridePrompt: voiceNoteText);
      }
    } catch (e) {
      debugPrint('Voice recording stop error: $e');
    }
  }

  void _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    setState(() {
      _isRecordingVoice = false;
      _recordingSeconds = 0;
    });
  }

  Future<void> _sendMessage({String? overridePrompt}) async {
    String text = (overridePrompt ?? _inputController.text).trim();
    if (text.isEmpty && _selectedImageFile == null && _selectedDocFile == null) return;

    if (text.isEmpty && _selectedImageFile != null) {
      text = "What is in this image?";
    } else if (text.isEmpty && _selectedDocFile != null) {
      text = "Summarize and explain the key points of this document: ${_selectedDocFile!.name}";
    }

    if (_selectedDocFile != null && _docFileContent != null && _docFileContent!.isNotEmpty) {
      text = "$text\n\n--- Document Content (${_selectedDocFile!.name}) ---\n$_docFileContent";
    }

    if (overridePrompt == null) {
      _inputController.clear();
    }

    String? imageUrl;
    final imageToUpload = _selectedImageFile;

    setState(() {
      _selectedImageFile = null;
      _selectedDocFile = null;
      _docFileContent = null;
      _isExpandedView = false;
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

      _stopRequested = false;
      await for (final chunk in _aiService.streamChat(
        text,
        imageUrl: imageUrl,
        systemPrompt: systemPrompt,
      )) {
        if (!mounted || _stopRequested) break;

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

          // Attachment preview chip (if any)
          _buildAttachmentPreview(isDark),

          // Quick Suggestion Chips (Features AI requested)
          if (!_isRecordingVoice && !_isTyping)
            _buildQuickSuggestionChips(isDark),

          // ChatGPT-Style Unified Input Area
          Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F0F0F) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF1F5F9),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: _isRecordingVoice
                  ? _buildVoiceRecordingBar(isDark)
                  : _buildChatGptInputContainer(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestionChips(bool isDark) {
    final suggestions = [
      (
        icon: Icons.explore_rounded,
        label: 'Campus Navigator',
        color: const Color(0xFF6366F1),
        action: () {
          _sendMessage(
            overridePrompt:
                'Can you guide me around ABUAD campus? Show me the colleges, AMSH hospital, and best study spots.',
          );
        },
      ),
      (
        icon: Icons.school_rounded,
        label: 'Calculate CGPA',
        color: const Color(0xFF0D9488),
        action: () {
          _sendMessage(
            overridePrompt:
                'How is CGPA calculated at ABUAD? What are the grade point scales and First Class cutoff?',
          );
        },
      ),
      (
        icon: Icons.upload_file_rounded,
        label: 'Handout / Handbook Q&A',
        color: const Color(0xFFF59E0B),
        action: () {
          _pickDocumentFile();
        },
      ),
      (
        icon: Icons.restaurant_rounded,
        label: 'Cafeteria & Buka',
        color: const Color(0xFFEC4899),
        action: () {
          _sendMessage(
            overridePrompt:
                'What cafeteria and buka food spots are available on ABUAD campus and what do they serve?',
          );
        },
      ),
      (
        icon: Icons.build_circle_rounded,
        label: 'Hostel Maintenance',
        color: const Color(0xFF3B82F6),
        action: () {
          _sendMessage(
            overridePrompt:
                'How do I log a hostel maintenance or room repair request for electrical or plumbing issues?',
          );
        },
      ),
      (
        icon: Icons.gavel_rounded,
        label: 'Handbook & Rules',
        color: const Color(0xFF8B5CF6),
        action: () {
          _sendMessage(
            overridePrompt:
                'What are the key rules in the ABUAD student handbook regarding dress code and hostel curfew?',
          );
        },
      ),
    ];

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final s = suggestions[index];
          return ActionChip(
            avatar: Icon(s.icon, size: 16, color: s.color),
            label: Text(
              s.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            backgroundColor:
                isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF1F5F9),
            side: BorderSide(
              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE2E8F0),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            onPressed: () {
              HapticFeedback.lightImpact();
              s.action();
            },
          );
        },
      ),
    );
  }

  Widget _buildAttachmentPreview(bool isDark) {
    if (_selectedImageFile == null && _selectedDocFile == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: _selectedDocFile != null
                  ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
                  : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF262626) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
                ),
              ),
              child: _selectedImageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb
                          ? Image.network(
                              _selectedImageFile!.path,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(_selectedImageFile!.path),
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.description_rounded,
                          size: 24,
                          color: Color(0xFF3B82F6),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(
                            _selectedDocFile!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedImageFile = null;
                    _selectedDocFile = null;
                    _docFileContent = null;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.close,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceRecordingBar(bool isDark) {
    final minutes = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$minutes:$seconds',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Listening... Speak your prompt',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
            tooltip: 'Cancel',
            onPressed: _cancelVoiceRecording,
          ),
          GestureDetector(
            onTap: () => _stopVoiceRecording(sendImmediately: true),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _currentMode.color,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_upward_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton(bool isDark) {
    final hasContent = _inputController.text.trim().isNotEmpty ||
        _selectedImageFile != null ||
        _selectedDocFile != null;

    final isActive = hasContent || _isTyping;
    final buttonColor = _isTyping
        ? Colors.redAccent
        : (isActive
            ? _currentMode.color
            : (isDark ? const Color(0xFF2E2E30) : const Color(0xFFE2E8F0)));
    final iconColor = isActive
        ? Colors.white
        : (isDark ? Colors.grey[600] : Colors.grey[400]);

    return GestureDetector(
      onTap: () {
        if (_isTyping) {
          HapticFeedback.mediumImpact();
          setState(() => _stopRequested = true);
        } else if (hasContent) {
          HapticFeedback.lightImpact();
          _sendMessage();
        }
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: buttonColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            _isTyping ? Icons.stop_rounded : Icons.arrow_upward_rounded,
            size: 20,
            color: iconColor,
          ),
        ),
      ),
    );
  }

  Widget _buildChatGptInputContainer(bool isDark) {
    final text = _inputController.text;
    final isCardMode = _isExpandedView || text.contains('\n') || text.length > 85;

    final containerBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF4F4F5);
    final borderColor = isDark ? const Color(0xFF2F2F2F) : const Color(0xFFE4E4E7);

    if (isCardMode) {
      // Multiline Card Mode (Images 3 & 4)
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: containerBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor, width: 1),
        ),
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top action bar with Expand/Collapse button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isExpandedView = !_isExpandedView;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, right: 4),
                    child: Icon(
                      _isExpandedView
                          ? Icons.close_fullscreen_rounded
                          : Icons.open_in_full_rounded,
                      size: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            // Text area
            TextField(
              controller: _inputController,
              focusNode: _inputFocusNode,
              maxLines: _isExpandedView ? 14 : 6,
              minLines: _isExpandedView ? 7 : 3,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
                height: 1.35,
              ),
              decoration: InputDecoration(
                hintText: 'Ask ${_currentMode.label}...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                  fontSize: 15,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.only(bottom: 8),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            // Bottom Action Row (+ on left, mic + send on right)
            Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(
                    Icons.add,
                    size: 22,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  tooltip: 'Attach options',
                  onPressed: () => _showAttachOptions(context),
                ),
                const Spacer(),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(
                    Icons.mic_none_rounded,
                    size: 22,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  tooltip: 'Voice prompt',
                  onPressed: _toggleVoiceInput,
                ),
                const SizedBox(width: 8),
                _buildSendButton(isDark),
              ],
            ),
          ],
        ),
      );
    }

    // Single-line Pill Mode (Image 5)
    return Container(
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Icon(
              Icons.add,
              size: 22,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            tooltip: 'Attach options',
            onPressed: () => _showAttachOptions(context),
          ),
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocusNode,
              maxLines: 4,
              minLines: 1,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Ask ${_currentMode.label}...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                  fontSize: 15,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Icon(
              Icons.mic_none_rounded,
              size: 22,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            tooltip: 'Voice prompt',
            onPressed: _toggleVoiceInput,
          ),
          const SizedBox(width: 4),
          _buildSendButton(isDark),
          const SizedBox(width: 4),
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
