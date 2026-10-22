import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_colors.dart';
import '../../user/data/user_repository.dart';
import '../data/marketplace_repository.dart';
import 'add_marketplace_item_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/url_validator.dart';

final recommendedMarketplaceItemsProvider =
    StreamProvider.autoDispose<List<MarketplaceItem>>((ref) {
      final repo = ref.watch(marketplaceRepositoryProvider);
      final currentUserId = ref.watch(currentUserIdProvider);
      final followingAsync = currentUserId != null
          ? ref.watch(followingProvider(currentUserId))
          : const AsyncValue<List<AppUser>>.data([]);

      return repo.watchItems(sortBy: 'newest').asBroadcastStream().map((items) {
        final followingIds =
            followingAsync.value?.map((user) => user.uid).toSet() ?? <String>{};
        final recommended = <MarketplaceItem>[];
        for (final item in items) {
          if (followingIds.contains(item.sellerId)) {
            recommended.add(item);
          }
          if (recommended.length >= 6) break;
        }

        if (recommended.length < 6) {
          for (final item in items) {
            if (recommended.contains(item)) continue;
            if (item.images.isNotEmpty || item.price < 10000) {
              recommended.add(item);
            }
            if (recommended.length >= 6) break;
          }
        }

        if (recommended.isEmpty && items.isNotEmpty) {
          recommended.addAll(items.take(3));
        }

        return recommended;
      });
    });

final boostedListingsProvider = StateProvider<Set<String>>((ref) => <String>{});

final listingReactionsProvider =
    NotifierProvider<ListingReactionNotifier, Map<String, int>>(
      ListingReactionNotifier.new,
    );

class ListingReactionNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => {};

  void addReaction(String itemId) {
    final current = state[itemId] ?? 0;
    state = {...state, itemId: current + 1};
  }
}

