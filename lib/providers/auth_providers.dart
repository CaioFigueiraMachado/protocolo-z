import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repository_providers.dart';

/// Eventos de login/logout do Supabase Auth.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

/// Id do jogador autenticado (null = não autenticado).
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).currentUser?.id;
});

/// E-mail da sessão (exibido no perfil).
final currentEmailProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).currentUser?.email;
});

/// A splash fica visível até a animação de abertura terminar.
class SplashController extends Notifier<bool> {
  @override
  bool build() => false;

  void finish() => state = true;
}

final splashDoneProvider = NotifierProvider<SplashController, bool>(SplashController.new);

/// Ações de autenticação usadas pelas telas de login/cadastro/perfil.
class AuthController {
  AuthController(this._ref);
  final Ref _ref;

  /// Retorna true se o Supabase pedir confirmação de e-mail.
  Future<bool> signUp({required String nickname, required String email, required String password}) =>
      _ref.read(authRepositoryProvider).signUp(nickname: nickname, email: email, password: password);

  Future<void> signIn({required String email, required String password}) =>
      _ref.read(authRepositoryProvider).signIn(email: email, password: password);

  Future<void> signOut() => _ref.read(authRepositoryProvider).signOut();
}

final authControllerProvider = Provider((ref) => AuthController(ref));
