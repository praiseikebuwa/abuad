import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../user/data/user_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/services/cloudinary_service.dart'; // Ensure this matches path
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
  String? _department;
  String? _college;
  File? _imageFile;
  bool _isLoading = false;

  final List<String> _colleges = [
    'Engineering',
    'Law',
    'Sciences',
    'Social & Management Sciences',
    'Medicine & Health Sciences',
    'Arts & Humanities',
  ];

  final Map<String, List<String>> _departments = {
    'Engineering': [
      'Computer',
      'Electrical',
      'Mechanical',
      'Civil',
      'Mechatronics',
    ],
    'Law': ['Law'],
    'Sciences': [
      'Computer Science',
      'Microbiology',
      'Biochemistry',
      'Industrial Chemistry',
    ],
    'Social & Management Sciences': [
      'Accounting',
      'Business Admin',
      'Economics',
      'Pol-Science',
      'Media',
    ],
    'Medicine & Health Sciences': [
      'Medicine',
      'Nursing',
      'MLS',
      'Anatomy',
      'Physiology',
    ],
    'Arts & Humanities': [
      'Performing Arts',
      'English',
      'History',
      'International Relations',
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
      setState(() => _imageFile = File(picked.path));
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
      final cloudinary = CloudinaryService();

      final currentUser = authRepo.currentUser;
      if (currentUser == null) return;

      String? photoUrl;
      if (_imageFile != null) {
        photoUrl = await cloudinary.uploadImage(XFile(_imageFile!.path));
      }

      await userRepo.updateUser(currentUser.uid, {
        'phoneNumber': _phoneController.text.trim(),
        'college': _college,
        'department': _department,
        if (photoUrl != null) 'avatarUrl': photoUrl,
        // Ensure verification is NOT auto-set here
      });

      if (mounted) {
        context.go('/'); // Navigate to Feed (removes this from stack)
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
                  backgroundImage: _imageFile != null
                      ? FileImage(_imageFile!)
                      : null,
                  child: _imageFile == null
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
