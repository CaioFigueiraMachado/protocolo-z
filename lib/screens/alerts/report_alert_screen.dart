import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme.dart';
import '../../providers/game_actions.dart';
import '../../widgets/common.dart';
import '../../widgets/location_picker.dart';

/// /alertas/novo — reportar horda avistada.
class ReportAlertScreen extends ConsumerStatefulWidget {
  const ReportAlertScreen({super.key, this.initialLat, this.initialLng});
  final double? initialLat;
  final double? initialLng;

  @override
  ConsumerState<ReportAlertScreen> createState() => _ReportAlertScreenState();
}

class _ReportAlertScreenState extends ConsumerState<ReportAlertScreen> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  String _intensity = 'media';
  LatLng? _point;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _point = LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    if (_point == null) {
      showErrorSnack(context, 'Marque no mapa onde a horda foi avistada.');
      return;
    }
    final ok = await confirmAction(
      context,
      title: 'Emitir alerta?',
      message: 'Todos os sobreviventes receberão este alerta agora. Ele expira em 30 minutos.',
      confirmLabel: 'Emitir alerta',
    );
    if (!ok || !mounted) return;
    setState(() => _sending = true);
    final done = await runAction(context, () async {
      await ref.read(gameActionsProvider).reportHorde(
            lat: _point!.latitude,
            lng: _point!.longitude,
            intensity: _intensity,
            description: _description.text.trim(),
          );
      return true;
    }, success: 'Alerta emitido para toda a rede!');
    if (!mounted) return;
    setState(() => _sending = false);
    if (done == true) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ALERTA DE HORDA')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionTitle('Intensidade'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'baixa', label: Text('Baixa')),
                ButtonSegment(value: 'media', label: Text('Média')),
                ButtonSegment(value: 'alta', label: Text('Alta')),
              ],
              selected: {_intensity},
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected)
                    ? AppColors.intensity(_intensity).withValues(alpha: 0.35)
                    : null),
              ),
              onSelectionChanged: (s) => setState(() => _intensity = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              maxLength: 140,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'O que você viu?',
                hintText: 'Ex.: grupo grande vindo pela avenida principal',
                alignLabelWithHint: true,
              ),
              validator: (v) => (v?.trim().length ?? 0) < 3 ? 'Descreva em pelo menos 3 caracteres.' : null,
            ),
            const SizedBox(height: 8),
            const SectionTitle('Onde?'),
            LocationPicker(value: _point, onChanged: (p) => setState(() => _point = p)),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.campaign),
              label: const Text('EMITIR ALERTA'),
            ),
          ],
        ),
      ),
    );
  }
}
