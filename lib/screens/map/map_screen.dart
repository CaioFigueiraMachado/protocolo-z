import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme.dart';
import '../../models/horde_alert.dart';
import '../../models/shelter.dart';
import '../../providers/auth_providers.dart';
import '../../providers/game_actions.dart';
import '../../providers/game_providers.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/horde_alert_banner.dart';
import '../../widgets/map_tiles.dart';
import '../../widgets/shelter_card.dart';
import '../shell/main_shell.dart';

/// Mapa interativo com abrigos e alertas de horda.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _map = MapController();
  LatLng? _me;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate(silent: true));
  }

  Future<void> _locate({bool silent = false}) async {
    setState(() => _locating = true);
    final pos = await ref.read(locationServiceProvider).currentPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _me = pos ?? _me;
    });
    if (pos != null) {
      _map.move(pos, 15);
    } else if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Localização indisponível ou permissão negada. Você ainda pode navegar e tocar no mapa.'),
      ));
    }
  }

  void _onLongPress(LatLng p) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.house_siding, color: AppColors.cobaltLight),
            title: const Text('Cadastrar abrigo aqui'),
            onTap: () {
              Navigator.of(ctx).pop();
              context.push('/abrigos/novo?lat=${p.latitude}&lng=${p.longitude}');
            },
          ),
          ListTile(
            leading: const Icon(Icons.campaign, color: AppColors.danger),
            title: const Text('Reportar horda aqui'),
            onTap: () {
              Navigator.of(ctx).pop();
              context.push('/alertas/novo?lat=${p.latitude}&lng=${p.longitude}');
            },
          ),
        ]),
      ),
    );
  }

  void _showAlert(HordeAlert alert) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _AlertSheet(alert: alert),
    );
  }

  void _showList(List<Shelter> shelters) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, controller) => shelters.isEmpty
            ? const EmptyState(
                icon: Icons.house_siding,
                title: 'Nenhum abrigo visível',
                message: 'Cadastre o primeiro abrigo da sua facção.',
              )
            : ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: shelters.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => ShelterCard(
                  shelter: shelters[i],
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push('/abrigos/${shelters[i].id}');
                  },
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shelters = ref.watch(sheltersProvider);
    final alerts = ref.watch(activeAlertsProvider);
    final shelterList = shelters.value ?? const <Shelter>[];
    final alertList = alerts.value ?? const <HordeAlert>[];
    final loading = shelters.isLoading || alerts.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MAPA'),
        actions: [
          IconButton(
            tooltip: 'Lista de abrigos',
            onPressed: () => _showList(shelterList),
            icon: const Icon(Icons.list_alt),
          ),
          const ShellAppBarActions(),
        ],
        bottom: loading ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator()) : null,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: kDefaultMapCenter,
              initialZoom: 12,
              onLongPress: (_, p) => _onLongPress(p),
            ),
            children: [
              const AppTileLayer(),
              MarkerLayer(markers: [
                for (final s in shelterList)
                  Marker(
                    point: LatLng(s.lat, s.lng),
                    width: 40,
                    height: 46,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => context.push('/abrigos/${s.id}'),
                      child: Tooltip(message: s.name, child: _ShelterMarker(shelter: s)),
                    ),
                  ),
                for (final a in alertList)
                  Marker(
                    point: LatLng(a.lat, a.lng),
                    width: 40,
                    height: 46,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => _showAlert(a),
                      child: SvgPicture.asset('assets/brand/alerta_${a.intensity}.svg'),
                    ),
                  ),
                if (_me != null)
                  Marker(
                    point: _me!,
                    width: 22,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.cobalt,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
              ]),
              const OsmAttribution(),
            ],
          ),
          if (shelters.hasError || alerts.hasError)
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Material(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(10),
                child: ListTile(
                  dense: true,
                  textColor: Colors.white,
                  iconColor: Colors.white,
                  leading: const Icon(Icons.wifi_off),
                  title: const Text('Não foi possível carregar o mapa.'),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      ref.invalidate(sheltersProvider);
                      ref.invalidate(activeAlertsProvider);
                    },
                  ),
                ),
              ),
            ),
          const Positioned(left: 12, bottom: 12, child: _Legend()),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'loc',
            tooltip: 'Minha localização',
            backgroundColor: AppColors.surfaceHigh,
            foregroundColor: AppColors.text,
            onPressed: _locating ? null : () => _locate(),
            child: _locating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'horde',
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            onPressed: () {
              final c = _map.camera.center;
              context.push('/alertas/novo?lat=${(_me ?? c).latitude}&lng=${(_me ?? c).longitude}');
            },
            icon: const Icon(Icons.campaign),
            label: const Text('Horda'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'shelter',
            onPressed: () {
              final c = _map.camera.center;
              context.push('/abrigos/novo?lat=${(_me ?? c).latitude}&lng=${(_me ?? c).longitude}');
            },
            icon: const Icon(Icons.add_home),
            label: const Text('Abrigo'),
          ),
        ],
      ),
    );
  }
}

