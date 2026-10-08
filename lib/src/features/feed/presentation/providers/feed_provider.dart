import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../feed_screen.dart';
import '../../data/post_repository.dart';
import '../../domain/post.dart';

// ──────────────────────────────────────────────────────────────────────────────
// FEATURE 1: Algorithmic Feed Ranking
// Score formula: (likes*2 + comments*3 + reposts) / (hoursElapsed^1.5 + 2)
// Posts within the last 2 hours get a "freshness boost".
// ──────────────────────────────────────────────────────────────────────────────

double computePostScore(Post post) {
  final hoursElapsed =
      DateTime.now().difference(post.timestamp).inMinutes / 60.0;
  final engagement =
      (post.likesCount * 2) + (post.commentsCount * 3) + post.repostCount;
  // Freshness boost: posts < 2hrs old get a +10 boost
  final freshnessBoost = hoursElapsed < 2.0 ? 10.0 : 0.0;
  return (engagement + freshnessBoost) /
          (hoursElapsed + 2).clamp(1.0, double.infinity).toDouble() +
      freshnessBoost / 10.0;

  // Equivalent to: score = engagement / time^gravity + boost
  // (simplified from Hacker News formula for mobile performance)
}

List<Post> rankPosts(List<Post> posts) {
  final sorted = List<Post>.from(posts);
  sorted.sort((a, b) => computePostScore(b).compareTo(computePostScore(a)));
  return sorted;
}

enum FeedFilter { mediaOnly, docsOnly, localChannels }

class FeedFilterNotifier extends Notifier<Set<FeedFilter>> {
  @override
  Set<FeedFilter> build() => {};

  void toggle(FeedFilter filter) {
    final updated = Set<FeedFilter>.from(state);
    if (!updated.add(filter)) {
      updated.remove(filter);
    }
    state = updated;
  }
}

final feedFilterProvider =
    NotifierProvider<FeedFilterNotifier, Set<FeedFilter>>(
      FeedFilterNotifier.new,
    );

class FeedAccessibilitySettings {
  final bool largeFonts;
  final bool blindMode;
  final bool highContrast;
  final bool reducedMotion;
  final bool dyslexicFont;

  const FeedAccessibilitySettings({
    this.largeFonts = false,
    this.blindMode = false,
    this.highContrast = false,
    this.reducedMotion = false,
    this.dyslexicFont = false,
  });

  FeedAccessibilitySettings copyWith({
    bool? largeFonts,
    bool? blindMode,
    bool? highContrast,
    bool? reducedMotion,
    bool? dyslexicFont,
  }) {
    return FeedAccessibilitySettings(
      largeFonts: largeFonts ?? this.largeFonts,
      blindMode: blindMode ?? this.blindMode,
      highContrast: highContrast ?? this.highContrast,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      dyslexicFont: dyslexicFont ?? this.dyslexicFont,
    );
  }
}

class FeedAccessibilityNotifier extends Notifier<FeedAccessibilitySettings> {
  @override
  FeedAccessibilitySettings build() => const FeedAccessibilitySettings();

  void toggleLargeFonts() {
    state = state.copyWith(largeFonts: !state.largeFonts);
  }

  void toggleBlindMode() {
    state = state.copyWith(blindMode: !state.blindMode);
  }

  void toggleHighContrast() {
    state = state.copyWith(highContrast: !state.highContrast);
  }

  void toggleReducedMotion() {
    state = state.copyWith(reducedMotion: !state.reducedMotion);
  }

  void toggleDyslexicFont() {
    state = state.copyWith(dyslexicFont: !state.dyslexicFont);
  }
}

final feedAccessibilityProvider =
    NotifierProvider<FeedAccessibilityNotifier, FeedAccessibilitySettings>(
      FeedAccessibilityNotifier.new,
    );

final isLoadingMoreProvider = StateProvider<bool>((ref) => false);

class ActivePostActionNotifier extends Notifier<String?> {
  Timer? _clearTimer;

  @override
  String? build() {
    ref.onDispose(() => _clearTimer?.cancel());
    return null;
  }

  void show(String postId) {
    _clearTimer?.cancel();
    state = postId;
    _clearTimer = Timer(const Duration(seconds: 3), () {
      if (ref.mounted) {
        state = null;
      }
    });
  }

  void hide() {
    _clearTimer?.cancel();
    state = null;
  }
}

