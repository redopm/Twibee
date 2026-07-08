import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> checkSchema() async {
  final res = await Supabase.instance.client
      .from('messages')
      .select('reply_to_id')
      .limit(1);
  print('Schema check: $res');
}

