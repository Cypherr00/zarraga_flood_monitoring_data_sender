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

  Future<int> getIdUsingUserName(String userName) async {
    final response = await _client
        .from('user')
        .select('id')
        .eq('user_name', userName)
        .single();
    return response['id'] as int;
  }



  Future<List<String>> getAllUsers() async {
    final response = await _client.from('user').select('user_name');
    return (response as List).map((e) => e['user_name'] as String).toList();
  }



  Future<List<Map<String, dynamic>>> getFloodLevelHistory(String filter) async {
    final client = Supabase.instance.client; // or use your _client

    // normalize filter
    final String normalized = switch (filter) {
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

    var sensorsQuery = client
        .from('WaterLevelData')
        .select('id, user_id, meters, created_at');

    if (cutoff != null) {
      sensorsQuery = sensorsQuery.gte('created_at', cutoff.toIso8601String());
    }

    final sensorsResp = await sensorsQuery.order('created_at', ascending: false);
    final List sensors = sensorsResp as List<dynamic>;


    if (sensors.isEmpty) return [];


    final List sensorIds = sensors.map((s) => s['id']).where((id) => id != null).toList();


    List alerts = [];
    if (sensorIds.isNotEmpty) {
      final alertsResp = await client
          .from('Alerts')
          .select('id, water_level_id, threat_level, message_advisory, time, meters')
          .eq('water_level_id', sensorIds)
          .order('time', ascending: false);
      alerts = alertsResp as List<dynamic>;
    }


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

    var query = _client.from('WaterLevelData').select(
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
    required int userId,
    required double meters,
    required bool isOverflow,
  }) async {
    if (meters < 0) {
      throw Exception("Meters cannot be negative.");
    }

    // If overflow, treat meters as 4 for alerts
    final effectiveMeters = meters;

    // Insert water level with is_overflow flag
    final insertedWaterLevel = await _client
        .from('WaterLevelData')
        .insert({
      'meters': meters,
      'user_id': userId,
    })
        .select()
        .single();

    final waterLevelId = insertedWaterLevel['id'];

    // Only create alerts for meters > 2
    if (effectiveMeters > 2) {
      String threatLevel = "Medium Threat";
      String messageAdvisory = "Water level exceeded 2m";

      if (effectiveMeters > 4) {
        threatLevel = "Very High Threat";
        messageAdvisory =
        "Threat Level: Very High Threat - Immediate evacuation required. Follow emergency services instructions.";
      } else if (effectiveMeters > 3) {
        threatLevel = "High Threat";
        messageAdvisory =
        "Threat Level: High Threat - Avoid flood-prone areas and secure belongings. Be ready to evacuate if necessary.";
      } else if (effectiveMeters > 2) {
        threatLevel = "Medium Threat";
        messageAdvisory =
        "Threat Level: Medium Threat - Minor flooding in low-lying areas is possible. Stay informed and monitor local weather updates.";
      }

      await _client.from('Alerts').insert({
        'water_level_id': waterLevelId,
        'message_advisory': messageAdvisory,
        'threat_level': threatLevel,
        'meters': effectiveMeters,
        'is_overflow': isOverflow
      });
    }
  }


  RealtimeChannel subscribeLatestWaterLevel(void Function(Map<String, dynamic>) onChange) {
    final channel = _client.channel('realtime:WaterLevelData').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'WaterLevelData',
      callback: (payload) async {
        final data = payload.newRecord;
        if (data != null) {
          final res = await _client
              .from('WaterLevelData')
              .select('id, created_at, meters, user(user_name)')
              .eq('id', data['id'])
              .maybeSingle();
          if (res != null) {
            onChange(res as Map<String, dynamic>);
          }
        }
      },
    ).subscribe();

    return channel;
  }
// Subscribe for realtime updates
  Future<Map<String, dynamic>?> fetchLatestWaterLevel() async {
    final response = await _client
        .from('WaterLevelData')
        .select('id, created_at, meters, user(user_name)')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response as Map<String, dynamic>?;
  }
}





