// db_config.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:digital_twin_data_sender/models/flood_level.dart';

class DbConfig {
  final SupabaseClient _client = Supabase.instance.client;

  // Check if user exists
  Future<bool> userExists(String userName) async {
    final response = await _client
        .from('user')
        .select('user_name')
        .eq('user_name', userName)
        .maybeSingle();

    return response != null;
  }

  // Verify pin for a user
  Future<bool> verifyPin(String userName, String pin) async {
    final response = await _client
        .from('user')
        .select('pin')
        .eq('user_name', userName)
        .maybeSingle();

    if (response == null) return false;
    return response['pin'] == pin;
  }

  // Fetch all users
  Future<List<String>> getAllUsers() async {
    final response = await _client.from('user').select('user_name');
    return (response as List).map((e) => e['user_name'] as String).toList();
  }

  // In db_config.dart (or wherever your DbConfig class is)
  Future<List<FloodLevel>> getFloodLevelHistory(String filter) async {
    // Normalize the filter coming from UI
    final String normalized = switch (filter) {
      '1d' => '1d',
      '1m' => '1m',
      'all' => 'all',
      _ => '1d', // default to last day for safety
    };

    // Compute cutoff in UTC (important when DB stores timestamptz)
    final nowUtc = DateTime.now().toUtc();
    DateTime? cutoff;
    if (normalized == '1d') {
      cutoff = nowUtc.subtract(const Duration(days: 1));
    } else if (normalized == '1m') {
      // Approximate 1 month as 30 days; adjust if you prefer calendar logic
      cutoff = nowUtc.subtract(const Duration(days: 30));
    } else {
      cutoff = null; // 'all'
    }

    // Build the query step-by-step so we can conditionally add filters
    var query = _client
        .from('SensorsData')
        .select('id, user_id, meters, created_at');

    if (cutoff != null) {
      // Use UTC ISO format
      query = query.gte('created_at', cutoff.toIso8601String());
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List)
        .map((e) => FloodLevel.fromMap(e))
        .toList();
  }

  Future<void> sendData({
    required String userName,
    required double meters,
  }) async {
    if (meters < 0 || meters > 4) {
      throw Exception("The maximum river depth measure is 4.");
    }

    // Get the user ID
    final user = await _client
        .from("user")
        .select("id")
        .eq('user_name', userName)
        .single();

    final userId = user['id'];

    // Insert into SensorsData and return the inserted row (with ID)
    final insertedWaterLevel = await _client
        .from('SensorsData')
        .insert({
      'meters': meters,
      'user_id': userId,
    })
        .select()
        .single();

    final waterLevelId = insertedWaterLevel['id'];

    if (meters > 2) {
      String threatLevel = "low";
      String message_advisory = "Water level exceeded 1m";

      if (meters > 4) {
        threatLevel = "Critical";
        message_advisory = "Threat Level: Critical - Immediate evacuation required. Follow emergency services instructions.";
      } else if (meters > 3) {
        threatLevel = "High";
        message_advisory = "Threat Level: High - Avoid flood-prone areas and secure belongings. Be ready to evacuate if necessary.";
      } else if (meters > 2) {
        threatLevel = "Low";
        message_advisory = "Threat Level: Low - Minor flooding in low-lying areas is possible. Stay informed and monitor local weather updates.";
      }

      await _client.from('Alerts').insert({
        'water_level_id': waterLevelId, // FK to SensorsData
        'message_advisory': message_advisory,
        'threat_level': threatLevel,
        'meters': meters,
      });
    }

  }

}


