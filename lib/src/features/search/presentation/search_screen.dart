import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../user/data/user_repository.dart';
import '../../feed/data/post_repository.dart';
import '../../feed/domain/post.dart';
import '../../feed/presentation/widgets/post_card.dart';
import '../../../core/providers/shared_preferences_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;
  String _query = '';
  List<String> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSearchHistory();
  }

  Future<void> _loadSearchHistory() async {
    final prefs = ref.read(sharedPreferencesProvider);
    setState(() {
      _searchHistory = prefs.getStringList('search_history') ?? [];
    });
  }

  Future<void> _saveToHistory(String query) async {
    if (query.isEmpty) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final history = prefs.getStringList('search_history') ?? [];
    history.remove(query);
    history.insert(0, query);
    if (history.length > 10) history.removeLast();
    await prefs.setStringList('search_history', history);
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _removeFromHistory(String query) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final history = prefs.getStringList('search_history') ?? [];
    history.remove(query);
    await prefs.setStringList('search_history', history);
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _clearHistory() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove('search_history');
    setState(() {
      _searchHistory = [];
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 70,
        title: Container(
          height: 42,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey[200],
            borderRadius: BorderRadius.circular(24),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: false,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: 'Search Nest',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 15,
              ),
              border: InputBorder.none,
              prefixIcon: Icon(
                Icons.search,
                size: 20,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.cancel, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
            ),
            onChanged: (value) => setState(() => _query = value),
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                _saveToHistory(value.trim());
              }
            },
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.secondaryTeal,
          labelColor: isDark ? Colors.white : Colors.black,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'People'),
            Tab(text: 'Posts'),
            Tab(text: 'Trending'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PeopleSearch(
            query: _query,
            history: _searchHistory,
            onHistoryTap: (q) {
              setState(() {
                _searchController.text = q;
                _query = q;
              });
            },
            onRemoveHistory: _removeFromHistory,
            onClearHistory: _clearHistory,
          ),
          _PostSearch(
            query: _query,
            history: _searchHistory,
            onHistoryTap: (q) {
              setState(() {
                _searchController.text = q;
                _query = q;
              });
            },
            onRemoveHistory: _removeFromHistory,
            onClearHistory: _clearHistory,
          ),
          _TrendingSearch(
            query: _query,
            onTagSelected: (tag) {
              setState(() {
                _searchController.text = "#$tag";
                _query = "#$tag";
                _tabController.animateTo(1);
                _saveToHistory("#$tag");
              });
            },
          ),
        ],
      ),
    );
  }
}

class _SearchInitialContent extends StatelessWidget {
  final List<String> history;
  final Function(String) onHistoryTap;
  final Function(String) onRemoveHistory;
  final VoidCallback onClearHistory;
  final Widget suggestions;
  final String suggestionTitle;

  const _SearchInitialContent({
    required this.history,
    required this.onHistoryTap,
    required this.onRemoveHistory,
    required this.onClearHistory,
    required this.suggestions,
    this.suggestionTitle = 'Suggested for you',
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (history.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Searches',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton(
                  onPressed: onClearHistory,
                  child: const Text('Clear All'),
                ),
              ],
            ),
          ),
          ...history.map(
            (query) => ListTile(
              leading: const Icon(Icons.history, color: Colors.grey),
              title: Text(query),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => onRemoveHistory(query),
              ),
              onTap: () => onHistoryTap(query),
            ),
          ),
          const Divider(),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            suggestionTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        suggestions,
      ],
    );
  }
}

