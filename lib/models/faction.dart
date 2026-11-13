import 'package:flutter/material.dart';

class Faction {
  const Faction({
    required this.id,
    required this.name,
    required this.symbol,
    required this.colorHex,
    required this.description,
    this.motto = '',
    this.specialty = '',
  });

  final int id;
  final String name;

  /// Slug do emblema: `assets/factions/<symbol>.svg`
  final String symbol;
  final String colorHex;
  final String description;
  final String motto;
  final String specialty;

  Color get color => Color(int.parse('FF${colorHex.replaceFirst('#', '')}', radix: 16));

  String get emblemAsset => 'assets/factions/$symbol.svg';
  String get darkEmblemAsset => 'assets/factions/${symbol}_escuro.svg';
  String get symbolAsset => 'assets/factions/${symbol}_simbolo.svg';
  String get markerAsset => 'assets/factions/${symbol}_marcador.svg';

  factory Faction.fromJson(Map<String, dynamic> json) => Faction(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        symbol: json['symbol'] as String,
        colorHex: json['color'] as String,
        description: json['description'] as String? ?? '',
        motto: json['motto'] as String? ?? '',
        specialty: json['specialty'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'symbol': symbol,
        'color': colorHex,
        'description': description,
        'motto': motto,
        'specialty': specialty,
      };
}
