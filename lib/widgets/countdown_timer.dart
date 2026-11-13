import 'dart:async';

import 'package:flutter/material.dart';

import '../core/server_clock.dart';
import '../core/theme.dart';

/// Contagem regressiva até [endsAt] (horário do servidor).
/// Como o fim vem do banco, a contagem continua certa mesmo depois de
/// fechar e abrir o app. Usado na Home, Expedições e detalhes da troca.
class CountdownTimer extends StatefulWidget {
  const CountdownTimer({
    super.key,
    required this.endsAt,
    this.onFinished,
    this.style,
    this.finishedText = 'Concluído!',
    this.showHours = false,
  });

  final DateTime endsAt;
  final VoidCallback? onFinished;
  final TextStyle? style;
  final String finishedText;
  final bool showHours;

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  Timer? _timer;
  late Duration _left;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant CountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) {
      _notified = false;
      _tick();
    }
  }

  void _tick() {
    final left = widget.endsAt.difference(ServerClock.now());
    final value = left.isNegative ? Duration.zero : left;
    if (mounted) setState(() => _left = value);
    if (value == Duration.zero && !_notified) {
      _notified = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onFinished?.call());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? AppText.display(size: 32, color: AppColors.signal);
    if (_left == Duration.zero) {
      return Text(widget.finishedText, style: style.copyWith(color: AppColors.success));
    }
    final h = _left.inHours;
    final m = _left.inMinutes.remainder(60);
    final s = _left.inSeconds.remainder(60);
    final text = (widget.showHours || h > 0) ? '${_two(h)}:${_two(m)}:${_two(s)}' : '${_two(m)}:${_two(s)}';
    return Text(text, style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]));
  }
}
