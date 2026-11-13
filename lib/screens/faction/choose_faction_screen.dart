import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/faction.dart';
import '../../providers/auth_providers.dart';
import '../../providers/game_actions.dart';
import '../../providers/game_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/faction_badge.dart';

/// Escolha definitiva da facção (obrigatória antes de qualquer tela interna).
class ChooseFactionScreen extends ConsumerStatefulWidget {
  const ChooseFactionScreen({super.key});

  @override
  ConsumerState<ChooseFactionScreen> createState() => _ChooseFactionScreenState();
}

class _ChooseFactionScreenState extends ConsumerState<ChooseFactionScreen> {
  int? _selected;
  bool _saving = false;

  Future<void> _confirm(Faction faction) async {
    final ok = await confirmAction(
      context,
      title: 'Entrar para ${faction.name}?',
      message: 'A escolha é definitiva e não poderá ser alterada depois. '
          'Você receberá um kit inicial de suprimentos.',
      confirmLabel: 'Jurar lealdade',
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    await runAction(context, () => ref.read(gameActionsProvider).chooseFaction(faction.id),
        success: 'Bem-vindo à ${faction.name}! Kit inicial recebido.');
    if (mounted) setState(() => _saving = false);
    // O redirect leva à Central assim que o perfil recarregar com a facção.
  }

  @override
  Widget build(BuildContext context) {
    final factions = ref.watch(factionsProvider);
    final nickname = ref.watch(currentProfileProvider).value?.nickname ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('ESCOLHA SEU LADO'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => ref.read(authControllerProvider).signOut(),
            child: const Text('Sair'),
          ),
        ],
      ),
      body: AsyncValueView(
        value: factions,
        onRetry: () => ref.invalidate(factionsProvider),
        data: (list) {
          final selected = list.where((f) => f.id == _selected).firstOrNull;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    Text(
                      nickname.isEmpty ? 'Cada facção protege a rede de um jeito.' : '$nickname, cada facção protege a rede de um jeito.',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    for (final f in list) ...[
                      _FactionCard(
                        faction: f,
                        selected: f.id == _selected,
                        onTap: _saving ? null : () => setState(() => _selected = f.id),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: FilledButton(
                    style: selected == null
                        ? null
                        : FilledButton.styleFrom(backgroundColor: selected.color, foregroundColor: Colors.white),
                    onPressed: selected == null || _saving ? null : () => _confirm(selected),
                    child: _saving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : Text(selected == null ? 'SELECIONE UMA FACÇÃO' : 'ENTRAR PARA ${selected.name.toUpperCase()}'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FactionCard extends StatelessWidget {
  const _FactionCard({required this.faction, required this.selected, this.onTap});
  final Faction faction;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? Color.lerp(AppColors.surface, faction.color, 0.18) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? faction.color : AppColors.outline, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FactionEmblem(faction: faction, size: 72, dark: !selected),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(faction.name.toUpperCase(), style: AppText.display(size: 20))),
                      if (selected) Icon(Icons.check_circle, color: faction.color),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: faction.color, borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(width: 6),
                      Text('Especialidade: ${faction.specialty}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 8),
                    Text(faction.description, style: const TextStyle(fontSize: 13.5)),
                    if (faction.motto.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('“${faction.motto}”',
                          style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.textMuted)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
