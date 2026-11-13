import 'package:flutter/material.dart';

import '../core/server_clock.dart';
import '../core/theme.dart';
import '../models/horde_alert.dart';

/// Destaque visual de um alerta de horda.
/// Usado no topo de qualquer tela (tempo real), na Home e no Mapa.
class HordeAlertBanner extends StatelessWidget {
  const HordeAlertBanner({
    super.key,
    required this.alert,
    this.onTap,
    this.onDismiss,
    this.live = false,
  });

  final HordeAlert alert;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  /// true quando acabou de chegar pelo Realtime (visual mais chamativo).
  final bool live;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.intensity(alert.intensity);
    final minutesLeft = alert.expiresAt.difference(ServerClock.now()).inMinutes.clamp(0, 30);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(
            color: Color.lerp(AppColors.surface, color, live ? 0.32 : 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color, width: live ? 2 : 1),
            boxShadow: live
                ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 18, spreadRadius: 1)]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      live ? 'HORDA AVISTADA AGORA · ${alert.intensityLabel.toUpperCase()}' : 'Horda · intensidade ${alert.intensityLabel.toLowerCase()}',
                      style: AppText.display(size: 13, color: color),
                    ),
                    const SizedBox(height: 2),
                    Text(alert.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${alert.confirmations} confirmação(ões) · expira em $minutesLeft min',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  tooltip: 'Dispensar',
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
