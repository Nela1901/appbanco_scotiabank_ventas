import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../model/cliente.dart';
import '../../viewmodel/cartera_viewmodel.dart';
import '../../viewmodel/auth_oficial_viewmodel.dart';
import '../../navigation/app_routes.dart';
import 'ficha_cliente_screen.dart';

class CarteraDiariaScreen extends StatefulWidget {
  const CarteraDiariaScreen({super.key});

  @override
  State<CarteraDiariaScreen> createState() => _CarteraDiariaScreenState();
}

class _CarteraDiariaScreenState extends State<CarteraDiariaScreen> {
  @override
  void initState() {
    super.initState();
    // Cargamos los datos de Supabase apenas entra a la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CarteraViewModel>().fetchClientes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final viewModel = context.watch<CarteraViewModel>();
    final authViewModel = context.watch<AuthOficialViewModel>();
    const scotiaRed = Color(0xFFED1C24);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cartera Diaria", style: TextStyle(color: Colors.white)),
        backgroundColor: scotiaRed,
        elevation: 0,
        actions: [
          // RF-36: Insignia numérica de alertas
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(icon: const Icon(Icons.notifications, color: Colors.white), onPressed: () {}),
              if (viewModel.alertasNoLeidas > 0)
                Positioned(
                  right: 8, top: 8,
                  child: CircleAvatar(radius: 8, backgroundColor: Colors.white, child: Text(viewModel.alertasNoLeidas.toString(), style: const TextStyle(fontSize: 10, color: scotiaRed, fontWeight: FontWeight.bold))),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => viewModel.fetchClientes(),
          )
        ],
      ),
      drawer: _buildDrawer(context, viewModel, authViewModel),
      body: Column(
        children: [
          // Dashboard de Contadores
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scotiaRed,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCounter("Total", viewModel.totalAsignados.toString()),
                    _buildCounter("Visitados", viewModel.visitadosTotal.toString()),
                    _buildCounter("Pendientes", viewModel.pendientesTotal.toString()),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  viewModel.resumenHeader,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  "Última actualización: ${viewModel.ultimaActualizacion}",
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),

          // Barra de Progreso y Buscador
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: viewModel.progresoDia,
                    backgroundColor: Colors.grey[200],
                    color: scotiaRed,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => viewModel.setSearchQuery(v),
                  decoration: InputDecoration(
                    hintText: "Buscar por nombre o DNI...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ],
            ),
          ),

