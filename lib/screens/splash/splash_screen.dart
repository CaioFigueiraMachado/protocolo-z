import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand.dart';
import '../../core/errors.dart';
import '../../core/theme.dart';
import '../../providers/auth_providers.dart';
import '../../providers/game_providers.dart';
import '../../widgets/app_logo.dart';

/// Splash: anima as três peças do Z em estêncil e depois libera o redirect
/// (login, escolha de facção ou Central, conforme o estado do jogador).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (mounted) ref.read(splashDoneProvider.notifier).finish();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Animation<double> _interval(double a, double b, [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _c, curve: Interval(a, b, curve: curve));

  @override
  Widget build(BuildContext context) {
    final splashDone = ref.watch(splashDoneProvider);
    final uid = ref.watch(currentUserIdProvider);
    final profile = uid == null ? null : ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StencilZ(
              top: _interval(0.0, 0.35),
              diagonal: _interval(0.2, 0.55),
              bottom: _interval(0.35, 0.7),
            ),
            const SizedBox(height: 28),
            FadeTransition(
              opacity: _interval(0.55, 0.9),
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(_interval(0.55, 0.9)),
                child: Column(children: [
                  const Wordmark(size: 36),
                  const SizedBox(height: 8),
                  Text(AppBrand.tagline, style: const TextStyle(color: AppColors.textMuted)),
                ]),
              ),
            ),
            const SizedBox(height: 40),
            if (splashDone && profile != null) _ProfileStatus(profile: profile),
          ],
        ),
      ),
    );
  }
}

/// Status exibido se o perfil demorar ou falhar ao carregar.
class _ProfileStatus extends ConsumerWidget {
  const _ProfileStatus({required this.profile});
  final AsyncValue profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (profile.hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(children: [
          Text(friendlyError(profile.error!), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(currentProfileProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar de novo'),
          ),
          TextButton(
            onPressed: () => ref.read(authControllerProvider).signOut(),
            child: const Text('Sair'),
          ),
        ]),
      );
    }
    if (profile.hasValue && profile.value == null) {
      return Column(children: [
        const Text('Perfil não encontrado.'),
        TextButton(onPressed: () => ref.read(authControllerProvider).signOut(), child: const Text('Sair')),
      ]);
    }
    return const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3));
  }
}

/// O Z da marca montado peça por peça (barras brancas + diagonal amarela).
class _StencilZ extends StatelessWidget {
  const _StencilZ({required this.top, required this.diagonal, required this.bottom});
  final Animation<double> top;
  final Animation<double> diagonal;
  final Animation<double> bottom;

  static const double size = 140;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(color: AppColors.cobalt, borderRadius: BorderRadius.circular(size * 0.16)),
        child: AnimatedBuilder(
          animation: Listenable.merge([top, diagonal, bottom]),
          builder: (context, _) => CustomPaint(
            painter: _ZPainter(top: top.value, diagonal: diagonal.value, bottom: bottom.value),
          ),
        ),
      ),
    );
  }
}

class _ZPainter extends CustomPainter {
  _ZPainter({required this.top, required this.diagonal, required this.bottom});
  final double top;
  final double diagonal;
  final double bottom;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 100; // grade de 100 unidades da prancha
    final white = Paint()..color = Colors.white;
    final yellow = Paint()..color = AppColors.signal;

    // Barra de cima entra pela esquerda
    canvas.drawRect(Rect.fromLTWH(22 * u, 22 * u, 56 * u * top, 14 * u), white);

    // Diagonal amarela
    if (diagonal > 0) {
      canvas.save();
      canvas.translate(50 * u, 50 * u);
      canvas.scale(diagonal);
      canvas.translate(-50 * u, -50 * u);
      final path = Path()
        ..moveTo(52 * u, 40 * u)
        ..lineTo(78 * u, 40 * u)
        ..lineTo(48 * u, 60 * u)
        ..lineTo(22 * u, 60 * u)
        ..close();
      canvas.drawPath(path, yellow);
      canvas.restore();
    }

    // Barra de baixo entra pela direita
    final w = 56 * u * bottom;
    canvas.drawRect(Rect.fromLTWH(78 * u - w, 64 * u, w, 14 * u), white);
  }

  @override
  bool shouldRepaint(_ZPainter old) => old.top != top || old.diagonal != diagonal || old.bottom != bottom;
}
