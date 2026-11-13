import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/server_clock.dart';
import '../models/expedition.dart';

class ExpeditionRepository {
  ExpeditionRepository(this._client);
  final SupabaseClient _client;

  /// Sincroniza o relógio local com o now() do servidor.
  Future<void> syncClock() async {
    final value = await _client.rpc<String>('server_now');
    ServerClock.sync(DateTime.parse(value));
  }

  /// Expedição em andamento (persistida no banco: sobrevive ao fechar o app).
  Future<Expedition?> fetchActive(String userId) async {
    final row = await _client
        .from('expeditions')
        .select('*, expedition_types(*, expedition_rewards(*, items(*)))')
        .eq('user_id', userId)
        .eq('status', 'em_andamento')
        .maybeSingle();
    return row == null ? null : Expedition.fromJson(row);
  }

  /// O servidor define início e fim (now() + duração).
  Future<void> start(int typeId) => _client.rpc('start_expedition', params: {'p_type_id': typeId});

  /// O servidor sorteia itens e quantidades.
  Future<ExpeditionResult> collect(String expeditionId) async {
    final data = await _client.rpc('collect_expedition', params: {'p_expedition_id': expeditionId});
    return ExpeditionResult.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
