class SurvivorRank {
  const SurvivorRank({
    required this.position,
    required this.id,
    required this.nickname,
    required this.reputation,
    required this.factionId,
    this.avatarUrl,
  });

  final int position;
  final String id;
  final String nickname;
  final int reputation;
  final int factionId;
  final String? avatarUrl;

  factory SurvivorRank.fromJson(Map<String, dynamic> json) => SurvivorRank(
        position: (json['position'] as num).toInt(),
        id: json['id'] as String,
        nickname: json['nickname'] as String,
        reputation: (json['reputation'] as num).toInt(),
        factionId: (json['faction_id'] as num).toInt(),
        avatarUrl: json['avatar_url'] as String?,
      );
}

class FactionRank {
  const FactionRank({
    required this.id,
    required this.name,
    required this.symbol,
    required this.colorHex,
    required this.totalReputation,
    required this.members,
  });

  final int id;
  final String name;
  final String symbol;
  final String colorHex;
  final int totalReputation;
  final int members;

  factory FactionRank.fromJson(Map<String, dynamic> json) => FactionRank(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        symbol: json['symbol'] as String,
        colorHex: json['color'] as String,
        totalReputation: (json['total_reputation'] as num).toInt(),
        members: (json['members'] as num).toInt(),
      );
}
