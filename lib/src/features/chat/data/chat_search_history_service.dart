import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/shared_preferences_provider.dart';

final chatSearchHistoryProvider = NotifierProvider<ChatSearchHistoryNotifier, List<String>>(() {
  return ChatSearchHistoryNotifier();
});

class ChatSearchHistoryNotifier extends Notifier<List<String>> {
  static const _key = 'chat_search_history';

  @override
  List<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final history = prefs.getStringList(_key) ?? [];
    return history;
  }

  Future<void> addQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    
    final prefs = ref.read(sharedPreferencesProvider);
    final newState = [trimmed, ...state.where((q) => q != trimmed)].take(10).toList();
    state = newState;
    await prefs.setStringList(_key, newState);
  }

  Future<void> clearHistory() async {
    state = [];
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_key);
  }
}
