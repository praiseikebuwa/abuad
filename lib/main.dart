import 'dart:ui';
import 'package:abuad/src/core/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'src/core/router/app_router.dart';
import 'src/core/database/local_database.dart';
import 'src/core/theme/app_theme.dart';
import 'src/features/utilities/broadcast_listener.dart';
import 'src/features/settings/presentation/settings_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/core/providers/shared_preferences_provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.deviceCheck,
      );
    } catch (e) {
      debugPrint("Firebase App Check activation failed: $e");
      // Optional: record to crashlytics as non-fatal
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current, reason: 'AppCheck Activation');
    }
  }

  if (!kIsWeb) {
    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  try {
    if (!kIsWeb) {
      // Register background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    // Configure System UI for Edge-to-Edge
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarColor: Colors.transparent,
      ),
    );

    // Initialize Notifications with timeout
    try {
      await NotificationService().initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint("Notification initialization timed out");
        },
      );
    } catch (e) {
      debugPrint("Notification initialization failed: $e");
    }
  } catch (e) {
    debugPrint("Initialization failed: $e");
  }

  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  // Initialize Hive (Legacy/Local cache) - Optional now
  await container.read(localDatabaseProvider.future);

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
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
    // Process any pending notification tap from terminated state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().consumePendingInitialMessage();
    });
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
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'status': status,
              'last_seen': FieldValue.serverTimestamp(),
            });
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
