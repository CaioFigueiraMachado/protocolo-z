import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors.dart';
import '../models/shelter.dart';

class ShelterRepository {
  ShelterRepository(this._client);
  final SupabaseClient _client;

  static const _select = '*, author:profiles(nickname), factions(*)';

  /// A RLS já filtra: abrigos "da facção" de outras facções nunca chegam aqui.
  Future<List<Shelter>> fetchShelters() async {
    final rows = await _client.from('shelters').select(_select).order('created_at', ascending: false);
    return rows.map(Shelter.fromJson).toList();
  }

  Future<List<Shelter>> fetchByAuthor(String authorId) async {
    final rows = await _client
        .from('shelters')
        .select(_select)
        .eq('author_id', authorId)
        .order('created_at', ascending: false);
    return rows.map(Shelter.fromJson).toList();
  }

  Future<Shelter?> fetchShelter(String id) async {
    final row = await _client.from('shelters').select(_select).eq('id', id).maybeSingle();
    return row == null ? null : Shelter.fromJson(row);
  }

  /// Criação via RPC: o servidor define autor, facção e concede +15 de reputação.
  Future<String> createShelter(ShelterInput input) async {
    final id = await _client.rpc<String>('create_shelter', params: {
      'p_name': input.name,
      'p_description': input.description,
      'p_capacity': input.capacity,
      'p_photo_url': input.photoUrl,
      'p_lat': input.lat,
      'p_lng': input.lng,
      'p_visibility': input.visibility,
    });
    return id;
  }

  /// Edição direta: a RLS só deixa o autor alterar, e apenas colunas permitidas.
  Future<void> updateShelter(String id, ShelterInput input) async {
    final rows = await _client
        .from('shelters')
        .update({
          'name': input.name,
          'description': input.description,
          'capacity': input.capacity,
          'photo_url': input.photoUrl,
          'lat': input.lat,
          'lng': input.lng,
          'visibility': input.visibility,
          'status': input.status,
        })
        .eq('id', id)
        .select('id');
    if (rows.isEmpty) {
      throw AppException('Apenas o autor pode editar este abrigo.');
    }
  }

  Future<void> deleteShelter(String id) => _client.rpc('delete_shelter', params: {'p_shelter_id': id});
}
