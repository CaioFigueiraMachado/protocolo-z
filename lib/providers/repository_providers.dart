import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/alert_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/expedition_repository.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/location_service.dart';
import '../repositories/profile_repository.dart';
import '../repositories/ranking_repository.dart';
import '../repositories/shelter_repository.dart';
import '../repositories/storage_repository.dart';
import '../repositories/trade_repository.dart';

/// Único ponto do app que conhece o cliente Supabase.
/// As telas nunca usam o cliente diretamente: passam pelos repositórios.
final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(supabaseClientProvider)));
final profileRepositoryProvider = Provider((ref) => ProfileRepository(ref.watch(supabaseClientProvider)));
final catalogRepositoryProvider = Provider((ref) => CatalogRepository(ref.watch(supabaseClientProvider)));
final inventoryRepositoryProvider = Provider((ref) => InventoryRepository(ref.watch(supabaseClientProvider)));
final shelterRepositoryProvider = Provider((ref) => ShelterRepository(ref.watch(supabaseClientProvider)));
final storageRepositoryProvider = Provider((ref) => StorageRepository(ref.watch(supabaseClientProvider)));
final expeditionRepositoryProvider = Provider((ref) => ExpeditionRepository(ref.watch(supabaseClientProvider)));
final tradeRepositoryProvider = Provider((ref) => TradeRepository(ref.watch(supabaseClientProvider)));
final alertRepositoryProvider = Provider((ref) => AlertRepository(ref.watch(supabaseClientProvider)));
final rankingRepositoryProvider = Provider((ref) => RankingRepository(ref.watch(supabaseClientProvider)));
final locationServiceProvider = Provider((ref) => LocationService());
