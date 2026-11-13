import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/item.dart';

/// Inventário: o app só LÊ. Alterações acontecem nas RPCs
/// (kit inicial, expedições e trocas).
class InventoryRepository {
  InventoryRepository(this._client);
  final SupabaseClient _client;

  Future<List<InventoryEntry>> fetchInventory(String userId) async {
    final rows = await _client
        .from('inventory')
        .select('quantity, items(*)')
        .eq('user_id', userId)
        .gt('quantity', 0)
        .order('item_id');
    return rows.map(InventoryEntry.fromJson).toList();
  }
}
