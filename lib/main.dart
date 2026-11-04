import 'dart:async';
import 'package:abuad/src/core/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'src/core/router/app_router.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/core/providers/shared_preferences_provider.dart';
import 'src/features/utilities/broadcast_listener.dart';
import 'src/features/settings/presentation/settings_screen.dart';
import 'src/features/auth/data/auth_repository.dart';
import 'src/core/utils/url_strategy_helper.dart';
import 'src/core/utils/startup_tracker.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  // Start high-precision startup instrumentation
  StartupTracker.instance.start();

  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  StartupTracker.instance.mark('widgets_binding_initialized');

  if (kIsWeb) {
    configureUrlStrategy();
  }

  // Prevent GoogleFonts from blocking main isolate or delaying layout
  GoogleFonts.config.allowRuntimeFetching = true;

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('🔴 Flutter Framework Error: ' + details.exceptionAsString());
    if (details.stack != null) {
      debugPrint(details.stack.toString());
    }
  };

  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    debugPrint('🔴 Uncaught Platform Error: ' + error.toString());
    return true;
  };

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
  } catch (e) {
    debugPrint("Initialization failed: $e");
  }

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  StartupTracker.instance.mark('shared_preferences_ready');

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );

  // Restore authenticated session tokens and cached profile instantly from local memory/disk (<2ms)
  await container.read(authRepositoryProvider).init(prefs);
  StartupTracker.instance.mark('auth_session_restored');

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
  StartupTracker.instance.mark('run_app_mounted');

  // Dismiss native splash as soon as the first frame renders
  widgetsBinding.addPostFrameCallback((_) {
    FlutterNativeSplash.remove();
    StartupTracker.instance.mark('first_frame_rendered');
    StartupTracker.instance.printSummary();

    // Start background network syncs with micro-delays so initial UI interaction is buttery smooth
    Timer(const Duration(milliseconds: 400), () {
      container.read(authRepositoryProvider).startBackgroundSync(prefs);
    });

    Timer(const Duration(milliseconds: 1200), () {
      NotificationService().initialize().catchError((e) {
        debugPrint("Notification initialization failed: $e");
      });
    });
  });
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(goRouterProvider);
    final themeModeAsync = ref.watch(themeModeProviderWithDefault);

    return ToastificationWrapper(
      child: MaterialApp.router(
        title: 'ABUAD',
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

final themeModeProviderWithDefault = Provider<ThemeMode>((ref) {
  return ref.watch(themeModeProvider);
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
    // Defer presence sync and launch payload parsing to avoid network contention on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Timer(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        NotificationService().consumePendingInitialMessage();
        _updateStatus('online');
      });
    });
    Connectivity().onConnectivityChanged.listen((result) {
      if (!mounted) return;
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
      await ApiClient.post('/auth/sync', {'status': status});
    } catch (e) {
      debugPrint("Error updating status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return BroadcastListener(child: widget.child ?? const SizedBox.shrink());
  }
}
