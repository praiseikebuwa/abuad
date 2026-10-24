import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_validator.dart';
import '../../auth/data/auth_repository.dart';
import '../../marketplace/data/marketplace_repository.dart';
import '../domain/advertisement.dart';
import '../data/advertisement_repository.dart';
import 'widgets/sponsored_ad_card.dart';

class CreateAdvertisementScreen extends ConsumerStatefulWidget {
  const CreateAdvertisementScreen({super.key});

  @override
  ConsumerState<CreateAdvertisementScreen> createState() =>
      _CreateAdvertisementScreenState();
}

class _CreateAdvertisementScreenState
    extends ConsumerState<CreateAdvertisementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetUrlController = TextEditingController();
  final _mediaUrlController = TextEditingController();

  final Set<String> _selectedPlacements = {'feed', 'story', 'marketplace'};
  String _ctaLabel = 'Visit Website';
  int _durationDays = 7;
  bool _isPromotingMarketplaceItem = false;
  MarketplaceItem? _selectedMarketplaceItem;
  XFile? _pickedMedia;
  bool _isPublishing = false;
  int _previewTab = 0; // 0: Feed, 1: Story, 2: Marketplace

  final List<String> _ctaOptions = [
    'Visit Website',
    'Shop Now',
    'Learn More',
    'Order Now',
    'Contact Seller',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetUrlController.dispose();
    _mediaUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) {
      setState(() {
        _pickedMedia = file;
        _mediaUrlController.text = file.path;
      });
    }
  }

  void _onMarketplaceItemSelected(MarketplaceItem item) {
    setState(() {
      _selectedMarketplaceItem = item;
      _titleController.text = item.title;
      _descriptionController.text = item.description;
      if (item.images.isNotEmpty) {
        _mediaUrlController.text = item.images.first;
      }
      _ctaLabel = 'Shop Now';
      if (_targetUrlController.text.isEmpty) {
        _targetUrlController.text = 'https://abuad.edu.ng/marketplace/${item.id}';
      }
    });
  }

  Future<void> _submitAd() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPlacements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one placement (Feed, Story, or Marketplace).'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final mediaPath = _mediaUrlController.text.trim();
    if (mediaPath.isEmpty && _pickedMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or upload an image banner for your advertisement.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.stars_rounded, color: AppColors.secondaryTeal),
            SizedBox(width: 8),
            Text('Coming Soon'),
          ],
        ),
        content: const Text(
          'Live campaign creation & payment processing are paused for now and will be unlocked in an upcoming update! Your placement preview is ready.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continue Previewing'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;

    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      final appUser = user != null
          ? await ref.read(userRepositoryProvider).getUserById(user.uid)
          : null;

      final advertiserName = appUser?.displayName ?? 'ABUAD Advertiser';
      final advertiserAvatar = appUser?.avatarUrl;
      final advertiserId = user?.uid ?? 'anon_advertiser';

      await ref.read(advertisementRepositoryProvider).createAdvertisement(
            advertiserId: advertiserId,
            advertiserName: advertiserName,
            advertiserAvatarUrl: advertiserAvatar,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            mediaUrl: mediaPath.isNotEmpty
                ? mediaPath
                : 'https://images.unsplash.com/photo-1523381210434-271e8be1f52b?w=800',
            targetUrl: _targetUrlController.text.trim(),
            marketplaceItemId: _selectedMarketplaceItem?.id,
            marketplaceItemTitle: _selectedMarketplaceItem?.title,
            marketplaceItemPrice: _selectedMarketplaceItem?.price,
            ctaLabel: _ctaLabel,
            placements: _selectedPlacements.toList(),
            durationDays: _durationDays,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.rocket_launch, color: Colors.greenAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🎉 Advertisement launched successfully across selected placements!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF0F172A),
            duration: Duration(seconds: 4),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish ad: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Advertisement _buildDummyPreviewAd() {
    return Advertisement(
      advertiserId: 'preview_user',
      advertiserName: 'Your Brand / Profile',
      title: _titleController.text.isNotEmpty
          ? _titleController.text
          : 'Your Compelling Headline Here',
      description: _descriptionController.text.isNotEmpty
          ? _descriptionController.text
          : 'High-visibility advertisement displayed directly to ABUAD students and campus community.',
      mediaUrl: _mediaUrlController.text.isNotEmpty
          ? _mediaUrlController.text
          : 'https://images.unsplash.com/photo-1523381210434-271e8be1f52b?w=800',
      targetUrl: _targetUrlController.text.isNotEmpty
          ? _targetUrlController.text
          : 'https://abuad.edu.ng',
      ctaLabel: _ctaLabel,
      marketplaceItemTitle: _selectedMarketplaceItem?.title,
      marketplaceItemPrice: _selectedMarketplaceItem?.price,
      placements: _selectedPlacements.toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? Colors.black : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF111111) : Colors.white;
    final borderColor = isDark ? const Color(0xFF222222) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Create Advertisement',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _isPublishing ? null : _submitAd,
              icon: _isPublishing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: const Text('Publish Ad', style: TextStyle(fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.secondaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview / Coming Soon notice
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: Color(0xFFF59E0B), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Campaign Creation & Payments are paused and coming soon in an upcoming update! Feel free to design and preview your placements.',
                        style: TextStyle(
                          color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Placement Selection Header
              Text(
                'Where would you like to advertise?',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select 1, 2, or all 3 placements for maximum campus reach:',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),

              // Placement cards
              Row(
                children: [
                  _buildPlacementTile(
                    title: 'Feed Post',
                    subtitle: 'In Campus Feed',
                    icon: Icons.dynamic_feed_rounded,
                    id: 'feed',
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildPlacementTile(
                    title: 'Story',
                    subtitle: 'Extended status',
                    icon: Icons.play_circle_fill_rounded,
                    id: 'story',
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildPlacementTile(
                    title: 'Marketplace',
                    subtitle: 'Featured banner',
                    icon: Icons.storefront_rounded,
                    id: 'marketplace',
                    isDark: isDark,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Marketplace Clothes / Product Linking Toggle
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accentAmber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.checkroom_rounded,
                              color: AppColors.accentAmber, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Promote Marketplace Clothes / Item',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                ),
                              ),
                              Text(
                                'Link a listing from campus marketplace',
                                style: TextStyle(color: textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isPromotingMarketplaceItem,
                          activeThumbColor: AppColors.secondaryTeal,
                          onChanged: (val) {
                            setState(() {
                              _isPromotingMarketplaceItem = val;
                              if (!val) _selectedMarketplaceItem = null;
                            });
                          },
                        ),
                      ],
                    ),

                    if (_isPromotingMarketplaceItem) ...[
                      const Divider(height: 20),
                      Consumer(
                        builder: (context, ref, child) {
                          final itemsAsync = ref.watch(marketplaceItemsProvider);
                          return itemsAsync.when(
                            data: (items) {
                              if (items.isEmpty) {
                                return Text(
                                  'No marketplace listings found. Enter product details manually below.',
                                  style: TextStyle(color: textSecondary, fontSize: 12.5),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Select a product to promote:',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 100,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: items.take(10).length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(width: 10),
                                      itemBuilder: (context, idx) {
                                        final item = items[idx];
                                        final isSelected =
                                            _selectedMarketplaceItem?.id == item.id;
                                        return InkWell(
                                          onTap: () => _onMarketplaceItemSelected(item),
                                          borderRadius: BorderRadius.circular(10),
                                          child: Container(
                                            width: 140,
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppColors.secondaryTeal.withValues(alpha: 0.15)
                                                  : (isDark ? Colors.black : Colors.grey[100]),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isSelected
                                                    ? AppColors.secondaryTeal
                                                    : borderColor,
                                                width: isSelected ? 1.8 : 1,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.title,
                                                  style: TextStyle(
                                                    color: textPrimary,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '₦${item.price.toInt()}',
                                                  style: const TextStyle(
                                                    color: AppColors.secondaryTeal,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  item.category.toUpperCase(),
                                                  style: TextStyle(
                                                    color: textSecondary,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) => const SizedBox.shrink(),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Ad Media Banner Upload
              Text(
                'Advertisement Banner / Media',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: borderColor,
                      style: BorderStyle.solid,
                      width: 1.2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _pickedMedia != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            kIsWeb
                                ? Image.network(_pickedMedia!.path, fit: BoxFit.cover)
                                : Image.file(File(_pickedMedia!.path), fit: BoxFit.cover),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.black.withValues(alpha: 0.6),
                                radius: 16,
                                child: IconButton(
                                  icon: const Icon(Icons.edit, size: 14, color: Colors.white),
                                  onPressed: _pickImage,
                                ),
                              ),
                            ),
                          ],
                        )
                      : (_mediaUrlController.text.isNotEmpty &&
                              UrlValidator.isValidUrl(_mediaUrlController.text))
                          ? Image.network(_mediaUrlController.text, fit: BoxFit.cover)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 40,
                                  color: AppColors.secondaryTeal,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to upload high-res photo / banner',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                                Text(
                                  'Supports PNG, JPG, or web banner URL',
                                  style: TextStyle(color: textSecondary, fontSize: 11.5),
                                ),
                              ],
                            ),
                ),
              ),

              const SizedBox(height: 10),

              // Media URL manual fallback input
              TextFormField(
                controller: _mediaUrlController,
                style: TextStyle(color: textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: 'Or enter Banner Image URL (optional)',
                  labelStyle: TextStyle(color: textSecondary),
                  hintText: 'https://images.unsplash.com/...',
                  filled: true,
                  fillColor: surfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 20),

              // Title / Headline
              TextFormField(
                controller: _titleController,
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Advertisement Headline *',
                  labelStyle: TextStyle(color: textSecondary),
                  hintText: 'e.g. 50% Off Campus Thrift Hoodies & Shoes!',
                  filled: true,
                  fillColor: surfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Headline is required.';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 14),

              // Description / Body Copy
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Advertisement Description *',
                  labelStyle: TextStyle(color: textSecondary),
                  hintText: 'Explain your offer, hostel delivery, or services...',
                  filled: true,
                  fillColor: surfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Description is required.';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 14),

              // Destination Website / Action URL
              TextFormField(
                controller: _targetUrlController,
                keyboardType: TextInputType.url,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Destination Website or WhatsApp URL *',
                  labelStyle: TextStyle(color: textSecondary),
                  hintText: 'https://yourwebsite.com or https://wa.me/...',
                  prefixIcon: const Icon(Icons.link, color: AppColors.secondaryTeal),
                  filled: true,
                  fillColor: surfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Destination link is required so students can tap to visit.';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 16),

              // Call-To-Action Button selector & Duration
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _ctaLabel,
                      dropdownColor: surfaceColor,
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Action Button',
                        labelStyle: TextStyle(color: textSecondary),
                        filled: true,
                        fillColor: surfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: borderColor),
                        ),
                      ),
                      items: _ctaOptions
                          .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _ctaLabel = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _durationDays,
                      dropdownColor: surfaceColor,
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Campaign Duration',
                        labelStyle: TextStyle(color: textSecondary),
                        filled: true,
                        fillColor: surfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: borderColor),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 3, child: Text('3 Days')),
                        DropdownMenuItem(value: 7, child: Text('7 Days (Popular)')),
                        DropdownMenuItem(value: 14, child: Text('14 Days')),
                        DropdownMenuItem(value: 30, child: Text('30 Days (Extended)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _durationDays = val);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Live Preview Section
              Text(
                'Live Advertisement Preview',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    // Preview Tabs
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          _buildPreviewTabButton(0, 'Feed Post Preview'),
                          _buildPreviewTabButton(1, 'Marketplace Preview'),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    SponsoredAdCard(
                      ad: _buildDummyPreviewAd(),
                      isCompact: _previewTab == 1,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isPublishing ? null : _submitAd,
                  icon: _isPublishing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.rocket_launch_rounded, color: Colors.white),
                  label: Text(
                    _isPublishing
                        ? 'Publishing Campaign...'
                        : 'Publish Advertisement (Coming Soon)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryTeal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlacementTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required String id,
    required bool isDark,
  }) {
    final isSelected = _selectedPlacements.contains(id);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (isSelected) {
              if (_selectedPlacements.length > 1) {
                _selectedPlacements.remove(id);
              }
            } else {
              _selectedPlacements.add(id);
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.secondaryTeal.withValues(alpha: isDark ? 0.2 : 0.1)
                : (isDark ? const Color(0xFF111111) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.secondaryTeal
                  : (isDark ? const Color(0xFF222222) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppColors.secondaryTeal
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                size: 24,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.secondaryTeal
                      : (isDark ? Colors.white : Colors.black87),
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                size: 16,
                color: isSelected ? AppColors.secondaryTeal : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewTabButton(int index, String label) {
    final isSelected = _previewTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _previewTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.secondaryTeal.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.secondaryTeal : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}
