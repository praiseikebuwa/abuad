import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../data/marketplace_repository.dart';
import '../../chat/data/chat_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/verification_badge.dart';
import '../../../core/utils/url_validator.dart';
import '../../../shared/widgets/user_avatar.dart';

class MarketplaceDetailScreen extends ConsumerStatefulWidget {
  final MarketplaceItem? item;
  final String? itemId;

  const MarketplaceDetailScreen({
    super.key,
    this.item,
    this.itemId,
  });

  @override
  ConsumerState<MarketplaceDetailScreen> createState() => _MarketplaceDetailScreenState();
}

class _MarketplaceDetailScreenState extends ConsumerState<MarketplaceDetailScreen> {
  MarketplaceItem? _item;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    if (_item == null && widget.itemId != null) {
      _loadItem();
    }
  }

  Future<void> _loadItem() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fetched = await ref
          .read(marketplaceRepositoryProvider)
          .getItemById(widget.itemId!);

      if (mounted) {
        if (fetched != null) {
          setState(() {
            _item = fetched;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Item not found or has been removed.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load item: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _shareItem(MarketplaceItem item) {
    final link = 'https://abuadapp.com.ng/marketplace/detail?id=${item.id}';
    final text =
        '🛍️ ${item.title}\n💰 Price: ₦${item.price.toStringAsFixed(0)}\n\n${item.description.isNotEmpty ? '${item.description}\n\n' : ''}Check out this item on ABUAD Campus Marketplace:\n$link';
    SharePlus.instance.share(ShareParams(text: text, subject: item.title));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.secondaryTeal),
        ),
      );
    }

    if (_errorMessage != null || _item == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/marketplace');
              }
            },
          ),
          title: const Text('Item Not Found'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storefront_rounded, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Marketplace item could not be found.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go('/marketplace');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryTeal,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Go to Marketplace'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final item = _item!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider).value;
    final isSeller = currentUser?.uid == item.sellerId;
    final sellerAsync = ref.watch(userProvider(item.sellerId));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                ),
                tooltip: 'Share listing',
                onPressed: () => _shareItem(item),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: item.images.isNotEmpty
                  ? Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        PageView.builder(
                          itemCount: item.images.length,
                          itemBuilder: (context, index) {
                            final rawUrl = item.images[index];
                            final formattedUrl = UrlValidator.formatImageUrl(rawUrl);
                            return (formattedUrl.isNotEmpty &&
                                    UrlValidator.isValidUrl(formattedUrl))
                                ? CachedNetworkImage(
                                    imageUrl: formattedUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    placeholder: (context, url) => Container(
                                      color: Colors.black12,
                                      child: const Center(
                                          child: CircularProgressIndicator()),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      color: Colors.black12,
                                      child: const Icon(Icons.image, size: 48),
                                    ),
                                  )
                                : Container(
                                    color: Colors.black12,
                                    child: const Icon(Icons.image, size: 48),
                                  );
                          },
                        ),
                        if (item.images.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                item.images.length,
                                (index) => Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : (item.imageUrl != null
                        ? (() {
                            final formattedUrl = UrlValidator.formatImageUrl(item.imageUrl);
                            return (formattedUrl.isNotEmpty && UrlValidator.isValidUrl(formattedUrl))
                                ? CachedNetworkImage(
                                    imageUrl: formattedUrl,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.image,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                  );
                          })()
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.image,
                              size: 64,
                              color: Colors.grey,
                            ),
                          )),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentAmber,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '₦${item.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () =>
                        context.push('/marketplace?category=${item.category}'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Description',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.description,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Seller Information',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  sellerAsync.when(
                    data: (seller) {
                      if (seller == null) {
                        return const Text('Seller info unavailable');
                      }
                      return GestureDetector(
                        onTap: () => _showSellerOptionsSheet(context, seller, item),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey[200]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              UserAvatar(
                                userId: item.sellerId,
                                avatarUrl: seller.avatarUrl,
                                displayName: seller.displayName,
                                radius: 25,
                                showStoryRing: true,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          seller.displayName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (seller.verificationType !=
                                            'none') ...[
                                          const SizedBox(width: 4),
                                          VerificationBadge(
                                            type: seller.verificationType,
                                            size: 14,
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      '@${seller.handle} · Tap to view store or profile',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryTeal.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.storefront_rounded, size: 14, color: AppColors.secondaryTeal),
                                    SizedBox(width: 4),
                                    Text(
                                      'Store',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryTeal),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Text('Error loading seller: $e'),
                  ),
                  const SizedBox(height: 100), // Space for bottom button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            OutlinedButton(
              onPressed: () => _shareItem(item),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : AppColors.primaryInk,
                side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                minimumSize: const Size(54, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Icon(Icons.share_rounded, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isSeller
                  ? FilledButton.icon(
                      onPressed: () => _handleDelete(context, ref),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline, color: Colors.white),
                      label: const Text(
                        'Delete Listing',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: () => _handleChat(context, ref),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondaryTeal,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                      label: const Text(
                        'Chat with Seller',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleChat(BuildContext context, WidgetRef ref) async {
    final item = _item;
    if (item == null) return;

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final userRepo = ref.read(userRepositoryProvider);
      final authRepo = ref.read(authRepositoryProvider);
      var currentUser = authRepo.currentUser ?? ref.read(currentUserProvider).value;
      if (currentUser == null) {
        await authRepo.init();
        if (!context.mounted) return;
        currentUser = authRepo.currentUser ?? ref.read(currentUserProvider).value;
      }

      if (currentUser == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please log in to chat')));
        return;
      }

      if (currentUser.uid == item.sellerId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You cannot chat with yourself')),
        );
        return;
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final seller = await userRepo.getUserById(item.sellerId);
      if (seller == null) throw Exception('Seller not found');

      final channelId = await chatRepo.createOrGetChannel(
        seller.uid,
        otherUserName: seller.displayName,
        otherUserAvatar: seller.avatarUrl,
        currentUserName: currentUser.displayName,
        currentUserAvatar: currentUser.avatarUrl,
      );

      if (context.mounted) {
        Navigator.pop(context); // Pop loading
        context.push('/chat/$channelId', extra: item);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting chat: $e')));
      }
    }
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final item = _item;
    if (item == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Listing'),
        content: const Text(
          'Are you sure you want to permanently delete this product?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await ref.read(marketplaceRepositoryProvider).deleteItem(item.id);
        if (context.mounted) {
          Navigator.pop(context); // Pop loading
          context.pop(); // Go back to marketplace
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Listing deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Pop loading
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting listing: $e')));
        }
      }
    }
  }

  void _showSellerOptionsSheet(BuildContext context, AppUser seller, MarketplaceItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.black : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  seller.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                Text(
                  '@${seller.handle} · Campus Marketplace Seller',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: AppColors.secondaryTeal),
                  ),
                  title: const Text('View Storefront & Clothes / Items', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('See all active products listed by ${seller.displayName}', style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(
                      '/marketplace/seller/${item.sellerId}',
                      extra: {'name': seller.displayName, 'avatar': seller.avatarUrl},
                    );
                  },
                ),
                const SizedBox(height: 6),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accentAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_outline_rounded, color: AppColors.accentAmber),
                  ),
                  title: const Text('View Student Profile', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('View bio, posts, and campus activities', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/user/${item.sellerId}');
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }
}
