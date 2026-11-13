import 'package:flutter/material.dart';

import '../../core/theme.dart';

final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Informe o e-mail.';
  if (!_emailRegex.hasMatch(v)) return 'E-mail inválido.';
  return null;
}

String? validatePassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return 'Informe a senha.';
  if (v.length < 6) return 'A senha precisa ter pelo menos 6 caracteres.';
  return null;
}

final _nickRegex = RegExp(r'^[A-Za-z0-9_À-ÿ]+$');

String? validateNickname(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Informe um apelido.';
  if (v.length < 3 || v.length > 20) return 'O apelido deve ter de 3 a 20 caracteres.';
  if (!_nickRegex.hasMatch(v)) return 'Use apenas letras, números e _.';
  return null;
}

class AuthErrorBox extends StatelessWidget {
  const AuthErrorBox({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.6)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppColors.danger),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]),
    );
  }
}
