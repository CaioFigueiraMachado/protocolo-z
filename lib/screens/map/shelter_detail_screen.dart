import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme.dart';
import '../../models/shelter.dart';
import '../../providers/auth_providers.dart';
import '../../providers/game_actions.dart';
import '../../providers/game_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/faction_badge.dart';
import '../../widgets/map_tiles.dart';
import '../../widgets/shelter_card.dart';

/// /abrigos/:id
class ShelterDetailScreen extends ConsumerWidget {
  const ShelterDetailScreen({super.key, required this.shelterId});
  final String shelterId;

  Future<void> _delete(BuildContext context, WidgetRef ref, Shelter s) async {
    final ok = await confirmAction(
      context,
      title: 'Excluir abrigo?',
      message: 'O abrigo "${s.name}" será removido do mapa e você perderá os 15 pontos de reputação ganhos com ele.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final done = await runAction(context, () async {
      await ref.read(gameActionsProvider).deleteShelter(s.id);
      return true;
    }, success: 'Abrigo excluído.');
    if (done == true && context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelter = ref.watch(shelterProvider(shelterId));
    final uid = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ABRIGO'),
        actions: [
          if (shelter.value?.authorId == uid && shelter.value != null) ...[
            IconButton(
              tooltip: 'Editar',
              onPressed: () => context.push('/abrigos/$shelterId/editar'),
              icon: const Icon(Icons.edit),
            ),
            IconButton(
              tooltip: 'Excluir',
              onPressed: () => _delete(context, ref, shelter.value!),
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            ),
          ],
        ],
      ),
      body: AsyncValueView(
        value: shelter,
        onRetry: () => ref.invalidate(shelterProvider(shelterId)),
        data: (s) {
          if (s == null) {
            return const EmptyState(
              icon: Icons.lock_outline,
              title: 'Abrigo indisponível',
              message: 'Ele foi removido ou pertence a outra facção.',
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: s.photoUrl != null
                    ? Image.network(
                        s.photoUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) =>
                            progress == null ? child : const Center(child: CircularProgressIndicator()),
                        errorBuilder: (_, _, _) => const _NoPhoto(),
                      )
                    : const _NoPhoto(),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: AppText.display(size: 26)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      if (s.faction != null) FactionBadge(faction: s.faction!),
                      StatusChip(safe: s.isSafe),
                      Chip(
                        avatar: Icon(s.isFactionOnly ? Icons.lock : Icons.public, size: 16),
                        label: Text(s.isFactionOnly ? 'Só da facção' : 'Público'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ]),
                    const SizedBox(height: 16),
                    if (s.description.isNotEmpty) ...[
                      Text(s.description),
                      const SizedBox(height: 16),
                    ],
                    _InfoRow(icon: Icons.groups, label: 'Capacidade', value: '${s.capacity} sobreviventes'),
                    _InfoRow(icon: Icons.person, label: 'Autor', value: s.authorNickname ?? '—'),
                    _InfoRow(
                      icon: Icons.event,
                      label: 'Cadastrado em',
                      value: DateFormat("dd/MM/yyyy 'às' HH:mm").format(s.createdAt.toLocal()),
                    ),
                    _InfoRow(
                      icon: Icons.place,
                      label: 'Coordenadas',
                      value: '${s.lat.toStringAsFixed(5)}, ${s.lng.toStringAsFixed(5)}',
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 180,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(s.lat, s.lng),
                            initialZoom: 15,
                            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                          ),
                          children: [
                            const AppTileLayer(),
                            MarkerLayer(markers: [
                              Marker(
                                point: LatLng(s.lat, s.lng),
                                width: 40,
                                height: 46,
                                alignment: Alignment.topCenter,
                                child: s.faction != null
                                    ? SvgPicture.asset(s.faction!.markerAsset)
                                    : const Icon(Icons.location_on, color: AppColors.signal, size: 40),
                              ),
                            ]),
                            const OsmAttribution(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(color: AppColors.textMuted)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

class _NoPhoto extends StatelessWidget {
  const _NoPhoto();

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surfaceHigh,
        alignment: Alignment.center,
        child: const Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.house_siding, size: 48, color: AppColors.textMuted),
          Text('Sem foto', style: TextStyle(color: AppColors.textMuted)),
        ]),
      );
}
