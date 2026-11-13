import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/horde_alert.dart';

class AlertRepository {
  AlertRepository(this._client);
  final SupabaseClient _client;

  /// A policy já esconde alertas expirados (expires_at > now()).
  Future<List<HordeAlert>> fetchActive() async {
    final rows = await _client
        .from('horde_alerts')
        .select('*, author:profiles(nickname)')
        .order('created_at', ascending: false);
    return rows.map(HordeAlert.fromJson).toList();
  }

  Future<Set<String>> fetchMyConfirmations() async {
    final rows = await _client.from('alert_confirmations').select('alert_id');
    return rows.map((r) => r['alert_id'] as String).toSet();
  }

  Future<void> report({
    required double lat,
    required double lng,
    required String intensity,
    required String description,
  }) =>
      _client.rpc('report_horde', params: {
        'p_lat': lat,
        'p_lng': lng,
        'p_intensity': intensity,
        'p_description': description,
      });

  /// Retorna true se esta confirmação deu reputação ao autor.
  Future<bool> confirm(String alertId) async {
    final data = await _client.rpc('confirm_alert', params: {'p_alert_id': alertId});
    return (data as Map)['author_rewarded'] == true;
  }

  /// Realtime: novos alertas e mudanças nas confirmações.
  RealtimeChannel subscribe(void Function(PostgresChangePayload payload) onChange) {
    return _client
        .channel('pz-horde-alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'horde_alerts',
          callback: onChange,
        )
        .subscribe();
  }

  Future<void> unsubscribe(RealtimeChannel channel) => _client.removeChannel(channel);
}
