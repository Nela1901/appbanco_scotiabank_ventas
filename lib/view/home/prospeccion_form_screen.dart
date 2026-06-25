import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/cartera_viewmodel.dart';

class ProspeccionFormScreen extends StatefulWidget {
  const ProspeccionFormScreen({super.key});

  @override
  State<ProspeccionFormScreen> createState() => _ProspeccionFormScreenState();
}

class _ProspeccionFormScreenState extends State<ProspeccionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _docController = TextEditingController();
  final _nombreController = TextEditingController();
  final _apellidosController = TextEditingController();
  String _tipoNegocio = 'Comercio';
  double _montoSolicitado = 5000;
  final _ingresosController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CarteraViewModel>();
    const scotiaRed = Color(0xFFED1C24);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Nueva Prospección", style: TextStyle(color: Colors.white)),
        backgroundColor: scotiaRed,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Datos del Prospecto", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _docController,
                decoration: const InputDecoration(labelText: "DNI (8 dígitos)", border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.length != 8) ? "Ingrese un DNI válido" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: "Nombres", border: OutlineInputBorder()),
                validator: (v) => (v == null || v.isEmpty) ? "Campo requerido" : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _tipoNegocio,
                decoration: const InputDecoration(labelText: "Tipo de Negocio", border: OutlineInputBorder()),
                items: ['Comercio', 'Producción', 'Servicios', 'Transporte'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _tipoNegocio = v!),
              ),
              const SizedBox(height: 24),
              Text("Monto Solicitado: S/ ${_montoSolicitado.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Slider(
                value: _montoSolicitado,
                min: 500,
                max: 50000,
                divisions: 99,
                activeColor: scotiaRed,
                onChanged: (v) => setState(() => _montoSolicitado = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ingresosController,
                decoration: const InputDecoration(labelText: "Ingresos Mensuales Estimados", prefixText: "S/ ", border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 32),
              viewModel.isLoading
                  ? const Center(child: CircularProgressIndicator(color: scotiaRed))
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: scotiaRed, padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: _submit,
                        child: const Text("PRE-EVALUAR EN CAMPO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final viewModel = context.read<CarteraViewModel>();
      await viewModel.preEvaluarProspecto({
        'dni': _docController.text,
        'nombres': _nombreController.text,
        'tipo_negocio': _tipoNegocio,
        'monto': _montoSolicitado,
        'ingresos': _ingresosController.text,
      });
      
      if (mounted && viewModel.resultadoPreEvaluacion != null) {
        _showResultDialog(viewModel.resultadoPreEvaluacion!);
      }
    }
  }

  void _showResultDialog(Map<String, dynamic> res) {
    Color color;
    IconData icon;
    switch (res['calificacion']) {
      case 'APTO': color = Colors.green; icon = Icons.check_circle; break;
      case 'REVISAR': color = Colors.orange; icon = Icons.warning; break;
      default: color = Colors.red; icon = Icons.error;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text("Resultado: ${res['calificacion']}"),
          ],
        ),
        content: Text(res['motivo'] ?? "Análisis crediticio completado."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CERRAR")),
          if (res['calificacion'] == 'APTO')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {},
              child: const Text("INICIAR SOLICITUD", style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}