import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/cartera_viewmodel.dart';
import '../../navigation/app_routes.dart';

class HistorialSolicitudesScreen extends StatefulWidget {
  const HistorialSolicitudesScreen({super.key});

  @override
  State<HistorialSolicitudesScreen> createState() => _HistorialSolicitudesScreenState();
}

class _HistorialSolicitudesScreenState extends State<HistorialSolicitudesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CarteraViewModel>().fetchSolicitudesMes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CarteraViewModel>();
    const scotiaRed = Color(0xFFED1C24);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mi Actividad del Mes", style: TextStyle(color: Colors.white)),
        backgroundColor: scotiaRed,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator(color: scotiaRed))
          : Column(
              children: [
                _buildResumenMensual(viewModel),
                Expanded(
                  child: viewModel.historialSolicitudes.isEmpty
                      ? const Center(child: Text("No has registrado solicitudes este mes."))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: viewModel.historialSolicitudes.length,
                          itemBuilder: (context, index) {
                            final solicitud = viewModel.historialSolicitudes[index];
                            return _buildSolicitudTile(context, solicitud);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildResumenMensual(CarteraViewModel vm) {
    final total = vm.historialSolicitudes.length;
    final aprobadas = vm.historialSolicitudes.where((s) => s['estado'] == 'Aprobada').length;
    double montoTotal = 0;
    for (var s in vm.historialSolicitudes) {
      if (s['estado'] == 'Aprobada' || s['estado'] == 'Desembolsada') {
        montoTotal += (s['monto'] ?? 0).toDouble();
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem("Enviadas", total.toString()),
          _buildInfoItem("Aprobadas", aprobadas.toString()),
          _buildInfoItem("Monto", "S/ ${montoTotal.toStringAsFixed(0)}"),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFED1C24))),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSolicitudTile(BuildContext context, Map<String, dynamic> s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => Navigator.pushNamed(context, AppRoutes.detalleSolicitud, arguments: s),
        title: Text(s['nombres'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Monto: S/ ${s['monto']} - ${s['estado']}"),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }
}