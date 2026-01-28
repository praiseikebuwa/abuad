import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../../user/data/user_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/shared_preferences_provider.dart';

// Theme Mode Provider with Persistence
final themeModeProvider = FutureProvider.autoDispose<ThemeMode>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final savedMode = prefs.getString('theme_mode');
  if (savedMode != null) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == savedMode,
      orElse: () => ThemeMode.system,
    );
  }
  return ThemeMode.system;
});

// Notification Settings Provider
final notificationSettingsProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return prefs.getBool('notifications_enabled') ?? true;
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _setThemeMode(WidgetRef ref, ThemeMode mode) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString('theme_mode', mode.name);
    ref.invalidate(themeModeProvider);
  }

  Future<void> _toggleNotifications(WidgetRef ref, bool value) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool('notifications_enabled', value);
    ref.invalidate(notificationSettingsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeAsync = ref.watch(themeModeProvider);
    final notificationsAsync = ref.watch(notificationSettingsProvider);
    final user = ref.watch(currentUserProvider).value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.blueGradient),
        ),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          const _SectionHeader(title: "Appearance"),
          themeModeAsync.when(
            data: (themeMode) => ListTile(
              leading: Icon(Icons.dark_mode, color: theme.colorScheme.primary),
              title: Text(
                "Theme",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: DropdownButton<ThemeMode>(
                value: themeMode,
                onChanged: (mode) {
                  if (mode != null) {
                    _setThemeMode(ref, mode);
                  }
                },
                dropdownColor: isDark ? Colors.grey[850] : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                items: [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text(
                      "System",
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text(
                      "Light",
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text(
                      "Dark",
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const ListTile(
              leading: Icon(Icons.dark_mode),
              title: Text("Theme"),
              trailing: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => const ListTile(
              leading: Icon(Icons.dark_mode),
              title: Text("Theme"),
              trailing: Text("Error"),
            ),
          ),
          const Divider(),
          const _SectionHeader(title: "Notifications"),
          notificationsAsync.when(
            data: (notificationsEnabled) => ListTile(
              leading: Icon(
                Icons.notifications_outlined,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                "Push Notifications",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                "Receive notifications for new messages and posts",
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 13,
                ),
              ),
              trailing: Switch(
                value: notificationsEnabled,
                onChanged: (val) {
                  _toggleNotifications(ref, val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        val
                            ? 'Notifications enabled'
                            : 'Notifications disabled',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                activeThumbColor: theme.colorScheme.primary,
              ),
            ),
            loading: () => const ListTile(
              leading: Icon(Icons.notifications_outlined),
              title: Text("Push Notifications"),
              trailing: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => const ListTile(
              leading: Icon(Icons.notifications_outlined),
              title: Text("Push Notifications"),
              trailing: Text("Error"),
            ),
          ),
          const Divider(),
          const _SectionHeader(title: "Account"),
          ListTile(
            leading: Icon(Icons.person, color: theme.colorScheme.primary),
            title: Text(
              "Profile",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              user?.displayName ?? "Guest",
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
            onTap: () => context.push('/profile'),
          ),
          ListTile(
            leading: Icon(Icons.lock, color: theme.colorScheme.primary),
            title: Text(
              "Change Password",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
            onTap: () {
              _showChangePasswordDialog(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip, color: Colors.blue),
            title: Text(
              "Privacy & Security",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Privacy settings coming soon")),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              "Delete Account",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Colors.red.withOpacity(0.5),
            ),
            onTap: () {
              _showDeleteAccountDialog(context, ref);
            },
          ),
          const Divider(),
          const _SectionHeader(title: "Support"),
          ListTile(
            leading: Icon(Icons.help_outline, color: theme.colorScheme.primary),
            title: Text(
              "Help Center",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Help Center coming soon")),
              );
            },
          ),
          ListTile(
            leading: Icon(
              Icons.bug_report_outlined,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              "Report a Bug",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Bug reporting coming soon")),
              );
            },
          ),
          const Divider(),
          const _SectionHeader(title: "About"),
          ListTile(
            leading: Icon(Icons.info, color: theme.colorScheme.primary),
            title: Text(
              "Version",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              "1.0.0",
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Log Out"),
                    content: const Text("Are you sure you want to log out?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text("Log Out"),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await ref.read(authRepositoryProvider).signOut();
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text("Log Out"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Current Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "New Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Confirm New Password",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              if (newPasswordController.text !=
                  confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Passwords don't match")),
                );
                return;
              }

              if (newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Password must be at least 6 characters"),
                  ),
                );
                return;
              }

              Navigator.pop(context);
              // TODO: Implement with Firebase Auth
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Password change feature coming soon"),
                ),
              );
            },
            child: const Text("Change"),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
          "Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(c);
              // TODO: Implement account deletion with Firebase
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Account deletion feature coming soon"),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
