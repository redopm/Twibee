import 'package:flutter/material.dart';
import '../theme.dart';
import 'select_call_participants_screen.dart';

class ScheduleCallScreen extends StatefulWidget {
  const ScheduleCallScreen({super.key});

  @override
  State<ScheduleCallScreen> createState() => _ScheduleCallScreenState();
}

class _ScheduleCallScreenState extends State<ScheduleCallScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();

  bool _includeEndTime = false;
  DateTime _endDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _endTime = TimeOfDay.now().replacing(hour: (TimeOfDay.now().hour + 1) % 24);

  bool _isVideoCall = true;
  bool _requireApproval = false;
  String _reminderTime = '10 minutes before';

  final List<String> _reminderOptions = [
    'At time of call',
    '5 minutes before',
    '10 minutes before',
    '15 minutes before',
    '30 minutes before',
    '1 hour before',
  ];

  Future<void> _pickDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => _buildPickerTheme(child!),
    );
    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
          if (_endDate.isBefore(_startDate)) _endDate = _startDate;
        } else {
          _endDate = date;
        }
      });
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) => _buildPickerTheme(child!),
    );
    if (time != null) {
      setState(() {
        if (isStart) {
          _startTime = time;
        } else {
          _endTime = time;
        }
      });
    }
  }

  Widget _buildPickerTheme(Widget child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: AppColors.orange,
          onPrimary: AppColors.white,
          onSurface: AppColors.dark,
        ),
      ),
      child: child,
    );
  }

  String _formatDate(DateTime date) {
    final isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;
    if (isToday) return 'Today';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _onNext() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a call title')));
      return;
    }

    // Prepare data to pass
    final Map<String, dynamic> callDetails = {
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'startDate': _startDate,
      'startTime': _startTime,
      'includeEndTime': _includeEndTime,
      'endDate': _includeEndTime ? _endDate : null,
      'endTime': _includeEndTime ? _endTime : null,
      'isVideoCall': _isVideoCall,
      'requireApproval': _requireApproval,
      'reminder': _reminderTime,
    };

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SelectCallParticipantsScreen(callDetails: callDetails)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F6), // Light grey background
      appBar: TwibeeAppBar(
        title: 'Schedule Call',
        centerTitle: true,
        onBack: () => Navigator.pop(context),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.dark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Description
            Container(
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Call title',
                      contentPadding: EdgeInsets.all(16),
                      border: InputBorder.none,
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.lightGrey),
                  TextField(
                    controller: _descController,
                    maxLines: 3,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'Add description (optional)',
                      contentPadding: EdgeInsets.all(16),
                      border: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Date & Time Card
            Container(
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Starts'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => _pickDate(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.lightGrey, borderRadius: BorderRadius.circular(6)),
                            child: Text(_formatDate(_startDate)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _pickTime(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.lightGrey, borderRadius: BorderRadius.circular(6)),
                            child: Text(_formatTime(_startTime)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.lightGrey),
                  SwitchListTile(
                    title: const Text('Include end time'),
                    activeThumbColor: AppColors.orange,
                    value: _includeEndTime,
                    onChanged: (val) => setState(() => _includeEndTime = val),
                  ),
                  if (_includeEndTime) ...[
                    const Divider(height: 1, color: AppColors.lightGrey),
                    ListTile(
                      title: const Text('Ends'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _pickDate(false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: AppColors.lightGrey, borderRadius: BorderRadius.circular(6)),
                              child: Text(_formatDate(_endDate)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _pickTime(false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: AppColors.lightGrey, borderRadius: BorderRadius.circular(6)),
                              child: Text(_formatTime(_endTime)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Call Options Card
            Container(
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Call type', style: TextStyle(fontSize: 16)),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.lightGrey,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => setState(() => _isVideoCall = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _isVideoCall ? AppColors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: _isVideoCall ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
                                  ),
                                  child: Icon(Icons.videocam, size: 20, color: _isVideoCall ? AppColors.orange : AppColors.grey),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _isVideoCall = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: !_isVideoCall ? AppColors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: !_isVideoCall ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
                                  ),
                                  child: Icon(Icons.call, size: 20, color: !_isVideoCall ? AppColors.orange : AppColors.grey),
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.lightGrey),
                  SwitchListTile(
                    title: const Text('Require approval to join'),
                    activeThumbColor: AppColors.orange,
                    value: _requireApproval,
                    onChanged: (val) => setState(() => _requireApproval = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Reminder Card
            Container(
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: const Text('Reminder'),
                trailing: DropdownButton<String>(
                  value: _reminderTime,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.chevron_right, color: AppColors.grey),
                  items: _reminderOptions.map((opt) {
                    return DropdownMenuItem<String>(
                      value: opt,
                      child: Text(opt, style: const TextStyle(color: AppColors.grey)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _reminderTime = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Next Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _onNext,
                child: const Text('Next', style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

