import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Centro padrão do mapa quando o GPS não está disponível (São Paulo).
const kDefaultMapCenter = LatLng(-23.5505, -46.6333);

/// Camada do OpenStreetMap (sem chave de API), escurecida para o tema.
class AppTileLayer extends StatelessWidget {
  const AppTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'br.senai.protocoloz.protocolo_z',
      tileBuilder: darkModeTileBuilder,
    );
  }
}

/// Crédito obrigatório do OpenStreetMap.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.all(4),
        child: DecoratedBox(
          decoration: BoxDecoration(color: Color(0xAA0F1226)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            child: Text('© OpenStreetMap', style: TextStyle(fontSize: 10, color: Colors.white70)),
          ),
        ),
      ),
    );
  }
}
