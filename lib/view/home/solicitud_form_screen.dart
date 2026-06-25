import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import '../../viewmodel/cartera_viewmodel.dart';
import '../../navigation/app_routes.dart';

class SolicitudFormScreen extends StatefulWidget {
  const SolicitudFormScreen({super.key});

  @override
  State<SolicitudFormScreen> createState() => _SolicitudFormScreenState();
}

class _SolicitudFormScreenState extends State<SolicitudFormScreen> {
  int _currentStep = 0;
  final List<GlobalKey<FormState>> _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];
  
  late SignatureController _signatureController;

  // Controladores de datos (Resumen de RF-44 a RF-48)
  final Map<String, dynamic> _solicitudData = {
    'nombres': '',
    'apellidos': '',
    'dni': '',
    'monto': 5000.0,
    'plazo': 12,
    'tipo_negocio': 'Comercio',
    'nombre_negocio': '',
    'destino': '',
  };

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
    const scotiaRed = Color(0xFFED1C24);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Registro de Solicitud", style: TextStyle(color: Colors.white)),
        backgroundColor: scotiaRed,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // RF-43: Indicador de progreso
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) => _buildStepIndicator(index)),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildStepContent(viewModel),
            ),
          ),
          _buildNavigationButtons(viewModel),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int index) {
    bool isActive = _currentStep == index;
    bool isCompleted = _currentStep > index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 40,
      height: 8,
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green : (isActive ? const Color(0xFFED1C24) : Colors.grey[300]),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildStepContent(CarteraViewModel viewModel) {
    switch (_currentStep) {
      case 0: return _stepDatosPersonales();
      case 1: return _stepDatosNegocio();
      case 2: return _stepCondicionesCredito(viewModel);
      case 3: return _stepFirmaYConfirmacion();
      default: return const SizedBox();
    }
  }

  Widget _stepDatosPersonales() {
    return Form(
      key: _formKeys[0],
      child: Column(
        children: [
          const Text("Paso 1: Datos del Solicitante", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(
            initialValue: _solicitudData['nombres'],
            decoration: const InputDecoration(labelText: "Nombres", border: OutlineInputBorder()),
            validator: (v) => v!.isEmpty ? "Campo obligatorio" : null,
            onChanged: (v) => _solicitudData['nombres'] = v,
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _solicitudData['apellidos'],
            decoration: const InputDecoration(labelText: "Apellidos", border: OutlineInputBorder()),
            validator: (v) => v!.isEmpty ? "Campo obligatorio" : null,
            onChanged: (v) => _solicitudData['apellidos'] = v,
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _solicitudData['dni'],
            decoration: const InputDecoration(labelText: "DNI", border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            validator: (v) => v!.length != 8 ? "DNI debe tener 8 dígitos" : null,
            onChanged: (v) => _solicitudData['dni'] = v,
          ),
        ],
      ),
    );
  }

  Widget _stepDatosNegocio() {
    return Form(
      key: _formKeys[1],
      child: Column(
        children: [
          const Text("Paso 2: Información del Negocio", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(
            initialValue: _solicitudData['nombre_negocio'],
            decoration: const InputDecoration(labelText: "Nombre del Negocio", border: OutlineInputBorder()),
            validator: (v) => v!.isEmpty ? "Campo obligatorio" : null,
            onChanged: (v) => _solicitudData['nombre_negocio'] = v,
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _solicitudData['destino'],
            maxLines: 3,
            decoration: const InputDecoration(labelText: "Destino del Crédito", border: OutlineInputBorder()),
            validator: (v) => v!.isEmpty ? "Campo obligatorio" : null,
            onChanged: (v) => _solicitudData['destino'] = v,
          ),
        ],
      ),
    );
  }

  Widget _stepCondicionesCredito(CarteraViewModel viewModel) {
    final simulacion = viewModel.calcularSimulacion(_solicitudData['monto'], 25.5, _solicitudData['plazo']);
    return Form(
      key: _formKeys[2],
      child: Column(
        children: [
          const Text("Paso 3: Condiciones y Simulación", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Text("Monto: S/ ${_solicitudData['monto_solicitado'].toInt()}"),
          Slider(
            value: _solicitudData['monto_solicitado'],
            min: 500, max: 150000, divisions: 299,
            onChanged: (v) => setState(() => _solicitudData['monto_solicitado'] = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _solicitudData['plazo_meses'],
            decoration: const InputDecoration(labelText: "Plazo", border: OutlineInputBorder()),
            items: [3, 6, 12, 18, 24, 36, 48, 60].map((p) => DropdownMenuItem(value: p, child: Text("$p meses"))).toList(),
            onChanged: (v) => setState(() => _solicitudData['plazo_meses'] = v!),
          ),
          const SizedBox(height: 24),
          if (simulacion.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Text("Cuota Estimada: S/ ${simulacion['cuota']?.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                  Text("Total a pagar: S/ ${simulacion['totalPagar']?.toStringAsFixed(2)}"),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _stepFirmaYConfirmacion() {
    return Form(
      key: _formKeys[3],
      child: Column(
        children: [
          const Text("Paso 4: Firma Digital", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text("Firma del cliente aquí:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
            child: Signature(controller: _signatureController, height: 200, backgroundColor: Colors.grey[50]!),
          ),
          TextButton(onPressed: () => _signatureController.clear(), child: const Text("LIMPIAR FIRMA")),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(CarteraViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton(onPressed: () => setState(() => _currentStep--), child: const Text("ANTERIOR")),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFED1C24)),
            onPressed: () async {
              if (!_formKeys[_currentStep].currentState!.validate()) return;
              
              if (_currentStep < 3) {
                setState(() => _currentStep++);
              } else {
                // Validar firma
                if (_signatureController.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("La firma es obligatoria.")));
                  return;
                }
                
                // Verificar documentos antes de enviar (Flujo 2)
                if (!viewModel.puedeEnviarSolicitud) {
                  final res = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text("Documentación incompleta"),
                      content: const Text("Faltan documentos obligatorios. ¿Desea ir a cargarlos ahora?"),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("DESPUÉS")),
                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("CARGAR")),
                      ],
                    )
                  );
                  if (res == true) {
                    Navigator.pushNamed(context, AppRoutes.documentosSolicitud);
                  }
                  return;
                }

                final image = await _signatureController.toPngBytes();
                _solicitudData['firma'] = base64Encode(image!);
                
                // Finalizar y enviar (RF-48)
                final result = await viewModel.enviarSolicitud(_solicitudData);
                if (mounted && result != null) {
                  _showSuccessDialog(result);
                }
              }
            },
            child: Text(
              _currentStep == 3 ? "FINALIZAR Y ENVIAR" : "SIGUIENTE",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String expediente) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Solicitud Enviada"),
        content: Text("Se ha generado el expediente: $expediente.\nEl comité de evaluación recibirá la solicitud en breve."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst), child: const Text("ACEPTAR")),
        ],
      ),
    );
  }
}