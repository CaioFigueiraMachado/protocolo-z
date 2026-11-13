import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ranking.dart';

/// Rankings calculados por views no banco (a partir dos dados persistidos).
class RankingRepository {
  RankingRepository(this._client);
  final SupabaseClient _client;

  Future<List<SurvivorRank>> fetchSurvivors() async {
    final rows = await _client.from('survivor_ranking').select().order('position').limit(200);
    return rows.map(SurvivorRank.fromJson).toList();
  }

  Future<List<FactionRank>> fetchFactions() async {
    final rows = await _client.from('faction_ranking').select().order('total_reputation', ascending: false);
    return rows.map(FactionRank.fromJson).toList();
  }
}
