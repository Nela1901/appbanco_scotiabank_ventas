import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/cartera_viewmodel.dart';

class DetalleSolicitudScreen extends StatefulWidget {
  const DetalleSolicitudScreen({super.key});

  @override
  State<DetalleSolicitudScreen> createState() => _DetalleSolicitudScreenState();
}

class _DetalleSolicitudScreenState extends State<DetalleSolicitudScreen> {
  final _notaController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final s = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final viewModel = context.watch<CarteraViewModel>();
    const scotiaRed = Color(0xFFED1C24);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Expediente Digital", style: TextStyle(color: Colors.white)),
        backgroundColor: scotiaRed,
        actions: [
          IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () {}), // RF-71: PDF
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(s),
            const Divider(height: 40),
            const Text("Línea de Tiempo del Proceso", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            _buildTimeline(s['estado']),
            const SizedBox(height: 30),
            _buildNotesSection(viewModel, s['id']),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s['nombres'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text("Expediente: ${s['numero_expediente'] ?? 'PENDIENTE'}", style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.monetization_on, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text("S/ ${s['monto']} - ${s['plazo']} meses", style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeline(String estadoActual) {
    final etapas = ['Enviada', 'En comité', 'Aprobada', 'Desembolsada'];
    int currentIdx = etapas.indexOf(estadoActual);
    if (currentIdx == -1 && estadoActual == 'Rechazada') currentIdx = 1;

    return Column(
      children: etapas.asMap().entries.map((entry) {
        int idx = entry.key;
        String name = entry.value;
        bool isPast = idx <= currentIdx;
        bool isLast = idx == etapas.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Icon(isPast ? Icons.check_circle : Icons.radio_button_unchecked, color: isPast ? Colors.green : Colors.grey),
                if (!isLast) Container(height: 40, width: 2, color: isPast ? Colors.green : Colors.grey.withOpacity(0.3)),
              ],
            ),
            const SizedBox(width: 15),
            Text(name, style: TextStyle(fontWeight: isPast ? FontWeight.bold : FontWeight.normal, color: isPast ? Colors.black : Colors.grey)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildNotesSection(CarteraViewModel vm, String id) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Notas Internas", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextField(
          controller: _notaController,
          maxLength: 500,
          decoration: const InputDecoration(hintText: "Agregar comentario privado...", border: OutlineInputBorder()),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_notaController.text.isNotEmpty) {
              await vm.agregarNotaInterna(id, _notaController.text);
              _notaController.clear();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nota guardada.")));
            }
          },
          child: const Text("GUARDAR NOTA"),
        ),
      ],
    );
  }
}