class _ShelterMarker extends StatelessWidget {
  const _ShelterMarker({required this.shelter});
  final Shelter shelter;

  @override
  Widget build(BuildContext context) {
    final faction = shelter.faction;
    return Stack(clipBehavior: Clip.none, children: [
      faction != null
          ? SvgPicture.asset(faction.markerAsset, width: 40, height: 46)
          : const Icon(Icons.location_on, size: 44, color: AppColors.cobaltLight),
      if (shelter.isFactionOnly)
        const Positioned(
          right: -2,
          top: -2,
          child: CircleAvatar(
            radius: 8,
            backgroundColor: AppColors.ink,
            child: Icon(Icons.lock, size: 10, color: AppColors.signal),
          ),
        ),
      if (!shelter.isSafe)
        const Positioned(
          left: -2,
          top: -2,
          child: CircleAvatar(
            radius: 8,
            backgroundColor: AppColors.danger,
            child: Icon(Icons.priority_high, size: 11, color: Colors.white),
          ),
        ),
    ]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        _LegendRow(color: AppColors.cobaltLight, icon: Icons.location_on, label: 'Abrigo (cor da facção)'),
        _LegendRow(color: AppColors.danger, icon: Icons.warning_amber_rounded, label: 'Horda'),
        _LegendRow(color: AppColors.signal, icon: Icons.touch_app, label: 'Segure no mapa para marcar'),
      ]),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.icon, required this.label});
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ]),
      );
}

/// Detalhes do alerta + botão para confirmar o avistamento.
class _AlertSheet extends ConsumerStatefulWidget {
  const _AlertSheet({required this.alert});
  final HordeAlert alert;

  @override
  ConsumerState<_AlertSheet> createState() => _AlertSheetState();
}

class _AlertSheetState extends ConsumerState<_AlertSheet> {
  bool _sending = false;

  Future<void> _confirm() async {
    setState(() => _sending = true);
    final rewarded = await runAction(context, () => ref.read(gameActionsProvider).confirmAlert(widget.alert.id));
    if (!mounted) return;
    setState(() => _sending = false);
    if (rewarded != null) {
      Navigator.of(context).pop();
      showSuccessSnack(
        context,
        rewarded ? 'Avistamento confirmado! O autor ganhou +25 de reputação.' : 'Avistamento confirmado!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final uid = ref.watch(currentUserIdProvider);
    final confirmed = ref.watch(myAlertConfirmationsProvider).value?.contains(alert.id) ?? false;
    final mine = alert.authorId == uid;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HordeAlertBanner(alert: alert),
            const SizedBox(height: 8),
            if (alert.authorNickname != null)
              Text('Reportado por ${alert.authorNickname}', style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 16),
            if (mine)
              const Text('Este alerta é seu. Outros jogadores podem confirmá-lo.', textAlign: TextAlign.center)
            else if (confirmed)
              const Text('Você já confirmou este avistamento.', textAlign: TextAlign.center)
            else
              FilledButton.icon(
                onPressed: _sending ? null : _confirm,
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.visibility),
                label: const Text('CONFIRMAR AVISTAMENTO'),
              ),
          ],
        ),
      ),
    );
  }
}
