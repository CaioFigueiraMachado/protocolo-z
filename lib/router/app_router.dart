import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';
import '../providers/game_providers.dart';
import '../screens/alerts/report_alert_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/expeditions/expeditions_screen.dart';
import '../screens/faction/choose_faction_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/map/shelter_detail_screen.dart';
import '../screens/map/shelter_form_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/ranking/ranking_screen.dart';
import '../screens/shell/main_shell.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/trades/new_trade_screen.dart';
import '../screens/trades/trade_detail_screen.dart';
import '../screens/trades/trades_screen.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Rotas públicas (acessíveis sem login).
const _authRoutes = {'/login', '/cadastro'};

/// Rotas de entrada: depois do cadastro completo, sempre vai para a Central.
const _entryRoutes = {'/splash', '/login', '/cadastro', '/faccao'};

final routerProvider = Provider<GoRouter>((ref) {
  // Notifica o GoRouter para reavaliar o redirect quando o estado muda.
  final refresh = ValueNotifier<int>(0);
  ref.listen(splashDoneProvider, (_, _) => refresh.value++);
  ref.listen(currentUserIdProvider, (_, _) => refresh.value++);
  ref.listen(currentProfileProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,

    // Redirect com os 3 estados do jogador:
    // 1) não autenticado      -> /login
    // 2) autenticado sem facção -> /faccao
    // 3) cadastro completo    -> rotas internas (/central ...)
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final splashDone = ref.read(splashDoneProvider);
      final uid = ref.read(currentUserIdProvider);
      final profileAsync = ref.read(currentProfileProvider);

      if (!splashDone) return loc == '/splash' ? null : '/splash';

      // 1) Não autenticado: só login e cadastro.
      if (uid == null) return _authRoutes.contains(loc) ? null : '/login';

      final profile = profileAsync.value;
      if (profile == null) {
        // Perfil ainda carregando (ou erro): fica na splash, que mostra o estado.
        return loc == '/splash' ? null : '/splash';
      }

      // 2) Autenticado sem facção: obrigatoriamente escolhe a facção.
      if (!profile.hasFaction) return loc == '/faccao' ? null : '/faccao';

      // 3) Cadastro completo: não volta para telas de entrada.
      if (_entryRoutes.contains(loc)) return '/central';
      return null;
    },

    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/cadastro', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/faccao', builder: (_, _) => const ChooseFactionScreen()),

      // Barra de navegação inferior persistente
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/central', builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/mapa', builder: (_, _) => const MapScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/expedicoes', builder: (_, _) => const ExpeditionsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/inventario', builder: (_, _) => const InventoryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/trocas', builder: (_, _) => const TradesScreen()),
          ]),
        ],
      ),

      // Telas empilhadas por cima da barra (com botão voltar no AppBar)
      GoRoute(
        path: '/abrigos/novo',
        parentNavigatorKey: _rootKey,
        builder: (_, state) {
          final lat = double.tryParse(state.uri.queryParameters['lat'] ?? '');
          final lng = double.tryParse(state.uri.queryParameters['lng'] ?? '');
          return ShelterFormScreen(initialLat: lat, initialLng: lng);
        },
      ),
      GoRoute(
        path: '/abrigos/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => ShelterDetailScreen(shelterId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'editar',
            parentNavigatorKey: _rootKey,
            builder: (_, state) => ShelterFormScreen(shelterId: state.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(
        path: '/trocas/nova',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const NewTradeScreen(),
      ),
      GoRoute(
        path: '/trocas/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => TradeDetailScreen(tradeId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/alertas/novo',
        parentNavigatorKey: _rootKey,
        builder: (_, state) {
          final lat = double.tryParse(state.uri.queryParameters['lat'] ?? '');
          final lng = double.tryParse(state.uri.queryParameters['lng'] ?? '');
          return ReportAlertScreen(initialLat: lat, initialLng: lng);
        },
      ),
      GoRoute(path: '/ranking', parentNavigatorKey: _rootKey, builder: (_, _) => const RankingScreen()),
      GoRoute(path: '/perfil', parentNavigatorKey: _rootKey, builder: (_, _) => const ProfileScreen()),
    ],
  );
});
