import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_app_icon_changer/flutter_app_icon_changer.dart';
import '../../../core/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Local data model – separate from the package's abstract AppIcon class
// ---------------------------------------------------------------------------
class NestIcon {
  final String name;     // icon alias name (Android/iOS)
  final String assetPath;
  final String label;
  final bool isDefault;

  const NestIcon({
    required this.name,
    required this.assetPath,
    required this.label,
    this.isDefault = false,
  });
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class AppIconScreen extends ConsumerStatefulWidget {
  const AppIconScreen({super.key});

  @override
  ConsumerState<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends ConsumerState<AppIconScreen> {
  String? _currentIcon;

  // Icon catalogue – each 'name' must match the alias in AndroidManifest / Info.plist
  final List<NestIcon> _icons = const [
    NestIcon(name: 'f1', assetPath: 'assets/logo.png', label: 'Original', isDefault: true),
    NestIcon(name: 'f1', assetPath: 'assets/app_icons/f1.png', label: 'Classic Blue'),
    NestIcon(name: 'f2', assetPath: 'assets/app_icons/f2.png', label: 'Emerald Green'),
    NestIcon(name: 'f3', assetPath: 'assets/app_icons/f3.png', label: 'Sunset Gold'),
    NestIcon(name: 'f4', assetPath: 'assets/app_icons/f4.png', label: 'Deep Purple'),
    NestIcon(name: 'f5', assetPath: 'assets/app_icons/f5.png', label: 'Midnight Dark'),
    NestIcon(name: 'f6', assetPath: 'assets/app_icons/f6.png', label: 'Vibrant Pink'),
    NestIcon(name: 'f7', assetPath: 'assets/app_icons/f7.png', label: 'Ocean Teal'),
  ];

  // Plugin instance – must receive the full icon set so it can register aliases
  late final FlutterAppIconChangerPlugin _plugin;

  @override
  void initState() {
    super.initState();
    _plugin = FlutterAppIconChangerPlugin(
      iconsSet: _icons
          .map((e) => _NestAppIconAdapter(
                iOSName: e.name,
                androidName: e.name,
                isDefault: e.isDefault,
              ))
          .toList(),
    );
    _loadCurrentIcon();
  }

  Future<void> _loadCurrentIcon() async {
    try {
      final iconName = await _plugin.getCurrentIcon();
      if (mounted) {
        setState(() => _currentIcon = iconName);
      }
    } catch (e) {
      debugPrint('Error loading current icon: $e');
    }
  }

  Future<void> _changeIcon(NestIcon icon) async {
    try {
      await _plugin.changeIcon(icon.name);
      if (mounted) {
        setState(() => _currentIcon = icon.name);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('App icon changed to ${icon.label}'),
            backgroundColor: AppColors.secondaryTeal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error changing icon: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Icon'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isDark ? AppColors.inkTealGradient : AppColors.goldGradient,
          ),
        ),
        foregroundColor: isDark ? Colors.white : AppColors.primaryInk,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 0.85,
        ),
        itemCount: _icons.length,
        itemBuilder: (context, index) {
          final icon = _icons[index];
          final isSelected =
              _currentIcon == icon.name ||
              (_currentIcon == null && icon.isDefault);

          return GestureDetector(
            onTap: () => _changeIcon(icon),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected
                      ? AppColors.secondaryTeal
                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.secondaryTeal.withValues(alpha: 0.2),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ]
                    : AppColors.softShadow,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(icon.assetPath, width: 80, height: 80),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    icon.label,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? AppColors.secondaryTeal
                          : theme.textTheme.bodyLarge?.color,
                      fontSize: 14,
                    ),
                  ),
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(
                          color: AppColors.secondaryTeal,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Adapter – bridges NestIcon into the package's abstract AppIcon type
// ---------------------------------------------------------------------------
final class _NestAppIconAdapter extends AppIcon {
  _NestAppIconAdapter({
    required String iOSName,
    required String androidName,
    required bool isDefault,
  }) : super(
          iOSIcon: iOSName,
          androidIcon: androidName,
          isDefaultIcon: isDefault,
        );
}
