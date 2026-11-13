import 'package:flutter/material.dart';

import '../core/theme.dart';

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({super.key, required this.value, required this.onChanged, this.max = 99});
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: value > 0 ? () => onChanged(value - 1) : null,
        icon: const Icon(Icons.remove_circle_outline),
      ),
      SizedBox(
        width: 28,
        child: Text('$value',
            textAlign: TextAlign.center,
            style: AppText.display(size: 16, color: value > 0 ? AppColors.signal : AppColors.textMuted)),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: value < max ? () => onChanged(value + 1) : null,
        icon: const Icon(Icons.add_circle_outline),
      ),
    ]);
  }
}
