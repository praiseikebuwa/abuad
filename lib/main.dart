import 'package:abuad/src/core/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'src/core/router/app_router.dart';
import 'src/core/database/local_database.dart';
import 'src/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'src/core/config/supabase_config.dart';
import 'src/features/utilities/broadcast_listener.dart';
import 'src/features/settings/presentation/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Configure System UI for Edge-to-Edge
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarColor: Colors.transparent,
      ),
    );

    // Initialize Notifications
    await NotificationService().initialize();
  } catch (e) {
    debugPrint("Initialization failed: $e");
  }

  final container = ProviderContainer();
  // Initialize Hive (Legacy/Local cache) - Optional now
  await container.read(localDatabaseProvider.future);

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(goRouterProvider);
    // Watch the theme mode from settings (with async handling)
    final themeModeAsync = ref.watch(themeModeProviderWithDefault);

    return ToastificationWrapper(
      child: MaterialApp.router(
        title: 'ABUAD App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeModeAsync,
        routerConfig: goRouter,
        builder: (context, child) {
          return _ConnectivityListener(child: child);
        },
      ),
    );
  }
}

// Helper provider to provide a default value while async loads
final themeModeProviderWithDefault = Provider<ThemeMode>((ref) {
  final asyncValue = ref.watch(themeModeProvider);
  return asyncValue.maybeWhen(
    data: (mode) => mode,
    orElse: () => ThemeMode.system,
  );
});

class _ConnectivityListener extends StatefulWidget {
  final Widget? child;
  const _ConnectivityListener({required this.child});

  @override
  State<_ConnectivityListener> createState() => _ConnectivityListenerState();
}

class _ConnectivityListenerState extends State<_ConnectivityListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateStatus('online');
    Connectivity().onConnectivityChanged.listen((result) {
      if (result.contains(ConnectivityResult.none)) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text("No Internet Connection"),
          description: const Text("Please check your network settings."),
          alignment: Alignment.bottomCenter,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateStatus('offline');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateStatus('online');
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _updateStatus('offline');
    }
  }

  Future<void> _updateStatus(String status) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({
              'status': status,
              'last_seen': DateTime.now().millisecondsSinceEpoch,
            })
            .eq('id', user.id);
      }
    } catch (e) {
      debugPrint("Error updating status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return BroadcastListener(child: widget.child ?? const SizedBox.shrink());
  }
}