          // RF-41: Sección de Campañas Activas (HU-16)
          if (viewModel.campanasActivas.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: viewModel.campanasActivas.length,
                itemBuilder: (context, index) {
                  final campana = viewModel.campanasActivas[index];
                  return Card(
                    color: Colors.blue[50],
                    margin: const EdgeInsets.only(right: 12, bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(campana['tipo'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                          Text("${campana['clientes']['nombres']} ${campana['clientes']['apellidos']}", style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Barra de Filtros
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Todos', 'Renovaciones', 'Nuevas', 'En mora', 'Visitados'].map((filtro) {
                  final isSelected = viewModel.filtroActual == filtro;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Text(filtro),
                      selected: isSelected,
                      onSelected: (_) => viewModel.setFiltro(filtro),
                      selectedColor: scotiaRed.withOpacity(0.2),
                      labelStyle: TextStyle(color: isSelected ? scotiaRed : Colors.black),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Filtro por Asesor (Solo visible para Supervisor y Admin)
          if (authViewModel.esSupervisor && viewModel.asesoresEnCartera.length > 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text("Filtrar por Asesor:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: viewModel.asesoresEnCartera.map((nombre) {
                        final isSelected = viewModel.filtroAsesor == nombre;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: FilterChip(
                            label: Text(nombre, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black)),
                            selected: isSelected,
                            onSelected: (_) => viewModel.setFiltroAsesor(nombre),
                            selectedColor: Colors.blue[700],
                            backgroundColor: Colors.blue[50],
                            checkmarkColor: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: viewModel.isLoading 
              ? const Center(child: CircularProgressIndicator(color: scotiaRed))
              : viewModel.clientes.isEmpty 
                ? const Center(child: Text("No hay clientes en esta categoría"))
                : ReorderableListView.builder(
                    onReorder: (old, newVal) => viewModel.reorderClientes(old, newVal),
                    padding: const EdgeInsets.all(8),
                    itemCount: viewModel.clientes.length,
                    itemBuilder: (context, index) {
                      final cliente = viewModel.clientes[index];
                      final colorGestion = _getColorGestion(cliente.tipoGestion);

                      return Card(
                        key: ValueKey(cliente.id), // Necesario para ReorderableListView
                        elevation: cliente.visitado ? 0 : 4,
                        shadowColor: Colors.black26,
                        color: cliente.visitado ? Colors.grey[100] : Colors.white,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(color: colorGestion, width: 6),
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            // RF-17: Mostramos primero el detalle rápido/acciones
                            onTap: () => _showClienteDetalle(context, cliente),
                            leading: _buildStatusIcon(cliente),
                            title: Text(
                              cliente.nombreCompleto, 
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: cliente.visitado ? Colors.grey : Colors.black87,
                              )
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  "${cliente.tipoDocumento}: ${cliente.documentoCensurado}",
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                // Si es manager, mostramos a quién está asignado el cliente
                                if (authViewModel.esSupervisor && cliente.nombreAsesor != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text("Asesor: ${cliente.nombreAsesor}", 
                                      style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                _buildGestionChip(cliente.tipoGestion),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("S/ ${cliente.monto.toStringAsFixed(0)}", 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: scotiaRed)),
                                const SizedBox(height: 4),
                                _buildPriorityTag(cliente.prioridad),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.prospeccion),
        backgroundColor: scotiaRed,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text("Prospecto", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, CarteraViewModel viewModel, AuthOficialViewModel authViewModel) {
    const scotiaRed = Color(0xFFED1C24);
    final perfil = authViewModel.perfil;

    return Drawer(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(color: scotiaRed),
                  accountName: Text(
                    authViewModel.mensajeBienvenida,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  accountEmail: Text(authViewModel.nombreUsuario),
                  currentAccountPicture: const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: scotiaRed, size: 40),
                  ),
                ),
                // Módulos base para Operador (y todos los perfiles superiores)
                ListTile(
                  leading: const Icon(Icons.home, color: scotiaRed),
                  title: const Text("Cartera Diaria"),
                  onTap: () {
                    Navigator.pop(context);
                    if (ModalRoute.of(context)?.settings.name !=
                        AppRoutes.home) {
                      Navigator.pushNamedAndRemoveUntil(
                          context, AppRoutes.home, (route) => false);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.map_outlined, color: scotiaRed),
                  title: const Text("Planificación de Ruta"),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.mapaRuta),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.person_search_outlined, color: scotiaRed),
                  title: const Text("Ficha del Cliente"),
                  onTap: () {
                    Navigator.pop(context);
                    if (ModalRoute.of(context)?.settings.name !=
                        AppRoutes.home) {
                      Navigator.pushNamedAndRemoveUntil(
                          context, AppRoutes.home, (route) => false);
                    } else {
                      viewModel.setSearchQuery("");
                      viewModel.setFiltro('Todos');
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_document, color: scotiaRed),
                  title: const Text("Solicitud de Crédito"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.solicitud);
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.file_present_outlined, color: scotiaRed),
                  title: const Text("Documentos"),
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.documentosSolicitud),
                ),
                ListTile(
                  leading: const Icon(Icons.money_off, color: scotiaRed),
                  title: const Text("Mora Diaria (Cobranza)"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.moraDiaria);
                  },
                ),
                const Divider(),
                // RF-05/06: Capacidades de Super Operador / Supervisor / Administrador
                if (authViewModel.esSuperOperador) ...[
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text("SUPERVISIÓN",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.analytics_outlined, color: scotiaRed),
                    title: const Text("Reportes y Monitor"),
                    onTap: () => Navigator.pushNamed(
                        context, AppRoutes.productividadMensual),
                  ),
                ],
                if (authViewModel.esSupervisor) ...[
                  ListTile(
                    leading:
                        const Icon(Icons.location_on_outlined, color: scotiaRed),
                    title: const Text("Monitor en mapa"),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                          context, AppRoutes.monitorSupervision);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1_outlined,
                        color: scotiaRed),
                    title: const Text("Reasignación Tareas"),
                    onTap: () {
                      Navigator.pop(context);
                      // Aquí navegaría a una pantalla que liste la cartera total para mover filas
                    },
                  ),
                ],
                if (authViewModel.esAdmin) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined,
                        color: scotiaRed),
                    title: const Text("Gestión de Usuarios"),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.gestionUsuarios);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined, color: scotiaRed),
                    title: const Text("Configuración"),
                    onTap: () {},
                  ),
                ],
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: scotiaRed),
            title: const Text("Cerrar Sesión"),
            onTap: () => _handleLogout(context, viewModel),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context, CarteraViewModel viewModel) async {
    final authViewModel = context.read<AuthOficialViewModel>();
    final navigator = Navigator.of(context);
    int pendientesSync = viewModel.pendientesSyncCount;

    if (pendientesSync > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Pendientes de Sincronización"),
          content: Text("Tienes $pendientesSync solicitudes sin enviar. ¿Cerrar sesión de todas formas?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCELAR")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("CERRAR SESIÓN")),
          ],
        ),
      );
      if (confirm != true) return;
    } else {
      // Diálogo de confirmación estándar HU-03
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Cerrar Sesión"),
          content: const Text("¿Estás seguro que deseas salir? Los datos locales se borrarán por seguridad."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCELAR")),
            TextButton(
              onPressed: () => Navigator.pop(context, true), 
              child: const Text("CERRAR SESIÓN", style: TextStyle(color: Color(0xFFED1C24))),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    // RF-07: Secuencia de cierre de sesión
    if (mounted) {
      Navigator.pop(context); // Cierra el Drawer
      
      await authViewModel.signOut(); // Invalida token en servidor y borra rastro
      viewModel.clearLocalData(); // Borra cartera y fichas en caché
      
      if (mounted) {
        // Navega a login limpiando el historial de navegación
        navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      }
    }
  }

  void _showClienteDetalle(BuildContext context, Cliente cliente) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(cliente.nombreCompleto, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Divider(height: 30),
                  _buildDetailRow(Icons.fingerprint, "ID de Registro", cliente.id),
                  _buildDetailRow(Icons.badge, "Documento", "${cliente.tipoDocumento} ${cliente.numeroDocumento}"),
                  _buildDetailRow(Icons.monetization_on, "Monto de Crédito", "S/ ${cliente.monto.toStringAsFixed(2)}"),
                  _buildDetailRow(Icons.priority_high, "Prioridad", cliente.prioridad),
                  _buildDetailRow(Icons.assignment, "Tipo de Gestión", cliente.tipoGestion),
                  _buildDetailRow(Icons.info_outline, "Estado Actual", cliente.estado.toUpperCase()),
                  _buildDetailRow(Icons.person, "Asesor Asignado", 
                    cliente.nombreAsesor ?? (cliente.oficialId ?? "No asignado")),
                  const SizedBox(height: 24),
                  // HU-11: Botón para ver la ficha completa
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.visibility, color: Colors.blue),
                      label: const Text("VER FICHA COMPLETA", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.blue),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) => FichaClienteScreen(cliente: cliente),
                        ));
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!cliente.visitado)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.how_to_reg, color: Colors.white),
                        label: const Text("REGISTRAR RESULTADO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () {
                          Navigator.pop(context);
                          _showPanelResultadoVisita(context, cliente);
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("CERRAR", style: TextStyle(color: Colors.black54)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPanelResultadoVisita(BuildContext context, Cliente cliente) {
    String? resultadoSeleccionado;
    final obsController = TextEditingController();
    final viewModel = context.read<CarteraViewModel>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Resultado de Visita", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: ['Visitado', 'No encontrado', 'Reagendar', 'Negocio cerrado'].map((res) {
                  final isSelected = resultadoSeleccionado == res;
                  return ChoiceChip(
                    label: Text(res),
                    selected: isSelected,
                    onSelected: (val) => setModalState(() => resultadoSeleccionado = val ? res : null),
                    selectedColor: const Color(0xFFED1C24).withOpacity(0.2),
                    labelStyle: TextStyle(color: isSelected ? const Color(0xFFED1C24) : Colors.black),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: obsController,
                maxLength: 200,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Observaciones (opcional)...",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFED1C24), padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: resultadoSeleccionado == null ? null : () async {
                    final success = await viewModel.registrarVisita(cliente.id, resultadoSeleccionado!, obsController.text);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(success ? "Visita registrada correctamente" : "Error al registrar. Se reintentará al conectar."))
                      );
                    }
                  },
                  child: const Text("CONFIRMAR Y FINALIZAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFED1C24), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black, fontSize: 15),
                children: [
                  TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounter(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Color _getColorGestion(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'RENOVACION': return Colors.blue;
      case 'AMPLIACION': return Colors.green;
      case 'NUEVA SOLICITUD': return Colors.orange;
      case 'SEGUIMIENTO': return Colors.blueGrey;
      case 'RECUPERACION MORA': return Colors.red;
      case 'DESERTOR': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Widget _buildGestionChip(String tipo) {
    final color = _getColorGestion(tipo);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(tipo, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPriorityTag(String prioridad) {
    Color color = prioridad == 'ALTA' ? Colors.red[700]! : (prioridad == 'MEDIA' ? Colors.orange[800]! : Colors.blue[700]!);
    return Text(prioridad, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold));
  }

  Widget _buildStatusIcon(Cliente cliente) {
    if (cliente.visitado) return const Icon(Icons.check_circle, color: Colors.green, size: 32);
    if (cliente.estado.toLowerCase() == 'en ruta') return const Icon(Icons.pending_actions, color: Colors.blue, size: 32);
    return const Icon(Icons.account_circle_outlined, color: Colors.grey, size: 32);
  }
}