import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/cartera_viewmodel.dart';
import '../../navigation/app_routes.dart';

class TableroSolicitudesScreen extends StatelessWidget {
  const TableroSolicitudesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CarteraViewModel>();
    const scotiaRed = Color(0xFFED1C24);

    final estados = ['Enviada', 'En comité', 'Aprobada', 'Desembolsada', 'Rechazada'];

    return DefaultTabController(
      length: estados.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Tablero de Solicitudes", style: TextStyle(color: Colors.white)),
          backgroundColor: scotiaRed,
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: estados.map((e) {
              final count = viewModel.solicitudesTablero.where((s) => s['estado'] == e).length;
              return Tab(text: "$e ($count)");
            }).toList(),
          ),
        ),
        body: TabBarView(
          children: estados.map((estado) {
            final lista = viewModel.solicitudesTablero.where((s) => s['estado'] == estado).toList();
            return _buildListaSolicitudes(context, lista);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildListaSolicitudes(BuildContext context, List<Map<String, dynamic>> solicitudes) {
    if (solicitudes.isEmpty) {
      return const Center(child: Text("No hay solicitudes en este estado."));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: solicitudes.length,
      itemBuilder: (context, index) {
        final s = solicitudes[index];
        return _buildCardSolicitud(context, s);
      },
    );
  }

  Widget _buildCardSolicitud(BuildContext context, Map<String, dynamic> s) {
    final date = DateTime.parse(s['created_at']);
    final dias = DateTime.now().difference(date).inDays;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => Navigator.pushNamed(context, AppRoutes.detalleSolicitud, arguments: s),
        title: Text(s['nombres'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Monto: S/ ${s['monto']}"),
            Text("Enviado hace $dias días"),
            if (s['analista'] != null) Text("Analista: ${s['analista']}"),
          ],
        ),
        trailing: _buildStatusBadge(s['estado']),
      ),
    );
  }

  Widget _buildStatusBadge(String estado) {
    Color color;
    switch (estado) {
      case 'Aprobada': color = Colors.green; break;
      case 'Rechazada': color = Colors.red; break;
      case 'En comité': color = Colors.orange; break;
      case 'Desembolsada': color = Colors.blue; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(estado, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}