import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/cloud_storage_service.dart';
import '../../auth/data/auth_repository.dart';
import '../data/marketplace_repository.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../shared/presentation/unified_image_editor.dart';

class AddMarketplaceItemScreen extends ConsumerStatefulWidget {
  const AddMarketplaceItemScreen({super.key});

  @override
  ConsumerState<AddMarketplaceItemScreen> createState() =>
      _AddMarketplaceItemScreenState();
}

class _AddMarketplaceItemScreenState
    extends ConsumerState<AddMarketplaceItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'books';
  String _selectedCondition = 'Good';
  String _selectedLocation = 'Main Gate';
  final List<XFile> _imageFiles = [];
  bool _isLoading = false;
  bool _isGeneratingMagic = false;

  final List<Map<String, String>> _categories = [
    {'value': 'books', 'label': 'Books'},
    {'value': 'electronics', 'label': 'Electronics'},
    {'value': 'dorm', 'label': 'Dorm Extras'},
    {'value': 'lost_found', 'label': 'Lost & Found'},
    {'value': 'fashion', 'label': 'Fashion'},
    {'value': 'services', 'label': 'Services'},
  ];

  final List<String> _conditions = ['New', 'Like New', 'Good', 'Fair'];
  final List<String> _locations = [
    'Main Gate',
    'Cafeteria 1',
    'Cafeteria 2',
    'Sport Center',
    'Senate Building',
    'Dorm Entrance',
    'Law College',
    'Engineering College'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(
      maxWidth: 1024,
      imageQuality: 85,
    );

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _imageFiles.addAll(pickedFiles);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
    });
  }

  Future<void> _editImage(int index) async {
    final file = _imageFiles[index];
    if (kIsWeb) return;
    final edited = await UnifiedImageEditor.open(context, file: File(file.path));
    if (edited != null && mounted) {
      setState(() {
        _imageFiles[index] = edited;
      });
      _showGlimpsePreview();
    }
  }

  Future<void> _generateMagicDraft() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title first ✨')),
      );
      return;
    }

    setState(() => _isGeneratingMagic = true);
    
    // Simulate complex AI drafting
    await Future.delayed(const Duration(seconds: 2));
    
    final title = _titleController.text;
    final cat = _selectedCategory;
    final condition = _selectedCondition;

    final draft = "✨ SPECIAL LISTING: $title\n\n"
        "This $cat is in $condition condition and ready for a new owner. "
        "Perfect for students looking for quality items at a great price.\n\n"
        "📍 Pickup Location: $_selectedLocation\n"
        "⚡ Fast delivery to campus dorms can also be discussed.";

    _descriptionController.text = draft;
    setState(() => _isGeneratingMagic = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Magic Draft applied! ✨')),
      );
    }
  }

  void _showGlimpsePreview() {
    if (_imageFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one photo for a preview 📸')),
      );
      return;
    }

    final tempItem = MarketplaceItem(
      id: 'preview',
      title: _titleController.text.isEmpty ? 'Untitled Item' : _titleController.text,
      description: _descriptionController.text,
      price: double.tryParse(_priceController.text) ?? 0.0,
      category: _selectedCategory,
      condition: _selectedCondition,
      location: _selectedLocation,
      sellerId: 'preview_user',
      sellerName: 'Your Name (Preview)',
      images: _imageFiles.map((f) => f.path).toList(), // local paths for preview
      createdAt: DateTime.now(),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark.withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              )
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Glimpse Preview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This is how other students will see your listing',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 200,
                    child: _buildPreviewItemCard(tempItem),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.secondaryTeal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Back to Editing'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewItemCard(MarketplaceItem item) {
    // Miniature version of MarketplaceItemCard logic
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: kIsWeb
                      ? NetworkImage(item.images.first)
                      : FileImage(File(item.images.first)) as ImageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '₦${item.price.toStringAsFixed(0)}',
                  style: TextStyle(color: AppColors.secondaryTeal, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      var user = authRepo.currentUser ?? ref.read(currentUserProvider).value;
      if (user == null) {
        await authRepo.init();
        user = authRepo.currentUser ?? ref.read(currentUserProvider).value;
      }
      if (user == null) throw Exception('You must be logged in');

      // 1. Upload Images
      final storage = CloudStorageService();
      final List<String> imageUrls = [];

      for (var file in _imageFiles) {
        final String imageId = const Uuid().v4();
        final url = await storage.uploadImage(
          file,
          path: 'marketplace/${user.uid}/$imageId',
        );
        imageUrls.add(url);
      }

      // 2. Create Item Model
      final item = MarketplaceItem(
        id: '', // Will be generated by repo
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.replaceAll(',', '')),
        category: _selectedCategory,
        condition: _selectedCondition,
        location: _selectedLocation,
        sellerId: user.uid,
        sellerName: user.displayName,
        images: imageUrls,
        createdAt: DateTime.now(),
        status: 'available',
      );

      // 3. Save to backend
      await ref.read(marketplaceRepositoryProvider).addItem(item);

      if (mounted) {
        context.pop(); // Close screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item listed successfully! 🚀'),
            backgroundColor: AppColors.secondaryTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildGlassCard({required Widget child, String? title, Widget? action}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF04060E), Color(0xFF0A1128)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('New Listing', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => context.pop(),
          ),
          actions: [
            TextButton.icon(
              onPressed: _showGlimpsePreview,
              icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.secondaryTeal),
              label: const Text('Glimpse', style: TextStyle(color: AppColors.secondaryTeal)),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.secondaryTeal))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Photo Section
                      _buildGlassCard(
                        title: 'GALLERY',
                        child: SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _imageFiles.length + 1,
                            itemBuilder: (context, index) {
                              if (index == _imageFiles.length) {
                                return _buildAddPhotoButton();
                              }
                              return _buildImageThumbnail(index);
                            },
                          ),
                        ),
                      ),

                      // Title & Price Section
                      _buildGlassCard(
                        title: 'CORE DETAILS',
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _titleController,
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                              decoration: _glassInputDecoration('What are you selling?', Icons.shopping_bag_outlined),
                              validator: (v) => v!.isEmpty ? 'Title is required' : null,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _priceController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: AppColors.secondaryTeal, fontSize: 24, fontWeight: FontWeight.w900),
                              decoration: _glassInputDecoration('Price (₦)', Icons.payments_outlined),
                              validator: (v) => v!.isEmpty ? 'Price is required' : null,
                            ),
                          ],
                        ),
                      ),

                      // Category & Condition
                      _buildGlassCard(
                        title: 'SPECIFICATIONS',
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _selectedCategory,
                              dropdownColor: AppColors.surfaceDark,
                              style: const TextStyle(color: Colors.white),
                              decoration: _glassInputDecoration('Category', Icons.category_outlined),
                              items: _categories.map((c) => DropdownMenuItem(value: c['value'], child: Text(c['label']!))).toList(),
                              onChanged: (v) => setState(() => _selectedCategory = v!),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<String>(
                                style: SegmentedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                                  selectedBackgroundColor: AppColors.secondaryTeal,
                                  foregroundColor: Colors.white,
                                  selectedForegroundColor: Colors.white,
                                  side: BorderSide.none,
                                ),
                                segments: _conditions.map((c) => ButtonSegment(value: c, label: Text(c, style: const TextStyle(fontSize: 10)))).toList(),
                                selected: {_selectedCondition},
                                onSelectionChanged: (v) => setState(() => _selectedCondition = v.first),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // AI Description Section
                      _buildGlassCard(
                        title: 'DESCRIPTION',
                        action: _isGeneratingMagic 
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                          : GestureDetector(
                              onTap: _generateMagicDraft,
                              child: const Text('✨ MAGIC DRAFT', style: TextStyle(color: AppColors.secondaryTeal, fontSize: 10, fontWeight: FontWeight.w900)),
                            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2000.ms),
                        child: TextFormField(
                          controller: _descriptionController,
                          maxLines: 6,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Tell students more about your item...',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                            border: InputBorder.none,
                          ),
                          validator: (v) => v!.isEmpty ? 'Description is required' : null,
                        ),
                      ),

                      // Location Picker
                      _buildGlassCard(
                        title: 'PICKUP LOCATION',
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedLocation,
                          dropdownColor: AppColors.surfaceDark,
                          style: const TextStyle(color: Colors.white),
                          decoration: _glassInputDecoration('Safe Meeting Point', Icons.place_outlined),
                          items: _locations.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                          onChanged: (v) => setState(() => _selectedLocation = v!),
                        ),
                      ),

                      const SizedBox(height: 24),
                      
                      // Final Action
                      FilledButton(
                        onPressed: _submitItem,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.secondaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('PUBLISH LISTING', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                            SizedBox(width: 8),
                            Icon(Icons.rocket_launch_rounded),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildAddPhotoButton() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: AppColors.secondaryTeal, size: 32),
            SizedBox(height: 8),
            Text('Add Photos', style: TextStyle(color: AppColors.secondaryTeal, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildImageThumbnail(int index) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: kIsWeb
                ? Image.network(_imageFiles[index].path, fit: BoxFit.cover)
                : Image.file(File(_imageFiles[index].path), fit: BoxFit.cover),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: _circleActionButton(Icons.close, () => _removeImage(index), Colors.black54),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: _circleActionButton(Icons.brush, () => _editImage(index), AppColors.secondaryTeal.withValues(alpha: 0.8)),
          ),
        ],
      ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
    );
  }

  Widget _circleActionButton(IconData icon, VoidCallback onTap, Color bgColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }

  InputDecoration _glassInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
      prefixIcon: Icon(icon, color: AppColors.secondaryTeal, size: 20),
      border: InputBorder.none,
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.secondaryTeal)),
    );
  }
}

