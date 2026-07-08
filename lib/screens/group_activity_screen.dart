import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../theme.dart';

class GroupActivityScreen extends StatefulWidget {
  final String chatId;
  final String groupName;

  const GroupActivityScreen({
    super.key,
    required this.chatId,
    required this.groupName,
  });

  @override
  State<GroupActivityScreen> createState() => _GroupActivityScreenState();
}

class _GroupActivityScreenState extends State<GroupActivityScreen> {
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchActivity();
  }

  Future<void> _fetchActivity() async {
    try {
      // Fetch system messages directly from Supabase (no wrapper method needed)
      final response = await Supabase.instance.client
          .from('messages')
          .select('id, content, created_at, message_type')
          .eq('chat_id', widget.chatId)
          .eq('message_type', 'system')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _activities = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: TwibeeAppBar(
        title: 'Member changes',
        subtitle: widget.groupName,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : _activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(color: AppColors.lightGrey, shape: BoxShape.circle),
                        child: const Icon(Icons.history, color: AppColors.grey, size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text('No member changes yet', style: TextStyle(color: AppColors.dark, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Activity like joining and leaving will appear here.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.grey, fontSize: 14)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: _activities.length,
                  itemBuilder: (context, index) {
                    final item = _activities[index];
                    final dateRaw = item['created_at'];
                    final date = dateRaw != null ? DateTime.tryParse(dateRaw.toString())?.toLocal() : null;
                    final dateStr = date != null ? DateFormat('MMM d, yyyy • h:mm a').format(date) : '';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.info_outline, color: AppColors.grey, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['content'] ?? 'System event', style: const TextStyle(color: AppColors.dark, fontSize: 15)),
                                const SizedBox(height: 4),
                                Text(dateStr, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

