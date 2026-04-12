import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';

class ChatSettingsScreen extends ConsumerStatefulWidget {
  final String channelId;
  const ChatSettingsScreen({super.key, required this.channelId});

  @override
  ConsumerState<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends ConsumerState<ChatSettingsScreen> {
  String? _wallpaperPath;
  String _selectedTheme = 'Teal';
  final _picker = ImagePicker();

  final List<Map<String, dynamic>> _themes = [
    {'name': 'Teal', 'color': AppColors.secondaryTeal},
    {'name': 'Blue', 'color': Colors.blue},
    {'name': 'Purple', 'color': Colors.purple},
    {'name': 'Gold', 'color': const Color(0xFFFFD700)},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _wallpaperPath = prefs.getString('chat_wallpaper_${widget.channelId}');
      _selectedTheme = prefs.getString('chat_theme_${widget.channelId}') ?? 'Teal';
    });
  }

  Future<void> _pickWallpaper() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_wallpaper_${widget.channelId}', image.path);
      setState(() {
        _wallpaperPath = image.path;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallpaper updated!')),
        );
      }
    }
  }

  Future<void> _resetWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_wallpaper_${widget.channelId}');
    setState(() {
      _wallpaperPath = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallpaper reset to default')),
      );
    }
  }

  Future<void> _setTheme(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_theme_${widget.channelId}', themeName);
    setState(() {
      _selectedTheme = themeName;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Chat Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.4),
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
                      ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                      : [const Color(0xFFF1F5F9), Colors.white],
                ),
              ),
            ),
          ),
          
          // Glassmorphic Content
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSectionTitle('Personalization'),
                const SizedBox(height: 12),
                _buildGlassCard(
                  child: Column(
                    children: [
                      _buildSettingTile(
                        icon: Icons.image_outlined,
                        title: 'Chat Wallpaper',
                        subtitle: _wallpaperPath != null ? 'Custom wallpaper set' : 'Default pattern',
                        onTap: _pickWallpaper,
                        trailing: const Icon(Icons.chevron_right, size: 20),
                      ),
                      if (_wallpaperPath != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_wallpaperPath!),
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _resetWallpaper,
                          icon: const Icon(Icons.refresh, size: 16, color: Colors.redAccent),
                          label: const Text('Reset Wallpaper', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Chat Theme'),
                const SizedBox(height: 12),
                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: _themes.map((theme) {
                        final isSelected = _selectedTheme == theme['name'];
                        return GestureDetector(
                          onTap: () => _setTheme(theme['name'] as String),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: (theme['color'] as Color).withOpacity(0.8),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: (theme['color'] as Color).withOpacity(0.4),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : [],
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Guides & Help'),
                const SizedBox(height: 12),
                _buildGlassCard(
                  child: Column(
                    children: [
                      _buildSettingTile(
                        icon: Icons.auto_awesome_outlined,
                        title: 'Using Snaps',
                        subtitle: 'Learn how to send disappearing photos',
                        onTap: () => _showGuide('Snaps', 'Send photos that can only be viewed once. Tap the camera icon in the attachment menu to start!'),
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildSettingTile(
                        icon: Icons.mic_none_outlined,
                        title: 'Voice Notes',
                        subtitle: 'Tips for high-quality audio messages',
                        onTap: () => _showGuide('Voice Notes', 'Hold the microphone icon to record. Swipe up to lock recording mode.'),
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildSettingTile(
                        icon: Icons.alternate_email_outlined,
                        title: 'Mentions',
                        subtitle: 'How to get someone\'s attention',
                        onTap: () => _showGuide('Mentions', 'Type @ followed by a name in group chats to notify specific members.'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Media & Privacy'),
                const SizedBox(height: 12),
                _buildGlassCard(
                  child: Column(
                    children: [
                      _buildSettingTile(
                        icon: Icons.perm_media_outlined,
                        title: 'Shared Media',
                        subtitle: 'Photos, videos, and links (coming soon)',
                        onTap: () => _showGuide(
                          'Shared Media',
                          'We are still building the dedicated media gallery. For now use the attachment menu to browse shared photos and videos.',
                        ),
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildSettingTile(
                        icon: Icons.timer_outlined,
                        title: 'Disappearing Messages',
                        subtitle: 'Off (coming soon)',
                        onTap: () => _showGuide(
                          'Disappearing Messages',
                          'Disappearing messages are on the roadmap. We will let you choose a timer here once the feature ships.',
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: AppColors.secondaryTeal,
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.secondaryTeal.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.secondaryTeal, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
      ),
      trailing: trailing,
    );
  }

  void _showGuide(String title, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              content,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Got it!', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
