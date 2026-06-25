import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:photo_view/photo_view.dart';
import '../../viewmodel/cartera_viewmodel.dart';

class DocumentosSolicitudScreen extends StatefulWidget {
  const DocumentosSolicitudScreen({super.key});

  @override
  State<DocumentosSolicitudScreen> createState() => _DocumentosSolicitudScreenState();
}

class _DocumentosSolicitudScreenState extends State<DocumentosSolicitudScreen> {
  // La solicitudId debe venir por argumentos o ser gestionada por el ViewModel
  // Si es una nueva solicitud, el ViewModel debería generar un ID temporal
  // y luego actualizarlo cuando la solicitud se guarde en Supabase.
  // Por ahora, se mantiene el placeholder, pero es un punto crítico a resolver.
  String solicitudId = "TEMP_EXP_001"; 
  

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CarteraViewModel>();
    const scotiaRed = Color(0xFFED1C24);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Documentos de la Solicitud", style: TextStyle(color: Colors.white)),
        backgroundColor: scotiaRed,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Cargue las fotos de los documentos obligatorios para habilitar el envío del expediente."),
          ),
          Expanded(
            child: ListView(
              children: viewModel.documentosEstado.entries.map((entry) {
                return _buildDocumentTile(context, viewModel, entry.key, entry.value);
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: scotiaRed,
                minimumSize: const Size(double.infinity, 50),
                disabledBackgroundColor: Colors.grey[300]
              ),
              onPressed: viewModel.puedeEnviarSolicitud ? () => Navigator.pop(context) : null,
              child: const Text("CONTINUAR CON EL ENVÍO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDocumentTile(BuildContext context, CarteraViewModel vm, String tipo, String estado) {
    Color colorEstado = estado == 'LISTO' ? Colors.green : (estado == 'OBLIGATORIO' ? Colors.red : Colors.grey);
    
    return ListTile(
      leading: Icon(Icons.file_present, color: colorEstado),
      title: Text(tipo.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      subtitle: Text(estado, style: TextStyle(color: colorEstado, fontSize: 11)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (estado == 'LISTO')
            IconButton(
              icon: const Icon(Icons.visibility, color: Colors.blue),
              onPressed: () => _showImageViewer(context, vm.getUrlDocumento(solicitudId, tipo), tipo, vm),
            ),
          IconButton(
            icon: Icon(estado == 'LISTO' ? Icons.replay : Icons.camera_alt, color: Colors.grey[700]),
            onPressed: () => _openCamera(context, vm, tipo),
          ),
        ],
      ),
    );
  }

  Future<void> _openCamera(BuildContext context, CarteraViewModel vm, String tipo) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    if (!mounted) return;
    
    // RF-53: Simulación de cámara con marco guía (se requiere implementar una vista de cámara personalizada)
    // Por ahora usaremos la lógica de captura y procesamiento
    final result = await Navigator.push<XFile>(
      context,
      MaterialPageRoute(builder: (context) => CameraCapturePage(cameras: cameras, tipo: tipo))
    );

    if (result != null) {
      final success = await vm.procesarYSubirDocumento(solicitudId, tipo, File(result.path));
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(vm.errorMessage ?? "Error en la nitidez o al subir la foto.")));
      }
    }
  }

  void _showImageViewer(BuildContext context, String url, String tipo, CarteraViewModel vm) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Column(
          children: [
            AppBar(
              title: Text(tipo),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text("¿Eliminar documento?"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("CANCELAR")),
                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("ELIMINAR")),
                        ],
                      )
                    );
                    if (confirm == true) {
                      await vm.eliminarDocumento(solicitudId, tipo);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                )
              ],
            ),
            Expanded(
              child: PhotoView(imageProvider: NetworkImage(url)),
            ),
          ],
        ),
      ),
    );
  }
}

// RF-53: Página de captura simple
class CameraCapturePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String tipo;
  const CameraCapturePage({super.key, required this.cameras, required this.tipo});

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    // Inicializamos el controlador en el initState para que persista
    _controller = CameraController(widget.cameras[0], ResolutionPreset.high);
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // Es vital liberar el controlador al cerrar la pantalla
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && !snapshot.hasError) {
            return Stack(
              children: [
                CameraPreview(_controller),
                Center(child: Container(width: 300, height: 200, decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2)))),
                Positioned(
                  bottom: 50, 
                  left: 0, 
                  right: 0, 
                  child: IconButton(
                    icon: const Icon(Icons.camera, size: 70, color: Colors.white), 
                    onPressed: () async {
                      // RF-53: Validar que el controlador esté listo y no esté capturando ya
                      if (!_controller.value.isInitialized || _controller.value.isTakingPicture) {
                        debugPrint("Cámara ocupada o no inicializada.");
                        return; // Evita intentar tomar foto si la cámara no está lista
                      }
                      try {
                        // Re-aseguramos la inicialización antes de disparar
                        await _initializeControllerFuture;
                        final file = await _controller.takePicture();
                        if (mounted) Navigator.pop(context, file);
                      } catch (e) {
                        debugPrint("Error al tomar fotografía: $e");
                      }
                    }
                  )
                )
              ],
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  "Error al iniciar la cámara: ${snapshot.error}\n\nVerifique los permisos en la configuración del dispositivo.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}