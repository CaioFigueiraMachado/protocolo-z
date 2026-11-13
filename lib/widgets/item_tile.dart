import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/item.dart';

/// Ícone do item (emoji) num quadrado.
class ItemIcon extends StatelessWidget {
  const ItemIcon({super.key, required this.item, this.size = 44});
  final Item item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: AppColors.outline),
      ),
      child: Text(item.icon, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}

/// Linha de item com ícone, nome, categoria e quantidade.
/// Usado no Inventário, Home, Expedições e Trocas.
class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.item,
    required this.quantity,
    this.trailing,
    this.onTap,
    this.quantityPrefix = 'x',
    this.dense = false,
  });

  final Item item;
  final int quantity;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String quantityPrefix;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 6 : 10),
        child: Row(
          children: [
            ItemIcon(item: item, size: dense ? 36 : 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  if (!dense)
                    Row(children: [
                      Icon(item.category.icon, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(item.category.label,
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                    ]),
                ],
              ),
            ),
            trailing ??
                Text(
                  '$quantityPrefix$quantity',
                  style: AppText.display(size: dense ? 16 : 20, color: AppColors.signal),
                ),
          ],
        ),
      ),
    );
  }
}
