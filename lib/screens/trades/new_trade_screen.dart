import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/item.dart';
import '../../models/profile.dart';
import '../../providers/game_actions.dart';
import '../../providers/game_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/faction_badge.dart';
import '../../widgets/item_tile.dart';
import '../../widgets/player_avatar.dart';
import '../../widgets/quantity_stepper.dart';

/// /trocas/nova — escolher jogador, itens oferecidos e itens pedidos.
class NewTradeScreen extends ConsumerStatefulWidget {
  const NewTradeScreen({super.key});

  @override
  ConsumerState<NewTradeScreen> createState() => _NewTradeScreenState();
}

class _NewTradeScreenState extends ConsumerState<NewTradeScreen> {
  int _step = 0;
  Profile? _target;
  final Map<int, int> _offered = {};
  final Map<int, int> _requested = {};
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  List<ItemAmount> _amounts(Map<int, int> map, List<Item> items) => [
        for (final e in map.entries)
          if (e.value > 0) ItemAmount(item: items.firstWhere((i) => i.id == e.key), quantity: e.value),
      ];

  Future<void> _send(List<Item> catalog) async {
    final offered = _amounts(_offered, catalog);
    final requested = _amounts(_requested, catalog);
    if (_target == null) return;
    String fmt(List<ItemAmount> l) => l.map((e) => '${e.quantity}× ${e.item.name}').join(', ');

    final ok = await confirmAction(
      context,
      title: 'Enviar proposta para ${_target!.nickname}?',
      message: 'Você oferece: ${fmt(offered)}\nVocê pede: ${fmt(requested)}\n\nA proposta expira em 24 horas.',
      confirmLabel: 'Enviar',
    );
    if (!ok || !mounted) return;
    setState(() => _sending = true);
    final id = await runAction(
      context,
      () => ref.read(gameActionsProvider).createTrade(
            toUser: _target!.id,
            offered: offered,
            requested: requested,
            message: _message.text.trim().isEmpty ? null : _message.text.trim(),
          ),
      success: 'Proposta enviada para ${_target!.nickname}!',
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (id != null) context.pushReplacement('/trocas/$id');
  }

  bool get _hasOffered => _offered.values.any((v) => v > 0);
  bool get _hasRequested => _requested.values.any((v) => v > 0);

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(inventoryProvider);
    final catalog = ref.watch(itemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('NOVA PROPOSTA')),
      body: AsyncValueView(
        value: catalog,
        onRetry: () => ref.invalidate(itemsProvider),
        data: (items) => Stepper(
          currentStep: _step,
          onStepTapped: (s) => setState(() => _step = s),
          controlsBuilder: (context, details) {
            final isLast = _step == 2;
            final canContinue = switch (_step) {
              0 => _target != null,
              1 => _hasOffered,
              _ => _hasRequested,
            };
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: !canContinue || _sending
                        ? null
                        : isLast
                            ? () => _send(items)
                            : details.onStepContinue,
                    child: _sending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(isLast ? 'ENVIAR PROPOSTA' : 'CONTINUAR'),
                  ),
                ),
                if (_step > 0) ...[
                  const SizedBox(width: 8),
                  TextButton(onPressed: details.onStepCancel, child: const Text('Voltar')),
                ],
              ]),
            );
          },
          onStepContinue: () => setState(() => _step = (_step + 1).clamp(0, 2)),
          onStepCancel: () => setState(() => _step = (_step - 1).clamp(0, 2)),
          steps: [
            Step(
              title: const Text('Jogador'),
              subtitle: _target == null ? null : Text(_target!.nickname),
              isActive: _step >= 0,
              state: _target != null ? StepState.complete : StepState.indexed,
              content: _PlayerPicker(
                selected: _target,
                onSelected: (p) => setState(() {
                  _target = p;
                  _step = 1;
                }),
              ),
            ),
            Step(
              title: const Text('Você oferece'),
              isActive: _step >= 1,
              state: _hasOffered ? StepState.complete : StepState.indexed,
              content: AsyncValueView(
                value: inventory,
                onRetry: () => ref.invalidate(inventoryProvider),
                data: (entries) => entries.isEmpty
                    ? const Text('Seu inventário está vazio. Faça uma expedição primeiro.')
                    : Column(children: [
                        for (final e in entries)
                          ItemTile(
                            item: e.item,
                            quantity: e.quantity,
                            dense: true,
                            trailing: QuantityStepper(
                              value: _offered[e.item.id] ?? 0,
                              max: e.quantity,
                              onChanged: (v) => setState(() => _offered[e.item.id] = v),
                            ),
                          ),
                      ]),
              ),
            ),
            Step(
              title: const Text('Você pede'),
              isActive: _step >= 2,
              state: _hasRequested ? StepState.complete : StepState.indexed,
              content: Column(children: [
                for (final item in items)
                  ItemTile(
                    item: item,
                    quantity: 0,
                    dense: true,
                    trailing: QuantityStepper(
                      value: _requested[item.id] ?? 0,
                      max: 20,
                      onChanged: (v) => setState(() => _requested[item.id] = v),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _message,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Mensagem (opcional)'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerPicker extends ConsumerStatefulWidget {
  const _PlayerPicker({required this.selected, required this.onSelected});
  final Profile? selected;
  final ValueChanged<Profile> onSelected;

  @override
  ConsumerState<_PlayerPicker> createState() => _PlayerPickerState();
}

class _PlayerPickerState extends ConsumerState<_PlayerPicker> {
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final players = ref.watch(playerSearchProvider(_query));
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar sobrevivente pelo apelido'),
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = v.trim()));
          },
        ),
        const SizedBox(height: 8),
        AsyncValueView(
          value: players,
          onRetry: () => ref.invalidate(playerSearchProvider(_query)),
          data: (list) {
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nenhum sobrevivente encontrado.', style: TextStyle(color: AppColors.textMuted)),
              );
            }
            return Column(children: [
              for (final p in list)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  selected: widget.selected?.id == p.id,
                  leading: PlayerAvatar(nickname: p.nickname, url: p.avatarUrl, borderColor: p.faction?.color),
                  title: Text(p.nickname),
                  subtitle: p.faction == null ? null : Align(
                    alignment: Alignment.centerLeft,
                    child: FactionBadge(faction: p.faction!),
                  ),
                  trailing: widget.selected?.id == p.id
                      ? const Icon(Icons.check_circle, color: AppColors.signal)
                      : const Icon(Icons.chevron_right),
                  onTap: () => widget.onSelected(p),
                ),
            ]);
          },
        ),
      ],
    );
  }
}
