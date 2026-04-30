import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../../user/data/user_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/shared_preferences_provider.dart';

// Theme Mode Provider with Persistence
final themeModeProvider = Provider.autoDispose<ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final savedMode = prefs.getString('theme_mode');
  if (savedMode != null) {
    try {
      return ThemeMode.values.firstWhere((mode) => mode.name == savedMode);
    } catch (_) {
      return ThemeMode.system;
    }
  }
  return ThemeMode.system;
});

// Notification Settings Provider
final notificationSettingsProvider = Provider.autoDispose<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool('notifications_enabled') ?? true;
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _setThemeMode(WidgetRef ref, ThemeMode mode) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('theme_mode', mode.name);
    ref.invalidate(themeModeProvider);
  }

  Future<void> _toggleNotifications(WidgetRef ref, bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('notifications_enabled', value);
    ref.invalidate(notificationSettingsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final notificationsEnabled = ref.watch(notificationSettingsProvider);
    final user = ref.watch(currentUserProvider).value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? AppColors.inkTealGradient
                : AppColors.goldGradient,
          ),
        ),
        foregroundColor: isDark ? Colors.white : AppColors.primaryInk,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _SectionHeader(title: "APPEARANCE"),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: "Theme",
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ThemeMode>(
                  value: themeMode,
                  isDense: true,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: theme.iconTheme.color,
                  ),
                  onChanged: (mode) {
                    if (mode != null) {
                      _setThemeMode(ref, mode);
                    }
                  },
                  dropdownColor: theme.cardTheme.color,
                  style: theme.textTheme.bodyMedium,
                  items: [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text("System"),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text("Light"),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text("Dark"),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.grid_view_outlined,
            title: "App Icon",
            subtitle: "Change the app's home screen icon",
            showArrow: true,
            onTap: () => context.push('/settings/app-icon'),
          ),

          const SizedBox(height: 24),
          _SectionHeader(title: "NOTIFICATIONS"),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: "Push Notifications",
            subtitle: "Receive updates for new messages and posts",
            trailing: Switch.adaptive(
              value: notificationsEnabled,
              onChanged: (val) {
                _toggleNotifications(ref, val);
              },
              activeColor: AppColors.secondaryTeal,
            ),
          ),

          const SizedBox(height: 24),
          _SectionHeader(title: "ACCOUNT"),
          _SettingsTile(
            icon: Icons.person_outline,
            title: "Profile",
            subtitle: user?.displayName ?? "Guest",
            showArrow: true,
            onTap: () => context.push('/profile/edit'),
          ),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: ref.read(authRepositoryProvider).isPasswordLinked
                ? "Change Password"
                : "Set Account Password",
            showArrow: true,
            onTap: () {
              if (ref.read(authRepositoryProvider).isPasswordLinked) {
                _showChangePasswordDialog(context, ref);
              } else {
                _showSetPasswordDialog(context, ref);
              }
            },
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: "Privacy Policy",
            showArrow: true,
            onTap: () => context.push('/settings/privacy'),
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: "Terms of Service",
            showArrow: true,
            onTap: () => context.push('/settings/terms'),
          ),
          if (user != null)
            _SettingsTile(
              icon: Icons.visibility_outlined,
              title: "Show Following List",
              subtitle: "Allow others to see who you follow",
              trailing: Switch.adaptive(
                value: user.isFollowingVisible,
                onChanged: (val) {
                  ref.read(userRepositoryProvider).updateUser(user.uid, {
                    'is_following_visible': val,
                  });
                },
                activeColor: AppColors.secondaryTeal,
              ),
            ),
          _SettingsTile(
            icon: Icons.delete_outline,
            title: "Delete Account",
            textColor: AppColors.error,
            iconColor: AppColors.error,
            onTap: () => _showDeleteAccountDialog(context, ref),
          ),

          const SizedBox(height: 24),
          _SectionHeader(title: "SUPPORT"),
          _SettingsTile(
            icon: Icons.help_outline,
            title: "Help Center",
            showArrow: true,
            onTap: () {
              context.push('/settings/help');
            },
          ),
          _SettingsTile(
            icon: Icons.feedback_outlined,
            title: "Send Feedback",
            showArrow: true,
            onTap: () => context.push('/settings/support', extra: {'title': 'Send Feedback', 'type': 'feedback'}),
          ),
          _SettingsTile(
            icon: Icons.star_outline,
            title: "Rate App",
            showArrow: true,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Redirecting to App Store...")),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.bug_report_outlined,
            title: "Report a Bug",
            showArrow: true,
            onTap: () => context.push('/settings/support', extra: {'title': 'Report a Bug', 'type': 'bug'}),
          ),

          const SizedBox(height: 24),
          _SectionHeader(title: "ABOUT"),
          _SettingsTile(
            icon: Icons.info_outline,
            title: "Version",
            subtitle: "1.0.0",
          ),
          const SizedBox(height: 32),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ElevatedButton(
              onPressed: () async {
                final confirmed = await _showConfirmationDialog(
                  context,
                  "Log Out",
                  "Are you sure you want to log out?",
                  isDestructive: true,
                );
                if (confirmed == true) {
                  await ref.read(authRepositoryProvider).signOut();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Colors.white,
              ),
              child: const Text("Log Out"),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmationDialog(
    BuildContext context,
    String title,
    String content, {
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.cardTheme.color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                "Cancel",
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                isDestructive ? "Confirm" : "OK",
                style: TextStyle(
                  color: isDestructive
                      ? AppColors.error
                      : AppColors.secondaryTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Enter current password'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter new password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value != newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setState(() => isLoading = true);

                          try {
                            await ref
                                .read(authRepositoryProvider)
                                .changePassword(
                                  currentPassword: currentPasswordController
                                      .text
                                      .trim(),
                                  newPassword: newPasswordController.text
                                      .trim(),
                                );

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Password changed successfully',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setState(() => isLoading = false);
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSetPasswordDialog(BuildContext context, WidgetRef ref) {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final user = ref.read(currentUserProvider).value;
            final email = user?.email ?? "your email";

            return AlertDialog(
              title: const Text('Set Account Password'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Set a password for $email to enable logging in without Google.",
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_open),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (value) {
                        if (value != passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setState(() => isLoading = true);

                          try {
                            final userEmail = ref
                                .read(currentUserProvider)
                                .value
                                ?.email;
                            if (userEmail == null) {
                              throw Exception('Email not found');
                            }

                            await ref
                                .read(authRepositoryProvider)
                                .linkWithEmailPassword(
                                  userEmail,
                                  passwordController.text.trim(),
                                );

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Password set successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              // Refresh current user info
                              ref.invalidate(currentUserProvider);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setState(() => isLoading = false);
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Set Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showConfirmationDialog(
      context,
      "Delete Account",
      "Are you sure you want to delete your account? This action cannot be undone.",
      isDestructive: true,
    );
    if (confirmed == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Deleting account...")));
      try {
        await ref.read(authRepositoryProvider).deleteAccount();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account deleted successfully")),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error deleting account: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showArrow;
  final Color? textColor;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showArrow = false,
    this.textColor,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 0.5,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? theme.colorScheme.primary).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor ?? theme.colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: textColor ?? theme.textTheme.bodyLarge?.color,
            fontSize: 15,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: TextStyle(
                  color: theme.textTheme.bodySmall?.color,
                  fontSize: 13,
                ),
              )
            : null,
        trailing:
            trailing ??
            (showArrow
                ? Icon(Icons.chevron_right, color: Colors.grey[400])
                : null),
      ),
    );
  }
}
