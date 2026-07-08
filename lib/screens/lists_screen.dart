import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/settings_group.dart';

class ListsScreen extends StatelessWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: TwibeeAppBar(
        title: 'Lists',
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Reorder', style: TextStyle(color: AppColors.dark, fontSize: 16)),
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.list_alt, size: 80, color: AppColors.orange), // Placeholder graphic
                  const SizedBox(height: 16),
                  const Text(
                    'Any list you create becomes a filter at the top of your Chats tab.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.grey, fontSize: 15),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add, color: AppColors.dark),
                      label: const Text('Create a custom list', style: TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.lightGrey,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SettingsGroup(
            header: 'Your lists',
            children: [
              SettingsItem(title: 'Unread (preset)', onTap: () {}),
              SettingsItem(title: 'Favorites', onTap: () {}),
              SettingsItem(title: 'Groups (preset)', showDivider: false, onTap: () {}),
            ],
          ),
          
          SettingsGroup(
            header: 'Available presets',
            children: [
              SettingsItem(
                title: 'Communities (preset)',
                showDivider: false,
                trailing: const Icon(Icons.add_circle, color: AppColors.orange),
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

