import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../model/auth_service.dart';

class AuthOficialViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoadingUsuarios = false;
  bool get isLoadingUsuarios => _isLoadingUsuarios;

  bool _isLoadingSolicitudes = false;
  bool get isLoadingSolicitudes => _isLoadingSolicitudes;

  bool _isLoadingAuth = false;
  bool get isLoadingAuth => _isLoadingAuth;

  bool _isLoadingProfile = false;
  bool get isLoadingProfile => _isLoadingProfile;

  // Mantenemos isLoading para compatibilidad, pero ahora es calculado
  bool get isLoading => _isLoadingUsuarios || _isLoadingSolicitudes || _isLoadingAuth;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int _intentosFallidos = 0;
  DateTime? _bloqueoHasta;
  String _perfil = 'operador'; // Por defecto (estándar DB)
  String _nombreUsuario = '';
  String _codigoUsuario = '';
  Timer? _countdownTimer;
  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _solicitudesAcceso = [];
  String _filtroUsuarioActual = 'Todos';

  AuthOficialViewModel() {
    _loadLockoutState();
    _checkInactivityOnStart();
    _loadProfileFromSession();
  }

  String get perfil => _perfil;
  String get nombreUsuario => _nombreUsuario;
  String get codigoUsuario => _codigoUsuario;
  String get filtroUsuarioActual => _filtroUsuarioActual;

  /// Devuelve la lista de usuarios filtrada por el rol seleccionado en la UI
  List<Map<String, dynamic>> get usuariosFiltrados {
    if (_filtroUsuarioActual == 'Todos') return _usuarios;
    
    // Normalizamos el filtro para comparar (ej: 'Super Operador' -> 'super_operador')
    final target = _filtroUsuarioActual.toLowerCase().replaceAll(' ', '_');
    return _usuarios.where((u) => 
      (u['perfil'] ?? '').toString().toLowerCase() == target
    ).toList();
  }

  /// Devuelve el mensaje de bienvenida para el Drawer: "Hola, [Rol] [Código]"
  String get mensajeBienvenida {
    // Si no hay código pero hay sesión, mostramos un genérico en lugar de "Cargando..." perpetuo
    if (_isLoadingProfile) return "Cargando perfil...";
    if (_codigoUsuario.isEmpty) return "Hola, Usuario";

    // Capitalizamos el rol y quitamos guiones bajos para que se vea profesional
    final rolDisplay = _perfil.isNotEmpty 
        ? _perfil[0].toUpperCase() + _perfil.substring(1).replaceAll('_', ' ') 
        : 'Usuario';

    return "Hola, $rolDisplay $_codigoUsuario";
  }

  List<Map<String, dynamic>> get usuarios => _usuarios;
  List<Map<String, dynamic>> get solicitudesAcceso => _solicitudesAcceso;
  bool get estaBloqueado => _bloqueoHasta != null && DateTime.now().isBefore(_bloqueoHasta!);

  // Helpers para facilitar la lógica en la UI
  // Siguen la jerarquía RF-06
  bool get esAdmin => _perfil == 'administrador';
  bool get esSupervisor => _perfil == 'supervisor' || esAdmin;
  bool get esSuperOperador => _perfil == 'super_operador' || esSupervisor;
  bool get esOperador => _perfil == 'operador' || esSuperOperador;

  int get segundosRestantesBloqueo {
    if (!estaBloqueado) return 0;
    final diff = _bloqueoHasta!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// Limpia el mensaje de error actual
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Carga el perfil si ya existe una sesión activa al arrancar la app
  Future<void> _loadProfileFromSession() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _isLoadingProfile = true;
      _codigoUsuario = ""; // Reset para mostrar "Cargando..."
      _errorMessage = null;
      notifyListeners();
      try {
        // Consultamos perfil, nombres y código del asesor registrado
        final data = await Supabase.instance.client
            .from('asesores_negocio')
            .select('perfil, nombres, codigo_empleado')
            .eq('user_id', user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 10));
            
        if (data != null && data['perfil'] != null) {
          _perfil = data['perfil'].toString().toLowerCase();
          _nombreUsuario = data['nombres'] ?? '';
          _codigoUsuario = data['codigo_empleado'] ?? '';
          debugPrint("Acceso concedido con perfil: $_perfil");
        } else {
          _perfil = 'operador';
          debugPrint("Aviso: No se encontró perfil en DB para ${user.id}, asignando operador.");
        }
      } catch (e) {
        debugPrint("Error crítico cargando perfil: $e");
        _errorMessage = _parseError(e); // Capturamos el error real (como la recursión)
        _perfil = 'operador';
      } finally {
        _isLoadingProfile = false;
        notifyListeners();
      }
    } else {
      // Si no hay usuario, reseteamos valores
      _perfil = 'operador';
      _codigoUsuario = '';
      _nombreUsuario = '';
      notifyListeners();
    }
  }

  /// Cambia el filtro de roles en la pantalla de gestión de usuarios
  void setFiltroUsuario(String nuevoFiltro) {
    _filtroUsuarioActual = nuevoFiltro;
    notifyListeners();
  }

  /// Obtiene la lista de todos los asesores (Solo Admin/Supervisor)
  Future<void> fetchUsuarios() async {
    _isLoadingUsuarios = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _usuarios = await _authService.fetchAsesores();
    } catch (e) {
      debugPrint("Error fetching usuarios: $e");
      _errorMessage = _parseError(e);
    } finally {
      _isLoadingUsuarios = false;
      notifyListeners();
    }
  }

  /// Obtiene solicitudes de acceso pendientes de aprobación
  Future<void> fetchSolicitudesAcceso() async {
    _isLoadingSolicitudes = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _solicitudesAcceso = await _authService.fetchSolicitudesAcceso();
    } catch (e) {
      debugPrint("Error fetching solicitudes: $e");
      _errorMessage = "Error al cargar solicitudes: $e";
    } finally {
      _isLoadingSolicitudes = false;
      notifyListeners();
    }
  }

  /// Crea un nuevo asesor y refresca la lista de usuarios. 
  /// Si viene de una solicitud, la marca como completada.
  /// Retorna el mensaje de éxito si todo salió bien, o null si hubo error.
  Future<String?> crearNuevoAsesor(String codigo, String nombres, String apellidos, String rol, String? agenciaId, {dynamic solicitudId}) async {
    _isLoadingUsuarios = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final successMessage = await _authService.crearAsesor(
        codigo: codigo, 
        nombres: nombres, 
        apellidos: apellidos, 
        rol: rol, 
        agenciaId: agenciaId,
        solicitudId: solicitudId,
      );
      
      await fetchSolicitudesAcceso();
      await fetchUsuarios();
      return successMessage; // Retornamos el mensaje para que el View lo use
    } catch (e) {
      _errorMessage = _parseError(e);
      return null;
    } finally {
      _isLoadingUsuarios = false;
      notifyListeners();
    }
  }

  /// Actualiza un asesor y refresca la lista
  Future<bool> actualizarAsesor(String id, String nombres, String apellidos, String rol) async {
    _isLoadingUsuarios = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.actualizarAsesor(id: id, nombres: nombres, apellidos: apellidos, rol: rol);
      // Timeout para la actualización de asesor
      await fetchUsuarios(); // Refrescar la lista local
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      return false;
    } finally {
      _isLoadingUsuarios = false;
      notifyListeners();
    }
  }

  /// Rechaza una solicitud de acceso enviándola a estado 'rechazada'
  Future<void> rechazarSolicitud(dynamic id) async {
    _isLoadingSolicitudes = true;
    notifyListeners();
    try {
      await _authService.actualizarEstadoSolicitud(id, 'rechazada');
      // Timeout para la actualización de solicitud
      await fetchSolicitudesAcceso();
    } catch (e) {
      _errorMessage = _parseError(e);
    } finally {
      _isLoadingSolicitudes = false;
      notifyListeners();
    }
  }

  /// Elimina un asesor y refresca la lista
  Future<bool> eliminarAsesor(String id) async {
    _isLoadingUsuarios = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.eliminarAsesor(id);
      // Timeout para la eliminación de asesor
      await fetchUsuarios();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      return false;
    } finally {
      _isLoadingUsuarios = false;
      notifyListeners();
    }
  }

  // RF-04: Cargar estado de bloqueo persistente
  Future<void> _loadLockoutState() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('bloqueo_hasta');
    if (timestamp != null) {
      _bloqueoHasta = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (estaBloqueado) _startCountdown();
      notifyListeners();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!estaBloqueado) {
        timer.cancel();
      }
      notifyListeners();
    });
  }

  Future<bool> login(String codigoEmpleado, String contrasena) async {
    if (estaBloqueado) {
      _errorMessage = "Cuenta bloqueada temporalmente.";
      notifyListeners();
      return false;
    }

    _isLoadingAuth = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _authService.loginOficial(codigoEmpleado, contrasena);
      if (success) {
        _intentosFallidos = 0;
        _bloqueoHasta = null;
        _isLoadingAuth = false;
        
        // Cargamos el perfil real desde la tabla. 
        // notifyListeners se llama dentro de _loadProfileFromSession
        await _loadProfileFromSession();
        return true;
      }
      
      _manejarIntentoFallido();
      _errorMessage = "Código o contraseña incorrectos.";
      return false;
    } catch (e) {
      _manejarIntentoFallido();
      _errorMessage = _parseError(e);
      return false;
    } finally {
      _isLoadingAuth = false;
      notifyListeners();
    }
  }

  void _manejarIntentoFallido() async {
    _intentosFallidos++;
    if (_intentosFallidos >= 5) {
      _bloqueoHasta = DateTime.now().add(const Duration(minutes: 30));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('bloqueo_hasta', _bloqueoHasta!.millisecondsSinceEpoch);
      _startCountdown();
    }
    notifyListeners();
  }

  // HU-01: Gestión de inactividad (8 horas)
  void recordActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_activity', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _checkInactivityOnStart() async {
    final prefs = await SharedPreferences.getInstance();
    final lastActivity = prefs.getInt('last_activity');
    if (lastActivity != null) {
      final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastActivity));
      if (diff.inHours >= 8) {
        await signOut();
      }
    }
  }

  /// Maneja la solicitud de nuevo registro
  Future<bool> requestRegistration(String codigo, String nombres, String apellidos, String email) async {
    _isLoadingAuth = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Timeout para el envío de solicitud de registro
      await _authService.sendRegistrationRequest(codigo, nombres, apellidos, email);
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      return false;
    } finally {
      _isLoadingAuth = false;
      notifyListeners();
    }
  }

  /// Maneja el olvido de contraseña
  Future<bool> resetPassword(String codigo) async {
    _isLoadingAuth = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Timeout para el reseteo de contraseña
      await _authService.sendPasswordReset(codigo);
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      return false;
    } finally {
      _isLoadingAuth = false;
      notifyListeners();
    }
  }

  /// Cierra la sesión y limpia el estado
  Future<void> signOut() async {
    await _authService.signOut();
    _perfil = 'operador'; // Resetear perfil por seguridad al salir
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_activity'); // RF-07: Borrar rastro de sesión activa
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Analiza errores de Supabase (Auth, Functions, Postgrest) para mostrar mensajes reales
  String _parseError(dynamic e) {
    if (e is FunctionException) {
      // Las FunctionException no tienen .message, tienen .details (Object?) y .status
      final dynamic details = e.details;

      // Caso 1: details es un Mapa (JSON ya decodificado)
      if (details is Map<String, dynamic>) {
        final msg = details['error'] ?? details['message'] ?? details['msg'];
        if (msg != null && msg.toString().trim().toLowerCase() != "message") {
          return msg.toString().trim();
        }
      }

      // Caso 2: details es un String (posible JSON sin decodificar)
      if (details is String && details.trim().isNotEmpty) {
        if (details.trim().toLowerCase() == "message") return "Error interno en la Edge Function (Sin detalle).";
        
        try {
          final decoded = jsonDecode(details);
          if (decoded is Map<String, dynamic>) {
            final msg = decoded['error'] ?? decoded['message'] ?? decoded['msg'];
            if (msg != null && msg.toString().trim().toLowerCase() != "message") {
              return msg.toString().trim();
            }
          }
        } catch (_) { 
          return details.trim(); // No es JSON, pero devolvemos el texto original
        }
      }

      // Fallback final: No usar e.message (no existe), usar status o toString()
      final String errStr = e.toString();
      if (errStr.toLowerCase().contains("message")) {
        return "Error del servidor (Código: ${e.status}). Contacte a soporte.";
      }
      return errStr;
    }

    if (e is AuthException) {
      if (e.message.contains("Email not confirmed")) {
        return "Tu cuenta aún no ha sido confirmada por un administrador.";
      }
      if (e.message.contains("Invalid login credentials")) {
        return "Código o contraseña incorrectos.";
      }
      return e.message;
    }
    if (e is PostgrestException) {
      if (e.message.contains("infinite recursion")) {
        return "Error de base de datos: Recursión infinita detectada en las políticas RLS. Contacte a soporte.";
      }
      return e.message;
    }
    return e.toString();
  }
}