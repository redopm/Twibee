import 'package:flutter/material.dart';
import '../theme.dart';

class CreateListScreen extends StatefulWidget {
  const CreateListScreen({super.key});

  @override
  State<CreateListScreen> createState() => _CreateListScreenState();
}

class _CreateListScreenState extends State<CreateListScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final listName = _nameController.text.trim();
    if (listName.isEmpty) return;
    
    // In the future, save to backend here
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('List "$listName" created!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: TwibeeAppBar(
        title: 'New list',
        centerTitle: true,
        onBack: () => Navigator.pop(context),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.grey.withValues(alpha: 0.3), shape: BoxShape.circle),
            child: const Icon(Icons.close, color: AppColors.dark, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 20),
              ),
              onPressed: _handleSave,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // List Name Input
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'List name',
                  hintStyle: TextStyle(color: AppColors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Included Section
            const Text(
              'Included',
              style: TextStyle(color: AppColors.grey, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
                title: const Text(
                  'Add people or groups',
                  style: TextStyle(color: AppColors.orange, fontSize: 16, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select contacts feature coming soon!')));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

