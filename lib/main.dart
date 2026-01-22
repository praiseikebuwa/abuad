import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'src/core/router/app_router.dart';
import 'src/core/database/local_database.dart';
import 'src/core/theme/app_theme.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'src/features/utilities/broadcast_listener.dart';
import 'src/core/services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Check if Firebase is already initialized (prevents hot reload errors)
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    // Initialize Notifications
    await NotificationService().initialize();
  } catch (e) {
    debugPrint("Initialization failed: $e");
  }

  final container = ProviderContainer();
  // Initialize Hive (Legacy/Local cache) - Optional now
  await container.read(localDatabaseProvider.future);

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(goRouterProvider);

    return ToastificationWrapper(
      child: MaterialApp.router(
        title: 'ABUAD App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        routerConfig: goRouter,
        builder: (context, child) {
          return _ConnectivityListener(child: child);
        },
      ),
    );
  }
}

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
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'status': status,
              'lastSeen': DateTime.now().millisecondsSinceEpoch,
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
