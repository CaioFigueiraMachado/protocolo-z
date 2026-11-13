import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/server_clock.dart';
import '../../core/theme.dart';
import '../../models/expedition.dart';
import '../../providers/game_actions.dart';
import '../../providers/game_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/countdown_timer.dart';
import '../../widgets/item_tile.dart';
import '../shell/main_shell.dart';

class ExpeditionsScreen extends ConsumerWidget {
  const ExpeditionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(expeditionTypesProvider);
    final active = ref.watch(activeExpeditionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('EXPEDIÇÕES'), actions: const [ShellAppBarActions()]),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeExpeditionProvider);
          ref.invalidate(expeditionTypesProvider);
        },
        child: AsyncValueView(
          value: types,
          onRetry: () => ref.invalidate(expeditionTypesProvider),
          data: (list) {
            final current = active.value;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (active.isLoading && !active.hasValue) const LinearProgressIndicator(),
                if (current != null) ...[
                  _ActiveExpeditionCard(expedition: current),
                  const SizedBox(height: 20),
                ],
                SectionTitle(current == null ? 'Escolha um destino' : 'Destinos'),
                if (current != null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text('Só é possível ter uma expedição por vez.',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                for (final t in list) ...[
                  _ExpeditionTypeCard(type: t, enabled: current == null && !active.isLoading),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActiveExpeditionCard extends ConsumerStatefulWidget {
  const _ActiveExpeditionCard({required this.expedition});
  final Expedition expedition;

  @override
  ConsumerState<_ActiveExpeditionCard> createState() => _ActiveExpeditionCardState();
}

class _ActiveExpeditionCardState extends ConsumerState<_ActiveExpeditionCard> {
  bool _collecting = false;

  Future<void> _collect() async {
    setState(() => _collecting = true);
    final result = await runAction(
      context,
      () => ref.read(gameActionsProvider).collectExpedition(widget.expedition.id),
    );
    if (!mounted) return;
    setState(() => _collecting = false);
    if (result != null) await _showResult(result);
  }

  Future<void> _showResult(ExpeditionResult result) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(result.success ? Icons.inventory_2 : Icons.dangerous,
            size: 40, color: result.success ? AppColors.success : AppColors.danger),
        title: Text(result.success ? 'Expedição concluída!' : 'Expedição fracassou'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!result.success)
              const Text('Seu sobrevivente encontrou errantes demais e voltou de mãos vazias.')
            else ...[
              const Text('O servidor sorteou estas recompensas:'),
              const SizedBox(height: 12),
              for (final i in result.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Text(i.icon, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(i.name)),
                    Text('+${i.quantity}', style: AppText.display(size: 18, color: AppColors.signal)),
                  ]),
                ),
              const Divider(height: 24),
              Row(children: [
                const Icon(Icons.star_rounded, color: AppColors.signal),
                const SizedBox(width: 8),
                Text('+${result.reputation} de reputação', style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ],
          ],
        ),
        actions: [FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exp = widget.expedition;
    final type = exp.type;
    final total = exp.endsAt.difference(exp.startedAt).inSeconds;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cobalt, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Text(type?.icon ?? '🧭', style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('EM ANDAMENTO', style: TextStyle(fontSize: 11, color: AppColors.cobaltLight, letterSpacing: 1)),
                  Text(type?.name ?? 'Expedição', style: AppText.display(size: 20)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            Center(
              child: CountdownTimer(
                endsAt: exp.endsAt,
                finishedText: 'DE VOLTA!',
                style: AppText.display(size: 48, color: AppColors.signal),
                onFinished: () => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            _ProgressBar(startedAt: exp.startedAt, totalSeconds: total),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: exp.isFinished && !_collecting ? _collect : null,
              icon: _collecting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.inventory_2),
              label: Text(exp.isFinished ? 'COLETAR RECOMPENSAS' : 'AGUARDANDO RETORNO'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de progresso que se atualiza junto com a contagem.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.startedAt, required this.totalSeconds});
  final DateTime startedAt;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (_, _) {
        final elapsed = ServerClock.now().difference(startedAt).inSeconds;
        final v = totalSeconds <= 0 ? 1.0 : (elapsed / totalSeconds).clamp(0.0, 1.0);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: v, minHeight: 8, color: AppColors.signal),
        );
      },
    );
  }
}

class _ExpeditionTypeCard extends ConsumerStatefulWidget {
  const _ExpeditionTypeCard({required this.type, required this.enabled});
  final ExpeditionType type;
  final bool enabled;

  @override
  ConsumerState<_ExpeditionTypeCard> createState() => _ExpeditionTypeCardState();
}

class _ExpeditionTypeCardState extends ConsumerState<_ExpeditionTypeCard> {
  bool _starting = false;

  Color get _riskColor => switch (widget.type.risk) {
        'alto' => AppColors.danger,
        'medio' => AppColors.warning,
        _ => AppColors.success,
      };

  Future<void> _start() async {
    final t = widget.type;
    final ok = await confirmAction(
      context,
      title: 'Partir para ${t.name}?',
      message: 'Duração: ${t.durationLabel}. ${t.riskLabel}'
          '${t.failureChance > 0 ? ' (${(t.failureChance * 100).round()}% de chance de voltar sem nada)' : ''}.',
      confirmLabel: 'Partir',
    );
    if (!ok || !mounted) return;
    setState(() => _starting = true);
    await runAction(context, () => ref.read(gameActionsProvider).startExpedition(t.id),
        success: 'Seu sobrevivente partiu para ${t.name}.');
    if (mounted) setState(() => _starting = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.type;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Text(t.icon, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.name, style: AppText.display(size: 18)),
                  Text(t.description, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              Chip(
                avatar: const Icon(Icons.timer_outlined, size: 16),
                label: Text(t.durationLabel),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                avatar: Icon(Icons.warning_amber_rounded, size: 16, color: _riskColor),
                label: Text(t.riskLabel),
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: _riskColor.withValues(alpha: 0.7)),
              ),
            ]),
            const SizedBox(height: 6),
            const Text('Possíveis recompensas', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            for (final r in t.rewards)
              ItemTile(
                item: r.item,
                quantity: r.maxQty,
                dense: true,
                trailing: Text(
                  '${r.minQty == r.maxQty ? '${r.minQty}' : '${r.minQty}–${r.maxQty}'} · ${(r.chance * 100).round()}%',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: widget.enabled && !_starting ? _start : null,
              child: _starting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('INICIAR EXPEDIÇÃO'),
            ),
          ],
        ),
      ),
    );
  }
}
