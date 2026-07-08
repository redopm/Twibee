import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/channel_service.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';

class CreateChannelScreen extends StatefulWidget {
  const CreateChannelScreen({super.key});

  @override
  State<CreateChannelScreen> createState() => _CreateChannelScreenState();
}

class _CreateChannelScreenState extends State<CreateChannelScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  final ChannelService _channelService = ChannelService();
  final SupabaseClient _supabase = Supabase.instance.client;

  // Step 1 State
  final _formKey1 = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  File? _avatarFile;

  // Step 2 State
  bool _isPublic = false;
  final _usernameController = TextEditingController();
  bool _restrictSaving = false;

  // Step 3 State
  List<Map<String, dynamic>> _availableUsers = [];
  final List<String> _selectedUserIds = [];
  String _searchQuery = '';
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    try {
      final chatService = context.read<ChatService>();
      final result = await chatService.syncDeviceContacts();
      
      if (mounted) {
        setState(() {
          _availableUsers = result.registeredUsers;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  Future<void> _nextPage() async {
    if (_currentPage == 0) {
      if (!_formKey1.currentState!.validate()) return;
    }
    
    if (_currentPage == 1 && _isPublic) {
      final username = _usernameController.text.trim().toLowerCase();
      if (username.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username is required for public channels.')));
        return;
      }

      // Regex validation (no spaces, only alphanumeric and underscore)
      if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username can only contain lowercase letters, numbers, and underscores (no spaces).')));
        return;
      }

      setState(() => _isLoading = true);
      try {
        // Live uniqueness check across profiles and channels
        final profileRes = await _supabase.from('profiles').select('id').eq('username', username).maybeSingle();
        final channelRes = await _supabase.from('channels').select('id').eq('username', username).maybeSingle();

        if (profileRes != null || channelRes != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Username @$username is already taken. Please choose another.')));
          }
          return;
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error checking username: $e')));
        return;
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }

    if (_currentPage < 2) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentPage++);
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentPage--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _createChannel() async {
    setState(() => _isLoading = true);
    try {
      await _channelService.createChannel(
        name: _nameController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        isPublic: _isPublic,
        username: _isPublic ? _usernameController.text.trim() : null,
        restrictSaving: _restrictSaving,
        initialSubscriberIds: _selectedUserIds,
        avatarFile: _avatarFile,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Channel created successfully! 🎉'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        if (e.code == '23505' && e.message.contains('channels_username_key')) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This username is already taken. Please choose another one.'), backgroundColor: Colors.red));
        } else {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Database Error: ${e.message}'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── BUILDERS ─────────────────────────────────────────────────────────────

  Widget _buildStep1() {
    return Form(
      key: _formKey1,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        children: [
          // Full-width Header Avatar Picker
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: AppColors.orange.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8)),
                  ],
                  border: Border.all(color: AppColors.orange.withOpacity(0.3), width: 1.5),
                  image: _avatarFile != null
                      ? DecorationImage(image: FileImage(_avatarFile!), fit: BoxFit.cover)
                      : null,
                ),
                child: _avatarFile == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_rounded, size: 56, color: AppColors.orange),
                          SizedBox(height: 12),
                          Text('Set Channel Photo', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      )
                    : Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: AppColors.orange,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
                            ),
                            child: const Icon(Icons.edit, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Channel Name',
              hintText: 'e.g. Tech News',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Channel name is required';
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _descController,
            maxLines: 3,
            maxLength: 255,
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'What is this channel about?',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        children: [
          const Text('Channel Type', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.dark, fontSize: 18)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  RadioListTile<bool>(
                    value: false,
                    groupValue: _isPublic,
                    activeColor: AppColors.orange,
                    title: const Text('Private Channel', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Only people with a special invite link can join. Link will be generated automatically.'),
                    onChanged: (val) => setState(() => _isPublic = val!),
                  ),
                  const Divider(height: 1),
                  RadioListTile<bool>(
                    value: true,
                    groupValue: _isPublic,
                    activeColor: AppColors.orange,
                    title: const Text('Public Channel', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Anyone can find the channel in search and join.'),
                    onChanged: (val) => setState(() => _isPublic = val!),
                  ),
                ],
              ),
            ),
          ),
        if (_isPublic) ...[
          const SizedBox(height: 24),
          const Text('Public Link', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.dark, fontSize: 16)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _usernameController,
            decoration: InputDecoration(
              prefixText: 'Twibee.app/ ',
              prefixStyle: const TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold),
              hintText: 'channel_name',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_A-Z]')),
            ],
            onChanged: (val) {
              if (val != val.toLowerCase()) {
                _usernameController.value = _usernameController.value.copyWith(
                  text: val.toLowerCase(),
                  selection: TextSelection.collapsed(offset: val.length),
                );
              }
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text('People can use this link to join your channel.', style: TextStyle(color: AppColors.grey2, fontSize: 13)),
          ),
        ],
        const SizedBox(height: 32),
        const Text('Security', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.dark, fontSize: 18)),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.1),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
            title: const Text('Restrict Saving Content', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Subscribers won\'t be able to copy, save, or forward content from this channel.'),
            value: _restrictSaving,
            activeThumbColor: Colors.white,
            activeColor: AppColors.orange,
            onChanged: (val) => setState(() => _restrictSaving = val),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    final filteredUsers = _availableUsers.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Who would you like to add?',
              prefixIcon: const Icon(Icons.search, color: AppColors.orange),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              filled: true,
              fillColor: AppColors.orange.withOpacity(0.05),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingUsers
              ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
              : ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final isSelected = _selectedUserIds.contains(user['id']);
                    final avatarUrl = user['avatar_url'];
                    final name = user['name'] ?? 'Unknown';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.orange.withValues(alpha: 0.2),
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null ? Text(name.isNotEmpty ? name.characters.first.toUpperCase() : '?', style: const TextStyle(color: AppColors.orange)) : null,
                      ),
                      title: Text(name),
                      subtitle: Text(user['phone_number'] ?? ''),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: AppColors.orange)
                          : const Icon(Icons.circle_outlined, color: AppColors.grey),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedUserIds.remove(user['id']);
                          } else {
                            _selectedUserIds.add(user['id']);
                          }
                        });
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Channel Info', 'Channel Settings', 'Add Subscribers'];
    
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: TwibeeAppBar(
        title: titles[_currentPage],
        subtitle: 'Step ${_currentPage + 1} of 3',
        onBack: _prevPage,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Disable swipe to force using buttons
        children: [
          _buildStep1(),
          _buildStep2(),
          _buildStep3(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 16 : 24,
            top: 16,
          ),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [AppColors.orange, Color(0xFFFF9800)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.orange.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : (_currentPage == 2 ? _createChannel : _nextPage),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text(
                      _currentPage == 2 ? 'Create Channel' : 'Next Step',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

