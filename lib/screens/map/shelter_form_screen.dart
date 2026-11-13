import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme.dart';
import '../../models/shelter.dart';
import '../../providers/game_actions.dart';
import '../../providers/game_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/image_source_sheet.dart';
import '../../widgets/location_picker.dart';

/// Cadastro (/abrigos/novo) e edição (/abrigos/:id/editar) de abrigo.
class ShelterFormScreen extends ConsumerStatefulWidget {
  const ShelterFormScreen({super.key, this.shelterId, this.initialLat, this.initialLng});
  final String? shelterId;
  final double? initialLat;
  final double? initialLng;

  bool get isEditing => shelterId != null;

  @override
  ConsumerState<ShelterFormScreen> createState() => _ShelterFormScreenState();
}

class _ShelterFormScreenState extends ConsumerState<ShelterFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _capacity = TextEditingController(text: '10');
  String _visibility = 'publico';
  String _status = 'seguro';
  LatLng? _point;
  PickedImage? _photo;
  String? _existingPhotoUrl;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _point = LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _capacity.dispose();
    super.dispose();
  }

  void _fill(Shelter s) {
    if (_loaded) return;
    _loaded = true;
    _name.text = s.name;
    _description.text = s.description;
    _capacity.text = '${s.capacity}';
    _visibility = s.visibility;
    _status = s.status;
    _point = LatLng(s.lat, s.lng);
    _existingPhotoUrl = s.photoUrl;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    if (_point == null) {
      showErrorSnack(context, 'Escolha a localização do abrigo no mapa ou pelo GPS.');
      return;
    }
    setState(() => _saving = true);
    final input = ShelterInput(
      name: _name.text.trim(),
      description: _description.text.trim(),
      capacity: int.parse(_capacity.text.trim()),
      lat: _point!.latitude,
      lng: _point!.longitude,
      visibility: _visibility,
      status: _status,
      photoUrl: _existingPhotoUrl,
    );
    final actions = ref.read(gameActionsProvider);
    final result = await runAction<String>(
      context,
      () async {
        if (widget.isEditing) {
          await actions.updateShelter(widget.shelterId!, input, newPhoto: _photo);
          return widget.shelterId!;
        }
        return actions.createShelter(input, photo: _photo);
      },
      success: widget.isEditing ? 'Abrigo atualizado.' : 'Abrigo cadastrado! +15 de reputação.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result != null) {
      if (widget.isEditing) {
        context.pop();
      } else {
        context.pushReplacement('/abrigos/$result');
      }
    }
  }

  Future<void> _pickPhoto() async {
    final img = await pickImage(context);
    if (img != null) setState(() => _photo = img);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) {
      final shelter = ref.watch(shelterProvider(widget.shelterId!));
      return Scaffold(
        appBar: AppBar(title: const Text('EDITAR ABRIGO')),
        body: AsyncValueView(
          value: shelter,
          onRetry: () => ref.invalidate(shelterProvider(widget.shelterId!)),
          data: (s) {
            if (s == null) return const EmptyState(icon: Icons.lock_outline, title: 'Abrigo indisponível');
            _fill(s);
            return _buildForm();
          },
        ),
      );
    }
    return Scaffold(appBar: AppBar(title: const Text('NOVO ABRIGO')), body: _buildForm());
  }

  Widget _buildForm() {
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PhotoPicker(
            photo: _photo,
            existingUrl: _existingPhotoUrl,
            onPick: _saving ? null : _pickPhoto,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Nome do abrigo', prefixIcon: Icon(Icons.house_siding)),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.length < 3) return 'O nome precisa ter pelo menos 3 caracteres.';
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _description,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Descrição',
              alignLabelWithHint: true,
              hintText: 'Ex.: galpão com portão reforçado, água de poço...',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _capacity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Capacidade (pessoas)', prefixIcon: Icon(Icons.groups)),
            validator: (v) {
              final n = int.tryParse(v?.trim() ?? '');
              if (n == null || n < 1 || n > 500) return 'Informe um número entre 1 e 500.';
              return null;
            },
          ),
          const SizedBox(height: 16),
          const SectionTitle('Visibilidade'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'publico', icon: Icon(Icons.public), label: Text('Público')),
              ButtonSegment(value: 'faccao', icon: Icon(Icons.lock), label: Text('Só da facção')),
            ],
            selected: {_visibility},
            onSelectionChanged: (s) => setState(() => _visibility = s.first),
          ),
          const SizedBox(height: 6),
          Text(
            _visibility == 'faccao'
                ? 'Apenas membros da sua facção poderão ver este abrigo (garantido pelo servidor).'
                : 'Todos os sobreviventes poderão ver este abrigo.',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          if (widget.isEditing) ...[
            const SizedBox(height: 16),
            const SectionTitle('Status'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'seguro', icon: Icon(Icons.verified_user), label: Text('Seguro')),
                ButtonSegment(value: 'comprometido', icon: Icon(Icons.dangerous), label: Text('Comprometido')),
              ],
              selected: {_status},
              onSelectionChanged: (s) => setState(() => _status = s.first),
            ),
          ],
          const SizedBox(height: 16),
          const SectionTitle('Localização'),
          LocationPicker(value: _point, onChanged: (p) => setState(() => _point = p)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text(widget.isEditing ? 'SALVAR ALTERAÇÕES' : 'CADASTRAR ABRIGO'),
          ),
        ],
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.photo, required this.existingUrl, required this.onPick});
  final PickedImage? photo;
  final String? existingUrl;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (photo != null) {
      content = Image.memory(photo!.bytes, fit: BoxFit.cover);
    } else if (existingUrl != null) {
      content = Image.network(existingUrl!, fit: BoxFit.cover);
    } else {
      content = const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.add_a_photo_outlined, size: 40, color: AppColors.textMuted),
        SizedBox(height: 6),
        Text('Adicionar foto do abrigo', style: TextStyle(color: AppColors.textMuted)),
      ]);
    }
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 180,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outline),
        ),
        child: Stack(fit: StackFit.expand, children: [
          content,
          if (photo != null || existingUrl != null)
            const Positioned(
              right: 8,
              bottom: 8,
              child: CircleAvatar(
                backgroundColor: AppColors.ink,
                child: Icon(Icons.edit, color: AppColors.signal, size: 18),
              ),
            ),
        ]),
      ),
    );
  }
}
