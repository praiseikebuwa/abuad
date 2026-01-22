import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../auth/data/auth_repository.dart';
import '../../user/data/user_repository.dart';
import '../../../core/theme/app_colors.dart';

// Simple Theme Provider
@riverpod
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ThemeMode.system;
  }

  void set(ThemeMode mode) {
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final user = ref.watch(currentUserProvider).value;

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
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text("Dark Mode"),
            trailing: DropdownButton<ThemeMode>(
              value: themeMode,
              onChanged: (mode) {
                if (mode != null) {
                  ref.read(themeModeProvider.notifier).set(mode);
                }
              },
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text("System"),
                ),
                DropdownMenuItem(value: ThemeMode.light, child: Text("Light")),
                DropdownMenuItem(value: ThemeMode.dark, child: Text("Dark")),
              ],
            ),
          ),
          const Divider(),
          const _SectionHeader(title: "Account"),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Profile"),
            subtitle: Text(user?.displayName ?? "Guest"),
            onTap: () => context.push('/profile'),
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text("Change Password"),
            onTap: () {
              // TODO: Implement Change Password Dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Feature coming soon")),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              "Delete Account",
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              // TODO: Implement Delete Logic
              showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text("Delete Account"),
                  content: const Text(
                    "Are you sure? This action cannot be undone.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        // Call delete on repo
                        Navigator.pop(c);
                      },
                      child: const Text(
                        "Delete",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          const _SectionHeader(title: "About"),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text("Version"),
            subtitle: const Text("1.0.0"),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Log Out"),
            onTap: () {
              ref.read(authRepositoryProvider).signOut();
            },
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
        ),
      ),
    );
  }
}
