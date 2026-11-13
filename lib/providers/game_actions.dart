import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors.dart';
import '../models/expedition.dart';
import '../models/item.dart';
import '../models/shelter.dart';
import 'auth_providers.dart';
import 'game_providers.dart';
import 'repository_providers.dart';

/// Imagem escolhida na câmera/galeria.
class PickedImage {
  const PickedImage({required this.bytes, required this.extension});
  final Uint8List bytes;
  final String extension;
}

/// Todas as ações do jogo. Cada ação chama o repositório (RPC no servidor)
/// e depois invalida os providers afetados, para que TODAS as telas
/// reflitam a mudança sem reiniciar o app.
class GameActions {
  GameActions(this._ref);
  final Ref _ref;

  String get _uid {
    final uid = _ref.read(currentUserIdProvider);
    if (uid == null) throw AppException('Sessão expirada. Entre novamente.');
    return uid;
  }

  void _refreshProgress() {
    _ref.invalidate(currentProfileProvider);
    _ref.invalidate(profileStatsProvider);
    _ref.invalidate(survivorRankingProvider);
    _ref.invalidate(factionRankingProvider);
  }

  // ---------------- Facção ----------------
  Future<void> chooseFaction(int factionId) async {
    await _ref.read(profileRepositoryProvider).chooseFaction(factionId);
    _ref.invalidate(inventoryProvider);
    _refreshProgress();
  }

  // ---------------- Perfil ----------------
  Future<void> updateAvatar(PickedImage image) async {
    final url = await _ref.read(storageRepositoryProvider).uploadImage(
          bucket: 'avatars',
          userId: _uid,
          bytes: image.bytes,
          extension: image.extension,
        );
    await _ref.read(profileRepositoryProvider).updateAvatar(_uid, url);
    _ref.invalidate(currentProfileProvider);
    _ref.invalidate(survivorRankingProvider);
  }

  // ---------------- Expedições ----------------
  Future<void> startExpedition(int typeId) async {
    await _ref.read(expeditionRepositoryProvider).start(typeId);
    _ref.invalidate(activeExpeditionProvider);
  }

  Future<ExpeditionResult> collectExpedition(String expeditionId) async {
    final result = await _ref.read(expeditionRepositoryProvider).collect(expeditionId);
    _ref.invalidate(activeExpeditionProvider);
    _ref.invalidate(inventoryProvider);
    _refreshProgress();
    return result;
  }

  // ---------------- Abrigos ----------------
  Future<String?> _uploadShelterPhoto(PickedImage? image) async {
    if (image == null) return null;
    return _ref.read(storageRepositoryProvider).uploadImage(
          bucket: 'shelters',
          userId: _uid,
          bytes: image.bytes,
          extension: image.extension,
        );
  }

  Future<String> createShelter(ShelterInput input, {PickedImage? photo}) async {
    final photoUrl = await _uploadShelterPhoto(photo);
    final id = await _ref.read(shelterRepositoryProvider).createShelter(
          ShelterInput(
            name: input.name,
            description: input.description,
            capacity: input.capacity,
            lat: input.lat,
            lng: input.lng,
            visibility: input.visibility,
            photoUrl: photoUrl,
          ),
        );
    _ref.invalidate(sheltersProvider);
    _ref.invalidate(myShelterListProvider);
    _refreshProgress();
    return id;
  }

  Future<void> updateShelter(String id, ShelterInput input, {PickedImage? newPhoto}) async {
    final photoUrl = await _uploadShelterPhoto(newPhoto) ?? input.photoUrl;
    await _ref.read(shelterRepositoryProvider).updateShelter(
          id,
          ShelterInput(
            name: input.name,
            description: input.description,
            capacity: input.capacity,
            lat: input.lat,
            lng: input.lng,
            visibility: input.visibility,
            status: input.status,
            photoUrl: photoUrl,
          ),
        );
    _ref.invalidate(sheltersProvider);
    _ref.invalidate(myShelterListProvider);
    _ref.invalidate(shelterProvider(id));
  }

  Future<void> deleteShelter(String id) async {
    await _ref.read(shelterRepositoryProvider).deleteShelter(id);
    _ref.invalidate(sheltersProvider);
    _ref.invalidate(myShelterListProvider);
    _refreshProgress();
  }

  // ---------------- Alertas ----------------
  Future<void> reportHorde({
    required double lat,
    required double lng,
    required String intensity,
    required String description,
  }) async {
    await _ref.read(alertRepositoryProvider).report(
          lat: lat,
          lng: lng,
          intensity: intensity,
          description: description,
        );
    _ref.invalidate(activeAlertsProvider);
  }

  Future<bool> confirmAlert(String alertId) async {
    final rewarded = await _ref.read(alertRepositoryProvider).confirm(alertId);
    _ref.invalidate(activeAlertsProvider);
    _ref.invalidate(myAlertConfirmationsProvider);
    _ref.invalidate(profileStatsProvider);
    if (rewarded) {
      _ref.invalidate(survivorRankingProvider);
      _ref.invalidate(factionRankingProvider);
    }
    return rewarded;
  }

  // ---------------- Trocas ----------------
  Future<String> createTrade({
    required String toUser,
    required List<ItemAmount> offered,
    required List<ItemAmount> requested,
    String? message,
  }) async {
    if (offered.isEmpty || requested.isEmpty) {
      throw AppException('Escolha pelo menos um item oferecido e um item pedido.');
    }
    final id = await _ref.read(tradeRepositoryProvider).createTrade(
          toUser: toUser,
          offered: offered,
          requested: requested,
          message: message,
        );
    _ref.invalidate(tradesProvider);
    return id;
  }

  Future<void> acceptTrade(String id) => _resolveTrade(id, _ref.read(tradeRepositoryProvider).accept);
  Future<void> rejectTrade(String id) => _resolveTrade(id, _ref.read(tradeRepositoryProvider).reject);
  Future<void> cancelTrade(String id) => _resolveTrade(id, _ref.read(tradeRepositoryProvider).cancel);

  Future<void> _resolveTrade(String id, Future<void> Function(String) action) async {
    try {
      await action(id);
    } finally {
      // Mesmo em caso de erro (ex.: expirou), atualiza a lista.
      _ref.invalidate(tradesProvider);
      _ref.invalidate(tradeProvider(id));
      _ref.invalidate(inventoryProvider);
      _refreshProgress();
    }
  }

  /// Puxar para atualizar.
  void refreshAll() {
    _ref.invalidate(inventoryProvider);
    _ref.invalidate(activeExpeditionProvider);
    _ref.invalidate(activeAlertsProvider);
    _ref.invalidate(tradesProvider);
    _ref.invalidate(sheltersProvider);
    _refreshProgress();
  }
}

final gameActionsProvider = Provider((ref) => GameActions(ref));
