import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../user/data/user_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/services/firebase_storage_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:async';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController(); // Added Name Controller
  final _bioController = TextEditingController(); // Added Bio Controller
  String? _department;
  String? _college;
  XFile? _pickedFile;
  bool _isLoading = false;

  @override
  @override
  void initState() {
    super.initState();
    // Pre-fill name if available
    final user = ref.read(authRepositoryProvider).currentUser;
    final displayName = user?.displayName;
    if (displayName != null && displayName.isNotEmpty) {
      _nameController.text = displayName;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  final List<String> _colleges = [
    'Engineering',
    'Law',
    'Sciences',
    'Social & Management Sciences',
    'Medicine & Health Sciences',
    'Arts & Humanities',
    'Agriculture',
    'Education',
    'Environmental Sciences',
  ];

  final Map<String, List<String>> _departments = {
    'Engineering': [
      'Computer',
      'Electrical',
      'Mechanical',
      'Civil',
      'Mechatronics',
      'Chemical',
      'Biomedical',
      'Aeronautical',
      'Petroleum',
    ],
    'Law': ['Law'],
    'Sciences': [
      'Computer Science',
      'Cyber Security',
      'Biochemistry',
      'Software Engineering',
      'Data Science',
      'Geology',
    ],
    'Social & Management Sciences': [
      'Accounting',
      'Business Admin',
      'Economics',
      'Pol-Science',
      'Media',
      'Sociology',
      'Banking & Finance',
      'Marketing',
      'Public Admin',
    ],
    'Medicine & Health Sciences': [
      'Medicine',
      'Nursing',
      'MLS',
      'Anatomy',
      'Physiology',
      'Public Health',
      'Pharmacy',
      'Radiography',
      'Optometry',
    ],
    'Arts & Humanities': [
      'History',
      'English',
      'Philosophy',
      'Linguistics',
      'Religious Studies',
    ],
    'Agriculture': [
      'Animal Science',
      'Crop Science',
      'Agricultural Economics',
    ],
    'Education': [
      'Guidance & Counseling',
      'Educational Management',
      'Physical & Health Education',
    ],
    'Environmental Sciences': [
      'Architecture',
      'Estate Management',
      'Quantity Surveying',
      'Urban & Regional Planning',
    ],
  };

  List<String> get _availableDepartments {
    if (_college == null) return [];
    return _departments[_college] ?? [];
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _pickedFile = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_department == null || _college == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select College and Department')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final userRepo = ref.read(userRepositoryProvider);
      final storage = FirebaseStorageService();

      final currentUser = authRepo.currentUser;
      if (currentUser == null) return;

      String? photoUrl;
      if (_pickedFile != null) {
        photoUrl = await storage.uploadImage(
          _pickedFile!,
          path: 'profile_images/${currentUser.uid}/',
        );
      }

      debugPrint('🔍 Fetching existing user for ${currentUser.uid}...');
      final existingUser = await userRepo
          .getUserById(currentUser.uid)
          .timeout(const Duration(seconds: 8));
      debugPrint('✅ Fetched existing user: ${existingUser?.handle}');
      String? handle = existingUser?.handle;

      if (handle == null || handle.isEmpty) {
        debugPrint(
          '🔍 Generating handle for ${_nameController.text.trim()}...',
        );
        handle = await userRepo
            .generateHandle(_nameController.text.trim())
            .timeout(const Duration(seconds: 8));
        debugPrint('✅ Generated handle: $handle');
      }

      debugPrint('📝 Updating user profile in Firestore...');
      await userRepo
          .updateUser(currentUser.uid, {
            'display_name': _nameController.text.trim(),
            'handle': handle,
            'email': currentUser.email ?? '',
            'phone_number': _phoneController.text.trim(),
            'college': _college,
            'department': _department,
            'bio': _bioController.text.trim(),
            'avatar_url': photoUrl,
          })
          .timeout(const Duration(seconds: 8));
      debugPrint('✅ Firestore update successful!');

      // Force refresh of the user provider to ensure the navigation guard
      // in ScaffoldWithBottomNav sees the updated data immediately.
      debugPrint('⏳ Refreshing user provider...');
      ref.invalidate(currentUserProvider);
      // Wait for the next value to be emitted by the StreamProvider
      await ref.read(currentUserProvider.future);
      debugPrint('✅ User provider refreshed!');

      // Allow a small delay for the provider to update before navigating
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        context.go('/'); // Navigate to Feed
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Connection timed out. Please check your internet and try again.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error: $e';
        if (e.toString().contains('UnknownHostException') ||
            e.toString().contains('UNAVAILABLE')) {
          errorMessage =
              'Network error: Unable to connect to database. Please check your connection.';
        }
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Complete Your Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _pickedFile != null
                      ? FileImage(File(_pickedFile!.path))
                      : null,
                  child: _pickedFile == null
                      ? const Icon(
                          Icons.add_a_photo,
                          size: 40,
                          color: Colors.grey,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Add a Profile Picture (Optional)",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name / Nickname',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Please enter your name'
                    : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _college,
                decoration: const InputDecoration(
                  labelText: 'College',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: _colleges
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _college = val;
                    _department = null; // Reset department
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _department,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: _availableDepartments
                    .map(
                      (d) => DropdownMenuItem(
                        value: d,
                        child: Text(d, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _department = val),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (val) => val == null || val.length < 10
                    ? 'Enter a valid phone number'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio (Share something about yourself)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info_outline),
                ),
                maxLines: 3,
                maxLength: 150,
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Please share a short bio'
                    : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save & Continue"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
