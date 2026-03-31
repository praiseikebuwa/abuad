import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize sharedPreferencesProvider in main');
});

class FirstLaunchRepository {
  FirstLaunchRepository(this._prefs);
  final SharedPreferences _prefs;

  static const _isFirstLaunchKey = 'is_first_launch';

  bool isFirstLaunch() => _prefs.getBool(_isFirstLaunchKey) ?? true;

  Future<void> setFirstLaunchComplete() async {
    await _prefs.setBool(_isFirstLaunchKey, false);
  }
}

final firstLaunchRepositoryProvider = Provider<FirstLaunchRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FirstLaunchRepository(prefs);
});
