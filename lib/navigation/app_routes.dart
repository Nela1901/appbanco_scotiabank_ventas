import 'package:flutter/material.dart';
import '../view/auth/login_oficial_screen.dart';
import '../view/home/cartera_diaria_screen.dart';
import '../view/auth/forgot_password_screen.dart';
import '../view/auth/register_request_screen.dart';
import '../view/home/mapa_ruta_screen.dart';
import '../view/home/prospeccion_form_screen.dart';
import '../view/home/solicitud_form_screen.dart';
import '../view/home/simulador_screen.dart';
import '../view/home/historial_solicitudes_screen.dart';
import '../view/home/documentos_solicitud_screen.dart';
import '../view/home/buro_consulta_screen.dart';
import '../view/home/tablero_solicitudes_screen.dart';
import '../view/home/detalle_solicitud_screen.dart';
import '../view/home/mora_diaria_screen.dart';
import '../view/home/gestion_cobranza_screen.dart';
import '../view/home/monitor_supervision_screen.dart';
import '../view/home/productividad_mensual_screen.dart';
import '../view/home/gestion_usuarios_screen.dart';

class AppRoutes {
  static const String login = '/';
  static const String home = '/home';
  static const String forgotPassword = '/forgot-password';
  static const String registerRequest = '/register-request';
  static const String mapaRuta = '/mapa-ruta';
  static const String prospeccion = '/prospeccion';
  static const String solicitud = '/solicitud';
  static const String simulador = '/simulador';
  static const String historialSolicitudes = '/historial-solicitudes';
  static const String documentosSolicitud = '/documentos-solicitud';
  static const String buroConsulta = '/buro-consulta';
  static const String tableroSolicitudes = '/tablero-solicitudes';
  static const String detalleSolicitud = '/detalle-solicitud';
  static const String moraDiaria = '/mora-diaria';
  static const String gestionCobranza = '/gestion-cobranza';
  static const String monitorSupervision = '/monitor-supervision';
  static const String productividadMensual = '/productividad-mensual';
  static const String gestionUsuarios = '/gestion-usuarios';

  static Map<String, WidgetBuilder> get routes {
    return {
      login: (context) => const LoginOficialScreen(),
      home: (context) => const CarteraDiariaScreen(),
      forgotPassword: (context) => const ForgotPasswordScreen(),
      registerRequest: (context) => const RegisterRequestScreen(),
      mapaRuta: (context) => const MapaRutaScreen(),
      prospeccion: (context) => const ProspeccionFormScreen(),
      solicitud: (context) => const SolicitudFormScreen(),
      simulador: (context) => const SimuladorScreen(),
      historialSolicitudes: (context) => const HistorialSolicitudesScreen(),
      documentosSolicitud: (context) => const DocumentosSolicitudScreen(),
      buroConsulta: (context) => const BuroConsultaScreen(),
      tableroSolicitudes: (context) => const TableroSolicitudesScreen(),
      detalleSolicitud: (context) => const DetalleSolicitudScreen(),
      moraDiaria: (context) => const MoraDiariaScreen(),
      gestionCobranza: (context) => const GestionCobranzaScreen(),
      monitorSupervision: (context) => const MonitorSupervisionScreen(),
      productividadMensual: (context) => const ProductividadMensualScreen(),
      gestionUsuarios: (context) => const GestionUsuariosScreen(),
    };
  }
}