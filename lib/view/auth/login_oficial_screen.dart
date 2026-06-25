import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/auth_oficial_viewmodel.dart';
import '../../navigation/app_routes.dart';

class LoginOficialScreen extends StatefulWidget {
  const LoginOficialScreen({super.key});

  @override
  State<LoginOficialScreen> createState() => _LoginOficialScreenState();
}

class _LoginOficialScreenState extends State<LoginOficialScreen> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AuthOficialViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.network(
                    'https://raw.githubusercontent.com/Nela1901/assets/main/logoscotia.png',
                    height: 60,
                    errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.account_balance, size: 80, color: Color(0xFFED1C24)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "SCOTIABANK",
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "Portal Oficial de Credito",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _userController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number, // RF-01: Teclado numérico
                    decoration: const InputDecoration(
                      labelText: "Código de empleado",
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Contraseña",
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white70,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (viewModel.errorMessage != null)
                    Text(viewModel.errorMessage!, style: const TextStyle(color: Colors.red)),
                  if (viewModel.estaBloqueado)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        "Bloqueado. Reintenta en ${viewModel.segundosRestantesBloqueo}s",
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                  const SizedBox(height: 16),
                  viewModel.isLoading
                      ? const CircularProgressIndicator(color: Color(0xFFED1C24))
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFED1C24),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          onPressed: viewModel.estaBloqueado 
                            ? null 
                            : () async {
                                final success = await viewModel.login(_userController.text, _passController.text);
                                if (success && mounted) {
                                  Navigator.pushReplacementNamed(context, AppRoutes.home);
                                }
                              },
                          child: const Text("INGRESAR", style: TextStyle(color: Colors.white)),
                        ),
                  const SizedBox(height: 24),
                  // RF-01: Enlace único de problemas para ingresar
                  TextButton(
                    onPressed: () => _showProblemasMenu(context),
                    child: const Text(
                      "Problemas para ingresar",
                      style: TextStyle(color: Colors.white70, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showProblemasMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.lock_reset, color: Colors.white),
            title: const Text("Olvidé mi contraseña", style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.popAndPushNamed(context, AppRoutes.forgotPassword),
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings, color: Colors.white),
            title: const Text("Solicitar acceso institucional", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Para nuevos ingresos", style: TextStyle(color: Colors.white60, fontSize: 12)),
            onTap: () => Navigator.popAndPushNamed(context, AppRoutes.registerRequest),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}