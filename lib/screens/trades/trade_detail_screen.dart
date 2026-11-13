import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/trade.dart';
import '../../providers/auth_providers.dart';
import '../../providers/game_actions.dart';
import '../../providers/game_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/countdown_timer.dart';
import '../../widgets/item_tile.dart';
import '../../widgets/trade_card.dart';

/// /trocas/:id
class TradeDetailScreen extends ConsumerStatefulWidget {
  const TradeDetailScreen({super.key, required this.tradeId});
  final String tradeId;

  @override
  ConsumerState<TradeDetailScreen> createState() => _TradeDetailScreenState();
}

class _TradeDetailScreenState extends ConsumerState<TradeDetailScreen> {
  bool _busy = false;

  Future<void> _act({
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function() action,
    required String success,
    bool destructive = false,
  }) async {
    final ok = await confirmAction(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    await runAction(context, () async {
      await action();
      return true;
    }, success: success);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final trade = ref.watch(tradeProvider(widget.tradeId));
    final uid = ref.watch(currentUserIdProvider);
    final actions = ref.read(gameActionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('PROPOSTA')),
      body: AsyncValueView(
        value: trade,
        onRetry: () => ref.invalidate(tradeProvider(widget.tradeId)),
        data: (t) {
          if (t == null) return const EmptyState(icon: Icons.search_off, title: 'Proposta não encontrada');
          final received = t.toUser == uid;
          final canAnswer = received && t.isPending;
          final canCancel = t.fromUser == uid && t.isPending;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    received ? 'Proposta de ${t.fromNickname}' : 'Proposta para ${t.toNickname}',
                    style: AppText.display(size: 22),
                  ),
                ),
                TradeStatusChip(status: t.status),
              ]),
              const SizedBox(height: 6),
              Text(
                'Criada em ${DateFormat("dd/MM 'às' HH:mm").format(t.createdAt.toLocal())}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              if (t.isPending) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      const Icon(Icons.hourglass_bottom, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Expira em')),
                      CountdownTimer(
                        endsAt: t.expiresAt,
                        showHours: true,
                        finishedText: 'Expirada',
                        style: AppText.display(size: 18, color: AppColors.signal),
                        onFinished: () => ref.invalidate(tradeProvider(widget.tradeId)),
                      ),
                    ]),
                  ),
                ),
              ],
              if (t.message != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.format_quote, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t.message!, style: const TextStyle(fontStyle: FontStyle.italic))),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _ItemsBlock(
                title: received ? 'Você recebe' : 'Você oferece',
                items: t.offered,
                color: received ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(height: 12),
              _ItemsBlock(
                title: received ? 'Você entrega' : 'Você pede',
                items: t.requested,
                color: received ? AppColors.warning : AppColors.success,
              ),
              const SizedBox(height: 24),
              if (canAnswer) ...[
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _act(
                            title: 'Aceitar troca?',
                            message: 'Os itens serão transferidos entre os dois inventários de uma só vez. '
                                'Se faltar algum item, nada será alterado.',
                            confirmLabel: 'Aceitar',
                            action: () => actions.acceptTrade(t.id),
                            success: 'Troca concluída! +20 de reputação.',
                          ),
                  icon: const Icon(Icons.handshake),
                  label: const Text('ACEITAR'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _act(
                            title: 'Recusar proposta?',
                            message: 'O autor será avisado de que você recusou.',
                            confirmLabel: 'Recusar',
                            destructive: true,
                            action: () => actions.rejectTrade(t.id),
                            success: 'Proposta recusada.',
                          ),
                  icon: const Icon(Icons.close),
                  label: const Text('RECUSAR'),
                ),
              ],
              if (canCancel)
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _act(
                            title: 'Cancelar proposta?',
                            message: 'A proposta deixará de valer para ${t.toNickname}.',
                            confirmLabel: 'Cancelar proposta',
                            destructive: true,
                            action: () => actions.cancelTrade(t.id),
                            success: 'Proposta cancelada.',
                          ),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('CANCELAR PROPOSTA'),
                ),
              if (_busy) const Padding(padding: EdgeInsets.all(16), child: LoadingState()),
            ],
          );
        },
      ),
    );
  }
}

class _ItemsBlock extends StatelessWidget {
  const _ItemsBlock({required this.title, required this.items, required this.color});
  final String title;
  final List<TradeItem> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Text(title.toUpperCase(), style: AppText.display(size: 13, color: color)),
          ),
          for (final i in items) ItemTile(item: i.item, quantity: i.quantity),
        ],
      ),
    );
  }
}