final activePostActionProvider =
    NotifierProvider<ActivePostActionNotifier, String?>(
      ActivePostActionNotifier.new,
    );

final postRepliesPreviewProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, postId) {
      return ref
          .watch(postRepositoryProvider)
          .watchComments(postId)
          .map((comments) => comments.take(3).toList());
    });

// ──────────────────────────────────────────────────────────────────────────────
// FEATURE 4: Native Feed Injections (Campus Events every N posts)
// ──────────────────────────────────────────────────────────────────────────────

/// Sentinel marker used to inject synthetic items into the feed.
/// Uses a special authorId to distinguish. Not persisted to Firestore.
Post createInjectedEventPost({
  required String title,
  required String body,
  required String channel,
  String? imageUrl,
  int injectAtIndex = 0,
}) {
  return Post(
    id: 'injected_event_$injectAtIndex',
    authorId: '__system__',
    authorName: '📢 ABUAD Updates',
    authorHandle: 'abuad_nest',
    content: '**$title**\n\n$body',
    timestamp: DateTime.now(),
    channelId: channel,
    mediaUrl: imageUrl ?? '',
    mediaType: imageUrl != null ? MediaType.image : MediaType.none,
    isVerified: true,
    verificationType: 'gold',
  );
}

/// Injects system/event posts into the feed at regular intervals.
List<Post> injectSystemPosts(List<Post> posts, List<Post> injections) {
  if (injections.isEmpty) return posts;
  final result = <Post>[];
  const injectEvery = 10; // Every 10 real posts, inject 1 system post
  int injectionIndex = 0;
  for (int i = 0; i < posts.length; i++) {
    result.add(posts[i]);
    if ((i + 1) % injectEvery == 0 && injectionIndex < injections.length) {
      result.add(injections[injectionIndex]);
      injectionIndex++;
    }
  }
  return result;
}

// ──────────────────────────────────────────────────────────────────────────────
// FEATURE 6: Optimistic Like State
// Tracks locally toggled posts before Firebase confirms.
// ──────────────────────────────────────────────────────────────────────────────

class OptimisticLikeNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => {};

  /// Returns the optimistic override for [postId], or null if no override.
  bool? get(String postId) => state[postId];

  /// Records an optimistic toggle.
  void toggle(String postId, bool currentValue) {
    state = {...state, postId: !currentValue};
  }

  /// Confirms or reverts an optimistic toggle.
  void confirm(String postId) {
    final updated = Map<String, bool>.from(state);
    updated.remove(postId);
    state = updated;
  }

  void revert(String postId, bool originalValue) {
    state = {...state, postId: originalValue};
  }
}

final optimisticLikeProvider =
    NotifierProvider<OptimisticLikeNotifier, Map<String, bool>>(
      OptimisticLikeNotifier.new,
    );

class OptimisticSaveNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => {};

  bool? get(String postId) => state[postId];

  void toggle(String postId, bool currentValue) {
    state = {...state, postId: !currentValue};
  }

  void confirm(String postId) {
    final updated = Map<String, bool>.from(state);
    updated.remove(postId);
    state = updated;
  }

  void revert(String postId, bool originalValue) {
    state = {...state, postId: originalValue};
  }
}

final optimisticSaveProvider =
    NotifierProvider<OptimisticSaveNotifier, Map<String, bool>>(
      OptimisticSaveNotifier.new,
    );

// ──────────────────────────────────────────────────────────────────────────────
// FEATURE 2: "Not Interested" / Muted hashtags
// ──────────────────────────────────────────────────────────────────────────────

class HiddenPostsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void hide(String postId) {
    state = {...state, postId};
  }

  bool isHidden(String postId) => state.contains(postId);
}

final hiddenPostsProvider = NotifierProvider<HiddenPostsNotifier, Set<String>>(
  HiddenPostsNotifier.new,
);

class MutedHashtagsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void mute(String tag) {
    state = {...state, tag.toLowerCase()};
  }

  void unmute(String tag) {
    final updated = Set<String>.from(state);
    updated.remove(tag.toLowerCase());
    state = updated;
  }

  bool isMuted(String tag) => state.contains(tag.toLowerCase());
}

final mutedHashtagsProvider =
    NotifierProvider<MutedHashtagsNotifier, Set<String>>(
      MutedHashtagsNotifier.new,
    );

