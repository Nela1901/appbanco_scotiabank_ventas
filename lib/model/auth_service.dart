import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  /// Autenticación real con Supabase Auth
  Future<bool> loginOficial(String codigo, String password) async { //
    // Mapeamos el código ingresado al formato de correo que Supabase entiende.
    // Quitamos el try-catch aquí para que el ViewModel capture el error específico.
    final emailFormateado = '${codigo.trim().toUpperCase()}@scotiabank.com.pe';
    debugPrint('Intentando login con: $emailFormateado');
    
    // Si la contraseña es igual al código (caso inicial), la normalizamos a Mayúsculas
    // para que coincida con lo creado por la Edge Function.
    String finalPassword = password;
    if (password.trim().toLowerCase() == codigo.trim().toLowerCase()) {
      finalPassword = password.trim().toUpperCase();
      // Si el código es menor a 6 caracteres, aplicamos el relleno de ceros 
      // para coincidir con la política de seguridad de la Edge Function.
      if (finalPassword.length < 6) {
        finalPassword = finalPassword.padRight(6, '0');
      }
    }

    final response = await _supabase.auth.signInWithPassword(
      email: emailFormateado,
      password: finalPassword,
    );
    return response.user != null;
  }

  /// Crea un nuevo usuario en la base de datos (Requiere lógica de Edge Function para Auth)
  Future<String> crearAsesor({ // Cambiamos el tipo de retorno a String
    required String codigo,
    required String nombres,
    required String apellidos,
    required String rol,
    String? agenciaId,
    dynamic solicitudId,
  }) async {
    FunctionResponse? response;
    try {
      // Invocamos la Edge Function que gestionará la creación en Auth y en la Tabla
      response = await _supabase.functions.invoke('admin-create-user', body: {
        'codigo': codigo.trim().toUpperCase(),
        'nombres': nombres,
        'apellidos': apellidos,
        'perfil': rol.toLowerCase().replaceAll(' ', '_'), 
        'agencia_id': (agenciaId == null || agenciaId.isEmpty || agenciaId == 'AG-001') ? null : agenciaId,
        'solicitud_id': solicitudId,
      });
    } on FunctionException catch (e) {
      // Si la función no existe (404), realizamos un fallback temporal para pruebas
      // Si la función no existe, mantenemos el fallback temporal para pruebas
      if (e.status == 404) {
        debugPrint('Aviso: Edge Function no encontrada. Realizando inserción directa en base de datos.');
        await _supabase.from('asesores_negocio').insert({
          'codigo_empleado': codigo.trim().toUpperCase(),
          'nombres': nombres,
          'apellidos': apellidos,
          'perfil': rol.toLowerCase().replaceAll(' ', '_'),
          'agencia_id': (agenciaId == null || agenciaId.isEmpty || agenciaId == 'AG-001') ? null : agenciaId,
        });
        // Si el fallback se ejecuta, devolvemos un mensaje genérico de éxito
        return 'Usuario creado exitosamente (vía fallback).';
      } else {
        rethrow;
      }
    }
    // Usamos ?. en data para evitar el error si la respuesta es nula o vacía
    return response?.data?['message']?.toString() ?? 'Usuario creado exitosamente.';
  }

  /// Obtiene la lista de todos los asesores
  Future<List<Map<String, dynamic>>> fetchAsesores() async {
    final response = await _supabase
        .from('asesores_negocio')
        .select('*')
        .order('perfil', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Actualiza los datos de un asesor existente
  Future<void> actualizarAsesor({
    required String id,
    required String nombres,
    required String apellidos,
    required String rol,
  }) async {
    // Usamos la tabla 'asesores_negocio' y las columnas del esquema proporcionado
    // Usamos .select() para verificar si la actualización realmente afectó filas (RLS)
    final response = await _supabase.from('asesores_negocio').update({
      'nombres': nombres,
      'apellidos': apellidos,
      'perfil': rol,
    }).eq('id', id).select();

    if (response.isEmpty) {
      throw Exception(
          'No se pudo actualizar: Verifique que tiene permisos de Administrador en la base de datos (RLS).');
    }
  }

  /// Elimina un usuario de la base de datos para revocar acceso
  Future<void> eliminarAsesor(String id) async {
    await _supabase.from('asesores_negocio').delete().eq('id', id);
  }

  /// Obtiene las solicitudes de acceso que aún no han sido procesadas
  Future<List<Map<String, dynamic>>> fetchSolicitudesAcceso() async {
    try {
      final response = await _supabase
          .from('solicitudes_acceso')
          .select('*')
          .eq('estado', 'pendiente')
          .order('fecha_creacion', ascending: false);
      
      debugPrint('AuthService: Solicitudes pendientes encontradas: ${response.length}');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('AuthService Error fetchSolicitudesAcceso: $e');
      rethrow;
    }
  }

  /// Actualiza el estado de una solicitud (ej: rechazada o completada)
  Future<void> actualizarEstadoSolicitud(dynamic id, String estado) async {
    await _supabase
        .from('solicitudes_acceso')
        .update({'estado': estado})
        .eq('id', id);
  }

  /// Inserta una solicitud en la tabla 'solicitudes_acceso'
  Future<void> sendRegistrationRequest(String codigo, String nombres, String apellidos, String email) async {
    await _supabase.from('solicitudes_acceso').insert({
      'codigo_empleado': codigo.trim().toUpperCase(),
      'nombres': nombres,
      'apellidos': apellidos,
      'email_contacto': email.trim(),
      'estado': 'pendiente',
      'fecha_creacion': DateTime.now().toIso8601String(),
    });
  }

  /// Usa el sistema de recuperación de Supabase mediante el código de empleado
  Future<void> sendPasswordReset(String codigo) async {
    // Convertimos el código al correo formateado que conoce Supabase Auth
    final emailFormateado = '${codigo.trim().toUpperCase()}@scotiabank.com.pe';
    await _supabase.auth.resetPasswordForEmail(emailFormateado);
  }

  /// RF-06: Reasigna una tarea de cartera a otro asesor (Solo Supervisor/Admin)
  Future<void> reasignarTarea(String carteraId, String nuevoAsesorId) async {
    await _supabase
        .from('cartera_diaria')
        .update({'asesor_id': nuevoAsesorId})
        .eq('id', carteraId);
  }

  /// Cierra la sesión activa en Supabase
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}