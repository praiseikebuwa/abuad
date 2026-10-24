import sys

with open('lib/src/features/chat/presentation/group_info_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update imports
old_imports = """import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/chat_repository.dart';
import '../domain/chat_channel.dart';
import '../domain/chat_message.dart';
import '../../../core/utils/url_validator.dart';
import 'group_settings_screen.dart';"""

new_imports = """import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/chat_repository.dart';
import '../domain/chat_channel.dart';
import '../domain/chat_message.dart';
import '../../user/data/user_repository.dart';
import '../../../core/services/image_upload_service.dart';
import '../../../core/utils/url_validator.dart';
import '../../../core/theme/app_colors.dart';
import 'group_settings_screen.dart';"""

if old_imports in content:
    content = content.replace(old_imports, new_imports)
    print("Imports updated successfully")
else:
    print("Old imports not found exactly, check manually")

# 2. Add state variables to _GroupInfoScreenState
old_state = """class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  bool _isMuted = false;
  String _notificationSetting = 'On / Custom';
  Future<ChatChannel?>? _channelFuture;"""

new_state = """class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  bool _isMuted = false;
  String _notificationSetting = 'On / Custom';
  Future<ChatChannel?>? _channelFuture;
  bool _isSearchingMembers = false;
  String _memberSearchQuery = '';"""

content = content.replace(old_state, new_state)

# 3. Replace share handlers
old_share_popup = """                  } else if (val == 'share') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Group invite link copied')),
                    );
                  }"""

new_share_popup = """                  } else if (val == 'share') {
                    _shareGroupLink(displayName);
                  }"""
content = content.replace(old_share_popup, new_share_popup)

old_share_btn = """        _buildActionButton(
          icon: Icons.share_rounded,
          label: 'Share Link',
          bg: buttonBg,
          textPrimary: textPrimary,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Group invite link copied')),
            );
          },
        ),"""

new_share_btn = """        _buildActionButton(
          icon: Icons.share_rounded,
          label: 'Share Link',
          bg: buttonBg,
          textPrimary: textPrimary,
          onTap: () => _shareGroupLink(displayName),
        ),"""
content = content.replace(old_share_btn, new_share_btn)

# 4. Add Group Wallpaper tile to _buildOptionsCard
old_options = """          _buildOptionTile(
            title: 'Group Settings',
            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupSettingsScreen(channelId: widget.channelId),
                ),
              );
            },
            textPrimary: textPrimary,
          ),"""

new_options = """          _buildOptionTile(
            title: 'Group Settings',
            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupSettingsScreen(channelId: widget.channelId),
                ),
              );
            },
            textPrimary: textPrimary,
          ),
          _buildInnerDivider(isDark),
          _buildOptionTile(
            title: 'Group Wallpaper / Background',
            trailing: const Icon(Icons.wallpaper_rounded, color: Color(0xFF94A3B8)),
            onTap: () => _showWallpaperPicker(context, isDark),
            textPrimary: textPrimary,
          ),"""
content = content.replace(old_options, new_options)

with open('lib/src/features/chat/presentation/group_info_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("First pass complete.")
