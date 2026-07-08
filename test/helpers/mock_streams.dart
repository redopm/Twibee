import 'dart:async';

/// Helper to simulate Supabase Real-time payloads
class MockSupabaseStream {
  final StreamController<List<Map<String, dynamic>>> _controller = StreamController<List<Map<String, dynamic>>>.broadcast();

  Stream<List<Map<String, dynamic>>> get stream => _controller.stream;

  void emitData(List<Map<String, dynamic>> data) {
    _controller.add(data);
  }

  void emitError(dynamic error) {
    _controller.addError(error);
  }

  void close() {
    _controller.close();
  }
}

