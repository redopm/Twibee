// test/phase3/status_bug_fix_test.dart
//
// Tests for the two status bugs fixed:
// 1. "Just now" time bug — timestamps stored as IST but treated as UTC
// 2. Owner appearing as viewer of their own status
//
// Run with: flutter test test/phase3/status_bug_fix_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EXTRACTED LOGIC (mirrors own_status_viewer_screen.dart _formatTime)
// We test the pure logic independently for reliability.
// ─────────────────────────────────────────────────────────────────────────────

/// Corrects timestamps stored with the IST-as-UTC bug.
/// If parsed date appears > 2 minutes in the future, subtract the local offset.
DateTime parseTimestamp(String isoString) {
  DateTime date;
  try {
    date = DateTime.parse(isoString);
    if (isoString.contains('+') || isoString.endsWith('Z')) {
      date = date.toLocal();
    }
    final now = DateTime.now();
    if (date.isAfter(now.add(const Duration(minutes: 2)))) {
      date = date.subtract(now.timeZoneOffset);
    }
  } catch (_) {
    date = DateTime.now();
  }
  return date;
}

String formatTime(String isoString) {
  final date = parseTimestamp(isoString);
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (now.day == date.day) return 'Today at ${DateFormat('hh:mm a').format(date)}';
  if (diff.inDays == 1) return 'Yesterday at ${DateFormat('hh:mm a').format(date)}';
  return DateFormat('MMM d, hh:mm a').format(date);
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('Status Time Bug Fix Tests', () {
    // ─── BUG 1: Timestamp timezone correction ─────────────────────────────

    test('Correct UTC timestamp (with Z) parses to local correctly', () {
      // Simulate a status posted 2 hours ago in proper UTC
      final twoHoursAgo = DateTime.now().toUtc().subtract(const Duration(hours: 2));
      final isoString = twoHoursAgo.toIso8601String(); // ends with Z

      final parsed = parseTimestamp(isoString);
      final diff = DateTime.now().difference(parsed);

      // Should be approximately 2 hours (120 minutes), NOT negative or 0
      expect(diff.inMinutes, greaterThan(115));
      expect(diff.inMinutes, lessThan(125));
    });

    test('Correct UTC timestamp with +00:00 offset parses correctly', () {
      final twoHoursAgo = DateTime.now().toUtc().subtract(const Duration(hours: 2));
      // Format as +00:00 style (what Supabase often returns)
      final isoString = twoHoursAgo.toIso8601String().replaceAll('Z', '+00:00');

      final parsed = parseTimestamp(isoString);
      final diff = DateTime.now().difference(parsed);

      expect(diff.inMinutes, greaterThan(115));
      expect(diff.inMinutes, lessThan(125));
    });

    test('BUGGY old timestamp (IST stored as UTC) is auto-corrected', () {
      // Simulate the OLD bug: local IST time (e.g. 5:50 PM) stored as UTC string
      // without timezone info — this makes it appear 5h30m in the future
      final localNow = DateTime.now();
      // Simulate: status was actually posted 2 hours ago in local time
      final actualPostTime = localNow.subtract(const Duration(hours: 2));
      // But it was stored as local time WITHOUT timezone marker
      // Supabase then treats it as UTC → when returned it has +00:00
      // This makes it appear (actual_IST + 0h offset) when it should be (actual_IST - 5h30)
      // We simulate the "future timestamp" scenario:
      final buggyTimestamp = localNow
          .add(const Duration(hours: 3, minutes: 30)) // 5h30 - 2h = 3h30 in future
          .toUtc()
          .toIso8601String();

      final parsed = parseTimestamp(buggyTimestamp);
      final diff = DateTime.now().difference(parsed);

      // After correction, should be approximately 2 hours in the past, NOT future
      expect(diff.inMinutes, greaterThan(0),
          reason: 'Corrected timestamp should be in the past, not future');
    });

    test('formatTime returns "Just now" only for truly recent timestamps (< 60s)', () {
      final justNow = DateTime.now().toUtc().subtract(const Duration(seconds: 30));
      final result = formatTime(justNow.toIso8601String());
      expect(result, equals('Just now'));
    });

    test('formatTime does NOT return "Just now" for 2-hour-old status', () {
      final twoHoursAgo = DateTime.now().toUtc().subtract(const Duration(hours: 2));
      final result = formatTime(twoHoursAgo.toIso8601String());
      expect(result, isNot(equals('Just now')),
          reason: 'A 2-hour-old status must NOT show "Just now"');
    });

    test('formatTime returns minutes for status posted 30 minutes ago', () {
      final thirtyMinAgo = DateTime.now().toUtc().subtract(const Duration(minutes: 30));
      final result = formatTime(thirtyMinAgo.toIso8601String());
      expect(result, contains('min ago'));
      expect(result, contains('30'));
    });

    test('formatTime handles malformed string gracefully (no crash)', () {
      // Should not throw — falls back to DateTime.now() → 'Just now'
      String? result;
      expect(() { result = formatTime('not-a-date-string'); }, returnsNormally,
          reason: 'Should not throw on malformed input');
      expect(result, isNotNull);
      expect(result, isA<String>());
    });

    test('Negative diff (future timestamp) is corrected, shows reasonable time', () {
      // If a timestamp is in the future by ~5 hours (IST bug scenario),
      // it should be corrected so diff > 0
      final futureTimestamp = DateTime.now()
          .add(const Duration(hours: 5, minutes: 29))
          .toUtc()
          .toIso8601String();

      final parsed = parseTimestamp(futureTimestamp);
      final diff = DateTime.now().difference(parsed);

      // After correction, should not be significantly in the future
      expect(diff.inSeconds, greaterThan(-120),
          reason: 'After correction, timestamp should not be in the far future');
    });
  });

  group('Status Viewer Filter Tests', () {
    // ─── BUG 2: Owner should NOT appear in their own viewers list ─────────

    test('Viewer list with owner entry is filtered correctly', () {
      const ownerId = 'user-123';

      // Simulate raw DB rows from status_views
      final rawViewers = [
        {'viewer_id': 'user-456', 'viewed_at': DateTime.now().toUtc().toIso8601String(), 'profiles': {'name': 'Alice'}},
        {'viewer_id': ownerId,    'viewed_at': DateTime.now().toUtc().toIso8601String(), 'profiles': {'name': 'Me (Owner)'}},
        {'viewer_id': 'user-789', 'viewed_at': DateTime.now().toUtc().toIso8601String(), 'profiles': {'name': 'Bob'}},
      ];

      // Apply the same filter used in StatusService.getViewers
      final filtered = rawViewers.where((v) => v['viewer_id'] != ownerId).toList();

      expect(filtered.length, equals(2),
          reason: 'Owner should be excluded from their own viewer list');
      expect(filtered.any((v) => v['viewer_id'] == ownerId), isFalse,
          reason: 'Owner ID must not appear in filtered viewers');
      expect(filtered.map((v) => (v['profiles'] as Map)['name']).toList(),
          containsAll(['Alice', 'Bob']));
    });

    test('Viewer count is accurate (excludes owner)', () {
      const ownerId = 'owner-abc';

      final rawViewers = List.generate(5, (i) => {
        'viewer_id': i == 2 ? ownerId : 'user-$i',
        'viewed_at': DateTime.now().toUtc().toIso8601String(),
        'profiles': {'name': 'User $i'},
      });

      final filtered = rawViewers.where((v) => v['viewer_id'] != ownerId).toList();

      expect(filtered.length, equals(4),
          reason: 'Out of 5 viewers, 1 is the owner — should show 4');
    });

    test('Viewer list with no owner entry remains unchanged', () {
      const ownerId = 'owner-xyz';

      final rawViewers = [
        {'viewer_id': 'user-a', 'viewed_at': DateTime.now().toUtc().toIso8601String(), 'profiles': {'name': 'User A'}},
        {'viewer_id': 'user-b', 'viewed_at': DateTime.now().toUtc().toIso8601String(), 'profiles': {'name': 'User B'}},
      ];

      final filtered = rawViewers.where((v) => v['viewer_id'] != ownerId).toList();

      expect(filtered.length, equals(2),
          reason: 'No owner in list — count should stay the same');
    });

    test('Empty viewer list stays empty after filter', () {
      const ownerId = 'owner-abc';
      final rawViewers = <Map<String, dynamic>>[];
      final filtered = rawViewers.where((v) => v['viewer_id'] != ownerId).toList();
      expect(filtered, isEmpty);
    });
  });
}

