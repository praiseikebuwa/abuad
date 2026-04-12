import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/shared_preferences_provider.dart';

final searchHistoryProvider = NotifierProvider<SearchHistoryNotifier, List<String>>(() {
  return SearchHistoryNotifier();
});

class SearchHistoryNotifier extends Notifier<List<String>> {
  static const _key = 'global_search_history';

  @override
  List<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    // Note: We are using a separate key from chat search history to allow distinct experiences
    final history = prefs.getStringList(_key) ?? [];
    return history;
  }

  Future<void> addQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    
    final prefs = ref.read(sharedPreferencesProvider);
    // Keep last 15 searches, most recent first
    final newState = [trimmed, ...state.where((q) => q != trimmed)].take(15).toList();
    state = newState;
    await prefs.setStringList(_key, newState);
  }

  Future<void> removeQuery(String query) async {
    final newState = state.where((q) => q != query).toList();
    state = newState;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(_key, newState);
  }

  Future<void> clearHistory() async {
    state = [];
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_key);
  }
}
