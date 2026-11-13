import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme.dart';
import '../providers/repository_providers.dart';
import 'map_tiles.dart';

/// Escolha de localização: toque no mapa OU botão "Usar GPS".
/// Se o GPS for negado, a escolha manual continua funcionando.
/// Usado no cadastro de abrigo e no alerta de horda.
class LocationPicker extends ConsumerStatefulWidget {
  const LocationPicker({super.key, required this.value, required this.onChanged, this.height = 220});
  final LatLng? value;
  final ValueChanged<LatLng> onChanged;
  final double height;

  @override
  ConsumerState<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends ConsumerState<LocationPicker> {
  final _map = MapController();
  bool _locating = false;

  Future<void> _useGps() async {
    setState(() => _locating = true);
    final pos = await ref.read(locationServiceProvider).currentPosition();
    if (!mounted) return;
    setState(() => _locating = false);
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Localização indisponível ou permissão negada. Toque no mapa para escolher o ponto.'),
      ));
      return;
    }
    widget.onChanged(pos);
    _map.move(pos, 16);
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: widget.height,
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: point ?? kDefaultMapCenter,
                initialZoom: point != null ? 15 : 12,
                onTap: (_, latLng) => widget.onChanged(latLng),
              ),
              children: [
                const AppTileLayer(),
                if (point != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: point,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.location_on, size: 44, color: AppColors.signal),
                    ),
                  ]),
                const OsmAttribution(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Text(
              point == null
                  ? 'Toque no mapa para marcar o local'
                  : '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          TextButton.icon(
            onPressed: _locating ? null : _useGps,
            icon: _locating
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
            label: const Text('Usar GPS'),
          ),
        ]),
      ],
    );
  }
}
