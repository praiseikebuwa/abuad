import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/story_repository.dart';
import '../domain/story_model.dart';

/// Provider for StoryRepository
final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  return StoryRepository(Supabase.instance.client);
});

/// Provider for all stories grouped by user
final allStoriesGroupedProvider = StreamProvider<Map<String, List<Story>>>((
  ref,
) {
  final repo = ref.watch(storyRepositoryProvider);
  return repo.getAllStoriesGrouped();
});

/// Provider for all stories (flat list)
final allStoriesProvider = StreamProvider<List<Story>>((ref) {
  final repo = ref.watch(storyRepositoryProvider);
  return repo.getAllStories();
});

/// Provider for a specific user's stories
final userStoriesProvider = StreamProvider.family<List<Story>, String>((
  ref,
  userId,
) {
  final repo = ref.watch(storyRepositoryProvider);
  return repo.getUserStories(userId);
});

/// Provider to check if a user has unviewed stories
final hasUnviewedStoriesProvider = FutureProvider.family<bool, String>((
  ref,
  userId,
) async {
  final repo = ref.watch(storyRepositoryProvider);
  final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
  return await repo.hasUnviewedStories(userId, currentUserId);
});

/// Provider for current user ID
final currentUserIdProvider = Provider<String>((ref) {
  return Supabase.instance.client.auth.currentUser?.id ?? '';
});
