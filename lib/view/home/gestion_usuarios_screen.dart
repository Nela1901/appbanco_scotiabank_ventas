import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/auth_oficial_viewmodel.dart';

class GestionUsuariosScreen extends StatefulWidget {
  const GestionUsuariosScreen({super.key});

  @override
  State<GestionUsuariosScreen> createState() => _GestionUsuariosScreenState();
}

class _GestionUsuariosScreenState extends State<GestionUsuariosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthOficialViewModel>().fetchUsuarios();
      context.read<AuthOficialViewModel>().fetchSolicitudesAcceso();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AuthOficialViewModel>();
    const scotiaRed = Color(0xFFED1C24);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Administración Central", style: TextStyle(color: Colors.white)),
          backgroundColor: scotiaRed,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "Usuarios", icon: Icon(Icons.people)),
              Tab(text: "Solicitudes", icon: Icon(Icons.pending_actions)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Pestaña 1: Usuarios existentes
            Column(
              children: [
                // Fila de Filtros (Nubes)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Row(
                    children: ['Todos', 'Operador', 'Super Operador', 'Supervisor', 'Administrador']
                        .map((rol) {
                      final isSelected = viewModel.filtroUsuarioActual == rol;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text(rol),
                          selected: isSelected,
                          onSelected: (_) => viewModel.setFiltroUsuario(rol),
                          selectedColor: scotiaRed.withOpacity(0.2),
                          labelStyle: TextStyle(
                              color: isSelected ? scotiaRed : Colors.black,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: viewModel.isLoadingUsuarios
                      ? const Center(child: CircularProgressIndicator(color: scotiaRed))
                      : viewModel.usuariosFiltrados.isEmpty
                          ? const Center(child: Text("No hay usuarios en este rol"))
                          : ListView.builder(
                              itemCount: viewModel.usuariosFiltrados.length,
                              itemBuilder: (context, index) {
                                final user = viewModel.usuariosFiltrados[index];
                                final userId = user['id']?.toString() ?? '';
                                final displayId = userId.length >= 8 ? userId.substring(0, 8) : userId;

                                return ListTile(
                                    leading: const CircleAvatar(child: Icon(Icons.person)),
                                    title: Text("${user['nombres'] ?? ''} ${user['apellidos'] ?? ''}"),
                                    subtitle: Text("Rol: ${user['perfil'] ?? 'Operador'} | ID: $displayId"),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                                          onPressed: () => _showEditUserDialog(context, viewModel, user),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                          onPressed: () => _confirmarEliminacion(context, viewModel, user),
                                        ),
                                      ],
                                    ));
                              },
                            ),
                ),
              ],
            ),
            // Pestaña 2: Solicitudes de Acceso
            viewModel.isLoadingSolicitudes
                ? const Center(child: CircularProgressIndicator(color: scotiaRed))
                    : viewModel.solicitudesAcceso.isEmpty
                    ? const Center(child: Text("No hay solicitudes pendientes"))
                    : ListView.builder(
                        itemCount: viewModel.solicitudesAcceso.length,
                        itemBuilder: (context, index) {
                          final solicitud = viewModel.solicitudesAcceso[index];
                          return ListTile(
                            leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.access_time, color: Colors.white)),
                            title: Text("${solicitud['nombres'] ?? ''} ${solicitud['apellidos'] ?? ''}"),
                            subtitle: Text("Cod: ${solicitud['codigo_empleado']} | ${solicitud['email_contacto']}"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                                  onPressed: () => _showAddUserDialog(context, viewModel, fromSolicitud: solicitud),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                                  onPressed: () => viewModel.rechazarSolicitud(solicitud['id']),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: scotiaRed,
          onPressed: () => _showAddUserDialog(context, viewModel),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  void _confirmarEliminacion(BuildContext context, AuthOficialViewModel vm, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Revocar Acceso"),
        content: Text("¿Estás seguro que deseas eliminar a ${user['nombres']}? No podrá volver a ingresar a la app."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          TextButton(
            onPressed: () async {
              final success = await vm.eliminarAsesor(user['id']);
              if (success && context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Usuario eliminado")));
              }
            },
            child: const Text("ELIMINAR", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, AuthOficialViewModel vm, Map<String, dynamic> user) {
    final nombreController = TextEditingController(text: user['nombres']);
    final apellidoController = TextEditingController(text: user['apellidos']);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    final roles = ['Operador', 'Super Operador', 'Supervisor', 'Administrador'];
    
    // Normalizamos el rol de la base de datos para que coincida con la lista UI.
    // Esto evita el crash si en la DB está 'administrador' o 'super_operador'.
    final dbPerfil = (user['perfil'] ?? '').toString().toLowerCase();
    String selectedRol = roles.firstWhere(
      (r) {
        final rLower = r.toLowerCase();
        return rLower == dbPerfil || rLower.replaceAll(' ', '_') == dbPerfil;
      },
      orElse: () => 'Operador',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setModalState) {
          return AlertDialog(
          title: Text("Editar Usuario: ${user['codigo_empleado'] ?? ''}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: "Nombres"),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: apellidoController,
                decoration: const InputDecoration(labelText: "Apellidos"),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRol,
                items: roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setModalState(() => selectedRol = v!),
                decoration: const InputDecoration(labelText: "Rol", border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
            ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFED1C24)),
                    onPressed: () async {
                      if (nombreController.text.isEmpty || apellidoController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Nombres y Apellidos son obligatorios")));
                        return;
                      }

                      // Normalizamos a minúsculas para la base de datos
                      final rolParaDB = selectedRol.toLowerCase().replaceAll(' ', '_');

                      // Cerramos de inmediato para mejor UX
                      Navigator.of(dialogContext).pop();

                      final success = await vm.actualizarAsesor(
                        user['id'],
                        nombreController.text,
                        apellidoController.text,
                        rolParaDB,
                      );

                      if (success) {
                        scaffoldMessenger.showSnackBar(
                            const SnackBar(content: Text("Usuario actualizado correctamente")));
                      } else {
                        scaffoldMessenger.showSnackBar(
                            SnackBar(content: Text(vm.errorMessage ?? "Error al actualizar")));
                      }
                    },
                    child: const Text("GUARDAR", style: TextStyle(color: Colors.white)),
                  ),
          ],
        );
        },
      ),
    );
  }

  void _showAddUserDialog(BuildContext context, AuthOficialViewModel vm, {Map<String, dynamic>? fromSolicitud}) {
    final codigoController = TextEditingController(text: fromSolicitud?['codigo_empleado'] ?? '');
    final nombreController = TextEditingController(text: fromSolicitud?['nombres'] ?? '');
    
    // Limpiamos errores previos al abrir el diálogo para que no aparezcan mensajes viejos
    vm.clearError();

    final apellidoController = TextEditingController(text: fromSolicitud?['apellidos'] ?? '');
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final roles = ['Operador', 'Super Operador', 'Supervisor', 'Administrador'];
    String selectedRol = 'Operador';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setModalState) => AlertDialog(
          title: Text(fromSolicitud != null ? "Aprobar Solicitud" : "Nuevo Asesor"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codigoController,
                  decoration: const InputDecoration(
                    labelText: "Código de Empleado",
                    hintText: "Ej: 7654321",
                  ),
                  maxLength: 8,
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(labelText: "Nombres"),
                  textCapitalization: TextCapitalization.words,
                ),
                TextField(
                  controller: apellidoController,
                  decoration: const InputDecoration(labelText: "Apellidos"),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRol,
                  items: roles
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) {
                    setModalState(() {
                      selectedRol = v!;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: "Rol",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
            ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFED1C24)),
                    onPressed: () async {
                      if (codigoController.text.isEmpty || nombreController.text.isEmpty || apellidoController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Todos los campos (Código, Nombres, Apellidos) son obligatorios")));
                        return;
                      }

                      // Capturamos datos y cerramos el diálogo de inmediato para mejor UX
                      final codigo = codigoController.text;
                      final nombres = nombreController.text;
                      final apellidos = apellidoController.text;
                      final rolNormalizado = selectedRol.toLowerCase().replaceAll(' ', '_');
                      final solicitudId = fromSolicitud?['id'];

                      Navigator.of(dialogContext).pop();

                      final resultMessage = await vm.crearNuevoAsesor(
                        codigo,
                        nombres,
                        apellidos,
                        rolNormalizado,
                        null, // Se envía null porque la DB espera un UUID (columna agencia_id)
                        solicitudId: solicitudId,
                      );

                      if (resultMessage != null) {
                        scaffoldMessenger.showSnackBar(SnackBar(content: Text(resultMessage)));
                      } else {
                        scaffoldMessenger.showSnackBar(SnackBar(content: Text(vm.errorMessage ?? "Error al procesar solicitud.")));
                      }
                    },
                    child: const Text("CREAR", style: TextStyle(color: Colors.white)),
                  ),
          ],
        ),
      ),
    );
  }
}