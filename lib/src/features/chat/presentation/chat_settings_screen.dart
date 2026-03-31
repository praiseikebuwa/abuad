import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';

class ChatSettingsScreen extends ConsumerWidget {
  const ChatSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Chat Settings',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.inkTealGradient),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildSectionHeader(context, 'Notifications'),
          _buildSettingTile(
            context,
            icon: Icons.notifications_active_outlined,
            title: 'Message Notifications',
            subtitle: 'Enable or disable message alerts',
            trailing: Switch(value: true, onChanged: (val) {}),
          ),
          _buildSettingTile(
            context,
            icon: Icons.volume_up_outlined,
            title: 'In-app Tones',
            subtitle: 'Play sounds for incoming messages',
            trailing: Switch(value: true, onChanged: (val) {}),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Privacy'),
          _buildSettingTile(
            context,
            icon: Icons.visibility_outlined,
            title: 'Last Seen & Online',
            subtitle: 'Manage who can see your status',
            onTap: () {},
          ),
          _buildSettingTile(
            context,
            icon: Icons.lock_outline,
            title: 'Read Receipts',
            subtitle: 'If turned off, you won\'t send or receive read receipts',
            trailing: Switch(value: true, onChanged: (val) {}),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Data & Storage'),
          _buildSettingTile(
            context,
            icon: Icons.cloud_upload_outlined,
            title: 'Chat Backup',
            subtitle: 'Backup your chat history to the cloud',
            onTap: () {},
          ),
          _buildSettingTile(
            context,
            icon: Icons.delete_outline,
            title: 'Clear All Chats',
            subtitle: 'Permanently delete all message history',
            isDestructive: true,
            onTap: () {
               _showClearChatsDialog(context);
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: isDark ? AppColors.accentAmber : AppColors.secondaryTeal,
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive 
              ? Colors.red.withOpacity(0.1) 
              : (isDark ? Colors.white10 : Colors.grey[100]),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isDestructive 
              ? Colors.red 
              : (isDark ? Colors.white70 : AppColors.primaryInk),
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : (isDark ? Colors.white : AppColors.primaryInk),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            )
          : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, size: 20) : null),
    );
  }

  void _showClearChatsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Chats?'),
        content: const Text(
          'This will permanently delete all your chat history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
