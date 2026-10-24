import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_validator.dart';
import '../../../core/widgets/verification_badge.dart';
import '../../user/data/user_repository.dart';
import '../../chat/data/chat_repository.dart';
import '../data/marketplace_repository.dart';

class SellerStorefrontScreen extends ConsumerStatefulWidget {
  final String sellerId;
  final String? initialSellerName;
  final String? initialSellerAvatar;

  const SellerStorefrontScreen({
    super.key,
    required this.sellerId,
    this.initialSellerName,
    this.initialSellerAvatar,
  });

  @override
  ConsumerState<SellerStorefrontScreen> createState() => _SellerStorefrontScreenState();
}

class _SellerStorefrontScreenState extends ConsumerState<SellerStorefrontScreen> {
  String _selectedCategory = 'all';
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF111827) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);

    final sellerAsync = ref.watch(userProvider(widget.sellerId));
    final itemsStream = ref.watch(marketplaceRepositoryProvider).watchItemsBySeller(widget.sellerId);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: backgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: innerBoxIsScrolled
                ? Text(
                    widget.initialSellerName ?? 'Seller Storefront',
                    style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
                  )
                : null,
            actions: [
              IconButton(
                icon: Icon(Icons.share_rounded, color: textPrimary, size: 20),
                onPressed: () {
                  final link = 'https://abuadapp.com.ng/store/${widget.sellerId}';
                  SharePlus.instance.share(
                    ShareParams(
                      text: 'Check out items on ${widget.initialSellerName ?? 'Seller'}\'s ABUAD storefront:\n$link',
                      subject: 'ABUAD Storefront',
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: sellerAsync.when(
                data: (seller) => _buildSellerHeader(seller, cardColor, textPrimary, textSecondary, isDark),
                loading: () => Center(
                  child: CircularProgressIndicator(color: AppColors.secondaryTeal),
                ),
                error: (error, stack) => _buildFallbackHeader(cardColor, textPrimary, textSecondary, isDark),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Listed Items',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _isGridView ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
                          color: textPrimary,
                          size: 22,
                        ),
                        onPressed: () => setState(() => _isGridView = !_isGridView),
                        tooltip: _isGridView ? 'Switch to List view' : 'Switch to Grid view',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: ['all', 'Fashion', 'Tech', 'Books', 'Housing', 'Services'].map((cat) {
                  final isSelected = _selectedCategory.toLowerCase() == cat.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat == 'all' ? 'All Items' : cat),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                      selectedColor: AppColors.secondaryTeal,
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : textSecondary,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],
        body: StreamBuilder<List<MarketplaceItem>>(
          stream: itemsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return Center(child: CircularProgressIndicator(color: AppColors.secondaryTeal));
            }

            final items = snapshot.data ?? [];
            final filteredItems = _selectedCategory == 'all'
                ? items
                : items.where((i) => i.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();

            if (filteredItems.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.checkroom_rounded, size: 36, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No items listed currently',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This student currently has no items available for sale in this category.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (_isGridView) {
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.68,
                ),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  return _buildProductCard(filteredItems[index], cardColor, textPrimary, textSecondary, isDark);
                },
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filteredItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildProductListTile(filteredItems[index], cardColor, textPrimary, textSecondary, isDark);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSellerHeader(AppUser? seller, Color cardColor, Color textPrimary, Color textSecondary, bool isDark) {
    final displayName = seller?.displayName ?? widget.initialSellerName ?? 'Seller Store';
    final avatar = seller?.avatarUrl ?? widget.initialSellerAvatar;
    final handle = seller?.handle ?? 'student';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), width: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.inkTealGradient,
                ),
              ),
              CircleAvatar(
                radius: 36,
                backgroundColor: cardColor,
                backgroundImage: (avatar != null && avatar.isNotEmpty && UrlValidator.isValidUrl(avatar))
                    ? CachedNetworkImageProvider(avatar)
                    : null,
                child: (avatar == null || avatar.isEmpty)
                    ? Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              if (seller?.verificationType != null && seller!.verificationType != 'NONE') ...[
                const SizedBox(width: 6),
                VerificationBadge(type: seller.verificationType, size: 16),
              ],
            ],
          ),
          Text(
            '@$handle ${seller?.department != null ? '· ${seller!.department}' : ''}',
            style: TextStyle(fontSize: 13, color: textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.person_outline_rounded, size: 16),
                label: const Text('View Profile'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textPrimary,
                  side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: () => context.push('/user/${widget.sellerId}'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: const Text('Chat with Seller'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryTeal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: () async {
                  final currentUser = ref.read(currentUserProvider).value;
                  final channelId = await ref.read(chatRepositoryProvider).createOrGetChannel(
                    widget.sellerId,
                    otherUserName: displayName,
                    otherUserAvatar: avatar,
                    currentUserName: currentUser?.displayName,
                    currentUserAvatar: currentUser?.avatarUrl,
                  );
                  if (mounted) {
                    context.push('/chat/$channelId');
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackHeader(Color cardColor, Color textPrimary, Color textSecondary, bool isDark) {
    return _buildSellerHeader(null, cardColor, textPrimary, textSecondary, isDark);
  }

  Widget _buildProductCard(MarketplaceItem item, Color cardColor, Color textPrimary, Color textSecondary, bool isDark) {
    return GestureDetector(
      onTap: () => context.push('/marketplace/detail', extra: item),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: SizedBox(
                  width: double.infinity,
                  child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: UrlValidator.formatImageUrl(item.imageUrl!),
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                          errorWidget: (_, __, ___) => const Center(child: Icon(Icons.shopping_bag_outlined, size: 36, color: Colors.grey)),
                        )
                      : const Center(child: Icon(Icons.shopping_bag_outlined, size: 36, color: Colors.grey)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '₦${item.price.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.accentAmber),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.category.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondaryTeal),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductListTile(MarketplaceItem item, Color cardColor, Color textPrimary, Color textSecondary, bool isDark) {
    return GestureDetector(
      onTap: () => context.push('/marketplace/detail', extra: item),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), width: 0.5),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 70,
                height: 70,
                child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: UrlValidator.formatImageUrl(item.imageUrl!),
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                        errorWidget: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, size: 28, color: Colors.grey),
                      )
                    : const Icon(Icons.shopping_bag_outlined, size: 28, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₦${item.price.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.accentAmber),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.category.toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryTeal),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