enum MarketplaceSmartFilter {
  verifiedDeals,
  localPickup,
  campusEssentials,
  mediaOnly,
}

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _selectedCategory = 'all';
  String _sortBy = 'newest';
  double? _maxPrice;
  bool _isSearching = false;
  bool _showNewDropsPill = false;
  String? _lastTopItemId;
  final _activeFilters = <MarketplaceSmartFilter>{};
  bool _largeFonts = false;
  bool _blindMode = false;
  bool get _isDarkTheme => Theme.of(context).brightness == Brightness.dark;

  /// Derived color for text/icons — accessible from all helper methods.
  Color get _themeColor => _isDarkTheme ? Colors.white : AppColors.primaryInk;

  /// Convenience alias for use in helper methods.
  bool get _isDark => _isDarkTheme;

  /// Subtle border color matching the current theme.
  Color get _borderSubtle =>
      _isDarkTheme ? Colors.white10 : Colors.black.withValues(alpha: 0.05);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset <= 0 && _showNewDropsPill) {
        setState(() => _showNewDropsPill = false);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsStream = ref
        .watch(marketplaceRepositoryProvider)
        .watchItems(
          category: _selectedCategory == 'all' ? null : _selectedCategory,
          searchQuery: _searchController.text,
          sortBy: _sortBy,
          maxPrice: _maxPrice,
        )
        .asBroadcastStream();

    final recommendedAsync = ref.watch(recommendedMarketplaceItemsProvider);

    final textScaleFactor = _largeFonts
        ? 1.15
        : MediaQuery.of(context).textScaleFactor;

    final isDark = _isDarkTheme;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final borderSubtle = isDark
        ? Colors.white10
        : Colors.black.withValues(alpha: 0.05);

    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: backgroundColor,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      Colors.black,
                      AppColors.surfaceDarkSecondary,
                      AppColors.surfaceDark,
                    ]
                  : [
                      const Color(0xFFF8FAFC),
                      const Color(0xFFF1F5F9),
                      Colors.white,
                    ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                expandedHeight: 46,
                floating: true,
                pinned: true,
                stretch: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: Navigator.of(context).canPop()
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back),
                        color: _themeColor,
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            context.go('/');
                          }
                        },
                      )
                    : null,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 8),
                  title: _isSearching
                      ? null
                      : Text(
                          'Marketplace',
                          style: TextStyle(
                            color: _themeColor,
                            fontWeight: FontWeight.w900,
                            fontSize: innerBoxIsScrolled ? 18 : 24,
                            letterSpacing: -0.5,
                          ),
                        ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? AppColors.inkTealGradient
                          : AppColors.goldGradient,
                    ),
                    child: Opacity(
                      opacity: 0.3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black : Colors.white)
                              .withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      _isSearching ? Icons.close : Icons.search,
                      color: _themeColor,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_isSearching) {
                          _searchController.clear();
                        }
                        _isSearching = !_isSearching;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.accessibility_new, color: _themeColor),
                    onPressed: _showAccessibilitySheet,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              if (_isSearching)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: TextStyle(color: _themeColor),
                      cursorColor: AppColors.accentAmber,
                      decoration: InputDecoration(
                        hintText: 'Search for books, tech, or dorm items...',
                        hintStyle: TextStyle(
                          color: _themeColor.withValues(alpha: 0.5),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: _themeColor.withValues(alpha: 0.7),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _buildUnifiedFilterBar(),
                    const SizedBox(height: 16),
                    _buildRecommendedSection(recommendedAsync),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              // Trending + Seller sections belong in the header so they
              // sit above the full-width grid, not awkwardly inside it.
              SliverToBoxAdapter(
                child: StreamBuilder<List<MarketplaceItem>>(
                  stream: itemsStream,
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTrendingCategories(items),
                        _buildSellerHighlights(items),
                        _buildTrendingHashtagRow(items),
                      ],
                    );
                  },
                ),
              ),
            ],
            body: StreamBuilder<List<MarketplaceItem>>(
              stream: itemsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingGrid();
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                }

                final items = _applySmartFilters(snapshot.data ?? []);
                _updateDropIndicator(items);

                return CustomScrollView(
                  slivers: [
                    if (_blindMode)
                      SliverToBoxAdapter(child: _buildBlindSummary(items)),
                    if (items.isEmpty)
                      SliverFillRemaining(
                        child: _buildEmptyState(_searchController.text),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverMasonryGrid.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          itemBuilder: (context, index) =>
                              _buildItemCard(context, items[index])
                                  .animate(delay: (index * 50).ms)
                                  .fadeIn(duration: 400.ms)
                                  .slideY(begin: 0.1, end: 0, duration: 400.ms),
                          childCount: items.length,
                        ),
                      ),
                    // Drop Indicator Pill
                    if (_showNewDropsPill)
                      SliverToBoxAdapter(child: _buildNewDropsPill()),
                  ],
                );
              },
            ),
          ),
        ),
        floatingActionButton: Padding(
          padding: EdgeInsets.only(
            bottom: 5 + MediaQuery.of(context).padding.bottom,
          ),
          child: FloatingActionButton(
            heroTag: 'marketplace_fab',
            onPressed: _showAddItemDialog,
            backgroundColor: AppColors.accentAmber,
            foregroundColor: AppColors.primaryInk,
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedFilterBar() {
    return Column(
      children: [
        // Categories Row
        SizedBox(
          height: 46,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: 7, // Fixed list from below
            itemBuilder: (context, index) {
              const categories = [
                {'id': 'all', 'label': 'All', 'icon': Icons.grid_view_rounded},
                {'id': 'books', 'label': 'Books', 'icon': Icons.book_outlined},
                {
                  'id': 'electronics',
                  'label': 'Tech',
                  'icon': Icons.devices_other,
                },
                {
                  'id': 'dorm',
                  'label': 'Dorm',
                  'icon': Icons.home_work_outlined,
                },
                {
                  'id': 'lost_found',
                  'label': 'Lost',
                  'icon': Icons.find_replace_rounded,
                },
                {
                  'id': 'fashion',
                  'label': 'Fashion',
                  'icon': Icons.checkroom_rounded,
                },
                {
                  'id': 'services',
                  'label': 'Services',
                  'icon': Icons.build_circle_outlined,
                },
              ];
              final category = categories[index];
              final isSelected = _selectedCategory == category['id'];
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  onTap: () => setState(
                    () => _selectedCategory = category['id'] as String,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: 300.ms,
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.secondaryTeal
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.secondaryTeal
                            : Colors.white10,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          category['icon'] as IconData,
                          size: 16,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          category['label'] as String,
                          style: TextStyle(
                            color: isSelected ? Colors.white : _themeColor,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Smart Filters and Sort Row
        SizedBox(
          height: 38,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              // Verified Deals Quick Toggle
              _buildQuickFilterChip(
                label: 'Verified Only',
                icon: Icons.verified_user_rounded,
                filter: MarketplaceSmartFilter.verifiedDeals,
              ),
              const SizedBox(width: 8),
              _buildQuickFilterChip(
                label: 'Local Pickup',
                icon: Icons.location_on_rounded,
                filter: MarketplaceSmartFilter.localPickup,
              ),
              const SizedBox(width: 8),
              // Price Filter Summary/Action
              InkWell(
                onTap: () {
                  // Pull up price filter dialog or simple sheet
                },
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _maxPrice != null
                        ? AppColors.accentAmber.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: _maxPrice != null
                          ? AppColors.accentAmber
                          : Colors.white10,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.payments_rounded,
                        size: 14,
                        color: _maxPrice != null
                            ? AppColors.accentAmber
                            : Colors.white60,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _maxPrice == null
                            ? 'All Prices'
                            : 'Under ₦${_maxPrice!.toInt()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _maxPrice != null
                              ? AppColors.accentAmber
                              : _themeColor,
                          fontWeight: _maxPrice != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildSortActionChip(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickFilterChip({
    required String label,
    required IconData icon,
    required MarketplaceSmartFilter filter,
  }) {
    final isSelected = _activeFilters.contains(filter);
    return InkWell(
      onTap: () => setState(() {
        if (isSelected) {
          _activeFilters.remove(filter);
        } else {
          _activeFilters.add(filter);
        }
      }),
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: 250.ms,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondaryTeal.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? AppColors.secondaryTeal : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppColors.secondaryTeal : Colors.white60,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppColors.secondaryTeal : _themeColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortActionChip() {
    return PopupMenuButton<String>(
      onSelected: (val) => setState(() => _sortBy = val),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'newest', child: Text('Newest First')),
        const PopupMenuItem(value: 'price_asc', child: Text('Cheapest First')),
        const PopupMenuItem(value: 'price_desc', child: Text('Most Expensive')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            const Icon(Icons.sort_rounded, size: 14, color: Colors.white60),
            const SizedBox(width: 6),
            Text(
              _sortBy == 'newest' ? 'Newest' : 'Price',
              style: TextStyle(fontSize: 12, color: _themeColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedSection(
    AsyncValue<List<MarketplaceItem>> recommendedAsync,
  ) {
    return recommendedAsync.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryTeal,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Featured Drops',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: _themeColor,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${items.length} live',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, index) =>
                    _buildRecommendedCard(context, items[index]),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.secondaryTeal),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildRecommendedCard(BuildContext context, MarketplaceItem item) {
    final limitedLabel = _limitedDropLabel(item);
    return GestureDetector(
      onTap: () => context.push('/marketplace/detail', extra: item),
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Image background
              Positioned.fill(
                child: (() {
                  final formattedUrl = UrlValidator.formatImageUrl(item.imageUrl);
                  return (formattedUrl.isNotEmpty && UrlValidator.isValidUrl(formattedUrl))
                      ? CachedNetworkImage(
                          imageUrl: formattedUrl,
                          fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.white.withValues(alpha: 0.05),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.white.withValues(alpha: 0.05),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            size: 48,
                            color: Colors.white24,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.white.withValues(alpha: 0.05),
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          size: 48,
                          color: Colors.white24,
                        ),
                      );
                })(),
              ),
              // Gradient Overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.4),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (limitedLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.accentAmber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          limitedLabel,
                          style: const TextStyle(
                            color: AppColors.primaryInk,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 18,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          _formatCurrency(item.price),
                          style: const TextStyle(
                            color: AppColors.accentAmber,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ClipRRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: const Text(
                                'View Deal',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, MarketplaceItem item) {
    final boostedIds = ref.watch(boostedListingsProvider);
    final isBoosted = boostedIds.contains(item.id);
    final priceLabel = _formatCurrency(item.price);
    final limitedLabel = _limitedDropLabel(item);
    final timeLabel = timeago.format(item.createdAt);

    return GestureDetector(
      onTap: () => context.push('/marketplace/detail', extra: item),
      child: Container(
        decoration: BoxDecoration(
          color: _isDark ? AppColors.surfaceDarkElevated : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _borderSubtle),
          boxShadow: [
            BoxShadow(
              color: _isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: (() {
                      final formattedUrl = UrlValidator.formatImageUrl(item.imageUrl);
                      return (formattedUrl.isNotEmpty && UrlValidator.isValidUrl(formattedUrl))
                          ? CachedNetworkImage(
                              imageUrl: formattedUrl,
                              fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.white10,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.white.withValues(alpha: 0.05),
                              child: const Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 30,
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.white.withValues(alpha: 0.05),
                            child: const Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: 30,
                                color: Colors.white24,
                              ),
                            ),
                          );
                    })(),
                  ),
                ),
                if (isBoosted || limitedLabel != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isBoosted ? 'BOOSTED' : 'LIMITED',
                        style: TextStyle(
                          color: isBoosted
                              ? AppColors.accentAmber
                              : Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: _themeColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        priceLabel,
                        style: const TextStyle(
                          color: AppColors.accentAmber,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '· $timeLabel',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 8,
                        backgroundColor: AppColors.secondaryTeal,
                        child: Text(
                          item.sellerName.isNotEmpty
                              ? item.sellerName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.sellerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (item.reactions.isNotEmpty) ...[
                        _buildReactionPreview(item.reactions),
                        const SizedBox(width: 4),
                      ],
                      Icon(
                        Icons.favorite_border_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionPreview(Map<String, String> reactions) {
    // Get unique emojis and their counts
    final counts = <String, int>{};
    for (final emoji in reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTwo = sorted.take(2).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...topTwo.map(
          (e) => Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(e.key, style: const TextStyle(fontSize: 10)),
          ),
        ),
        if (reactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              '${reactions.length}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 9,
              ),
            ),
          ),
      ],
    );
  }

  List<String> _generateNegotiationReplies(MarketplaceItem item) {
    final snippet = item.description.trim();
    if (snippet.isEmpty) return [];
    final shortened = snippet.length > 60
        ? '${snippet.substring(0, 60)}…'
        : snippet;
    return ['Buyer: Is this still available?', 'Seller: $shortened'];
  }

  Widget _buildNegotiationThread(List<String> replies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: replies
          .take(2)
          .map(
            (reply) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Text(
                reply,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          )
          .toList(),
    );
  }

  bool _isLowStock(MarketplaceItem item) =>
      item.status.toLowerCase().contains('low') || item.price < 2500;

  bool _isOpenToHaggle(MarketplaceItem item) =>
      item.status.toLowerCase().contains('haggle') ||
      item.description.toLowerCase().contains('negotiable');

  bool _isInvoiceReady(MarketplaceItem item) =>
      item.status.toLowerCase().contains('invoice');

  bool _shouldShowLocalMeetup(MarketplaceItem item) =>
      item.category.toLowerCase() == 'dorm' ||
      item.category.toLowerCase() == 'services';

  String? _limitedDropLabel(MarketplaceItem item) {
    final remaining = item.createdAt
        .add(const Duration(hours: 8))
        .difference(DateTime.now());
    if (remaining.isNegative) return null;
    if (remaining.inHours >= 1) {
      return 'Limited drop · ${remaining.inHours}h ${remaining.inMinutes % 60}m left';
    }
    if (remaining.inMinutes > 0) {
      return 'Limited drop · ${remaining.inMinutes}m left';
    }
    return 'Limited drop · Ends soon';
  }

  Widget _buildInventoryDot() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
    );
  }

  Widget _buildCardMenu(MarketplaceItem item) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20, color: Colors.black54),
        onSelected: (value) {
          if (value == 'share') {
            _shareListing(item);
          } else if (value == 'boost') {
            _boostListing(item);
          } else if (value == 'react') {
            _showReactionTray(item);
          } else if (value == 'report') {
            _showReportDialog(context, item);
          } else if (value == 'block') {
            _blockSeller(context, item.sellerId);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'share', child: Text('Share listing')),
          const PopupMenuItem(value: 'boost', child: Text('Boost visibility')),
          const PopupMenuItem(value: 'react', child: Text('Add reaction')),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'report', child: Text('Report listing')),
          const PopupMenuItem(value: 'block', child: Text('Block seller')),
        ],
      ),
    );
  }

  void _shareListing(MarketplaceItem item) {
    final priceLabel = _formatCurrency(item.price);
    final text =
        'Check out this ${item.title} for $priceLabel on ABUAD Campus Marketplace!\n\n${item.description}';
    Share.share(text, subject: item.title);
  }

  Future<void> _boostListing(MarketplaceItem item) async {
    final repo = ref.read(marketplaceRepositoryProvider);
    try {
      await repo.boostItem(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing Boosted! 🚀 It will now appear at the top.'),
            backgroundColor: AppColors.secondaryTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to boost: $e')));
      }
    }
  }

  void _showReactionTray(MarketplaceItem item) {
    final reactions = ['🔥', '❤️', '👏', '😮', '😂', '👍'];
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Express your interest',
                style: TextStyle(
                  color: _themeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: reactions.map((emoji) {
                  final isSelected = item.reactions[userId] == emoji;
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await ref
                          .read(marketplaceRepositoryProvider)
                          .toggleReaction(item.id, userId, emoji);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.secondaryTeal.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.secondaryTeal
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCardActions(BuildContext context, MarketplaceItem item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share listing'),
              onTap: () {
                Navigator.pop(context);
                _shareListing(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign),
              title: const Text('Boost your listing'),
              onTap: () {
                Navigator.pop(context);
                _boostListing(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_emoticon),
              title: const Text('Add reaction'),
              onTap: () {
                Navigator.pop(context);
                _showReactionTray(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Report listing'),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(context, item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Block seller'),
              onTap: () {
                Navigator.pop(context);
                _blockSeller(context, item.sellerId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context, MarketplaceItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report listing'),
        content: const Text('Report this item for inappropriate content?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(
                this.context,
              ).showSnackBar(const SnackBar(content: Text('Report submitted')));
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _blockSeller(BuildContext context, String sellerId) async {
    final userRepo = ref.read(userRepositoryProvider);
    try {
      await userRepo.blockUser(sellerId);
      if (mounted) {
        ScaffoldMessenger.of(
          this.context,
        ).showSnackBar(const SnackBar(content: Text('Seller blocked')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          this.context,
        ).showSnackBar(SnackBar(content: Text('Error blocking seller: $e')));
      }
    }
  }

  Widget _buildNewDropsPill() {
    return Center(
      child: GestureDetector(
        onTap: _scrollToTop,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.secondaryTeal,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondaryTeal.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Text(
            'New drops • Tap to view',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String query) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            query.isEmpty ? 'No items yet' : 'No matching deals',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return MasonryGridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  List<MarketplaceItem> _applySmartFilters(List<MarketplaceItem> items) {
    var filtered = List<MarketplaceItem>.from(items);
    if (_activeFilters.contains(MarketplaceSmartFilter.verifiedDeals)) {
      filtered = filtered.where((item) => item.price <= 6000).toList();
    }
    if (_activeFilters.contains(MarketplaceSmartFilter.localPickup)) {
      filtered = filtered
          .where((item) => item.category == 'dorm' || item.category == 'books')
          .toList();
    }
    if (_activeFilters.contains(MarketplaceSmartFilter.campusEssentials)) {
      const essentials = {
        'books',
        'dorm',
        'services',
        'fashion',
        'electronics',
        'general',
      };
      filtered = filtered
          .where((item) => essentials.contains(item.category.toLowerCase()))
          .toList();
    }
    if (_activeFilters.contains(MarketplaceSmartFilter.mediaOnly)) {
      filtered = filtered.where((item) => item.images.isNotEmpty).toList();
    }
    return filtered;
  }

  void _updateDropIndicator(List<MarketplaceItem> items) {
    if (items.isEmpty) return;
    final topId = items.first.id;
    if (_lastTopItemId == null) {
      _lastTopItemId = topId;
      return;
    }
    if (topId != _lastTopItemId) {
      _lastTopItemId = topId;
      if (!_showNewDropsPill) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _showNewDropsPill = true);
        });
      }
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
    setState(() => _showNewDropsPill = false);
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sell an item'),
        content: const Text(
          'Share what you no longer need with the ABUAD community.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddMarketplaceItemScreen(),
                ),
              );
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showAccessibilitySheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                value: _largeFonts,
                title: const Text('Larger fonts'),
                subtitle: const Text(
                  'Increase text scale for better readability.',
                ),
                onChanged: (value) => setState(() => _largeFonts = value),
              ),
              SwitchListTile(
                value: _blindMode,
                title: const Text('Blind-mode summary'),
                subtitle: const Text(
                  'Show quick text-only previews for listings.',
                ),
                onChanged: (value) => setState(() => _blindMode = value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendingCategories(List<MarketplaceItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final counts = <String, int>{};
    for (final item in items) {
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }
    final trending = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final display = trending.take(4).toList();
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 6),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: display.length,
          itemBuilder: (context, index) {
            final entry = display[index];
            final highlight = index == 0;
            return Container(
              margin: EdgeInsets.only(
                right: index == display.length - 1 ? 0 : 8,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: highlight ? null : Colors.white10,
                gradient: highlight ? AppColors.inkTealGradient : null,
                borderRadius: BorderRadius.circular(20),
                border: highlight ? null : Border.all(color: Colors.white24),
              ),
              child: Text(
                '${_friendlyCategoryLabel(entry.key)} · ${entry.value}',
                style: TextStyle(
                  color: highlight ? Colors.white : Colors.grey[300],
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSellerHighlights(List<MarketplaceItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final sellers = <String, List<MarketplaceItem>>{};
    for (final item in items) {
      sellers.putIfAbsent(item.sellerId, () => []).add(item);
    }
    final highlights = sellers.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    final display = highlights.take(3).toList();
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 6, bottom: 4),
      child: SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: display.length,
          itemBuilder: (context, index) {
            final seller = display[index];
            final sample = seller.value.first;
            final gradient = index.isEven
                ? AppColors.inkTealGradient
                : AppColors.amberGradient;
            return Container(
              width: 180,
              margin: EdgeInsets.only(
                right: index == display.length - 1 ? 0 : 12,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    seller.value.first.sellerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${seller.value.length} listings',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    _friendlyCategoryLabel(sample.category),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(sample.price),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTrendingHashtagRow(List<MarketplaceItem> items) {
    final tags = items
        .map((item) => _formatHashtag(item.category))
        .toSet()
        .toList();
    if (tags.isEmpty) return const SizedBox.shrink();
    final limitedTags = tags.take(6).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: limitedTags.map((tag) {
          return Chip(
            label: Text(tag),
            backgroundColor: Colors.white10,
            labelStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            side: const BorderSide(color: Colors.white24),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBlindSummary(List<MarketplaceItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final preview = items.take(3).map((item) {
      final timeLabel = timeago.format(item.createdAt);
      return '${item.title} · ${_formatCurrency(item.price)} · $timeLabel';
    }).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Blind-mode summary',
              style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ...preview.map(
              (text) => Text(
                text,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyCategoryLabel(String category) {
    if (category.isEmpty) return 'General';
    return category
        .split('_')
        .map(
          (segment) => segment.isEmpty
              ? segment
              : '${segment[0].toUpperCase()}${segment.substring(1)}',
        )
        .join(' ');
  }

  String _formatCurrency(double amount) {
    final formatted = amount % 1 == 0
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '₦$formatted';
  }

  String _formatHashtag(String category) {
    final cleaned = category.replaceAll('_', '');
    if (cleaned.isEmpty) return '#ABUAD';
    final normalized =
        '${cleaned[0].toUpperCase()}${cleaned.substring(1).toLowerCase()}';
    return '#$normalized';
  }
}
