import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/push_notification_service.dart';
import '../theme.dart';
import '../utils/permission_utils.dart';
import 'e2ee_routing_wrapper.dart';
import 'welcome_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isLoading = false;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      var status = await Permission.camera.status;
      if (status.isDenied) status = await Permission.camera.request();
      if (status.isPermanentlyDenied) {
        if (mounted) PermissionUtils.showPermissionDialog(context, 'Camera');
        return;
      }
    } else {
      var status = await Permission.photos.status;
      if (status.isDenied) status = await Permission.photos.request();
      if (status.isPermanentlyDenied) {
        if (mounted) PermissionUtils.showPermissionDialog(context, 'Gallery');
        return;
      }
    }

    try {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 50);
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.orange),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.orange),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      // Insert profile data
      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'name': name,
        'phone_number': user.phone ?? '',
        'about': _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : 'Hey there! I am using Twibee',
      });
      
      // Request Notification Permission here during onboarding
      if (mounted) {
        final status = await Permission.notification.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          // We can show a dialog here or just proceed, but user requested to ask here.
          // Since it's onboarding, asking is enough to trigger the OS prompt.
        }
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const E2EERoutingWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.orange,
        elevation: 0,
        automaticallyImplyLeading: false, // No back button on profile setup
        centerTitle: true,
        title: const Text(
          'Set Up Profile',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.white),
            tooltip: 'Clear Session & Start Over',
            onPressed: () async {
              await PushNotificationService().unregisterDeviceToken();
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Profile Photo Avatar
            GestureDetector(
              onTap: _showImagePickerOptions,
              child: Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.lightGrey,
                        shape: BoxShape.circle,
                        image: _profileImage != null
                            ? DecorationImage(
                                image: FileImage(_profileImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _profileImage == null
                          ? const Icon(
                              Icons.person,
                              size: 60,
                              color: AppColors.grey2,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 3),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: AppColors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add your profile photo',
              style: TextStyle(color: AppColors.grey, fontSize: 16),
            ),
            const SizedBox(height: 40),
            
            // Form Fields
            _buildInputField('Your Name', 'Enter your name', controller: _nameController, isFocused: true),
            const SizedBox(height: 24),
            _buildInputField('Bio (Optional)', "Hey there! I'm using Twibee 👋", controller: _bioController, maxLines: 3),
            
            const SizedBox(height: 40),
            
            // Done Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: AppColors.white)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.check, color: AppColors.white, size: 20),
                      ],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, String hint, {required TextEditingController controller, bool isFocused = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.grey,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.lightGrey,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              bottom: BorderSide(
                color: isFocused ? AppColors.orange : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              hintText: hint,
              hintStyle: const TextStyle(
                color: AppColors.grey,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

