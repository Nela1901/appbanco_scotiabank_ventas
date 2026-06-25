import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/cartera_viewmodel.dart';
import 'package:intl/intl.dart';

class GestionCobranzaScreen extends StatefulWidget {
  const GestionCobranzaScreen({super.key});

  @override
  State<GestionCobranzaScreen> createState() => _GestionCobranzaScreenState();
}

class _GestionCobranzaScreenState extends State<GestionCobranzaScreen> {
  final _formKey = GlobalKey<FormState>();
  String _tipoGestion = 'Visita';
  String _resultado = 'Compromiso de pago';
  final _obsController = TextEditingController();
  final _montoComprometidoController = TextEditingController();
  final _montoPagadoController = TextEditingController();
  DateTime? _fechaCompromiso;

  @override
  Widget build(BuildContext context) {
    final item = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final viewModel = context.watch<CarteraViewModel>();
    const scotiaRed = Color(0xFFED1C24);

    return Scaffold(
      appBar: AppBar(
        title: Text("Gestionar: ${item['clientes']['nombre']}", style: const TextStyle(color: Colors.white, fontSize: 16)),
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
              const Text("Detalles de la Acción", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _tipoGestion,
                decoration: const InputDecoration(labelText: "Tipo de Gestión", border: OutlineInputBorder()),
                items: ['Visita', 'Llamada', 'Mensaje'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _tipoGestion = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _resultado,
                decoration: const InputDecoration(labelText: "Resultado", border: OutlineInputBorder()),
                items: ['Compromiso de pago', 'Pago parcial', 'Sin contacto', 'Se niega a pagar'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _resultado = v!),
              ),
              const SizedBox(height: 16),
              if (_resultado == 'Pago parcial')
                TextFormField(
                  controller: _montoPagadoController,
                  decoration: const InputDecoration(labelText: "Monto Pagado Hoy (S/)", border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              if (_resultado == 'Compromiso de pago') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _montoComprometidoController,
                  decoration: const InputDecoration(labelText: "Monto Comprometido (S/)", border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) setState(() => _fechaCompromiso = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: "Fecha de Compromiso", border: OutlineInputBorder()),
                    child: Text(_fechaCompromiso == null ? "Seleccionar fecha" : DateFormat('dd/MM/yyyy').format(_fechaCompromiso!)),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _obsController,
                maxLines: 3,
                maxLength: 200,
                decoration: const InputDecoration(labelText: "Observaciones", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 32),
              viewModel.isLoading
                  ? const Center(child: CircularProgressIndicator(color: scotiaRed))
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: scotiaRed, padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: () => _submit(viewModel, item['id']),
                        child: const Text("REGISTRAR GESTIÓN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit(CarteraViewModel vm, String moraId) async {
    if (_formKey.currentState!.validate()) {
      final data = {
        'mora_id': moraId,
        'tipo_gestion': _tipoGestion,
        'resultado': _resultado,
        'observaciones': _obsController.text,
        'monto_pagado': double.tryParse(_montoPagadoController.text) ?? 0,
        'monto_comprometido': double.tryParse(_montoComprometidoController.text) ?? 0,
        'fecha_compromiso': _fechaCompromiso?.toIso8601String(),
      };

      final success = await vm.registrarGestionCobranza(data);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gestión registrada correctamente")));
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al registrar gestión")));
        }
      }
    }
  }
}