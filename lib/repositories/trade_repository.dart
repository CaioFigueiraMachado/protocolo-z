import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors.dart';
import '../models/item.dart';
import '../models/trade.dart';

class TradeRepository {
  TradeRepository(this._client);
  final SupabaseClient _client;

  static const _select = '*, '
      'from_profile:profiles!trades_from_user_fkey(nickname), '
      'to_profile:profiles!trades_to_user_fkey(nickname), '
      'trade_items(*, items(*))';

  /// Propostas enviadas e recebidas (a RLS só devolve as do jogador).
  Future<List<Trade>> fetchTrades() async {
    // Marca como expiradas as pendentes com mais de 24 h (horário do servidor).
    await _client.rpc('expire_trades');
    final rows = await _client.from('trades').select(_select).order('created_at', ascending: false);
    return rows.map(Trade.fromJson).toList();
  }

  Future<Trade?> fetchTrade(String id) async {
    final row = await _client.from('trades').select(_select).eq('id', id).maybeSingle();
    return row == null ? null : Trade.fromJson(row);
  }

  Future<String> createTrade({
    required String toUser,
    required List<ItemAmount> offered,
    required List<ItemAmount> requested,
    String? message,
  }) async {
    return _client.rpc<String>('create_trade', params: {
      'p_to_user': toUser,
      'p_offered': offered.map((e) => e.toRpcJson()).toList(),
      'p_requested': requested.map((e) => e.toRpcJson()).toList(),
      'p_message': message,
    });
  }

  /// Aceite atômico no servidor (accept_trade).
  Future<void> accept(String id) => _resolve('accept_trade', id);
  Future<void> reject(String id) => _resolve('reject_trade', id);
  Future<void> cancel(String id) => _resolve('cancel_trade', id);

  Future<void> _resolve(String fn, String id) async {
    final status = await _client.rpc<String>(fn, params: {'p_trade_id': id});
    if (status == 'expirada') {
      throw AppException('Esta proposta expirou (mais de 24 h).');
    }
  }

  /// Realtime: qualquer INSERT/UPDATE em trades visível pela RLS.
  RealtimeChannel subscribe(void Function(PostgresChangePayload payload) onChange) {
    return _client
        .channel('pz-trades')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trades',
          callback: onChange,
        )
        .subscribe();
  }

  Future<void> unsubscribe(RealtimeChannel channel) => _client.removeChannel(channel);
}
