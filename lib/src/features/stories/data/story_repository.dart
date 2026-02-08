import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/story_model.dart';
import '../../../core/services/supabase_storage_service.dart';

/// Repository for Story operations with Supabase
class StoryRepository {
  final SupabaseClient _supabase;
  final SupabaseStorageService _storage;

  StoryRepository(this._supabase) : _storage = SupabaseStorageService();

  /// Create a new story
  /// Uploads media to Supabase Storage and saves to Postgres with 24h expiration
  Future<String> createStory({
    required XFile mediaFile,
    required String mediaType,
    String? caption,
    String? backgroundColor,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Upload media to Supabase Storage
      debugPrint('📤 Uploading story media to Supabase Storage...');

      final mediaUrl = mediaType == 'video'
          ? await _storage.uploadVideo(mediaFile)
          : await _storage.uploadImage(mediaFile);

      // Calculate expiration (24 hours from now)
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24));

      // Create story records in 'stories' table
      final data = {
        'user_id': user.id,
        'media_url': mediaUrl,
        'media_type': mediaType,
        'caption': caption,
        'background_color': backgroundColor,
        'created_at': now.millisecondsSinceEpoch,
        'expires_at': expiresAt.millisecondsSinceEpoch,
        'view_count': 0,
      };

      final response = await _supabase
          .from('stories')
          .insert(data)
          .select()
          .single();
      debugPrint('✅ Story created: ${response['id']}');

