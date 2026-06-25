import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/cartera_viewmodel.dart';

class MonitorSupervisionScreen extends StatefulWidget {
  const MonitorSupervisionScreen({super.key});

  @override
  State<MonitorSupervisionScreen> createState() => _MonitorSupervisionScreenState();
}

class _MonitorSupervisionScreenState extends State<MonitorSupervisionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CarteraViewModel>().initMonitoreoRealtime();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CarteraViewModel>();
    const scotiaRed = Color(0xFFED1C24);

    final Set<Marker> markers = viewModel.monitoreoAsesores
        .where((a) => a['lat'] != null)
        .map((a) {
          double hue = (a['id'].hashCode % 360).toDouble();
          return Marker(
            markerId: MarkerId(a['id']),
            position: LatLng(a['lat'], a['lng']),
            icon: BitmapDescriptor.defaultMarkerWithHue(hue),
            infoWindow: InfoWindow(title: a['nombre'], snippet: "Avance: ${a['visitados']}/${a['total']}"),
          );
        }).toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Monitoreo de Equipo", style: TextStyle(color: Colors.white)),
        backgroundColor: scotiaRed,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: LatLng(-12.0463, -77.0427), zoom: 12),
            markers: markers,
            myLocationButtonEnabled: false,
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.1,
            maxChildSize: 0.6,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: viewModel.monitoreoAsesores.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return const ListTile(title: Text("Estado de Cobertura", style: TextStyle(fontWeight: FontWeight.bold)));
                    final a = viewModel.monitoreoAsesores[index - 1];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: HSVColor.fromAHSV(1, (a['id'].hashCode % 360).toDouble(), 0.7, 0.9).toColor(),
                        child: Text(a['nombre'][0], style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(a['nombre']),
                      subtitle: Text("Sincronización: ${a['ultima_sync']?.substring(11, 16) ?? '---'}"),
                      trailing: Text("${a['visitados']}/${a['total']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}