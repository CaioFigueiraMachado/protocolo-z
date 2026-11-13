import 'faction.dart';

class Shelter {
  const Shelter({
    required this.id,
    required this.authorId,
    required this.factionId,
    required this.name,
    required this.description,
    required this.capacity,
    required this.lat,
    required this.lng,
    required this.visibility,
    required this.status,
    required this.createdAt,
    this.photoUrl,
    this.authorNickname,
    this.faction,
  });

  final String id;
  final String authorId;
  final int factionId;
  final String name;
  final String description;
  final int capacity;
  final String? photoUrl;
  final double lat;
  final double lng;
  final String visibility; // 'publico' | 'faccao'
  final String status; // 'seguro' | 'comprometido'
  final DateTime createdAt;
  final String? authorNickname;
  final Faction? faction;

  bool get isFactionOnly => visibility == 'faccao';
  bool get isSafe => status == 'seguro';

  factory Shelter.fromJson(Map<String, dynamic> json) => Shelter(
        id: json['id'] as String,
        authorId: json['author_id'] as String,
        factionId: (json['faction_id'] as num).toInt(),
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        capacity: (json['capacity'] as num).toInt(),
        photoUrl: json['photo_url'] as String?,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        visibility: json['visibility'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        authorNickname: (json['author'] as Map<String, dynamic>?)?['nickname'] as String?,
        faction: json['factions'] is Map<String, dynamic>
            ? Faction.fromJson(json['factions'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'author_id': authorId,
        'faction_id': factionId,
        'name': name,
        'description': description,
        'capacity': capacity,
        'photo_url': photoUrl,
        'lat': lat,
        'lng': lng,
        'visibility': visibility,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Dados digitados no formulário de abrigo.
class ShelterInput {
  const ShelterInput({
    required this.name,
    required this.description,
    required this.capacity,
    required this.lat,
    required this.lng,
    required this.visibility,
    this.status = 'seguro',
    this.photoUrl,
  });

  final String name;
  final String description;
  final int capacity;
  final double lat;
  final double lng;
  final String visibility;
  final String status;
  final String? photoUrl;
}
