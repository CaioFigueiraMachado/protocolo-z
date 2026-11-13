import 'faction.dart';

class Profile {
  const Profile({
    required this.id,
    required this.nickname,
    required this.reputation,
    this.avatarUrl,
    this.factionId,
    this.faction,
  });

  final String id;
  final String nickname;
  final String? avatarUrl;
  final int? factionId;
  final int reputation;
  final Faction? faction;

  bool get hasFaction => factionId != null;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        nickname: json['nickname'] as String,
        avatarUrl: json['avatar_url'] as String?,
        factionId: (json['faction_id'] as num?)?.toInt(),
        reputation: (json['reputation'] as num?)?.toInt() ?? 0,
        faction: json['factions'] is Map<String, dynamic>
            ? Faction.fromJson(json['factions'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'avatar_url': avatarUrl,
        'faction_id': factionId,
        'reputation': reputation,
      };
}

class ProfileStats {
  const ProfileStats({
    this.expeditionsCompleted = 0,
    this.tradesCompleted = 0,
    this.sheltersCreated = 0,
    this.alertsConfirmed = 0,
  });

  final int expeditionsCompleted;
  final int tradesCompleted;
  final int sheltersCreated;
  final int alertsConfirmed;

  factory ProfileStats.fromJson(Map<String, dynamic> json) => ProfileStats(
        expeditionsCompleted: (json['expeditions_completed'] as num?)?.toInt() ?? 0,
        tradesCompleted: (json['trades_completed'] as num?)?.toInt() ?? 0,
        sheltersCreated: (json['shelters_created'] as num?)?.toInt() ?? 0,
        alertsConfirmed: (json['alerts_confirmed'] as num?)?.toInt() ?? 0,
      );
}
