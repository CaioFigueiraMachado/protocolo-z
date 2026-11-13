import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/faction.dart';

/// Emblema da facção (SVG em estêncil).
class FactionEmblem extends StatelessWidget {
  const FactionEmblem({super.key, required this.faction, this.size = 40, this.dark = false});
  final Faction faction;
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      dark ? faction.darkEmblemAsset : faction.emblemAsset,
      width: size,
      height: size,
      semanticsLabel: 'Emblema ${faction.name}',
      placeholderBuilder: (_) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: faction.color, borderRadius: BorderRadius.circular(size * 0.16)),
      ),
    );
  }
}

/// Selo da facção: emblema + nome em pílula com a cor da facção.
/// Usado na Home, Perfil, Ranking, detalhes de abrigo e escolha de facção.
class FactionBadge extends StatelessWidget {
  const FactionBadge({super.key, required this.faction, this.compact = false});
  final Faction faction;

  /// compact = só o emblema pequeno, sem o nome.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) return FactionEmblem(faction: faction, size: 22);

    final deep = Color.lerp(faction.color, const Color(0xFF0F1226), 0.78)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        color: deep,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: faction.color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FactionEmblem(faction: faction, size: 24),
          const SizedBox(width: 8),
          Text(
            faction.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
