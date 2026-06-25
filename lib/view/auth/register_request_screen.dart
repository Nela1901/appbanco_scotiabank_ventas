import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/auth_oficial_viewmodel.dart';

class RegisterRequestScreen extends StatefulWidget {
  const RegisterRequestScreen({super.key});

  @override
  State<RegisterRequestScreen> createState() => _RegisterRequestScreenState();
}

class _RegisterRequestScreenState extends State<RegisterRequestScreen> {
  final _codigoController = TextEditingController();
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AuthOficialViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Solicitud de Acceso", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("Completa tus datos para que un administrador autorice tu cuenta institucional.", style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 32),
                  _buildField(_codigoController, "Código de empleado (DNI)", isNumeric: true, maxLength: 8),
                  const SizedBox(height: 16),
                  _buildField(_nombresController, "Nombres"),
                  const SizedBox(height: 16),
                  _buildField(_apellidosController, "Apellidos"),
                  const SizedBox(height: 16),
                  _buildField(_emailController, "Correo Personal"),
                  const SizedBox(height: 32),
                  if (viewModel.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16), 
                      child: Text(
                        viewModel.errorMessage ?? "Error desconocido", 
                        style: const TextStyle(color: Colors.red)
                      )
                    ),
                  viewModel.isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFED1C24)))
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFED1C24), minimumSize: const Size(double.infinity, 50)),
                          onPressed: () async {
                            final success = await viewModel.requestRegistration(
                              _codigoController.text,
                              _nombresController.text,
                              _apellidosController.text,
                              _emailController.text,
                            );
                            if (success && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Solicitud enviada. Una vez aprobada, podrás definir tu contraseña en 'Olvidé mi contraseña'.")));
                              Navigator.pop(context);
                            }
                          },
                          child: const Text("ENVIAR SOLICITUD", style: TextStyle(color: Colors.white)),
                        ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, {bool isNumeric = false, int? maxLength}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
      ),
    );
  }
}