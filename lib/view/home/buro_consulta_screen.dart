import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import '../../viewmodel/cartera_viewmodel.dart';
import '../../model/cliente.dart';
import '../../navigation/app_routes.dart';

class BuroConsultaScreen extends StatefulWidget {
  const BuroConsultaScreen({super.key});

  @override
  State<BuroConsultaScreen> createState() => _BuroConsultaScreenState();
}

class _BuroConsultaScreenState extends State<BuroConsultaScreen> {
  static const scotiaRed = Color(0xFFED1C24);

  late SignatureController _signatureController;
  bool _consentimientoAceptado = false;

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(penStrokeWidth: 3, penColor: Colors.black);
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CarteraViewModel>();
    final Cliente? cliente = ModalRoute.of(context)?.settings.arguments as Cliente?;

    if (cliente == null) return const Scaffold(body: Center(child: Text("Error: Cliente no seleccionado")));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Verificación de Riesgos", style: TextStyle(color: Colors.white)),
        backgroundColor: scotiaRed,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: viewModel.resultadoBuro != null 
        ? _buildResultados(viewModel, cliente)
        : _buildConsentimiento(viewModel, cliente),
    );
  }

  Widget _buildConsentimiento(CarteraViewModel vm, Cliente c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (vm.errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
              child: Text(vm.errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
          const Text("Autorización de Consulta", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text(
            "Yo, el cliente, autorizo expresamente a Scotiabank Perú para realizar consultas sobre mi comportamiento crediticio en centrales de riesgo y verificar mis datos en listas de prevención de fraude y lavado de activos, conforme a la Ley 29733.",
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              "Acepto los términos y condiciones de la consulta.",
              style: TextStyle(fontSize: 13),
            ),
            value: _consentimientoAceptado,
            activeColor: scotiaRed,
            onChanged: (val) {
              setState(() {
                _consentimientoAceptado = val ?? false;
              });
            },
          controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 24),
          const Text("Firma del cliente aquí:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
            child: Signature(controller: _signatureController, height: 200, backgroundColor: Colors.grey[50]!),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => _signatureController.clear(), child: const Text("LIMPIAR FIRMA")),
            ],
          ),
          const SizedBox(height: 24),
          vm.isLoading 
            ? const Center(child: CircularProgressIndicator())
            : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scotiaRed, 
                    padding: const EdgeInsets.symmetric(vertical: 16)
                  ),
                  onPressed: () async {
                    if (!_consentimientoAceptado) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Debe aceptar el consentimiento")));
                      return;
                    }
                    if (_signatureController.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("La firma es obligatoria")));
                      return;
                    }
                    final image = await _signatureController.toPngBytes();
                    if (image == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al procesar la firma")));
                      return;
                    }
                    final base64Firma = base64Encode(image);
                    await vm.consultarBuroYListas(c.id, base64Firma);
                  },
                  child: const Text("CONSULTAR BURÓ Y LISTAS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildResultados(CarteraViewModel vm, Cliente c) {
    final res = vm.resultadoBuro!;
    final bool enListaNegra = res['en_lista_negra'] ?? false;

    return SingleChildScrollView( // Añadido SingleChildScrollView para evitar overflow si el contenido es largo
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBanner(vm, enListaNegra),
          const SizedBox(height: 24),
          const Text("Resumen SBS y Buró", style: TextStyle(fontWeight: FontWeight.bold)),
          const Divider(),
          _rowInfo("Calificación SBS", res['calificacion']),
          _rowInfo("Entidades con deuda", "${res['num_entidades']}"),
          _rowInfo("Deuda Total", "S/ ${res['deuda_total']}"),
          _rowInfo("Mora Máxima", "${res['mora_maxima']} días"),
          const SizedBox(height: 24),
          const Text("Interpretación del Sistema", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(vm.interpretacionBuro, style: const TextStyle(fontStyle: FontStyle.italic)),
          const SizedBox(height: 40), // Reemplazado Spacer por SizedBox para evitar la excepción
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: enListaNegra ? Colors.grey : scotiaRed,
                padding: const EdgeInsets.symmetric(vertical: 16)
              ),
              onPressed: enListaNegra ? null : () => Navigator.pushNamed(context, AppRoutes.solicitud, arguments: {'cliente': c}),
              child: Text(enListaNegra ? "SOLICITUD BLOQUEADA" : "CONTINUAR A SOLICITUD", style: const TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatusBanner(CarteraViewModel vm, bool error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: error ? Colors.red[100] : Colors.green[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: error ? Colors.red : Colors.green),
      ),
      child: Row(
        children: [
          Icon(error ? Icons.block : Icons.check_circle, color: error ? Colors.red : Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error ? "CLIENTE EN LISTA DE RESTRICCIÓN\nMotivo: ${vm.resultadoBuro!['motivo_lista'] ?? 'No especificado'}" : "VERIFICACIÓN LIMPIA\nEl cliente no presenta impedimentos.",
              style: TextStyle(color: error ? Colors.red[900] : Colors.green[900], fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowInfo(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value ?? "N/A", style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}