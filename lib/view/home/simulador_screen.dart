import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/cartera_viewmodel.dart';
import '../../navigation/app_routes.dart';

class SimuladorScreen extends StatefulWidget {
  const SimuladorScreen({super.key});

  @override
  State<SimuladorScreen> createState() => _SimuladorScreenState();
}

class _SimuladorScreenState extends State<SimuladorScreen> {
  double _monto = 5000;
  int _plazo = 12;
  final double _teaReferencial = 25.5;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CarteraViewModel>();
    final resultados = viewModel.calcularSimulacion(_monto, _teaReferencial, _plazo);
    const scotiaRed = Color(0xFFED1C24);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Simulador de Cuotas", style: TextStyle(color: Colors.white)),
        backgroundColor: scotiaRed,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResultCard("Cuota Mensual Estimada", resultados['cuota'] ?? 0, isMain: true),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildResultCard("Total a Pagar", resultados['totalPagar'] ?? 0)),
                const SizedBox(width: 12),
                Expanded(child: _buildResultCard("Costo Financiero", resultados['costoFinanciero'] ?? 0)),
              ],
            ),
            const SizedBox(height: 40),
            const Text("Configuración del Crédito", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 24),
            Text("Monto: S/ ${_monto.toInt()}", style: const TextStyle(fontSize: 16)),
            Slider(
              value: _monto,
              min: 500,
              max: 150000,
              divisions: 299,
              activeColor: scotiaRed,
              onChanged: (v) => setState(() => _monto = v),
            ),
            const SizedBox(height: 24),
            const Text("Plazo (Meses)"),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _plazo,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [3, 6, 12, 18, 24, 36, 48, 60].map((p) => DropdownMenuItem(value: p, child: Text("$p meses"))).toList(),
              onChanged: (v) => setState(() => _plazo = v!),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: scotiaRed, padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.solicitud, arguments: {'monto': _monto, 'plazo': _plazo});
                },
                child: const Text("CREAR SOLICITUD CON ESTOS DATOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(String title, double value, {bool isMain = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMain ? const Color(0xFFED1C24).withOpacity(0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isMain ? const Color(0xFFED1C24) : Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: isMain ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: isMain ? const Color(0xFFED1C24) : Colors.grey[600])),
          const SizedBox(height: 4),
          Text(
            "S/ ${value.toStringAsFixed(2)}",
            style: TextStyle(fontSize: isMain ? 28 : 16, fontWeight: FontWeight.bold, color: isMain ? const Color(0xFFED1C24) : Colors.black),
          ),
        ],
      ),
    );
  }
}