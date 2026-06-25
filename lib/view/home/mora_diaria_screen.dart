import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/cartera_viewmodel.dart';
import '../../navigation/app_routes.dart';

class MoraDiariaScreen extends StatefulWidget {
  const MoraDiariaScreen({super.key});

  @override
  State<MoraDiariaScreen> createState() => _MoraDiariaScreenState();
}

class _MoraDiariaScreenState extends State<MoraDiariaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CarteraViewModel>().fetchCarteraVencida();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CarteraViewModel>();
    const scotiaRed = Color(0xFFED1C24);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cobranza - Mora Diaria", style: TextStyle(color: Colors.white)),
        backgroundColor: scotiaRed,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            color: scotiaRed,
            child: Column(
              children: [
                const Text("MONTO TOTAL VENCIDO", style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text("S/ ${viewModel.totalMora.toStringAsFixed(2)}", 
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: viewModel.isLoading
                ? const Center(child: CircularProgressIndicator(color: scotiaRed))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: viewModel.carteraVencida.length,
                    itemBuilder: (context, index) {
                      final item = viewModel.carteraVencida[index];
                      return _buildMoraCard(context, item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoraCard(BuildContext context, Map<String, dynamic> item) {
    final dias = item['dias_mora'] ?? 0;
    Color semaforo;
    String urgencia;

    if (dias <= 30) {
      semaforo = Colors.yellow[700]!;
      urgencia = "Seguimiento preventivo";
    } else if (dias <= 60) {
      semaforo = Colors.orange;
      urgencia = "Gestión prioritaria";
    } else {
      semaforo = Colors.red;
      urgencia = "Recuperación urgente";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => Navigator.pushNamed(context, AppRoutes.gestionCobranza, arguments: item),
        title: Text(item['clientes']['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Monto Vencido: S/ ${item['monto_vencido']}"),
            Text("Último contacto: ${item['ultimo_contacto'] ?? 'Ninguno'}"),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: semaforo.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(urgencia, style: TextStyle(color: semaforo, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("$dias", style: TextStyle(color: semaforo, fontSize: 20, fontWeight: FontWeight.bold)),
            const Text("días", style: TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}