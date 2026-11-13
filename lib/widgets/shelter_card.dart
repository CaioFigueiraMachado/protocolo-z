import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/shelter.dart';
import 'faction_badge.dart';

/// Resumo de um abrigo. Usado na lista do Mapa e no Perfil ("Meus abrigos").
class ShelterCard extends StatelessWidget {
  const ShelterCard({super.key, required this.shelter, this.onTap});
  final Shelter shelter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 88,
              height: 88,
              child: shelter.photoUrl != null
                  ? Image.network(
                      shelter.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _PhotoPlaceholder(),
                    )
                  : const _PhotoPlaceholder(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (shelter.faction != null) ...[
                        FactionBadge(faction: shelter.faction!, compact: true),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(shelter.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      StatusChip(safe: shelter.isSafe),
                      _MiniChip(
                        icon: shelter.isFactionOnly ? Icons.lock : Icons.public,
                        label: shelter.isFactionOnly ? 'Da facção' : 'Público',
                      ),
                      _MiniChip(icon: Icons.groups, label: '${shelter.capacity}'),
                    ]),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.chevron_right, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.safe});
  final bool safe;

  @override
  Widget build(BuildContext context) {
    final color = safe ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        safe ? 'SEGURO' : 'COMPROMETIDO',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ]),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surfaceHigh,
        alignment: Alignment.center,
        child: const Icon(Icons.house_siding, color: AppColors.textMuted, size: 32),
      );
}
