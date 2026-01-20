import 'package:flutter_riverpod/flutter_riverpod.dart';

final localDatabaseProvider = FutureProvider<void>((ref) async {
  // Hive initialization (Legacy) - Disabled for Firestore transition
  // await Hive.initFlutter();
});
