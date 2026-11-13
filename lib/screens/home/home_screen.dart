import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/faction.dart';
import '../../models/item.dart';
import '../../providers/game_actions.dart';
import '../../providers/game_providers.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/common.dart';
import '../../widgets/countdown_timer.dart';
import '../../widgets/faction_badge.dart';
import '../../widgets/horde_alert_banner.dart';
import '../shell/main_shell.dart';

/// Central de Sobrevivência: painel principal do jogador.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(children: [BrandMark(size: 28), SizedBox(width: 10), Text('CENTRAL')]),
        actions: const [ShellAppBarActions()],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(gameActionsProvider).refreshAll(),
        child: AsyncValueView(
          value: profileAsync,
          onRetry: () => ref.invalidate(currentProfileProvider),
          data: (profile) {
            if (profile == null) return const LoadingState();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _Greeting(nickname: profile.nickname, reputation: profile.reputation, faction: profile.faction),
                const SizedBox(height: 20),
                const _AlertsSection(),
                const SizedBox(height: 20),
                const _ExpeditionSection(),
                const SizedBox(height: 20),
                const _SuppliesSection(),
                const SizedBox(height: 20),
                const _TradesSection(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.nickname, required this.reputation, this.faction});
  final String nickname;
  final int reputation;
  final Faction? faction;

  String get _period {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    final faction = this.faction;
    final color = faction?.color ?? AppColors.cobalt;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [Color.lerp(AppColors.surface, color, 0.35)!, AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          if (faction != null) FactionEmblem(faction: faction, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_period,', style: const TextStyle(color: AppColors.textMuted)),
                Text(nickname, style: AppText.display(size: 24), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                if (faction != null) FactionBadge(faction: faction),
              ],
            ),
          ),
          Column(children: [
            const Icon(Icons.star_rounded, color: AppColors.signal, size: 28),
            Text('$reputation', style: AppText.display(size: 26, color: AppColors.signal)),
            const Text('reputação', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ],
      ),
    );
  }
}

class _AlertsSection extends ConsumerWidget {
  const _AlertsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(activeAlertsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Alertas de horda ativos',
          trailing: TextButton.icon(
            onPressed: () => context.push('/alertas/novo'),
            icon: const Icon(Icons.campaign_outlined, size: 18),
            label: const Text('Reportar'),
          ),
        ),
        AsyncValueView(
          value: alerts,
          onRetry: () => ref.invalidate(activeAlertsProvider),
          loading: const LinearProgressIndicator(),
          data: (list) {
            if (list.isEmpty) {
              return const _InfoCard(icon: Icons.verified_user_outlined, text: 'Nenhuma horda avistada. Por enquanto.');
            }
            return Column(children: [
              for (final a in list.take(3)) ...[
                HordeAlertBanner(alert: a, onTap: () => context.go('/mapa')),
                const SizedBox(height: 8),
              ],
              if (list.length > 3)
                TextButton(onPressed: () => context.go('/mapa'), child: Text('Ver todos (${list.length}) no mapa')),
            ]);
          },
        ),
      ],
    );
  }
}

class _ExpeditionSection extends ConsumerWidget {
  const _ExpeditionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeExpeditionProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Expedição'),
        AsyncValueView(
          value: active,
          onRetry: () => ref.invalidate(activeExpeditionProvider),
          loading: const LinearProgressIndicator(),
          data: (exp) {
            if (exp == null) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.explore, color: AppColors.cobaltLight),
                  title: const Text('Nenhuma expedição em andamento'),
                  subtitle: const Text('Envie seu sobrevivente atrás de suprimentos.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/expedicoes'),
                ),
              );
            }
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => context.go('/expedicoes'),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Text(exp.type?.icon ?? '🧭', style: const TextStyle(fontSize: 34)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(exp.type?.name ?? 'Expedição', style: const TextStyle(fontWeight: FontWeight.w700)),
                        const Text('Em andamento', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ]),
                    ),
                    CountdownTimer(
                      endsAt: exp.endsAt,
                      finishedText: 'COLETAR',
                      style: AppText.display(size: 24, color: AppColors.signal),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SuppliesSection extends ConsumerWidget {
  const _SuppliesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(inventoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Suprimentos',
          trailing: TextButton(onPressed: () => context.go('/inventario'), child: const Text('Inventário')),
        ),
        AsyncValueView(
          value: inventory,
          onRetry: () => ref.invalidate(inventoryProvider),
          loading: const LinearProgressIndicator(),
          data: (entries) {
            final totals = {for (final c in ItemCategory.values) c: 0};
            for (final e in entries) {
              totals[e.item.category] = totals[e.item.category]! + e.quantity;
            }
            return GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.78,
              children: [
                for (final c in ItemCategory.values)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(c.icon, color: totals[c]! > 0 ? AppColors.cobaltLight : AppColors.textMuted),
                      const SizedBox(height: 4),
                      Text('${totals[c]}',
                          style: AppText.display(size: 18, color: totals[c]! > 0 ? AppColors.text : AppColors.textMuted)),
                      Text(c.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ]),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TradesSection extends ConsumerWidget {
  const _TradesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingReceivedCountProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Trocas'),
        Card(
          child: ListTile(
            leading: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: const Icon(Icons.swap_horiz, color: AppColors.cobaltLight),
            ),
            title: Text(pending == 0
                ? 'Nenhuma proposta pendente'
                : pending == 1
                    ? '1 proposta aguardando sua resposta'
                    : '$pending propostas aguardando sua resposta'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/trocas'),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push('/ranking'),
          icon: const Icon(Icons.leaderboard_outlined),
          label: const Text('Ver ranking'),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(icon, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ]),
        ),
      );
}
