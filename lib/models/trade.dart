import 'item.dart';

enum TradeStatus {
  pendente('pendente', 'Pendente'),
  aceita('aceita', 'Aceita'),
  recusada('recusada', 'Recusada'),
  cancelada('cancelada', 'Cancelada'),
  expirada('expirada', 'Expirada');

  const TradeStatus(this.value, this.label);
  final String value;
  final String label;

  static TradeStatus fromValue(String v) =>
      TradeStatus.values.firstWhere((s) => s.value == v, orElse: () => TradeStatus.pendente);
}

class TradeItem {
  const TradeItem({required this.item, required this.side, required this.quantity});

  final Item item;
  final String side; // oferecido | pedido
  final int quantity;

  bool get isOffered => side == 'oferecido';

  factory TradeItem.fromJson(Map<String, dynamic> json) => TradeItem(
        item: Item.fromJson(json['items'] as Map<String, dynamic>),
        side: json['side'] as String,
        quantity: (json['quantity'] as num).toInt(),
      );
}

class Trade {
  const Trade({
    required this.id,
    required this.fromUser,
    required this.toUser,
    required this.fromNickname,
    required this.toNickname,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.items,
    this.message,
    this.resolvedAt,
  });

  final String id;
  final String fromUser;
  final String toUser;
  final String fromNickname;
  final String toNickname;
  final TradeStatus status;
  final String? message;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? resolvedAt;
  final List<TradeItem> items;

  List<TradeItem> get offered => items.where((i) => i.isOffered).toList();
  List<TradeItem> get requested => items.where((i) => !i.isOffered).toList();
  bool get isPending => status == TradeStatus.pendente;

  factory Trade.fromJson(Map<String, dynamic> json) => Trade(
        id: json['id'] as String,
        fromUser: json['from_user'] as String,
        toUser: json['to_user'] as String,
        fromNickname: (json['from_profile'] as Map<String, dynamic>?)?['nickname'] as String? ?? '???',
        toNickname: (json['to_profile'] as Map<String, dynamic>?)?['nickname'] as String? ?? '???',
        status: TradeStatus.fromValue(json['status'] as String),
        message: json['message'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        expiresAt: DateTime.parse(json['expires_at'] as String).toUtc(),
        resolvedAt: json['resolved_at'] == null ? null : DateTime.parse(json['resolved_at'] as String).toUtc(),
        items: ((json['trade_items'] as List?) ?? [])
            .map((e) => TradeItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
