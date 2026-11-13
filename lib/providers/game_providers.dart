import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/expedition.dart';
import '../models/faction.dart';
import '../models/horde_alert.dart';
import '../models/item.dart';
import '../models/profile.dart';
import '../models/ranking.dart';
import '../models/shelter.dart';
import '../models/trade.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';

// ---------------------------------------------------------------------------
// Perfil
// ---------------------------------------------------------------------------

/// Perfil do jogador logado. É a base do redirect do GoRouter:
/// null/sem facção/completo.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return null;
  // Sincroniza o relógio com o servidor (usado nas contagens regressivas).
  unawaited(ref.read(expeditionRepositoryProvider).syncClock().catchError((_) {}));
  return ref.watch(profileRepositoryProvider).fetchProfile(uid);
});

final profileStatsProvider = FutureProvider<ProfileStats>((ref) async {
  ref.watch(currentUserIdProvider);
  return ref.watch(profileRepositoryProvider).fetchStats();
});

final playerSearchProvider = FutureProvider.family<List<Profile>, String>((ref, query) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return [];
  return ref.watch(profileRepositoryProvider).searchPlayers(query, excludeId: uid);
});

// ---------------------------------------------------------------------------
// Catálogos
// ---------------------------------------------------------------------------

final factionsProvider = FutureProvider<List<Faction>>(
  (ref) => ref.watch(catalogRepositoryProvider).fetchFactions(),
);

final itemsProvider = FutureProvider<List<Item>>(
  (ref) => ref.watch(catalogRepositoryProvider).fetchItems(),
);

final expeditionTypesProvider = FutureProvider<List<ExpeditionType>>(
  (ref) => ref.watch(catalogRepositoryProvider).fetchExpeditionTypes(),
);

/// Facção por id (para ranking, abrigos etc.).
final factionByIdProvider = Provider.family<Faction?, int>((ref, id) {
  final list = ref.watch(factionsProvider).value ?? const [];
  for (final f in list) {
    if (f.id == id) return f;
  }
  return null;
});

// ---------------------------------------------------------------------------
// Inventário
// ---------------------------------------------------------------------------

final inventoryProvider = FutureProvider<List<InventoryEntry>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return [];
  return ref.watch(inventoryRepositoryProvider).fetchInventory(uid);
});

// ---------------------------------------------------------------------------
// Abrigos
// ---------------------------------------------------------------------------

final sheltersProvider = FutureProvider<List<Shelter>>((ref) async {
  ref.watch(currentUserIdProvider);
  return ref.watch(shelterRepositoryProvider).fetchShelters();
});

final myShelterListProvider = FutureProvider<List<Shelter>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return [];
  return ref.watch(shelterRepositoryProvider).fetchByAuthor(uid);
});

final shelterProvider = FutureProvider.family<Shelter?, String>(
  (ref, id) => ref.watch(shelterRepositoryProvider).fetchShelter(id),
);

// ---------------------------------------------------------------------------
// Expedições
// ---------------------------------------------------------------------------

final activeExpeditionProvider = FutureProvider<Expedition?>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return null;
  return ref.watch(expeditionRepositoryProvider).fetchActive(uid);
});

// ---------------------------------------------------------------------------
// Trocas
// ---------------------------------------------------------------------------

final tradesProvider = FutureProvider<List<Trade>>((ref) async {
  ref.watch(currentUserIdProvider);
  return ref.watch(tradeRepositoryProvider).fetchTrades();
});

final tradeProvider = FutureProvider.family<Trade?, String>(
  (ref, id) => ref.watch(tradeRepositoryProvider).fetchTrade(id),
);

/// Propostas recebidas ainda pendentes (contador da Home e da barra inferior).
final pendingReceivedCountProvider = Provider<int>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final trades = ref.watch(tradesProvider).value ?? const [];
  return trades.where((t) => t.toUser == uid && t.isPending).length;
});

// ---------------------------------------------------------------------------
// Alertas de horda
// ---------------------------------------------------------------------------

final activeAlertsProvider = FutureProvider<List<HordeAlert>>((ref) async {
  ref.watch(currentUserIdProvider);
  // Recarrega a cada minuto para sumir com os alertas que expiraram (30 min).
  final timer = Timer(const Duration(minutes: 1), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final list = await ref.watch(alertRepositoryProvider).fetchActive();
  return list.where((a) => a.isActive).toList();
});

final myAlertConfirmationsProvider = FutureProvider<Set<String>>((ref) async {
  ref.watch(currentUserIdProvider);
  return ref.watch(alertRepositoryProvider).fetchMyConfirmations();
});

// ---------------------------------------------------------------------------
// Rankings
// ---------------------------------------------------------------------------

final survivorRankingProvider = FutureProvider<List<SurvivorRank>>((ref) async {
  ref.watch(currentUserIdProvider);
  return ref.watch(rankingRepositoryProvider).fetchSurvivors();
});

final factionRankingProvider = FutureProvider<List<FactionRank>>((ref) async {
  ref.watch(currentUserIdProvider);
  return ref.watch(rankingRepositoryProvider).fetchFactions();
});
