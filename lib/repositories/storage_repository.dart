import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Upload de imagens. A policy do Storage só aceita arquivos em
/// `<bucket>/<id do usuário>/...`, por isso o caminho começa com o userId.
class StorageRepository {
  StorageRepository(this._client);
  final SupabaseClient _client;

  Future<String> uploadImage({
    required String bucket,
    required String userId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final ext = extension.toLowerCase().replaceAll('.', '');
    final safeExt = ['png', 'webp'].contains(ext) ? ext : 'jpg';
    final contentType = switch (safeExt) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$safeExt';

    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return _client.storage.from(bucket).getPublicUrl(path);
  }
}
