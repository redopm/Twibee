import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import '../theme.dart';

class GroupJoinRequestsScreen extends StatefulWidget {
  final String chatId;
  
  const GroupJoinRequestsScreen({super.key, required this.chatId});

  @override
  State<GroupJoinRequestsScreen> createState() => _GroupJoinRequestsScreenState();
}

class _GroupJoinRequestsScreenState extends State<GroupJoinRequestsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final reqs = await context.read<ChatService>().getPendingJoinRequests(widget.chatId);
      if (mounted) {
        setState(() {
          _requests = reqs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _approve(Map<String, dynamic> request) async {
    try {
      final userId = request['profiles']['id'];
      await context.read<ChatService>().approveJoinRequest(request['id'], widget.chatId, userId);
      
      setState(() {
        _requests.removeWhere((r) => r['id'] == request['id']);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${request['profiles']['name']} approved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _reject(Map<String, dynamic> request) async {
    try {
      await context.read<ChatService>().rejectJoinRequest(request['id']);
      
      setState(() {
        _requests.removeWhere((r) => r['id'] == request['id']);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${request['profiles']['name']} rejected')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const TwibeeAppBar(title: 'Review join requests'),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : _requests.isEmpty 
              ? const Center(child: Text('No pending requests', style: TextStyle(color: AppColors.grey)))
              : ListView.builder(
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final req = _requests[index];
                    final profile = req['profiles'];
                    final String? avatarUrl = profile['avatar_url'];
                    final String name = profile['name'] ?? 'Unknown';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.green,
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null ? Text((profile['name']?.toString().isNotEmpty == true) ? profile['name']!.toString().characters.first.toUpperCase() : '?', style: const TextStyle(color: Colors.white)) : null,
                      ),
                      title: Text(profile['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.dark)),
                      subtitle: Text(profile['phone'] ?? '', style: const TextStyle(color: AppColors.grey)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.red),
                            onPressed: () => _reject(req),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check, color: AppColors.green),
                            onPressed: () => _approve(req),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

