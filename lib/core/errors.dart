import 'package:supabase_flutter/supabase_flutter.dart';

/// Converte qualquer erro em uma mensagem compreensível para o jogador.
///
/// As funções RPC do banco já devolvem mensagens em português
/// (ex.: "Você não possui mais esses itens."), então elas são repassadas.
String friendlyError(Object error) {
  if (error is String) return error;
  final text = error.toString();

  if (_isOffline(text)) {
    return 'Sem conexão com a internet. Verifique sua rede e tente novamente.';
  }

  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'Este e-mail já está cadastrado.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Confirme seu e-mail antes de entrar.';
    }
    if (msg.contains('password')) {
      return 'Senha fraca: use pelo menos 6 caracteres.';
    }
    if (msg.contains('rate limit') || error.statusCode == '429') {
      return 'Muitas tentativas. Aguarde alguns minutos.';
    }
    if (msg.contains('invalid') && msg.contains('email')) {
      return 'E-mail inválido.';
    }
    return error.message;
  }

  if (error is PostgrestException) {
    final msg = error.message;
    if (msg.contains('permission denied') || error.code == '42501') {
      return 'Ação não permitida pelo servidor.';
    }
    if (msg.contains('violates check constraint')) {
      return 'Algum valor informado é inválido.';
    }
    if (msg.contains('duplicate key') && msg.contains('nickname')) {
      return 'Este apelido já está em uso.';
    }
    if (msg.contains('JWT') || msg.contains('jwt')) {
      return 'Sua sessão expirou. Entre novamente.';
    }
    return msg;
  }

  if (error is StorageException) {
    if (error.statusCode == '413') return 'A imagem é muito grande (máx. 5 MB).';
    return 'Falha ao enviar a imagem: ${error.message}';
  }

  if (error is AppException) return error.message;

  return 'Algo deu errado. Tente novamente.';
}

bool _isOffline(String text) =>
    text.contains('SocketException') ||
    text.contains('Failed host lookup') ||
    text.contains('ClientException') ||
    text.contains('Connection refused') ||
    text.contains('Network is unreachable') ||
    text.contains('XMLHttpRequest error');

/// Erro de regra do próprio app (validação local).
class AppException implements Exception {
  AppException(this.message);
  final String message;
  @override
  String toString() => message;
}
