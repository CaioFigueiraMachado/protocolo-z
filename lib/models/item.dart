import 'package:flutter/material.dart';

/// Categorias de itens (mesmos valores da restrição CHECK no banco).
enum ItemCategory {
  agua('agua', 'Água', Icons.water_drop),
  comida('comida', 'Comida', Icons.restaurant),
  medicamentos('medicamentos', 'Medicamentos', Icons.medical_services),
  ferramentas('ferramentas', 'Ferramentas', Icons.handyman),
  combustivel('combustivel', 'Combustível', Icons.local_gas_station);

  const ItemCategory(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;

  static ItemCategory fromValue(String value) =>
      ItemCategory.values.firstWhere((c) => c.value == value, orElse: () => ItemCategory.ferramentas);
}

class Item {
  const Item({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
  });

  final int id;
  final String name;
  final ItemCategory category;
  final String icon; // emoji

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        category: ItemCategory.fromValue(json['category'] as String),
        icon: json['icon'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.value,
        'icon': icon,
      };
}

class InventoryEntry {
  const InventoryEntry({required this.item, required this.quantity});

  final Item item;
  final int quantity;

  factory InventoryEntry.fromJson(Map<String, dynamic> json) => InventoryEntry(
        item: Item.fromJson(json['items'] as Map<String, dynamic>),
        quantity: (json['quantity'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {'items': item.toJson(), 'quantity': quantity};
}

/// Item + quantidade (usado em trocas e recompensas).
class ItemAmount {
  const ItemAmount({required this.item, required this.quantity});
  final Item item;
  final int quantity;

  Map<String, dynamic> toRpcJson() => {'item_id': item.id, 'quantity': quantity};
}
