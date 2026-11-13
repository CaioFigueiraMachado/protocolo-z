import '../core/server_clock.dart';

class HordeAlert {
  const HordeAlert({
    required this.id,
    required this.authorId,
    required this.lat,
    required this.lng,
    required this.intensity,
    required this.description,
    required this.confirmations,
    required this.createdAt,
    required this.expiresAt,
    this.authorNickname,
  });

  final String id;
  final String authorId;
  final double lat;
  final double lng;
  final String intensity; // baixa | media | alta
  final String description;
  final int confirmations;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? authorNickname;

  bool get isActive => ServerClock.now().isBefore(expiresAt);

  String get intensityLabel => switch (intensity) {
        'alta' => 'Alta',
        'media' => 'Média',
        _ => 'Baixa',
      };

  factory HordeAlert.fromJson(Map<String, dynamic> json) => HordeAlert(
        id: json['id'] as String,
        authorId: json['author_id'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        intensity: json['intensity'] as String,
        description: json['description'] as String,
        confirmations: (json['confirmations'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        expiresAt: DateTime.parse(json['expires_at'] as String).toUtc(),
        authorNickname: (json['author'] as Map<String, dynamic>?)?['nickname'] as String?,
      );
}
