import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../viewmodel/cartera_viewmodel.dart';
import '../../model/cliente.dart';
import '../../navigation/app_routes.dart';

class FichaClienteScreen extends StatefulWidget {
  final Cliente cliente;
  const FichaClienteScreen({super.key, required this.cliente});

  @override
  State<FichaClienteScreen> createState() => _FichaClienteScreenState();
}

class _FichaClienteScreenState extends State<FichaClienteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CarteraViewModel>().fetchDetalleCliente(widget.cliente.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CarteraViewModel>();
    const scotiaRed = Color(0xFFED1C24);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ficha del Cliente", style: TextStyle(color: Colors.white)),
        backgroundColor: scotiaRed,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator(color: scotiaRed))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEncabezado(widget.cliente),
                  const SizedBox(height: 20),
                  _buildSemaforoSBS(widget.cliente.calificacionSBS),
                  const SizedBox(height: 20),
                  _buildSeccionPosicion(viewModel.posicionConsolidada),
                  const SizedBox(height: 20),
                  _buildSeccionComportamiento(viewModel),
                  const SizedBox(height: 30),
                ],
              ),
            ),
      bottomNavigationBar: _buildActionButtons(viewModel, widget.cliente),
    );
  }

  Widget _buildEncabezado(Cliente c) {
    return Row(
      children: [
        CircleAvatar(
          radius: 35,
          backgroundColor: const Color(0xFFED1C24).withOpacity(0.1),
          child: Text(c.nombres.isNotEmpty ? c.nombres[0] : "?", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFED1C24))),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.nombreCompleto, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text("${c.tipoDocumento}: ${c.numeroDocumento}", style: const TextStyle(color: Colors.grey)),
              Text(c.negocioTipo ?? "Giro no especificado", style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSemaforoSBS(String calificacion) {
    Color color;
    switch (calificacion.toUpperCase()) {
      case 'NORMAL': color = Colors.green; break;
      case 'CPP': color = Colors.orange; break;
      case 'DEFICIENTE': color = Colors.deepOrange; break;
      case 'DUDOSO': color = Colors.red; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Row(
        children: [
          Icon(Icons.traffic, color: color),
          const SizedBox(width: 12),
          Text("Riesgo SBS: $calificacion", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSeccionPosicion(Map<String, dynamic>? data) {
    if (data == null) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("POSICIÓN DEL CLIENTE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _rowInfo("Deuda Total", "S/ ${data['deuda_total']}"),
                _rowInfo("Cuentas Vigentes", "${data['cuentas_vigentes']}"),
                _rowInfo("Último Pago", "${data['fecha_ultimo_pago']}"),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _rowInfo(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))],
    );
  }

  Widget _buildSeccionComportamiento(CarteraViewModel vm) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("COMPORTAMIENTO (12M)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        SizedBox(height: 10),
        SizedBox(height: 100, child: Center(child: Text("Gráfico de comportamiento cargando..."))),
      ],
    );
  }

  Widget _buildActionButtons(CarteraViewModel vm, Cliente c) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.buroConsulta, arguments: c),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFED1C24), minimumSize: const Size(double.infinity, 50)),
        icon: const Icon(Icons.security, color: Colors.white),
        label: const Text("VERIFICAR RIESGOS", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}