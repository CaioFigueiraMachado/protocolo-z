import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/item.dart';
import '../../providers/game_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/item_tile.dart';
import '../shell/main_shell.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  ItemCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(inventoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('INVENTÁRIO'), actions: const [ShellAppBarActions()]),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Todos'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                ),
                for (final c in ItemCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(c.icon, size: 16),
                      label: Text(c.label),
                      selected: _filter == c,
                      onSelected: (_) => setState(() => _filter = _filter == c ? null : c),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(inventoryProvider),
              child: AsyncValueView(
                value: inventory,
                onRetry: () => ref.invalidate(inventoryProvider),
                data: (entries) {
                  final filtered = _filter == null ? entries : entries.where((e) => e.item.category == _filter).toList();
                  if (filtered.isEmpty) {
                    return ListView(children: [
                      const SizedBox(height: 60),
                      EmptyState(
                        icon: Icons.backpack_outlined,
                        title: _filter == null ? 'Mochila vazia' : 'Nada de ${_filter!.label.toLowerCase()}',
                        message: 'Saia em expedições ou faça trocas para conseguir suprimentos.',
                        action: FilledButton.icon(
                          style: FilledButton.styleFrom(minimumSize: const Size(220, 48)),
                          onPressed: () => context.go('/expedicoes'),
                          icon: const Icon(Icons.explore),
                          label: const Text('IR PARA EXPEDIÇÕES'),
                        ),
                      ),
                    ]);
                  }

                  // Agrupa por categoria
                  final groups = <ItemCategory, List<InventoryEntry>>{};
                  for (final e in filtered) {
                    groups.putIfAbsent(e.item.category, () => []).add(e);
                  }
                  final total = filtered.fold<int>(0, (sum, e) => sum + e.quantity);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      Text('$total itens no total', style: const TextStyle(color: AppColors.textMuted)),
                      const SizedBox(height: 8),
                      for (final c in ItemCategory.values)
                        if (groups[c] != null) ...[
                          SectionTitle(c.label, trailing: Icon(c.icon, size: 18, color: AppColors.textMuted)),
                          Card(
                            child: Column(children: [
                              for (final e in groups[c]!) ItemTile(item: e.item, quantity: e.quantity),
                            ]),
                          ),
                          const SizedBox(height: 12),
                        ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
