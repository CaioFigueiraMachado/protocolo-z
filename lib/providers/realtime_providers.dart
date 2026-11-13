import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/horde_alert.dart';
import 'auth_providers.dart';
import 'game_providers.dart';
import 'repository_providers.dart';

/// Último alerta de horda recebido em tempo real (exibido em qualquer tela).
class IncomingAlertController extends Notifier<HordeAlert?> {
  @override
  HordeAlert? build() => null;

  void show(HordeAlert alert) => state = alert;
  void dismiss() => state = null;
}

final incomingAlertProvider =
    NotifierProvider<IncomingAlertController, HordeAlert?>(IncomingAlertController.new);

/// Aviso de troca (nova proposta recebida, aceita, recusada...).
class TradeNotice {
  const TradeNotice({required this.tradeId, required this.message, required this.at});
  final String tradeId;
  final String message;
  final DateTime at;
}

class TradeNoticeController extends Notifier<TradeNotice?> {
  @override
  TradeNotice? build() => null;

  void push(String tradeId, String message) =>
      state = TradeNotice(tradeId: tradeId, message: message, at: DateTime.now());
}

final tradeNoticeProvider = NotifierProvider<TradeNoticeController, TradeNotice?>(TradeNoticeController.new);

/// Assina o Supabase Realtime enquanto o jogador está logado.
/// - horde_alerts: novos alertas aparecem para todos sem recarregar.
/// - trades: propostas recebidas/respondidas atualizam listas e inventário.
final realtimeSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return;

  final alertRepo = ref.watch(alertRepositoryProvider);
  final tradeRepo = ref.watch(tradeRepositoryProvider);

  final alertChannel = alertRepo.subscribe((payload) {
    ref.invalidate(activeAlertsProvider);
    if (payload.eventType == PostgresChangeEvent.insert) {
      try {
        final alert = HordeAlert.fromJson(payload.newRecord);
        if (alert.authorId != uid) {
          ref.read(incomingAlertProvider.notifier).show(alert);
        }
      } catch (_) {}
    }
  });

  final tradeChannel = tradeRepo.subscribe((payload) {
    ref.invalidate(tradesProvider);
    final row = payload.newRecord;
    final id = row['id'] as String?;
    if (id == null) return;
    ref.invalidate(tradeProvider(id));

    if (payload.eventType == PostgresChangeEvent.insert && row['to_user'] == uid) {
      ref.read(tradeNoticeProvider.notifier).push(id, 'Nova proposta de troca recebida!');
    } else if (payload.eventType == PostgresChangeEvent.update) {
      final status = row['status'];
      if (status == 'aceita') {
        ref.invalidate(inventoryProvider);
        ref.invalidate(currentProfileProvider);
        ref.invalidate(profileStatsProvider);
        ref.invalidate(survivorRankingProvider);
        ref.invalidate(factionRankingProvider);
      }
      if (row['from_user'] == uid) {
        final msg = switch (status) {
          'aceita' => 'Sua proposta foi aceita! Inventário atualizado.',
          'recusada' => 'Sua proposta foi recusada.',
          _ => null,
        };
        if (msg != null) ref.read(tradeNoticeProvider.notifier).push(id, msg);
      }
    }
  });

  ref.onDispose(() {
    alertRepo.unsubscribe(alertChannel);
    tradeRepo.unsubscribe(tradeChannel);
  });
});
