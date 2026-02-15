import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../user/data/user_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/services/firebase_storage_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

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
      'Petroleum',
    ],
    'Law': ['Law'],
    'Sciences': [
      'Computer Science',
      'Microbiology',
      'Biochemistry',
      'Industrial Chemistry',
      'Physics',
      'Mathematics',
      'Statistics',
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
      'Performing Arts',
      'English',
      'History',
      'International Relations',
      'Philosophy',
      'Religious Studies',
      'Linguistics',
      'Music',
    ],
    'Agriculture': [
      'Agricultural Science',
      'Fisheries',
      'Forestry',
      'Animal Science',
      'Crop Science',
      'Soil Science',
    ],
    'Education': [
      'Guidance & Counseling',
      'Educational Management',
      'Science Education',
      'Arts Education',
      'Social Science Education',
      'Library Science',
    ],
    'Environmental Sciences': [
      'Architecture',
      'Estate Management',
      'Urban & Regional Planning',
      'Quantity Surveying',
      'Building',
      'Surveying & Geoinformatics',
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

      final existingUser = await userRepo.getUserById(currentUser.uid);
      String? handle = existingUser?.handle;

      if (handle == null || handle.isEmpty) {
        handle = await userRepo.generateHandle(_nameController.text.trim());
      }

      await userRepo.updateUser(currentUser.uid, {
        'display_name': _nameController.text.trim(),
        'handle': handle,
        'email': currentUser.email ?? '',
        'phone_number': _phoneController.text.trim(),
        'college': _college,
        'department': _department,
        if (photoUrl != null) 'avatar_url': photoUrl,
      });

      // Force refresh of the user provider to ensure the navigation guard
      // in ScaffoldWithBottomNav sees the updated data immediately.
      ref.invalidate(currentUserProvider);

      // Allow a small delay for the provider to update before navigating
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        context.go('/'); // Navigate to Feed
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
                items: _colleges
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
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
                items: _availableDepartments
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (val) => setState(() => _department = val),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (val) => val == null || val.length < 10
                    ? 'Enter a valid phone number'
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