      return response['id'] as String;
    } catch (e) {
      debugPrint('❌ Error creating story: $e');
      rethrow;
    }
  }

  /// Get all stories for a specific user (non-expired)
  Stream<List<Story>> getUserStories(String userId) {
    // Current user for view check
    final currentUid = _supabase.auth.currentUser?.id;

    // Build query with optional join to check if viewed by current user
    // We join 'story_views' filtered by current user aliased as 'my_views'
    var query = _supabase
        .from('stories')
        .select('*, profiles(*), my_views:story_views(viewer_id)')
        .eq('user_id', userId)
        .gt('expires_at', DateTime.now().millisecondsSinceEpoch);

    // If authenticated, we can filter the join, but standard Supabase select join filtering
    // requires inner join or specific syntax.
    // simpler to just join all story_views limit 1? No, logic is tricky with one query for "my view".
    // Supabase allows filtering on joined tables: story_views!left(viewer_id.eq.currentUid)
    // Query: select *, profiles(*), story_views!left(*) w/ filter.

    if (currentUid != null) {
      // Ideally:
      // .select('*, profiles(*), my_views:story_views!left(viewer_id)')
      // .eq('my_views.viewer_id', currentUid) -- this would filter STORIES to only those viewed, not what we want.
      // We want all stories, with a flag.
      // The standard way is: .select('*, story_views(viewer_id)') and filter in memory or client-side.
      // Or simpler: just don't load view status in list, load on view.
    }

    return query.order('created_at', ascending: true).asStream().map((data) {
      return data.map((map) {
        // Inject manual check or rely on map structure
        // If we used my_views:...
        return Story.fromMap(map, currentUserId: currentUid);
      }).toList();
    });
  }

  /// Get all non-expired stories grouped by user
  Stream<Map<String, List<Story>>> getAllStoriesGrouped() {
    final currentUid = _supabase.auth.currentUser?.id;
    final nowEpoch = DateTime.now().millisecondsSinceEpoch;

    return _supabase
        .from('stories')
        .select('*, profiles(*)')
        .gt('expires_at', nowEpoch)
        .order('created_at', ascending: false)
        .asStream()
        .map((data) {
          final stories = data
              .map((map) => Story.fromMap(map, currentUserId: currentUid))
              .toList();

          // Group stories by userId
          final grouped = <String, List<Story>>{};
          for (final story in stories) {
            grouped.putIfAbsent(story.userId, () => []).add(story);
          }

          return grouped;
        });
  }

  /// Get all non-expired stories as a flat list
  Stream<List<Story>> getAllStories() {
    final currentUid = _supabase.auth.currentUser?.id;
    final nowEpoch = DateTime.now().millisecondsSinceEpoch;

    return _supabase
        .from('stories')
        .select('*, profiles(*)')
        .gt('expires_at', nowEpoch)
        .order('created_at', ascending: false)
        .asStream()
        .map((data) {
          return data
              .map((map) => Story.fromMap(map, currentUserId: currentUid))
              .toList();
        });
  }

  /// Mark a story as viewed by the current user
  Future<void> markAsViewed(String storyId, String viewerId) async {
    try {
      // 1. Insert into story_views (idempotent due to composite PK or unique index if set)
      // My schema.sql didn't strictly enforce unique constraint on (story_id, viewer_id),
      // so we use simple select to check first or just insert and ignore error.

      final existing = await _supabase.from('story_views').select().match({
        'story_id': storyId,
        'viewer_id': viewerId,
      }).maybeSingle();

      if (existing != null) return;

      await _supabase.from('story_views').insert({
        'story_id': storyId,
        'viewer_id': viewerId,
        'viewed_at': DateTime.now().millisecondsSinceEpoch,
      });

      // 2. Increment view count on story
      // Ideally use RPC
      await _supabase.rpc('increment_story_views', params: {'row_id': storyId});

      debugPrint('✅ Story $storyId marked as viewed by $viewerId');
    } catch (e) {
      debugPrint('❌ Error marking story as viewed: $e');
    }
  }

  /// Delete a story (only owner can delete)
  Future<void> deleteStory(String storyId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Delete (RLS will ensure ownership)
      await _supabase.from('stories').delete().eq('id', storyId);

      debugPrint('✅ Story deleted: $storyId');
    } catch (e) {
      debugPrint('❌ Error deleting story: $e');
      rethrow;
    }
  }

  /// Get viewers for a story (for owner to see who viewed)
  Future<List<Map<String, dynamic>>> getStoryViewers(String storyId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Query story_views join profiles
      final response = await _supabase
          .from('story_views')
          .select('*, profiles(*)')
          .eq('story_id', storyId)
          .order('viewed_at', ascending: false);

      final viewers = response.map((data) {
        final profile = data['profiles'] ?? {};
        return {
          'userId': data['viewer_id'],
          'displayName': profile['display_name'] ?? 'Unknown',
          'avatarUrl': profile['avatar_url'],
          'viewedAt': data['viewed_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(data['viewed_at'])
              : null,
        };
      }).toList();

      return viewers;
    } catch (e) {
      debugPrint('❌ Error getting story viewers: $e');
      return [];
    }
  }

  /// Check if user has unviewed stories from a specific user
  Future<bool> hasUnviewedStories(String userId, String currentUserId) async {
    // This requires a bit of logic:
    // Fetch user's active stories AND the views by current user.
    // If any story is NOT in the views list, return true.
    try {
      // 1. Get IDs of active stories by user
      final nowEpoch = DateTime.now().millisecondsSinceEpoch;
      final storiesData = await _supabase
          .from('stories')
          .select('id')
          .eq('user_id', userId)
          .gt('expires_at', nowEpoch);

      if (storiesData.isEmpty) return false;
      final storyIds = storiesData.map((e) => e['id'] as String).toList();

      // 2. Get views by current user for these stories
      final viewsData = await _supabase
          .from('story_views')
          .select('story_id')
          .eq('viewer_id', currentUserId)
          .inFilter('story_id', storyIds);

      final viewedStoryIds = viewsData
          .map((e) => e['story_id'] as String)
          .toSet();

      // 3. Check if we have any unviewed
      return storyIds.any((id) => !viewedStoryIds.contains(id));
    } catch (e) {
      debugPrint('❌ Error checking unviewed stories: $e');
      return false;
    }
  }
}
