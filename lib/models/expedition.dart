import '../core/server_clock.dart';
import 'item.dart';

class ExpeditionReward {
  const ExpeditionReward({
    required this.item,
    required this.minQty,
    required this.maxQty,
    required this.chance,
  });

  final Item item;
  final int minQty;
  final int maxQty;
  final double chance;

  factory ExpeditionReward.fromJson(Map<String, dynamic> json) => ExpeditionReward(
        item: Item.fromJson(json['items'] as Map<String, dynamic>),
        minQty: (json['min_qty'] as num).toInt(),
        maxQty: (json['max_qty'] as num).toInt(),
        chance: (json['chance'] as num).toDouble(),
      );
}

class ExpeditionType {
  const ExpeditionType({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.durationSeconds,
    required this.risk,
    required this.failureChance,
    required this.rewards,
  });

  final int id;
  final String name;
  final String description;
  final String icon;
  final int durationSeconds;
  final String risk; // baixo | medio | alto
  final double failureChance;
  final List<ExpeditionReward> rewards;

  String get riskLabel => switch (risk) {
        'alto' => 'Risco alto',
        'medio' => 'Risco médio',
        _ => 'Risco baixo',
      };

  String get durationLabel {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    if (m == 0) return '${s}s';
    return s == 0 ? '$m min' : '$m min ${s}s';
  }

  factory ExpeditionType.fromJson(Map<String, dynamic> json) => ExpeditionType(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        description: json['description'] as String,
        icon: json['icon'] as String,
        durationSeconds: (json['duration_seconds'] as num).toInt(),
        risk: json['risk'] as String,
        failureChance: (json['failure_chance'] as num).toDouble(),
        rewards: ((json['expedition_rewards'] as List?) ?? [])
            .map((e) => ExpeditionReward.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.chance.compareTo(a.chance)),
      );
}

class Expedition {
  const Expedition({
    required this.id,
    required this.typeId,
    required this.startedAt,
    required this.endsAt,
    required this.status,
    this.type,
  });

  final String id;
  final int typeId;
  final DateTime startedAt;
  final DateTime endsAt;
  final String status;
  final ExpeditionType? type;

  bool get isFinished => !ServerClock.now().isBefore(endsAt);

  factory Expedition.fromJson(Map<String, dynamic> json) => Expedition(
        id: json['id'] as String,
        typeId: (json['expedition_type_id'] as num).toInt(),
        startedAt: DateTime.parse(json['started_at'] as String).toUtc(),
        endsAt: DateTime.parse(json['ends_at'] as String).toUtc(),
        status: json['status'] as String,
        type: json['expedition_types'] is Map<String, dynamic>
            ? ExpeditionType.fromJson(json['expedition_types'] as Map<String, dynamic>)
            : null,
      );
}

/// Resultado devolvido pela RPC collect_expedition (sorteado no servidor).
class ExpeditionResult {
  const ExpeditionResult({
    required this.success,
    required this.reputation,
    required this.items,
  });

  final bool success;
  final int reputation;
  final List<({String name, String icon, int quantity})> items;

  factory ExpeditionResult.fromJson(Map<String, dynamic> json) => ExpeditionResult(
        success: json['success'] as bool,
        reputation: (json['reputation'] as num).toInt(),
        items: ((json['items'] as List?) ?? [])
            .map((e) => (
                  name: e['name'] as String,
                  icon: e['icon'] as String,
                  quantity: (e['quantity'] as num).toInt(),
                ))
            .toList(),
      );
}
