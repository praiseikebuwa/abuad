import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';

class ChatSettingsScreen extends ConsumerStatefulWidget {
  final String? channelId;
  const ChatSettingsScreen({super.key, this.channelId});

  @override
  ConsumerState<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends ConsumerState<ChatSettingsScreen> {
  String? _wallpaperPath;
  String _selectedTheme = 'Teal';
  double _wallpaperDim = 0.3;
  bool _useCustomForChat = false;

  // Chat Preferences
  bool _enterIsSend = false;
  bool _readReceipts = true;
  bool _typingStatus = true;
  String _mediaAutoDownload = 'Wi-Fi & Cellular';
  String _fontSize = 'Medium';

  // Story Preferences
  String _storyPrivacy = 'Everyone';
  String _storyDuration = '24 Hours';
  bool _storyAutoSave = false;
  bool _storyAllowReplies = true;
  bool _storyAllowReactions = true;

  final _picker = ImagePicker();

  bool get _isGlobal => widget.channelId == null || widget.channelId == 'global' || widget.channelId!.isEmpty;

  final List<Map<String, dynamic>> _themes = [
    {'name': 'Teal', 'color': AppColors.secondaryTeal},
    {'name': 'Blue', 'color': const Color(0xFF3B82F6)},
    {'name': 'Purple', 'color': const Color(0xFF8B5CF6)},
    {'name': 'Gold', 'color': const Color(0xFFF59E0B)},
    {'name': 'Rose', 'color': const Color(0xFFEC4899)},
    {'name': 'Emerald', 'color': const Color(0xFF10B981)},
  ];

  final List<Map<String, dynamic>> _presets = [
    {'id': 'preset_default', 'name': 'Default', 'color1': Color(0xFF0F172A), 'color2': Color(0xFF1E293B)},
    {'id': 'preset_obsidian', 'name': 'Obsidian', 'color1': Color(0xFF050505), 'color2': Color(0xFF1A1A24)},
    {'id': 'preset_aurora', 'name': 'Aurora', 'color1': Color(0xFF1E1B4B), 'color2': Color(0xFF4C1D95)},
    {'id': 'preset_teal', 'name': 'Teal Glow', 'color1': Color(0xFF064E3B), 'color2': Color(0xFF022C22)},
    {'id': 'preset_sunset', 'name': 'Sunset', 'color1': Color(0xFF4C0519), 'color2': Color(0xFF831843)},
    {'id': 'preset_emerald', 'name': 'Emerald', 'color1': Color(0xFF022C22), 'color2': Color(0xFF065F46)},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_isGlobal) {
        _wallpaperPath = prefs.getString('global_chat_wallpaper');
        _selectedTheme = prefs.getString('global_chat_theme') ?? 'Teal';
      } else {
        final channelWallpaper = prefs.getString('chat_wallpaper_${widget.channelId}');
        _useCustomForChat = channelWallpaper != null;
        _wallpaperPath = channelWallpaper ?? prefs.getString('global_chat_wallpaper');
        _selectedTheme = prefs.getString('chat_theme_${widget.channelId}') ??
            prefs.getString('global_chat_theme') ??
            'Teal';
      }

      _wallpaperDim = prefs.getDouble('chat_wallpaper_dim') ?? 0.3;
      _enterIsSend = prefs.getBool('chat_enter_is_send') ?? false;
      _readReceipts = prefs.getBool('chat_read_receipts') ?? true;
      _typingStatus = prefs.getBool('chat_typing_status') ?? true;
      _mediaAutoDownload = prefs.getString('chat_auto_download') ?? 'Wi-Fi & Cellular';
      _fontSize = prefs.getString('chat_font_size') ?? 'Medium';

      // Story settings
      _storyPrivacy = prefs.getString('story_privacy') ?? 'Everyone';
      _storyDuration = prefs.getString('story_duration') ?? '24 Hours';
      _storyAutoSave = prefs.getBool('story_auto_save') ?? false;
      _storyAllowReplies = prefs.getBool('story_allow_replies') ?? true;
      _storyAllowReactions = prefs.getBool('story_allow_reactions') ?? true;
    });
  }

  Future<void> _saveSettingString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _saveSettingBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _pickWallpaper() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image != null) {
      final prefs = await SharedPreferences.getInstance();
      if (_isGlobal) {
        await prefs.setString('global_chat_wallpaper', image.path);
      } else {
        await prefs.setString('chat_wallpaper_${widget.channelId}', image.path);
        setState(() => _useCustomForChat = true);
      }
      setState(() {
        _wallpaperPath = image.path;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat wallpaper updated!')),
        );
      }
    }
  }

  Future<void> _selectPresetWallpaper(String presetId) async {
    final prefs = await SharedPreferences.getInstance();
    if (_isGlobal) {
      await prefs.setString('global_chat_wallpaper', presetId);
    } else {
      await prefs.setString('chat_wallpaper_${widget.channelId}', presetId);
      setState(() => _useCustomForChat = true);
    }
    setState(() {
      _wallpaperPath = presetId;
    });
  }

  Future<void> _resetWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isGlobal) {
      await prefs.remove('global_chat_wallpaper');
    } else {
      await prefs.remove('chat_wallpaper_${widget.channelId}');
      setState(() => _useCustomForChat = false);
    }
    setState(() {
      _wallpaperPath = _isGlobal ? null : prefs.getString('global_chat_wallpaper');
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isGlobal ? 'Reset to default background' : 'Using global wallpaper')),
      );
    }
  }

  Future<void> _setTheme(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    if (_isGlobal) {
      await prefs.setString('global_chat_theme', themeName);
    } else {
      await prefs.setString('chat_theme_${widget.channelId}', themeName);
    }
    setState(() {
      _selectedTheme = themeName;
    });
  }

  Color _getThemeColor(String name) {
    final found = _themes.firstWhere((t) => t['name'] == name, orElse: () => _themes[0]);
    return found['color'] as Color;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColor = _getThemeColor(_selectedTheme);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _isGlobal ? 'Chat & Story Settings' : 'Chat Customization',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                (isDark ? Colors.black : Colors.black).withValues(alpha: 0.6),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF0F172A), Colors.black]
                      : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                ),
              ),
            ),
          ),

          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // Live Chat Preview Header Card
                _buildLivePreviewCard(themeColor, isDark),
                const SizedBox(height: 24),

                // Wallpapers & Backgrounds Section
                _buildSectionHeader('WALLPAPER & BACKGROUND', Icons.wallpaper),
                const SizedBox(height: 10),
                _buildGlassCard(
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isGlobal)
                        SwitchListTile.adaptive(
                          title: const Text('Custom Wallpaper for this Chat', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(
                            _useCustomForChat ? 'Override global wallpaper' : 'Using app global wallpaper',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                          value: _useCustomForChat,
                          activeTrackColor: themeColor,
                          onChanged: (val) {
                            if (!val) {
                              _resetWallpaper();
                            } else {
                              setState(() => _useCustomForChat = true);
                            }
                          },
                        ),
                      
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Text(
                          'Preset Wallpapers',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: themeColor),
                        ),
                      ),
                      
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: _presets.length + 1,
                          separatorBuilder: (context, subIndex) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              // Custom image picker item
                              return GestureDetector(
                                onTap: _pickWallpaper,
                                child: Column(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: themeColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: themeColor, width: 1.5),
                                      ),
                                      child: Icon(Icons.add_a_photo_outlined, color: themeColor, size: 26),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text('Gallery', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              );
                            }
                            
                            final preset = _presets[index - 1];
                            final isSelected = _wallpaperPath == preset['id'];
                            return GestureDetector(
                              onTap: () => _selectPresetWallpaper(preset['id'] as String),
                              child: Column(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [preset['color1'] as Color, preset['color2'] as Color],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected ? Colors.white : Colors.transparent,
                                        width: 2.5,
                                      ),
                                      boxShadow: isSelected
                                          ? [BoxShadow(color: themeColor.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1)]
                                          : [],
                                    ),
                                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 22) : null,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(preset['name'] as String, style: const TextStyle(fontSize: 11)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      if (_wallpaperPath != null) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Divider(height: 24),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const Text('Background Dimming', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              Expanded(
                                child: Slider(
                                  value: _wallpaperDim,
                                  min: 0.0,
                                  max: 0.8,
                                  activeColor: themeColor,
                                  onChanged: (val) {
                                    setState(() => _wallpaperDim = val);
                                    SharedPreferences.getInstance().then((prefs) => prefs.setDouble('chat_wallpaper_dim', val));
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        Center(
                          child: TextButton.icon(
                            onPressed: _resetWallpaper,
                            icon: const Icon(Icons.restart_alt, size: 16, color: Colors.redAccent),
                            label: const Text('Reset Wallpaper', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Theme Color Section
                _buildSectionHeader('CHAT THEME ACCENT', Icons.palette_outlined),
                const SizedBox(height: 10),
                _buildGlassCard(
                  isDark: isDark,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: _themes.map((themeItem) {
                        final isSelected = _selectedTheme == themeItem['name'];
                        final color = themeItem['color'] as Color;
                        return GestureDetector(
                          onTap: () => _setTheme(themeItem['name'] as String),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : [],
                            ),
                            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Chat Preferences Section
                _buildSectionHeader('CHAT PREFERENCES', Icons.tune),
                const SizedBox(height: 10),
                _buildGlassCard(
                  isDark: isDark,
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        title: const Text('Enter Key to Send', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Press Enter on physical or soft keyboard to send message', style: TextStyle(fontSize: 12)),
                        value: _enterIsSend,
                        activeTrackColor: themeColor,
                        onChanged: (val) {
                          setState(() => _enterIsSend = val);
                          _saveSettingBool('chat_enter_is_send', val);
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile.adaptive(
                        title: const Text('Read Receipts', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Allow others to see when you have read their messages', style: TextStyle(fontSize: 12)),
                        value: _readReceipts,
                        activeTrackColor: themeColor,
                        onChanged: (val) {
                          setState(() => _readReceipts = val);
                          _saveSettingBool('chat_read_receipts', val);
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile.adaptive(
                        title: const Text('Typing Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Show typing indicator when composing a message', style: TextStyle(fontSize: 12)),
                        value: _typingStatus,
                        activeTrackColor: themeColor,
                        onChanged: (val) {
                          setState(() => _typingStatus = val);
                          _saveSettingBool('chat_typing_status', val);
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        title: const Text('Media Auto-Download', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(_mediaAutoDownload, style: TextStyle(fontSize: 12, color: themeColor)),
                        trailing: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _mediaAutoDownload,
                            icon: const Icon(Icons.arrow_drop_down),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _mediaAutoDownload = val);
                                _saveSettingString('chat_auto_download', val);
                              }
                            },
                            items: ['Wi-Fi & Cellular', 'Wi-Fi Only', 'Never']
                                .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                                .toList(),
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        title: const Text('Chat Text Size', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(_fontSize, style: TextStyle(fontSize: 12, color: themeColor)),
                        trailing: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _fontSize,
                            icon: const Icon(Icons.arrow_drop_down),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _fontSize = val);
                                _saveSettingString('chat_font_size', val);
                              }
                            },
                            items: ['Small', 'Medium', 'Large']
                                .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Story Settings Section
                _buildSectionHeader('STORIES & STATUS SETTINGS', Icons.auto_awesome),
                const SizedBox(height: 10),
                _buildGlassCard(
                  isDark: isDark,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.lock_outline, color: themeColor, size: 20),
                        ),
                        title: const Text('Story Audience Privacy', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text('Who can view your stories: $_storyPrivacy', style: const TextStyle(fontSize: 12)),
                        trailing: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _storyPrivacy,
                            icon: const Icon(Icons.arrow_drop_down),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _storyPrivacy = val);
                                _saveSettingString('story_privacy', val);
                              }
                            },
                            items: ['Everyone', 'Connections Only', 'Only Me']
                                .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                                .toList(),
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.timer_outlined, color: themeColor, size: 20),
                        ),
                        title: const Text('Story Expiry Duration', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text('Stories automatically disappear after $_storyDuration', style: const TextStyle(fontSize: 12)),
                        trailing: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _storyDuration,
                            icon: const Icon(Icons.arrow_drop_down),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _storyDuration = val);
                                _saveSettingString('story_duration', val);
                              }
                            },
                            items: ['12 Hours', '24 Hours', '48 Hours']
                                .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                                .toList(),
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile.adaptive(
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.download_outlined, color: themeColor, size: 20),
                        ),
                        title: const Text('Save Stories to Gallery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Automatically save photo/video stories you post to your phone gallery', style: TextStyle(fontSize: 12)),
                        value: _storyAutoSave,
                        activeTrackColor: themeColor,
                        onChanged: (val) {
                          setState(() => _storyAutoSave = val);
                          _saveSettingBool('story_auto_save', val);
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile.adaptive(
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.reply_outlined, color: themeColor, size: 20),
                        ),
                        title: const Text('Allow Story Direct Replies', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Allow viewers to send DM responses to your posted stories', style: TextStyle(fontSize: 12)),
                        value: _storyAllowReplies,
                        activeTrackColor: themeColor,
                        onChanged: (val) {
                          setState(() => _storyAllowReplies = val);
                          _saveSettingBool('story_allow_replies', val);
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile.adaptive(
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.favorite_border, color: themeColor, size: 20),
                        ),
                        title: const Text('Allow Quick Emoji Reactions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Allow viewers to send fast reaction emojis to your story', style: TextStyle(fontSize: 12)),
                        value: _storyAllowReactions,
                        activeTrackColor: themeColor,
                        onChanged: (val) {
                          setState(() => _storyAllowReactions = val);
                          _saveSettingBool('story_allow_reactions', val);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Features & Guides Section
                _buildSectionHeader('GUIDES & HELP', Icons.help_outline),
                const SizedBox(height: 10),
                _buildGlassCard(
                  isDark: isDark,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.auto_awesome, color: themeColor, size: 20),
                        ),
                        title: const Text('Using Disappearing Snaps', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Learn how to send view-once photo snaps in chat', style: TextStyle(fontSize: 12)),
                        onTap: () => _showGuide(
                          'Disappearing Snaps',
                          'To send a view-once snap photo, open any chat, tap the Camera icon in attachments, and select Snap mode before sending!',
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.mic, color: themeColor, size: 20),
                        ),
                        title: const Text('Voice Notes & Recording', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Tips for crystal-clear voice messages and hands-free recording', style: TextStyle(fontSize: 12)),
                        onTap: () => _showGuide(
                          'Voice Notes',
                          'Press and hold the microphone button to record. Swipe up to lock continuous recording mode or swipe left to cancel recording.',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreviewCard(Color themeColor, bool isDark) {
    BoxDecoration bgDecoration;
    if (_wallpaperPath != null && _wallpaperPath!.startsWith('preset_')) {
      final preset = _presets.firstWhere(
        (p) => p['id'] == _wallpaperPath,
        orElse: () => _presets[0],
      );
      bgDecoration = BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [preset['color1'] as Color, preset['color2'] as Color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );
    } else if (_wallpaperPath != null) {
      if (kIsWeb) {
        bgDecoration = BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: DecorationImage(
            image: NetworkImage(_wallpaperPath!),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: _wallpaperDim),
              BlendMode.darken,
            ),
          ),
        );
      } else if (File(_wallpaperPath!).existsSync()) {
        bgDecoration = BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: DecorationImage(
            image: FileImage(File(_wallpaperPath!)),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: _wallpaperDim),
              BlendMode.darken,
            ),
          ),
        );
      } else {
        bgDecoration = BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? Colors.black : const Color(0xFFF1F5F9),
        );
      }
    } else {
      bgDecoration = BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0F172A), Colors.black]
              : [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: themeColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 180,
          decoration: bgDecoration,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.remove_red_eye_outlined, color: themeColor, size: 14),
                        const SizedBox(width: 6),
                        const Text('Live Chat Preview', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _isGlobal ? 'Global Theme' : 'Custom Chat Theme',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                  ),
                ],
              ),
              const Spacer(),
              // Received bubble sample
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.85),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Hey there! How does this new theme look? ✨',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Sent bubble sample
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: themeColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Looks amazing! Background & colors match perfectly 🎨',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().scale(duration: 300.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.secondaryTeal),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AppColors.secondaryTeal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, required bool isDark}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: child,
          ),
        ),
      ),
    );
  }

  void _showGuide(String title, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Text(
                content,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Got it!', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
