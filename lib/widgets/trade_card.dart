import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../models/trade.dart';

Color tradeStatusColor(TradeStatus status) => switch (status) {
      TradeStatus.pendente => AppColors.signal,
      TradeStatus.aceita => AppColors.success,
      TradeStatus.recusada => AppColors.danger,
      TradeStatus.cancelada => AppColors.textMuted,
      TradeStatus.expirada => AppColors.textMuted,
    };

class TradeStatusChip extends StatelessWidget {
  const TradeStatusChip({super.key, required this.status});
  final TradeStatus status;

  @override
  Widget build(BuildContext context) {
    final color = tradeStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(status.label.toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
    );
  }
}

/// Proposta de troca com itens e status. Usado em Trocas e na Home.
class TradeCard extends StatelessWidget {
  const TradeCard({super.key, required this.trade, required this.myId, this.onTap});
  final Trade trade;
  final String? myId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final received = trade.toUser == myId;
    final other = received ? trade.fromNickname : trade.toNickname;
    final theme = Theme.of(context);

    String items(List list) => list.map((e) => '${e.quantity}× ${e.item.icon}').join('  ');

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(received ? Icons.call_received : Icons.call_made,
                    size: 18, color: received ? AppColors.cobaltLight : AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(received ? 'De $other' : 'Para $other',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
                TradeStatusChip(status: trade.status),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _Side(label: received ? 'Você recebe' : 'Você dá', text: items(trade.offered))),
                const Icon(Icons.swap_horiz, color: AppColors.textMuted),
                Expanded(child: _Side(label: received ? 'Você dá' : 'Você recebe', text: items(trade.requested))),
              ]),
              const SizedBox(height: 8),
              Text(
                DateFormat("dd/MM 'às' HH:mm").format(trade.createdAt.toLocal()),
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.label, required this.text});
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(text.isEmpty ? '—' : text, style: const TextStyle(fontSize: 16)),
      ],
    );
  }
}
