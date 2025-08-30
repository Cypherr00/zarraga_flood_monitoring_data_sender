// db_config.dart
import 'package:supabase_flutter/supabase_flutter.dart';


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
  Future<List<Map<String, dynamic>>> getFloodLevelHistory(String filter) async {
    final client = Supabase.instance.client; // or use your _client

    // normalize filter
    final String normalized = switch (filter) {
      '1d' => '1d',
      '1m' => '1m',
      'all' => 'all',
      _ => '1d',
    };

    // cutoff in UTC
    final nowUtc = DateTime.now().toUtc();
    DateTime? cutoff;
    if (normalized == '1d') {
      cutoff = nowUtc.subtract(const Duration(days: 1));
    } else if (normalized == '1m') {
      cutoff = nowUtc.subtract(const Duration(days: 30));
    }

    // 1) fetch sensors
    var sensorsQuery = client
        .from('WaterLevelDataa')
        .select('id, user_id, meters, created_at');

    if (cutoff != null) {
      sensorsQuery = sensorsQuery.gte('created_at', cutoff.toIso8601String());
    }

    final sensorsResp = await sensorsQuery.order('created_at', ascending: false);
    final List sensors = sensorsResp as List<dynamic>;

    // If no sensor rows, return empty
    if (sensors.isEmpty) return [];

    // collect sensor ids
    final List sensorIds = sensors.map((s) => s['id']).where((id) => id != null).toList();

    // 2) fetch alerts that reference those sensor ids (if any)
    List alerts = [];
    if (sensorIds.isNotEmpty) {
      final alertsResp = await client
          .from('Alerts')
          .select('id, water_level_id, threat_level, message_advisory, time, meters')
          .eq('water_level_id', sensorIds)
          .order('time', ascending: false);
      alerts = alertsResp as List<dynamic>;
    }

    // 3) group alerts by water_level_id and pick the latest by 'time'
    final Map<dynamic, Map<String, dynamic>> latestAlertBySensor = {};

    for (final a in alerts) {
      final Map<String, dynamic> alert = Map<String, dynamic>.from(a as Map);
      final key = alert['water_level_id'];
      if (key == null) continue;

      if (!latestAlertBySensor.containsKey(key)) {
        latestAlertBySensor[key] = alert;
      } else {
        final existing = latestAlertBySensor[key]!;
        final existingTime = DateTime.tryParse(existing['time']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final candidateTime = DateTime.tryParse(alert['time']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (candidateTime.isAfter(existingTime)) {
          latestAlertBySensor[key] = alert;
        }
      }
    }

    // 4) merge: attach 'alert' object (nullable) to each sensor row
    final merged = sensors.map<Map<String, dynamic>>((s) {
      final Map<String, dynamic> sensor = Map<String, dynamic>.from(s as Map);
      sensor['alert'] = latestAlertBySensor[sensor['id']]; // either a Map or null
      return sensor;
    }).toList();

    return merged;
  }

  Future<List<Map<String, dynamic>>> getFloodLevelHistoryRaw(String filter) async {
    final normalized = switch (filter) {
      '1d' => '1d',
      '1m' => '1m',
      'all' => 'all',
      _ => '1d',
    };

    final nowUtc = DateTime.now().toUtc();
    DateTime? cutoff;
    if (normalized == '1d') {
      cutoff = nowUtc.subtract(const Duration(days: 1));
    } else if (normalized == '1m') {
      cutoff = nowUtc.subtract(const Duration(days: 30));
    }

    var query = _client.from('WaterLevelDataa').select(
      'id, user_id, meters, created_at, Alerts(threat_level, message_advisory)',
    );

    if (cutoff != null) {
      query = query.gte('created_at', cutoff.toIso8601String());
    }

    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response as List);
  }


//------------------------------------------------------------------
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

    // Insert into WaterLevelDataa and return the inserted row (with ID)
    final insertedWaterLevel = await _client
        .from('WaterLevelDataa')
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
        'water_level_id': waterLevelId, // FK to WaterLevelData
        'message_advisory': message_advisory,
        'threat_level': threatLevel,
        'meters': meters,
      });
    }

  }

}


