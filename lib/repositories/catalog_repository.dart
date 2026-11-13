import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/expedition.dart';
import '../models/faction.dart';
import '../models/item.dart';

/// Tabelas de catálogo (somente leitura para o app).
class CatalogRepository {
  CatalogRepository(this._client);
  final SupabaseClient _client;

  Future<List<Faction>> fetchFactions() async {
    final rows = await _client.from('factions').select().order('id');
    return rows.map(Faction.fromJson).toList();
  }

  Future<List<Item>> fetchItems() async {
    final rows = await _client.from('items').select().order('id');
    return rows.map(Item.fromJson).toList();
  }

  Future<List<ExpeditionType>> fetchExpeditionTypes() async {
    final rows = await _client
        .from('expedition_types')
        .select('*, expedition_rewards(*, items(*))')
        .order('duration_seconds');
    return rows.map(ExpeditionType.fromJson).toList();
  }
}
