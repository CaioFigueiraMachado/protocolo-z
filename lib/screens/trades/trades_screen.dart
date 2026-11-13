import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/trade.dart';
import '../../providers/auth_providers.dart';
import '../../providers/game_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/trade_card.dart';
import '../shell/main_shell.dart';

/// Propostas recebidas e enviadas, separadas por status.
/// Novas propostas aparecem em tempo real (Supabase Realtime).
class TradesScreen extends ConsumerWidget {
  const TradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trades = ref.watch(tradesProvider);
    final uid = ref.watch(currentUserIdProvider);
    final pending = ref.watch(pendingReceivedCountProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TROCAS'),
          actions: const [ShellAppBarActions()],
          bottom: TabBar(tabs: [
            Tab(child: Badge(isLabelVisible: pending > 0, label: Text('$pending'), child: const Text('Recebidas'))),
            const Tab(text: 'Enviadas'),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/trocas/nova'),
          icon: const Icon(Icons.add),
          label: const Text('Nova proposta'),
        ),
        body: AsyncValueView(
          value: trades,
          onRetry: () => ref.invalidate(tradesProvider),
          data: (list) => TabBarView(children: [
            _TradeList(
              trades: list.where((t) => t.toUser == uid).toList(),
              myId: uid,
              emptyText: 'Nenhuma proposta recebida ainda.',
            ),
            _TradeList(
              trades: list.where((t) => t.fromUser == uid).toList(),
              myId: uid,
              emptyText: 'Você ainda não enviou propostas.',
            ),
          ]),
        ),
      ),
    );
  }
}

class _TradeList extends ConsumerWidget {
  const _TradeList({required this.trades, required this.myId, required this.emptyText});
  final List<Trade> trades;
  final String? myId;
  final String emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(tradesProvider),
      child: trades.isEmpty
          ? ListView(children: [
              const SizedBox(height: 80),
              EmptyState(icon: Icons.swap_horiz, title: 'Sem propostas', message: emptyText),
            ])
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                // Separadas por status: pendente, aceita, recusada, cancelada, expirada
                for (final status in TradeStatus.values)
                  if (trades.any((t) => t.status == status)) ...[
                    SectionTitle(
                      '${status.label}s',
                      trailing: Text('${trades.where((t) => t.status == status).length}'),
                    ),
                    for (final t in trades.where((t) => t.status == status)) ...[
                      TradeCard(trade: t, myId: myId, onTap: () => context.push('/trocas/${t.id}')),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 8),
                  ],
              ],
            ),
    );
  }
}
