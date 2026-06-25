import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/cartera_viewmodel.dart';
import '../../model/cliente.dart';

class MapaRutaScreen extends StatefulWidget {
  const MapaRutaScreen({super.key});

  @override
  State<MapaRutaScreen> createState() => _MapaRutaScreenState();
}

class _MapaRutaScreenState extends State<MapaRutaScreen> {
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CarteraViewModel>();
    const scotiaRed = Color(0xFFED1C24);

    Set<Marker> markers = viewModel.clientes.where((c) => c.latitud != null && c.longitud != null).map((c) {
      double hue;
      if (c.visitado) hue = BitmapDescriptor.hueCyan;
      else if (c.prioridad == 'ALTA') hue = BitmapDescriptor.hueRed;
      else if (c.prioridad == 'MEDIA') hue = BitmapDescriptor.hueYellow;
      else hue = BitmapDescriptor.hueGreen;

      return Marker(
        markerId: MarkerId(c.id),
        position: LatLng(c.latitud!, c.longitud!),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: c.nombreCompleto,
          snippet: c.tipoGestion,
          onTap: () => _showQuickInfo(context, c, viewModel),
        ),
      );
    }).toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Planificación de Ruta", style: TextStyle(color: Colors.white)),
        backgroundColor: scotiaRed,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: LatLng(-12.0463, -77.0427), zoom: 12),
            onMapCreated: (controller) => _mapController = controller,
            markers: markers,
            myLocationEnabled: true,
            polylines: {
              Polyline(
                polylineId: const PolylineId("ruta_optima"),
                points: viewModel.rutaOptimizada.map((c) => LatLng(c.latitud!, c.longitud!)).toList(),
                color: scotiaRed,
                width: 5,
              ),
            },
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => viewModel.optimizarRuta(),
                    icon: const Icon(Icons.auto_fix_high, color: Colors.white),
                    label: const Text("OPTIMIZAR RUTA", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: scotiaRed),
                  ),
                ),
              ],
            ),
          ),
          if (viewModel.isLoading)
            const Center(child: CircularProgressIndicator(color: scotiaRed)),
        ],
      ),
    );
  }

  void _showQuickInfo(BuildContext context, Cliente cliente, CarteraViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cliente.nombreCompleto, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(cliente.tipoGestion),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("VER FICHA"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => viewModel.lanzarNavegacion(cliente.latitud!, cliente.longitud!),
                    child: const Text("NAVEGAR"),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}