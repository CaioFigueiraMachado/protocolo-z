import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);
  final SupabaseClient _client;

  Future<Profile?> fetchProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select('*, factions(*)')
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  /// Escolha definitiva da facção + kit inicial (tudo no servidor).
  Future<void> chooseFaction(int factionId) =>
      _client.rpc('choose_faction', params: {'p_faction_id': factionId});

  /// Apenas avatar e apelido podem ser alterados diretamente (column grant).
  Future<void> updateAvatar(String userId, String url) =>
      _client.from('profiles').update({'avatar_url': url}).eq('id', userId);

  Future<ProfileStats> fetchStats() async {
    final data = await _client.rpc('get_profile_stats');
    return ProfileStats.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Busca outros jogadores (com facção) para propor trocas.
  Future<List<Profile>> searchPlayers(String query, {required String excludeId}) async {
    var builder = _client
        .from('profiles')
        .select('*, factions(*)')
        .neq('id', excludeId)
        .not('faction_id', 'is', null);
    if (query.trim().isNotEmpty) {
      builder = builder.ilike('nickname', '%${query.trim()}%');
    }
    final rows = await builder.order('nickname').limit(30);
    return rows.map(Profile.fromJson).toList();
  }
}
