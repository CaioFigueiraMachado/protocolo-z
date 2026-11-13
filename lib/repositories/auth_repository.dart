import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors.dart';

class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
  User? get currentUser => _client.auth.currentUser;

  /// Cria a conta. O perfil é criado no banco pela trigger handle_new_user,
  /// usando o apelido enviado em `data`.
  /// Retorna `true` se o Supabase exigir confirmação de e-mail.
  Future<bool> signUp({
    required String nickname,
    required String email,
    required String password,
  }) async {
    final available = await _client.rpc<bool>(
      'nickname_available',
      params: {'p_nickname': nickname},
    );
    if (available != true) {
      throw AppException('Este apelido já está em uso. Escolha outro.');
    }

    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'nickname': nickname},
    );

    // Com confirmação de e-mail ativa, o Supabase devolve um usuário "fantasma"
    // sem identidades quando o e-mail já existe.
    final identities = response.user?.identities;
    if (response.user != null && identities != null && identities.isEmpty) {
      throw AppException('Este e-mail já está cadastrado.');
    }
    return response.session == null;
  }

  Future<void> signIn({required String email, required String password}) =>
      _client.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => _client.auth.signOut();
}
