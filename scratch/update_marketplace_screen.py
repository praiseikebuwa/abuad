with open('lib/src/features/marketplace/presentation/marketplace_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add _isListView to _MarketplaceScreenState
old_state = """  bool _largeFonts = false;
  bool _blindMode = false;"""

new_state = """  bool _largeFonts = false;
  bool _blindMode = false;
  bool _isListView = false;"""

content = content.replace(old_state, new_state)

# 2. Replace accessibility button with View Mode Toggle button
old_access_btn = """                  IconButton(
                    icon: Icon(Icons.accessibility_new, color: _themeColor),
                    onPressed: _showAccessibilitySheet,
                  ),"""

new_access_btn = """                  IconButton(
                    icon: Icon(
                      _isListView ? Icons.grid_view_rounded : Icons.view_agenda_outlined,
                      color: _themeColor,
                    ),
                    tooltip: _isListView ? 'Switch to Grid View' : 'Switch to List View',
                    onPressed: () => setState(() => _isListView = !_isListView),
                  ),"""

content = content.replace(old_access_btn, new_access_btn)

# 3. Insert Trending Sellers story row before Featured Drops
old_slivers = """              SliverToBoxAdapter(
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
              ),"""

new_slivers = """              SliverToBoxAdapter(
                child: StreamBuilder<List<MarketplaceItem>>(
                  stream: itemsStream,
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        _buildUnifiedFilterBar(),
                        const SizedBox(height: 14),
                        if (items.isNotEmpty) _buildTrendingSellerStories(items),
                        const SizedBox(height: 14),
                        _buildRecommendedSection(recommendedAsync),
                        const SizedBox(height: 8),
                        if (items.isNotEmpty) ...[
                          _buildTrendingCategories(items),
                          _buildSellerHighlights(items),
                          _buildTrendingHashtagRow(items),
                        ],
                      ],
                    );
                  },
                ),
              ),"""

content = content.replace(old_slivers, new_slivers)

# 4. Support list view in body StreamBuilder
old_grid_slivers = """                      SliverPadding(
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
                      ),"""

new_grid_slivers = """                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: _isListView
                            ? SliverList.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) =>
                                    _buildListItemCard(context, items[index])
                                        .animate(delay: (index * 30).ms)
                                        .fadeIn(duration: 300.ms),
                              )
                            : SliverMasonryGrid.count(
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
                      ),"""

content = content.replace(old_grid_slivers, new_grid_slivers)

# 5. Make _buildTrendingCategories interactive
old_trending_cat = """            final entry = display[index];
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
            );"""

new_trending_cat = """            final entry = display[index];
            final isSelected = _selectedCategory.toLowerCase() == entry.key.toLowerCase();
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = isSelected ? 'all' : entry.key;
                });
              },
              child: AnimatedContainer(
                duration: 250.ms,
                margin: EdgeInsets.only(
                  right: index == display.length - 1 ? 0 : 8,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.secondaryTeal : (index == 0 ? null : Colors.white10),
                  gradient: (isSelected || index == 0) ? AppColors.inkTealGradient : null,
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected
                      ? Border.all(color: AppColors.secondaryTeal, width: 1.5)
                      : Border.all(color: Colors.white24),
                ),
                child: Text(
                  '${_friendlyCategoryLabel(entry.key)} · ${entry.value}',
                  style: TextStyle(
                    color: (isSelected || index == 0) ? Colors.white : Colors.grey[300],
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );"""

content = content.replace(old_trending_cat, new_trending_cat)

# 6. Make _buildTrendingHashtagRow interactive
old_hashtag_row = """        children: limitedTags.map((tag) {
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
        }).toList(),"""

new_hashtag_row = """        children: limitedTags.map((tag) {
          final cleanCat = tag.replaceAll('#', '').toLowerCase();
          final isSelected = _selectedCategory.toLowerCase() == cleanCat;
          return ActionChip(
            label: Text(tag),
            backgroundColor: isSelected ? AppColors.secondaryTeal : Colors.white10,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            side: BorderSide(color: isSelected ? AppColors.secondaryTeal : Colors.white24),
            onPressed: () {
              setState(() {
                _selectedCategory = isSelected ? 'all' : cleanCat;
              });
            },
          );
        }).toList(),"""

content = content.replace(old_hashtag_row, new_hashtag_row)

# 7. Add _buildTrendingSellerStories and _buildListItemCard methods
helper_code = """
  Widget _buildTrendingSellerStories(List<MarketplaceItem> items) {
    final sellersMap = <String, List<MarketplaceItem>>{};
    for (final item in items) {
      sellersMap.putIfAbsent(item.sellerId, () => []).add(item);
    }
    final sortedSellers = sellersMap.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    final displaySellers = sortedSellers.take(10).toList();

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
                  color: AppColors.accentAmber,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Trending Sellers',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: _themeColor,
                ),
              ),
              const Spacer(),
              Text(
                'Top verified stores',
                style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 98,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: displaySellers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final seller = displaySellers[index];
              final sampleItem = seller.value.first;
              final sellerName = sampleItem.sellerName.isNotEmpty ? sampleItem.sellerName : 'Seller';
              final firstWord = sellerName.split(' ').first;

              return GestureDetector(
                onTap: () {
                  context.push(
                    '/marketplace/seller/${seller.key}',
                    extra: {'name': sellerName, 'avatar': sampleItem.imageUrl},
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.inkTealGradient,
                          ),
                        ),
                        Container(
                          width: 55,
                          height: 55,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isDark ? Colors.black : Colors.white,
                          ),
                          child: ClipOval(
                            child: (sampleItem.imageUrl != null && sampleItem.imageUrl!.isNotEmpty)
                                ? CachedNetworkImage(
                                    imageUrl: UrlValidator.formatImageUrl(sampleItem.imageUrl!),
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(color: Colors.grey[800]),
                                    errorWidget: (_, __, ___) => Center(
                                      child: Text(
                                        firstWord.isNotEmpty ? firstWord[0].toUpperCase() : 'S',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      firstWord.isNotEmpty ? firstWord[0].toUpperCase() : 'S',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: AppColors.accentAmber,
                              shape: BoxShape.circle,
                              border: Border.all(color: _isDark ? Colors.black : Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.check, size: 8, color: AppColors.primaryInk),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 66,
                      child: Text(
                        firstWord,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _themeColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildListItemCard(BuildContext context, MarketplaceItem item) {
    return GestureDetector(
      onTap: () => context.push('/marketplace/detail', extra: item),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isDark ? AppColors.surfaceDarkElevated : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderSubtle),
          boxShadow: [
            BoxShadow(
              color: _isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 90,
                height: 90,
                child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: UrlValidator.formatImageUrl(item.imageUrl!),
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: Colors.white10),
                        errorWidget: (_, __, ___) => const Center(child: Icon(Icons.image_outlined, size: 30, color: Colors.white24)),
                      )
                    : const Center(child: Icon(Icons.image_outlined, size: 30, color: Colors.white24)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryTeal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.category.toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.secondaryTeal),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        timeago.format(item.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _themeColor),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatCurrency(item.price),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.accentAmber,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '· by ${item.sellerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
"""

last_brace = content.rfind('}')
content = content[:last_brace] + helper_code + "\n}\n"

with open('lib/src/features/marketplace/presentation/marketplace_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("marketplace_screen.dart updated successfully!")
