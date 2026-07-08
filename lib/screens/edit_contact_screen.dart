import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme.dart';

class EditContactScreen extends StatefulWidget {
  final String initialName;
  final String initialPhone;

  const EditContactScreen({
    super.key,
    required this.initialName,
    required this.initialPhone,
  });

  @override
  State<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends State<EditContactScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  bool _syncToPhone = true;
  bool _hasChanges = false;
  bool _canPop = false;

  @override
  void initState() {
    super.initState();
    // For simplicity, assuming the name provided is the first name
    _firstNameController = TextEditingController(text: widget.initialName);
    _lastNameController = TextEditingController();
    _phoneController = TextEditingController(text: widget.initialPhone);

    _firstNameController.addListener(_onChange);
    _lastNameController.addListener(_onChange);
    _phoneController.addListener(_onChange);
  }

  void _onChange() {
    setState(() {
      _hasChanges = true;
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<bool> _showDiscardDialog() async {
    bool? discard = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Are you sure you want to discard this new contact?', style: TextStyle(fontSize: 13)),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context, true); // Return true to discard
            },
            child: const Text('Discard changes'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () {
            Navigator.pop(context, false); // Return false to keep editing
          },
          child: const Text('Keep editing'),
        ),
      ),
    );
    return discard ?? false;
  }

  void _handleClose() async {
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }
    bool discard = await _showDiscardDialog();
    if (discard && mounted) {
      setState(() => _canPop = true);
      Navigator.pop(context);
    }
  }
  void _handleSave() {
    setState(() => _canPop = true);
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final fullName = [first, last].where((e) => e.isNotEmpty).join(' ');
    final phone = _phoneController.text.trim();
    Navigator.pop(context, {'name': fullName, 'phone': phone});
  }

  void _handleDelete() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Contact'),
        content: const Text('Are you sure you want to delete this contact?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              setState(() => _canPop = true); // Allow edit screen to pop
              Navigator.pop(context); // Close edit screen
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF2F2F7);

    return PopScope(
      canPop: !_hasChanges || _canPop,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final discard = await _showDiscardDialog();
        if (discard && context.mounted) {
          setState(() => _canPop = true);
          Navigator.pop(context);
        }
      },
      child: Scaffold(
      backgroundColor: bgColor,
      appBar: TwibeeAppBar(
        title: 'Edit contact',
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: AppColors.dark, size: 20),
            ),
            onPressed: _handleClose,
          ),
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
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // Group 1: Names
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildTextField('First name', _firstNameController, showBorder: true),
                _buildTextField('Last name', _lastNameController, showBorder: false),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Group 2: Phone
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  title: const Row(
                    children: [
                      SizedBox(width: 80, child: Text('Phone', style: TextStyle(fontWeight: FontWeight.w600))),
                      Expanded(child: Text('India', style: TextStyle(color: AppColors.dark))),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.grey, size: 20),
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 16, color: AppColors.lightGrey),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const SizedBox(width: 80, child: Text('Mobile', style: TextStyle(fontWeight: FontWeight.w600))),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(color: AppColors.dark, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Group 3: Sync
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              title: const Text('Sync contact to phone', style: TextStyle(color: AppColors.dark, fontSize: 16)),
              trailing: CupertinoSwitch(
                value: _syncToPhone,
                activeTrackColor: AppColors.orange,
                onChanged: (val) {
                  setState(() => _syncToPhone = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Group 4: Delete
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              title: const Text('Delete contact', style: TextStyle(color: AppColors.red, fontSize: 16)),
              onTap: _handleDelete,
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildTextField(String hint, TextEditingController controller, {bool showBorder = true}) {
    return Column(
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.grey),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          style: const TextStyle(color: AppColors.dark, fontSize: 16),
        ),
        if (showBorder) const Divider(height: 1, indent: 16, color: AppColors.lightGrey),
      ],
    );
  }
}

