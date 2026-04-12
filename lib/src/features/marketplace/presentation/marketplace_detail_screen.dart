import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/marketplace_repository.dart';
import '../../chat/data/chat_repository.dart';
import '../../user/data/user_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/verification_badge.dart';
import '../../../core/utils/url_validator.dart';
import '../../../shared/widgets/user_avatar.dart';

class MarketplaceDetailScreen extends ConsumerWidget {
  final MarketplaceItem item;

  const MarketplaceDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            flexibleSpace: FlexibleSpaceBar(
              background: item.images.isNotEmpty
                  ? Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        PageView.builder(
                          itemCount: item.images.length,
                          itemBuilder: (context, index) {
                            return (item.images[index].isNotEmpty &&
                                    UrlValidator.isValidUrl(item.images[index]))
                                ? CachedNetworkImage(
                                    imageUrl: item.images[index],
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
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : (item.imageUrl != null
                        ? (UrlValidator.isValidUrl(item.imageUrl)
                            ? CachedNetworkImage(
                                imageUrl: item.imageUrl!,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.image,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                              ))
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
                        color: Colors.grey.withOpacity(0.1),
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
                        onTap: () => context.push('/profile/${item.sellerId}'),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
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
                                      '@${seller.handle}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey[400],
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
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: isSeller
            ? FilledButton.icon(
                onPressed: () => _handleDelete(context, ref),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text(
                  'Delete Listing',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              )
            : FilledButton.icon(
                onPressed: () => _handleChat(context, ref),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.secondaryTeal,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text(
                  'Chat with Seller',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
      ),
    );
  }

  Future<void> _handleChat(BuildContext context, WidgetRef ref) async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final userRepo = ref.read(userRepositoryProvider);
      final currentUser = ref.read(currentUserProvider).value;

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
        context.push('/chat/$channelId');
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
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
}