class _SuggestedUsers extends ConsumerWidget {
  const _SuggestedUsers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRepo = ref.watch(userRepositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<AppUser>>(
      stream: userRepo.watchPopularUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return _ErrorRetryWidget(
            error: snapshot.error.toString(),
            onRetry: () {
              // Trigger a rebuild
            },
          );
        }

        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'No suggestions found',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return Column(
          children: users
              .map(
                (user) => ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user.avatarUrl != null
                        ? CachedNetworkImageProvider(user.avatarUrl!)
                        : null,
                    child: user.avatarUrl == null
                        ? Text(user.displayName[0].toUpperCase())
                        : null,
                  ),
                  title: Row(
                    children: [
                      Text(
                        user.displayName,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (user.isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified,
                          size: 14,
                          color: user.verificationType == 'gold'
                              ? Colors.amber
                              : AppColors.secondaryTeal,
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '@${user.handle}',
                    style: TextStyle(color: Colors.grey),
                  ),
                  onTap: () => context.push('/user/${user.uid}'),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SuggestedPosts extends ConsumerWidget {
  const _SuggestedPosts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postRepo = ref.watch(postRepositoryProvider);

    return StreamBuilder<List<Post>>(
      stream: postRepo.watchSuggestedPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return _ErrorRetryWidget(
            error: snapshot.error.toString(),
            onRetry: () {},
          );
        }

        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'No suggestions found',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return Column(
          children: posts.map((post) => PostCard(post: post)).toList(),
        );
      },
    );
  }
}

class _ErrorRetryWidget extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorRetryWidget({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isOffline =
        error.contains('UNAVAILABLE') || error.contains('UnknownHostException');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOffline ? Icons.wifi_off : Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isOffline ? "Connect to Interest" : "Something went wrong",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              isOffline
                  ? "We couldn't reach Nest. Please check your internet connection."
                  : "We encountered an error while searching. Please try again.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingSearch extends ConsumerWidget {
  final String query;
  final Function(String) onTagSelected;

  const _TrendingSearch({required this.query, required this.onTagSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.isNotEmpty) {
      return Center(
        child: Text(
          "Results for '$query' in Trending",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final trendingAsync = ref.watch(trendingTagsProvider);

    return trendingAsync.when(
      data: (tags) {
        if (tags.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.trending_up, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  "No trending topics yet",
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: tags.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final tagData = tags[index];
            final tag = tagData['tag'] as String;
            final count = tagData['count'] as int;

            return _TrendingItem(
              category: "Trending in ABUAD",
              topic: "#${tag.toUpperCase()}",
              posts: "$count",
              onTap: () => onTagSelected(tag),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _ErrorRetryWidget(
        error: error.toString(),
        onRetry: () {
          ref.invalidate(trendingTagsProvider);
        },
      ),
    );
  }
}

class _TrendingItem extends StatelessWidget {
  final String category;
  final String topic;
  final String posts;
  final VoidCallback onTap;

  const _TrendingItem({
    required this.category,
    required this.topic,
    required this.posts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  category,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Icon(Icons.more_horiz, size: 16, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              topic,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "$posts posts",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeopleSearch extends ConsumerWidget {
  final String query;
  final List<String> history;
  final Function(String) onHistoryTap;
  final Function(String) onRemoveHistory;
  final VoidCallback onClearHistory;

  const _PeopleSearch({
    required this.query,
    required this.history,
    required this.onHistoryTap,
    required this.onRemoveHistory,
    required this.onClearHistory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.isEmpty) {
      return _SearchInitialContent(
        history: history,
        onHistoryTap: onHistoryTap,
        onRemoveHistory: onRemoveHistory,
        onClearHistory: onClearHistory,
        suggestions: const _SuggestedUsers(),
      );
    }

    final userRepo = ref.watch(userRepositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<AppUser>>(
      stream: userRepo.searchUsers(query),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No users found',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: user.avatarUrl != null
                    ? CachedNetworkImageProvider(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Text(user.displayName[0].toUpperCase())
                    : null,
              ),
              title: Text(
                user.displayName,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '@${user.handle}',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () => context.push('/user/${user.uid}'),
            );
          },
        );
      },
    );
  }
}

class _PostSearch extends ConsumerWidget {
  final String query;
  final List<String> history;
  final Function(String) onHistoryTap;
  final Function(String) onRemoveHistory;
  final VoidCallback onClearHistory;

  const _PostSearch({
    required this.query,
    required this.history,
    required this.onHistoryTap,
    required this.onRemoveHistory,
    required this.onClearHistory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.isEmpty) {
      return _SearchInitialContent(
        history: history,
        onHistoryTap: onHistoryTap,
        onRemoveHistory: onRemoveHistory,
        onClearHistory: onClearHistory,
        suggestionTitle: 'Suggested Posts',
        suggestions: const _SuggestedPosts(),
      );
    }

    final postRepo = ref.watch(postRepositoryProvider);

    return StreamBuilder<List<Post>>(
      stream: postRepo.searchPosts(query),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No posts found',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return PostCard(post: posts[index]);
          },
        );
      },
    );
  }
}

// _TagSearch removed in favor of _TrendingSearch in redesign
