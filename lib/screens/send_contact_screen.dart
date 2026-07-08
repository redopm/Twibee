import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../theme.dart';
import 'dart:convert';

class SendContactScreen extends StatelessWidget {
  final Contact contact;

  const SendContactScreen({super.key, required this.contact});

  @override
  Widget build(BuildContext context) {
    final phone = contact.phones.isNotEmpty ? contact.phones.first.number : 'No Phone Number';
    final initial = contact.displayName.isNotEmpty ? contact.displayName.characters.first.toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: TwibeeAppBar(
        title: 'Send contact',
        centerTitle: true,
        onBack: () => Navigator.pop(context),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
            child: const Icon(Icons.close, color: AppColors.dark),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {
                final contactData = jsonEncode({
                  'name': contact.displayName,
                  'phone': phone,
                });
                Navigator.pop(context, contactData);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: const Text('Send', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.pink,
                  child: Text(initial, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                ),
                const SizedBox(width: 16),
                Text(contact.displayName, style: const TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                    child: const Icon(Icons.check, color: AppColors.white, size: 16),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Phone', style: TextStyle(color: AppColors.green, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(phone, style: const TextStyle(color: AppColors.dark, fontSize: 18)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

