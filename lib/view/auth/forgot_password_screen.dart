import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/auth_oficial_viewmodel.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _codigoController = TextEditingController();

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
                  const Text("Recuperar Acceso", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("Ingresa tu código de empleado y te enviaremos un enlace a tu correo institucional registrado.", style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _codigoController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Código de empleado",
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (viewModel.errorMessage != null)
                    Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(viewModel.errorMessage!, style: const TextStyle(color: Colors.red))),
                  viewModel.isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFED1C24)))
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFED1C24), minimumSize: const Size(double.infinity, 50)),
                          onPressed: () async {
                            final success = await viewModel.resetPassword(_codigoController.text);
                            if (success && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Enlace enviado. Por favor revisa tu bandeja institucional."))
                              );
                              Navigator.pop(context);
                            }
                          },
                          child: const Text("ENVIAR ENLACE", style: TextStyle(color: Colors.white)),
                        ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}