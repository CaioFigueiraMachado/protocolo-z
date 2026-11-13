import 'package:flutter/material.dart';

import '../core/theme.dart';

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.nickname, this.url, this.size = 40, this.borderColor});
  final String nickname;
  final String? url;
  final double size;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final initial = nickname.isEmpty ? '?' : nickname.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceHigh,
        border: Border.all(color: borderColor ?? AppColors.outline, width: size > 60 ? 3 : 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: url != null
          ? Image.network(
              url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _Initial(initial: initial, size: size),
            )
          : _Initial(initial: initial, size: size),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.initial, required this.size});
  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Text(initial, style: AppText.display(size: size * 0.42, color: AppColors.cobaltLight));
}
