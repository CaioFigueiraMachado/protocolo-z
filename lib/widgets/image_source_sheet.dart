import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/game_actions.dart';

/// Pergunta câmera ou galeria e devolve a imagem escolhida (ou null).
Future<PickedImage?> pickImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!kIsWeb)
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Tirar foto'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
        ListTile(
          leading: const Icon(Icons.photo_library),
          title: const Text('Escolher da galeria'),
          onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
        ),
      ]),
    ),
  );
  if (source == null) return null;

  try {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 80,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final name = file.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : 'jpg';
    return PickedImage(bytes: bytes, extension: ext);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível acessar a câmera/galeria. Verifique as permissões.')),
      );
    }
    return null;
  }
}
