import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  print(AsyncNotifier);
  print(AsyncNotifierProvider);
  try {
    print(AutoDisposeAsyncNotifier);
  } catch (e) {
    print('AutoDisposeAsyncNotifier not found: $e');
  }
}

class AutoDisposeAsyncNotifier {
}
