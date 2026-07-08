import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class TestDiagnosticsScreen extends StatefulWidget {
  const TestDiagnosticsScreen({super.key});

  @override
  State<TestDiagnosticsScreen> createState() => _TestDiagnosticsScreenState();
}

class _TestDiagnosticsScreenState extends State<TestDiagnosticsScreen> {
  String _log = "Diagnostics Started...\n";

  void _addLog(String message) {
    setState(() {
      _log += "$message\n";
    });
    print(message);
  }

  Future<void> _runTests() async {
    setState(() => _log = "Running Tests...\n");
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      _addLog("❌ ERROR: You are not logged in!");
      return;
    }
    _addLog("✅ Logged in as: ${user.phone ?? user.id}");

    // 1. Test FCM Token Registration
    _addLog("\n--- Testing Push Notification (FCM) ---");
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        _addLog("❌ FCM Token is NULL on device.");
      } else {
        _addLog("✅ Device FCM Token Generated: ${token.substring(0, 10)}...");
        // Check if token is in Supabase
        final dbTokens = await supabase
            .from('linked_devices')
            .select('fcm_token')
            .eq('user_id', user.id);
            
        if (dbTokens.isNotEmpty && dbTokens.any((d) => d['fcm_token'] == token)) {
          _addLog("✅ FCM Token successfully registered in Supabase DB!");
        } else {
          _addLog("❌ FCM Token NOT found in Supabase DB! The init script failed or didn't run.");
        }
      }
    } catch (e) {
      _addLog("❌ FCM Test Error: $e");
    }

    // 2. Test Local Contacts Cache
    _addLog("\n--- Testing Contact Sync ---");
    try {
      final chatService = context.read<ChatService>();
      final cache = chatService.localContactsCache;
      if (cache.isEmpty) {
        _addLog("❌ Local Contacts Cache is EMPTY. It didn't load or no permission.");
      } else {
        _addLog("✅ Local Contacts Cached: ${cache.length} numbers.");
        _addLog("Example mapped name: ${cache.values.first}");
      }
    } catch (e) {
      _addLog("❌ Contact Sync Test Error: $e");
    }

    // 3. Test Privacy Setting (Double Tick)
    _addLog("\n--- Testing Read Receipts Privacy (Double Tick) ---");
    try {
      // Test the SQL function directly by seeing what it returns for the current user against themselves
      final result = await supabase.rpc('can_view_read_receipts', params: {
        'viewer_id': user.id,
        'target_id': user.id,
      });
      if (result == true) {
        _addLog("✅ Privacy SQL Function works! It returns TRUE as expected.");
      } else {
        _addLog("❌ Privacy SQL Function returned FALSE! Did you run the SQL migration?");
      }
    } catch (e) {
      _addLog("❌ Privacy Test Error: $e\nThis usually means you HAVEN'T run the SQL script in Supabase Dashboard yet!");
    }

    _addLog("\n--- TESTS COMPLETED ---");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("System Diagnostics"),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _runTests,
          )
        ],
      ),
      body: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(16.0),
        width: double.infinity,
        height: double.infinity,
        child: SingleChildScrollView(
          child: SelectableText(
            _log,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _runTests,
        child: const Icon(Icons.play_arrow),
      ),
    );
  }
}
