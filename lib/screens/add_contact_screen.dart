import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import '../theme.dart';
import 'individual_chat_screen.dart';

class AddContactScreen extends StatefulWidget {
  final String? initialPhone;
  final String? initialName;

  const AddContactScreen({super.key, this.initialPhone, this.initialName});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final nameParts = (widget.initialName ?? '').split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    
    _firstNameController = TextEditingController(text: firstName);
    _lastNameController = TextEditingController(text: lastName);
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveContact() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();

    if (firstName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('First name is required')));
      return;
    }
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number is required')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Request write permissions
      if (!await FlutterContacts.requestPermission(readonly: false)) {
        throw Exception('Permission to write contacts denied');
      }

      // 2. Insert into device contacts
      final newContact = Contact(
        name: Name(first: firstName, last: lastName),
        phones: [Phone(phone)],
      );
      await newContact.insert();

      // 3. Sync contacts with backend
      if (mounted) {
        final syncResult = await context.read<ChatService>().syncDeviceContacts();
        
        // 4. Find the matched user to start chat
        Map<String, dynamic>? matchedUser;
        for (var user in syncResult.registeredUsers) {
          final normalizedPhone = user['phone_number']?.toString().replaceAll(RegExp(r'\D'), '');
          final targetPhone = phone.replaceAll(RegExp(r'\D'), '');
          if (normalizedPhone != null && normalizedPhone.endsWith(targetPhone)) {
            matchedUser = user;
            break;
          }
        }

        if (mounted) {
          if (matchedUser != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => IndividualChatScreen(
                  otherUserId: matchedUser!['id'],
                  chatName: '$firstName $lastName'.trim(),
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contact saved, but they are not registered on Twibee.')),
            );
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save contact: ')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: TwibeeAppBar(
        title: 'New contact',
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveContact,
            child: _isSaving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.lightGrey,
              child: Icon(Icons.add_a_photo, size: 30, color: AppColors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'First name',
                prefixIcon: Icon(Icons.person_outline, color: AppColors.grey),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Last name',
                prefixIcon: SizedBox(width: 48), // Padding to align with above
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone_outlined, color: AppColors.grey),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }
}