List<Post> _applySmartFilters(List<Post> posts, Set<FeedFilter> filters) {
  if (filters.isEmpty) return posts;
  var updated = List<Post>.from(posts);
  if (filters.contains(FeedFilter.mediaOnly)) {
    updated = updated
        .where((post) => post.mediaType != MediaType.none)
        .toList();
  }
  if (filters.contains(FeedFilter.docsOnly)) {
    updated = updated.where(_isDocPost).toList();
  }
  if (filters.contains(FeedFilter.localChannels)) {
    updated = updated.where((post) => _isLocalChannel(post.channelId)).toList();
  }
  return updated;
}

bool _isDocPost(Post post) {
  final lowerContent = post.content.toLowerCase();
  final lowerMedia = post.mediaUrl.toLowerCase();
  return lowerMedia.endsWith('.pdf') || lowerContent.contains('.pdf');
}

bool _isLocalChannel(String channelId) {
  const localChannels = {
    'general',
    'hostel',
    'engineering',
    'confessions',
    'freshers',
    'events',
  };
  return localChannels.contains(channelId.toLowerCase());
}

// ──────────────────────────────────────────────────────────────────────────────
// Feed Limit Provider
// ──────────────────────────────────────────────────────────────────────────────

class FeedLimitNotifier extends Notifier<int> {
  @override
  int build() => 50;

  void increment(int value) {
    state += value;
  }
}

final feedLimitProvider = NotifierProvider<FeedLimitNotifier, int>(
  FeedLimitNotifier.new,
);

// ──────────────────────────────────────────────────────────────────────────────
// Paginated Feed Provider (Continuous Cursor-Based Recommendation Feed)
// ──────────────────────────────────────────────────────────────────────────────

class PaginatedFeedNotifier extends AsyncNotifier<List<Post>> {
  String? _nextCursor;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  @override
  FutureOr<List<Post>> build() async {
    _nextCursor = null;
    _hasMore = true;
    _isLoadingMore = false;
    return _fetchInitial();
  }

  Future<List<Post>> _fetchInitial() async {
    _nextCursor = null;
    _hasMore = true;
    return _fetchBatch(isInitial: true);
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore || state.isLoading || state.isRefreshing) return;

    _isLoadingMore = true;
    ref.read(isLoadingMoreProvider.notifier).state = true;

    try {
      final currentPosts = state.value ?? <Post>[];
      final newPosts = await _fetchBatch(isInitial: false);
      
      // Deduplicate against existing post IDs
      final existingIds = currentPosts.map((p) => p.id).toSet();
      final fresh = newPosts.where((p) => !existingIds.contains(p.id)).toList();

      state = AsyncData([...currentPosts, ...fresh]);
    } catch (e) {
      // Keep existing state intact on error
    } finally {
      _isLoadingMore = false;
      ref.read(isLoadingMoreProvider.notifier).state = false;
    }
  }

  Future<void> refresh() async {
    _nextCursor = null;
    _hasMore = true;
    _isLoadingMore = false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchInitial());
  }

  Future<List<Post>> _fetchBatch({required bool isInitial}) async {
    final feedType = ref.watch(feedTypeProvider);
    final selectedChannel = ref.watch(feedChannelProvider);
    final hiddenPosts = ref.watch(hiddenPostsProvider);
    final mutedTags = ref.watch(mutedHashtagsProvider);
    final activeFilters = ref.watch(feedFilterProvider);
    final repo = ref.watch(postRepositoryProvider);

    final result = await repo.fetchFeedPage(
      cursor: isInitial ? null : _nextCursor,
      limit: 15,
      feedType: feedType == FeedType.following ? 'following' : 'foryou',
      channel: feedType == FeedType.discovery ? selectedChannel : 'all',
    );

    _nextCursor = result.nextCursor;
    _hasMore = result.hasMore;

    var filtered = result.posts
        .where((p) => !hiddenPosts.contains(p.id))
        .toList();

    if (mutedTags.isNotEmpty && feedType == FeedType.discovery) {
      filtered = filtered.where((p) {
        return !p.hashtags.any((tag) => mutedTags.contains(tag.toLowerCase()));
      }).toList();
    }

    filtered = _applySmartFilters(filtered, activeFilters);

    return filtered;
  }
}

final paginatedFeedProvider =
    AsyncNotifierProvider<PaginatedFeedNotifier, List<Post>>(
      PaginatedFeedNotifier.new,
    );

