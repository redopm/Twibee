import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../services/chat_service.dart';
import '../utils/permission_utils.dart';
import 'individual_chat_screen.dart';
import 'select_group_members_screen.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'add_contact_screen.dart';
import 'qr_contact_screen.dart';
import 'new_broadcast_screen.dart';

class ContactsScreen extends StatefulWidget {
  final bool isPicker;
  const ContactsScreen({super.key, this.isPicker = false});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _registeredUsers = [];
  List<Contact> _unregisteredContacts = [];
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final chatService = context.read<ChatService>();
      var status = await Permission.contacts.status;
      
      if (status.isDenied) {
        status = await Permission.contacts.request();
      }

      if (status.isGranted) {
        final result = await chatService.syncDeviceContacts();
        
        if (mounted) {
          setState(() {
            _registeredUsers = result.registeredUsers;
            _unregisteredContacts = result.unregisteredContacts;
            _isLoading = false;
          });
        }
      } else if (status.isPermanentlyDenied) {
        if (mounted) {
          setState(() => _isLoading = false);
          PermissionUtils.showPermissionDialog(context, 'Contacts');
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact permission denied')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching contacts: $e')),
        );
      }
    }
  }

  Future<void> _startChat(Map<String, dynamic> otherUser) async {
    if (widget.isPicker) {
      Navigator.pop(context, otherUser['contact_name'] ?? otherUser['name'] ?? 'Unknown Contact');
      return;
    }
    try {
      final chatId = await context.read<ChatService>().createChat(otherUser['id']);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => IndividualChatScreen(
              chatId: chatId,
              chatName: otherUser['contact_name'] ?? otherUser['name'] ?? 'Unknown',
              otherUserId: otherUser['id'],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting chat: $e')),
        );
      }
    }
  }

  Future<void> _inviteContact(Contact contact) async {
    if (widget.isPicker) {
      Navigator.pop(context, contact.displayName);
      return;
    }
    if (contact.phones.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact has no phone number')));
      }
      return;
    }
    final phone = contact.phones.first.number;
    final url = Uri.parse('sms:$phone?body=Hey! Join me on Twibee app to chat.');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open SMS app')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredRegisteredUsers = _searchQuery.isEmpty 
        ? _registeredUsers 
        : _registeredUsers.where((u) {
            final name = (u['contact_name'] ?? u['name'] ?? '').toString().toLowerCase();
            final phone = (u['phone'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) || phone.contains(_searchQuery);
          }).toList();
          
    final filteredUnregisteredContacts = _searchQuery.isEmpty 
        ? _unregisteredContacts 
        : _unregisteredContacts.where((c) {
            final name = c.displayName.toLowerCase();
            final phone = c.phones.isNotEmpty ? c.phones.first.number.toLowerCase() : '';
            return name.contains(_searchQuery) || phone.contains(_searchQuery);
          }).toList();

    const bgColor = Color(0xFFF2F2F7);
    return Scaffold(
      backgroundColor: bgColor,
      appBar: _isSearching
          ? AppBar(
              backgroundColor: bgColor,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.dark),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              ),
              title: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search contacts...',
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.toLowerCase();
                  });
                },
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.dark),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                ),
              ],
            )
          : TwibeeAppBar(
              title: 'Select contact',
              subtitle: _isLoading ? null : '${filteredRegisteredUsers.length} contacts',
              actions: [
                IconButton(
                  icon: const Icon(Icons.search, color: AppColors.dark),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                ),
                IconButton(icon: const Icon(Icons.more_vert, color: AppColors.dark), onPressed: () {}),
              ],
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.green,
                          child: Icon(Icons.group_add, color: AppColors.white),
                        ),
                        title: const Text('New group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.dark)),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SelectGroupMembersScreen()));
                        },
                      ),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.green,
                          child: Icon(Icons.person_add, color: AppColors.white),
                        ),
                        title: const Text('New contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.dark)),
                        trailing: IconButton(
                          icon: const Icon(Icons.qr_code, color: AppColors.grey),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const QRContactScreen()));
                          },
                        ),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddContactScreen()));
                        },
                      ),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.green,
                          child: Icon(Icons.campaign, color: AppColors.white),
                        ),
                        title: const Text('New broadcast', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.dark)),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const NewBroadcastScreen()));
                        },
                      ),
                    ],
                  ),
                ),
                if (filteredRegisteredUsers.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                      child: Text('Contacts on Twibee', style: TextStyle(color: AppColors.grey, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final user = filteredRegisteredUsers[index];
                        final name = user['contact_name'] ?? user['name'] ?? 'Unknown';
                        final about = user['about'] ?? 'Hey there! I am using Twibee.';
                        final avatarUrl = user['avatar_url'];
                        
                        return ListTile(
                          onTap: () => _startChat(user),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.grey2.withValues(alpha: 0.3),
                            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl == null ? const Icon(Icons.person, color: AppColors.white) : null,
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.dark)),
                          subtitle: Text(about, style: const TextStyle(color: AppColors.grey, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        );
                      },
                      childCount: filteredRegisteredUsers.length,
                    ),
                  ),
                ],
                if (filteredUnregisteredContacts.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                      child: Text('Invite to Twibee', style: TextStyle(color: AppColors.grey, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final contact = filteredUnregisteredContacts[index];
                        final name = contact.displayName;
                        
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.grey2.withValues(alpha: 0.3),
                            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.dark)),
                          trailing: TextButton(
                            onPressed: () => _inviteContact(contact),
                            child: const Text('INVITE', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                      childCount: filteredUnregisteredContacts.length,
                    ),
                  ),
                ],
                if (filteredRegisteredUsers.isEmpty && filteredUnregisteredContacts.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: Text("No contacts found.")),
                  ),
              ],
            ),
    );
  }
}

