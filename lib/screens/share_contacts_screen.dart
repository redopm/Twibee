import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme.dart';
import 'send_contact_screen.dart';

class ShareContactsScreen extends StatefulWidget {
  const ShareContactsScreen({super.key});

  @override
  State<ShareContactsScreen> createState() => _ShareContactsScreenState();
}

class _ShareContactsScreenState extends State<ShareContactsScreen> {
  bool _isLoading = true;
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  final Set<Contact> _selectedContacts = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    var status = await Permission.contacts.status;
    if (status.isDenied) {
      status = await Permission.contacts.request();
    }
    if (status.isGranted) {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      contacts.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _filteredContacts = contacts;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contacts permission required')));
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filteredContacts = _contacts
          .where((c) => c.displayName.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _proceedToSend() async {
    if (_selectedContacts.isEmpty) return;
    // For simplicity, we pass the first selected contact for now, but UI supports multiselect visually
    final selected = _selectedContacts.first;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SendContactScreen(contact: selected)),
    );
    if (result != null) {
      if (mounted) Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey, // Assuming a slight grey background
      appBar: TwibeeAppBar(
        title: 'Share contacts',
        subtitle: _isLoading ? null : '${_selectedContacts.length}/${_contacts.length}',
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
              onPressed: _selectedContacts.isNotEmpty ? _proceedToSend : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedContacts.isNotEmpty ? AppColors.green : AppColors.grey2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: const Text('Next', style: TextStyle(color: AppColors.white)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16)),
                    child: TextField(
                      onChanged: _onSearchChanged,
                      decoration: const InputDecoration(
                        hintText: 'Search',
                        prefixIcon: Icon(Icons.search, color: AppColors.dark),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                    ),
                    child: ListView.builder(
                      itemCount: _filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact = _filteredContacts[index];
                        final isSelected = _selectedContacts.contains(contact);
                        final initial = contact.displayName.isNotEmpty ? contact.displayName.characters.first.toUpperCase() : '?';

                        return ListTile(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedContacts.remove(contact);
                              } else {
                                _selectedContacts.add(contact);
                              }
                            });
                          },
                          leading: CircleAvatar(
                            backgroundColor: Colors.primaries[index % Colors.primaries.length].withValues(alpha: 0.2),
                            child: Text(initial, style: TextStyle(color: Colors.primaries[index % Colors.primaries.length], fontWeight: FontWeight.bold)),
                          ),
                          title: Text(contact.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          trailing: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? AppColors.green : AppColors.grey, width: 2),
                              color: isSelected ? AppColors.green : Colors.transparent,
                            ),
                            child: isSelected ? const Icon(Icons.check, color: AppColors.white, size: 16) : null,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

