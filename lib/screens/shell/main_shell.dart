import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/game_providers.dart';
import '../../providers/realtime_providers.dart';
import '../../widgets/horde_alert_banner.dart';
import '../../widgets/player_avatar.dart';

/// Estrutura com a barra de navegação inferior persistente.
/// Também mantém o Realtime ativo e mostra alertas de horda por cima
/// de qualquer aba, assim que chegam.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mantém as assinaturas do Supabase Realtime enquanto o shell existir.
    ref.watch(realtimeSyncProvider);

    // Esconde o banner de horda depois de 10 s.
    ref.listen(incomingAlertProvider, (_, alert) {
      _hideTimer?.cancel();
      if (alert != null) {
        _hideTimer = Timer(const Duration(seconds: 10), () {
          if (mounted) ref.read(incomingAlertProvider.notifier).dismiss();
        });
      }
    });

    // Avisos de troca em tempo real.
    ref.listen(tradeNoticeProvider, (_, notice) {
      if (notice == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(notice.message),
          action: SnackBarAction(label: 'VER', onPressed: () => context.push('/trocas/${notice.tradeId}')),
        ));
    });

    final incoming = ref.watch(incomingAlertProvider);
    final pending = ref.watch(pendingReceivedCountProvider);
    final shell = widget.navigationShell;

    return Scaffold(
      body: Stack(
        children: [
          shell,
          // Destaque do alerta em tempo real, em qualquer aba.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween(begin: const Offset(0, -1.2), end: Offset.zero).animate(anim),
              child: child,
            ),
            child: incoming == null
                ? const SizedBox.shrink()
                : SafeArea(
                    key: ValueKey(incoming.id),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: HordeAlertBanner(
                        alert: incoming,
                        live: true,
                        onTap: () {
                          ref.read(incomingAlertProvider.notifier).dismiss();
                          shell.goBranch(1); // abre o Mapa
                        },
                        onDismiss: () => ref.read(incomingAlertProvider.notifier).dismiss(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield), label: 'Central'),
          const NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mapa'),
          const NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Expedições'),
          const NavigationDestination(
              icon: Icon(Icons.backpack_outlined), selectedIcon: Icon(Icons.backpack), label: 'Inventário'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: const Icon(Icons.swap_horiz),
            ),
            label: 'Trocas',
          ),
        ],
      ),
    );
  }
}

/// Ações do AppBar de todas as abas: Ranking e Perfil.
class ShellAppBarActions extends ConsumerWidget {
  const ShellAppBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        tooltip: 'Ranking',
        onPressed: () => context.push('/ranking'),
        icon: const Icon(Icons.leaderboard_outlined),
      ),
      Padding(
        padding: const EdgeInsets.only(right: 8, left: 4),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.push('/perfil'),
          child: Tooltip(
            message: 'Perfil',
            child: PlayerAvatar(
              nickname: profile?.nickname ?? '',
              url: profile?.avatarUrl,
              size: 34,
              borderColor: profile?.faction?.color ?? AppColors.outline,
            ),
          ),
        ),
      ),
    ]);
  }
}
